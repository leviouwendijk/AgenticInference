public protocol AgentInferenceAdapterResolving: Sendable {
    func require(
        _ identifier: AgentInferenceAdapterIdentifier
    ) throws -> any AgentInferenceAdapter
}
