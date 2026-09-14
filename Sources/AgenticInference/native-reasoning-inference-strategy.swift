import Agentic

public struct NativeReasoningInferenceStrategy:
    AgentInferenceStrategy,
    Sendable
{
    public let identifier: AgentInferenceStrategyIdentifier = .native_reasoning

    public init() {}

    public func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization,
        attempts: any AgentInferenceAttemptExecuting
    ) async throws -> AgentInferenceExecutionResult<Inference.Output> {
        let attempt: AgentInferenceAttemptResult<Inference.Output>

        do {
            attempt = try await attempts.execute(
                inference,
                input: input,
                realization: realization,
                priorAttempts: [],
                additionalRequirements: AgentModelRequirements(
                    capabilities: [
                        .reasoning,
                    ]
                )
            )
        } catch let failure as AgentInferenceAttemptFailure {
            throw AgentInferenceExecutionFailure(
                attempt: failure,
                inference: inference.definition.identifier,
                strategy: identifier,
                budget: realization.budget,
                metadata: realization.metadata
            )
        }

        return AgentInferenceExecutionResult(
            output: attempt.output,
            record: AgentInferenceExecutionRecord(
                inference: inference.definition.identifier,
                strategy: identifier,
                attempts: [
                    attempt.record,
                ],
                budget: realization.budget,
                metadata: realization.metadata
            )
        )
    }
}