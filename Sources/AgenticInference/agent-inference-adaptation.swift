import Agentic

public struct AgentInferenceAdaptation: Sendable {
    public var request: AgentRequest
    public var requirements: AgentModelRequirements

    public init(
        request: AgentRequest,
        requirements: AgentModelRequirements = AgentModelRequirements(
            capabilities: []
        )
    ) {
        self.request = request
        self.requirements = requirements
    }
}
