import Agentic

public protocol AgentInferenceAdapter: Sendable {
    var identifier: AgentInferenceAdapterIdentifier { get }

    func prepare<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization
    ) throws -> AgentInferenceAdaptation

    func decode<Inference: AgentInference>(
        _ inference: Inference.Type,
        response: AgentResponse
    ) throws -> Inference.Output
}
