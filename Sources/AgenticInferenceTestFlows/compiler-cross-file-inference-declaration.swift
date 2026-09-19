import Agentic
import Macros
import Schema

@JSONSchema
struct CrossFileInferenceInstructionProposalExample:
    Sendable,
    Codable,
    Hashable
{
    var inputJSON: String
    var expectedOutputJSON: String
    var metadata: [String: String]

    init(
        inputJSON: String,
        expectedOutputJSON: String,
        metadata: [String: String] = [:]
    ) {
        self.inputJSON = inputJSON
        self.expectedOutputJSON = expectedOutputJSON
        self.metadata = metadata
    }
}

@JSONSchema
struct CrossFileInferenceInstructionProposal:
    Sendable,
    Codable,
    Hashable
{
    var instructions: String
    var rationale: String
}

extension Standard.Inferences {
    @Inference
    struct CrossFileProposeInferenceInstructions {
        @JSONSchema
        struct Input:
            Source,
            Hashable
        {
            var inferenceIdentifier: String
            var inferencePurpose: String
            var seedInstructions: String
            var examples: [CrossFileInferenceInstructionProposalExample]
            var requestedProposalCount: Int

            init(
                inferenceIdentifier: String,
                inferencePurpose: String,
                seedInstructions: String,
                examples: [CrossFileInferenceInstructionProposalExample],
                requestedProposalCount: Int
            ) {
                self.inferenceIdentifier = inferenceIdentifier
                self.inferencePurpose = inferencePurpose
                self.seedInstructions = seedInstructions
                self.examples = examples
                self.requestedProposalCount = requestedProposalCount
            }
        }

        @JSONSchema
        struct Output:
            Result,
            Hashable
        {
            var proposals: [CrossFileInferenceInstructionProposal]
        }

        static let purpose =
            "Compile-only cross-file inference execution reproducer."
    }
}
