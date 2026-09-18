import Agentic
import AgenticRecovery

public protocol InferenceRecoveryClassifying: Sendable {
    func incident(
        for error: any Error,
        stage: Recovery.Stage,
        inference: InferenceIdentifier,
        attemptIndex: Int,
        invocationIndex: Int
    ) -> Recovery.Incident?
}
