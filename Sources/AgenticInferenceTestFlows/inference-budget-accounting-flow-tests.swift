import Agentic
import AgenticInference
import Macros
import Schema
import Foundation
import TestFlows

private struct LegacyBudgetAttemptRecord: Encodable {
    let index: Int
    let adapter: InferenceAdapterIdentifier
    let selection: AgentModelSelection
    let route: AgentModelRouteRecord
    let usage: AgentUsage?
    let metadata: [String: String]
}

private struct BudgetFixtureInference: Inference {
    @JSONSchema
    struct Input:
        Source
    {
        let value: String
    }

    typealias Output = String

    static let definition = InferenceDefinition(
        identifier: "fixture.budget_execution",
        purpose: "Prove deterministic inference budget accounting."
    )
}

private struct BudgetFixtureAdapter:
    InferenceAdapter,
    Sendable
{
    let identifier: InferenceAdapterIdentifier =
        "budget_fixture_adapter"

    func prepare<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        input: InferenceType.Input,
        realization: InferenceRealizationConfiguration
    ) throws -> InferenceAdaptation {
        InferenceAdaptation(
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

    func decode<InferenceType: Inference>(
        _ inference: InferenceType.Type,
        response: AgentResponse
    ) throws -> InferenceType.Output {
        try JSONDecoder().decode(
            InferenceType.Output.self,
            from: Data(
                response.message.content.text.utf8
            )
        )
    }
}

private struct BudgetFixtureAdapterResolver:
    InferenceAdapterResolving,
    Sendable
{
    let adapter = BudgetFixtureAdapter()

    func require(
        _ identifier: InferenceAdapterIdentifier
    ) throws -> any InferenceAdapter {
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

extension InferenceExecutionFlowTests {
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
        let budget = try InferenceBudget(
            maximumAttempts: 1,
            maximumTotalTokens: 10
        )
        let realization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Return the budget fixture output.",
            budget: budget,
            adapter: "budget_fixture_adapter"
        )
        let executor = InferenceExecutor(
            modelInvoker: modelInvoker,
            adapters: BudgetFixtureAdapterResolver()
        )

        let result = try await BudgetFixtureInference.execute(
            using: executor,
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
            InferenceExecutionRecord.self,
            from: encodedRecord
        )

        try Expect.equal(
            decodedRecord,
            result.record,
            "execution records survive durable codec round trip"
        )

        let attemptRecorder = BudgetInvocationRecorder()
        let attemptExecutor = InferenceAttemptExecutor(
            modelInvoker: BudgetFixtureModelInvoker(
                recorder: attemptRecorder,
                response: response
            ),
            adapters: BudgetFixtureAdapterResolver()
        )

        var invalidAttemptBudgetRejected = false

        do {
            _ = try InferenceBudget(
                maximumAttempts: 0
            )
        } catch InferenceBudgetParsingError
            .nonPositiveMaximumAttempts(_) {
            invalidAttemptBudgetRejected = true
        }

        try Expect.equal(
            invalidAttemptBudgetRejected,
            true,
            "invalid attempt limits are rejected at budget parsing"
        )

        let invalidBudgetData = Data(
            """
            {
              "maximumAttempts": 0
            }
            """.utf8
        )
        var invalidBudgetDecodeRejected = false

        do {
            _ = try JSONDecoder().decode(
                InferenceBudget.self,
                from: invalidBudgetData
            )
        } catch InferenceBudgetParsingError
            .nonPositiveMaximumAttempts(_) {
            invalidBudgetDecodeRejected = true
        }

        try Expect.equal(
            invalidBudgetDecodeRejected,
            true,
            "budget decoding cannot bypass parsed invariants"
        )

        let validBudget = try InferenceBudget(
            maximumAttempts: 2,
            maximumTotalTokens: 5,
            maximumEstimatedUsd: 0
        )
        let validBudgetRoundTrip = try JSONDecoder().decode(
            InferenceBudget.self,
            from: JSONEncoder().encode(
                validBudget
            )
        )

        try Expect.equal(
            validBudgetRoundTrip,
            validBudget,
            "valid parsed budgets survive durable codec round trip"
        )

        let tokenRealization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Exercise token budget enforcement.",
            budget: validBudget,
            adapter: "budget_fixture_adapter"
        )
        let firstAttempt = try await attemptExecutor.execute(
            BudgetFixtureInference.self,
            input: BudgetFixtureInference.Input(
                value: "first"
            ),
            realization: tokenRealization,
            context: .default,
            priorAttempts: []
        )

        try Expect.equal(
            firstAttempt.record.index,
            0,
            "semantic attempt index is derived from prior semantic attempt count"
        )
        try Expect.equal(
            firstAttempt.record.invocations.count,
            1,
            "one successful semantic attempt records one model invocation"
        )

        let firstRoute = try Expect.notNil(
            firstAttempt.record.route,
            "successful budget fixture attempt preserves its route"
        )
        let legacyAttemptData = try JSONEncoder().encode(
            LegacyBudgetAttemptRecord(
                index: firstAttempt.record.index,
                adapter: firstAttempt.record.adapter,
                selection: firstAttempt.record.selection,
                route: firstRoute,
                usage: firstAttempt.record.usage,
                metadata: firstAttempt.record.metadata
            )
        )
        let migratedLegacyAttempt = try JSONDecoder().decode(
            InferenceAttemptRecord.self,
            from: legacyAttemptData
        )

        try Expect.equal(
            migratedLegacyAttempt.invocations.count,
            1,
            "legacy attempt records synthesize their historical successful invocation"
        )
        try Expect.equal(
            migratedLegacyAttempt.route,
            firstRoute,
            "legacy successful attempt records migrate into the explicit success outcome"
        )

        let failedInvocation = InferenceInvocationRecord(
            index: 0,
            selection: firstAttempt.record.selection,
            outcome: .failed(
                .init(
                    message: "fixture terminal failure"
                )
            ),
            metadata: [
                "fixture": "failed_attempt",
            ]
        )
        let failedAttempt = InferenceAttemptRecord(
            index: 1,
            adapter: firstAttempt.record.adapter,
            selection: firstAttempt.record.selection,
            failure: InferenceFailureRecord(
                type: "FixtureTerminalFailure",
                message: "fixture terminal failure"
            ),
            invocations: [
                failedInvocation,
            ],
            metadata: [
                "fixture": "failed_attempt",
            ]
        )
        let failedAttemptRoundTrip = try JSONDecoder().decode(
            InferenceAttemptRecord.self,
            from: JSONEncoder().encode(
                failedAttempt
            )
        )
        let failedEvidence = try Expect.notNil(
            failedAttemptRoundTrip.failure,
            "failed attempt round trip preserves canonical failure evidence"
        )

        try Expect.equal(
            failedAttemptRoundTrip.route == nil,
            true,
            "failed inference attempts do not invent a successful route"
        )
        try Expect.equal(
            failedAttemptRoundTrip.usage == nil,
            true,
            "failed inference attempts do not invent successful attempt usage"
        )
        try Expect.equal(
            failedAttemptRoundTrip.invocations.count,
            1,
            "failed inference attempts preserve their partial invocation evidence"
        )
        try Expect.equal(
            failedEvidence.type,
            "FixtureTerminalFailure",
            "failed attempt preserves canonical failure type"
        )
        try Expect.equal(
            failedEvidence.message,
            "fixture terminal failure",
            "failed attempt preserves canonical failure message"
        )

        var recoveredAttempt = firstAttempt.record
        recoveredAttempt.invocations.append(
            InferenceInvocationRecord(
                index: 1,
                selection: firstAttempt.record.selection,
                route: firstRoute,
                usage: firstAttempt.record.usage,
                metadata: firstAttempt.record.metadata
            )
        )

        let recoveredUsage = InferenceBudgetUsage(
            attempts: [
                recoveredAttempt,
            ]
        )

        try Expect.equal(
            recoveredUsage.attemptCount,
            1,
            "mechanical recovery does not create another semantic inference attempt"
        )
        try Expect.equal(
            recoveredUsage.invocationCount,
            2,
            "mechanical recovery can add another model invocation inside one semantic attempt"
        )
        try Expect.equal(
            recoveredUsage.reportedTotalTokens,
            10,
            "token accounting includes every model invocation inside the semantic attempt"
        )

        let semanticBudget = try InferenceBudget(
            maximumAttempts: 2,
            maximumTotalTokens: 20
        )
        let nextSemanticAttempt = try semanticBudget.nextAttempt(
            priorAttempts: [
                recoveredAttempt,
            ]
        )

        try Expect.equal(
            nextSemanticAttempt.index,
            1,
            "two model invocations inside one attempt still consume only one semantic attempt"
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
                context: .default,
                priorAttempts: [
                    firstAttempt.record,
                ]
            )
        } catch InferenceBudgetError.maximumTotalTokensReached(
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
            "token-limit rejection occurs before another model invocation"
        )

        let unavailableRecorder = BudgetInvocationRecorder()
        let unavailableExecutor = InferenceAttemptExecutor(
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
        let unavailableRealization = InferenceRealizationConfiguration(
            strategy: .direct,
            instructions: "Exercise missing usage handling.",
            budget: try InferenceBudget(
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
            context: .default,
            priorAttempts: []
        )

        var missingUsageBlocked = false

        do {
            _ = try await unavailableExecutor.execute(
                BudgetFixtureInference.self,
                input: BudgetFixtureInference.Input(
                    value: "second"
                ),
                realization: unavailableRealization,
                context: .default,
                priorAttempts: [
                    unavailableFirst.record,
                ]
            )
        } catch InferenceBudgetError.totalTokenUsageUnavailable {
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
                "semantic_attempts",
                String(recoveredUsage.attemptCount)
            ),
            .field(
                "model_invocations",
                String(recoveredUsage.invocationCount)
            ),
            .field(
                "budget_parse",
                String(
                    invalidAttemptBudgetRejected
                        && invalidBudgetDecodeRejected
                )
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
