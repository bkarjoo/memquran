# Development Request - Debug Anchor V2 Downward Swipe Bug Fix

## Status: TESTING FAILED - DEBUG REQUIRED

**Date:** 2025-10-31
**Priority:** High
**Previous Commit:** b586388

---

## Issue Summary

Your bug fix for the downward swipe race condition **FAILED** manual testing. The code changes appear correct and build successfully, but the actual runtime behavior does not match expectations.

### Expected Behavior:
When anchor is BELOW current position and user swipes down → should jump DIRECTLY to anchor
- Example: verse 3 → verse 5 (direct jump)

### Actual Behavior:
App navigates through normal verse sequence instead of jumping
- Example: verse 3 → verse 4 → verse 5 (normal navigation, NOT a jump)

---

## Test Results

**Critical Tests:**
- ❌ **Test 1:** Downward swipe with anchor below (single) - FAILED
- ❌ **Test 2:** Downward swipe with anchor below (rapid) - FAILED
- ⚠️ **Test 3:** Cross-page downward swipe - NOT TESTED (blocked by Test 1 failure)

**Regression Tests:**
- ✅ **Test 4:** Upward swipe with anchor above - PASSED ✓
- ✅ **Test 5:** Downward swipe without anchor - PASSED ✓
- ✅ **Test 6:** Upward swipe without anchor - PASSED ✓
- ✅ **Test 7:** Horizontal swipes - PASSED ✓
- ⚠️ **Test 8:** 2-page mode - NOT TESTED (blocked)

**Overall:** 4/9 tests passed (44%) - Critical functionality FAILED

---

## Key Findings

### What's Working:
1. ✅ Upward swipe (Test 4) PASSED - using identical logic to downward swipe
2. ✅ Build succeeds with no errors/warnings
3. ✅ Code logic appears correct on review
4. ✅ All regression tests for normal navigation passed

### What's NOT Working:
1. ❌ Downward swipe does NOT jump to anchor below
2. ❌ Goes through normal navigation instead (verse by verse)
3. ⚠️ Diagnostic logs were NOT visible to tester (they didn't see expected log messages)

### Critical Observation:
**Upward swipe works but downward swipe doesn't** - yet they use identical logic (lines 593-596 vs 604-607). This suggests:
- Either the condition evaluation differs between directions
- Or the `jumpToAnchor()` function behaves differently when anchor is below vs above
- Or there's a timing/state issue specific to downward gestures

---

## Your Code (for reference)

### State Capture (lines 413-415):
```swift
@State private var capturedAnchorWord: Word? = nil
@State private var capturedSelectedWord: Word? = nil
@State private var hasSetCapturedAnchors = false
```

### Gesture Start (lines 559-566):
```swift
.onChanged { _ in
    if !hasSetCapturedAnchors {
        capturedAnchorWord = anchorWord
        capturedSelectedWord = selectedWord
        hasSetCapturedAnchors = true
    }
}
```

### Downward Swipe Handler (lines 604-607):
```swift
if let anchor = capturedAnchorWord, let selected = capturedSelectedWord, anchor > selected {
    writeLog("⬇️ Swipe down -> jump to anchor (below) anchor=\(anchor.id) selected=\(selected.id)")
    jumpToAnchor()
}
```

**Note:** Upward swipe (lines 593-596) uses identical pattern and WORKS correctly.

---

## Debugging Tasks Required

### 1. Verify State Capture
**Set breakpoint at ContentView.swift:604**
- [ ] Check if `capturedAnchorWord` is set (not nil)
- [ ] Check if `capturedSelectedWord` is set (not nil)
- [ ] Verify `anchor > selected` evaluates to `true` when anchor IS below
- [ ] Confirm values match expected anchor (verse 5) and selected (verse 3)

### 2. Investigate Logging
**Why didn't tester see diagnostic logs?**
- [ ] Add `print()` statements in addition to `writeLog()` as fallback
- [ ] Verify logs actually execute (breakpoint or console output)
- [ ] Check if `writeLog()` function is working correctly
- [ ] Ensure logs visible in Xcode console during testing

### 3. Compare Upward vs Downward Logic
**Upward works, downward doesn't - why?**
- [ ] Review comparison operators: `anchor < selected` (up) vs `anchor > selected` (down)
- [ ] Check if Word comparison (< and >) works correctly in both directions
- [ ] Verify Word IDs/indices behave as expected
- [ ] Test if anchor/selected order affects `jumpToAnchor()` execution

### 4. Investigate jumpToAnchor() Function
**Does it have directional behavior?**
- [ ] Review `jumpToAnchor()` implementation
- [ ] Check if it handles "anchor below" differently than "anchor above"
- [ ] Verify it's actually being called (add logging/breakpoint)
- [ ] Test if navigation direction affects its execution

### 5. Verify Gesture Timing
**Is .onChanged firing correctly?**
- [ ] Confirm `.onChanged` fires BEFORE `.onEnded`
- [ ] Check if `hasSetCapturedAnchors` flag is set correctly
- [ ] Verify state capture happens early enough in gesture lifecycle
- [ ] Test if rapid swipes affect timing

---

## Questions to Answer

1. **Are the diagnostic log messages appearing in your Xcode console?**
   - If not, why? Is `writeLog()` broken?

2. **Does `jumpToAnchor()` have different behavior when anchor is below vs. above?**
   - Review its implementation for directional logic

3. **Is `.onChanged` definitely firing before `.onEnded` in your testing?**
   - Add logging to verify gesture event order

4. **Do Word comparison operators (< and >) work correctly?**
   - Verify Word implements Comparable correctly
   - Test if `anchor > selected` evaluates as expected

5. **Why does upward swipe work but downward doesn't?**
   - They use identical logic - what's different at runtime?

---

## Next Steps

### Required Actions:
1. **Debug the downward swipe logic** using breakpoints and logging
2. **Identify root cause** of why condition doesn't trigger or `jumpToAnchor()` doesn't work
3. **Implement fix** addressing the actual runtime issue
4. **Test locally** with same test cases (verse 3 → anchor at verse 5 → swipe down)
5. **Add better diagnostic logging** that's guaranteed to be visible
6. **Commit fix** with clear explanation of what was wrong

### Deliverables:
Create `.plan/response.md` with:
- Root cause analysis (what was actually wrong?)
- Explanation of your fix
- Local test results showing it now works
- Updated commit hash
- Request for re-testing OR explanation if you need help

---

## Test Environment for Your Reference

**Tester Used:**
- Device: iOS Simulator - iPhone 16
- OS: iOS 18.6
- Build: Debug-iphonesimulator
- Commit: b586388

**Test Steps That Failed:**
1. Navigate to verse 3
2. Set anchor at verse 5 (anchor BELOW - red square lower than blue square)
3. Swipe down once
4. **EXPECTED:** Jump to verse 5
5. **ACTUAL:** Went to verse 4, then verse 5

---

## Additional Context

### Full Test Report:
See `.plan/archive/20251031_222530_testing_anchor_v2_swipe_fix_response.md` for complete test results and tester observations.

### Original Test Request:
See `.test/archive/20251031_222217_anchor_v2_swipe_fix_test_request.md` for test plan details.

### Code Location:
- File: `MemQuran/ContentView.swift`
- Relevant lines: 413-415, 559-637

---

**Request Created:** 2025-10-31 22:25
**Assigned To:** Development Team
**Blocked By:** Runtime behavior not matching code logic
**Blocking:** Anchor System V2 completion
