import Agentic

public struct InferenceExecutor:
    InferenceExecuting,
    Sendable
{
    private let strategies: any InferenceStrategyResolving
    private let attempts: InferenceAttemptExecutor

    public init(
        modelInvoker: any AgentModelInvoking,
        adapters: any InferenceAdapterResolving,
        defaultAdapterIdentifier: InferenceAdapterIdentifier? = nil,
        strategies: (any InferenceStrategyResolving)? = nil,
        sampleEvaluator: (any InferenceCandidateEvaluating)? = nil,
        refinementGuide: (any InferenceRefinementGuiding)? = nil,
        recoveryClassifier: (any InferenceRecoveryClassifying)? = nil
    ) {
        if let strategies {
            self.strategies = strategies
        } else {
            self.strategies = InferenceStrategyCatalog.configured(
                sampleEvaluator: sampleEvaluator,
                refinementGuide: refinementGuide
            )
        }

        self.attempts = InferenceAttemptExecutor(
            modelInvoker: modelInvoker,
            adapters: adapters,
            defaultAdapterIdentifier: defaultAdapterIdentifier,
            recoveryClassifier: recoveryClassifier
        )
    }

    public func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        let strategy = try strategies.require(
            realization.strategy
        )

        return try await strategy.execute(
            inference,
            input: input,
            realization: realization,
            context: context,
            attempts: attempts
        )
    }
}
