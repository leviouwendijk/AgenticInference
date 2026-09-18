import Agentic

public protocol InferenceStrategy: Sendable {
    var identifier: InferenceStrategyIdentifier { get }

    func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext,
        attempts: any InferenceAttemptExecuting
    ) async throws -> InferenceExecutionResult<InferenceType.Output>
}

public protocol InferenceStrategyResolving: Sendable {
    func require(
        _ identifier: InferenceStrategyIdentifier
    ) throws -> any InferenceStrategy
}
