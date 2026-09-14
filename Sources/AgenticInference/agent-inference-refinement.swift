import Foundation
import Primitives

public struct AgentInferenceRefinementGuideIdentifier:
    StringIdentifier
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

public enum AgentInferenceRefinementInstructionsParsingError:
    Error,
    Sendable,
    LocalizedError
{
    case empty

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "Inference refinement instructions cannot be empty."
        }
    }
}

public struct AgentInferenceRefinementInstructions:
    Sendable,
    Codable,
    Hashable
{
    public let value: String

    public init(
        _ value: String
    ) throws {
        let normalized = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalized.isEmpty else {
            throw AgentInferenceRefinementInstructionsParsingError.empty
        }

        self.value = normalized
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()
        try self.init(
            try container.decode(
                String.self
            )
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.singleValueContainer()
        try container.encode(
            value
        )
    }
}

public enum AgentInferenceRefinementDirective:
    Sendable,
    Codable,
    Hashable
{
    case stop
    case continueWith(AgentInferenceRefinementInstructions)
}

public struct AgentInferenceRefinementDecision:
    Sendable,
    Codable,
    Hashable
{
    public let evaluation: AgentInferenceCandidateScore
    public let directive: AgentInferenceRefinementDirective
    public let metadata: [String: String]

    public init(
        evaluation: AgentInferenceCandidateScore,
        directive: AgentInferenceRefinementDirective,
        metadata: [String: String] = [:]
    ) {
        self.evaluation = evaluation
        self.directive = directive
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
    case attempt_failed
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
