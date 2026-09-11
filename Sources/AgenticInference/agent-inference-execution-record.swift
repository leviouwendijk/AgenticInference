import Agentic

public struct AgentInferenceAttemptRecord: Sendable {
    public var index: Int
    public var adapter: AgentInferenceAdapterIdentifier
    public var route: AgentModelRouteRecord
    public var usage: AgentUsage?
    public var metadata: [String: String]

    public init(
        index: Int,
        adapter: AgentInferenceAdapterIdentifier,
        route: AgentModelRouteRecord,
        usage: AgentUsage? = nil,
        metadata: [String: String] = [:]
    ) {
        self.index = index
        self.adapter = adapter
        self.route = route
        self.usage = usage
        self.metadata = metadata
    }
}

public struct AgentInferenceExecutionRecord: Sendable {
    public var inference: AgentInferenceIdentifier
    public var strategy: AgentInferenceStrategyIdentifier
    public var attempts: [AgentInferenceAttemptRecord]
    public var metadata: [String: String]

    public init(
        inference: AgentInferenceIdentifier,
        strategy: AgentInferenceStrategyIdentifier,
        attempts: [AgentInferenceAttemptRecord] = [],
        metadata: [String: String] = [:]
    ) {
        self.inference = inference
        self.strategy = strategy
        self.attempts = attempts
        self.metadata = metadata
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
