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
    AgentInferenceStrategy,
    Sendable
{
    public let identifier: AgentInferenceStrategyIdentifier = .refining

    private let guide: any AgentInferenceRefinementGuiding

    public init(
        guide: any AgentInferenceRefinementGuiding
    ) {
        self.guide = guide
    }

    public func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization,
        attempts: any AgentInferenceAttemptExecuting
    ) async throws -> AgentInferenceExecutionResult<Inference.Output> {
        var attemptRecords: [AgentInferenceAttemptRecord] = []
        var refinementSteps: [AgentInferenceRefinementStep] = []
        var currentRealization = realization

        var selectedOutput: Inference.Output?
        var selectedScore: Double?
        var selectedAttemptIndex: Int?
        var lastAttemptIndex: Int?
        var termination: AgentInferenceRefinementTermination?

        refinementLoop: while
            attemptRecords.count < realization.budget.maximumAttempts
        {
            let attemptIndex = attemptRecords.count
            let attempt: AgentInferenceAttemptResult<Inference.Output>

            do {
                attempt = try await attempts.execute(
                    inference,
                    input: input,
                    realization: currentRealization,
                    priorAttempts: attemptRecords,
                    additionalRequirements: AgentModelRequirements(
                        capabilities: []
                    )
                )
            } catch let failure as AgentInferenceAttemptFailure {
                let refinement = selectedAttemptIndex.map {
                    AgentInferenceRefinementRecord(
                        guide: guide.identifier,
                        steps: refinementSteps,
                        selectedAttemptIndex: $0,
                        lastAttemptIndex: failure.record.index,
                        termination: .attempt_failed
                    )
                }

                throw AgentInferenceExecutionFailure(
                    attempt: failure,
                    inference: inference.definition.identifier,
                    strategy: identifier,
                    priorAttempts: attemptRecords,
                    budget: realization.budget,
                    refinement: refinement,
                    metadata: realization.metadata
                )
            } catch let error as AgentInferenceBudgetError {
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

            let decision: AgentInferenceRefinementDecision

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
                    AgentInferenceRefinementRecord(
                        guide: guide.identifier,
                        steps: refinementSteps,
                        selectedAttemptIndex: $0,
                        lastAttemptIndex: attemptIndex,
                        termination: .guide_failed
                    )
                }

                throw AgentInferenceExecutionFailure(
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
                AgentInferenceRefinementStep(
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

        return AgentInferenceExecutionResult(
            output: selectedOutput,
            record: AgentInferenceExecutionRecord(
                inference: inference.definition.identifier,
                strategy: identifier,
                attempts: attemptRecords,
                budget: realization.budget,
                refinement: AgentInferenceRefinementRecord(
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
