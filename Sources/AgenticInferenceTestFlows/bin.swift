import Agentic
import AgenticInference
import TestFlows

@main
enum AgenticInferenceFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: AgenticInferenceFlowSuite.self
        )
    }
}

enum AgenticInferenceFlowSuite: TestFlowRegistry {
    static let title = "AgenticInference flow tests"

    static let flows: [TestFlow] = [
        TestFlow(
            "inference-substrate",
            tags: [
                "inference",
                "strategy",
                "realization",
            ]
        ) {
            let strategies = [
                InferenceStrategyIdentifier.direct.rawValue,
                InferenceStrategyIdentifier.native_reasoning.rawValue,
                InferenceStrategyIdentifier.sampled.rawValue,
                InferenceStrategyIdentifier.refining.rawValue,
            ]

            try Expect.equal(
                strategies,
                [
                    "direct",
                    "native_reasoning",
                    "sampled",
                    "refining",
                ],
                "well-known inference strategy identifiers"
            )

            let realization = InferenceRealizationConfiguration(
                strategy: .direct,
                instructions: "Return the fixture output.",
                budget: .singleAttempt
            )

            try Expect.equal(
                realization.strategy,
                .direct,
                "realization retains typed strategy identifier"
            )

            return [
                .field(
                    "strategies",
                    strategies.joined(
                        separator: ","
                    )
                ),
                .field(
                    "strategy",
                    realization.strategy.rawValue
                ),
            ]
        },
        TestFlow(
            "direct-inference-execution",
            tags: [
                "inference",
                "execution",
                "strategy",
                "direct",
            ]
        ) {
            try await InferenceExecutionFlowTests.runDirect()
        },
        TestFlow(
            "native-reasoning-inference-execution",
            tags: [
                "inference",
                "execution",
                "strategy",
                "native-reasoning",
            ]
        ) {
            try await InferenceExecutionFlowTests.runNativeReasoning()
        },
        TestFlow(
            "determine-next-action",
            tags: [
                "inference",
                "semantic",
                "decision",
                "action-selection",
            ]
        ) {
            try InferenceFlowTesting.runDetermineNextAction()
        },
        TestFlow(
            "assess-candidate-action",
            tags: [
                "inference",
                "semantic",
                "assessment",
                "action",
            ]
        ) {
            try InferenceFlowTesting.runAssessCandidateAction()
        },
        TestFlow(
            "inference-budget-accounting",
            tags: [
                "inference",
                "execution",
                "budget",
                "record",
                "multi-attempt",
            ]
        ) {
            try await InferenceExecutionFlowTests
                .runBudgetAccounting()
        },
        TestFlow(
            "sampled-inference-execution",
            tags: [
                "inference",
                "execution",
                "strategy",
                "sampled",
                "evaluation",
                "multi-attempt",
            ]
        ) {
            try await InferenceExecutionFlowTests
                .runSampled()
        },
        TestFlow(
            "refining-inference-execution",
            tags: [
                "inference",
                "execution",
                "strategy",
                "refining",
                "evaluation",
                "multi-attempt",
            ]
        ) {
            try await InferenceExecutionFlowTests
                .runRefining()
        },
    ]
        + inferenceRecoveryFlows
        + inferenceTransportRecoveryFlows
        + inferenceOutputRepairRecoveryFlows
        + inferenceStrategyRecoveryTransparencyFlows
}
