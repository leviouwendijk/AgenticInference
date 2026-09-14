import Agentic
import AgenticRecovery
import Foundation

private struct AgentInferenceActiveRecovery {
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

private enum AgentInferenceInvocationMode {
    case initial
    case recovery(
        AgentInferenceActiveRecovery,
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

private func classifyAgentInferenceRecoveryIncident(
    for error: any Error,
    stage: Recovery.Stage,
    adapter: any AgentInferenceAdapter,
    fallback: (any AgentInferenceRecoveryClassifying)?,
    inference: AgentInferenceIdentifier,
    attemptIndex: Int,
    invocationIndex: Int
) -> Recovery.Incident? {
    if let adapterClassifier =
        adapter as? any AgentInferenceRecoveryClassifying,
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

public struct AgentInferenceAttemptExecutor:
    AgentInferenceAttemptExecuting,
    Sendable
{
    private let modelInvoker: any AgentModelInvoking
    private let adapters: any AgentInferenceAdapterResolving
    private let defaultAdapterIdentifier: AgentInferenceAdapterIdentifier?
    private let recoveryClassifier: (any AgentInferenceRecoveryClassifying)?

    public init(
        modelInvoker: any AgentModelInvoking,
        adapters: any AgentInferenceAdapterResolving,
        defaultAdapterIdentifier: AgentInferenceAdapterIdentifier? = nil,
        recoveryClassifier: (any AgentInferenceRecoveryClassifying)? = nil
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
        adapter: AgentInferenceAdapterIdentifier,
        selection: AgentModelSelection,
        invocations: [AgentInferenceInvocationRecord],
        recoveries: [Recovery.Record],
        metadata: [String: String]
    ) -> AgentInferenceAttemptFailure {
        var recordedRecoveries = recoveries

        if let recovery {
            recordedRecoveries.append(recovery)
        }

        return AgentInferenceAttemptFailure(
            index: attemptIndex,
            adapter: adapter,
            selection: selection,
            failure: AgentInferenceFailureRecord(
                capturing: error,
                recovery: recovery
            ),
            invocations: invocations,
            recoveries: recordedRecoveries,
            metadata: metadata
        )
    }

    public func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization,
        priorAttempts: [AgentInferenceAttemptRecord] = [],
        additionalRequirements: AgentModelRequirements = AgentModelRequirements(
            capabilities: []
        )
    ) async throws -> AgentInferenceAttemptResult<Inference.Output> {
        let attemptPermit = try realization.budget.nextAttempt(
            priorAttempts: priorAttempts
        )
        let attemptIndex = attemptPermit.index

        guard let adapterIdentifier = realization.adapter ?? defaultAdapterIdentifier else {
            throw AgentInferenceExecutionError.adapterUnspecified(
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

        var invocations: [AgentInferenceInvocationRecord] = []
        var recoveries: [Recovery.Record] = []
        var activeRecovery: AgentInferenceActiveRecovery?
        var lastSelection = realization.modelSelection
        var lastMetadata = realization.metadata

        while true {
            let invocationMode: AgentInferenceInvocationMode

            if let activeRecovery {
                guard let recoveryPermit = activeRecovery.decision.limit.nextAttempt(
                    after: UInt(
                        activeRecovery.attempts.count
                    )
                ) else {
                    let recoveryRecord = activeRecovery.record(
                        outcome: .exhausted
                    )
                    let recoveryError = AgentInferenceRecoveryError(
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

            let invocationPermit = try realization.budget.nextInvocation(
                priorAttempts: priorAttempts,
                currentInvocations: invocations
            )
            let invocationIndex = invocationPermit.index

            var selection = realization.modelSelection
            selection.requirements = selection.requirements
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
                let incident = classifyAgentInferenceRecoveryIncident(
                    for: error,
                    stage: .execution,
                    adapter: adapter,
                    fallback: recoveryClassifier,
                    inference: inference.definition.identifier,
                    attemptIndex: attemptIndex,
                    invocationIndex: invocationIndex
                )

                invocations.append(
                    AgentInferenceInvocationRecord(
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
                        let recoveryRecord = AgentInferenceRecoveryError(
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

                    activeRecovery = AgentInferenceActiveRecovery(
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
                AgentInferenceInvocationRecord(
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

            let output: Inference.Output

            do {
                output = try adapter.decode(
                    inference,
                    response: result.response
                )
            } catch {
                let message = error.localizedDescription
                let incident = classifyAgentInferenceRecoveryIncident(
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
                        throw AgentInferenceRecoveryError(
                            record: recovery.record(
                                outcome: .failed
                            ),
                            message: message
                        )
                    }

                    guard let repairingAdapter = adapter as? any AgentInferenceOutputRepairing else {
                        throw AgentInferenceRecoveryError(
                            record: recovery.record(
                                outcome: .propagated
                            ),
                            message: message
                        )
                    }

                    adaptation = try repairingAdapter.repair(
                        inference,
                        input: input,
                        response: result.response,
                        error: error,
                        realization: realization
                    )
                    activeRecovery = recovery
                    continue
                }

                guard let incident else {
                    throw error
                }

                let plan = realization.recovery?.plan(
                    for: incident
                )

                guard
                    let plan,
                    let step = plan.steps.first,
                    step.action == .repair_output
                else {
                    throw AgentInferenceRecoveryError(
                        propagating: incident,
                        plan: plan,
                        message: message
                    )
                }

                guard let repairingAdapter =
                    adapter as? any AgentInferenceOutputRepairing
                else {
                    throw AgentInferenceRecoveryError(
                        propagating: incident,
                        plan: plan,
                        message: message
                    )
                }

                adaptation = try repairingAdapter.repair(
                    inference,
                    input: input,
                    response: result.response,
                    error: error,
                    realization: realization
                )
                activeRecovery = AgentInferenceActiveRecovery(
                    incident: incident,
                    plan: plan,
                    decision: Recovery.Decision(
                        step: step
                    ),
                    message: message
                )
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

            return AgentInferenceAttemptResult(
                output: output,
                record: AgentInferenceAttemptRecord(
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
