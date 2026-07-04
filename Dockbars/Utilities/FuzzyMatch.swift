import Foundation

/// Lightweight subsequence fuzzy matcher with ranking. Pure and unit-testable.
///
/// A query matches if all its characters appear in order in the candidate
/// (case/diacritic-insensitive). The score rewards contiguous runs, matches at
/// word starts, and a prefix match, so "saf" ranks "Safari" above "Some File".
enum FuzzyMatch {
    /// Returns a score (higher = better) or nil if the query doesn't match.
    static func score(_ query: String, in candidate: String) -> Int? {
        let q = Array(query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil))
        let c = Array(candidate.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil))
        guard !q.isEmpty else { return 0 }
        guard q.count <= c.count else { return nil }

        var score = 0
        var qi = 0
        var lastMatch = -2
        for (ci, char) in c.enumerated() {
            guard qi < q.count, char == q[qi] else { continue }
            score += 1
            if ci == lastMatch + 1 { score += 5 }          // contiguous run
            if ci == 0 { score += 10 }                       // prefix
            else if !c[ci - 1].isLetter && !c[ci - 1].isNumber { score += 3 } // word start
            lastMatch = ci
            qi += 1
        }
        guard qi == q.count else { return nil }             // all query chars consumed
        // Shorter candidates that fully consumed the query rank slightly higher.
        return score + max(0, 5 - (c.count - q.count) / 4)
    }

    static func matches(_ query: String, _ candidate: String) -> Bool {
        score(query, in: candidate) != nil
    }
}
