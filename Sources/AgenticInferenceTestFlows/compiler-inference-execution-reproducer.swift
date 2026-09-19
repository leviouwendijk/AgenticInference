import Agentic
import AgenticInference
import Macros
import Schema

private struct CompilerReproducerExecutor:
    InferenceExecuting,
    Sendable
{
    func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        fatalError("compile-only reproducer")
    }
}

private struct CompilerReproducerManualInference:
    Inference
{
    struct Input:
        SemanticInput,
        Hashable
    {
        let value: String
    }

    @JSONSchema
    struct Output:
        InferredOutput,
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
    struct Input:
        SemanticInput,
        Hashable
    {
        let value: String
    }

    @JSONSchema
    struct Output:
        InferredOutput,
        Hashable
    {
        let value: String
    }

    static let purpose = "Compile-only macro inference reproducer with explicit IO contracts."
}

@Inference
private struct CompilerReproducerMacroImplicitInference {
    struct Input:
        Hashable
    {
        let value: String
    }

    @JSONSchema
    struct Output:
        Hashable
    {
        let value: String
    }

    static let purpose = "Compile-only macro inference reproducer with implicit IO contracts."
}


private func compilerReproducerManualConcrete() async throws {
    let executor = CompilerReproducerExecutor()
    _ = try await executor.execute(
        CompilerReproducerManualInference.self,
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

    _ = try await executor.execute(
        CompilerReproducerManualInference.self,
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
    _ = try await executor.execute(
        CompilerReproducerMacroExplicitInference.self,
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

    _ = try await executor.execute(
        CompilerReproducerMacroExplicitInference.self,
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
    _ = try await executor.execute(
        CompilerReproducerMacroImplicitInference.self,
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

    _ = try await executor.execute(
        CompilerReproducerMacroImplicitInference.self,
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

// REPRODUCER_PROBES
