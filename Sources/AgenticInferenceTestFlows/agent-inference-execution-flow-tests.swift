import Agentic
import AgenticInference
import Foundation
import TestFlows

private struct FixtureInference: AgentInference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = AgentInferenceDefinition(
        identifier: "fixture.direct_execution",
        purpose: "Prove direct typed inference execution."
    )
}

private struct FixtureInferenceAdapter:
    AgentInferenceAdapter,
    Sendable
{
    let identifier: AgentInferenceAdapterIdentifier = "fixture_adapter"

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

    func decode<Inference: AgentInference>(
        _ inference: Inference.Type,
        response: AgentResponse
    ) throws -> Inference.Output {
        try JSONDecoder().decode(
            Inference.Output.self,
            from: Data(
                response.message.content.text.utf8
            )
        )
    }
}

private struct FixtureInferenceAdapterResolver:
    AgentInferenceAdapterResolving,
    Sendable
{
    let adapter = FixtureInferenceAdapter()

    func require(
        _ identifier: AgentInferenceAdapterIdentifier
    ) throws -> any AgentInferenceAdapter {
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

enum AgentInferenceExecutionFlowTests {
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
        let executor = AgentInferenceExecutor(
            modelInvoker: modelInvoker,
            adapters: FixtureInferenceAdapterResolver()
        )
        let realization = AgentInferenceRealization(
            strategy: .direct,
            modelSelection: .executor,
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
        try Expect.equal(
            result.record.attempts[0].route.route.profile.identifier.rawValue,
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
                result.record.attempts[0]
                    .route
                    .route
                    .profile
                    .identifier
                    .rawValue
            ),
        ]
    }
}
