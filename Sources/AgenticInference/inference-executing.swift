import Agentic

public protocol InferenceExecuting: Sendable {
    func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext
    ) async throws -> InferenceExecutionResult<InferenceType.Output>
}

public extension InferenceExecuting {
    func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        try await execute(
            inference,
            input: input,
            realization: realization,
            context: .default
        )
    }

    func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationDefinition<InferenceType>,
        context: InferenceExecutionContext = .default
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        try await execute(
            inference,
            input: input,
            realization: realization.configuration,
            context: context
        )
    }
}
