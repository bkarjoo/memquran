# Anchor System Documentation Index

**Purpose:** Quick reference to all anchor system documentation to ensure nothing is forgotten.

---

## Primary Documents

### 1. Complete Behavior Specification
**File:** `.plan/COMPLETE_ANCHOR_BEHAVIOR_SPEC.md`
**Purpose:** Exhaustive specification of anchor behavior for ALL scenarios
**Status:** APPROVED by user (2025-11-01)
**Use When:**
- Implementing new anchor features
- Debugging anchor issues
- Testing anchor functionality
- Understanding expected behavior

**Key Decisions Documented:**
- Scope: +/- 1 page only
- Visual: Red only when overlapping
- Nil selector: Directional logic applies
- Persistence: Anchor always persists after jump

---

### 2. Comprehensive Analysis
**File:** `.plan/COMPREHENSIVE_ANALYSIS.md`
**Purpose:** Root cause analysis of 4-iteration fix-test-bug cycle
**Status:** Completed
**Use When:**
- Understanding why previous fixes failed
- Learning from mistakes
- Planning similar complex features

**Key Insights:**
- Why incremental fixes don't work
- State management design issues
- Testing whack-a-mole pattern

---

---

## Development Request

**File:** `.lifecycle/issue-page-navigation-fixes/20251101_185412_request_to_dev.md`
**Purpose:** Current comprehensive fix request sent to dev team
**Status:** In Progress
**References:** Complete spec and analysis documents

---

## Implementation Status

### Fixes Required:
1. **Visual Indicator Priority** - Not implemented
2. **Scope Distance (3→1 page)** - Not implemented
3. **Nil Selector Persistence** - Not implemented

**Current Code Status:** Has all 3 bugs documented above

---

## Testing Checklist

When dev completes fixes, test team should verify:
- Visual tests (red only when overlapping)
- Scope tests (removed at >1 page)
- Nil selector tests (anchor persists)
- Regression tests (all existing functionality)

**Full checklist:** See request.md section "Testing Checklist"

---

## History

### Iteration Timeline:
1. **Oct 31** - Fixed race condition (commit 39bcfdc)
2. **Oct 31** - Fixed nil selector bug (commit ae41f7a)
3. **Nov 1** - Fixed infinite loop (commit 02ef79a)
4. **Nov 1** - Fixed page navigation issues (commit f4827f1)
5. **Nov 1** - Discovered UI rendering bug (test team)
6. **Nov 1** - Created comprehensive analysis and spec (THIS WORK)
7. **Nov 1** - Sent comprehensive fix (3 bugs) to dev (CURRENT)

**Lesson Learned:** Incremental fixes create cycles. Need comprehensive state machine design.

---

## Quick Reference

**Where is anchor code?**
- `MemQuran/ContentView.swift` (all anchor logic)
  - Lines 283-298: Visual indicators
  - Lines 1371+: jumpToAnchor() function
  - Lines 1417-1431: checkAndRemoveAnchorIfNeeded() function
  - Swipe gesture handlers: Search for "jumpToAnchor"

**State Variables:**
- `@State private var anchorWord: WordIdentifier?`
- `@State private var anchorPage: Int?`
- `@State private var selectedWord: WordIdentifier?`

---

## Future Work

If anchor issues arise again:
1. Read `.plan/COMPLETE_ANCHOR_BEHAVIOR_SPEC.md` first
2. Understand which scenario is failing
3. Check if behavior matches spec
4. If spec is wrong, update spec BEFORE coding
5. If code is wrong, fix code to match spec
6. Test ALL scenarios, not just the failing one

---

## Document Maintenance

**Update this index when:**
- New anchor documentation is created
- Behavior spec changes (requires user approval)
- Implementation is completed
- New bugs are discovered

**Last Updated:** 2025-11-01
**Next Review:** After dev completes current fix request
