# Code Review Request: Anchor System V2 - Downward Swipe Bug

**Date:** 2025-10-31
**Requested by:** Project Planner
**Priority:** High

---

## Context

Manual testing of Anchor System V2 has been completed. Most tests passed, but one critical bug was found in Phase 2 testing.

---

## Bug Report from Manual Testing

**Bug:** Downward swipe to anchor is inconsistent (race condition suspected)

**Location:** ContentView.swift - downward swipe anchor navigation logic

**Steps to Reproduce:**
1. Set anchor at verse 5
2. Navigate back to verse 3 (earlier than anchor)
3. Swipe down → should jump to verse 5 anchor

**Expected:** Jump directly to verse 5 (the anchor)

**Actual:** Sometimes goes verse-by-verse (verse 3 → verse 4), doesn't jump to anchor. However:
- It DOES work when coming from previous page
- Sometimes it works, sometimes it doesn't (race condition suspected)

**Severity:** High (core feature inconsistency)

---

## Test Results Summary

- **Phase 1 (Basic Anchor Operations):** ✅ All passed
- **Phase 2 (Directional Navigation):** ⚠️ Item 7 failed (downward swipe)
- **Phase 3 (Scope Testing):** ✅ All passed
- **Phase 4 (Edge Cases):** ✅ All passed

---

## Your Task

Please investigate the downward swipe anchor logic in ContentView.swift:

1. Review the swipe down handler code (likely around lines 578-600 based on testing response)
2. Identify why downward swipe anchor navigation is inconsistent
3. Determine if this is a race condition, logic error, or state management issue
4. Compare with upward swipe logic (which works consistently)
5. Provide diagnosis and recommended fix

---

## Deliverable

Please provide your findings in `.plan/response.md` with:

1. **Root Cause Analysis:** What's causing the inconsistent behavior?
2. **Code Location:** Specific line numbers and code snippets
3. **Recommended Fix:** What needs to change to fix this bug
4. **Risk Assessment:** Could this affect other swipe gestures?

---

## Reference Files

- Anchor implementation: `MemQuran/ContentView.swift`
- Requirements: `.plan/REQUIREMENTS_V2_ANCHOR_SIMPLIFIED.md`
- Testing response: `.plan/archive/20251031_201718_testing_response.md`
