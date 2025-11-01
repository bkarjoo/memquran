# Testing Request - Anchor System V2

## Overview
Please test the simplified anchor system implemented in Phase 4. The anchor system allows users to mark a word and quickly jump to it using swipe gestures.

## What Changed

### Key Behavior Changes:
1. **No automatic anchor creation** - Anchors must be manually set by tapping words
2. **Directional swipe logic** - Up/down swipes check anchor direction before jumping
3. **Last visible word can be anchor** - No restriction on which visible word can be set
4. **Updated scope** - Anchor auto-removes when 2+ pages away (was "current or previous page")

## Test Environment Setup

### Prerequisites:
- iOS Simulator or physical iOS device
- MemQuran app built from latest code (commit: "Implement simplified anchor requirements V2")

### Launch Instructions:
1. Open MemQuran app
2. Navigate to any surah/page
3. Enable hidden mode (if testing anchor setting)

## Test Scenarios

### Test 1: Setting an Anchor (Manual Creation)
**Purpose:** Verify users can manually set anchors by tapping visible words

**Steps:**
1. Enable hidden mode
2. Tap any visible word (blue square)

**Expected Results:**
- ✅ Word should turn red (anchor indicator)
- ✅ No other side effects (no navigation)
- ✅ Last visible word in verse should also be settable as anchor

**Pass/Fail:** ______

---

### Test 2: Moving an Anchor
**Purpose:** Verify tapping a different word moves the anchor

**Steps:**
1. Set an anchor on word A (turns red)
2. Tap a different visible word B (blue square)

**Expected Results:**
- ✅ Word A returns to blue
- ✅ Word B turns red (new anchor position)
- ✅ Only one anchor exists at a time

**Pass/Fail:** ______

---

### Test 3: Removing an Anchor
**Purpose:** Verify tapping the anchor removes it

**Steps:**
1. Set an anchor (red square)
2. Tap the red anchor square

**Expected Results:**
- ✅ Anchor removed (word turns back to blue)
- ✅ No anchor exists after removal

**Pass/Fail:** ______

---

### Test 4: Up Swipe with Anchor Above Current Position
**Purpose:** Verify up swipe jumps to anchor when anchor is earlier in the Quran

**Steps:**
1. Set anchor at verse 5
2. Navigate forward to verse 10
3. Swipe up

**Expected Results:**
- ✅ Should jump directly to verse 5 (anchor position)
- ✅ Should NOT go to verse 9 (previous verse)
- ✅ Anchor remains in place

**Pass/Fail:** ______

---

### Test 5: Up Swipe with Anchor Below Current Position
**Purpose:** Verify up swipe uses normal navigation when anchor is later in the Quran

**Steps:**
1. Set anchor at verse 10
2. Navigate backward to verse 5
3. Swipe up

**Expected Results:**
- ✅ Should go to verse 4 (previous verse)
- ✅ Should NOT jump to anchor at verse 10
- ✅ Normal backwards navigation

**Pass/Fail:** ______

---

### Test 6: Up Swipe with No Anchor
**Purpose:** Verify up swipe uses normal navigation when no anchor exists

**Steps:**
1. Ensure no anchor is set
2. At any verse, swipe up

**Expected Results:**
- ✅ Should go to previous verse
- ✅ No anchor should be automatically created
- ✅ Normal backwards navigation

**Pass/Fail:** ______

---

### Test 7: Down Swipe with Anchor Below Current Position
**Purpose:** Verify down swipe jumps to anchor when anchor is later in the Quran

**Steps:**
1. Set anchor at verse 10
2. Navigate backward to verse 5
3. Swipe down

**Expected Results:**
- ✅ Should jump directly to verse 10 (anchor position)
- ✅ Should NOT go to verse 6 (next verse)
- ✅ Anchor remains in place

**Pass/Fail:** ______

---

### Test 8: Down Swipe with Anchor Above Current Position
**Purpose:** Verify down swipe uses normal navigation when anchor is earlier in the Quran

**Steps:**
1. Set anchor at verse 5
2. Navigate forward to verse 10
3. Swipe down

**Expected Results:**
- ✅ Should go to verse 11 (next verse)
- ✅ Should NOT jump to anchor at verse 5
- ✅ Normal forwards navigation

**Pass/Fail:** ______

---

### Test 9: Down Swipe with No Anchor
**Purpose:** Verify down swipe uses normal navigation when no anchor exists

**Steps:**
1. Ensure no anchor is set
2. At any verse, swipe down

**Expected Results:**
- ✅ Should go to next verse
- ✅ No anchor should be automatically created
- ✅ Normal forwards navigation

**Pass/Fail:** ______

---

### Test 10: Anchor Scope - Within Range
**Purpose:** Verify anchor persists when within 1 page distance

**Steps:**
1. Set anchor at page 1
2. Navigate to page 2
3. Check if anchor still exists
4. Navigate back to page 1
5. Check if anchor still exists

**Expected Results:**
- ✅ Anchor should remain visible at page 2 (within +/- 1 page)
- ✅ Anchor should remain visible when returning to page 1
- ✅ Swipe gestures should still jump to anchor

**Pass/Fail:** ______

---

### Test 11: Anchor Scope - Out of Range
**Purpose:** Verify anchor auto-removes when more than 1 page away

**Steps:**
1. Set anchor at page 1
2. Navigate to page 3 (2 pages away)
3. Check if anchor exists

**Expected Results:**
- ✅ Anchor should be automatically removed
- ✅ No red square visible when returning to page 1
- ✅ Swipe gestures should use normal navigation

**Pass/Fail:** ______

---

### Test 12: Setting Last Visible Word as Anchor
**Purpose:** Verify the last visible word in a verse can be set as anchor

**Steps:**
1. In hidden mode, identify the last visible word in current verse (rightmost blue square)
2. Tap the last visible word

**Expected Results:**
- ✅ Last visible word should turn red (becomes anchor)
- ✅ No restriction or error
- ✅ Functions same as any other anchor

**Pass/Fail:** ______

---

### Test 13: Cross-Verse Anchor Navigation
**Purpose:** Verify anchor navigation works across different verses

**Steps:**
1. Set anchor on word 3 of verse 5
2. Navigate to verse 8
3. Swipe up (should jump back to anchor)
4. Verify position

**Expected Results:**
- ✅ Should jump to word 3 of verse 5
- ✅ Verse display should show verse 5
- ✅ Anchor remains at correct position

**Pass/Fail:** ______

---

### Test 14: Multiple Direction Changes
**Purpose:** Verify anchor navigation works with multiple direction changes

**Steps:**
1. Set anchor at verse 5
2. Navigate forward to verse 10
3. Swipe up (should jump to verse 5)
4. Navigate forward to verse 10 again
5. Swipe up again (should jump to verse 5)

**Expected Results:**
- ✅ Each up swipe should jump to verse 5
- ✅ Anchor should persist through multiple jumps
- ✅ Navigation should be consistent

**Pass/Fail:** ______

---

### Test 15: 2-Page Mode Scope
**Purpose:** Verify anchor scope works correctly in 2-page display mode

**Steps:**
1. Enable 2-page display mode (if available)
2. Set anchor on left page
3. Navigate forward/backward
4. Verify scope behavior

**Expected Results:**
- ✅ Anchor removed when both displayed pages are more than 1 page away
- ✅ actualDisplayedPage logic handles 2-page correctly
- ✅ Scope calculation accounts for both visible pages

**Pass/Fail:** ______

---

## Edge Cases to Test

### Edge Case 1: Anchor at First Verse
**Steps:**
1. Set anchor at first verse of a surah
2. Navigate forward
3. Swipe up

**Expected:** Should jump to first verse (anchor)

**Pass/Fail:** ______

---

### Edge Case 2: Anchor at Last Verse
**Steps:**
1. Set anchor at last verse of a surah
2. Navigate backward
3. Swipe down

**Expected:** Should jump to last verse (anchor)

**Pass/Fail:** ______

---

### Edge Case 3: Rapid Swipes
**Steps:**
1. Set anchor at verse 5
2. Navigate to verse 10
3. Perform rapid up swipes (3-4 times quickly)

**Expected:** Each swipe should jump to verse 5, navigation should be stable

**Pass/Fail:** ______

---

### Edge Case 4: Anchor During Page Transition
**Steps:**
1. Set anchor near page boundary
2. Navigate so anchor is at edge of scope
3. Test swipe navigation

**Expected:** Anchor should be removed when crossing scope boundary

**Pass/Fail:** ______

---

## Regression Testing

### Verify No Regressions:
- [ ] Normal up/down swipe navigation (without anchor) works as before
- [ ] Word selection in normal mode works as before
- [ ] Hidden mode word revealing works as before
- [ ] Page navigation works as before
- [ ] Surah/verse display accurate
- [ ] No crashes or freezes
- [ ] Performance is acceptable

## Bug Reporting Template

If you find issues, report them using this format:

```
**Bug Title:** [Brief description]

**Test Scenario:** [Which test case]

**Steps to Reproduce:**
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happened]

**Severity:** [Critical/High/Medium/Low]

**Screenshots/Video:** [If applicable]

**Device/Simulator:** [iOS version, device model]
```

## Summary Checklist

After completing all tests, verify:

- [ ] All 15 main test scenarios passed
- [ ] All 4 edge cases passed
- [ ] No regressions found
- [ ] Performance is acceptable
- [ ] UI indicators (red/blue squares) work correctly
- [ ] No crashes or errors observed
- [ ] Any bugs reported using template above

## Notes Section

Use this space for additional observations:

---
---
---

## Sign-off

**Tester Name:** _________________

**Date:** _________________

**Overall Status:** [ ] PASS  [ ] FAIL  [ ] NEEDS REVIEW

**Comments:**
