import AgenticRecovery
import Foundation

public struct InferenceRecoveryError:
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

    init(
        propagating incident: Recovery.Incident,
        plan: Recovery.Plan? = nil,
        message: String
    ) {
        self.init(
            record: Recovery.Record(
                incident: incident,
                plan: plan,
                attempts: [],
                outcome: .propagated
            ),
            message: message
        )
    }

    public var errorDescription: String? {
        message
    }
}
