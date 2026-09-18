import Agentic
import AgenticRecovery
import Foundation

private struct InferenceActiveRecovery {
    let incident: Recovery.Incident
    let plan: Recovery.Plan
    let decision: Recovery.Decision
    var attempts: [Recovery.Attempt]
    var lastMessage: String

    init(
        incident: Recovery.Incident,
        plan: Recovery.Plan,
        decision: Recovery.Decision,
        message: String
    ) {
        self.incident = incident
        self.plan = plan
        self.decision = decision
        self.attempts = []
        self.lastMessage = message
    }

    func record(
        outcome: Recovery.Outcome
    ) -> Recovery.Record {
        Recovery.Record(
            incident: incident,
            plan: plan,
            attempts: attempts,
            outcome: outcome
        )
    }
}

private enum InferenceInvocationMode {
    case initial
    case recovery(
        InferenceActiveRecovery,
        Recovery.AttemptPermit
    )
}

private func recoveryIncidentCapturingEvidence(
    _ incident: Recovery.Incident,
    error: any Error
) -> Recovery.Incident {
    guard incident.report == nil else {
        return incident
    }

    return Recovery.Incident(
        capturing: error,
        kind: incident.kind,
        stage: incident.stage,
        effectState: incident.effectState,
        retrySafety: incident.retrySafety,
        scope: incident.scope,
        message: incident.message,
        metadata: incident.metadata
    )
}

private func classifyInferenceRecoveryIncident(
    for error: any Error,
    stage: Recovery.Stage,
    adapter: any InferenceAdapter,
    fallback: (any InferenceRecoveryClassifying)?,
    inference: InferenceIdentifier,
    attemptIndex: Int,
    invocationIndex: Int
) -> Recovery.Incident? {
    if let adapterClassifier =
        adapter as? any InferenceRecoveryClassifying,
       let incident = adapterClassifier.incident(
            for: error,
            stage: stage,
            inference: inference,
            attemptIndex: attemptIndex,
            invocationIndex: invocationIndex
       )
    {
        return recoveryIncidentCapturingEvidence(
            incident,
            error: error
        )
    }

    guard let incident = fallback?.incident(
        for: error,
        stage: stage,
        inference: inference,
        attemptIndex: attemptIndex,
        invocationIndex: invocationIndex
    ) else {
        return nil
    }

    return recoveryIncidentCapturingEvidence(
        incident,
        error: error
    )
}

public struct InferenceAttemptExecutor:
    InferenceAttemptExecuting,
    Sendable
{
    private let modelInvoker: any AgentModelInvoking
    private let adapters: any InferenceAdapterResolving
    private let defaultAdapterIdentifier: InferenceAdapterIdentifier?
    private let recoveryClassifier: (any InferenceRecoveryClassifying)?

    public init(
        modelInvoker: any AgentModelInvoking,
        adapters: any InferenceAdapterResolving,
        defaultAdapterIdentifier: InferenceAdapterIdentifier? = nil,
        recoveryClassifier: (any InferenceRecoveryClassifying)? = nil
    ) {
        self.modelInvoker = modelInvoker
        self.adapters = adapters
        self.defaultAdapterIdentifier = defaultAdapterIdentifier
        self.recoveryClassifier = recoveryClassifier
    }

    private func terminalFailure(
        error: any Error,
        recovery: Recovery.Record? = nil,
        attemptIndex: Int,
        adapter: InferenceAdapterIdentifier,
        selection: AgentModelSelection,
        invocations: [InferenceInvocationRecord],
        recoveries: [Recovery.Record],
        metadata: [String: String]
    ) -> InferenceAttemptFailure {
        var recordedRecoveries = recoveries

        if let recovery {
            recordedRecoveries.append(recovery)
        }

        return InferenceAttemptFailure(
            index: attemptIndex,
            adapter: adapter,
            selection: selection,
            failure: InferenceFailureRecord(
                capturing: error,
                recovery: recovery
            ),
            invocations: invocations,
            recoveries: recordedRecoveries,
            metadata: metadata
        )
    }

    public func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext,
        priorAttempts: [InferenceAttemptRecord] = [],
        additionalRequirements: AgentModelRequirements = AgentModelRequirements(
            capabilities: []
        )
    ) async throws -> InferenceAttemptResult<InferenceType.Output> {
        let attemptPermit = try realization.budget.nextAttempt(
            priorAttempts: priorAttempts
        )
        let attemptIndex = attemptPermit.index

        guard let adapterIdentifier = realization.adapter ?? defaultAdapterIdentifier else {
            throw InferenceExecutionError.adapterUnspecified(
                inference: inference.definition.identifier
            )
        }

        let adapter = try adapters.require(
            adapterIdentifier
        )
        var adaptation = try adapter.prepare(
            inference,
            input: input,
            realization: realization
        )

        var invocations: [InferenceInvocationRecord] = []
        var recoveries: [Recovery.Record] = []
        var activeRecovery: InferenceActiveRecovery?
        var lastSelection = context.modelSelection
        var lastMetadata = realization.metadata

        while true {
            let invocationMode: InferenceInvocationMode

            if let activeRecovery {
                guard let recoveryPermit = activeRecovery.decision.limit.nextAttempt(
                    after: UInt(
                        activeRecovery.attempts.count
                    )
                ) else {
                    let recoveryRecord = activeRecovery.record(
                        outcome: .exhausted
                    )
                    let recoveryError = InferenceRecoveryError(
                        record: recoveryRecord,
                        message: activeRecovery.lastMessage
                    )

                    throw terminalFailure(
                        error: recoveryError,
                        recovery: recoveryRecord,
                        attemptIndex: attemptIndex,
                        adapter: adapter.identifier,
                        selection: lastSelection,
                        invocations: invocations,
                        recoveries: recoveries,
                        metadata: lastMetadata
                    )
                }

                invocationMode = .recovery(
                    activeRecovery,
                    recoveryPermit
                )
            } else {
                invocationMode = .initial
            }

            let invocationPermit: InferenceInvocationPermit

            do {
                invocationPermit = try realization.budget.nextInvocation(
                    priorAttempts: priorAttempts,
                    currentInvocations: invocations
                )
            } catch {
                guard !invocations.isEmpty else {
                    throw error
                }

                let recoveryRecord = activeRecovery?.record(
                    outcome: .failed
                )

                throw terminalFailure(
                    error: error,
                    recovery: recoveryRecord,
                    attemptIndex: attemptIndex,
                    adapter: adapter.identifier,
                    selection: lastSelection,
                    invocations: invocations,
                    recoveries: recoveries,
                    metadata: lastMetadata
                )
            }

            let invocationIndex = invocationPermit.index

            var selection = context.modelSelection
            selection.requirements = selection.requirements
                .merging(
                    context.requirements
                )
                .merging(
                    adaptation.requirements
                )
                .merging(
                    additionalRequirements
                )
            lastSelection = selection

            var metadata = realization.metadata
            metadata["inference.identifier"] =
                inference.definition.identifier.rawValue
            metadata["inference.strategy"] =
                realization.strategy.rawValue
            metadata["inference.adapter"] =
                adapter.identifier.rawValue
            metadata["inference.attempt"] =
                String(attemptIndex)
            metadata["inference.invocation"] =
                String(invocationIndex)
            lastMetadata = metadata

            let result: AgentModelInvocationResult

            do {
                result = try await modelInvoker.buffered(
                    AgentModelInvocation(
                        request: adaptation.request,
                        selection: selection,
                        metadata: metadata
                    )
                )
            } catch {
                let message = error.localizedDescription
                let incident = classifyInferenceRecoveryIncident(
                    for: error,
                    stage: .execution,
                    adapter: adapter,
                    fallback: recoveryClassifier,
                    inference: inference.definition.identifier,
                    attemptIndex: attemptIndex,
                    invocationIndex: invocationIndex
                )

                invocations.append(
                    InferenceInvocationRecord(
                        index: invocationIndex,
                        selection: selection,
                        outcome: .failed(
                            .init(
                                message: message,
                                incident: incident
                            )
                        ),
                        metadata: metadata
                    )
                )

                switch invocationMode {
                case .initial:
                    guard let incident else {
                        throw terminalFailure(
                            error: error,
                            attemptIndex: attemptIndex,
                            adapter: adapter.identifier,
                            selection: selection,
                            invocations: invocations,
                            recoveries: recoveries,
                            metadata: metadata
                        )
                    }

                    let plan = realization.recovery?.plan(
                        for: incident
                    )

                    guard
                        let plan,
                        let step = plan.steps.first,
                        step.action == .retry_same_operation
                    else {
                        let recoveryRecord = InferenceRecoveryError(
                            propagating: incident,
                            plan: plan,
                            message: message
                        ).record

                        throw terminalFailure(
                            error: error,
                            recovery: recoveryRecord,
                            attemptIndex: attemptIndex,
                            adapter: adapter.identifier,
                            selection: selection,
                            invocations: invocations,
                            recoveries: recoveries,
                            metadata: metadata
                        )
                    }

                    activeRecovery = InferenceActiveRecovery(
                        incident: incident,
                        plan: plan,
                        decision: Recovery.Decision(
                            step: step
                        ),
                        message: message
                    )

                case .recovery(
                    var recovery,
                    let permit
                ):
                    recovery.attempts.append(
                        Recovery.Attempt(
                            capturing: error,
                            number: permit.number,
                            action: recovery.decision.action,
                            message: message
                        )
                    )
                    recovery.lastMessage = message

                    guard
                        let incident,
                        incident.kind == recovery.incident.kind,
                        incident.stage == recovery.incident.stage
                    else {
                        let recoveryRecord = recovery.record(
                            outcome: .failed
                        )

                        throw terminalFailure(
                            error: error,
                            recovery: recoveryRecord,
                            attemptIndex: attemptIndex,
                            adapter: adapter.identifier,
                            selection: selection,
                            invocations: invocations,
                            recoveries: recoveries,
                            metadata: metadata
                        )
                    }

                    activeRecovery = recovery
                }

                continue
            }

            invocations.append(
                InferenceInvocationRecord(
                    index: invocationIndex,
                    selection: selection,
                    outcome: .succeeded(
                        .init(
                            route: result.route,
                            usage: result.response.usage
                        )
                    ),
                    metadata: metadata
                )
            )

            if case .recovery(
                var recovery,
                let permit
            ) = invocationMode,
               recovery.decision.action == .retry_same_operation
            {
                recovery.attempts.append(
                    Recovery.Attempt(
                        number: permit.number,
                        action: recovery.decision.action,
                        status: .succeeded
                    )
                )
                recoveries.append(
                    recovery.record(
                        outcome: .recovered
                    )
                )
                activeRecovery = nil
            }

            let output: InferenceType.Output

            do {
                output = try adapter.decode(
                    inference,
                    response: result.response
                )
            } catch {
                let message = error.localizedDescription
                let incident = classifyInferenceRecoveryIncident(
                    for: error,
                    stage: .decoding,
                    adapter: adapter,
                    fallback: recoveryClassifier,
                    inference: inference.definition.identifier,
                    attemptIndex: attemptIndex,
                    invocationIndex: invocationIndex
                )

                if case .recovery(
                    var recovery,
                    let permit
                ) = invocationMode,
                   recovery.decision.action == .repair_output
                {
                    recovery.attempts.append(
                        Recovery.Attempt(
                            capturing: error,
                            number: permit.number,
                            action: recovery.decision.action,
                            message: message
                        )
                    )
                    recovery.lastMessage = message

                    guard
                        let incident,
                        incident.kind == recovery.incident.kind,
                        incident.stage == recovery.incident.stage
                    else {
                        let recoveryRecord = recovery.record(
                            outcome: .failed
                        )

                        throw terminalFailure(
                            error: error,
                            recovery: recoveryRecord,
                            attemptIndex: attemptIndex,
                            adapter: adapter.identifier,
                            selection: selection,
                            invocations: invocations,
                            recoveries: recoveries,
                            metadata: metadata
                        )
                    }

                    guard let repairingAdapter =
                        adapter as? any InferenceOutputRepairing
                    else {
                        let recoveryRecord = recovery.record(
                            outcome: .propagated
                        )

                        throw terminalFailure(
                            error: error,
                            recovery: recoveryRecord,
                            attemptIndex: attemptIndex,
                            adapter: adapter.identifier,
                            selection: selection,
                            invocations: invocations,
                            recoveries: recoveries,
                            metadata: metadata
                        )
                    }

                    do {
                        adaptation = try repairingAdapter.repair(
                            inference,
                            input: input,
                            response: result.response,
                            error: error,
                            realization: realization
                        )
                    } catch {
                        let recoveryRecord = recovery.record(
                            outcome: .failed
                        )

                        throw terminalFailure(
                            error: error,
                            recovery: recoveryRecord,
                            attemptIndex: attemptIndex,
                            adapter: adapter.identifier,
                            selection: selection,
                            invocations: invocations,
                            recoveries: recoveries,
                            metadata: metadata
                        )
                    }

                    activeRecovery = recovery
                    continue
                }

                guard let incident else {
                    throw terminalFailure(
                        error: error,
                        attemptIndex: attemptIndex,
                        adapter: adapter.identifier,
                        selection: selection,
                        invocations: invocations,
                        recoveries: recoveries,
                        metadata: metadata
                    )
                }

                let plan = realization.recovery?.plan(
                    for: incident
                )

                guard
                    let plan,
                    let step = plan.steps.first,
                    step.action == .repair_output
                else {
                    let recoveryRecord = InferenceRecoveryError(
                        propagating: incident,
                        plan: plan,
                        message: message
                    ).record

                    throw terminalFailure(
                        error: error,
                        recovery: recoveryRecord,
                        attemptIndex: attemptIndex,
                        adapter: adapter.identifier,
                        selection: selection,
                        invocations: invocations,
                        recoveries: recoveries,
                        metadata: metadata
                    )
                }

                guard let repairingAdapter =
                    adapter as? any InferenceOutputRepairing
                else {
                    let recoveryRecord = InferenceRecoveryError(
                        propagating: incident,
                        plan: plan,
                        message: message
                    ).record

                    throw terminalFailure(
                        error: error,
                        recovery: recoveryRecord,
                        attemptIndex: attemptIndex,
                        adapter: adapter.identifier,
                        selection: selection,
                        invocations: invocations,
                        recoveries: recoveries,
                        metadata: metadata
                    )
                }

                let recovery = InferenceActiveRecovery(
                    incident: incident,
                    plan: plan,
                    decision: Recovery.Decision(
                        step: step
                    ),
                    message: message
                )

                do {
                    adaptation = try repairingAdapter.repair(
                        inference,
                        input: input,
                        response: result.response,
                        error: error,
                        realization: realization
                    )
                } catch {
                    let recoveryRecord = recovery.record(
                        outcome: .failed
                    )

                    throw terminalFailure(
                        error: error,
                        recovery: recoveryRecord,
                        attemptIndex: attemptIndex,
                        adapter: adapter.identifier,
                        selection: selection,
                        invocations: invocations,
                        recoveries: recoveries,
                        metadata: metadata
                    )
                }

                activeRecovery = recovery
                continue
            }

            if case .recovery(
                var recovery,
                let permit
            ) = invocationMode,
               recovery.decision.action == .repair_output
            {
                recovery.attempts.append(
                    Recovery.Attempt(
                        number: permit.number,
                        action: recovery.decision.action,
                        status: .succeeded
                    )
                )
                recoveries.append(
                    recovery.record(
                        outcome: .recovered
                    )
                )
                activeRecovery = nil
            }

            return InferenceAttemptResult(
                output: output,
                record: InferenceAttemptRecord(
                    index: attemptIndex,
                    adapter: adapter.identifier,
                    selection: selection,
                    route: result.route,
                    usage: result.response.usage,
                    invocations: invocations,
                    recoveries: recoveries,
                    metadata: metadata
                )
            )
        }
    }
}
