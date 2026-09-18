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
    InferenceStrategy,
    Sendable
{
    public let identifier: InferenceStrategyIdentifier = .sampled

    private let evaluator: any InferenceCandidateEvaluating

    public init(
        evaluator: any InferenceCandidateEvaluating
    ) {
        self.evaluator = evaluator
    }

    public func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext,
        attempts: any InferenceAttemptExecuting
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        var attemptRecords: [InferenceAttemptRecord] = []
        var evaluations: [InferenceSampleEvaluation] = []
        var selectedOutput: InferenceType.Output?
        var selectedAttemptIndex: Int?
        var selectedScore: Double?

        while attemptRecords.count < realization.budget.maximumAttempts {
            let attemptIndex = attemptRecords.count
            let attempt: InferenceAttemptResult<InferenceType.Output>

            do {
                attempt = try await attempts.execute(
                    inference,
                    input: input,
                    realization: realization,
                    context: context,
                    priorAttempts: attemptRecords,
                    additionalRequirements: AgentModelRequirements(
                        capabilities: []
                    )
                )
            } catch let failure as InferenceAttemptFailure {
                let sampling = selectedAttemptIndex.map {
                    InferenceSamplingRecord(
                        evaluator: evaluator.identifier,
                        evaluations: evaluations,
                        selectedAttemptIndex: $0
                    )
                }

                throw InferenceExecutionFailure(
                    attempt: failure,
                    inference: inference.definition.identifier,
                    strategy: identifier,
                    priorAttempts: attemptRecords,
                    budget: realization.budget,
                    sampling: sampling,
                    metadata: realization.metadata
                )
            } catch InferenceBudgetError.maximumTotalTokensReached {
                break
            } catch InferenceBudgetError.totalTokenUsageUnavailable {
                break
            }

            attemptRecords.append(
                attempt.record
            )

            let candidateScore: InferenceCandidateScore

            do {
                candidateScore = try await evaluator.evaluate(
                    inference,
                    input: input,
                    output: attempt.output,
                    attempt: attempt.record
                )
            } catch {
                let sampling = selectedAttemptIndex.map {
                    InferenceSamplingRecord(
                        evaluator: evaluator.identifier,
                        evaluations: evaluations,
                        selectedAttemptIndex: $0
                    )
                }

                throw InferenceExecutionFailure(
                    capturing: error,
                    inference: inference.definition.identifier,
                    strategy: identifier,
                    attempts: attemptRecords,
                    budget: realization.budget,
                    sampling: sampling,
                    metadata: realization.metadata
                )
            }

            evaluations.append(
                InferenceSampleEvaluation(
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

        return InferenceExecutionResult(
            output: selectedOutput,
            record: InferenceExecutionRecord(
                inference: inference.definition.identifier,
                strategy: identifier,
                attempts: attemptRecords,
                budget: realization.budget,
                sampling: InferenceSamplingRecord(
                    evaluator: evaluator.identifier,
                    evaluations: evaluations,
                    selectedAttemptIndex: selectedAttemptIndex
                ),
                metadata: realization.metadata
            )
        )
    }
}
