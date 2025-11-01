**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Status:** Complete - CRITICAL BUG PERSISTS

## Test Results Summary

**Commits Tested:**
- ae41f7a: Fix Anchor V2 nil selector bug using optional binding
- e2ad8a2: Fix jumpToAnchor() to unhide anchor word after jump

**Build Status:** ✅ Build successful, app launches correctly

**Test Scenarios Executed:**

### Scenario 1: Nil Selector Anchor Jump
- Set anchor on verse 2:60:29
- Swipe up until selectedWord = nil
- Swipe down to trigger anchor jump
- **Result:** ✅ Anchor jump works correctly
- **Console:** Shows `🔍 DEBUG: anchorNotNil=true selectedIsNil=true combined=true`
- **Console:** Shows `🎯 jumpToAnchor() called: anchor=2:60:29 targetPage=10`

### Scenario 2: Post-Anchor Navigation (THE CRITICAL BUG)
- Continue from Scenario 1 after successful anchor jump
- Navigate to next page (page 11)
- **BUG:** selectedWord becomes nil again when on new page
- **BUG:** This triggers ANOTHER unwanted anchor jump back to page 10
- **Result:** ❌ INFINITE LOOP - App keeps jumping back to anchor
- **Console Evidence:**
```
📄 Loading page data for page 11, got 15 lines
🎬 GESTURE START: captured anchor=2:60:29 selected=nil page=10
⬇️ DOWN SWIPE: capturedAnchor=2:60:29 capturedSelected=nil
🔍 DEBUG: anchorNotNil=true selectedIsNil=true combined=true
⬇️ Swipe down -> jump to anchor (nil selector) anchor=2:60:29
🎯 jumpToAnchor() called: anchor=2:60:29 targetPage=10
📄 Loading page data for page 10, got 15 lines
```

## Why Previous Attempts Were Incorrect

**I have thoroughly reviewed the previous fix attempts in the lifecycle history (.lifecycle/issue-anchor-v2-nil-selector/). Here's why they failed:**

### First Attempt (commit ae41f7a):
**What it did:** Fixed the nil selector detection using Swift optional binding pattern
**Why it's incomplete:** While it correctly detects and jumps to anchor when selectedWord is nil, it doesn't address what happens AFTER the jump. The fix makes the anchor jump work but creates an infinite loop scenario.

### Second Attempt (commit e2ad8a2):
**What it did:** Added `unhideWord(anchor)` calls at lines 1392 and 1398 in `jumpToAnchor()`
**Why it's fundamentally wrong:**
1. **Misunderstands the data model:** `unhideWord()` adds a `WordInteraction` record to the database for spaced repetition tracking. This has NOTHING to do with UI visibility or the selectedWord state variable.
2. **Wrong problem diagnosis:** The function name `unhideWord()` is misleading - it doesn't "unhide" anything visually. It only records that a word was reviewed in the learning database.
3. **Doesn't address root cause:** The actual problem is that `selectedWord` becomes nil when navigating to a new page after an anchor jump. Adding database entries doesn't prevent this.
4. **Database should be visibility-agnostic:** The WordData model (Models.swift:7-37) has no fields for hidden/visible state. The interactions array is for learning analytics, not UI state management.

## Root Cause Analysis

The core issue is a **state management problem**, not a database problem:

1. After `jumpToAnchor()` executes, `selectedWord` is correctly set to the anchor word
2. When the user navigates to the next page, `selectedWord` becomes nil (this is the bug)
3. Because an anchor is still set and selectedWord is nil, the nil selector condition is met again
4. This triggers another anchor jump, creating an infinite loop
5. The app becomes unusable because you can't navigate away from the anchor page

**The real fix needed:** Investigate why `selectedWord` becomes nil during page navigation after an anchor jump. The fix should ensure `selectedWord` maintains its value or is properly managed during page transitions, OR the anchor should be removed/disabled after the first successful jump.

## Bugs/Issues Discovered

**CRITICAL:** App is unusable after anchor jump in nil selector scenario
- **Severity:** Blocks all navigation
- **Impact:** User cannot navigate to any page other than the anchor page
- **Reproduction:** 100% consistent across all test runs

## Edge Cases Identified

- The nil selector fix assumes the user wants to keep jumping to the anchor indefinitely
- No mechanism exists to break out of the anchor jump cycle once started
- The `checkAndRemoveAnchorIfNeeded()` function (ContentView.swift:1403-1415) may not be working correctly

## Recommendation

**DO NOT MERGE** - This fix makes the app worse than before.

**Required Actions:**
1. **Revert commit e2ad8a2** - The `unhideWord()` approach is conceptually wrong
2. **Investigate state management:** Why does `selectedWord` become nil during page navigation after anchor jump?
3. **Review anchor lifecycle:** Should the anchor be automatically removed after first jump? Review `checkAndRemoveAnchorIfNeeded()` logic
4. **Consider alternative approaches:**
   - Should nil selector scenario even trigger anchor jumps?
   - Should anchor be cleared after successful navigation to it?
   - Should there be a "jump once" flag to prevent infinite loops?

## Blockers/Questions

None - testing complete. Waiting for development team to address the state management issue.

**When proceeding with this work, remember to read your README.md as crucial process requirements are documented there.**
