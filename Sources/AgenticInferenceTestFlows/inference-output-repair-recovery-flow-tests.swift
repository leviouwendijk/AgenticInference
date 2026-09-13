import Agentic
import AgenticInference
import AgenticRecovery
import Foundation
import TestFlows

private struct OutputRepairFixtureInference: AgentInference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = AgentInferenceDefinition(
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
    AgentInferenceAdapter,
    AgentInferenceOutputRepairing,
    Sendable
{
    let identifier: AgentInferenceAdapterIdentifier =
        "output_repair_fixture_adapter"

    func prepare<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization
    ) throws -> AgentInferenceAdaptation {
        AgentInferenceAdaptation(
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

    func decode<Inference: AgentInference>(
        _ inference: Inference.Type,
        response: AgentResponse
    ) throws -> Inference.Output {
        do {
            return try JSONDecoder().decode(
                Inference.Output.self,
                from: Data(
                    response.message.content.text.utf8
                )
            )
        } catch {
            throw OutputRepairFixtureError.invalidStructuredOutput
        }
    }

    func repair<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        response: AgentResponse,
        error: any Error,
        realization: AgentInferenceRealization
    ) throws -> AgentInferenceAdaptation {
        AgentInferenceAdaptation(
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
    AgentInferenceAdapterResolving,
    Sendable
{
    let adapter = OutputRepairFixtureAdapter()

    func require(
        _ identifier: AgentInferenceAdapterIdentifier
    ) throws -> any AgentInferenceAdapter {
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
    AgentInferenceRecoveryClassifying,
    Sendable
{
    func incident(
        for error: any Error,
        stage: Recovery.Stage,
        inference: AgentInferenceIdentifier,
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

let agentInferenceOutputRepairRecoveryFlows: [TestFlow] = [
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
        let executor = AgentInferenceExecutor(
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
        let realization = AgentInferenceRealization(
            strategy: .direct,
            modelSelection: .executor,
            instructions: "Return the fixture output.",
            budget: .singleAttempt,
            recovery: policy
        )

        let result = try await executor.execute(
            OutputRepairFixtureInference.self,
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
]
