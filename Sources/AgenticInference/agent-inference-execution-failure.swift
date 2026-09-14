import AgenticRecovery
import Foundation

/// Terminal failure of one inference execution.
///
/// The attempt is the exact lower-layer terminal semantic-attempt failure.
/// The execution record adds strategy-level context without reconstructing or
/// discarding the evidence accumulated by that attempt.
public struct AgentInferenceExecutionFailure:
    Error,
    Sendable,
    LocalizedError
{
    public let attempt: AgentInferenceAttemptFailure
    public let record: AgentInferenceExecutionRecord

    public init(
        attempt: AgentInferenceAttemptFailure,
        inference: AgentInferenceIdentifier,
        strategy: AgentInferenceStrategyIdentifier,
        priorAttempts: [AgentInferenceAttemptRecord] = [],
        budget: AgentInferenceBudget? = nil,
        sampling: AgentInferenceSamplingRecord? = nil,
        refinement: AgentInferenceRefinementRecord? = nil,
        metadata: [String: String] = [:]
    ) {
        var attempts = priorAttempts
        attempts.append(attempt.record)

        self.attempt = attempt
        self.record = AgentInferenceExecutionRecord(
            inference: inference,
            strategy: strategy,
            attempts: attempts,
            budget: budget,
            sampling: sampling,
            refinement: refinement,
            metadata: metadata
        )
    }

    public var failure: AgentInferenceFailureRecord {
        attempt.failure
    }

    public var recovery: Recovery.Record? {
        attempt.recovery
    }

    public var errorDescription: String? {
        failure.message
    }
}
