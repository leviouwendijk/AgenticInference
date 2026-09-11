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
                AgentInferenceStrategyIdentifier.direct.rawValue,
                AgentInferenceStrategyIdentifier.native_reasoning.rawValue,
                AgentInferenceStrategyIdentifier.sampled.rawValue,
                AgentInferenceStrategyIdentifier.refining.rawValue,
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

            let realization = AgentInferenceRealization(
                strategy: .direct,
                modelSelection: .executor,
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
            try await AgentInferenceExecutionFlowTests.runDirect()
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
            try await AgentInferenceExecutionFlowTests.runNativeReasoning()
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
            try AgentInferenceFlowTesting.runDetermineNextAction()
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
            try AgentInferenceFlowTesting.runAssessCandidateAction()
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
            try await AgentInferenceExecutionFlowTests
                .runBudgetAccounting()
        },
    ]
}
