**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** issue-anchor-v2-nil-selector

## Critical Bug Fix Needed - Infinite Loop After Anchor Jump

The test team has identified that commit e2ad8a2 is **fundamentally wrong** and creates a critical infinite loop bug. The fix must be reverted and the root cause properly addressed.

## Test Team Findings

**What Works:**
- Commit ae41f7a correctly enables anchor jumps when selectedWord is nil
- The anchor jump itself works correctly

**Critical Bug Discovered:**
After a successful anchor jump in nil selector scenario:
1. User navigates to next page (e.g., page 11)
2. selectedWord becomes nil again on the new page
3. This triggers ANOTHER anchor jump back to the anchor page (page 10)
4. This creates an **infinite loop** - user cannot navigate away from anchor page
5. App becomes completely unusable

**Console Evidence:**
```
📄 Loading page data for page 11, got 15 lines
🎬 GESTURE START: captured anchor=2:60:29 selected=nil page=10
⬇️ DOWN SWIPE: capturedAnchor=2:60:29 capturedSelected=nil
🔍 DEBUG: anchorNotNil=true selectedIsNil=true combined=true
⬇️ Swipe down -> jump to anchor (nil selector) anchor=2:60:29
🎯 jumpToAnchor() called: anchor=2:60:29 targetPage=10
📄 Loading page data for page 10, got 15 lines
```

## Why Commit e2ad8a2 is Wrong

The development team's understanding was incorrect:

**Dev team thought:**
- `unhideWord()` makes words visible
- The problem was about verse revealing
- Adding `unhideWord()` calls would fix navigation

**Reality:**
1. `unhideWord()` adds a WordInteraction record to the database for spaced repetition tracking
2. It has NOTHING to do with UI visibility or the selectedWord state variable
3. The WordData model (Models.swift:7-37) has no fields for hidden/visible state
4. The interactions array is for learning analytics, not UI state management
5. Adding database entries does not prevent selectedWord from becoming nil

## Root Cause Analysis

This is a **state management problem**:

1. After `jumpToAnchor()` executes, `selectedWord` is correctly set to the anchor word
2. When user navigates to next page, `selectedWord` becomes nil (THIS IS THE BUG)
3. Because anchor is still set and selectedWord is nil, the nil selector condition is met again
4. This triggers another anchor jump, creating infinite loop
5. User cannot navigate away from anchor page

## Required Fix

**Step 1: Revert commit e2ad8a2**
- The `unhideWord()` approach is conceptually wrong
- Remove the `unhideWord(anchor)` calls added at lines 1392 and 1398 in ContentView.swift

**Step 2: Investigate state management**
- Why does `selectedWord` become nil during page navigation after an anchor jump?
- Trace through the page loading code to find where selectedWord is being cleared
- Check the page transition lifecycle

**Step 3: Review anchor lifecycle**
- Examine `checkAndRemoveAnchorIfNeeded()` function (ContentView.swift:1403-1415)
- Determine if anchor should be cleared after first successful jump
- Consider if there should be a "jump once" flag to prevent infinite loops

**Step 4: Implement proper fix**
Consider these approaches:
1. Ensure `selectedWord` maintains its value during page navigation after anchor jump
2. Clear the anchor after first successful jump to prevent re-triggering
3. Add a flag to track if anchor jump has already occurred
4. Re-evaluate if nil selector scenario should even trigger anchor jumps

## Testing Requirements

After implementing the fix, test these scenarios:
1. Set anchor on verse 2:60:29
2. Swipe until selectedWord = nil
3. Swipe to trigger anchor jump → should work
4. Navigate to next page → should NOT trigger another anchor jump
5. Continue navigating freely → should work normally
6. App should not get stuck in infinite loop

## Build Requirements

- Ensure build completes successfully
- Run the app in simulator
- Commit changes with clear message explaining the state management fix

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
