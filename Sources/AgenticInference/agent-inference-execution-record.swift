import Agentic

public struct AgentInferenceInvocationRecord:
    Sendable,
    Codable,
    Hashable
{
    /// Zero-based model invocation index within one semantic inference attempt.
    public var index: Int
    public var selection: AgentModelSelection
    public var route: AgentModelRouteRecord?
    public var usage: AgentUsage?
    public var metadata: [String: String]

    public init(
        index: Int,
        selection: AgentModelSelection,
        route: AgentModelRouteRecord? = nil,
        usage: AgentUsage? = nil,
        metadata: [String: String] = [:]
    ) {
        self.index = index
        self.selection = selection
        self.route = route
        self.usage = usage
        self.metadata = metadata
    }
}

public struct AgentInferenceAttemptRecord:
    Sendable,
    Codable,
    Hashable
{
    /// Zero-based semantic attempt index within the inference strategy.
    public var index: Int
    public var adapter: AgentInferenceAdapterIdentifier

    /// Effective selection and successful terminal route retained as the
    /// compact summary of this semantic attempt.
    public var selection: AgentModelSelection
    public var route: AgentModelRouteRecord
    public var usage: AgentUsage?

    /// Every model invocation performed while realizing this semantic attempt.
    /// Mechanical recovery may therefore append invocations without consuming
    /// another semantic attempt.
    public var invocations: [AgentInferenceInvocationRecord]
    public var metadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case index
        case adapter
        case selection
        case route
        case usage
        case invocations
        case metadata
    }

    public init(
        index: Int,
        adapter: AgentInferenceAdapterIdentifier,
        selection: AgentModelSelection,
        route: AgentModelRouteRecord,
        usage: AgentUsage? = nil,
        invocations: [AgentInferenceInvocationRecord]? = nil,
        metadata: [String: String] = [:]
    ) {
        self.index = index
        self.adapter = adapter
        self.selection = selection
        self.route = route
        self.usage = usage
        self.invocations = invocations ?? [
            AgentInferenceInvocationRecord(
                index: 0,
                selection: selection,
                route: route,
                usage: usage,
                metadata: metadata
            ),
        ]
        self.metadata = metadata
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        let index = try container.decode(
            Int.self,
            forKey: .index
        )
        let adapter = try container.decode(
            AgentInferenceAdapterIdentifier.self,
            forKey: .adapter
        )
        let selection = try container.decode(
            AgentModelSelection.self,
            forKey: .selection
        )
        let route = try container.decode(
            AgentModelRouteRecord.self,
            forKey: .route
        )
        let usage = try container.decodeIfPresent(
            AgentUsage.self,
            forKey: .usage
        )
        let metadata = try container.decodeIfPresent(
            [String: String].self,
            forKey: .metadata
        ) ?? [:]
        let invocations = try container.decodeIfPresent(
            [AgentInferenceInvocationRecord].self,
            forKey: .invocations
        )

        self.init(
            index: index,
            adapter: adapter,
            selection: selection,
            route: route,
            usage: usage,
            invocations: invocations,
            metadata: metadata
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            index,
            forKey: .index
        )
        try container.encode(
            adapter,
            forKey: .adapter
        )
        try container.encode(
            selection,
            forKey: .selection
        )
        try container.encode(
            route,
            forKey: .route
        )
        try container.encodeIfPresent(
            usage,
            forKey: .usage
        )
        try container.encode(
            invocations,
            forKey: .invocations
        )
        try container.encode(
            metadata,
            forKey: .metadata
        )
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
    public var refinement: AgentInferenceRefinementRecord?
    public var metadata: [String: String]

    public init(
        inference: AgentInferenceIdentifier,
        strategy: AgentInferenceStrategyIdentifier,
        attempts: [AgentInferenceAttemptRecord] = [],
        budget: AgentInferenceBudget? = nil,
        sampling: AgentInferenceSamplingRecord? = nil,
        refinement: AgentInferenceRefinementRecord? = nil,
        metadata: [String: String] = [:]
    ) {
        self.inference = inference
        self.strategy = strategy
        self.attempts = attempts
        self.budget = budget
        self.sampling = sampling
        self.refinement = refinement
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
