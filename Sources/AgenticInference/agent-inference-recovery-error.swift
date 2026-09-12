import AgenticRecovery
import Foundation

public struct AgentInferenceRecoveryError:
    Error,
    Sendable,
    LocalizedError
{
    public let record: Recovery.Record
    public let message: String

    public init(
        record: Recovery.Record,
        message: String
    ) {
        self.record = record
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}
