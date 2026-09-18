import Agentic

/// Optional adapter capability for mechanically repairing a model response
/// that was successfully produced but could not be restored as the typed
/// inference output.
///
/// Repair remains adapter-owned because the adapter owns the lowering and
/// decoding conventions required to construct an equivalent repair request.
public protocol InferenceOutputRepairing: Sendable {
    func repair<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        response: AgentResponse,
        error: any Error,
        realization: InferenceRealizationConfiguration
    ) throws -> InferenceAdaptation
}
