import Agentic
import Macros
import Schema

extension Standard.Inferences {
    @Inference
    public struct DetermineNextAction {
        public struct Candidate:
            Sendable,
            Codable,
            Hashable
        {
            public var identifier: String
            public var description: String

            public init(
                identifier: String,
                description: String
            ) {
                self.identifier = identifier
                self.description = description
            }
        }

        public struct Input:
            Sendable,
            Codable,
            Hashable
        {
            public var goal: String
            public var state: String
            public var candidates: [Candidate]

            public init(
                goal: String,
                state: String,
                candidates: [Candidate]
            ) {
                self.goal = goal
                self.state = state
                self.candidates = candidates
            }
        }

        @JSONSchema
        public struct Output:
            Sendable,
            Codable,
            Hashable
        {
            /// Identifier of the candidate that should be performed next.
            public var selectedActionIdentifier: String

            public init(
                selectedActionIdentifier: String
            ) {
                self.selectedActionIdentifier = selectedActionIdentifier
            }
        }

        public static let purpose =
            "Select the most appropriate next action from the supplied candidates for the current goal and state."
    }
}
