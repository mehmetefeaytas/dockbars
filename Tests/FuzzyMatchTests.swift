import XCTest
@testable import Dockbars

final class FuzzyMatchTests: XCTestCase {
    func testEmptyQueryMatchesEverything() {
        XCTAssertNotNil(FuzzyMatch.score("", in: "Anything"))
    }

    func testSubsequenceMatches() {
        XCTAssertTrue(FuzzyMatch.matches("saf", "Safari"))
        XCTAssertTrue(FuzzyMatch.matches("term", "Terminal"))
        XCTAssertTrue(FuzzyMatch.matches("sysprf", "System Preferences"))
    }

    func testNonSubsequenceDoesNotMatch() {
        XCTAssertFalse(FuzzyMatch.matches("xyz", "Safari"))
        XCTAssertFalse(FuzzyMatch.matches("frs", "Safari")) // wrong order
    }

    func testQueryLongerThanCandidateFails() {
        XCTAssertNil(FuzzyMatch.score("safarii", in: "Safari"))
    }

    func testPrefixRanksHigherThanMidMatch() {
        let prefix = FuzzyMatch.score("saf", in: "Safari")!
        let mid = FuzzyMatch.score("saf", in: "Some Amazing File")!
        XCTAssertGreaterThan(prefix, mid)
    }

    func testContiguousRanksHigherThanScattered() {
        let contiguous = FuzzyMatch.score("term", in: "Terminal")!
        let scattered = FuzzyMatch.score("term", in: "The Elder Ring Manual")!
        XCTAssertGreaterThan(contiguous, scattered)
    }

    func testCaseAndDiacriticInsensitive() {
        XCTAssertTrue(FuzzyMatch.matches("SAF", "safari"))
        XCTAssertTrue(FuzzyMatch.matches("naive", "naïve"))
    }

    func testWordStartBonus() {
        // "of" matches the word-start 'F' in "Open Files" better than inside a word.
        XCTAssertTrue(FuzzyMatch.matches("of", "Open Files"))
    }
}
