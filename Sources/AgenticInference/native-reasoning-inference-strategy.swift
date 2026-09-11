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
        let attempt = try await attempts.execute(
            inference,
            input: input,
            realization: realization,
            additionalRequirements: AgentModelRequirements(
                capabilities: [
                    .reasoning,
                ]
            ),
            attemptIndex: 0
        )

        return AgentInferenceExecutionResult(
            output: attempt.output,
            record: AgentInferenceExecutionRecord(
                inference: inference.definition.identifier,
                strategy: identifier,
                attempts: [
                    attempt.record,
                ],
                metadata: realization.metadata
            )
        )
    }
}
