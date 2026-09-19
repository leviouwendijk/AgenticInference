import Agentic
import Foundation

public struct InferenceInvocation: Sendable {
    public let definition: InferenceDefinition
    public let input: Data
    public let realization: InferenceRealizationConfiguration
    public let context: InferenceExecutionContext

    private let operation: @Sendable (
        any InferenceStrategyResolving,
        InferenceAttemptExecutor
    ) async throws -> InferenceInvocationResult

    init(
        definition: InferenceDefinition,
        input: Data,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext,
        operation: @escaping @Sendable (
            any InferenceStrategyResolving,
            InferenceAttemptExecutor
        ) async throws -> InferenceInvocationResult
    ) {
        self.definition = definition
        self.input = input
        self.realization = realization
        self.context = context
        self.operation = operation
    }

    func execute(
        strategies: any InferenceStrategyResolving,
        attempts: InferenceAttemptExecutor
    ) async throws -> InferenceInvocationResult {
        try await operation(
            strategies,
            attempts
        )
    }
}

public struct InferenceInvocationResult: Sendable {
    public let output: Data
    public let record: InferenceExecutionRecord

    public init(
        output: Data,
        record: InferenceExecutionRecord
    ) {
        self.output = output
        self.record = record
    }
}

public protocol InferenceExecuting: Sendable {
    func execute(
        _ invocation: InferenceInvocation
    ) async throws -> InferenceInvocationResult
}

public extension Inference {
    static func invocation(
        input: Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext = .default
    ) throws -> InferenceInvocation {
        let encodedInput = try JSONEncoder().encode(
            input
        )

        return InferenceInvocation(
            definition: definition,
            input: encodedInput,
            realization: realization,
            context: context,
            operation: { strategies, attempts in
                let strategy = try strategies.require(
                    realization.strategy
                )
                let execution = try await strategy.execute(
                    Self.self,
                    input: input,
                    realization: realization,
                    context: context,
                    attempts: attempts
                )

                return InferenceInvocationResult(
                    output: try JSONEncoder().encode(
                        execution.output
                    ),
                    record: execution.record
                )
            }
        )
    }

    static func execute(
        using executor: any InferenceExecuting,
        input: Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext = .default
    ) async throws -> InferenceExecutionResult<Output> {
        let invocation = try invocation(
            input: input,
            realization: realization,
            context: context
        )
        let execution = try await executor.execute(
            invocation
        )

        return InferenceExecutionResult(
            output: try JSONDecoder().decode(
                Output.self,
                from: execution.output
            ),
            record: execution.record
        )
    }
}

public extension InferenceSite {
    func invocation(
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext = .default
    ) throws -> InferenceInvocation {
        try InferenceType.invocation(
            input: input,
            realization: realization,
            context: context
        )
    }

    func execute(
        using executor: any InferenceExecuting,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration,
        context: InferenceExecutionContext = .default
    ) async throws -> InferenceExecutionResult<InferenceType.Output> {
        try await InferenceType.execute(
            using: executor,
            input: input,
            realization: realization,
            context: context
        )
    }
}
