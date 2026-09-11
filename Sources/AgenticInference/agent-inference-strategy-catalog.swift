import Foundation

public enum AgentInferenceStrategyCatalogError:
    Error,
    Sendable,
    LocalizedError
{
    case duplicateStrategy(AgentInferenceStrategyIdentifier)
    case unknownStrategy(AgentInferenceStrategyIdentifier)

    public var errorDescription: String? {
        switch self {
        case .duplicateStrategy(let identifier):
            return "An inference strategy with id '\(identifier.rawValue)' is already registered."

        case .unknownStrategy(let identifier):
            return "Unknown inference strategy: \(identifier.rawValue)"
        }
    }
}

public struct AgentInferenceStrategyCatalog:
    AgentInferenceStrategyResolving,
    Sendable
{
    private let strategies: [
        AgentInferenceStrategyIdentifier:
            any AgentInferenceStrategy
    ]

    public init(
        strategies: [any AgentInferenceStrategy]
    ) throws {
        var indexed: [
            AgentInferenceStrategyIdentifier:
                any AgentInferenceStrategy
        ] = [:]

        for strategy in strategies {
            guard indexed[strategy.identifier] == nil else {
                throw AgentInferenceStrategyCatalogError.duplicateStrategy(
                    strategy.identifier
                )
            }

            indexed[strategy.identifier] = strategy
        }

        self.strategies = indexed
    }

    private init(
        strategies: [
            AgentInferenceStrategyIdentifier:
                any AgentInferenceStrategy
        ]
    ) {
        self.strategies = strategies
    }

    public func require(
        _ identifier: AgentInferenceStrategyIdentifier
    ) throws -> any AgentInferenceStrategy {
        guard let strategy = strategies[identifier] else {
            throw AgentInferenceStrategyCatalogError.unknownStrategy(
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

    public static func standard(
        sampleEvaluator: any AgentInferenceCandidateEvaluating
    ) -> Self {
        Self(
            strategies: [
                .direct: DirectInferenceStrategy(),
                .native_reasoning: NativeReasoningInferenceStrategy(),
                .sampled: SampledInferenceStrategy(
                    evaluator: sampleEvaluator
                ),
            ]
        )
    }
}
