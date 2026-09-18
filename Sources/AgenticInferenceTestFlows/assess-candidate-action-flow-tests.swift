import Agentic
import AgenticInference
import Foundation
import TestFlows

extension InferenceFlowTesting {
    static func runAssessCandidateAction()
        throws
        -> [TestFlowDiagnostic]
    {
        let input = AssessCandidateAction.Input(
            goal: "Publish a completed change safely.",
            state: "Implementation and tests are complete.",
            candidate: .init(
                identifier: "publish",
                description: "Publish the completed changes."
            )
        )

        let encodedInput = try JSONEncoder().encode(
            input
        )
        let decodedInput = try JSONDecoder().decode(
            AssessCandidateAction.Input.self,
            from: encodedInput
        )

        try Expect.equal(
            decodedInput,
            input,
            "assess-candidate-action input survives typed codec round trip"
        )
        try Expect.equal(
            AssessCandidateAction.definition.identifier,
            InferenceIdentifier("assess_candidate_action"),
            "assess-candidate-action exposes stable semantic inference identifier"
        )

        let output = AssessCandidateAction.Output(
            acceptable: true,
            assessment: "The change is tested and ready to publish."
        )
        let encodedOutput = try JSONEncoder().encode(
            output
        )
        let decodedOutput = try JSONDecoder().decode(
            AssessCandidateAction.Output.self,
            from: encodedOutput
        )

        try Expect.equal(
            decodedOutput,
            output,
            "assess-candidate-action output survives typed codec round trip"
        )

        let schemaData = try JSONEncoder().encode(
            AssessCandidateAction.Output.jsonschema.jsonvalue
        )
        let schemaText = String(
            decoding: schemaData,
            as: UTF8.self
        )

        try Expect.equal(
            schemaText.contains("acceptable"),
            true,
            "assessment schema exposes acceptability"
        )
        try Expect.equal(
            schemaText.contains("assessment"),
            true,
            "assessment schema exposes explanation"
        )

        return [
            .field(
                "inference",
                AssessCandidateAction.definition.identifier.rawValue
            ),
            .field(
                "candidate",
                input.candidate.identifier
            ),
            .field(
                "acceptable",
                String(output.acceptable)
            ),
            .field(
                "structured_output",
                "true"
            ),
        ]
    }
}
