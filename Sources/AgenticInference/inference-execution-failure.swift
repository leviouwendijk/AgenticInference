import Agentic
import AgenticRecovery
import Foundation

/// Terminal failure of one inference execution.
///
/// Failure is always represented at execution scope. `terminalAttempt` is
/// present only when the execution terminated because a semantic attempt
/// itself failed. Strategy-local failures may occur after successful attempts
/// and therefore have no failed semantic attempt to manufacture.
public struct InferenceExecutionFailure:
    Error,
    Sendable,
    LocalizedError
{
    public let failure: InferenceFailureRecord
    public let record: InferenceExecutionRecord
    public let terminalAttempt: InferenceAttemptFailure?

    public init(
        attempt: InferenceAttemptFailure,
        inference: InferenceIdentifier,
        strategy: InferenceStrategyIdentifier,
        priorAttempts: [InferenceAttemptRecord] = [],
        budget: InferenceBudget? = nil,
        sampling: InferenceSamplingRecord? = nil,
        refinement: InferenceRefinementRecord? = nil,
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
        inference: InferenceIdentifier,
        strategy: InferenceStrategyIdentifier,
        attempts: [InferenceAttemptRecord] = [],
        budget: InferenceBudget? = nil,
        sampling: InferenceSamplingRecord? = nil,
        refinement: InferenceRefinementRecord? = nil,
        metadata: [String: String] = [:]
    ) {
        self.init(
            failure: InferenceFailureRecord(
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
        failure: InferenceFailureRecord,
        terminalAttempt: InferenceAttemptFailure?,
        inference: InferenceIdentifier,
        strategy: InferenceStrategyIdentifier,
        attempts: [InferenceAttemptRecord],
        budget: InferenceBudget?,
        sampling: InferenceSamplingRecord?,
        refinement: InferenceRefinementRecord?,
        metadata: [String: String]
    ) {
        self.failure = failure
        self.terminalAttempt = terminalAttempt
        self.record = InferenceExecutionRecord(
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
