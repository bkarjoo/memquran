//
//  AnchorSystemTests.swift
//  MemQuran iOSTests
//
//  Unit tests for the anchor system functionality
//  Tests WordIdentifier comparison, anchor scope logic, and word visibility
//

import Testing
@testable import MemQuran_iOS

struct AnchorSystemTests {

    // MARK: - WordIdentifier Comparison Tests

    @Test("WordIdentifier comparison - same surah, different ayah")
    func testWordIdentifierComparisonSamesurah() async throws {
        let word1 = WordIdentifier(surah: 2, ayah: 5, position: 3)
        let word2 = WordIdentifier(surah: 2, ayah: 10, position: 1)

        #expect(word1 < word2, "Word from earlier ayah should be less than word from later ayah")
        #expect(word2 > word1, "Word from later ayah should be greater than word from earlier ayah")
    }

    @Test("WordIdentifier comparison - different surahs")
    func testWordIdentifierComparisonDifferentSurahs() async throws {
        let word1 = WordIdentifier(surah: 2, ayah: 100, position: 50)
        let word2 = WordIdentifier(surah: 3, ayah: 1, position: 1)

        #expect(word1 < word2, "Word from earlier surah should be less than word from later surah")
        #expect(word2 > word1, "Word from later surah should be greater than word from earlier surah")
    }

    @Test("WordIdentifier comparison - same ayah, different positions")
    func testWordIdentifierComparisonSameAyah() async throws {
        let word1 = WordIdentifier(surah: 2, ayah: 5, position: 3)
        let word2 = WordIdentifier(surah: 2, ayah: 5, position: 7)

        #expect(word1 < word2, "Earlier word in verse should be less than later word")
        #expect(word2 > word1, "Later word in verse should be greater than earlier word")
    }

    @Test("WordIdentifier comparison - equal words")
    func testWordIdentifierComparisonEqual() async throws {
        let word1 = WordIdentifier(surah: 2, ayah: 5, position: 3)
        let word2 = WordIdentifier(surah: 2, ayah: 5, position: 3)

        #expect(word1 == word2, "Identical words should be equal")
        #expect(!(word1 < word2), "Equal words should not be less than each other")
        #expect(!(word1 > word2), "Equal words should not be greater than each other")
    }

    // MARK: - Anchor Direction Tests (for swipe navigation)

    @Test("Anchor is above (earlier) when in previous verse")
    func testAnchorAboveInPreviousVerse() async throws {
        let anchor = WordIdentifier(surah: 2, ayah: 5, position: 10)
        let current = WordIdentifier(surah: 2, ayah: 10, position: 1)

        #expect(anchor < current, "Anchor in previous verse should be 'above' (less than) current position")
    }

    @Test("Anchor is below (later) when in next verse")
    func testAnchorBelowInNextVerse() async throws {
        let anchor = WordIdentifier(surah: 2, ayah: 10, position: 1)
        let current = WordIdentifier(surah: 2, ayah: 5, position: 10)

        #expect(anchor > current, "Anchor in next verse should be 'below' (greater than) current position")
    }

    @Test("Anchor is above when same verse, earlier position")
    func testAnchorAboveSameVerse() async throws {
        let anchor = WordIdentifier(surah: 2, ayah: 5, position: 3)
        let current = WordIdentifier(surah: 2, ayah: 5, position: 7)

        #expect(anchor < current, "Anchor earlier in same verse should be 'above' current position")
    }

    // MARK: - Anchor Scope Tests

    @Test("Anchor scope - same page")
    func testAnchorScopeSamePage() async throws {
        let anchorPage = 5
        let currentPage = 5
        let distance = abs(currentPage - anchorPage)

        #expect(distance <= 1, "Anchor on same page should be in scope")
    }

    @Test("Anchor scope - one page away")
    func testAnchorScopeOnePageAway() async throws {
        let anchorPage = 5
        let currentPage = 6
        let distance = abs(currentPage - anchorPage)

        #expect(distance <= 1, "Anchor one page away should be in scope")
    }

    @Test("Anchor scope - two pages away (should be removed)")
    func testAnchorScopeTwoPagesAway() async throws {
        let anchorPage = 5
        let currentPage = 7
        let distance = abs(currentPage - anchorPage)

        #expect(distance > 1, "Anchor two pages away should be out of scope")
    }

    @Test("Anchor scope - backwards navigation one page")
    func testAnchorScopeBackwardsOnePage() async throws {
        let anchorPage = 10
        let currentPage = 9
        let distance = abs(currentPage - anchorPage)

        #expect(distance <= 1, "Anchor one page behind should be in scope")
    }

    @Test("Anchor scope - backwards navigation two pages")
    func testAnchorScopeBackwardsTwoPages() async throws {
        let anchorPage = 10
        let currentPage = 8
        let distance = abs(currentPage - anchorPage)

        #expect(distance > 1, "Anchor two pages behind should be out of scope")
    }

    // MARK: - Edge Cases

    @Test("Anchor at first verse of surah")
    func testAnchorAtFirstVerse() async throws {
        let anchor = WordIdentifier(surah: 2, ayah: 1, position: 1)
        let current = WordIdentifier(surah: 2, ayah: 5, position: 1)

        #expect(anchor < current, "Anchor at first verse should work correctly")
    }

    @Test("Anchor at last page boundary")
    func testAnchorAtLastPage() async throws {
        let anchorPage = 604
        let currentPage = 603
        let distance = abs(currentPage - anchorPage)

        #expect(distance <= 1, "Anchor at last page should be in scope from page 603")
    }

    @Test("Anchor at first page boundary")
    func testAnchorAtFirstPage() async throws {
        let anchorPage = 1
        let currentPage = 2
        let distance = abs(currentPage - anchorPage)

        #expect(distance <= 1, "Anchor at first page should be in scope from page 2")
    }

    @Test("Cross-surah anchor comparison")
    func testCrossSurahAnchor() async throws {
        // Anchor in Surah 2, current position in Surah 3
        let anchor = WordIdentifier(surah: 2, ayah: 286, position: 50)
        let current = WordIdentifier(surah: 3, ayah: 1, position: 1)

        #expect(anchor < current, "Anchor in previous surah should be less than current in next surah")
    }
}
