import Agentic
import Foundation

public enum InferenceCandidateScoreParsingError:
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

public struct InferenceCandidateScore:
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

    public init(
        score: Double,
        metadata: [String: String] = [:]
    ) throws {
        guard score.isFinite else {
            throw InferenceCandidateScoreParsingError.nonFinite(
                score
            )
        }

        self.score = score
        self.metadata = metadata
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        try self.init(
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

public protocol InferenceCandidateEvaluating: Sendable {
    var identifier: InferenceEvaluatorIdentifier { get }

    func evaluate<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        output: InferenceType.Output,
        attempt: InferenceAttemptRecord
    ) async throws -> InferenceCandidateScore
}

public struct InferenceSampleEvaluation:
    Sendable,
    Codable,
    Hashable
{
    public let attemptIndex: Int
    public let evaluator: InferenceEvaluatorIdentifier
    public let evaluation: InferenceCandidateScore

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
        evaluator: InferenceEvaluatorIdentifier,
        evaluation: InferenceCandidateScore
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
                InferenceEvaluatorIdentifier.self,
                forKey: .evaluator
            ),
            evaluation: try InferenceCandidateScore(
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

public struct InferenceSamplingRecord:
    Sendable,
    Codable,
    Hashable
{
    public var evaluator: InferenceEvaluatorIdentifier
    public var evaluations: [InferenceSampleEvaluation]
    public var selectedAttemptIndex: Int

    public init(
        evaluator: InferenceEvaluatorIdentifier,
        evaluations: [InferenceSampleEvaluation],
        selectedAttemptIndex: Int
    ) {
        self.evaluator = evaluator
        self.evaluations = evaluations
        self.selectedAttemptIndex = selectedAttemptIndex
    }
}
