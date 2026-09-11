import Foundation

public enum AgentInferenceCandidateScoreParsingError:
    Error,
    Sendable,
    LocalizedError
{
    case nonFinite(Double)

    public var errorDescription: String? {
        switch self {
        case .nonFinite(let value):
            return "Inference candidate score must be finite; received \(value)."
        }
    }
}

public struct AgentInferenceCandidateScore:
    Sendable,
    Codable,
    Hashable
{
    public let score: Double
    public let metadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case score
        case metadata
    }

    private init(
        parsedScore score: Double,
        metadata: [String: String]
    ) {
        self.score = score
        self.metadata = metadata
    }

    public init(
        score: Double,
        metadata: [String: String] = [:]
    ) throws {
        self = try Self.parse(
            score: score,
            metadata: metadata
        )
    }

    public static func parse(
        score: Double,
        metadata: [String: String] = [:]
    ) throws -> Self {
        guard score.isFinite else {
            throw AgentInferenceCandidateScoreParsingError.nonFinite(
                score
            )
        }

        return Self(
            parsedScore: score,
            metadata: metadata
        )
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self = try Self.parse(
            score: try container.decode(
                Double.self,
                forKey: .score
            ),
            metadata: try container.decodeIfPresent(
                [String: String].self,
                forKey: .metadata
            ) ?? [:]
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            score,
            forKey: .score
        )
        try container.encode(
            metadata,
            forKey: .metadata
        )
    }
}

public protocol AgentInferenceCandidateEvaluating: Sendable {
    var identifier: AgentInferenceEvaluatorIdentifier { get }

    func evaluate<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        output: Inference.Output,
        attempt: AgentInferenceAttemptRecord
    ) async throws -> AgentInferenceCandidateScore
}

public struct AgentInferenceSampleEvaluation:
    Sendable,
    Codable,
    Hashable
{
    public let attemptIndex: Int
    public let evaluator: AgentInferenceEvaluatorIdentifier
    public let evaluation: AgentInferenceCandidateScore

    public var score: Double {
        evaluation.score
    }

    public var metadata: [String: String] {
        evaluation.metadata
    }

    private enum CodingKeys: String, CodingKey {
        case attemptIndex
        case evaluator
        case score
        case metadata
    }

    public init(
        attemptIndex: Int,
        evaluator: AgentInferenceEvaluatorIdentifier,
        evaluation: AgentInferenceCandidateScore
    ) {
        self.attemptIndex = attemptIndex
        self.evaluator = evaluator
        self.evaluation = evaluation
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            attemptIndex: try container.decode(
                Int.self,
                forKey: .attemptIndex
            ),
            evaluator: try container.decode(
                AgentInferenceEvaluatorIdentifier.self,
                forKey: .evaluator
            ),
            evaluation: try AgentInferenceCandidateScore.parse(
                score: try container.decode(
                    Double.self,
                    forKey: .score
                ),
                metadata: try container.decodeIfPresent(
                    [String: String].self,
                    forKey: .metadata
                ) ?? [:]
            )
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            attemptIndex,
            forKey: .attemptIndex
        )
        try container.encode(
            evaluator,
            forKey: .evaluator
        )
        try container.encode(
            score,
            forKey: .score
        )
        try container.encode(
            metadata,
            forKey: .metadata
        )
    }
}

public struct AgentInferenceSamplingRecord:
    Sendable,
    Codable,
    Hashable
{
    public var evaluator: AgentInferenceEvaluatorIdentifier
    public var evaluations: [AgentInferenceSampleEvaluation]
    public var selectedAttemptIndex: Int

    public init(
        evaluator: AgentInferenceEvaluatorIdentifier,
        evaluations: [AgentInferenceSampleEvaluation],
        selectedAttemptIndex: Int
    ) {
        self.evaluator = evaluator
        self.evaluations = evaluations
        self.selectedAttemptIndex = selectedAttemptIndex
    }
}
