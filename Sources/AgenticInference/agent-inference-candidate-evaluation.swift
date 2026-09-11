public struct AgentInferenceCandidateScore:
    Sendable,
    Codable,
    Hashable
{
    public var score: Double
    public var metadata: [String: String]

    public init(
        score: Double,
        metadata: [String: String] = [:]
    ) {
        self.score = score
        self.metadata = metadata
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
    public var attemptIndex: Int
    public var evaluator: AgentInferenceEvaluatorIdentifier
    public var score: Double
    public var metadata: [String: String]

    public init(
        attemptIndex: Int,
        evaluator: AgentInferenceEvaluatorIdentifier,
        score: Double,
        metadata: [String: String] = [:]
    ) {
        self.attemptIndex = attemptIndex
        self.evaluator = evaluator
        self.score = score
        self.metadata = metadata
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
