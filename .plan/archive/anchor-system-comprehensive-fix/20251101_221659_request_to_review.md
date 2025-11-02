**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** anchor-system-comprehensive-fix

## Assignment: Code Review - Direction Check for Nil Selector Anchor Jumps

### Context

After circuit breaker analysis, we identified the root cause of the anchor navigation bug: when selector is nil (at page boundary), swipe gestures were jumping to anchor regardless of direction. This violated user expectations.

### User Requirements (Validated)

1. **Upswipe from nil selector:** Should ONLY jump to anchor if anchor is ABOVE (on previous pages)
2. **Downswipe from nil selector:** Should ONLY jump to anchor if anchor is BELOW (on current/next pages)
3. **Page boundary definition:** The point where next swipe requires page change
4. **Direction logic:** Upswipe jumps to anchor above, downswipe jumps to anchor below - NEVER the opposite

### Changes Made

**File:** MemQuran/ContentView.swift

**1. Added helper function (lines 1624-1628):**
```swift
func getFirstWordOnPage(_ pageNumber: Int) -> WordIdentifier? {
    let words = getWordsForPage(pageNumber)
    return words.first
}
```
- Tested for pages 1-10, returns correct first word (e.g., page 1: 1:1:1, page 9: 2:58:1)

**2. Fixed upswipe nil selector logic (lines 604-624):**
- OLD: Jumped to anchor unconditionally when selector is nil
- NEW: Gets first word on current page, only jumps if `anchor < firstWord` (anchor is above)
- Otherwise: Normal navigation (previousVerse)

**3. Fixed downswipe nil selector logic (lines 664-684):**
- OLD: Jumped to anchor unconditionally when selector is nil
- NEW: Gets first word on current page, only jumps if `anchor > firstWord` (anchor is below)
- Otherwise: Normal navigation (nextVerse)

### Review Checklist

**State Space Analysis:**
- [ ] Nil selector + anchor above + upswipe → Jump to anchor ✓
- [ ] Nil selector + anchor below + upswipe → Normal navigation ✓
- [ ] Nil selector + anchor below + downswipe → Jump to anchor ✓
- [ ] Nil selector + anchor above + downswipe → Normal navigation ✓
- [ ] Nil selector + no anchor → Normal navigation ✓

**Edge Cases:**
- [ ] Anchor on same page as current page - does comparison work correctly?
- [ ] First word lookup fails (returns nil) - handled with fallback to normal navigation
- [ ] Anchor is first word on page - comparison logic handles equality correctly?

**Logic Verification:**
- [ ] Using `anchor < firstWord` for upswipe is correct (anchor must be above/before first word)
- [ ] Using `anchor > firstWord` for downswipe is correct (anchor must be below/after first word)
- [ ] `getFirstWordOnPage(currentPage)` returns correct reference word for comparison

**Code Quality:**
- [ ] No unnecessary variables added (previous `capturedCurrentPage` was removed)
- [ ] Clear comments explaining direction check logic
- [ ] Consistent with existing code patterns
- [ ] No code duplication

**Requirement Validation:**
- [ ] Implementation matches user's validated requirements (upswipe → anchor above, downswipe → anchor below)
- [ ] No deviation from specification
- [ ] Fixes the original bug (upswipe was jumping to anchor below)

### What to Verify

1. **Direction logic is correct:** Comparing anchor with first word on page correctly determines "above" vs "below"
2. **Edge case: anchor on same page:** What happens if anchor is on current page but after first word? Should upswipe jump to it or navigate?
3. **Helper function correctness:** `getFirstWordOnPage(_:)` uses existing `getWordsForPage(_:)` which is already tested
4. **No regression:** Non-nil selector cases remain unchanged

### Expected Outcome

✅ APPROVE if:
- Direction check logic is correct
- Edge cases are handled properly
- No regression in existing functionality

❌ REQUEST CHANGES if:
- Logic errors in direction comparison
- Edge cases not properly handled
- Code quality issues

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
