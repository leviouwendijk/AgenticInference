import Agentic
import Foundation

public enum InferenceExecutionError:
    Error,
    Sendable,
    LocalizedError
{
    case adapterUnspecified(
        inference: InferenceIdentifier
    )

    public var errorDescription: String? {
        switch self {
        case .adapterUnspecified(let inference):
            return "No inference adapter was specified for '\(inference.rawValue)', and no default inference adapter is configured."
        }
    }
}
