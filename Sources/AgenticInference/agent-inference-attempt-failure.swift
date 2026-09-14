import Agentic
import AgenticRecovery
import Foundation

/// Terminal failure of one semantic inference attempt.
///
/// The record is the canonical evidence accumulated by the attempt before it
/// became unable to continue. Higher execution layers may add strategy-level
/// context, but must not reconstruct or discard this evidence.
public struct AgentInferenceAttemptFailure:
    Error,
    Sendable,
    LocalizedError
{
    public let failure: AgentInferenceFailureRecord
    public let record: AgentInferenceAttemptRecord

    public init(
        index: Int,
        adapter: AgentInferenceAdapterIdentifier,
        selection: AgentModelSelection,
        failure: AgentInferenceFailureRecord,
        invocations: [AgentInferenceInvocationRecord] = [],
        recoveries: [Recovery.Record] = [],
        metadata: [String: String] = [:]
    ) {
        self.failure = failure
        self.record = AgentInferenceAttemptRecord(
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
