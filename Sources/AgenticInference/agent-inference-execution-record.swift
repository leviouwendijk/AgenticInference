import Agentic
import AgenticRecovery

public enum AgentInferenceInvocationOutcome:
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

public struct AgentInferenceInvocationRecord:
    Sendable,
    Codable,
    Hashable
{
    public let index: Int
    public let selection: AgentModelSelection
    public let outcome: AgentInferenceInvocationOutcome
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
        outcome: AgentInferenceInvocationOutcome,
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
            AgentInferenceInvocationOutcome.self,
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

public enum AgentInferenceAttemptOutcome:
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
    case failed(AgentInferenceFailureRecord)
}

public struct AgentInferenceAttemptRecord:
    Sendable,
    Codable,
    Hashable
{
    public var index: Int
    public var adapter: AgentInferenceAdapterIdentifier
    public var selection: AgentModelSelection
    public var outcome: AgentInferenceAttemptOutcome
    public var invocations: [AgentInferenceInvocationRecord]
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
        adapter: AgentInferenceAdapterIdentifier,
        selection: AgentModelSelection,
        outcome: AgentInferenceAttemptOutcome,
        invocations: [AgentInferenceInvocationRecord]? = nil,
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
                    AgentInferenceInvocationRecord(
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
        adapter: AgentInferenceAdapterIdentifier,
        selection: AgentModelSelection,
        route: AgentModelRouteRecord,
        usage: AgentUsage? = nil,
        invocations: [AgentInferenceInvocationRecord]? = nil,
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
        adapter: AgentInferenceAdapterIdentifier,
        selection: AgentModelSelection,
        failure: AgentInferenceFailureRecord,
        invocations: [AgentInferenceInvocationRecord] = [],
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

    public var failure: AgentInferenceFailureRecord? {
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
            AgentInferenceAdapterIdentifier.self,
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
            [AgentInferenceInvocationRecord].self,
            forKey: .invocations
        )
        let recoveries = try container.decodeIfPresent(
            [Recovery.Record].self,
            forKey: .recoveries
        ) ?? []

        let outcome: AgentInferenceAttemptOutcome

        if let decodedOutcome = try container.decodeIfPresent(
            AgentInferenceAttemptOutcome.self,
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

public struct AgentInferenceExecutionRecord:
    Sendable,
    Codable,
    Hashable
{
    public var inference: AgentInferenceIdentifier
    public var strategy: AgentInferenceStrategyIdentifier
    public var attempts: [AgentInferenceAttemptRecord]
    public var failure: AgentInferenceFailureRecord?
    public var budget: AgentInferenceBudget?
    public var sampling: AgentInferenceSamplingRecord?
    public var refinement: AgentInferenceRefinementRecord?
    public var metadata: [String: String]

    public init(
        inference: AgentInferenceIdentifier,
        strategy: AgentInferenceStrategyIdentifier,
        attempts: [AgentInferenceAttemptRecord] = [],
        failure: AgentInferenceFailureRecord? = nil,
        budget: AgentInferenceBudget? = nil,
        sampling: AgentInferenceSamplingRecord? = nil,
        refinement: AgentInferenceRefinementRecord? = nil,
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
