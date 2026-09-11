public protocol AgentInferenceStrategy: Sendable {
    var identifier: AgentInferenceStrategyIdentifier { get }

    func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization,
        attempts: any AgentInferenceAttemptExecuting
    ) async throws -> AgentInferenceExecutionResult<Inference.Output>
}

public protocol AgentInferenceStrategyResolving: Sendable {
    func require(
        _ identifier: AgentInferenceStrategyIdentifier
    ) throws -> any AgentInferenceStrategy
}
