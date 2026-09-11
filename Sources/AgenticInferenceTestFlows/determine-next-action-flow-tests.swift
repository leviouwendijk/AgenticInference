import AgenticInference
import Foundation
import TestFlows

extension AgentInferenceFlowTesting {
    static func runDetermineNextAction()
        throws
        -> [TestFlowDiagnostic]
    {
        let input = DetermineNextAction.Input(
            goal: "Finish the current task safely.",
            state: "Implementation is complete and tests pass.",
            candidates: [
                .init(
                    identifier: "review",
                    description: "Review the resulting changes."
                ),
                .init(
                    identifier: "publish",
                    description: "Publish the completed changes."
                ),
            ]
        )

        let encodedInput = try JSONEncoder().encode(
            input
        )
        let decodedInput = try JSONDecoder().decode(
            DetermineNextAction.Input.self,
            from: encodedInput
        )

        try Expect.equal(
            decodedInput,
            input,
            "determine-next-action input survives typed codec round trip"
        )
        try Expect.equal(
            DetermineNextAction.definition.identifier,
            AgentInferenceIdentifier("determine_next_action"),
            "determine-next-action exposes stable semantic inference identifier"
        )
        try Expect.equal(
            DetermineNextAction.definition.tags,
            [
                "decision",
                "action-selection",
            ],
            "determine-next-action exposes semantic discovery tags"
        )

        let output = DetermineNextAction.Output(
            selectedActionIdentifier: "publish"
        )
        let encodedOutput = try JSONEncoder().encode(
            output
        )
        let decodedOutput = try JSONDecoder().decode(
            DetermineNextAction.Output.self,
            from: encodedOutput
        )

        try Expect.equal(
            decodedOutput,
            output,
            "determine-next-action structured output survives typed codec round trip"
        )

        let schemaData = try JSONEncoder().encode(
            DetermineNextAction.Output.jsonschema.jsonvalue
        )
        let schemaText = String(
            decoding: schemaData,
            as: UTF8.self
        )

        try Expect.equal(
            schemaText.contains(
                "selectedActionIdentifier"
            ),
            true,
            "determine-next-action schema exposes selected action identifier"
        )

        return [
            .field(
                "inference",
                DetermineNextAction.definition.identifier.rawValue
            ),
            .field(
                "candidates",
                String(input.candidates.count)
            ),
            .field(
                "selected",
                output.selectedActionIdentifier
            ),
            .field(
                "structured_output",
                "true"
            ),
        ]
    }
}
