import AgenticRecovery
import Foundation

/// Durable, transport-neutral evidence describing why inference work failed.
///
/// Recovery is operation evidence, not the semantic decision a caller may make
/// after the failure propagates.
public struct AgentInferenceFailureRecord:
    Sendable,
    Codable,
    Hashable
{
    public let type: String
    public let message: String
    public let recovery: Recovery.Record?

    public init(
        type: String,
        message: String,
        recovery: Recovery.Record? = nil
    ) {
        self.type = type
        self.message = message
        self.recovery = recovery
    }

    public init(
        capturing error: any Error,
        recovery: Recovery.Record? = nil
    ) {
        self.init(
            type: String(
                reflecting: Swift.type(of: error)
            ),
            message: error.localizedDescription,
            recovery: recovery
        )
    }
}
