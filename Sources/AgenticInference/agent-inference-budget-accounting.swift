import Foundation

public struct AgentInferenceBudgetUsage:
    Sendable,
    Codable,
    Hashable
{
    /// Number of semantic inference attempts.
    public var attemptCount: Int

    /// Number of actual model invocations across those semantic attempts.
    public var invocationCount: Int
    public var reportedTotalTokens: Int
    public var unreportedTokenInvocationCount: Int

    public init(
        attempts: [AgentInferenceAttemptRecord]
    ) {
        let invocations = attempts.flatMap(\.invocations)

        attemptCount = attempts.count
        invocationCount = invocations.count
        reportedTotalTokens = invocations.reduce(
            into: 0
        ) { total, invocation in
            total += invocation.usage?.totalTokens ?? 0
        }
        unreportedTokenInvocationCount = invocations.reduce(
            into: 0
        ) { count, invocation in
            if invocation.usage?.totalTokens == nil {
                count += 1
            }
        }
    }

    public var totalTokens: Int? {
        guard unreportedTokenInvocationCount == 0 else {
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
    case maximumAttemptsReached(
        maximumAttempts: Int,
        requestedAttemptIndex: Int
    )
    case totalTokenUsageUnavailable(
        maximumTotalTokens: Int,
        priorInvocationCount: Int
    )
    case maximumTotalTokensReached(
        maximumTotalTokens: Int,
        consumedTotalTokens: Int
    )

    public var errorDescription: String? {
        switch self {
        case .maximumAttemptsReached(
            let maximumAttempts,
            let requestedAttemptIndex
        ):
            return "Inference attempt \(requestedAttemptIndex) exceeds the configured maximum of \(maximumAttempts) semantic attempt(s)."

        case .totalTokenUsageUnavailable(
            let maximumTotalTokens,
            let priorInvocationCount
        ):
            return "Cannot safely continue inference under a \(maximumTotalTokens)-token budget because token usage is unavailable for one or more of the \(priorInvocationCount) prior model invocation(s)."

        case .maximumTotalTokensReached(
            let maximumTotalTokens,
            let consumedTotalTokens
        ):
            return "Inference has consumed \(consumedTotalTokens) tokens and reached the configured maximum of \(maximumTotalTokens); another model invocation is not allowed."
        }
    }
}

public extension AgentInferenceBudget {
    /// Returns the index of the next semantic inference attempt.
    ///
    /// `maximumAttempts` bounds semantic strategy attempts. Token accounting,
    /// however, includes every model invocation performed within those attempts.
    func nextAttemptIndex(
        priorAttempts: [AgentInferenceAttemptRecord]
    ) throws -> Int {
        let index = priorAttempts.count

        guard index < maximumAttempts else {
            throw AgentInferenceBudgetError.maximumAttemptsReached(
                maximumAttempts: maximumAttempts,
                requestedAttemptIndex: index
            )
        }

        guard let maximumTotalTokens else {
            return index
        }

        let usage = AgentInferenceBudgetUsage(
            attempts: priorAttempts
        )

        guard let consumedTotalTokens = usage.totalTokens else {
            throw AgentInferenceBudgetError.totalTokenUsageUnavailable(
                maximumTotalTokens: maximumTotalTokens,
                priorInvocationCount: usage.invocationCount
            )
        }

        guard consumedTotalTokens < maximumTotalTokens else {
            throw AgentInferenceBudgetError.maximumTotalTokensReached(
                maximumTotalTokens: maximumTotalTokens,
                consumedTotalTokens: consumedTotalTokens
            )
        }

        return index
    }
}
