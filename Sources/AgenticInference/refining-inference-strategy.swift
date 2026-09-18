import Agentic
import Foundation

public enum RefiningInferenceStrategyError:
    Error,
    Sendable,
    LocalizedError
{
    case noCandidatesProduced

    public var errorDescription: String? {
        switch self {
        case .noCandidatesProduced:
            return "Refining inference did not produce any candidate outputs."
        }
    }
}

public struct RefiningInferenceStrategy:
    InferenceStrategy,
    Sendable
{
    public let identifier: InferenceStrategyIdentifier = .refining

    private let guide: any InferenceRefinementGuiding

    public init(
        guide: any InferenceRefinementGuiding
    ) {
        self.guide = guide
    }

    public func execute<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext,
        attempts: any InferenceAttemptExecuting
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        var attemptRecords: [InferenceAttemptRecord] = []
        var refinementSteps: [InferenceRefinementStep] = []
        var currentRealization = realization

        var selectedOutput: InferenceType.Output?
        var selectedScore: Double?
        var selectedAttemptIndex: Int?
        var lastAttemptIndex: Int?
        var termination: InferenceRefinementTermination?

        refinementLoop: while
            attemptRecords.count < realization.budget.maximumAttempts
        {
            let attemptIndex = attemptRecords.count
            let attempt: InferenceAttemptResult<InferenceType.Output>

            do {
                attempt = try await attempts.execute(
                    inference,
                    input: input,
                    realization: currentRealization,
                    context: context,
                    priorAttempts: attemptRecords,
                    additionalRequirements: AgentModelRequirements(
                        capabilities: []
                    )
                )
            } catch let failure as InferenceAttemptFailure {
                let refinement = selectedAttemptIndex.map {
                    InferenceRefinementRecord(
                        guide: guide.identifier,
                        steps: refinementSteps,
                        selectedAttemptIndex: $0,
                        lastAttemptIndex: failure.record.index,
                        termination: .attempt_failed
                    )
                }

                throw InferenceExecutionFailure(
                    attempt: failure,
                    inference: inference.definition.identifier,
                    strategy: identifier,
                    priorAttempts: attemptRecords,
                    budget: realization.budget,
                    refinement: refinement,
                    metadata: realization.metadata
                )
            } catch let error as InferenceBudgetError {
                switch error {
                case .maximumTotalTokensReached(_, _):
                    guard selectedOutput != nil else {
                        throw error
                    }

                    termination = .maximum_total_tokens
                    break refinementLoop

                case .totalTokenUsageUnavailable(_, _):
                    guard selectedOutput != nil else {
                        throw error
                    }

                    termination = .token_usage_unavailable
                    break refinementLoop

                case .maximumAttemptsReached(_, _):
                    throw error
                }
            }

            attemptRecords.append(
                attempt.record
            )
            lastAttemptIndex = attemptIndex

            let decision: InferenceRefinementDecision

            do {
                decision = try await guide.guide(
                    inference,
                    input: input,
                    output: attempt.output,
                    attempt: attempt.record,
                    realization: currentRealization
                )
            } catch {
                let refinement = selectedAttemptIndex.map {
                    InferenceRefinementRecord(
                        guide: guide.identifier,
                        steps: refinementSteps,
                        selectedAttemptIndex: $0,
                        lastAttemptIndex: attemptIndex,
                        termination: .guide_failed
                    )
                }

                throw InferenceExecutionFailure(
                    capturing: error,
                    inference: inference.definition.identifier,
                    strategy: identifier,
                    attempts: attemptRecords,
                    budget: realization.budget,
                    refinement: refinement,
                    metadata: realization.metadata
                )
            }

            let continued: Bool
            switch decision.directive {
            case .stop:
                continued = false

            case .continueWith:
                continued = true
            }

            refinementSteps.append(
                InferenceRefinementStep(
                    attemptIndex: attemptIndex,
                    guide: guide.identifier,
                    evaluation: decision.evaluation,
                    continued: continued,
                    metadata: decision.metadata
                )
            )

            if let currentSelectedScore = selectedScore {
                if decision.evaluation.score > currentSelectedScore {
                    selfSelect(
                        output: attempt.output,
                        score: decision.evaluation.score,
                        attemptIndex: attemptIndex,
                        selectedOutput: &selectedOutput,
                        selectedScore: &selectedScore,
                        selectedAttemptIndex: &selectedAttemptIndex
                    )
                }
            } else {
                selfSelect(
                    output: attempt.output,
                    score: decision.evaluation.score,
                    attemptIndex: attemptIndex,
                    selectedOutput: &selectedOutput,
                    selectedScore: &selectedScore,
                    selectedAttemptIndex: &selectedAttemptIndex
                )
            }

            switch decision.directive {
            case .stop:
                termination = .guide_stop
                break refinementLoop

            case .continueWith(let nextInstructions):
                guard
                    attemptRecords.count
                        < realization.budget.maximumAttempts
                else {
                    termination = .maximum_attempts
                    break refinementLoop
                }

                currentRealization = realization
                currentRealization.instructions =
                    nextInstructions.value
                currentRealization.metadata[
                    "inference.refinement.guide"
                ] = guide.identifier.rawValue
                currentRealization.metadata[
                    "inference.refinement.source_attempt"
                ] = String(attemptIndex)
            }
        }

        if termination == nil {
            termination = .maximum_attempts
        }

        guard
            let selectedOutput,
            let selectedAttemptIndex,
            let lastAttemptIndex,
            let termination
        else {
            throw RefiningInferenceStrategyError.noCandidatesProduced
        }

        return InferenceExecutionResult(
            output: selectedOutput,
            record: InferenceExecutionRecord(
                inference: inference.definition.identifier,
                strategy: identifier,
                attempts: attemptRecords,
                budget: realization.budget,
                refinement: InferenceRefinementRecord(
                    guide: guide.identifier,
                    steps: refinementSteps,
                    selectedAttemptIndex: selectedAttemptIndex,
                    lastAttemptIndex: lastAttemptIndex,
                    termination: termination
                ),
                metadata: realization.metadata
            )
        )
    }

    private func selfSelect<Output: Sendable>(
        output: Output,
        score: Double,
        attemptIndex: Int,
        selectedOutput: inout Output?,
        selectedScore: inout Double?,
        selectedAttemptIndex: inout Int?
    ) {
        selectedOutput = output
        selectedScore = score
        selectedAttemptIndex = attemptIndex
    }
}
