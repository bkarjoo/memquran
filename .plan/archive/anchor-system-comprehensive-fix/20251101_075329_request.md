# Development Request: Fix Nil Selector Edge Case in Anchor V2

**Date:** 2025-11-01
**Priority:** Medium-High
**From:** Project Planner
**Previous Work:** Commit 39bcfdc (original bug fix)

---

## Context

Testing team has completed re-test of Anchor V2 downward swipe bug fix. Results:
- ✅ Original bug (race condition with visible verses): **FIXED**
- ❌ New edge case discovered: **Nil selector bug** (requires fix)

Full test report archived at: `.plan/archive/20251101_071155_anchor_v2_retest_response.md`

---

## The Bug

**Problem:** When no verse is visible on the page (nil selector) and an anchor is set, vertical swipes do not jump to the anchor as expected. Instead, they perform normal navigation.

**Root Cause:** The current logic requires BOTH `capturedAnchorWord` AND `capturedSelectedWord` to be non-nil:

```swift
if let anchor = capturedAnchorWord, let selected = capturedSelectedWord, anchor > selected {
    // Jump to anchor
}
```

When `capturedSelectedWord=nil`, the `if let` unwrapping fails, causing fallback to normal navigation.

---

## Expected Behavior

When an anchor exists and selector is nil, ANY vertical swipe should jump to the anchor, since:
1. There's no current "position" to compare against (nil selector)
2. The anchor is a clear destination
3. User intent is likely to navigate to the anchor

---

## Recommended Solution

Handle the nil selector case separately:

```swift
// Handle nil selector case - if anchor exists and no current position, jump to it
if capturedAnchorWord != nil && capturedSelectedWord == nil {
    jumpToAnchor(to: capturedAnchorWord, onPage: capturedAnchorPage)
}
// Handle normal case with both anchor and selector
else if let anchor = capturedAnchorWord, let selected = capturedSelectedWord {
    if (value.translation.height < 0 && anchor < selected) ||
       (value.translation.height > 0 && anchor > selected) {
        jumpToAnchor(to: capturedAnchorWord, onPage: capturedAnchorPage)
    } else {
        // Normal navigation
    }
}
```

---

## Test Scenarios to Verify

After fixing, ensure these scenarios work:
1. ✅ Downward swipe with anchor below (visible verses) - should still work
2. ✅ Upward swipe with anchor above (visible verses) - should still work
3. ❌ Downward swipe with anchor below (nil selector) - **FIX THIS**
4. ❌ Upward swipe with anchor above (nil selector) - **FIX THIS**

---

## Files to Modify

Based on previous work, likely in:
- `MemQuran/ReadingFlowView.swift` (gesture handling logic)

Console logs from testing show the logic is in the gesture end handler around lines that capture anchor/selector state.

---

## Requirements

1. Implement nil selector handling as recommended above
2. Preserve existing functionality (regression tests must still pass)
3. Add console logs if helpful for debugging edge cases
4. When complete, create response.md in .plan directory
5. Commit your changes with clear commit message

---

## Notes

- Severity: Medium-High (works in common case, fails in edge case)
- Original fix (39bcfdc) is good, just needs enhancement for this edge case
- Testing team is ready to re-test once fix is complete

---

**Next Steps:**
1. Implement the fix
2. Test locally if possible
3. Commit changes
4. Create response.md in .plan directory
5. Planner will route to testing team for verification
