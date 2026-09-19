import Agentic
import AgenticInference
import Macros
import Schema
import AgenticRecovery
import Foundation
import TestFlows

private struct OutputRepairFixtureInference: Inference {
    @JSONSchema
    struct Input:
        Source
    {
        let value: String
    }

    typealias Output = String

    static let definition = InferenceDefinition(
        identifier: "fixture.output_repair",
        purpose: "Prove structured-output repair within one semantic inference attempt."
    )
}

private enum OutputRepairFixtureError:
    Error,
    Sendable,
    LocalizedError
{
    case invalidStructuredOutput
    case unknownAdapter(String)

    var errorDescription: String? {
        switch self {
        case .invalidStructuredOutput:
            "fixture response is not valid structured output"

        case .unknownAdapter(let identifier):
            "unknown fixture adapter: \(identifier)"
        }
    }
}

private struct OutputRepairFixtureAdapter:
    InferenceAdapter,
    InferenceOutputRepairing,
    Sendable
{
    let identifier: InferenceAdapterIdentifier =
        "output_repair_fixture_adapter"

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
                        text: "initial structured-output fixture request"
                    ),
                ],
                generationConfiguration: realization.generation
            ),
            requirements: AgentModelRequirements(
                capabilities: [
                    .structured_output,
                ]
            )
        )
    }

    func decode<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        response: AgentResponse
    ) throws -> InferenceType.Output {
        do {
            return try JSONDecoder().decode(
                InferenceType.Output.self,
                from: Data(
                    response.message.content.text.utf8
                )
            )
        } catch {
            throw OutputRepairFixtureError.invalidStructuredOutput
        }
    }

    func repair<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        response: AgentResponse,
        error: any Error,
        realization: InferenceRealizationConfiguration
    ) throws -> InferenceAdaptation {
        InferenceAdaptation(
            request: AgentRequest(
                messages: [
                    AgentMessage(
                        role: .assistant,
                        text: response.message.content.text
                    ),
                    AgentMessage(
                        role: .user,
                        text: "repair structured output: \(error.localizedDescription)"
                    ),
                ],
                generationConfiguration: realization.generation
            ),
            requirements: AgentModelRequirements(
                capabilities: [
                    .structured_output,
                ]
            )
        )
    }
}

private struct OutputRepairFixtureAdapterResolver:
    InferenceAdapterResolving,
    Sendable
{
    let adapter = OutputRepairFixtureAdapter()

    func require(
        _ identifier: InferenceAdapterIdentifier
    ) throws -> any InferenceAdapter {
        guard identifier == adapter.identifier else {
            throw OutputRepairFixtureError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}

private actor OutputRepairFixtureState {
    private var count = 0
    private var repairRequestSeen = false

    func record(
        invocation: AgentModelInvocation
    ) -> Int {
        let index = count
        count += 1

        if invocation.request.messages.contains(
            where: {
                $0.content.text.contains(
                    "repair structured output"
                )
            }
        ) {
            repairRequestSeen = true
        }

        return index
    }

    func invocationCount() -> Int {
        count
    }

    func sawRepairRequest() -> Bool {
        repairRequestSeen
    }
}

private struct OutputRepairFixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let state: OutputRepairFixtureState

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        let index = await state.record(
            invocation: invocation
        )

        let text: String

        if index == 0 {
            text = "not-json"
        } else {
            text = String(
                decoding: try JSONEncoder().encode(
                    "REPAIRED"
                ),
                as: UTF8.self
            )
        }

        let response = AgentResponse(
            message: AgentMessage(
                role: .assistant,
                text: text
            ),
            stopReason: .end_turn,
            usage: AgentUsage(
                inputTokens: 1,
                outputTokens: 1,
                totalTokens: 2
            )
        )
        let profile = AgentModelProfile(
            identifier: "output_repair_fixture_profile",
            gatewayIdentifier: "output_repair_fixture_gateway",
            model: "fixture",
            purposes: [
                invocation.selection.purpose,
            ],
            capabilities: [
                .text,
                .structured_output,
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

private struct OutputRepairFixtureClassifier:
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
        guard error is OutputRepairFixtureError,
              stage == .decoding
        else {
            return nil
        }

        return Recovery.Incident(
            kind: .structured_output_invalid,
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

let inferenceOutputRepairRecoveryFlows: [TestFlow] = [
    TestFlow(
        "inference-output-repair-recovery",
        tags: [
            "agentic-inference",
            "recovery",
            "structured-output",
            "decoding",
            "repair",
        ]
    ) {
        let state = OutputRepairFixtureState()
        let executor = InferenceExecutor(
            modelInvoker: OutputRepairFixtureModelInvoker(
                state: state
            ),
            adapters: OutputRepairFixtureAdapterResolver(),
            defaultAdapterIdentifier: "output_repair_fixture_adapter",
            recoveryClassifier: OutputRepairFixtureClassifier()
        )
        let policy = Recovery.Policy(
            rules: [
                .init(
                    match: .init(
                        kind: .structured_output_invalid,
                        stage: .decoding,
                        scope: .inference,
                        effectState: Recovery.EffectState.none,
                        retrySafety: .safe
                    ),
                    plan: .init(
                        steps: [
                            .init(
                                action: .repair_output,
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

        let result = try await OutputRepairFixtureInference.execute(
            using: executor,
            input: .init(
                value: "fixture"
            ),
            realization: realization
        )
        let attempt = try Expect.notNil(
            result.record.attempts.first,
            "output repair remains inside one semantic inference attempt"
        )
        let recovery = try Expect.notNil(
            attempt.recoveries.first,
            "successful output repair is recorded"
        )

        try Expect.equal(
            result.output,
            "REPAIRED",
            "repair invocation restores the typed inference output"
        )
        try Expect.equal(
            result.record.attempts.count,
            1,
            "output repair does not consume another semantic attempt"
        )
        try Expect.equal(
            attempt.invocations.count,
            2,
            "malformed response and repair response are two provider invocations"
        )

        let firstSucceeded: Bool
        switch attempt.invocations[0].outcome {
        case .succeeded:
            firstSucceeded = true

        case .failed:
            firstSucceeded = false
        }

        try Expect.equal(
            firstSucceeded,
            true,
            "provider invocation remains successful when failure occurs during decoding"
        )
        try Expect.equal(
            attempt.invocations[0].usage?.totalTokens,
            2,
            "malformed provider response retains its reported usage"
        )
        try Expect.equal(
            result.record.budgetUsage.invocationCount,
            2,
            "budget accounting includes the malformed response and repair invocation"
        )
        try Expect.equal(
            result.record.budgetUsage.totalTokens,
            4,
            "token accounting includes both successful provider invocations"
        )
        try Expect.equal(
            recovery.incident.kind,
            .structured_output_invalid,
            "decode failure is normalized as structured_output_invalid"
        )
        try Expect.equal(
            recovery.incident.stage,
            .decoding,
            "structured-output failure retains decoding stage"
        )
        let decodeReport = try Expect.notNil(
            recovery.incident.report,
            "structured-output incident retains the captured decode ErrorReport"
        )

        try Expect.equal(
            decodeReport.presentation.message,
            recovery.incident.message,
            "decode ErrorReport preserves the normalized incident presentation"
        )
        try Expect.equal(
            recovery.attempts.count,
            1,
            "one bounded repair attempt was required"
        )
        try Expect.equal(
            recovery.attempts[0].action,
            .repair_output,
            "policy selected repair_output rather than retry_same_operation"
        )
        try Expect.equal(
            recovery.outcome,
            .recovered,
            "repair recovery record reports success"
        )
        try Expect.equal(
            await state.invocationCount(),
            2,
            "model invoker was called exactly twice"
        )
        try Expect.equal(
            await state.sawRepairRequest(),
            true,
            "second invocation uses adapter-authored repair adaptation rather than blindly repeating the original request"
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
                "reported_tokens",
                String(result.record.budgetUsage.totalTokens ?? 0)
            ),
        ]
    },
    TestFlow(
        "inference-output-classification-propagation",
        tags: [
            "agentic-inference",
            "recovery",
            "structured-output",
            "decoding",
            "classification",
            "propagation",
            "evidence",
        ]
    ) {
        let state = OutputRepairFixtureState()
        let executor = InferenceExecutor(
            modelInvoker: OutputRepairFixtureModelInvoker(
                state: state
            ),
            adapters: OutputRepairFixtureAdapterResolver(),
            defaultAdapterIdentifier:
                "output_repair_fixture_adapter",
            recoveryClassifier:
                OutputRepairFixtureClassifier()
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return the fixture output.",
            budget: .singleAttempt
        )

        let terminalFailure: InferenceExecutionFailure?

        do {
            _ = try await OutputRepairFixtureInference.execute(
                using: executor,
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
            "classified decoding propagation preserves the failed inference execution"
        )
        let failure = try Expect.notNil(
            executionFailure.terminalAttempt,
            "decoding propagation retains its exact terminal semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.attempts,
            [
                failure.record,
            ],
            "direct execution failure retains the exact decoding semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.failure,
            executionFailure.failure,
            "decoding execution record durably preserves execution failure"
        )
        let record = try Expect.notNil(
            failure.recovery,
            "classified decoding propagation remains attached to the failed attempt"
        )
        let invocation = try Expect.notNil(
            failure.record.invocations.first,
            "failed decoding attempt retains the provider invocation that produced the malformed response"
        )
        let budgetUsage = InferenceBudgetUsage(
            attempts: [failure.record]
        )

        try Expect.equal(
            await state.invocationCount(),
            1,
            "classification without repair policy performs no second model invocation"
        )
        try Expect.equal(
            await state.sawRepairRequest(),
            false,
            "classification alone never manufactures an output-repair attempt"
        )
        try Expect.equal(
            record.incident.kind,
            .structured_output_invalid,
            "propagated record preserves the structured-output classification"
        )
        try Expect.equal(
            record.incident.stage,
            .decoding,
            "propagated structured-output failure retains decoding stage"
        )
        try Expect.equal(
            record.plan == nil,
            true,
            "classification without policy invents no repair plan"
        )
        try Expect.equal(
            record.attempts.count,
            0,
            "classification without policy records no repair attempts"
        )
        try Expect.equal(
            record.outcome,
            .propagated,
            "classified unresolved decoding failure is explicitly propagated"
        )
        try Expect.equal(
            record.state.effect,
            .none,
            "propagated decoding record preserves authoritative effect state"
        )
        try Expect.equal(
            record.state.retry,
            .safe,
            "propagated decoding record preserves retry safety"
        )
        try Expect.equal(
            record.incident.report != nil,
            true,
            "propagated decoding record retains structured error evidence"
        )
        try Expect.equal(
            failure.record.invocations.count,
            1,
            "failed semantic attempt retains exactly the provider call already performed"
        )
        try Expect.equal(
            invocation.usage?.totalTokens,
            2,
            "failed semantic attempt preserves token usage from the successful provider response"
        )
        try Expect.equal(
            budgetUsage.invocationCount,
            1,
            "budget accounting counts provider work inside a failed semantic attempt"
        )
        try Expect.equal(
            budgetUsage.totalTokens,
            2,
            "budget accounting retains token spend even though decoding later failed"
        )
        try Expect.equal(
            failure.record.route == nil,
            true,
            "failed semantic attempt does not masquerade as a successful routed attempt"
        )
        try Expect.equal(
            failure.record.usage == nil,
            true,
            "failed semantic attempt exposes no top-level success usage while nested invocation usage remains authoritative"
        )
        try Expect.equal(
            failure.record.recoveries.last?.outcome,
            .propagated,
            "failed semantic attempt retains the propagated recovery decision"
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
                "stage",
                record.incident.stage.rawValue
            ),
            .field(
                "model_invocations",
                String(await state.invocationCount())
            ),
            .field(
                "recorded_invocations",
                String(failure.record.invocations.count)
            ),
            .field(
                "recorded_tokens",
                String(budgetUsage.totalTokens ?? 0)
            ),
        ]
    },
    TestFlow(
        "inference-output-repair-budget-failure-evidence",
        tags: [
            "agentic-inference",
            "recovery",
            "structured-output",
            "decoding",
            "repair",
            "budget",
            "evidence",
        ]
    ) {
        let state = OutputRepairFixtureState()
        let executor = InferenceExecutor(
            modelInvoker: OutputRepairFixtureModelInvoker(
                state: state
            ),
            adapters: OutputRepairFixtureAdapterResolver(),
            defaultAdapterIdentifier:
                "output_repair_fixture_adapter",
            recoveryClassifier:
                OutputRepairFixtureClassifier()
        )
        let policy = Recovery.Policy(
            rules: [
                .init(
                    match: .init(
                        kind: .structured_output_invalid,
                        stage: .decoding,
                        scope: .inference,
                        effectState: Recovery.EffectState.none,
                        retrySafety: .safe
                    ),
                    plan: .init(
                        steps: [
                            .init(
                                action: .repair_output,
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
        let budget = try InferenceBudget(
            maximumAttempts: 1,
            maximumTotalTokens: 2
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return the fixture output.",
            budget: budget,
            recovery: policy
        )

        let terminalFailure: InferenceExecutionFailure?

        do {
            _ = try await OutputRepairFixtureInference.execute(
                using: executor,
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
            "repair blocked by token budget preserves the failed inference execution"
        )
        let failure = try Expect.notNil(
            executionFailure.terminalAttempt,
            "budget-blocked repair retains its exact terminal semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.attempts,
            [
                failure.record,
            ],
            "budget-blocked execution retains the exact paid semantic attempt"
        )
        try Expect.equal(
            executionFailure.record.failure,
            executionFailure.failure,
            "budget-blocked execution record durably preserves execution failure"
        )
        let recovery = try Expect.notNil(
            failure.recovery,
            "budget-blocked repair retains the decoding recovery context"
        )
        let invocation = try Expect.notNil(
            failure.record.invocations.first,
            "budget-blocked repair retains the malformed provider response invocation"
        )
        let budgetUsage = InferenceBudgetUsage(
            attempts: [failure.record]
        )

        try Expect.equal(
            await state.invocationCount(),
            1,
            "token budget prevents a second provider invocation"
        )
        try Expect.equal(
            await state.sawRepairRequest(),
            false,
            "repair adaptation is never sent after the invocation budget refuses it"
        )
        try Expect.equal(
            recovery.incident.kind,
            .structured_output_invalid,
            "budget failure does not erase the decoding incident that motivated repair"
        )
        try Expect.equal(
            recovery.incident.stage,
            .decoding,
            "budget failure retains decoding as the recovery incident stage"
        )
        try Expect.equal(
            recovery.outcome,
            .failed,
            "mechanical repair is recorded as failed when the global inference budget prevents its provider call"
        )
        try Expect.equal(
            recovery.attempts.count,
            0,
            "budget refusal before the repair provider call does not invent a recovery attempt"
        )
        try Expect.equal(
            failure.record.invocations.count,
            1,
            "failed attempt retains only the provider invocation actually performed"
        )
        try Expect.equal(
            invocation.usage?.totalTokens,
            2,
            "already-paid malformed response preserves its reported token usage"
        )
        try Expect.equal(
            budgetUsage.invocationCount,
            1,
            "failed-attempt budget usage counts exactly the provider invocation that escaped"
        )
        try Expect.equal(
            budgetUsage.totalTokens,
            2,
            "failed-attempt budget usage preserves the exact spend that caused the token ceiling"
        )
        try Expect.equal(
            failure.record.route == nil,
            true,
            "budget-blocked failed attempt remains semantically failed rather than exposing a success route"
        )
        try Expect.equal(
            failure.record.usage == nil,
            true,
            "budget-blocked failed attempt keeps cost evidence at invocation granularity"
        )
        try Expect.equal(
            failure.record.recoveries.last?.outcome,
            .failed,
            "failed attempt retains the recovery failure caused by the budget boundary"
        )

        return [
            .field(
                "recovery_outcome",
                recovery.outcome.rawValue
            ),
            .field(
                "model_invocations",
                String(await state.invocationCount())
            ),
            .field(
                "recorded_invocations",
                String(failure.record.invocations.count)
            ),
            .field(
                "recorded_tokens",
                String(budgetUsage.totalTokens ?? 0)
            ),
        ]
    },
]
