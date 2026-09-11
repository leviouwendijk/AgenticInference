import Agentic

public struct AgentInferenceAttemptExecutor:
    AgentInferenceAttemptExecuting,
    Sendable
{
    private let modelInvoker: any AgentModelInvoking
    private let adapters: any AgentInferenceAdapterResolving
    private let defaultAdapterIdentifier: AgentInferenceAdapterIdentifier?

    public init(
        modelInvoker: any AgentModelInvoking,
        adapters: any AgentInferenceAdapterResolving,
        defaultAdapterIdentifier: AgentInferenceAdapterIdentifier? = nil
    ) {
        self.modelInvoker = modelInvoker
        self.adapters = adapters
        self.defaultAdapterIdentifier = defaultAdapterIdentifier
    }

    public func execute<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization,
        additionalRequirements: AgentModelRequirements = AgentModelRequirements(
            capabilities: []
        ),
        attemptIndex: Int
    ) async throws -> AgentInferenceAttemptResult<Inference.Output> {
        guard let adapterIdentifier =
            realization.adapter
            ?? defaultAdapterIdentifier
        else {
            throw AgentInferenceExecutionError.adapterUnspecified(
                inference: inference.definition.identifier
            )
        }

        let adapter = try adapters.require(
            adapterIdentifier
        )
        let adaptation = try adapter.prepare(
            inference,
            input: input,
            realization: realization
        )

        var selection = realization.modelSelection
        selection.requirements = selection.requirements
            .merging(
                adaptation.requirements
            )
            .merging(
                additionalRequirements
            )

        var metadata = realization.metadata
        metadata["inference.identifier"] =
            inference.definition.identifier.rawValue
        metadata["inference.strategy"] =
            realization.strategy.rawValue
        metadata["inference.adapter"] =
            adapter.identifier.rawValue
        metadata["inference.attempt"] =
            String(attemptIndex)

        let result = try await modelInvoker.buffered(
            AgentModelInvocation(
                request: adaptation.request,
                selection: selection,
                metadata: metadata
            )
        )
        let output = try adapter.decode(
            inference,
            response: result.response
        )

        return AgentInferenceAttemptResult(
            output: output,
            record: AgentInferenceAttemptRecord(
                index: attemptIndex,
                adapter: adapter.identifier,
                route: result.route,
                usage: result.response.usage,
                metadata: metadata
            )
        )
    }
}
