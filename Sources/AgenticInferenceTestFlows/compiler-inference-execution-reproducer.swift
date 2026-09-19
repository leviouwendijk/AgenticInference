import Agentic
import Foundation
import AgenticInference
import Macros
import Schema

private struct CompilerReproducerExecutor:
    InferenceExecuting,
    Sendable
{
    func execute(
        _ invocation: InferenceInvocation
    ) async throws -> InferenceInvocationResult {
        fatalError("compile-only erased execution reproducer")
    }

}

private struct CompilerReproducerManualInference:
    Inference
{
    @JSONSchema
    struct Input:
        Source,
        Hashable
    {
        let value: String
    }

    @JSONSchema
    struct Output:
        Result,
        Hashable
    {
        let value: String
    }

    static let definition = InferenceDefinition(
        identifier: "compiler_reproducer_manual",
        purpose: "Compile-only manual inference reproducer."
    )
}

@Inference
private struct CompilerReproducerMacroExplicitInference {
    @JSONSchema
    struct Input:
        Source,
        Hashable
    {
        let value: String
    }

    @JSONSchema
    struct Output:
        Result,
        Hashable
    {
        let value: String
    }

    static let purpose = "Compile-only macro inference reproducer with explicit IO contracts."
}

@Inference
private struct CompilerReproducerMacroImplicitInference {
    @JSONSchema
    struct Input:
        Source,
        Hashable
    {
        let value: String
    }

    @JSONSchema
    struct Output:
        Result,
        Hashable
    {
        let value: String
    }

    static let purpose = "Compile-only macro inference reproducer with implicit IO contracts."
}


private func compilerReproducerManualConcrete() async throws {
    let executor = CompilerReproducerExecutor()
    _ = try await CompilerReproducerManualInference.execute(
        using: executor,
        input: CompilerReproducerManualInference.Input(
            value: "value"
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        ),
        context: .default
    )
}


private func compilerReproducerManualExistential() async throws {
    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    _ = try await CompilerReproducerManualInference.execute(
        using: executor,
        input: CompilerReproducerManualInference.Input(
            value: "value"
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        ),
        context: .default
    )
}


private func compilerReproducerMacroExplicitConcrete() async throws {
    let executor = CompilerReproducerExecutor()
    _ = try await CompilerReproducerMacroExplicitInference.execute(
        using: executor,
        input: CompilerReproducerMacroExplicitInference.Input(
            value: "value"
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        ),
        context: .default
    )
}


private func compilerReproducerMacroExplicitExistential() async throws {
    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    _ = try await CompilerReproducerMacroExplicitInference.execute(
        using: executor,
        input: CompilerReproducerMacroExplicitInference.Input(
            value: "value"
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        ),
        context: .default
    )
}


private func compilerReproducerMacroImplicitConcrete() async throws {
    let executor = CompilerReproducerExecutor()
    _ = try await CompilerReproducerMacroImplicitInference.execute(
        using: executor,
        input: CompilerReproducerMacroImplicitInference.Input(
            value: "value"
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        ),
        context: .default
    )
}


private func compilerReproducerMacroImplicitExistential() async throws {
    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    _ = try await CompilerReproducerMacroImplicitInference.execute(
        using: executor,
        input: CompilerReproducerMacroImplicitInference.Input(
            value: "value"
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        ),
        context: .default
    )
}

private func compilerReproducerMacroImplicitExistentialConvenience() async throws {
    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    _ = try await CompilerReproducerMacroImplicitInference.execute(
        using: executor,
        input: CompilerReproducerMacroImplicitInference.Input(
            value: "value"
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        )
    )
}

@JSONSchema
public struct CompilerReproducerProposalExample:
    Sendable,
    Codable,
    Hashable
{
    public var inputJSON: String
    public var expectedOutputJSON: String

    public init(
        inputJSON: String,
        expectedOutputJSON: String
    ) {
        self.inputJSON = inputJSON
        self.expectedOutputJSON = expectedOutputJSON
    }
}

@JSONSchema
public struct CompilerReproducerProposal:
    Sendable,
    Codable,
    Hashable
{
    public var instructions: String
    public var rationale: String

    public init(
        instructions: String,
        rationale: String
    ) {
        self.instructions = instructions
        self.rationale = rationale
    }
}

extension Standard.Inferences {
    @Inference
    public struct CompilerReproducerNamespacedInference {
        @JSONSchema
        public struct Input:
            Source,
            Hashable
        {
            public var inferenceIdentifier: String
            public var inferencePurpose: String
            public var seedInstructions: String
            public var examples: [CompilerReproducerProposalExample]
            public var requestedProposalCount: Int

            public init(
                inferenceIdentifier: String,
                inferencePurpose: String,
                seedInstructions: String,
                examples: [CompilerReproducerProposalExample],
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
        public struct Output:
            Result,
            Hashable
        {
            public var proposals: [CompilerReproducerProposal]

            public init(
                proposals: [CompilerReproducerProposal]
            ) {
                self.proposals = proposals
            }
        }

        public static let purpose =
            "Compile-only namespaced inference reproducer."
    }
}

private struct CompilerReproducerOptimizationExample<
    InferenceType: Inference
> {
    let input: InferenceType.Input
    let expectedOutput: InferenceType.Output
}

private func compilerReproducerNamespacedExistentialConvenience() async throws {
    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    _ = try await Standard.Inferences.CompilerReproducerNamespacedInference.execute(
        using: executor,
        input: Standard.Inferences.CompilerReproducerNamespacedInference.Input(
            inferenceIdentifier: "outer",
            inferencePurpose: "outer purpose",
            seedInstructions: "seed",
            examples: [],
            requestedProposalCount: 1
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        )
    )
}

private func compilerReproducerNamespacedInsideGeneric<
    OuterInference: Inference
>(
    _ inference: OuterInference.Type
) async throws {
    _ = inference

    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    _ = try await Standard.Inferences.CompilerReproducerNamespacedInference.execute(
        using: executor,
        input: Standard.Inferences.CompilerReproducerNamespacedInference.Input(
            inferenceIdentifier: "outer",
            inferencePurpose: "outer purpose",
            seedInstructions: "seed",
            examples: [],
            requestedProposalCount: 1
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        )
    )
}

private func compilerReproducerNamespacedInsideGenericDerived<
    OuterInference: Inference
>(
    _ inference: OuterInference.Type
) async throws {
    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    _ = try await Standard.Inferences.CompilerReproducerNamespacedInference.execute(
        using: executor,
        input: Standard.Inferences.CompilerReproducerNamespacedInference.Input(
            inferenceIdentifier: inference.definition.identifier.rawValue,
            inferencePurpose: inference.definition.purpose,
            seedInstructions: "seed",
            examples: [],
            requestedProposalCount: 1
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        )
    )
}

private func compilerReproducerNamespacedInsideGenericMapped<
    OuterInference: Inference
>(
    _ inference: OuterInference.Type,
    examples: [CompilerReproducerOptimizationExample<OuterInference>]
) async throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [
        .sortedKeys,
    ]

    let proposalExamples = try examples.map { example in
        CompilerReproducerProposalExample(
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
            )
        )
    }

    let executor: any InferenceExecuting =
        CompilerReproducerExecutor()

    let execution = try await Standard.Inferences.CompilerReproducerNamespacedInference.execute(
        using: executor,
        input: Standard.Inferences.CompilerReproducerNamespacedInference.Input(
            inferenceIdentifier: inference.definition.identifier.rawValue,
            inferencePurpose: inference.definition.purpose,
            seedInstructions: "seed",
            examples: proposalExamples,
            requestedProposalCount: 1
        ),
        realization: InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "compile-only",
            budget: .singleAttempt
        )
    )

    _ = execution.output.proposals
}

// REPRODUCER_PROBES
