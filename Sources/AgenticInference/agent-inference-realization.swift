import Agentic
import Primitives

public struct AgentInferenceDemonstration:
    Sendable,
    Codable,
    Hashable
{
    public var input: JSONValue
    public var output: JSONValue
    public var metadata: [String: String]

    public init(
        input: JSONValue,
        output: JSONValue,
        metadata: [String: String] = [:]
    ) {
        self.input = input
        self.output = output
        self.metadata = metadata
    }
}

public struct AgentInferenceBudget:
    Sendable,
    Codable,
    Hashable
{
    public var maximumAttempts: Int
    public var maximumTotalTokens: Int?
    public var maximumEstimatedUsd: Double?

    public init(
        maximumAttempts: Int,
        maximumTotalTokens: Int? = nil,
        maximumEstimatedUsd: Double? = nil
    ) {
        self.maximumAttempts = maximumAttempts
        self.maximumTotalTokens = maximumTotalTokens
        self.maximumEstimatedUsd = maximumEstimatedUsd
    }

    public static let singleAttempt = Self(
        maximumAttempts: 1
    )
}

public struct AgentInferenceRealization:
    Sendable,
    Codable,
    Hashable
{
    public var strategy: AgentInferenceStrategyIdentifier
    public var adapter: AgentInferenceAdapterIdentifier?
    public var modelSelection: AgentModelSelection
    public var instructions: String
    public var demonstrations: [AgentInferenceDemonstration]
    public var generation: AgentGenerationConfiguration
    public var budget: AgentInferenceBudget
    public var metadata: [String: String]

    public init(
        strategy: AgentInferenceStrategyIdentifier,
        modelSelection: AgentModelSelection,
        instructions: String,
        budget: AgentInferenceBudget,
        adapter: AgentInferenceAdapterIdentifier? = nil,
        demonstrations: [AgentInferenceDemonstration] = [],
        generation: AgentGenerationConfiguration = .default,
        metadata: [String: String] = [:]
    ) {
        self.strategy = strategy
        self.adapter = adapter
        self.modelSelection = modelSelection
        self.instructions = instructions
        self.demonstrations = demonstrations
        self.generation = generation
        self.budget = budget
        self.metadata = metadata
    }
}
