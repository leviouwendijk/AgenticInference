import Foundation

public struct AgentInferenceAttemptPermit:
    Sendable,
    Hashable
{
    public let index: Int

    fileprivate init(
        index: Int
    ) {
        self.index = index
    }
}

public struct AgentInferenceInvocationPermit:
    Sendable,
    Hashable
{
    public let index: Int

    fileprivate init(
        index: Int
    ) {
        self.index = index
    }
}

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
        attempts: [AgentInferenceAttemptRecord],
        additionalInvocations: [AgentInferenceInvocationRecord] = []
    ) {
        let invocations = attempts.flatMap(\.invocations)
            + additionalInvocations

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
    /// Constructs permission to begin the next semantic inference attempt.
    func nextAttempt(
        priorAttempts: [AgentInferenceAttemptRecord]
    ) throws -> AgentInferenceAttemptPermit {
        let index = priorAttempts.count

        guard index < maximumAttempts else {
            throw AgentInferenceBudgetError.maximumAttemptsReached(
                maximumAttempts: maximumAttempts,
                requestedAttemptIndex: index
            )
        }

        return AgentInferenceAttemptPermit(
            index: index
        )
    }

    /// Constructs permission for another model invocation inside the current
    /// semantic inference attempt.
    func nextInvocation(
        priorAttempts: [AgentInferenceAttemptRecord],
        currentInvocations: [AgentInferenceInvocationRecord] = []
    ) throws -> AgentInferenceInvocationPermit {
        let index = currentInvocations.count

        guard let maximumTotalTokens else {
            return AgentInferenceInvocationPermit(
                index: index
            )
        }

        let usage = AgentInferenceBudgetUsage(
            attempts: priorAttempts,
            additionalInvocations: currentInvocations
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

        return AgentInferenceInvocationPermit(
            index: index
        )
    }
}
