import Agentic
import AgenticInference
import AgenticRecovery
import Foundation
import TestFlows

private struct TransportRecoveryFixtureInference: Inference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = InferenceDefinition(
        identifier: "fixture.transport_recovery",
        purpose: "Prove bounded transport recovery within one semantic inference attempt."
    )
}

private enum TransportRecoveryFixtureError:
    Error,
    Sendable,
    LocalizedError
{
    case transient
    case unknownAdapter(String)

    var errorDescription: String? {
        switch self {
        case .transient:
            "fixture transport failed transiently"

        case .unknownAdapter(let identifier):
            "unknown fixture adapter: \(identifier)"
        }
    }
}

private struct TransportRecoveryFixtureAdapter:
    InferenceAdapter,
    Sendable
{
    let identifier: InferenceAdapterIdentifier =
        "transport_recovery_fixture_adapter"

    func prepare<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration
    ) throws -> InferenceAdaptation {
        InferenceAdaptation(
            request: AgentRequest(
                messages: [
                    AgentMessage(
                        role: .user,
                        text: "transport recovery fixture request"
                    ),
                ],
                generationConfiguration: realization.generation
            )
        )
    }

    func decode<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        response: AgentResponse
    ) throws -> InferenceType.Output {
        try JSONDecoder().decode(
            InferenceType.Output.self,
            from: Data(
                response.message.content.text.utf8
            )
        )
    }
}

private struct TransportRecoveryFixtureAdapterResolver:
    InferenceAdapterResolving,
    Sendable
{
    let adapter = TransportRecoveryFixtureAdapter()

    func require(
        _ identifier: InferenceAdapterIdentifier
    ) throws -> any InferenceAdapter {
        guard identifier == adapter.identifier else {
            throw TransportRecoveryFixtureError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}

private actor TransportRecoveryFixtureState {
    private var count = 0

    func nextInvocationIndex() -> Int {
        let index = count
        count += 1
        return index
    }

    func invocationCount() -> Int {
        count
    }
}

private struct TransportRecoveryFixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let state: TransportRecoveryFixtureState
    let failureCount: Int

    init(
        state: TransportRecoveryFixtureState,
        failureCount: Int = 1
    ) {
        self.state = state
        self.failureCount = failureCount
    }

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        let index = await state.nextInvocationIndex()

        if index < failureCount {
            throw TransportRecoveryFixtureError.transient
        }

        let encoded = try JSONEncoder().encode(
            "RECOVERED"
        )
        let response = AgentResponse(
            message: AgentMessage(
                role: .assistant,
                text: String(
                    decoding: encoded,
                    as: UTF8.self
                )
            ),
            stopReason: .end_turn,
            usage: AgentUsage(
                inputTokens: 1,
                outputTokens: 1,
                totalTokens: 2
            )
        )
        let profile = AgentModelProfile(
            identifier: "transport_recovery_fixture_profile",
            gatewayIdentifier: "transport_recovery_fixture_gateway",
            model: "fixture",
            purposes: [
                invocation.selection.purpose,
            ],
            capabilities: [
                .text,
            ]
        )
        let route = AgentModelRoute(
            purpose: invocation.selection.purpose,
            profile: profile
        )

        return AgentModelInvocationResult(
            response: response,
            route: AgentModelRouteRecord(
                route: route,
                requestMetadata: invocation.metadata,
                responseMetadata: response.metadata
            )
        )
    }

    func stream(
        _ invocation: AgentModelInvocation
    ) -> AsyncThrowingStream<AgentModelInvocationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await buffered(
                        invocation
                    )
                    continuation.yield(
                        .completed(result)
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private struct TransportRecoveryFixtureClassifier:
    InferenceRecoveryClassifying,
    Sendable
{
    func incident(
        for error: any Error,
        stage: Recovery.Stage,
        inference: InferenceIdentifier,
        attemptIndex: Int,
        invocationIndex: Int
    ) -> Recovery.Incident? {
        guard error is TransportRecoveryFixtureError,
              stage == .execution
        else {
            return nil
        }

        return Recovery.Incident(
            kind: .transport_transient,
            stage: stage,
            effectState: Recovery.EffectState.none,
            retrySafety: .safe,
            scope: .init(
                kind: .inference,
                identifier: inference.rawValue
            ),
            message: error.localizedDescription,
            metadata: [
                "attempt": String(attemptIndex),
                "invocation": String(invocationIndex),
            ]
        )
    }
}

let inferenceTransportRecoveryFlows: [TestFlow] = [
    TestFlow(
        "inference-transport-recovery",
        tags: [
            "agentic-inference",
            "recovery",
            "transport",
            "retry",
        ]
    ) {
        let state = TransportRecoveryFixtureState()
        let executor = InferenceExecutor(
            modelInvoker: TransportRecoveryFixtureModelInvoker(
                state: state
            ),
            adapters: TransportRecoveryFixtureAdapterResolver(),
            defaultAdapterIdentifier: "transport_recovery_fixture_adapter",
            recoveryClassifier: TransportRecoveryFixtureClassifier()
        )
        let policy = Recovery.Policy(
            rules: [
                .init(
                    match: .init(
                        kind: .transport_transient,
                        stage: .execution,
                        scope: .inference,
                        effectState: Recovery.EffectState.none,
                        retrySafety: .safe
                    ),
                    plan: .init(
                        steps: [
                            .init(
                                action: .retry_same_operation,
                                limit: .once
                            ),
                            .init(
                                action: .propagate,
                                limit: .once
                            ),
                        ]
                    )
                ),
            ]
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return the fixture output.",
            budget: .singleAttempt,
            recovery: policy
        )

        let result = try await executor.execute(
            TransportRecoveryFixtureInference.self,
            input: .init(
                value: "fixture"
            ),
            realization: realization
        )
        let attempt = try Expect.notNil(
            result.record.attempts.first,
            "transport recovery still produces one semantic attempt"
        )
        let recovery = try Expect.notNil(
            attempt.recoveries.first,
            "successful mechanical retry is recorded"
        )

        try Expect.equal(
            result.output,
            "RECOVERED",
            "transport retry eventually returns the semantic inference output"
        )
        try Expect.equal(
            result.record.attempts.count,
            1,
            "mechanical recovery does not consume another semantic attempt"
        )
        try Expect.equal(
            attempt.invocations.count,
            2,
            "failed transport plus successful retry are two model invocations"
        )
        let firstFailure: InferenceInvocationOutcome.Failure?
        switch attempt.invocations[0].outcome {
        case .failed(let failure):
            firstFailure = failure

        case .succeeded:
            firstFailure = nil
        }

        let recordedFailure = try Expect.notNil(
            firstFailure,
            "failed transport invocation has an explicit failure outcome"
        )

        try Expect.equal(
            recordedFailure.incident?.kind,
            .transport_transient,
            "failed invocation retains its normalized recovery incident"
        )
        let incidentReport = try Expect.notNil(
            recordedFailure.incident?.report,
            "normalized transport incident retains structured error evidence"
        )

        try Expect.equal(
            incidentReport.presentation.message,
            recordedFailure.incident?.message,
            "captured transport report preserves the classified failure presentation"
        )

        let secondSucceeded: Bool
        switch attempt.invocations[1].outcome {
        case .succeeded:
            secondSucceeded = true

        case .failed:
            secondSucceeded = false
        }

        try Expect.equal(
            secondSucceeded,
            true,
            "recovered model invocation has an explicit success outcome"
        )
        try Expect.equal(
            recovery.outcome,
            .recovered,
            "recovery record reports successful recovery"
        )
        try Expect.equal(
            recovery.attempts.count,
            1,
            "one retry action was required"
        )
        try Expect.equal(
            recovery.attempts[0].action,
            .retry_same_operation,
            "policy selected retry_same_operation"
        )
        try Expect.equal(
            await state.invocationCount(),
            2,
            "model invoker was called exactly twice"
        )

        return [
            .field(
                "semantic_attempts",
                String(result.record.attempts.count)
            ),
            .field(
                "model_invocations",
                String(attempt.invocations.count)
            ),
            .field(
                "recovery_action",
                recovery.attempts[0].action.rawValue
            ),
            .field(
                "recovery_outcome",
                recovery.outcome.rawValue
            ),
            .field(
                "incident_report",
                String(recordedFailure.incident?.report != nil)
            ),
        ]
    },
    TestFlow(
        "inference-transport-recovery-error-evidence",
        tags: [
            "agentic-inference",
            "recovery",
            "transport",
            "errors",
            "evidence",
            "exhaustion",
        ]
    ) {
        let state = TransportRecoveryFixtureState()
        let executor = InferenceExecutor(
            modelInvoker: TransportRecoveryFixtureModelInvoker(
                state: state,
                failureCount: 2
            ),
            adapters: TransportRecoveryFixtureAdapterResolver(),
            defaultAdapterIdentifier: "transport_recovery_fixture_adapter",
            recoveryClassifier: TransportRecoveryFixtureClassifier()
        )
        let policy = Recovery.Policy(
            rules: [
                .init(
                    match: .init(
                        kind: .transport_transient,
                        stage: .execution,
                        scope: .inference,
                        effectState: Recovery.EffectState.none,
                        retrySafety: .safe
                    ),
                    plan: .init(
                        steps: [
                            .init(
                                action: .retry_same_operation,
                                limit: .once
                            ),
                            .init(
                                action: .propagate,
                                limit: .once
                            ),
                        ]
                    )
                ),
            ]
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return the fixture output.",
            budget: .singleAttempt,
            recovery: policy
        )

        let terminalFailure: InferenceExecutionFailure?

        do {
            _ = try await executor.execute(
                TransportRecoveryFixtureInference.self,
                input: .init(
                    value: "fixture"
                ),
                realization: realization
            )
            terminalFailure = nil
        } catch let error as InferenceExecutionFailure {
            terminalFailure = error
        } catch {
            throw error
        }

        let executionFailure = try Expect.notNil(
            terminalFailure,
            "exhausted transport recovery preserves the terminal inference execution"
        )
        let failure = try Expect.notNil(
            executionFailure.terminalAttempt,
            "transport exhaustion retains its exact terminal semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.attempts,
            [
                failure.record,
            ],
            "direct execution failure retains the exact terminal semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.failure,
            executionFailure.failure,
            "execution record durably preserves the terminal execution failure"
        )
        let record = try Expect.notNil(
            failure.recovery,
            "exhausted transport recovery remains attached to the failed attempt"
        )
        let incidentReport = try Expect.notNil(
            record.incident.report,
            "exhausted recovery retains the initial incident ErrorReport"
        )

        try Expect.equal(
            record.outcome,
            .exhausted,
            "bounded retry exhaustion is represented explicitly"
        )
        try Expect.equal(
            record.attempts.count,
            1,
            "one permitted retry produces one recorded recovery attempt"
        )
        try Expect.equal(
            record.attempts[0].status,
            .failed,
            "the exhausted retry remains a failed recovery attempt"
        )

        let attemptReport = try Expect.notNil(
            record.attempts[0].report,
            "failed retry retains the ErrorReport for the recovery-attempt failure"
        )

        try Expect.equal(
            attemptReport,
            incidentReport,
            "repeated equivalent transport failures retain equivalent structured evidence"
        )
        try Expect.equal(
            await state.invocationCount(),
            2,
            "exhaustion performs exactly the initial invocation and one bounded retry"
        )
        try Expect.equal(
            failure.record.invocations.count,
            2,
            "terminal attempt retains both model invocations already performed"
        )
        try Expect.equal(
            failure.record.recoveries.last?.outcome,
            .exhausted,
            "terminal attempt retains its exhausted mechanical recovery"
        )
        try Expect.equal(
            failure.failure.recovery,
            record,
            "terminal failure and attempt evidence reference the same recovery record"
        )

        return [
            .field(
                "outcome",
                record.outcome.rawValue
            ),
            .field(
                "recovery_attempts",
                String(record.attempts.count)
            ),
            .field(
                "incident_report",
                String(record.incident.report != nil)
            ),
            .field(
                "attempt_report",
                String(record.attempts[0].report != nil)
            ),
            .field(
                "model_invocations",
                String(await state.invocationCount())
            ),
            .field(
                "recorded_invocations",
                String(failure.record.invocations.count)
            ),
        ]
    },
    TestFlow(
        "inference-transport-classification-propagation",
        tags: [
            "agentic-inference",
            "recovery",
            "transport",
            "classification",
            "propagation",
        ]
    ) {
        let state = TransportRecoveryFixtureState()
        let executor = InferenceExecutor(
            modelInvoker: TransportRecoveryFixtureModelInvoker(
                state: state
            ),
            adapters: TransportRecoveryFixtureAdapterResolver(),
            defaultAdapterIdentifier:
                "transport_recovery_fixture_adapter",
            recoveryClassifier:
                TransportRecoveryFixtureClassifier()
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return the fixture output.",
            budget: .singleAttempt
        )

        let terminalFailure: InferenceExecutionFailure?

        do {
            _ = try await executor.execute(
                TransportRecoveryFixtureInference.self,
                input: .init(
                    value: "fixture"
                ),
                realization: realization
            )
            terminalFailure = nil
        } catch let error as InferenceExecutionFailure {
            terminalFailure = error
        } catch {
            throw error
        }

        let executionFailure = try Expect.notNil(
            terminalFailure,
            "classified transport propagation preserves the failed inference execution"
        )
        let failure = try Expect.notNil(
            executionFailure.terminalAttempt,
            "transport propagation retains its exact terminal semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.attempts,
            [
                failure.record,
            ],
            "direct execution failure retains the exact propagated semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.failure,
            executionFailure.failure,
            "propagated execution record durably preserves execution failure"
        )
        let record = try Expect.notNil(
            failure.recovery,
            "classified transport propagation remains attached to the failed attempt"
        )

        try Expect.equal(
            await state.invocationCount(),
            1,
            "classification without a recovery policy performs no mechanical retry"
        )
        try Expect.equal(
            record.incident.kind,
            .transport_transient,
            "propagated record preserves classified transport incident"
        )
        try Expect.equal(
            record.incident.stage,
            .execution,
            "propagated transport classification retains execution stage"
        )
        try Expect.equal(
            record.plan == nil,
            true,
            "classification without policy invents no recovery plan"
        )
        try Expect.equal(
            record.attempts.count,
            0,
            "classification without policy records no mechanical recovery attempts"
        )
        try Expect.equal(
            record.outcome,
            .propagated,
            "classified unresolved transport failure is explicitly propagated"
        )
        try Expect.equal(
            record.state.effect,
            .none,
            "propagated transport record preserves authoritative effect state"
        )
        try Expect.equal(
            record.state.retry,
            .safe,
            "propagated transport record preserves retry safety"
        )
        try Expect.equal(
            record.incident.report != nil,
            true,
            "propagated transport record retains structured error evidence"
        )
        try Expect.equal(
            failure.record.invocations.count,
            1,
            "propagated transport attempt preserves the failed outbound invocation"
        )
        try Expect.equal(
            failure.record.recoveries.last?.outcome,
            .propagated,
            "failed attempt retains the propagated recovery decision"
        )
        try Expect.equal(
            failure.failure.message,
            TransportRecoveryFixtureError.transient.localizedDescription,
            "canonical attempt failure preserves the underlying transport presentation"
        )

        return [
            .field(
                "outcome",
                record.outcome.rawValue
            ),
            .field(
                "kind",
                record.incident.kind.rawValue
            ),
            .field(
                "effect",
                record.state.effect.rawValue
            ),
            .field(
                "retry",
                record.state.retry.rawValue
            ),
            .field(
                "model_invocations",
                String(await state.invocationCount())
            ),
            .field(
                "recorded_invocations",
                String(failure.record.invocations.count)
            ),
        ]
    },
]
