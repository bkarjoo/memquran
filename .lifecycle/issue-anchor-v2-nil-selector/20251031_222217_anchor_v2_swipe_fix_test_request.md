# Testing Request - Anchor System V2: Downward Swipe Bug Fix

## Overview
Please test the bug fix for the Anchor System V2 downward swipe race condition. This fix addresses the intermittent behavior discovered during manual testing where downward swipes would inconsistently jump to anchors positioned below the current position.

## Context

### Original Issue:
- **Date Found:** 2025-10-31 during Phase 2 manual testing
- **Test Item:** Item 7 - Downward swipe with anchor below
- **Symptom:** Downward swipe navigation was inconsistent when anchor was below current position
- **Root Cause:** Race condition - gesture handler evaluated state at gesture END instead of gesture START

### Fix Implemented:
- **Commit:** b586388
- **File Modified:** MemQuran/ContentView.swift (lines 413-415, 559-637)
- **Solution:** Capture `anchorWord` and `selectedWord` state at gesture START (`.onChanged`) instead of gesture END (`.onEnded`)
- **Scope:** Applied to both upward AND downward swipes for consistency

## Test Environment Setup

### Prerequisites:
- Latest code (commit b586388 or later)
- iOS Simulator or physical iOS device
- MemQuran app built and running

### Launch Instructions:
1. Open MemQuran app
2. Navigate to any surah/page with multiple verses
3. Enable hidden mode

## Test Scenarios

### PRIMARY TEST - Downward Swipe Bug Fix

#### Test 1: Downward Swipe with Anchor Below (Single Attempt)
**Purpose:** Verify downward swipe now consistently jumps to anchor below

**Steps:**
1. Navigate to verse 3 (or any verse)
2. Set anchor at verse 5 (anchor is BELOW current position - red square should be lower)
3. Verify: Blue selection square at verse 3, red anchor square at verse 5
4. Swipe down ONCE

**Expected Results:**
- ✅ Should jump to verse 5 (anchor position)
- ✅ Blue selection square should move to verse 5
- ✅ Red anchor square should remain at verse 5

**Pass/Fail:** ______

---

#### Test 2: Downward Swipe with Anchor Below (Rapid Attempts)
**Purpose:** Verify fix eliminates race condition during rapid swipes

**Steps:**
1. Navigate to verse 3
2. Set anchor at verse 5 (anchor is BELOW)
3. Swipe down rapidly 3-4 times in quick succession

**Expected Results:**
- ✅ FIRST swipe should jump to verse 5 (anchor)
- ✅ SUBSEQUENT swipes should behave normally (no anchor below anymore)
- ✅ ALL swipes should be consistent (no intermittent failures)

**Pass/Fail:** ______

---

#### Test 3: Downward Swipe with Anchor Below (Cross-Page)
**Purpose:** Verify fix works when anchor is on different page

**Steps:**
1. Navigate to page 10, verse 3
2. Set anchor at page 10, verse 7 (near bottom, might be on next page in view)
3. Navigate back to page 10, verse 3
4. Swipe down multiple times

**Expected Results:**
- ✅ Should consistently jump to anchor at verse 7
- ✅ No intermittent behavior

**Pass/Fail:** ______

---

### REGRESSION TESTS - Ensure Fix Didn't Break Other Features

#### Test 4: Upward Swipe with Anchor Above (Regression)
**Purpose:** Verify upward swipe still works correctly after fix

**Steps:**
1. Navigate to verse 10
2. Set anchor at verse 5 (anchor is ABOVE current position)
3. Swipe up multiple times rapidly

**Expected Results:**
- ✅ FIRST swipe should jump to verse 5 (anchor)
- ✅ SUBSEQUENT swipes should behave normally
- ✅ Consistent behavior (no race conditions)

**Pass/Fail:** ______

---

#### Test 5: Downward Swipe WITHOUT Anchor (Regression)
**Purpose:** Verify normal downward swipe still works when no anchor exists

**Steps:**
1. Ensure no anchor is set (no red square)
2. Navigate to verse 3
3. Swipe down

**Expected Results:**
- ✅ Should go to verse 4 (normal next verse behavior)
- ✅ No errors or unexpected jumps

**Pass/Fail:** ______

---

#### Test 6: Upward Swipe WITHOUT Anchor (Regression)
**Purpose:** Verify normal upward swipe still works when no anchor exists

**Steps:**
1. Ensure no anchor is set (no red square)
2. Navigate to verse 10
3. Swipe up

**Expected Results:**
- ✅ Should go to verse 9 (normal previous verse behavior)
- ✅ No errors or unexpected jumps

**Pass/Fail:** ______

---

#### Test 7: Horizontal Swipes Unaffected (Regression)
**Purpose:** Verify left/right page navigation wasn't affected by gesture handler changes

**Steps:**
1. Set an anchor anywhere
2. Swipe left (next page)
3. Swipe right (previous page)

**Expected Results:**
- ✅ Normal page navigation works
- ✅ Anchor state preserved correctly
- ✅ No unexpected behavior

**Pass/Fail:** ______

---

#### Test 8: 2-Page Mode (Regression)
**Purpose:** Verify fix works in 2-page mode (both single and double page layouts)

**Steps:**
1. Switch to 2-page mode
2. Set anchor on left page
3. Navigate to different position
4. Test upward and downward swipes

**Expected Results:**
- ✅ All swipe behaviors work correctly in 2-page mode
- ✅ State capture works regardless of page layout

**Pass/Fail:** ______

---

### DIAGNOSTIC TESTS - Verify State Capture

#### Test 9: Check Enhanced Logging
**Purpose:** Verify new diagnostic logs show correct anchor/selected IDs

**Steps:**
1. Open Xcode console/logs
2. Set anchor at verse 5 (note the word ID if visible)
3. Navigate to verse 3
4. Swipe down
5. Check logs for messages like: "⬇️ Swipe down -> jump to anchor (below) anchor=X selected=Y"

**Expected Results:**
- ✅ Log messages show correct anchor and selected word IDs
- ✅ IDs match the actual state at gesture START time
- ✅ Logs help confirm state was captured correctly

**Pass/Fail:** ______
**Log Output:** ______

---

## Test Execution Notes

### Automated Tests:
- Developer attempted to run automated tests but encountered infrastructure issues (deployment target mismatch)
- These are pre-existing issues unrelated to this bug fix
- **Action Required:** Manual testing only for this fix

### Build Verification:
- ✅ Build completed successfully with no errors
- ✅ No compiler warnings related to changes

## Success Criteria

**MUST PASS (Critical):**
- [ ] Test 1: Downward swipe with anchor below - single attempt
- [ ] Test 2: Downward swipe with anchor below - rapid attempts
- [ ] Test 4: Upward swipe regression test

**SHOULD PASS (Important):**
- [ ] Test 3: Cross-page downward swipe
- [ ] Test 5-6: Swipes without anchor
- [ ] Test 7-8: Other modes unaffected

**NICE TO HAVE:**
- [ ] Test 9: Diagnostic logging verification

## Reporting Instructions

After completing testing, create `.plan/response.md` with:

1. **Overall Status:** PASS / FAIL / PARTIAL
2. **Test Results:** Results for each test (pass/fail with notes)
3. **Issues Found:** Any bugs or unexpected behavior
4. **Logs:** Relevant log output from Test 9
5. **Recommendation:**
   - If all tests pass: "Ready for code review"
   - If tests fail: "Return to developer for fixes" + details
   - If infrastructure issues: Document and suggest next steps

## Additional Context

### Files Modified:
- `MemQuran/ContentView.swift` (lines 413-415, 559-637)

### Risk Assessment:
- **Risk Level:** Low
- Changes isolated to gesture handling logic
- No modifications to navigation functions
- Applied same pattern to both swipe directions

### Developer's Testing Recommendations:
See `.plan/archive/20251031_211042_anchor_v2_swipe_fix_response.md` for full developer notes.

---

**Testing Request Created:** 2025-10-31
**Assigned To:** Test Team
**Priority:** High (blocking completion of Anchor System V2)
