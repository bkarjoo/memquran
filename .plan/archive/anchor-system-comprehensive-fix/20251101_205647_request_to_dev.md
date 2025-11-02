**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** anchor-system-comprehensive-fix

## Bug Fix: Swipe Navigation Hijacked by Anchor Jumps at Page Boundaries

### Context

During comprehensive testing of the anchor system fixes (commit ef50088), all three original fixes passed validation:
- ✓ Visual priority fix working correctly
- ✓ Scope distance logic correctly implemented (±1 page)
- ✓ Nil selector persistence fix working correctly

However, testing revealed a separate interaction bug in the swipe gesture handling logic.

### Bug Description

**Issue:** When an anchor is set on the CURRENT page, swiping up from the top of the page jumps to the anchor instead of navigating to the previous page.

**Expected Behavior:**
- Swipe up at top of page → Navigate to previous page (regardless of anchor state)
- Swipe down at bottom of page → Navigate to next page (regardless of anchor state)
- Swipe up/down in middle of page with anchor → Jump to anchor (preserve existing feature)

**Actual Behavior:**
- Swipe up at top of page with anchor on same page → Jumps to anchor below instead of navigating to previous page

**Affected Platforms:**
- iPhone: Confirmed across all pages tested (1, 10, 11, 604)
- iPad: Confirmed in both 1-page and 2-page modes
- macOS: Anchors can be selected but up/down arrows do not navigate to them

**Impact:** Breaks normal page navigation when anchors are active, forcing users into unexpected anchor jumps instead of page transitions.

### Root Cause

The swipe gesture logic in ContentView.swift (lines 605-629 for up swipe, 640-664 for down swipe) prioritizes anchor jumps over page navigation without considering page boundaries:

```swift
// Line 611-623: Up swipe with anchor
else if let anchor = capturedAnchorWord, let selected = capturedSelectedWord {
    if anchor < selected {
        // Anchor is above - jump to it
        jumpToAnchor(to: capturedAnchorWord, onPage: capturedAnchorPage)
    } else {
        // Anchor below - normal navigation
        previousVerse()
    }
}
```

**Problem:** When `anchor < selected` (anchor is above selected word), the code always jumps to anchor, even if the user is at the top of a page and expects page navigation.

### Requirements

**Fix the swipe gesture logic to respect page boundaries:**

1. **Page Boundary Detection:** Determine if the current scroll position is at the top or bottom of the page
   - Top of page: ScrollView is scrolled to minimum position
   - Bottom of page: ScrollView is scrolled to maximum position

2. **Swipe-Up Logic (at top of page):**
   - If at top of page AND swipe up → `previousVerse()` (navigate to previous page)
   - If NOT at top of page AND anchor exists AND anchor < selected → `jumpToAnchor()`
   - Otherwise → `previousVerse()`

3. **Swipe-Down Logic (at bottom of page):**
   - If at bottom of page AND swipe down → `nextVerse()` (navigate to next page)
   - If NOT at bottom of page AND anchor exists AND anchor > selected → `jumpToAnchor()`
   - Otherwise → `nextVerse()`

4. **Preserve Nil Selector Behavior:**
   - Lines 605-609 and 640-644 (nil selector jumps to anchor) should remain unchanged
   - Only modify the logic for when both anchor and selector exist

### Implementation Notes

**ScrollView Position Detection:**
You'll need to track the ScrollView's scroll position to determine if user is at top/bottom of page. Consider using:
- `ScrollViewReader` with position tracking
- `PreferenceKey` to capture scroll offset
- Or existing state if scroll position is already tracked elsewhere in the code

**Testing Considerations:**
- Verify page boundary detection works in both 1-page and 2-page modes
- Ensure anchor jumps still work when swiping from middle of page
- Test on iPhone, iPad, and macOS platforms
- Verify nil selector behavior remains intact

**macOS Arrow Key Issue:**
The test report mentioned "On macOS: anchors can be selected but up/down arrows do not navigate to them." Investigate if this is related to the same root cause or a separate macOS-specific issue.

### Success Criteria

After fix is implemented:
1. Swipe up at top of page → Navigates to previous page (regardless of anchor)
2. Swipe down at bottom of page → Navigates to next page (regardless of anchor)
3. Swipe up in middle of page with anchor above → Jumps to anchor
4. Swipe down in middle of page with anchor below → Jumps to anchor
5. All regression tests still pass
6. Visual priority, scope distance, and nil selector persistence fixes remain intact

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
