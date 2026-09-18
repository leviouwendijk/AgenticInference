import Agentic
import AgenticInference
import Foundation
import TestFlows

extension InferenceFlowTesting {
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
            InferenceIdentifier("determine_next_action"),
            "determine-next-action exposes stable semantic inference identifier"
        )
        try Expect.equal(
            DetermineNextAction.definition.purpose,
            "Select the most appropriate next action from the supplied candidates for the current goal and state.",
            "determine-next-action exposes semantic inference purpose"
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
