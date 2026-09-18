import Agentic
import AgenticInference
import AgenticRecovery
import Foundation
import TestFlows

let inferenceRecoveryFlows: [TestFlow] = [
    TestFlow(
        "inference-realization-recovery-policy",
        tags: [
            "agentic-inference",
            "recovery",
            "realization",
            "policy",
        ]
    ) {
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

        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return structured fixture output.",
            budget: .singleAttempt,
            recovery: policy
        )
        let incident = Recovery.Incident(
            kind: .structured_output_invalid,
            stage: .decoding,
            effectState: .none,
            retrySafety: .safe,
            scope: .init(
                kind: .inference,
                identifier: "fixture_inference"
            ),
            message: "fixture output could not be decoded"
        )

        let selectedPlan = try Expect.notNil(
            realization.recovery?.plan(
                for: incident
            ),
            "inference realization carries its authored recovery policy"
        )
        let selectedStep = try Expect.notNil(
            selectedPlan.steps.first,
            "resolved inference recovery plan has a first step"
        )

        try Expect.equal(
            selectedStep.action,
            .repair_output,
            "structured inference decode failure resolves output repair"
        )
        try Expect.equal(
            realization.budget.maximumAttempts,
            1,
            "semantic inference attempt budget remains independent of recovery policy"
        )

        let persisted = try JSONDecoder().decode(
            InferenceRealizationConfiguration.self,
            from: JSONEncoder().encode(
                realization
            )
        )

        try Expect.equal(
            persisted,
            realization,
            "recovery policy survives realization Codable round trip"
        )

        return [
            .field(
                "recovery_action",
                selectedStep.action.rawValue
            ),
            .field(
                "semantic_attempts",
                String(realization.budget.maximumAttempts)
            ),
        ]
    },
    TestFlow(
        "inference-realization-recovery-optional",
        tags: [
            "agentic-inference",
            "recovery",
            "compatibility",
        ]
    ) {
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "No recovery policy is authored here.",
            budget: .singleAttempt
        )

        try Expect.equal(
            realization.recovery == nil,
            true,
            "recovery remains absent unless explicitly authored"
        )

        return [
            .field(
                "recovery",
                realization.recovery == nil
                    ? "none"
                    : "configured"
            ),
        ]
    },
]
