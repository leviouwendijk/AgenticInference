import Schema

public struct AgentInferenceDefinition:
    Sendable,
    Codable,
    Hashable
{
    public var identifier: AgentInferenceIdentifier
    public var purpose: String
    public var title: String?
    public var tags: [String]
    public var metadata: [String: String]

    public init(
        identifier: AgentInferenceIdentifier,
        purpose: String,
        title: String? = nil,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.purpose = purpose
        self.title = title
        self.tags = tags
        self.metadata = metadata
    }
}

public protocol AgentInference<Input, Output>: Sendable {
    associatedtype Input:
        Sendable &
        Codable

    associatedtype Output:
        Sendable &
        Codable &
        JSONSchemaProviding

    static var definition: AgentInferenceDefinition { get }
}
