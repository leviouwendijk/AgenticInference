public struct AgentInferenceIdentifier:
    Sendable,
    Codable,
    Hashable,
    RawRepresentable,
    ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        _ rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        stringLiteral value: String
    ) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }
}

public struct AgentInferenceSiteIdentifier:
    Sendable,
    Codable,
    Hashable,
    RawRepresentable,
    ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        _ rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        stringLiteral value: String
    ) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }
}

public struct AgentInferenceStrategyIdentifier:
    Sendable,
    Codable,
    Hashable,
    RawRepresentable,
    ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        _ rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        stringLiteral value: String
    ) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }
}

public struct AgentInferenceAdapterIdentifier:
    Sendable,
    Codable,
    Hashable,
    RawRepresentable,
    ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        _ rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        stringLiteral value: String
    ) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }
}
