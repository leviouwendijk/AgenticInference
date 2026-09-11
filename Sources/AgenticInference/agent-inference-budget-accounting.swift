import Foundation

public struct AgentInferenceBudgetUsage:
    Sendable,
    Codable,
    Hashable
{
    public var attemptCount: Int
    public var reportedTotalTokens: Int
    public var unreportedTokenAttemptCount: Int

    public init(
        attempts: [AgentInferenceAttemptRecord]
    ) {
        attemptCount = attempts.count
        reportedTotalTokens = attempts.reduce(
            into: 0
        ) { total, attempt in
            total += attempt.usage?.totalTokens ?? 0
        }
        unreportedTokenAttemptCount = attempts.reduce(
            into: 0
        ) { count, attempt in
            if attempt.usage?.totalTokens == nil {
                count += 1
            }
        }
    }

    public var totalTokens: Int? {
        guard unreportedTokenAttemptCount == 0 else {
            return nil
        }

        return reportedTotalTokens
    }
}

public enum AgentInferenceBudgetError:
    Error,
    Sendable,
    LocalizedError
{
    case attemptIndexMismatch(
        expected: Int,
        actual: Int
    )
    case maximumAttemptsReached(
        maximumAttempts: Int,
        requestedAttemptIndex: Int
    )
    case totalTokenUsageUnavailable(
        maximumTotalTokens: Int,
        priorAttemptCount: Int
    )
    case maximumTotalTokensReached(
        maximumTotalTokens: Int,
        consumedTotalTokens: Int
    )

    public var errorDescription: String? {
        switch self {
        case .attemptIndexMismatch(
            let expected,
            let actual
        ):
            return "Inference attempt index \(actual) is invalid; the next contiguous attempt index is \(expected)."

        case .maximumAttemptsReached(
            let maximumAttempts,
            let requestedAttemptIndex
        ):
            return "Inference attempt \(requestedAttemptIndex) exceeds the configured maximum of \(maximumAttempts) attempt(s)."

        case .totalTokenUsageUnavailable(
            let maximumTotalTokens,
            let priorAttemptCount
        ):
            return "Cannot safely continue inference under a \(maximumTotalTokens)-token budget because token usage is unavailable for one or more of the \(priorAttemptCount) prior attempt(s)."

        case .maximumTotalTokensReached(
            let maximumTotalTokens,
            let consumedTotalTokens
        ):
            return "Inference has consumed \(consumedTotalTokens) tokens and reached the configured maximum of \(maximumTotalTokens); another attempt is not allowed."
        }
    }
}

public extension AgentInferenceBudget {
    func validateNextAttempt(
        index: Int,
        priorAttempts: [AgentInferenceAttemptRecord]
    ) throws {
        let expectedIndex = priorAttempts.count

        guard index == expectedIndex else {
            throw AgentInferenceBudgetError.attemptIndexMismatch(
                expected: expectedIndex,
                actual: index
            )
        }

        guard index < maximumAttempts else {
            throw AgentInferenceBudgetError.maximumAttemptsReached(
                maximumAttempts: maximumAttempts,
                requestedAttemptIndex: index
            )
        }

        guard let maximumTotalTokens else {
            return
        }

        let usage = AgentInferenceBudgetUsage(
            attempts: priorAttempts
        )

        guard let consumedTotalTokens = usage.totalTokens else {
            throw AgentInferenceBudgetError.totalTokenUsageUnavailable(
                maximumTotalTokens: maximumTotalTokens,
                priorAttemptCount: priorAttempts.count
            )
        }

        guard consumedTotalTokens < maximumTotalTokens else {
            throw AgentInferenceBudgetError.maximumTotalTokensReached(
                maximumTotalTokens: maximumTotalTokens,
                consumedTotalTokens: consumedTotalTokens
            )
        }
    }
}
