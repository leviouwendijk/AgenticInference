import Agentic

public protocol InferenceAdapterResolving: Sendable {
    func require(
        _ identifier: InferenceAdapterIdentifier
    ) throws -> any InferenceAdapter
}
