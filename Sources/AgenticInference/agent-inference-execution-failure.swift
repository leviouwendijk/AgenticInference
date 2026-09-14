import AgenticRecovery
import Foundation

/// Terminal failure of one inference execution.
///
/// Failure is always represented at execution scope. `terminalAttempt` is
/// present only when the execution terminated because a semantic attempt
/// itself failed. Strategy-local failures may occur after successful attempts
/// and therefore have no failed semantic attempt to manufacture.
public struct AgentInferenceExecutionFailure:
    Error,
    Sendable,
    LocalizedError
{
    public let failure: AgentInferenceFailureRecord
    public let record: AgentInferenceExecutionRecord
    public let terminalAttempt: AgentInferenceAttemptFailure?

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

        self.init(
            failure: attempt.failure,
            terminalAttempt: attempt,
            inference: inference,
            strategy: strategy,
            attempts: attempts,
            budget: budget,
            sampling: sampling,
            refinement: refinement,
            metadata: metadata
        )
    }

    public init(
        capturing error: any Error,
        inference: AgentInferenceIdentifier,
        strategy: AgentInferenceStrategyIdentifier,
        attempts: [AgentInferenceAttemptRecord] = [],
        budget: AgentInferenceBudget? = nil,
        sampling: AgentInferenceSamplingRecord? = nil,
        refinement: AgentInferenceRefinementRecord? = nil,
        metadata: [String: String] = [:]
    ) {
        self.init(
            failure: AgentInferenceFailureRecord(
                capturing: error
            ),
            terminalAttempt: nil,
            inference: inference,
            strategy: strategy,
            attempts: attempts,
            budget: budget,
            sampling: sampling,
            refinement: refinement,
            metadata: metadata
        )
    }

    private init(
        failure: AgentInferenceFailureRecord,
        terminalAttempt: AgentInferenceAttemptFailure?,
        inference: AgentInferenceIdentifier,
        strategy: AgentInferenceStrategyIdentifier,
        attempts: [AgentInferenceAttemptRecord],
        budget: AgentInferenceBudget?,
        sampling: AgentInferenceSamplingRecord?,
        refinement: AgentInferenceRefinementRecord?,
        metadata: [String: String]
    ) {
        self.failure = failure
        self.terminalAttempt = terminalAttempt
        self.record = AgentInferenceExecutionRecord(
            inference: inference,
            strategy: strategy,
            attempts: attempts,
            failure: failure,
            budget: budget,
            sampling: sampling,
            refinement: refinement,
            metadata: metadata
        )
    }

    public var recovery: Recovery.Record? {
        failure.recovery
    }

    public var errorDescription: String? {
        failure.message
    }
}
