import Schema
import SchemaMacros

public struct AssessCandidateAction: AgentInference {
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        public var goal: String
        public var state: String
        public var candidate: DetermineNextAction.Candidate

        public init(
            goal: String,
            state: String,
            candidate: DetermineNextAction.Candidate
        ) {
            self.goal = goal
            self.state = state
            self.candidate = candidate
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        /// Whether the candidate is appropriate to perform next.
        public var acceptable: Bool

        /// Concise assessment of why the candidate is or is not appropriate.
        public var assessment: String

        public init(
            acceptable: Bool,
            assessment: String
        ) {
            self.acceptable = acceptable
            self.assessment = assessment
        }
    }

    public static let definition = AgentInferenceDefinition(
        identifier: "assess_candidate_action",
        purpose: "Assess whether one candidate action is appropriate for the current goal and state.",
        title: "Assess Candidate Action",
        tags: [
            "assessment",
            "decision",
            "action",
        ]
    )
}
