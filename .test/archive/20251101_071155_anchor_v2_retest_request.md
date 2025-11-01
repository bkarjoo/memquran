# Test Request: Anchor V2 Downward Swipe Bug Fix - RE-TEST

**Date:** 2025-11-01
**Priority:** HIGH
**From:** Project Planner
**Previous Test:** FAILED (see archive/20251031_222530_testing_anchor_v2_swipe_fix_response.md)
**Development Response:** See archive/20251101_*_development_anchor_v2_fix_response.md

---

## Context

The development team has completed a bug fix for the Anchor V2 downward swipe feature. This is a **RE-TEST** after the previous test failed. The developers have:

1. ✅ Identified root cause: Race condition between captured state and action execution
2. ✅ Fixed by applying captured values directly to `jumpToAnchor()`
3. ✅ Added comprehensive console logging for debugging
4. ✅ Build succeeded
5. ✅ Commit: 39bcfdc

---

## What Changed Since Last Test

**Root Cause Identified:**
- The gesture handler was checking `capturedAnchorWord` and `capturedSelectedWord` to decide whether to jump to anchor
- BUT `jumpToAnchor()` was using the **uncaptured** instance variables `anchorWord` and `anchorPage`
- This caused `jumpToAnchor()` to return early if those values had changed

**The Fix:**
1. Added `capturedAnchorPage` state variable (was missing before)
2. Modified `jumpToAnchor()` to accept optional parameters
3. Swipe handlers now pass captured values directly to `jumpToAnchor()`
4. Added comprehensive console logging (print + writeLog)

---

## Test Environment

**Required:**
- iPhone 16 Simulator (iOS 18.6) - same as previous test
- Xcode Console open to view diagnostic logs

**Configuration:**
- Build: Debug-iphonesimulator
- Mode: Hidden Mode only

---

## Critical Test Case

**Test 1: Downward Swipe with Anchor Below (THE BUG)**

1. Navigate to verse 3 (ayah marker selected)
2. Set anchor at verse 5 (any word in verse 5)
3. Swipe down once
4. **EXPECTED:** Jump DIRECTLY to verse 5 (NOT verse 4)
5. **CHECK CONSOLE:** Should see diagnostic logs showing:
   - `🎬 GESTURE START: captured anchor=1:5:X selected=1:3:Y`
   - `⬇️ DOWN SWIPE: capturedAnchor=1:5:X`
   - `⬇️ Comparing: anchor=1:5:X selected=1:3:Y anchor>selected=true`
   - `⬇️ Swipe down -> jump to anchor`
   - `🎯 jumpToAnchor() called`
   - `🎯 Jumping to anchor: 1:5:X`

**What to Look For:**
- ✅ Direct jump to verse 5 (no intermediate stop at verse 4)
- ✅ Console logs appear in Xcode (proving diagnostics work)
- ✅ NO "EARLY RETURN" message in logs
- ✅ Comparison shows `anchor>selected=true`

---

## Regression Tests

**Test 2: Upward Swipe with Anchor Above**
1. Navigate to verse 5
2. Set anchor at verse 3
3. Swipe up once
4. **EXPECTED:** Jump DIRECTLY to verse 3

**Test 3: Cross-Page Downward Swipe**
1. Navigate to verse on page N
2. Set anchor on page N+1
3. Swipe down
4. **EXPECTED:** Page changes to N+1, jumps to anchor

**Test 4-9: Run all tests from original test plan**
- Normal swipes without anchor (up/down/left/right)
- Anchor removal scenarios
- 2-page mode tests
- Edge cases

---

## Success Criteria

**PASS if:**
- ✅ Test 1 shows direct jump to verse 5 (no stop at verse 4)
- ✅ Console logs appear and show correct logic flow
- ✅ All regression tests pass
- ✅ No unexpected behavior

**FAIL if:**
- ❌ Still stops at intermediate verse 4
- ❌ No console logs appear
- ❌ Logs show "EARLY RETURN" in `jumpToAnchor()`
- ❌ Any regression test fails

---

## Deliverables

**Required in response.md:**
1. Test execution date/time
2. Test results for all cases (PASS/FAIL with details)
3. **Console log output** for Test 1 (copy from Xcode)
4. Any unexpected behavior observed
5. Overall recommendation: PASS to code review OR FAIL back to development

**If Test Fails:**
- Include full console log output
- Note exact verse numbers and pages used
- Describe observed vs. expected behavior
- Any error messages or warnings

---

## Notes

- The enhanced logging makes debugging much easier
- If tests fail, console logs will show us exactly what's happening
- Please test on the SAME environment (iPhone 16 Simulator) for consistency
- Feel free to run additional edge case tests if you discover issues

---

**Created:** 2025-11-01
**Status:** READY FOR TESTING
**Route:** .test → .plan (response.md)
