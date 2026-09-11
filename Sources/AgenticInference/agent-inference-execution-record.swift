import Agentic

public struct AgentInferenceAttemptRecord:
    Sendable,
    Codable,
    Hashable
{
    public var index: Int
    public var adapter: AgentInferenceAdapterIdentifier
    public var selection: AgentModelSelection
    public var route: AgentModelRouteRecord
    public var usage: AgentUsage?
    public var metadata: [String: String]

    public init(
        index: Int,
        adapter: AgentInferenceAdapterIdentifier,
        selection: AgentModelSelection,
        route: AgentModelRouteRecord,
        usage: AgentUsage? = nil,
        metadata: [String: String] = [:]
    ) {
        self.index = index
        self.adapter = adapter
        self.selection = selection
        self.route = route
        self.usage = usage
        self.metadata = metadata
    }
}

public struct AgentInferenceExecutionRecord:
    Sendable,
    Codable,
    Hashable
{
    public var inference: AgentInferenceIdentifier
    public var strategy: AgentInferenceStrategyIdentifier
    public var attempts: [AgentInferenceAttemptRecord]
    public var budget: AgentInferenceBudget?
    public var sampling: AgentInferenceSamplingRecord?
    public var metadata: [String: String]

    public init(
        inference: AgentInferenceIdentifier,
        strategy: AgentInferenceStrategyIdentifier,
        attempts: [AgentInferenceAttemptRecord] = [],
        budget: AgentInferenceBudget? = nil,
        sampling: AgentInferenceSamplingRecord? = nil,
        metadata: [String: String] = [:]
    ) {
        self.inference = inference
        self.strategy = strategy
        self.attempts = attempts
        self.budget = budget
        self.sampling = sampling
        self.metadata = metadata
    }

    public var budgetUsage: AgentInferenceBudgetUsage {
        AgentInferenceBudgetUsage(
            attempts: attempts
        )
    }
}

public struct AgentInferenceAttemptResult<Output: Sendable>: Sendable {
    public var output: Output
    public var record: AgentInferenceAttemptRecord

    public init(
        output: Output,
        record: AgentInferenceAttemptRecord
    ) {
        self.output = output
        self.record = record
    }
}

public struct AgentInferenceExecutionResult<Output: Sendable>: Sendable {
    public var output: Output
    public var record: AgentInferenceExecutionRecord

    public init(
        output: Output,
        record: AgentInferenceExecutionRecord
    ) {
        self.output = output
        self.record = record
    }
}
