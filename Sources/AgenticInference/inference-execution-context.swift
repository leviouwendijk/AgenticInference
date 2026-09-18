import Agentic

public struct InferenceExecutionContext: Sendable {
    public var modelSelection: AgentModelSelection
    public var requirements: AgentModelRequirements

    public init(
        modelSelection: AgentModelSelection = .executor,
        requirements: AgentModelRequirements = AgentModelRequirements(
            capabilities: []
        )
    ) {
        self.modelSelection = modelSelection
        self.requirements = requirements
    }

    public static let `default` = Self()
}
