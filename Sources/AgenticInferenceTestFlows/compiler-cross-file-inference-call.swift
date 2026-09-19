import Agentic
import AgenticInference
import Foundation

struct CrossFileCompilerReproducerExecutor:
    InferenceExecuting,
    Sendable
{
    func execute(
        _ invocation: InferenceInvocation
    ) async throws -> InferenceInvocationResult {
        fatalError("compile-only cross-file reproducer")
    }
}

struct CrossFileOptimizationExample<
    InferenceType: Inference
> {
    let input: InferenceType.Input
    let expectedOutput: InferenceType.Output
    let metadata: [String: String]
}

func compilerCrossFileGenerate<
    InferenceType: Inference
>(
    _ inference: InferenceType.Type,
    examples: [CrossFileOptimizationExample<InferenceType>],
    seed: InferenceRealizationConfiguration,
    maximumProposals: Int
) async throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [
        .sortedKeys,
    ]

    let proposalExamples = try examples.map { example in
        CrossFileInferenceInstructionProposalExample(
            inputJSON: String(
                decoding: try encoder.encode(
                    example.input
                ),
                as: UTF8.self
            ),
            expectedOutputJSON: String(
                decoding: try encoder.encode(
                    example.expectedOutput
                ),
                as: UTF8.self
            ),
            metadata: example.metadata
        )
    }

    let proposer: any InferenceExecuting =
        CrossFileCompilerReproducerExecutor()

    let proposalExecution = try await Standard.Inferences
        .CrossFileProposeInferenceInstructions.execute(
            using: proposer,
            input: Standard.Inferences.CrossFileProposeInferenceInstructions.Input(
                inferenceIdentifier: inference.definition.identifier.rawValue,
                inferencePurpose: inference.definition.purpose,
                seedInstructions: seed.instructions,
                examples: proposalExamples,
                requestedProposalCount: maximumProposals
            ),
            realization: seed
        )

    _ = proposalExecution.output.proposals
}
