import Agentic
import Foundation

public enum SampledInferenceStrategyError:
    Error,
    Sendable,
    LocalizedError
{
    case noSamplesProduced
    case invalidScore(
        evaluator: AgentInferenceEvaluatorIdentifier,
        attemptIndex: Int
    )

    public var errorDescription: String? {
        switch self {
        case .noSamplesProduced:
            return "Sampled inference did not produce any candidate outputs."

        case .invalidScore(
            let evaluator,
            let attemptIndex
        ):
            return "Inference evaluator '\(evaluator.rawValue)' returned a non-finite score for attempt \(attemptIndex)."
        }
    }
}

public struct SampledInferenceStrategy:
    AgentInferenceStrategy,
    Sendable
{
    public let identifier: AgentInferenceStrategyIdentifier = .sampled

    private let evaluator: any AgentInferenceCandidateEvaluating

    public init(
        evaluator: any AgentInferenceCandidateEvaluating
    ) {
        self.evaluator = evaluator
    }

    public func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization,
        attempts: any AgentInferenceAttemptExecuting
    ) async throws -> AgentInferenceExecutionResult<Inference.Output> {
        var attemptRecords: [AgentInferenceAttemptRecord] = []
        var evaluations: [AgentInferenceSampleEvaluation] = []
        var selectedOutput: Inference.Output?
        var selectedAttemptIndex: Int?
        var selectedScore: Double?

        while attemptRecords.count < realization.budget.maximumAttempts {
            let attemptIndex = attemptRecords.count
            let attempt: AgentInferenceAttemptResult<Inference.Output>

            do {
                attempt = try await attempts.execute(
                    inference,
                    input: input,
                    realization: realization,
                    priorAttempts: attemptRecords,
                    additionalRequirements: AgentModelRequirements(
                        capabilities: []
                    ),
                    attemptIndex: attemptIndex
                )
            } catch AgentInferenceBudgetError.maximumTotalTokensReached {
                break
            } catch AgentInferenceBudgetError.totalTokenUsageUnavailable {
                break
            }

            attemptRecords.append(
                attempt.record
            )

            let candidateScore = try await evaluator.evaluate(
                inference,
                input: input,
                output: attempt.output,
                attempt: attempt.record
            )

            guard candidateScore.score.isFinite else {
                throw SampledInferenceStrategyError.invalidScore(
                    evaluator: evaluator.identifier,
                    attemptIndex: attemptIndex
                )
            }

            evaluations.append(
                AgentInferenceSampleEvaluation(
                    attemptIndex: attemptIndex,
                    evaluator: evaluator.identifier,
                    score: candidateScore.score,
                    metadata: candidateScore.metadata
                )
            )

            if selectedScore == nil
                || candidateScore.score > selectedScore!
            {
                selectedScore = candidateScore.score
                selectedAttemptIndex = attemptIndex
                selectedOutput = attempt.output
            }
        }

        guard
            let selectedOutput,
            let selectedAttemptIndex
        else {
            throw SampledInferenceStrategyError.noSamplesProduced
        }

        return AgentInferenceExecutionResult(
            output: selectedOutput,
            record: AgentInferenceExecutionRecord(
                inference: inference.definition.identifier,
                strategy: identifier,
                attempts: attemptRecords,
                budget: realization.budget,
                sampling: AgentInferenceSamplingRecord(
                    evaluator: evaluator.identifier,
                    evaluations: evaluations,
                    selectedAttemptIndex: selectedAttemptIndex
                ),
                metadata: realization.metadata
            )
        )
    }
}
