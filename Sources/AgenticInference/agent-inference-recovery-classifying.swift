import AgenticRecovery

public protocol AgentInferenceRecoveryClassifying: Sendable {
    func incident(
        for error: any Error,
        stage: Recovery.Stage,
        inference: AgentInferenceIdentifier,
        attemptIndex: Int,
        invocationIndex: Int
    ) -> Recovery.Incident?
}
