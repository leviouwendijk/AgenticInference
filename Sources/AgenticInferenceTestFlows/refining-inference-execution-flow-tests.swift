import Agentic
import AgenticInference
import Foundation
import TestFlows

private struct RefiningFixtureInference: Inference {
    struct Input:
        SemanticInput
    {
        let value: String
    }

    typealias Output = String

    static let definition = InferenceDefinition(
        identifier: "fixture.refining_execution",
        purpose: "Prove iterative typed inference refinement."
    )
}

private struct RefiningFixtureAdapter:
    InferenceAdapter,
    Sendable
{
    let identifier: InferenceAdapterIdentifier =
        "refining_fixture_adapter"

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

private struct RefiningFixtureAdapterResolver:
    InferenceAdapterResolving,
    Sendable
{
    let adapter = RefiningFixtureAdapter()

    func require(
        _ identifier: InferenceAdapterIdentifier
    ) throws -> any InferenceAdapter {
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
    InferenceRefinementGuiding,
    Sendable
{
    let identifier: InferenceRefinementGuideIdentifier =
        "fixture_refinement"
    let failingAttemptIndex: Int?

    init(
        failingAttemptIndex: Int? = nil
    ) {
        self.failingAttemptIndex = failingAttemptIndex
    }

    func guide<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        output: InferenceType.Output,
        attempt: InferenceAttemptRecord,
        realization: InferenceRealizationConfiguration
    ) async throws -> InferenceRefinementDecision {
        if failingAttemptIndex == attempt.index {
            throw RefiningFixtureError.guideFailed(
                attempt.index
            )
        }

        let data = try JSONEncoder().encode(
            output
        )
        let value = try JSONDecoder().decode(
            String.self,
            from: data
        )

        switch value {
        case "ROUGH":
            return InferenceRefinementDecision(
                evaluation: try InferenceCandidateScore(
                    score: 0.2,
                    metadata: [
                        "value": value,
                    ]
                ),
                directive: .continueWith(
                    try InferenceRefinementInstructions(
                        "Improve the ROUGH candidate into a BETTER candidate."
                    )
                )
            )

        case "BETTER":
            return InferenceRefinementDecision(
                evaluation: try InferenceCandidateScore(
                    score: 0.7,
                    metadata: [
                        "value": value,
                    ]
                ),
                directive: .continueWith(
                    try InferenceRefinementInstructions(
                        "Improve the BETTER candidate into the FINAL candidate."
                    )
                )
            )

        case "FINAL":
            return InferenceRefinementDecision(
                evaluation: try InferenceCandidateScore(
                    score: 1.0,
                    metadata: [
                        "value": value,
                    ]
                ),
                directive: .stop
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
    case guideFailed(Int)
    case streamingUnsupported
}

extension InferenceExecutionFlowTests {
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
        let executor = InferenceExecutor(
            modelInvoker: RefiningFixtureModelInvoker(
                state: state
            ),
            adapters: RefiningFixtureAdapterResolver(),
            refinementGuide: guide
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .refining,
            instructions: "Produce the initial candidate.",
            budget: try InferenceBudget(
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

        var emptyInstructionsRejected = false

        do {
            _ = try InferenceRefinementInstructions(
                "   "
            )
        } catch InferenceRefinementInstructionsParsingError.empty {
            emptyInstructionsRejected = true
        }

        try Expect.equal(
            emptyInstructionsRejected,
            true,
            "refinement continuation instructions reject empty input at parsing"
        )

        let encodedRecord = try JSONEncoder().encode(
            result.record
        )
        let decodedRecord = try JSONDecoder().decode(
            InferenceExecutionRecord.self,
            from: encodedRecord
        )

        try Expect.equal(
            decodedRecord,
            result.record,
            "refining execution provenance survives durable codec round trip"
        )

        let failureState = RefiningFixtureState(
            outputs: [
                "ROUGH",
            ]
        )
        let failureExecutor = InferenceExecutor(
            modelInvoker: RefiningFixtureModelInvoker(
                state: failureState
            ),
            adapters: RefiningFixtureAdapterResolver(),
            refinementGuide: guide
        )
        let executionFailure: InferenceExecutionFailure?

        do {
            _ = try await failureExecutor.execute(
                RefiningFixtureInference.self,
                input: .init(
                    value: "terminal-failure"
                ),
                realization: InferenceRealizationConfiguration(
                    strategy: .refining,
                    instructions: "Preserve completed refinement work when a later attempt fails.",
                    budget: try InferenceBudget(
                        maximumAttempts: 2
                    ),
                    adapter: "refining_fixture_adapter"
                )
            )
            executionFailure = nil
        } catch let error as InferenceExecutionFailure {
            executionFailure = error
        } catch {
            throw error
        }

        let refiningFailure = try Expect.notNil(
            executionFailure,
            "refining terminal attempt failure becomes canonical execution failure"
        )
        let terminalRefiningAttempt = try Expect.notNil(
            refiningFailure.terminalAttempt,
            "refining attempt failure preserves its exact terminal attempt"
        )
        let partialRefinement = try Expect.notNil(
            refiningFailure.record.refinement,
            "refining failure preserves completed guide state"
        )

        try Expect.equal(
            refiningFailure.record.strategy,
            .refining,
            "refining failure preserves strategy identity"
        )
        try Expect.equal(
            refiningFailure.record.attempts.count,
            2,
            "refining failure preserves completed and terminal failed attempts"
        )
        try Expect.equal(
            refiningFailure.record.attempts[0].failure == nil,
            true,
            "first refining attempt remains a successful candidate"
        )
        try Expect.equal(
            refiningFailure.record.attempts[1],
            terminalRefiningAttempt.record,
            "terminal refining attempt is preserved exactly"
        )
        try Expect.equal(
            terminalRefiningAttempt.record.index,
            1,
            "refining failure preserves the failed semantic attempt index"
        )
        try Expect.equal(
            partialRefinement.steps.count,
            1,
            "refining failure preserves only guide decisions actually completed"
        )
        try Expect.equal(
            partialRefinement.selectedAttemptIndex,
            0,
            "refining failure preserves the best completed candidate"
        )
        try Expect.equal(
            partialRefinement.lastAttemptIndex,
            1,
            "refining failure identifies the terminal failed attempt as the last executed attempt"
        )
        try Expect.equal(
            partialRefinement.termination,
            .attempt_failed,
            "refining provenance explicitly distinguishes terminal attempt failure"
        )
        try Expect.equal(
            refiningFailure.record.budgetUsage.invocationCount,
            2,
            "refining failed execution accounts for successful and failed provider invocations"
        )
        try Expect.equal(
            refiningFailure.record.budgetUsage.reportedTotalTokens,
            2,
            "refining failed execution preserves reported spend from completed provider work"
        )
        try Expect.equal(
            refiningFailure.record.budgetUsage.unreportedTokenInvocationCount,
            1,
            "failed refining provider invocation remains explicit when usage was never reported"
        )
        try Expect.equal(
            refiningFailure.record.failure,
            refiningFailure.failure,
            "refining attempt failure is durable on the execution record"
        )

        let guideFailureState = RefiningFixtureState(
            outputs: [
                "ROUGH",
                "BETTER",
            ]
        )
        let guideFailureExecutor = InferenceExecutor(
            modelInvoker: RefiningFixtureModelInvoker(
                state: guideFailureState
            ),
            adapters: RefiningFixtureAdapterResolver(),
            refinementGuide: RefiningFixtureGuide(
                failingAttemptIndex: 1
            )
        )
        let guideExecutionFailure: InferenceExecutionFailure?

        do {
            _ = try await guideFailureExecutor.execute(
                RefiningFixtureInference.self,
                input: .init(
                    value: "guide-failure"
                ),
                realization: InferenceRealizationConfiguration(
                    strategy: .refining,
                    instructions: "Preserve paid attempts when refinement guidance fails.",
                    budget: try InferenceBudget(
                        maximumAttempts: 2
                    ),
                    adapter: "refining_fixture_adapter"
                )
            )
            guideExecutionFailure = nil
        } catch let error as InferenceExecutionFailure {
            guideExecutionFailure = error
        } catch {
            throw error
        }

        let guideFailure = try Expect.notNil(
            guideExecutionFailure,
            "refinement guide failure becomes canonical execution failure"
        )
        let guideRefinement = try Expect.notNil(
            guideFailure.record.refinement,
            "guide failure preserves completed refinement state"
        )

        try Expect.equal(
            guideFailure.terminalAttempt == nil,
            true,
            "strategy-local guide failure manufactures no failed semantic attempt"
        )
        try Expect.equal(
            guideFailure.record.failure,
            guideFailure.failure,
            "strategy-local guide failure is durable on the execution record"
        )
        try Expect.equal(
            guideFailure.record.attempts.count,
            2,
            "guide failure retains both successful paid model attempts"
        )
        try Expect.equal(
            guideFailure.record.attempts[1].failure == nil,
            true,
            "model attempt remains successful when only subsequent guidance fails"
        )
        try Expect.equal(
            guideRefinement.steps.count,
            1,
            "guide failure preserves only completed guide decisions"
        )
        try Expect.equal(
            guideRefinement.selectedAttemptIndex,
            0,
            "guide failure preserves the best fully guided candidate"
        )
        try Expect.equal(
            guideRefinement.lastAttemptIndex,
            1,
            "guide failure records the successful model attempt whose guidance failed"
        )
        try Expect.equal(
            guideRefinement.termination,
            .guide_failed,
            "partial refinement explicitly distinguishes guide failure"
        )
        try Expect.equal(
            guideFailure.record.budgetUsage.invocationCount,
            2,
            "guide failure retains both provider invocations"
        )
        try Expect.equal(
            guideFailure.record.budgetUsage.totalTokens,
            4,
            "guide failure preserves all reported provider spend"
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
            .field(
                "failed_execution_attempts",
                String(refiningFailure.record.attempts.count)
            ),
            .field(
                "guide_failure_tokens",
                String(guideFailure.record.budgetUsage.totalTokens ?? 0)
            ),
        ]
    }
}
