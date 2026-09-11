public struct AgentInferenceRefinementGuideIdentifier:
    Sendable,
    Codable,
    Hashable,
    RawRepresentable,
    ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        _ rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        stringLiteral value: String
    ) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }
}

public struct AgentInferenceRefinementDecision:
    Sendable,
    Codable,
    Hashable
{
    public var evaluation: AgentInferenceCandidateScore
    public var shouldContinue: Bool
    public var nextInstructions: String?
    public var metadata: [String: String]

    public init(
        evaluation: AgentInferenceCandidateScore,
        shouldContinue: Bool,
        nextInstructions: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.evaluation = evaluation
        self.shouldContinue = shouldContinue
        self.nextInstructions = nextInstructions
        self.metadata = metadata
    }
}

public protocol AgentInferenceRefinementGuiding: Sendable {
    var identifier: AgentInferenceRefinementGuideIdentifier { get }

    func guide<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        output: Inference.Output,
        attempt: AgentInferenceAttemptRecord,
        realization: AgentInferenceRealization
    ) async throws -> AgentInferenceRefinementDecision
}

public struct AgentInferenceRefinementStep:
    Sendable,
    Codable,
    Hashable
{
    public var attemptIndex: Int
    public var guide: AgentInferenceRefinementGuideIdentifier
    public var evaluation: AgentInferenceCandidateScore
    public var continued: Bool
    public var metadata: [String: String]

    public init(
        attemptIndex: Int,
        guide: AgentInferenceRefinementGuideIdentifier,
        evaluation: AgentInferenceCandidateScore,
        continued: Bool,
        metadata: [String: String] = [:]
    ) {
        self.attemptIndex = attemptIndex
        self.guide = guide
        self.evaluation = evaluation
        self.continued = continued
        self.metadata = metadata
    }
}

public enum AgentInferenceRefinementTermination:
    String,
    Sendable,
    Codable,
    Hashable
{
    case guide_stop
    case maximum_attempts
    case maximum_total_tokens
    case token_usage_unavailable
}

public struct AgentInferenceRefinementRecord:
    Sendable,
    Codable,
    Hashable
{
    public var guide: AgentInferenceRefinementGuideIdentifier
    public var steps: [AgentInferenceRefinementStep]
    public var selectedAttemptIndex: Int
    public var lastAttemptIndex: Int
    public var termination: AgentInferenceRefinementTermination

    public init(
        guide: AgentInferenceRefinementGuideIdentifier,
        steps: [AgentInferenceRefinementStep],
        selectedAttemptIndex: Int,
        lastAttemptIndex: Int,
        termination: AgentInferenceRefinementTermination
    ) {
        self.guide = guide
        self.steps = steps
        self.selectedAttemptIndex = selectedAttemptIndex
        self.lastAttemptIndex = lastAttemptIndex
        self.termination = termination
    }
}
