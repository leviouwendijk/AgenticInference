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

            let binding = AgentInferenceRealizationBinding(
                site: "fixture_site",
                inference: "fixture_inference",
                realization: realization
            )

            try Expect.equal(
                binding.site.rawValue,
                "fixture_site",
                "binding retains inference site"
            )

            try Expect.equal(
                binding.inference.rawValue,
                "fixture_inference",
                "binding retains inference identifier"
            )

            try Expect.equal(
                binding.realization.strategy,
                .direct,
                "binding retains typed strategy identifier"
            )

            return [
                .field(
                    "strategies",
                    strategies.joined(
                        separator: ","
                    )
                ),
                .field(
                    "binding",
                    binding.site.rawValue
                ),
            ]
        },
    ]
}
