public protocol AgentInferenceInvoking: Sendable {
    func infer<Inference: AgentInference>(
        _ inference: Inference.Type,
        at site: AgentInferenceSiteIdentifier,
        input: Inference.Input
    ) async throws -> Inference.Output
}
