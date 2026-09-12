import Agentic

public struct AgentInferenceExecutor:
    AgentInferenceExecuting,
    Sendable
{
    private let strategies: any AgentInferenceStrategyResolving
    private let attempts: AgentInferenceAttemptExecutor

    public init(
        modelInvoker: any AgentModelInvoking,
        adapters: any AgentInferenceAdapterResolving,
        defaultAdapterIdentifier: AgentInferenceAdapterIdentifier? = nil,
        strategies: (any AgentInferenceStrategyResolving)? = nil,
        sampleEvaluator: (any AgentInferenceCandidateEvaluating)? = nil,
        refinementGuide: (any AgentInferenceRefinementGuiding)? = nil,
        recoveryClassifier: (any AgentInferenceRecoveryClassifying)? = nil
    ) {
        if let strategies {
            self.strategies = strategies
        } else {
            self.strategies = AgentInferenceStrategyCatalog.configured(
                sampleEvaluator: sampleEvaluator,
                refinementGuide: refinementGuide
            )
        }

        self.attempts = AgentInferenceAttemptExecutor(
            modelInvoker: modelInvoker,
            adapters: adapters,
            defaultAdapterIdentifier: defaultAdapterIdentifier,
            recoveryClassifier: recoveryClassifier
        )
    }

    public func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization
    ) async throws -> AgentInferenceExecutionResult<Inference.Output> {
        let strategy = try strategies.require(
            realization.strategy
        )

        return try await strategy.execute(
            inference,
            input: input,
            realization: realization,
            attempts: attempts
        )
    }
}
