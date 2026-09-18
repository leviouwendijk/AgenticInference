import Agentic

public protocol InferenceAttemptExecuting: Sendable {
    func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext,
        priorAttempts: [InferenceAttemptRecord],
        additionalRequirements: AgentModelRequirements
    ) async throws -> InferenceAttemptResult<InferenceType.Output>
}
