import Agentic
import AgenticInference
import Foundation
import TestFlows

private struct FixtureInference: Inference {
    struct Input:
        SemanticInput
    {
        let value: String
    }

    typealias Output = String

    static let definition = InferenceDefinition(
        identifier: "fixture.direct_execution",
        purpose: "Prove direct typed inference execution."
    )
}

private struct FixtureInferenceAdapter:
    InferenceAdapter,
    Sendable
{
    let identifier: InferenceAdapterIdentifier = "fixture_adapter"

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
                        text: "fixture request"
                    ),
                ],
                generationConfiguration: realization.generation,
                metadata: [
                    "fixture": inference.definition.identifier.rawValue,
                ]
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
        try JSONDecoder().decode(
            InferenceType.Output.self,
            from: Data(
                response.message.content.text.utf8
            )
        )
    }
}

private struct FixtureInferenceAdapterResolver:
    InferenceAdapterResolving,
    Sendable
{
    let adapter = FixtureInferenceAdapter()

    func require(
        _ identifier: InferenceAdapterIdentifier
    ) throws -> any InferenceAdapter {
        guard identifier == adapter.identifier else {
            throw FixtureInferenceExecutionError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}

private actor FixtureInvocationRecorder {
    private var invocations: [AgentModelInvocation] = []

    func append(
        _ invocation: AgentModelInvocation
    ) {
        invocations.append(
            invocation
        )
    }

    func snapshot() -> [AgentModelInvocation] {
        invocations
    }
}

private struct FixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let recorder: FixtureInvocationRecorder
    let response: AgentResponse

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        await recorder.append(
            invocation
        )

        let profile = AgentModelProfile(
            identifier: "fixture_profile",
            gatewayIdentifier: "fixture_gateway",
            model: "fixture",
            purposes: [
                invocation.selection.purpose,
            ],
            capabilities: [
                .text,
                .structured_output,
                .reasoning,
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
                responseMetadata: response.metadata,
                usage: response.usage
            )
        )
    }

    func stream(
        _ invocation: AgentModelInvocation
    ) -> AsyncThrowingStream<AgentModelInvocationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(
                throwing: FixtureInferenceExecutionError.streamingUnsupported
            )
        }
    }
}

private enum FixtureInferenceExecutionError:
    Error,
    Sendable
{
    case unknownAdapter(String)
    case streamingUnsupported
}

enum InferenceExecutionFlowTests {
    static func runNativeReasoning()
        async throws
        -> [TestFlowDiagnostic]
    {
        let recorder = FixtureInvocationRecorder()
        let modelInvoker = FixtureModelInvoker(
            recorder: recorder,
            response: AgentResponse(
                message: AgentMessage(
                    role: .assistant,
                    text: "\"REASONED\""
                ),
                stopReason: .end_turn,
                usage: AgentUsage(
                    inputTokens: 4,
                    outputTokens: 3,
                    totalTokens: 7
                ),
                metadata: [
                    "fixture_response": "reasoning",
                ]
            )
        )
        let executor = InferenceExecutor(
            modelInvoker: modelInvoker,
            adapters: FixtureInferenceAdapterResolver()
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .native_reasoning,
            instructions: "Use native reasoning and return the fixture output.",
            budget: .singleAttempt,
            adapter: "fixture_adapter"
        )

        let result = try await executor.execute(
            FixtureInference.self,
            input: FixtureInference.Input(
                value: "reason"
            ),
            realization: realization
        )
        let invocations = await recorder.snapshot()

        try Expect.equal(
            result.output,
            "REASONED",
            "native reasoning strategy restores typed inference output"
        )
        try Expect.equal(
            result.record.strategy,
            .native_reasoning,
            "execution record retains native reasoning strategy"
        )
        try Expect.equal(
            result.record.attempts.count,
            1,
            "native reasoning strategy performs exactly one attempt"
        )
        try Expect.equal(
            invocations.count,
            1,
            "native reasoning strategy reaches model invoker once"
        )
        try Expect.equal(
            invocations[0].selection.requirements.capabilities.contains(
                .reasoning
            ),
            true,
            "native reasoning strategy adds reasoning capability requirement"
        )
        try Expect.equal(
            invocations[0].selection.requirements.capabilities.contains(
                .structured_output
            ),
            true,
            "native reasoning retains adapter capability requirements"
        )
        try Expect.equal(
            invocations[0].metadata["inference.strategy"],
            "native_reasoning",
            "model invocation carries native reasoning strategy metadata"
        )
        try Expect.equal(
            result.record.attempts[0].usage?.totalTokens,
            7,
            "native reasoning attempt records model usage"
        )

        return [
            .field(
                "output",
                result.output
            ),
            .field(
                "strategy",
                result.record.strategy.rawValue
            ),
            .field(
                "attempts",
                String(result.record.attempts.count)
            ),
            .field(
                "model_invocations",
                String(invocations.count)
            ),
            .field(
                "reasoning_required",
                String(
                    invocations[0]
                        .selection
                        .requirements
                        .capabilities
                        .contains(
                            .reasoning
                        )
                )
            ),
        ]
    }

    static func runDirect()
        async throws
        -> [TestFlowDiagnostic]
    {
        let recorder = FixtureInvocationRecorder()
        let modelInvoker = FixtureModelInvoker(
            recorder: recorder,
            response: AgentResponse(
                message: AgentMessage(
                    role: .assistant,
                    text: "\"DONE\""
                ),
                stopReason: .end_turn,
                usage: AgentUsage(
                    inputTokens: 3,
                    outputTokens: 2,
                    totalTokens: 5
                ),
                metadata: [
                    "fixture_response": "true",
                ]
            )
        )
        let executor = InferenceExecutor(
            modelInvoker: modelInvoker,
            adapters: FixtureInferenceAdapterResolver()
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return the fixture output.",
            budget: .singleAttempt,
            adapter: "fixture_adapter"
        )

        let result = try await executor.execute(
            FixtureInference.self,
            input: FixtureInference.Input(
                value: "hello"
            ),
            realization: realization
        )
        let invocations = await recorder.snapshot()

        try Expect.equal(
            result.output,
            "DONE",
            "direct strategy restores typed inference output"
        )
        try Expect.equal(
            result.record.inference,
            FixtureInference.definition.identifier,
            "execution record retains inference identifier"
        )
        try Expect.equal(
            result.record.strategy,
            .direct,
            "execution record retains resolved strategy"
        )
        try Expect.equal(
            result.record.attempts.count,
            1,
            "direct strategy performs exactly one attempt"
        )
        try Expect.equal(
            result.record.attempts[0].adapter.rawValue,
            "fixture_adapter",
            "attempt records resolved inference adapter"
        )
        let attemptRoute = try Expect.notNil(
            result.record.attempts[0].route,
            "successful inference attempt preserves its routed model"
        )

        try Expect.equal(
            attemptRoute.route.profile.identifier.rawValue,
            "fixture_profile",
            "attempt records exact routed model profile"
        )
        try Expect.equal(
            result.record.attempts[0].usage?.totalTokens,
            5,
            "attempt records model usage"
        )
        try Expect.equal(
            invocations.count,
            1,
            "direct strategy reaches model invoker once"
        )
        try Expect.equal(
            invocations[0].selection.requirements.capabilities.contains(
                .structured_output
            ),
            true,
            "attempt execution merges adapter requirements into model selection"
        )
        try Expect.equal(
            invocations[0].metadata["inference.strategy"],
            "direct",
            "model invocation carries inference strategy metadata"
        )

        return [
            .field(
                "output",
                result.output
            ),
            .field(
                "strategy",
                result.record.strategy.rawValue
            ),
            .field(
                "attempts",
                String(result.record.attempts.count)
            ),
            .field(
                "model_invocations",
                String(invocations.count)
            ),
            .field(
                "route",
                attemptRoute
                    .route
                    .profile
                    .identifier
                    .rawValue
            ),
        ]
    }
}
