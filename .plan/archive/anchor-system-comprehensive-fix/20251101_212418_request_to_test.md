**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** anchor-system-comprehensive-fix

## Comprehensive Testing Required

The swipe navigation boundary detection fix has been approved by review. You must run a **comprehensive test matrix** covering all state combinations and edge cases. Report **ALL findings in one response, not sequentially**.

### Context

The implementation fixes a bug where swipe navigation was hijacked by anchor jumps at page boundaries. The fix uses line-based boundary detection (checking if selected word is on lines 1-2 or 14-15 out of 15 total lines).

### Test Matrix - Core Functionality

**Swipe Up Behavior:**
1. [ ] Nil selector with anchor → Jump to anchor (original behavior)
2. [ ] At top boundary (lines 1-2) with anchor → Navigate to previous page (boundary priority)
3. [ ] Not at boundary with anchor above → Jump to anchor
4. [ ] Not at boundary with anchor below → Navigate to previous page
5. [ ] No anchor → Navigate to previous page

**Swipe Down Behavior:**
6. [ ] Nil selector with anchor → Jump to anchor (original behavior)
7. [ ] At bottom boundary (lines 14-15) with anchor → Navigate to next page (boundary priority)
8. [ ] Not at boundary with anchor below → Jump to anchor
9. [ ] Not at boundary with anchor above → Navigate to next page
10. [ ] No anchor → Navigate to next page

**macOS Arrow Keys:**
11. [ ] Up arrow at top boundary → Navigate to previous page
12. [ ] Down arrow at bottom boundary → Navigate to next page
13. [ ] Up arrow with anchor above (not at boundary) → Jump to anchor
14. [ ] Down arrow with anchor below (not at boundary) → Jump to anchor

### Test Matrix - Display Modes

**1-Page Mode:**
15. [ ] All swipe up behaviors work correctly
16. [ ] All swipe down behaviors work correctly
17. [ ] Boundary detection works at lines 1-2 and 14-15

**2-Page Mode:**
18. [ ] All swipe behaviors work on right page
19. [ ] **CRITICAL:** Swipe from left page at top boundary → behavior?
20. [ ] **CRITICAL:** Swipe from left page at bottom boundary → behavior?
21. [ ] Boundary detection searches both lineWords and lineWordsLeft dictionaries

### Test Matrix - Platforms

Test on all three platforms:
22. [ ] iPhone (iOS) - all core behaviors
23. [ ] iPad (iOS) - all core behaviors
24. [ ] macOS - all core behaviors including arrow keys

### Regression Testing - Original Anchor Fixes

Verify the three original anchor system fixes remain intact:

**Fix 1: Visual Priority**
25. [ ] When a word is both anchor and selected, red border shows (not blue)

**Fix 2: Scope Distance Logic**
26. [ ] Anchor only shows when within ±1 page of current page
27. [ ] Anchor hidden when >1 page away

**Fix 3: Nil Selector Persistence**
28. [ ] When selector is nil, swipes jump to anchor without clearing it
29. [ ] Anchor persists after nil selector jump

### Edge Cases

30. [ ] Selected word not found in line dictionaries → normal navigation (no crash)
31. [ ] Rapid swipes → no race conditions
32. [ ] Page boundaries at start/end of Quran
33. [ ] Very long words that might span multiple visual lines

### Success Criteria

ALL of the following must pass:
1. Swipe navigation works at page boundaries without being hijacked by anchor jumps
2. Boundary priority is correctly enforced (boundary > anchor when both conditions exist)
3. Anchor jumps still work in middle of page
4. Nil selector behavior preserved
5. All three original anchor fixes still work (no regressions)
6. Consistent behavior across iOS swipe gestures and macOS arrow keys

### Special Attention Areas

The review identified these areas for special scrutiny:
- **2-page mode left page boundaries** - The implementation doesn't document what should happen when swiping from the left page at boundaries. Test and document actual behavior.
- **Boundary threshold tuning** - Current thresholds are lines 1-2 and 14-15. Note if these feel too aggressive or conservative during testing.

### Reporting Format

For each failed test, report:
1. Test number and description
2. Expected behavior
3. Actual behavior
4. Steps to reproduce
5. Platform/display mode where it occurred

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
