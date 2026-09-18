import Agentic
import AgenticRecovery

public enum InferenceInvocationOutcome:
    Sendable,
    Codable,
    Hashable
{
    public struct Success:
        Sendable,
        Codable,
        Hashable
    {
        public let route: AgentModelRouteRecord
        public let usage: AgentUsage?

        public init(
            route: AgentModelRouteRecord,
            usage: AgentUsage? = nil
        ) {
            self.route = route
            self.usage = usage
        }
    }

    public struct Failure:
        Sendable,
        Codable,
        Hashable
    {
        public let message: String
        public let incident: Recovery.Incident?

        public init(
            message: String,
            incident: Recovery.Incident? = nil
        ) {
            self.message = message
            self.incident = incident
        }
    }

    case succeeded(Success)
    case failed(Failure)
}

public struct InferenceInvocationRecord:
    Sendable,
    Codable,
    Hashable
{
    public let index: Int
    public let selection: AgentModelSelection
    public let outcome: InferenceInvocationOutcome
    public let metadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case index
        case selection
        case outcome
        case route
        case usage
        case metadata
    }

    public init(
        index: Int,
        selection: AgentModelSelection,
        outcome: InferenceInvocationOutcome,
        metadata: [String: String] = [:]
    ) {
        self.index = index
        self.selection = selection
        self.outcome = outcome
        self.metadata = metadata
    }

    public init(
        index: Int,
        selection: AgentModelSelection,
        route: AgentModelRouteRecord,
        usage: AgentUsage? = nil,
        metadata: [String: String] = [:]
    ) {
        self.init(
            index: index,
            selection: selection,
            outcome: .succeeded(
                .init(
                    route: route,
                    usage: usage
                )
            ),
            metadata: metadata
        )
    }

    public var route: AgentModelRouteRecord? {
        switch outcome {
        case .succeeded(let success):
            success.route

        case .failed:
            nil
        }
    }

    public var usage: AgentUsage? {
        switch outcome {
        case .succeeded(let success):
            success.usage

        case .failed:
            nil
        }
    }

    public var incident: Recovery.Incident? {
        switch outcome {
        case .succeeded:
            nil

        case .failed(let failure):
            failure.incident
        }
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
        let selection = try container.decode(
            AgentModelSelection.self,
            forKey: .selection
        )
        let metadata = try container.decodeIfPresent(
            [String: String].self,
            forKey: .metadata
        ) ?? [:]

        if let outcome = try container.decodeIfPresent(
            InferenceInvocationOutcome.self,
            forKey: .outcome
        ) {
            self.init(
                index: index,
                selection: selection,
                outcome: outcome,
                metadata: metadata
            )
            return
        }

        self.init(
            index: index,
            selection: selection,
            route: try container.decode(
                AgentModelRouteRecord.self,
                forKey: .route
            ),
            usage: try container.decodeIfPresent(
                AgentUsage.self,
                forKey: .usage
            ),
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
            selection,
            forKey: .selection
        )
        try container.encode(
            outcome,
            forKey: .outcome
        )
        try container.encode(
            metadata,
            forKey: .metadata
        )
    }
}

public enum InferenceAttemptOutcome:
    Sendable,
    Codable,
    Hashable
{
    public struct Success:
        Sendable,
        Codable,
        Hashable
    {
        public let route: AgentModelRouteRecord
        public let usage: AgentUsage?

        public init(
            route: AgentModelRouteRecord,
            usage: AgentUsage? = nil
        ) {
            self.route = route
            self.usage = usage
        }
    }

    case succeeded(Success)
    case failed(InferenceFailureRecord)
}

public struct InferenceAttemptRecord:
    Sendable,
    Codable,
    Hashable
{
    public var index: Int
    public var adapter: InferenceAdapterIdentifier
    public var selection: AgentModelSelection
    public var outcome: InferenceAttemptOutcome
    public var invocations: [InferenceInvocationRecord]
    public var recoveries: [Recovery.Record]
    public var metadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case index
        case adapter
        case selection
        case outcome
        case route
        case usage
        case invocations
        case recoveries
        case metadata
    }

    public init(
        index: Int,
        adapter: InferenceAdapterIdentifier,
        selection: AgentModelSelection,
        outcome: InferenceAttemptOutcome,
        invocations: [InferenceInvocationRecord]? = nil,
        recoveries: [Recovery.Record] = [],
        metadata: [String: String] = [:]
    ) {
        self.index = index
        self.adapter = adapter
        self.selection = selection
        self.outcome = outcome

        if let invocations {
            self.invocations = invocations
        } else {
            switch outcome {
            case .succeeded(let success):
                self.invocations = [
                    InferenceInvocationRecord(
                        index: 0,
                        selection: selection,
                        route: success.route,
                        usage: success.usage,
                        metadata: metadata
                    ),
                ]

            case .failed:
                self.invocations = []
            }
        }

        self.recoveries = recoveries
        self.metadata = metadata
    }

    public init(
        index: Int,
        adapter: InferenceAdapterIdentifier,
        selection: AgentModelSelection,
        route: AgentModelRouteRecord,
        usage: AgentUsage? = nil,
        invocations: [InferenceInvocationRecord]? = nil,
        recoveries: [Recovery.Record] = [],
        metadata: [String: String] = [:]
    ) {
        self.init(
            index: index,
            adapter: adapter,
            selection: selection,
            outcome: .succeeded(
                .init(
                    route: route,
                    usage: usage
                )
            ),
            invocations: invocations,
            recoveries: recoveries,
            metadata: metadata
        )
    }

    public init(
        index: Int,
        adapter: InferenceAdapterIdentifier,
        selection: AgentModelSelection,
        failure: InferenceFailureRecord,
        invocations: [InferenceInvocationRecord] = [],
        recoveries: [Recovery.Record] = [],
        metadata: [String: String] = [:]
    ) {
        self.init(
            index: index,
            adapter: adapter,
            selection: selection,
            outcome: .failed(failure),
            invocations: invocations,
            recoveries: recoveries,
            metadata: metadata
        )
    }

    public var route: AgentModelRouteRecord? {
        switch outcome {
        case .succeeded(let success):
            success.route

        case .failed:
            nil
        }
    }

    public var usage: AgentUsage? {
        switch outcome {
        case .succeeded(let success):
            success.usage

        case .failed:
            nil
        }
    }

    public var failure: InferenceFailureRecord? {
        switch outcome {
        case .succeeded:
            nil

        case .failed(let failure):
            failure
        }
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
            InferenceAdapterIdentifier.self,
            forKey: .adapter
        )
        let selection = try container.decode(
            AgentModelSelection.self,
            forKey: .selection
        )
        let metadata = try container.decodeIfPresent(
            [String: String].self,
            forKey: .metadata
        ) ?? [:]
        let invocations = try container.decodeIfPresent(
            [InferenceInvocationRecord].self,
            forKey: .invocations
        )
        let recoveries = try container.decodeIfPresent(
            [Recovery.Record].self,
            forKey: .recoveries
        ) ?? []

        let outcome: InferenceAttemptOutcome

        if let decodedOutcome = try container.decodeIfPresent(
            InferenceAttemptOutcome.self,
            forKey: .outcome
        ) {
            outcome = decodedOutcome
        } else {
            outcome = .succeeded(
                .init(
                    route: try container.decode(
                        AgentModelRouteRecord.self,
                        forKey: .route
                    ),
                    usage: try container.decodeIfPresent(
                        AgentUsage.self,
                        forKey: .usage
                    )
                )
            )
        }

        self.init(
            index: index,
            adapter: adapter,
            selection: selection,
            outcome: outcome,
            invocations: invocations,
            recoveries: recoveries,
            metadata: metadata
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(index, forKey: .index)
        try container.encode(adapter, forKey: .adapter)
        try container.encode(selection, forKey: .selection)
        try container.encode(outcome, forKey: .outcome)
        try container.encodeIfPresent(route, forKey: .route)
        try container.encodeIfPresent(usage, forKey: .usage)
        try container.encode(invocations, forKey: .invocations)
        try container.encode(recoveries, forKey: .recoveries)
        try container.encode(metadata, forKey: .metadata)
    }
}

public struct InferenceExecutionRecord:
    Sendable,
    Codable,
    Hashable
{
    public var inference: InferenceIdentifier
    public var strategy: InferenceStrategyIdentifier
    public var attempts: [InferenceAttemptRecord]
    public var failure: InferenceFailureRecord?
    public var budget: InferenceBudget?
    public var sampling: InferenceSamplingRecord?
    public var refinement: InferenceRefinementRecord?
    public var metadata: [String: String]

    public init(
        inference: InferenceIdentifier,
        strategy: InferenceStrategyIdentifier,
        attempts: [InferenceAttemptRecord] = [],
        failure: InferenceFailureRecord? = nil,
        budget: InferenceBudget? = nil,
        sampling: InferenceSamplingRecord? = nil,
        refinement: InferenceRefinementRecord? = nil,
        metadata: [String: String] = [:]
    ) {
        self.inference = inference
        self.strategy = strategy
        self.attempts = attempts
        self.failure = failure
        self.budget = budget
        self.sampling = sampling
        self.refinement = refinement
        self.metadata = metadata
    }

    public var budgetUsage: InferenceBudgetUsage {
        InferenceBudgetUsage(
            attempts: attempts
        )
    }
}

public struct InferenceAttemptResult<Output: Sendable>: Sendable {
    public var output: Output
    public var record: InferenceAttemptRecord

    public init(
        output: Output,
        record: InferenceAttemptRecord
    ) {
        self.output = output
        self.record = record
    }
}

public struct InferenceExecutionResult<Output: Sendable>: Sendable {
    public var output: Output
    public var record: InferenceExecutionRecord

    public init(
        output: Output,
        record: InferenceExecutionRecord
    ) {
        self.output = output
        self.record = record
    }
}
