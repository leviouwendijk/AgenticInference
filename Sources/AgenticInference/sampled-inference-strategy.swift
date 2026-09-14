import Agentic
import Foundation

public enum SampledInferenceStrategyError:
    Error,
    Sendable,
    LocalizedError
{
    case noSamplesProduced

    public var errorDescription: String? {
        switch self {
        case .noSamplesProduced:
            return "Sampled inference did not produce any candidate outputs."
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
                    )
                )
            } catch let failure as AgentInferenceAttemptFailure {
                let sampling = selectedAttemptIndex.map {
                    AgentInferenceSamplingRecord(
                        evaluator: evaluator.identifier,
                        evaluations: evaluations,
                        selectedAttemptIndex: $0
                    )
                }

                throw AgentInferenceExecutionFailure(
                    attempt: failure,
                    inference: inference.definition.identifier,
                    strategy: identifier,
                    priorAttempts: attemptRecords,
                    budget: realization.budget,
                    sampling: sampling,
                    metadata: realization.metadata
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

            evaluations.append(
                AgentInferenceSampleEvaluation(
                    attemptIndex: attemptIndex,
                    evaluator: evaluator.identifier,
                    evaluation: candidateScore
                )
            )

            if let currentSelectedScore = selectedScore {
                if candidateScore.score > currentSelectedScore {
                    selectedScore = candidateScore.score
                    selectedAttemptIndex = attemptIndex
                    selectedOutput = attempt.output
                }
            } else {
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
