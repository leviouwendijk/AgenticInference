import Agentic
import AgenticInference
import Foundation
import TestFlows

private struct BudgetFixtureInference: AgentInference {
    struct Input:
        Sendable,
        Codable
    {
        let value: String
    }

    typealias Output = String

    static let definition = AgentInferenceDefinition(
        identifier: "fixture.budget_execution",
        purpose: "Prove deterministic inference budget accounting."
    )
}

private struct BudgetFixtureAdapter:
    AgentInferenceAdapter,
    Sendable
{
    let identifier: AgentInferenceAdapterIdentifier =
        "budget_fixture_adapter"

    func prepare<Inference: AgentInference>(
        _ inference: Inference.Type,
        input: Inference.Input,
        realization: AgentInferenceRealization
    ) throws -> AgentInferenceAdaptation {
        AgentInferenceAdaptation(
            request: AgentRequest(
                messages: [
                    AgentMessage(
                        role: .user,
                        text: "budget fixture request"
                    ),
                ],
                generationConfiguration: realization.generation
            ),
            requirements: AgentModelRequirements(
                capabilities: [
                    .structured_output,
                ]
            )
        )
    }

    func decode<Inference: AgentInference>(
        _ inference: Inference.Type,
        response: AgentResponse
    ) throws -> Inference.Output {
        try JSONDecoder().decode(
            Inference.Output.self,
            from: Data(
                response.message.content.text.utf8
            )
        )
    }
}

private struct BudgetFixtureAdapterResolver:
    AgentInferenceAdapterResolving,
    Sendable
{
    let adapter = BudgetFixtureAdapter()

    func require(
        _ identifier: AgentInferenceAdapterIdentifier
    ) throws -> any AgentInferenceAdapter {
        guard identifier == adapter.identifier else {
            throw BudgetFixtureError.unknownAdapter(
                identifier.rawValue
            )
        }

        return adapter
    }
}

private actor BudgetInvocationRecorder {
    private var invocations: [AgentModelInvocation] = []

    func append(
        _ invocation: AgentModelInvocation
    ) {
        invocations.append(
            invocation
        )
    }

    func snapshot() -> [AgentModelInvocation] {
        invocations
    }
}

private struct BudgetFixtureModelInvoker:
    AgentModelInvoking,
    Sendable
{
    let recorder: BudgetInvocationRecorder
    let response: AgentResponse

    func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        await recorder.append(
            invocation
        )

        let profile = AgentModelProfile(
            identifier: "budget_fixture_profile",
            gatewayIdentifier: "budget_fixture_gateway",
            model: "fixture",
            purposes: [
                invocation.selection.purpose,
            ],
            capabilities: [
                .text,
                .structured_output,
            ]
        )
        let route = AgentModelRoute(
            purpose: invocation.selection.purpose,
            profile: profile
        )

        return AgentModelInvocationResult(
            response: response,
            route: AgentModelRouteRecord(
                route: route,
                requestMetadata: invocation.metadata,
                responseMetadata: response.metadata,
                usage: response.usage
            )
        )
    }

    func stream(
        _ invocation: AgentModelInvocation
    ) -> AsyncThrowingStream<AgentModelInvocationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(
                throwing: BudgetFixtureError.streamingUnsupported
            )
        }
    }
}

private enum BudgetFixtureError:
    Error,
    Sendable
{
    case unknownAdapter(String)
    case streamingUnsupported
}

extension AgentInferenceExecutionFlowTests {
    static func runBudgetAccounting()
        async throws
        -> [TestFlowDiagnostic]
    {
        let executionRecorder = BudgetInvocationRecorder()
        let response = AgentResponse(
            message: AgentMessage(
                role: .assistant,
                text: "\"BUDGETED\""
            ),
            stopReason: .end_turn,
            usage: AgentUsage(
                inputTokens: 3,
                outputTokens: 2,
                totalTokens: 5
            ),
            metadata: [
                "fixture_response": "budget",
            ]
        )
        let modelInvoker = BudgetFixtureModelInvoker(
            recorder: executionRecorder,
            response: response
        )
        let budget = AgentInferenceBudget(
            maximumAttempts: 1,
            maximumTotalTokens: 10
        )
        let realization = AgentInferenceRealization(
            strategy: .direct,
            modelSelection: .executor,
            instructions: "Return the budget fixture output.",
            budget: budget,
            adapter: "budget_fixture_adapter"
        )
        let executor = AgentInferenceExecutor(
            modelInvoker: modelInvoker,
            adapters: BudgetFixtureAdapterResolver()
        )

        let result = try await executor.execute(
            BudgetFixtureInference.self,
            input: BudgetFixtureInference.Input(
                value: "budget"
            ),
            realization: realization
        )

        try Expect.equal(
            result.output,
            "BUDGETED",
            "budgeted inference preserves typed output"
        )
        try Expect.equal(
            result.record.budget,
            budget,
            "execution record preserves configured inference budget"
        )
        try Expect.equal(
            result.record.budgetUsage.attemptCount,
            1,
            "execution record derives stable attempt count"
        )
        try Expect.equal(
            result.record.budgetUsage.totalTokens,
            5,
            "execution record derives reported total token usage"
        )
        try Expect.equal(
            result.record.attempts[0]
                .selection
                .requirements
                .capabilities
                .contains(
                    .structured_output
                ),
            true,
            "attempt record preserves the effective merged model selection"
        )

        let encodedRecord = try JSONEncoder().encode(
            result.record
        )
        let decodedRecord = try JSONDecoder().decode(
            AgentInferenceExecutionRecord.self,
            from: encodedRecord
        )

        try Expect.equal(
            decodedRecord,
            result.record,
            "execution records survive durable codec round trip"
        )

        let attemptRecorder = BudgetInvocationRecorder()
        let attemptExecutor = AgentInferenceAttemptExecutor(
            modelInvoker: BudgetFixtureModelInvoker(
                recorder: attemptRecorder,
                response: response
            ),
            adapters: BudgetFixtureAdapterResolver()
        )

        var expectedIndex: Int?
        var actualIndex: Int?

        do {
            _ = try await attemptExecutor.execute(
                BudgetFixtureInference.self,
                input: BudgetFixtureInference.Input(
                    value: "out-of-order"
                ),
                realization: AgentInferenceRealization(
                    strategy: .direct,
                    modelSelection: .executor,
                    instructions: "Do not execute out of order.",
                    budget: AgentInferenceBudget(
                        maximumAttempts: 2
                    ),
                    adapter: "budget_fixture_adapter"
                ),
                priorAttempts: [],
                attemptIndex: 1
            )
        } catch AgentInferenceBudgetError.attemptIndexMismatch(
            let expected,
            let actual
        ) {
            expectedIndex = expected
            actualIndex = actual
        }

        try Expect.equal(
            expectedIndex,
            0,
            "attempt executor requires contiguous attempt indexes"
        )
        try Expect.equal(
            actualIndex,
            1,
            "attempt executor reports the rejected out-of-order index"
        )

        var blockedMaximumAttempts: Int?

        do {
            _ = try await attemptExecutor.execute(
                BudgetFixtureInference.self,
                input: BudgetFixtureInference.Input(
                    value: "blocked"
                ),
                realization: AgentInferenceRealization(
                    strategy: .direct,
                    modelSelection: .executor,
                    instructions: "This attempt must not reach the model.",
                    budget: AgentInferenceBudget(
                        maximumAttempts: 0
                    ),
                    adapter: "budget_fixture_adapter"
                ),
                priorAttempts: [],
                attemptIndex: 0
            )
        } catch AgentInferenceBudgetError.maximumAttemptsReached(
            let maximumAttempts,
            _
        ) {
            blockedMaximumAttempts = maximumAttempts
        }

        try Expect.equal(
            blockedMaximumAttempts,
            0,
            "maximum-attempt budget blocks execution before model invocation"
        )

        let tokenRealization = AgentInferenceRealization(
            strategy: .direct,
            modelSelection: .executor,
            instructions: "Exercise token budget enforcement.",
            budget: AgentInferenceBudget(
                maximumAttempts: 2,
                maximumTotalTokens: 5
            ),
            adapter: "budget_fixture_adapter"
        )
        let firstAttempt = try await attemptExecutor.execute(
            BudgetFixtureInference.self,
            input: BudgetFixtureInference.Input(
                value: "first"
            ),
            realization: tokenRealization,
            priorAttempts: [],
            attemptIndex: 0
        )

        var blockedTokenMaximum: Int?
        var consumedTokens: Int?

        do {
            _ = try await attemptExecutor.execute(
                BudgetFixtureInference.self,
                input: BudgetFixtureInference.Input(
                    value: "second"
                ),
                realization: tokenRealization,
                priorAttempts: [
                    firstAttempt.record,
                ],
                attemptIndex: 1
            )
        } catch AgentInferenceBudgetError.maximumTotalTokensReached(
            let maximumTotalTokens,
            let consumedTotalTokens
        ) {
            blockedTokenMaximum = maximumTotalTokens
            consumedTokens = consumedTotalTokens
        }

        try Expect.equal(
            blockedTokenMaximum,
            5,
            "token budget prevents a subsequent attempt after reaching its cap"
        )
        try Expect.equal(
            consumedTokens,
            5,
            "token budget reports actual provider token consumption"
        )

        let attemptInvocations = await attemptRecorder.snapshot()

        try Expect.equal(
            attemptInvocations.count,
            1,
            "rejected index, attempt-limit, and token-limit attempts do not invoke the model"
        )

        let unavailableRecorder = BudgetInvocationRecorder()
        let unavailableExecutor = AgentInferenceAttemptExecutor(
            modelInvoker: BudgetFixtureModelInvoker(
                recorder: unavailableRecorder,
                response: AgentResponse(
                    message: AgentMessage(
                        role: .assistant,
                        text: "\"NO_USAGE\""
                    ),
                    stopReason: .end_turn
                )
            ),
            adapters: BudgetFixtureAdapterResolver()
        )
        let unavailableRealization = AgentInferenceRealization(
            strategy: .direct,
            modelSelection: .executor,
            instructions: "Exercise missing usage handling.",
            budget: AgentInferenceBudget(
                maximumAttempts: 2,
                maximumTotalTokens: 10
            ),
            adapter: "budget_fixture_adapter"
        )
        let unavailableFirst = try await unavailableExecutor.execute(
            BudgetFixtureInference.self,
            input: BudgetFixtureInference.Input(
                value: "first"
            ),
            realization: unavailableRealization,
            priorAttempts: [],
            attemptIndex: 0
        )

        var missingUsageBlocked = false

        do {
            _ = try await unavailableExecutor.execute(
                BudgetFixtureInference.self,
                input: BudgetFixtureInference.Input(
                    value: "second"
                ),
                realization: unavailableRealization,
                priorAttempts: [
                    unavailableFirst.record,
                ],
                attemptIndex: 1
            )
        } catch AgentInferenceBudgetError.totalTokenUsageUnavailable {
            missingUsageBlocked = true
        }

        let unavailableInvocations = await unavailableRecorder.snapshot()

        try Expect.equal(
            missingUsageBlocked,
            true,
            "token-capped multi-attempt execution fails closed when prior usage is unavailable"
        )
        try Expect.equal(
            unavailableInvocations.count,
            1,
            "missing token usage blocks the next attempt before model invocation"
        )

        return [
            .field(
                "selection_recorded",
                "true"
            ),
            .field(
                "record_codec",
                "true"
            ),
            .field(
                "attempt_limit_enforced",
                String(blockedMaximumAttempts == 0)
            ),
            .field(
                "token_limit_enforced",
                String(blockedTokenMaximum == 5)
            ),
            .field(
                "missing_usage_blocked",
                String(missingUsageBlocked)
            ),
        ]
    }
}
