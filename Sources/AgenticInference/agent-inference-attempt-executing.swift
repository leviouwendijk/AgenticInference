import Agentic

public protocol AgentInferenceAttemptExecuting: Sendable {
    func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization,
        priorAttempts: [AgentInferenceAttemptRecord],
        additionalRequirements: AgentModelRequirements,
        attemptIndex: Int
    ) async throws -> AgentInferenceAttemptResult<Inference.Output>
}
