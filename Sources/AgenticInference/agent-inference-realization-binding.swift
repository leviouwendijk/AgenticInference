public struct AgentInferenceRealizationBinding:
    Sendable,
    Codable,
    Hashable
{
    public var site: AgentInferenceSiteIdentifier
    public var inference: AgentInferenceIdentifier
    public var realization: AgentInferenceRealization

    public init(
        site: AgentInferenceSiteIdentifier,
        inference: AgentInferenceIdentifier,
        realization: AgentInferenceRealization
    ) {
        self.site = site
        self.inference = inference
        self.realization = realization
    }
}
