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

    public func execute(
        _ invocation: InferenceInvocation
    ) async throws -> InferenceInvocationResult {
        try await invocation.execute(
            strategies: strategies,
            attempts: attempts
        )
    }
}
