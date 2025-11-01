**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Status:** Complete

**Changes Made:**
- Files modified: ContentView.swift
- Functions added/changed:
  - Modified `jumpToAnchor()` to accept `fromNilSelector` parameter
  - Updated swipe gesture handlers to pass `fromNilSelector: true` when jumping from nil selector scenario
- Key implementation details:
  - Removed incorrect `unhideWord()` calls from lines 1392 and 1398 (revert of commit e2ad8a2)
  - Added logic to clear anchor after nil selector jumps to prevent infinite loop
  - Anchor is cleared immediately after a successful nil selector jump

**Root Cause Analysis:**
The infinite loop occurred because:
1. After `jumpToAnchor()` from nil selector, `selectedWord` was set to the anchor word
2. When user navigated to next page, `selectedWord` became nil again (due to line 1003 in `loadPageData()`)
3. This re-triggered the nil selector condition (anchor exists, selectedWord is nil)
4. This caused another jump back to the anchor page, creating infinite loop

**Solution Implemented:**
- Added `fromNilSelector` parameter to track when jump originates from nil selector scenario
- When `fromNilSelector: true`, anchor is immediately cleared after jump succeeds
- This prevents re-triggering the nil selector condition on subsequent navigation

**Build Results:**
Build successful - both macOS and iOS targets compile without errors. Only minor warnings about unused variables remain.

**Test Results:**
App launches successfully in simulator. Due to simulator limitations, manual testing of the specific anchor jump scenario is required to fully verify the fix.

**Issues/Blockers:**
None - the implementation is complete and ready for testing by QA team.

**Next Steps/Recommendations:**
1. Test team should verify the fix using the test scenarios described in the request
2. Test that anchor jump from nil selector works correctly
3. Verify user can navigate freely after the jump without getting stuck
4. Ensure normal anchor functionality (with selectedWord) remains unaffected

**When proceeding with this work, remember to read your README.md as crucial process requirements are documented there.**