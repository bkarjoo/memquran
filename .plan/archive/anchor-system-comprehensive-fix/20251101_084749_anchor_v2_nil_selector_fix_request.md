**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

## Assignment: Fix Anchor V2 Nil Selector Bug

**Priority:** High
**Context:** Testing revealed that the nil selector fix implemented in ContentView.swift (lines 603-606, 633-636) is not working correctly.

### Bug Description

The new nil selector handling code is not executing. When an anchor exists but the selector is nil, the app performs normal verse navigation instead of jumping to the anchor.

**Evidence from testing:**

Console logs show:
```
🎬 GESTURE START: captured anchor=2:63:16 selected=nil page=10
⬇️ DOWN SWIPE: capturedAnchor=2:63:16 capturedSelected=nil
⬇️ Swipe down -> next verse
```

**Expected:** Should log "⬇️ Swipe down -> jump to anchor (nil selector)" and jump to anchor
**Actual:** Logs "⬇️ Swipe down -> next verse" and performs normal navigation

### Root Cause Analysis

Even though the gesture start captures the anchor (as shown in "GESTURE START" log), the condition `capturedAnchorWord != nil && capturedSelectedWord == nil` on lines 603 and 633 is NOT being met during swipe processing.

The console shows the code is executing the "No anchor - normal navigation" else block instead (lines 622-627 for upward swipe, lines 652-657 for downward swipe).

This indicates that `capturedAnchorWord` is nil during swipe processing, even though the gesture start shows the anchor was captured. The captured anchor state is not being preserved properly when the selector is nil.

### Test Scenarios

**Passing:**
- ✅ Scenario 1: Downward swipe with anchor below (with selector)
- ✅ Scenario 2: Upward swipe with anchor above (with selector)

**Failing:**
- ❌ Scenario 3: Downward swipe with anchor below (nil selector)
- ❌ Scenario 4: Upward swipe with anchor above (nil selector)

### Investigation Steps

1. Add debug logging to confirm the values of `capturedAnchorWord` and `capturedSelectedWord` at the point where the nil selector conditions are evaluated (lines 603 and 633)
2. Verify the capture logic for `capturedAnchorWord` when `capturedSelectedWord` is nil
3. Investigate whether the gesture state capture is occurring properly for the nil selector case
4. Fix the issue so that anchor jumps work correctly when selector is nil

### Files to Review

- `MemQuran/ContentView.swift` (lines 603-606, 633-636, and related gesture capture logic)

### Testing Verification

After implementing the fix:
1. Build the project
2. Test in simulator with various anchor positions where selector is nil
3. Verify console logs show "jump to anchor (nil selector)" messages
4. Verify the app actually jumps to the anchor verse

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
