import Agentic
import Foundation

public enum InferenceStrategyCatalogError:
    Error,
    Sendable,
    LocalizedError
{
    case duplicateStrategy(InferenceStrategyIdentifier)
    case unknownStrategy(InferenceStrategyIdentifier)

    public var errorDescription: String? {
        switch self {
        case .duplicateStrategy(let identifier):
            return "An inference strategy with id '\(identifier.rawValue)' is already registered."

        case .unknownStrategy(let identifier):
            return "Unknown inference strategy: \(identifier.rawValue)"
        }
    }
}

public struct InferenceStrategyCatalog:
    InferenceStrategyResolving,
    Sendable
{
    private let strategies: [
        InferenceStrategyIdentifier:
            any InferenceStrategy
    ]

    public init(
        strategies: [any InferenceStrategy]
    ) throws {
        var indexed: [
            InferenceStrategyIdentifier:
                any InferenceStrategy
        ] = [:]

        for strategy in strategies {
            guard indexed[strategy.identifier] == nil else {
                throw InferenceStrategyCatalogError.duplicateStrategy(
                    strategy.identifier
                )
            }

            indexed[strategy.identifier] = strategy
        }

        self.strategies = indexed
    }

    private init(
        strategies: [
            InferenceStrategyIdentifier:
                any InferenceStrategy
        ]
    ) {
        self.strategies = strategies
    }

    public func require(
        _ identifier: InferenceStrategyIdentifier
    ) throws -> any InferenceStrategy {
        guard let strategy = strategies[identifier] else {
            throw InferenceStrategyCatalogError.unknownStrategy(
                identifier
            )
        }

        return strategy
    }

    public static let standard = Self(
        strategies: [
            .direct: DirectInferenceStrategy(),
            .native_reasoning: NativeReasoningInferenceStrategy(),
        ]
    )

    public static func configured(
        sampleEvaluator: (any InferenceCandidateEvaluating)? = nil,
        refinementGuide: (any InferenceRefinementGuiding)? = nil
    ) -> Self {
        var strategies: [
            InferenceStrategyIdentifier:
                any InferenceStrategy
        ] = [
            .direct: DirectInferenceStrategy(),
            .native_reasoning: NativeReasoningInferenceStrategy(),
        ]

        if let sampleEvaluator {
            strategies[.sampled] = SampledInferenceStrategy(
                evaluator: sampleEvaluator
            )
        }

        if let refinementGuide {
            strategies[.refining] = RefiningInferenceStrategy(
                guide: refinementGuide
            )
        }

        return Self(
            strategies: strategies
        )
    }
}
