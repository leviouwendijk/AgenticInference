import Agentic
import AgenticRecovery
import Foundation
import Primitives

public struct AgentInferenceDemonstration:
    Sendable,
    Codable,
    Hashable
{
    public var input: JSONValue
    public var output: JSONValue
    public var metadata: [String: String]

    public init(
        input: JSONValue,
        output: JSONValue,
        metadata: [String: String] = [:]
    ) {
        self.input = input
        self.output = output
        self.metadata = metadata
    }
}

public enum AgentInferenceBudgetParsingError:
    Error,
    Sendable,
    LocalizedError
{
    case nonPositiveMaximumAttempts(Int)
    case nonPositiveMaximumTotalTokens(Int)
    case invalidMaximumEstimatedUsd(Double)

    public var errorDescription: String? {
        switch self {
        case .nonPositiveMaximumAttempts(let value):
            return "Inference maximum attempts must be positive; received \(value)."

        case .nonPositiveMaximumTotalTokens(let value):
            return "Inference maximum total tokens must be positive; received \(value)."

        case .invalidMaximumEstimatedUsd(let value):
            return "Inference maximum estimated USD must be finite and non-negative; received \(value)."
        }
    }
}

public struct AgentInferenceBudget:
    Sendable,
    Codable,
    Hashable
{
    public let maximumAttempts: Int
    public let maximumTotalTokens: Int?
    public let maximumEstimatedUsd: Double?

    private enum CodingKeys: String, CodingKey {
        case maximumAttempts
        case maximumTotalTokens
        case maximumEstimatedUsd
    }

    private init(
        validatedMaximumAttempts maximumAttempts: Int,
        maximumTotalTokens: Int?,
        maximumEstimatedUsd: Double?
    ) {
        self.maximumAttempts = maximumAttempts
        self.maximumTotalTokens = maximumTotalTokens
        self.maximumEstimatedUsd = maximumEstimatedUsd
    }

    public init(
        maximumAttempts: Int,
        maximumTotalTokens: Int? = nil,
        maximumEstimatedUsd: Double? = nil
    ) throws {
        guard maximumAttempts > 0 else {
            throw AgentInferenceBudgetParsingError
                .nonPositiveMaximumAttempts(
                    maximumAttempts
                )
        }

        if let maximumTotalTokens {
            guard maximumTotalTokens > 0 else {
                throw AgentInferenceBudgetParsingError
                    .nonPositiveMaximumTotalTokens(
                        maximumTotalTokens
                    )
            }
        }

        if let maximumEstimatedUsd {
            guard
                maximumEstimatedUsd.isFinite,
                maximumEstimatedUsd >= 0
            else {
                throw AgentInferenceBudgetParsingError
                    .invalidMaximumEstimatedUsd(
                        maximumEstimatedUsd
                    )
            }
        }

        self.maximumAttempts = maximumAttempts
        self.maximumTotalTokens = maximumTotalTokens
        self.maximumEstimatedUsd = maximumEstimatedUsd
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        try self.init(
            maximumAttempts: try container.decode(
                Int.self,
                forKey: .maximumAttempts
            ),
            maximumTotalTokens: try container.decodeIfPresent(
                Int.self,
                forKey: .maximumTotalTokens
            ),
            maximumEstimatedUsd: try container.decodeIfPresent(
                Double.self,
                forKey: .maximumEstimatedUsd
            )
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            maximumAttempts,
            forKey: .maximumAttempts
        )
        try container.encodeIfPresent(
            maximumTotalTokens,
            forKey: .maximumTotalTokens
        )
        try container.encodeIfPresent(
            maximumEstimatedUsd,
            forKey: .maximumEstimatedUsd
        )
    }

    public static let singleAttempt = Self(
        validatedMaximumAttempts: 1,
        maximumTotalTokens: nil,
        maximumEstimatedUsd: nil
    )
}

public struct AgentInferenceRealization:
    Sendable,
    Codable,
    Hashable
{
    public var strategy: AgentInferenceStrategyIdentifier
    public var adapter: AgentInferenceAdapterIdentifier?
    public var modelSelection: AgentModelSelection
    public var instructions: String
    public var demonstrations: [AgentInferenceDemonstration]
    public var generation: AgentGenerationConfiguration
    public var budget: AgentInferenceBudget
    public var recovery: Recovery.Policy?
    public var metadata: [String: String]

    public init(
        strategy: AgentInferenceStrategyIdentifier,
        modelSelection: AgentModelSelection,
        instructions: String,
        budget: AgentInferenceBudget,
        recovery: Recovery.Policy? = nil,
        adapter: AgentInferenceAdapterIdentifier? = nil,
        demonstrations: [AgentInferenceDemonstration] = [],
        generation: AgentGenerationConfiguration = .default,
        metadata: [String: String] = [:]
    ) {
        self.strategy = strategy
        self.adapter = adapter
        self.modelSelection = modelSelection
        self.instructions = instructions
        self.demonstrations = demonstrations
        self.generation = generation
        self.budget = budget
        self.recovery = recovery
        self.metadata = metadata
    }
}
