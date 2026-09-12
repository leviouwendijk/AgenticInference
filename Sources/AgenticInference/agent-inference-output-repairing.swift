import Agentic

/// Optional adapter capability for mechanically repairing a model response
/// that was successfully produced but could not be restored as the typed
/// inference output.
///
/// Repair remains adapter-owned because the adapter owns the lowering and
/// decoding conventions required to construct an equivalent repair request.
public protocol AgentInferenceOutputRepairing: Sendable {
    func repair<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        response: AgentResponse,
        error: any Error,
        realization: AgentInferenceRealization
    ) throws -> AgentInferenceAdaptation
}
