import Agentic
import AgenticInference
import Foundation
import TestFlows

private struct SampledFixtureInference: AgentInference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = AgentInferenceDefinition(
        identifier: "fixture.sampled_execution",
        purpose: "Prove sampled inference candidate generation and evaluation."
    )
}

private struct SampledFixtureAdapter:
    AgentInferenceAdapter,
    Sendable
{
    let identifier: AgentInferenceAdapterIdentifier =
        "sampled_fixture_adapter"

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
                        text: "sampled fixture request"
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
        try JSONDecoder().decode(
            Inference.Output.self,
            from: Data(
                response.message.content.text.utf8
            )
        )
    }
}

private struct SampledFixtureAdapterResolver:
    AgentInferenceAdapterResolving,
    Sendable
{
    let adapter = SampledFixtureAdapter()

    func require(
        _ identifier: AgentInferenceAdapterIdentifier
    ) throws -> any AgentInferenceAdapter {
        guard identifier == adapter.identifier else {
            throw SampledFixtureError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}

private actor SampledFixtureState {
    private var outputs: [String]
    private var invocationCount = 0

    init(
        outputs: [String]
    ) {
        self.outputs = outputs
    }

    func nextOutput() throws -> String {
        guard !outputs.isEmpty else {
            throw SampledFixtureError.responsesExhausted
        }

        invocationCount += 1
        return outputs.removeFirst()
    }

    func count() -> Int {
        invocationCount
    }
}

private struct SampledFixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let state: SampledFixtureState

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        let output = try await state.nextOutput()
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
            identifier: "sampled_fixture_profile",
            gatewayIdentifier: "sampled_fixture_gateway",
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
                throwing: SampledFixtureError.streamingUnsupported
            )
        }
    }
}

private struct SampledFixtureEvaluator:
    AgentInferenceCandidateEvaluating,
    Sendable
{
    let identifier: AgentInferenceEvaluatorIdentifier =
        "fixture_quality"

    func evaluate<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        output: Inference.Output,
        attempt: AgentInferenceAttemptRecord
    ) async throws -> AgentInferenceCandidateScore {
        let data = try JSONEncoder().encode(
            output
        )
        let value = try JSONDecoder().decode(
            String.self,
            from: data
        )
        let score: Double

        switch value {
        case "BEST":
            score = 0.9
        case "MID":
            score = 0.5
        default:
            score = 0.1
        }

        return try AgentInferenceCandidateScore(
            score: score,
            metadata: [
                "value": value,
            ]
        )
    }
}

private enum SampledFixtureError:
    Error,
    Sendable
{
    case unknownAdapter(String)
    case responsesExhausted
    case streamingUnsupported
}

extension AgentInferenceExecutionFlowTests {
    static func runSampled()
        async throws
        -> [TestFlowDiagnostic]
    {
        let state = SampledFixtureState(
            outputs: [
                "LOW",
                "BEST",
                "MID",
            ]
        )
        let evaluator = SampledFixtureEvaluator()
        let executor = AgentInferenceExecutor(
            modelInvoker: SampledFixtureModelInvoker(
                state: state
            ),
            adapters: SampledFixtureAdapterResolver(),
            sampleEvaluator: evaluator
        )
        let realization = AgentInferenceRealization(
            strategy: .sampled,
            modelSelection: .executor,
            instructions: "Generate multiple candidate outputs.",
            budget: try AgentInferenceBudget(
                maximumAttempts: 3
            ),
            adapter: "sampled_fixture_adapter"
        )

        let result = try await executor.execute(
            SampledFixtureInference.self,
            input: SampledFixtureInference.Input(
                value: "sample"
            ),
            realization: realization
        )
        let invocationCount = await state.count()

        try Expect.equal(
            result.output,
            "BEST",
            "sampled inference returns the highest-scoring candidate"
        )
        try Expect.equal(
            result.record.strategy,
            .sampled,
            "sampled inference records sampled strategy"
        )
        try Expect.equal(
            result.record.attempts.count,
            3,
            "sampled inference executes one attempt per configured sample budget"
        )
        try Expect.equal(
            result.record.budgetUsage.totalTokens,
            6,
            "sampled inference aggregates token usage across attempts"
        )
        try Expect.equal(
            result.record.sampling?.evaluator,
            evaluator.identifier,
            "sampling record preserves evaluator identity"
        )
        try Expect.equal(
            result.record.sampling?.evaluations.count,
            3,
            "sampling record preserves typed candidate evaluations"
        )
        try Expect.equal(
            result.record.sampling?.selectedAttemptIndex,
            1,
            "sampling record identifies the winning attempt"
        )
        try Expect.equal(
            invocationCount,
            3,
            "sampled inference performs the expected number of model invocations"
        )

        let cappedState = SampledFixtureState(
            outputs: [
                "LOW",
                "BEST",
                "MID",
            ]
        )
        let cappedExecutor = AgentInferenceExecutor(
            modelInvoker: SampledFixtureModelInvoker(
                state: cappedState
            ),
            adapters: SampledFixtureAdapterResolver(),
            sampleEvaluator: evaluator
        )
        let cappedResult = try await cappedExecutor.execute(
            SampledFixtureInference.self,
            input: SampledFixtureInference.Input(
                value: "token-capped"
            ),
            realization: AgentInferenceRealization(
                strategy: .sampled,
                modelSelection: .executor,
                instructions: "Stop sampling when the token budget is exhausted.",
                budget: try AgentInferenceBudget(
                    maximumAttempts: 3,
                    maximumTotalTokens: 4
                ),
                adapter: "sampled_fixture_adapter"
            )
        )
        let cappedInvocationCount = await cappedState.count()

        try Expect.equal(
            cappedResult.output,
            "BEST",
            "token-capped sampling selects among completed candidates"
        )
        try Expect.equal(
            cappedResult.record.attempts.count,
            2,
            "token budget stops further sampling after completed attempts"
        )
        try Expect.equal(
            cappedResult.record.budgetUsage.totalTokens,
            4,
            "token-capped sampling records consumed tokens"
        )
        try Expect.equal(
            cappedResult.record.sampling?.selectedAttemptIndex,
            1,
            "token-capped sampling preserves winning candidate provenance"
        )
        try Expect.equal(
            cappedInvocationCount,
            2,
            "budget rejection prevents an additional model invocation"
        )

        let failureState = SampledFixtureState(
            outputs: [
                "BEST",
            ]
        )
        let failureExecutor = AgentInferenceExecutor(
            modelInvoker: SampledFixtureModelInvoker(
                state: failureState
            ),
            adapters: SampledFixtureAdapterResolver(),
            sampleEvaluator: evaluator
        )
        let executionFailure: AgentInferenceExecutionFailure?

        do {
            _ = try await failureExecutor.execute(
                SampledFixtureInference.self,
                input: .init(
                    value: "terminal-failure"
                ),
                realization: AgentInferenceRealization(
                    strategy: .sampled,
                    modelSelection: .executor,
                    instructions: "Preserve completed samples when a later sample fails.",
                    budget: try AgentInferenceBudget(
                        maximumAttempts: 2
                    ),
                    adapter: "sampled_fixture_adapter"
                )
            )
            executionFailure = nil
        } catch let error as AgentInferenceExecutionFailure {
            executionFailure = error
        } catch {
            throw error
        }

        let sampledFailure = try Expect.notNil(
            executionFailure,
            "sampled terminal attempt failure becomes canonical execution failure"
        )
        let partialSampling = try Expect.notNil(
            sampledFailure.record.sampling,
            "sampled failure preserves completed evaluation state"
        )

        try Expect.equal(
            sampledFailure.record.strategy,
            .sampled,
            "sampled failure preserves strategy identity"
        )
        try Expect.equal(
            sampledFailure.record.attempts.count,
            2,
            "sampled failure preserves completed and terminal failed attempts"
        )
        try Expect.equal(
            sampledFailure.record.attempts[0].failure == nil,
            true,
            "first sampled attempt remains a successful candidate"
        )
        try Expect.equal(
            sampledFailure.record.attempts[1],
            sampledFailure.attempt.record,
            "terminal sampled attempt is preserved exactly"
        )
        try Expect.equal(
            sampledFailure.attempt.record.index,
            1,
            "sampled failure preserves the failed semantic attempt index"
        )
        try Expect.equal(
            partialSampling.evaluations.count,
            1,
            "sampled failure preserves only evaluations actually completed"
        )
        try Expect.equal(
            partialSampling.selectedAttemptIndex,
            0,
            "sampled failure preserves the best completed candidate"
        )
        try Expect.equal(
            sampledFailure.record.budgetUsage.invocationCount,
            2,
            "sampled failed execution accounts for successful and failed provider invocations"
        )
        try Expect.equal(
            sampledFailure.record.budgetUsage.reportedTotalTokens,
            2,
            "sampled failed execution preserves reported spend from completed provider work"
        )
        try Expect.equal(
            sampledFailure.record.budgetUsage.unreportedTokenInvocationCount,
            1,
            "failed provider invocation remains explicit when token usage was never reported"
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
                "evaluator",
                evaluator.identifier.rawValue
            ),
            .field(
                "selected_attempt",
                String(result.record.sampling?.selectedAttemptIndex ?? -1)
            ),
            .field(
                "token_capped_attempts",
                String(cappedResult.record.attempts.count)
            ),
            .field(
                "failed_execution_attempts",
                String(sampledFailure.record.attempts.count)
            ),
        ]
    }
}
