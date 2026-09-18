import Agentic

public struct DirectInferenceStrategy:
    InferenceStrategy,
    Sendable
{
    public let identifier: InferenceStrategyIdentifier = .direct

    public init() {}

    public func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext,
        attempts: any InferenceAttemptExecuting
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        let attempt: InferenceAttemptResult<InferenceType.Output>

        do {
            attempt = try await attempts.execute(
                inference,
                input: input,
                realization: realization,
                context: context,
                priorAttempts: [],
                additionalRequirements: AgentModelRequirements(
                    capabilities: []
                )
            )
        } catch let failure as InferenceAttemptFailure {
            throw InferenceExecutionFailure(
                attempt: failure,
                inference: inference.definition.identifier,
                strategy: identifier,
                budget: realization.budget,
                metadata: realization.metadata
            )
        }

        return InferenceExecutionResult(
            output: attempt.output,
            record: InferenceExecutionRecord(
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
