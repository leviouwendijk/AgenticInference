import Agentic
import AgenticRecovery
import Foundation

/// Terminal failure of one semantic inference attempt.
///
/// The record is the canonical evidence accumulated by the attempt before it
/// became unable to continue. Higher execution layers may add strategy-level
/// context, but must not reconstruct or discard this evidence.
public struct InferenceAttemptFailure:
    Error,
    Sendable,
    LocalizedError
{
    public let failure: InferenceFailureRecord
    public let record: InferenceAttemptRecord

    public init(
        index: Int,
        adapter: InferenceAdapterIdentifier,
        selection: AgentModelSelection,
        failure: InferenceFailureRecord,
        invocations: [InferenceInvocationRecord] = [],
        recoveries: [Recovery.Record] = [],
        metadata: [String: String] = [:]
    ) {
        self.failure = failure
        self.record = InferenceAttemptRecord(
            index: index,
            adapter: adapter,
            selection: selection,
            failure: failure,
            invocations: invocations,
            recoveries: recoveries,
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
