import Agentic
import Foundation
import Primitives

public struct InferenceRefinementGuideIdentifier:
    StringIdentifier
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

public enum InferenceRefinementInstructionsParsingError:
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

public struct InferenceRefinementInstructions:
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
            throw InferenceRefinementInstructionsParsingError.empty
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

public enum InferenceRefinementDirective:
    Sendable,
    Codable,
    Hashable
{
    case stop
    case continueWith(InferenceRefinementInstructions)
}

public struct InferenceRefinementDecision:
    Sendable,
    Codable,
    Hashable
{
    public let evaluation: InferenceCandidateScore
    public let directive: InferenceRefinementDirective
    public let metadata: [String: String]

    public init(
        evaluation: InferenceCandidateScore,
        directive: InferenceRefinementDirective,
        metadata: [String: String] = [:]
    ) {
        self.evaluation = evaluation
        self.directive = directive
        self.metadata = metadata
    }
}

public protocol InferenceRefinementGuiding: Sendable {
    var identifier: InferenceRefinementGuideIdentifier { get }

    func guide<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        output: InferenceType.Output,
        attempt: InferenceAttemptRecord,
        realization: InferenceRealizationConfiguration
    ) async throws -> InferenceRefinementDecision
}

public struct InferenceRefinementStep:
    Sendable,
    Codable,
    Hashable
{
    public var attemptIndex: Int
    public var guide: InferenceRefinementGuideIdentifier
    public var evaluation: InferenceCandidateScore
    public var continued: Bool
    public var metadata: [String: String]

    public init(
        attemptIndex: Int,
        guide: InferenceRefinementGuideIdentifier,
        evaluation: InferenceCandidateScore,
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

public enum InferenceRefinementTermination:
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
    case guide_failed
}

public struct InferenceRefinementRecord:
    Sendable,
    Codable,
    Hashable
{
    public var guide: InferenceRefinementGuideIdentifier
    public var steps: [InferenceRefinementStep]
    public var selectedAttemptIndex: Int
    public var lastAttemptIndex: Int
    public var termination: InferenceRefinementTermination

    public init(
        guide: InferenceRefinementGuideIdentifier,
        steps: [InferenceRefinementStep],
        selectedAttemptIndex: Int,
        lastAttemptIndex: Int,
        termination: InferenceRefinementTermination
    ) {
        self.guide = guide
        self.steps = steps
        self.selectedAttemptIndex = selectedAttemptIndex
        self.lastAttemptIndex = lastAttemptIndex
        self.termination = termination
    }
}
