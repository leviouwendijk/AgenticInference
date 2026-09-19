import Agentic
import AgenticInference
import AgenticRecovery
import Foundation
import TestFlows

private struct StrategyRecoveryFixtureInference: Inference {
    struct Input:
        SemanticInput
    {
        let value: String
    }

    typealias Output = String

    static let definition = InferenceDefinition(
        identifier: "fixture.strategy_recovery",
        purpose: "Prove that mechanical recovery remains internal to semantic inference attempts."
    )
}

private enum StrategyRecoveryFixtureMode: Sendable {
    case transport
    case outputRepair
}

private enum StrategyRecoveryFixtureError:
    Error,
    Sendable,
    LocalizedError
{
    case transient
    case invalidStructuredOutput
    case missingAttemptMetadata
    case unexpectedAttempt(Int)
    case unknownAdapter(String)
    case unexpectedOutput(String)
    case streamingUnsupported

    var errorDescription: String? {
        switch self {
        case .transient:
            "fixture transport failure"

        case .invalidStructuredOutput:
            "fixture response is not valid structured output"

        case .missingAttemptMetadata:
            "fixture invocation is missing inference attempt metadata"

        case .unexpectedAttempt(let attempt):
            "fixture received unexpected semantic attempt \(attempt)"

        case .unknownAdapter(let identifier):
            "unknown fixture adapter: \(identifier)"

        case .unexpectedOutput(let output):
            "unexpected fixture output: \(output)"

        case .streamingUnsupported:
            "fixture streaming is unsupported"
        }
    }
}

private struct StrategyRecoveryFixtureAdapter:
    InferenceAdapter,
    InferenceOutputRepairing,
    Sendable
{
    let identifier: InferenceAdapterIdentifier =
        "strategy_recovery_fixture_adapter"

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
                        text: realization.instructions
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
            throw StrategyRecoveryFixtureError.invalidStructuredOutput
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

private struct StrategyRecoveryFixtureAdapterResolver:
    InferenceAdapterResolving,
    Sendable
{
    let adapter = StrategyRecoveryFixtureAdapter()

    func require(
        _ identifier: InferenceAdapterIdentifier
    ) throws -> any InferenceAdapter {
        guard identifier == adapter.identifier else {
            throw StrategyRecoveryFixtureError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}

private actor StrategyRecoveryFixtureState {
    private var count = 0
    private var repairRequestSeen = false

    func record(
        invocation: AgentModelInvocation
    ) {
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
    }

    func invocationCount() -> Int {
        count
    }

    func sawRepairRequest() -> Bool {
        repairRequestSeen
    }
}

private struct StrategyRecoveryFixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let mode: StrategyRecoveryFixtureMode
    let outputs: [Int: String]
    let state: StrategyRecoveryFixtureState

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        await state.record(
            invocation: invocation
        )

        guard
            let rawAttempt = invocation.metadata[
                "inference.attempt"
            ],
            let attemptIndex = Int(rawAttempt),
            let rawInvocation = invocation.metadata[
                "inference.invocation"
            ],
            let invocationIndex = Int(rawInvocation)
        else {
            throw StrategyRecoveryFixtureError
                .missingAttemptMetadata
        }

        if mode == .transport,
           attemptIndex == 0,
           invocationIndex == 0
        {
            throw StrategyRecoveryFixtureError.transient
        }

        let text: String

        if mode == .outputRepair,
           attemptIndex == 0,
           invocationIndex == 0
        {
            text = "not-json"
        } else {
            guard let output = outputs[attemptIndex] else {
                throw StrategyRecoveryFixtureError
                    .unexpectedAttempt(attemptIndex)
            }

            text = String(
                decoding: try JSONEncoder().encode(
                    output
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
            identifier: "strategy_recovery_fixture_profile",
            gatewayIdentifier: "strategy_recovery_fixture_gateway",
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
            continuation.finish(
                throwing: StrategyRecoveryFixtureError
                    .streamingUnsupported
            )
        }
    }
}

private struct StrategyRecoveryFixtureClassifier:
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
        guard let fixtureError =
            error as? StrategyRecoveryFixtureError
        else {
            return nil
        }

        let kind: Recovery.Kind

        switch (fixtureError, stage) {
        case (.transient, .execution):
            kind = .transport_transient

        case (.invalidStructuredOutput, .decoding):
            kind = .structured_output_invalid

        default:
            return nil
        }

        return Recovery.Incident(
            kind: kind,
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

private struct StrategyRecoveryFixtureEvaluator:
    InferenceCandidateEvaluating,
    Sendable
{
    let identifier: InferenceEvaluatorIdentifier =
        "strategy_recovery_fixture_evaluator"

    func evaluate<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        output: InferenceType.Output,
        attempt: InferenceAttemptRecord
    ) async throws -> InferenceCandidateScore {
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

        return try InferenceCandidateScore(
            score: score,
            metadata: [
                "value": value,
            ]
        )
    }
}

private struct StrategyRecoveryFixtureGuide:
    InferenceRefinementGuiding,
    Sendable
{
    let identifier: InferenceRefinementGuideIdentifier =
        "strategy_recovery_fixture_guide"

    func guide<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        output: InferenceType.Output,
        attempt: InferenceAttemptRecord,
        realization: InferenceRealizationConfiguration
    ) async throws -> InferenceRefinementDecision {
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
                        "Improve ROUGH to BETTER."
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
                        "Improve BETTER to FINAL."
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
            throw StrategyRecoveryFixtureError
                .unexpectedOutput(value)
        }
    }
}

private func strategyRecoveryFixturePolicy()
    -> Recovery.Policy
{
    Recovery.Policy(
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
                    ]
                )
            ),
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
                    ]
                )
            ),
        ]
    )
}

private func runSampledTransportRecoveryTransparency()
    async throws
    -> [TestFlowDiagnostic]
{
    let state = StrategyRecoveryFixtureState()
    let evaluator = StrategyRecoveryFixtureEvaluator()
    let executor = InferenceExecutor(
        modelInvoker: StrategyRecoveryFixtureModelInvoker(
            mode: .transport,
            outputs: [
                0: "LOW",
                1: "BEST",
                2: "MID",
            ],
            state: state
        ),
        adapters: StrategyRecoveryFixtureAdapterResolver(),
        sampleEvaluator: evaluator,
        recoveryClassifier: StrategyRecoveryFixtureClassifier()
    )
    let realization = InferenceRealizationConfiguration(
        strategy: .sampled,
        instructions: "Generate sampled fixture candidates.",
        budget: try InferenceBudget(
            maximumAttempts: 3
        ),
        recovery: strategyRecoveryFixturePolicy(),
        adapter: "strategy_recovery_fixture_adapter"
    )

    let result = try await executor.execute(
        StrategyRecoveryFixtureInference.self,
        input: .init(
            value: "sample"
        ),
        realization: realization
    )
    let recoveries = result.record.attempts
        .flatMap(\.recoveries)
    let recoveryActions = recoveries
        .flatMap(\.attempts)
        .map(\.action)

    try Expect.equal(
        result.output,
        "BEST",
        "sampled inference still selects the best semantic candidate after transport recovery"
    )
    try Expect.equal(
        result.record.budgetUsage.attemptCount,
        3,
        "sampled recovery does not consume an additional semantic attempt"
    )
    try Expect.equal(
        result.record.budgetUsage.invocationCount,
        4,
        "sampled execution records the recovered provider retry as a fourth model invocation"
    )
    try Expect.equal(
        result.record.budgetUsage.reportedTotalTokens,
        6,
        "successful sampled provider invocations retain their reported token usage"
    )
    try Expect.equal(
        result.record.budgetUsage.unreportedTokenInvocationCount,
        1,
        "failed transport invocation remains an invocation with unavailable token usage"
    )
    try Expect.equal(
        result.record.attempts.map(\.index),
        [0, 1, 2],
        "sampled semantic attempt indexes remain contiguous"
    )
    try Expect.equal(
        result.record.attempts.map {
            $0.invocations.count
        },
        [2, 1, 1],
        "transport recovery remains nested inside the first semantic attempt"
    )
    try Expect.equal(
        result.record.sampling?.evaluations.count,
        3,
        "sample evaluator runs once per completed semantic attempt rather than once per provider invocation"
    )
    try Expect.equal(
        result.record.sampling?.selectedAttemptIndex,
        1,
        "sample selection continues to reference semantic attempt indexes"
    )
    try Expect.equal(
        recoveries.count,
        1,
        "sampled execution records exactly one mechanical recovery"
    )
    try Expect.equal(
        recoveryActions,
        [.retry_same_operation],
        "sampled transport failure is restored by retrying the same operation"
    )
    try Expect.equal(
        await state.invocationCount(),
        4,
        "fixture observed exactly four physical model invocations"
    )

    return [
        .field(
            "semantic_attempts",
            String(result.record.budgetUsage.attemptCount)
        ),
        .field(
            "model_invocations",
            String(result.record.budgetUsage.invocationCount)
        ),
        .field(
            "evaluations",
            String(
                result.record.sampling?.evaluations.count
                    ?? 0
            )
        ),
        .field(
            "selected_attempt",
            String(
                result.record.sampling?.selectedAttemptIndex
                    ?? -1
            )
        ),
        .field(
            "recovery_action",
            recoveryActions.first?.rawValue
                ?? "none"
        ),
    ]
}

private func runRefiningTransportRecoveryTransparency()
    async throws
    -> [TestFlowDiagnostic]
{
    let state = StrategyRecoveryFixtureState()
    let guide = StrategyRecoveryFixtureGuide()
    let executor = InferenceExecutor(
        modelInvoker: StrategyRecoveryFixtureModelInvoker(
            mode: .transport,
            outputs: [
                0: "ROUGH",
                1: "BETTER",
                2: "FINAL",
            ],
            state: state
        ),
        adapters: StrategyRecoveryFixtureAdapterResolver(),
        refinementGuide: guide,
        recoveryClassifier: StrategyRecoveryFixtureClassifier()
    )
    let realization = InferenceRealizationConfiguration(
        strategy: .refining,
        instructions: "Produce the initial refining fixture candidate.",
        budget: try InferenceBudget(
            maximumAttempts: 3
        ),
        recovery: strategyRecoveryFixturePolicy(),
        adapter: "strategy_recovery_fixture_adapter"
    )

    let result = try await executor.execute(
        StrategyRecoveryFixtureInference.self,
        input: .init(
            value: "refine"
        ),
        realization: realization
    )
    let recoveries = result.record.attempts
        .flatMap(\.recoveries)
    let recoveryActions = recoveries
        .flatMap(\.attempts)
        .map(\.action)

    try Expect.equal(
        result.output,
        "FINAL",
        "refining inference reaches the same final semantic candidate after transport recovery"
    )
    try Expect.equal(
        result.record.budgetUsage.attemptCount,
        3,
        "refining transport recovery remains inside three semantic attempts"
    )
    try Expect.equal(
        result.record.budgetUsage.invocationCount,
        4,
        "refining recovery records one extra physical provider invocation"
    )
    try Expect.equal(
        result.record.budgetUsage.reportedTotalTokens,
        6,
        "three successful refining invocations retain reported token usage"
    )
    try Expect.equal(
        result.record.budgetUsage.unreportedTokenInvocationCount,
        1,
        "failed transport invocation remains visible in invocation accounting"
    )
    try Expect.equal(
        result.record.attempts.map(\.index),
        [0, 1, 2],
        "refining semantic attempt indexes remain contiguous"
    )
    try Expect.equal(
        result.record.attempts.map {
            $0.invocations.count
        },
        [2, 1, 1],
        "transport retry remains nested inside the first refinement attempt"
    )
    try Expect.equal(
        result.record.refinement?.steps.map(\.attemptIndex),
        [0, 1, 2],
        "refinement guide still produces one step per semantic candidate"
    )
    try Expect.equal(
        result.record.refinement?.selectedAttemptIndex,
        2,
        "refinement selection continues to reference semantic attempt indexes"
    )
    try Expect.equal(
        result.record.refinement?.lastAttemptIndex,
        2,
        "refinement last-attempt state ignores internal provider retry indexes"
    )
    try Expect.equal(
        result.record.refinement?.termination,
        .guide_stop,
        "refinement termination remains guide-driven after mechanical recovery"
    )
    try Expect.equal(
        recoveries.count,
        1,
        "refining execution records exactly one transport recovery"
    )
    try Expect.equal(
        recoveryActions,
        [.retry_same_operation],
        "refining transport recovery restores the same semantic operation"
    )
    try Expect.equal(
        await state.invocationCount(),
        4,
        "fixture observed exactly four physical model invocations"
    )

    return [
        .field(
            "semantic_attempts",
            String(result.record.budgetUsage.attemptCount)
        ),
        .field(
            "model_invocations",
            String(result.record.budgetUsage.invocationCount)
        ),
        .field(
            "refinement_steps",
            String(
                result.record.refinement?.steps.count
                    ?? 0
            )
        ),
        .field(
            "selected_attempt",
            String(
                result.record.refinement?.selectedAttemptIndex
                    ?? -1
            )
        ),
        .field(
            "recovery_action",
            recoveryActions.first?.rawValue
                ?? "none"
        ),
    ]
}

private func runRefiningOutputRepairTransparency()
    async throws
    -> [TestFlowDiagnostic]
{
    let state = StrategyRecoveryFixtureState()
    let guide = StrategyRecoveryFixtureGuide()
    let executor = InferenceExecutor(
        modelInvoker: StrategyRecoveryFixtureModelInvoker(
            mode: .outputRepair,
            outputs: [
                0: "ROUGH",
                1: "BETTER",
                2: "FINAL",
            ],
            state: state
        ),
        adapters: StrategyRecoveryFixtureAdapterResolver(),
        refinementGuide: guide,
        recoveryClassifier: StrategyRecoveryFixtureClassifier()
    )
    let realization = InferenceRealizationConfiguration(
        strategy: .refining,
        instructions: "Produce the initial refining fixture candidate.",
        budget: try InferenceBudget(
            maximumAttempts: 3
        ),
        recovery: strategyRecoveryFixturePolicy(),
        adapter: "strategy_recovery_fixture_adapter"
    )

    let result = try await executor.execute(
        StrategyRecoveryFixtureInference.self,
        input: .init(
            value: "repair"
        ),
        realization: realization
    )
    let recoveries = result.record.attempts
        .flatMap(\.recoveries)
    let recoveryActions = recoveries
        .flatMap(\.attempts)
        .map(\.action)

    try Expect.equal(
        result.output,
        "FINAL",
        "refining inference reaches the final candidate after structured-output repair"
    )
    try Expect.equal(
        result.record.budgetUsage.attemptCount,
        3,
        "output repair does not consume a new semantic refinement attempt"
    )
    try Expect.equal(
        result.record.budgetUsage.invocationCount,
        4,
        "output repair records the adapter-authored repair request as an additional provider invocation"
    )
    try Expect.equal(
        result.record.budgetUsage.totalTokens,
        8,
        "all four successful provider responses contribute to token accounting"
    )
    try Expect.equal(
        result.record.attempts.map {
            $0.invocations.count
        },
        [2, 1, 1],
        "decode repair remains nested inside the first semantic refinement attempt"
    )
    try Expect.equal(
        result.record.refinement?.steps.map(\.attemptIndex),
        [0, 1, 2],
        "guide execution remains one-for-one with semantic candidates after repair"
    )
    try Expect.equal(
        result.record.refinement?.selectedAttemptIndex,
        2,
        "repaired refinement preserves semantic selection indexing"
    )
    try Expect.equal(
        result.record.refinement?.lastAttemptIndex,
        2,
        "repaired refinement preserves semantic final-attempt indexing"
    )
    try Expect.equal(
        result.record.refinement?.termination,
        .guide_stop,
        "repaired refinement still terminates by authored guide semantics"
    )
    try Expect.equal(
        recoveries.count,
        1,
        "refining output repair records exactly one mechanical recovery"
    )
    try Expect.equal(
        recoveryActions,
        [.repair_output],
        "decode failure uses adapter-owned output repair"
    )
    try Expect.equal(
        await state.sawRepairRequest(),
        true,
        "repair recovery invokes the adapter-authored repair request rather than blindly repeating the original request"
    )
    try Expect.equal(
        await state.invocationCount(),
        4,
        "fixture observed exactly four physical model invocations"
    )

    return [
        .field(
            "semantic_attempts",
            String(result.record.budgetUsage.attemptCount)
        ),
        .field(
            "model_invocations",
            String(result.record.budgetUsage.invocationCount)
        ),
        .field(
            "refinement_steps",
            String(
                result.record.refinement?.steps.count
                    ?? 0
            )
        ),
        .field(
            "selected_attempt",
            String(
                result.record.refinement?.selectedAttemptIndex
                    ?? -1
            )
        ),
        .field(
            "recovery_action",
            recoveryActions.first?.rawValue
                ?? "none"
        ),
        .field(
            "repair_request",
            String(
                await state.sawRepairRequest()
            )
        ),
    ]
}

let inferenceStrategyRecoveryTransparencyFlows: [TestFlow] = [
    TestFlow(
        "sampled-recovery-transparency",
        tags: [
            "agentic-inference",
            "sampled",
            "strategy",
            "recovery",
            "transport",
            "semantic-attempt",
        ]
    ) {
        try await runSampledTransportRecoveryTransparency()
    },
    TestFlow(
        "refining-transport-recovery-transparency",
        tags: [
            "agentic-inference",
            "refining",
            "strategy",
            "recovery",
            "transport",
            "semantic-attempt",
        ]
    ) {
        try await runRefiningTransportRecoveryTransparency()
    },
    TestFlow(
        "refining-output-repair-transparency",
        tags: [
            "agentic-inference",
            "refining",
            "strategy",
            "recovery",
            "structured-output",
            "repair",
            "semantic-attempt",
        ]
    ) {
        try await runRefiningOutputRepairTransparency()
    },
]
