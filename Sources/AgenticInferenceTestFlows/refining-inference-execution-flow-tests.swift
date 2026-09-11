import Agentic
import AgenticInference
import Foundation
import TestFlows

private struct RefiningFixtureInference: AgentInference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = AgentInferenceDefinition(
        identifier: "fixture.refining_execution",
        purpose: "Prove iterative typed inference refinement."
    )
}

private struct RefiningFixtureAdapter:
    AgentInferenceAdapter,
    Sendable
{
    let identifier: AgentInferenceAdapterIdentifier =
        "refining_fixture_adapter"

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
                        text: "refining fixture request"
                    ),
                ],
                generationConfiguration: realization.generation,
                metadata: [
                    "fixture.instructions": realization.instructions,
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

private struct RefiningFixtureAdapterResolver:
    AgentInferenceAdapterResolving,
    Sendable
{
    let adapter = RefiningFixtureAdapter()

    func require(
        _ identifier: AgentInferenceAdapterIdentifier
    ) throws -> any AgentInferenceAdapter {
        guard identifier == adapter.identifier else {
            throw RefiningFixtureError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}

private actor RefiningFixtureState {
    private var outputs: [String]
    private var instructions: [String] = []

    init(
        outputs: [String]
    ) {
        self.outputs = outputs
    }

    func nextOutput(
        instructions currentInstructions: String
    ) throws -> String {
        guard !outputs.isEmpty else {
            throw RefiningFixtureError.responsesExhausted
        }

        instructions.append(
            currentInstructions
        )

        return outputs.removeFirst()
    }

    func observedInstructions() -> [String] {
        instructions
    }
}

private struct RefiningFixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let state: RefiningFixtureState

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        let output = try await state.nextOutput(
            instructions: invocation.request.metadata[
                "fixture.instructions"
            ] ?? ""
        )
        let encodedOutput = try JSONEncoder().encode(
            output
        )
        let response = AgentResponse(
            message: AgentMessage(
                role: .assistant,
                text: String(
                    decoding: encodedOutput,
                    as: UTF8.self
                )
            ),
            stopReason: .end_turn,
            usage: AgentUsage(
                inputTokens: 1,
                outputTokens: 1,
                totalTokens: 2
            ),
            metadata: [
                "fixture_output": output,
            ]
        )
        let profile = AgentModelProfile(
            identifier: "refining_fixture_profile",
            gatewayIdentifier: "refining_fixture_gateway",
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
                throwing: RefiningFixtureError.streamingUnsupported
            )
        }
    }
}

private struct RefiningFixtureGuide:
    AgentInferenceRefinementGuiding,
    Sendable
{
    let identifier: AgentInferenceRefinementGuideIdentifier =
        "fixture_refinement"

    func guide<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        output: Inference.Output,
        attempt: AgentInferenceAttemptRecord,
        realization: AgentInferenceRealization
    ) async throws -> AgentInferenceRefinementDecision {
        let data = try JSONEncoder().encode(
            output
        )
        let value = try JSONDecoder().decode(
            String.self,
            from: data
        )

        switch value {
        case "ROUGH":
            return AgentInferenceRefinementDecision(
                evaluation: AgentInferenceCandidateScore(
                    score: 0.2,
                    metadata: [
                        "value": value,
                    ]
                ),
                shouldContinue: true,
                nextInstructions: "Improve the ROUGH candidate into a BETTER candidate."
            )

        case "BETTER":
            return AgentInferenceRefinementDecision(
                evaluation: AgentInferenceCandidateScore(
                    score: 0.7,
                    metadata: [
                        "value": value,
                    ]
                ),
                shouldContinue: true,
                nextInstructions: "Improve the BETTER candidate into the FINAL candidate."
            )

        case "FINAL":
            return AgentInferenceRefinementDecision(
                evaluation: AgentInferenceCandidateScore(
                    score: 1.0,
                    metadata: [
                        "value": value,
                    ]
                ),
                shouldContinue: false
            )

        default:
            throw RefiningFixtureError.unexpectedOutput(
                value
            )
        }
    }
}

private enum RefiningFixtureError:
    Error,
    Sendable
{
    case unknownAdapter(String)
    case responsesExhausted
    case unexpectedOutput(String)
    case streamingUnsupported
}

extension AgentInferenceExecutionFlowTests {
    static func runRefining()
        async throws
        -> [TestFlowDiagnostic]
    {
        let state = RefiningFixtureState(
            outputs: [
                "ROUGH",
                "BETTER",
                "FINAL",
            ]
        )
        let guide = RefiningFixtureGuide()
        let executor = AgentInferenceExecutor(
            modelInvoker: RefiningFixtureModelInvoker(
                state: state
            ),
            adapters: RefiningFixtureAdapterResolver(),
            refinementGuide: guide
        )
        let realization = AgentInferenceRealization(
            strategy: .refining,
            modelSelection: .executor,
            instructions: "Produce the initial candidate.",
            budget: AgentInferenceBudget(
                maximumAttempts: 4
            ),
            adapter: "refining_fixture_adapter"
        )

        let result = try await executor.execute(
            RefiningFixtureInference.self,
            input: RefiningFixtureInference.Input(
                value: "refine"
            ),
            realization: realization
        )
        let observedInstructions = await state
            .observedInstructions()

        try Expect.equal(
            result.output,
            "FINAL",
            "refining inference returns the highest-scoring refined candidate"
        )
        try Expect.equal(
            result.record.strategy,
            .refining,
            "refining inference records refining strategy"
        )
        try Expect.equal(
            result.record.attempts.count,
            3,
            "refining inference performs bounded iterative attempts until the guide stops"
        )
        try Expect.equal(
            result.record.budgetUsage.totalTokens,
            6,
            "refining inference aggregates token usage across iterations"
        )
        try Expect.equal(
            result.record.refinement?.guide,
            guide.identifier,
            "refinement record preserves guide identity"
        )
        try Expect.equal(
            result.record.refinement?.steps.count,
            3,
            "refinement record preserves one typed decision per completed candidate"
        )
        try Expect.equal(
            result.record.refinement?.selectedAttemptIndex,
            2,
            "refinement record identifies the highest-scoring candidate"
        )
        try Expect.equal(
            result.record.refinement?.lastAttemptIndex,
            2,
            "refinement record preserves the final executed attempt"
        )
        try Expect.equal(
            result.record.refinement?.termination,
            .guide_stop,
            "refinement terminates when the guide accepts the candidate"
        )
        try Expect.equal(
            observedInstructions.joined(
                separator: "|"
            ),
            "Produce the initial candidate.|Improve the ROUGH candidate into a BETTER candidate.|Improve the BETTER candidate into the FINAL candidate.",
            "refinement guide deterministically supplies the instructions for each subsequent attempt"
        )

        let encodedRecord = try JSONEncoder().encode(
            result.record
        )
        let decodedRecord = try JSONDecoder().decode(
            AgentInferenceExecutionRecord.self,
            from: encodedRecord
        )

        try Expect.equal(
            decodedRecord,
            result.record,
            "refining execution provenance survives durable codec round trip"
        )

        return [
            .field(
                "output",
                result.output
            ),
            .field(
                "attempts",
                String(result.record.attempts.count)
            ),
            .field(
                "guide",
                guide.identifier.rawValue
            ),
            .field(
                "selected_attempt",
                String(
                    result.record.refinement?
                        .selectedAttemptIndex
                        ?? -1
                )
            ),
            .field(
                "termination",
                result.record.refinement?
                    .termination
                    .rawValue
                    ?? "missing"
            ),
        ]
    }
}
