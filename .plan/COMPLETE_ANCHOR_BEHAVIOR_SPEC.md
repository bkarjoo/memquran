# Complete Anchor System Behavior Specification

**Date:** 2025-11-01
**Purpose:** Exhaustive specification of anchor system behavior for all scenarios

---

## State Variables

```swift
@State private var anchorWord: WordIdentifier?      // The saved anchor point
@State private var anchorPage: Int?                 // Page where anchor is set
@State private var selectedWord: WordIdentifier?    // Current selection/position
```

---

## Visual Indicators

- **Red border (2pt)**: Shows where anchor is set (`anchorWord != nil`)
- **Blue border (2pt)**: Shows current selection (`selectedWord != nil`)
- **Both visible**: When anchor and selection are at same word, BOTH borders should be visible
  - Implementation: Red border should render on top OR use dual indicator (different sizes)

---

## Scenario 1: Setting an Anchor

### 1.1: Tap on word (no anchor exists)
**Initial State:**
```
anchorWord = nil
selectedWord = 2:60:20 (or any word, or nil)
currentPage = 10
```

**User Action:** Taps word 2:60:29

**Expected Behavior:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:29  (selection moves to tapped word)
```

**Visual:** Word 2:60:29 shows BOTH red border (anchor) and blue border (selection)

---

### 1.2: Tap on different word (anchor exists)
**Initial State:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:35
currentPage = 10
```

**User Action:** Taps word 2:60:40

**Expected Behavior:**
```
anchorWord = 2:60:40  (anchor MOVES to new word)
anchorPage = 10
selectedWord = 2:60:40
```

**Visual:**
- Old anchor (2:60:29) has NO borders
- New anchor (2:60:40) has BOTH red and blue borders

**Requirement Source:** REQUIREMENTS line 36-39 (Method 2: Tap on Different Word)

---

### 1.3: Tap on anchor itself
**Initial State:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:35 (different word)
currentPage = 10
```

**User Action:** Taps word 2:60:29 (the anchor)

**Expected Behavior:**
```
anchorWord = nil  (anchor is REMOVED)
anchorPage = nil
selectedWord = 2:60:29  (selection moves to that word)
```

**Visual:** Word 2:60:29 shows ONLY blue border (no red)

**Requirement Source:** REQUIREMENTS line 30-33 (Method 1: Tap on Anchor Itself)

---

## Scenario 2: Navigation Without Anchor

### 2.1: Swipe up (no anchor)
**Initial State:**
```
anchorWord = nil
selectedWord = 2:60:29
currentPage = 10
```

**User Action:** Swipe up

**Expected Behavior:**
```
anchorWord = nil
selectedWord = 2:60:20  (previous verse)
currentPage = 10 or 9 (depending on verse location)
```

**Visual:** Blue border moves to previous verse

**Requirement Source:** REQUIREMENTS line 58-68 (Normal navigation when no anchor or anchor not above)

---

### 2.2: Swipe down (no anchor)
**Initial State:**
```
anchorWord = nil
selectedWord = 2:60:29
currentPage = 10
```

**User Action:** Swipe down

**Expected Behavior:**
```
anchorWord = nil
selectedWord = 2:60:30  (next verse)
currentPage = 10 or 11 (depending on verse location)
```

**Visual:** Blue border moves to next verse

**Requirement Source:** REQUIREMENTS line 70-81 (Normal navigation when no anchor or anchor not below)

---

## Scenario 3: Navigation With Anchor (Anchor Above Current Position)

### 3.1: Swipe up when anchor is above
**Initial State:**
```
anchorWord = 2:60:20  (earlier verse)
anchorPage = 9
selectedWord = 2:60:35  (later verse)
currentPage = 10
Comparison: 2:60:20 < 2:60:35  (anchor is ABOVE)
```

**User Action:** Swipe up

**Expected Behavior:**
```
anchorWord = 2:60:20  (UNCHANGED - anchor persists)
anchorPage = 9
selectedWord = 2:60:20  (JUMPS to anchor)
currentPage = 9  (page with anchor)
```

**Visual:**
- Page 9 loads
- Word 2:60:20 shows BOTH red border (anchor) and blue border (selection)

**Requirement Source:** REQUIREMENTS line 58-68 (Up swipe with anchor above jumps to anchor)

---

### 3.2: Swipe down when anchor is above
**Initial State:**
```
anchorWord = 2:60:20  (earlier verse)
anchorPage = 9
selectedWord = 2:60:35  (later verse)
currentPage = 10
Comparison: 2:60:20 < 2:60:35  (anchor is ABOVE)
```

**User Action:** Swipe down

**Expected Behavior:**
```
anchorWord = 2:60:20  (UNCHANGED - anchor persists)
anchorPage = 9
selectedWord = 2:60:36  (next verse - NORMAL navigation)
currentPage = 10 or 11
```

**Visual:** Blue border moves to next verse (normal navigation)

**Requirement Source:** REQUIREMENTS line 70-81 (Down swipe does normal navigation when anchor is above, not below)

---

## Scenario 4: Navigation With Anchor (Anchor Below Current Position)

### 4.1: Swipe up when anchor is below
**Initial State:**
```
anchorWord = 2:60:40  (later verse)
anchorPage = 11
selectedWord = 2:60:20  (earlier verse)
currentPage = 9
Comparison: 2:60:40 > 2:60:20  (anchor is BELOW)
```

**User Action:** Swipe up

**Expected Behavior:**
```
anchorWord = 2:60:40  (UNCHANGED - anchor persists)
anchorPage = 11
selectedWord = 2:60:19  (previous verse - NORMAL navigation)
currentPage = 9 or 8
```

**Visual:** Blue border moves to previous verse (normal navigation)

**Requirement Source:** REQUIREMENTS line 58-68 (Up swipe does normal navigation when anchor is below, not above)

---

### 4.2: Swipe down when anchor is below
**Initial State:**
```
anchorWord = 2:60:40  (later verse)
anchorPage = 11
selectedWord = 2:60:20  (earlier verse)
currentPage = 9
Comparison: 2:60:40 > 2:60:20  (anchor is BELOW)
```

**User Action:** Swipe down

**Expected Behavior:**
```
anchorWord = 2:60:40  (UNCHANGED - anchor persists)
anchorPage = 11
selectedWord = 2:60:40  (JUMPS to anchor)
currentPage = 11  (page with anchor)
```

**Visual:**
- Page 11 loads
- Word 2:60:40 shows BOTH red border (anchor) and blue border (selection)

**Requirement Source:** REQUIREMENTS line 70-81 (Down swipe with anchor below jumps to anchor)

---

## Scenario 5: Navigation With Anchor (selectedWord = nil)

**Context:** selectedWord becomes nil when page turns FORWARD (not backward, since backward selects last aya marker). The behavior depends on where the anchor is relative to the current page.

### 5.1: Nil selector with anchor on CURRENT page
**Initial State:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = nil  (page just turned forward to page 10)
currentPage = 10
```

**User Action A:** Swipe down

**Expected Behavior:**
```
anchorWord = 2:60:29  (UNCHANGED - anchor persists)
anchorPage = 10
selectedWord = 2:60:29  (JUMPS to anchor)
currentPage = 10
```

**Visual:** Word 2:60:29 shows BOTH red and blue borders

**Rationale:** Anchor is on current page, swipe down (toward anchor) jumps to it

---

**User Action B:** Swipe up

**Expected Behavior:**
```
anchorWord = 2:60:29  (UNCHANGED - anchor persists)
anchorPage = 10
selectedWord = (first visible verse on page 10)  (NORMAL navigation)
currentPage = 10
```

**Visual:** Blue border appears on first verse, red border still on anchor

**Rationale:** Swipe up (away from anchor) does normal navigation

---

### 5.2: Nil selector with anchor on PREVIOUS page
**Initial State:**
```
anchorWord = 2:55:20
anchorPage = 9
selectedWord = nil  (page just turned forward to page 10)
currentPage = 10
```

**User Action A:** Swipe up

**Expected Behavior:**
```
anchorWord = 2:55:20  (UNCHANGED - anchor persists)
anchorPage = 9
selectedWord = 2:55:20  (JUMPS to anchor on previous page)
currentPage = 9
```

**Visual:**
- Page 9 loads
- Word 2:55:20 shows BOTH red and blue borders

**Rationale:** Anchor is on previous page (above), swipe up (toward anchor) jumps to it

---

**User Action B:** Swipe down

**Expected Behavior:**
```
anchorWord = 2:55:20  (UNCHANGED - anchor persists)
anchorPage = 9
selectedWord = (first visible verse on page 10)  (NORMAL navigation)
currentPage = 10
```

**Visual:** Blue border appears on first verse on page 10, anchor remains on page 9

**Rationale:** Swipe down (away from anchor) does normal navigation

---

**Key Insight:** Even with nil selector, directional logic still applies:
- Swipe TOWARD anchor → jump to anchor
- Swipe AWAY from anchor → normal navigation

---

## Scenario 6: Anchor At Same Position As Selection

### 6.1: Already at anchor position
**Initial State:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:29  (SAME as anchor)
currentPage = 10
```

**User Action:** Swipe up

**Expected Behavior:**
```
anchorWord = 2:60:29  (UNCHANGED)
anchorPage = 10
selectedWord = 2:60:28  (previous verse - NORMAL navigation)
currentPage = 10 or 9
```

**Visual:** Blue border moves away from anchor. Word 2:60:29 now shows ONLY red border.

**Rationale:** When already at anchor, swipes do normal navigation (not anchor jump)

**Requirement Source:** REQUIREMENTS line 58-68 (Up swipe jumps to anchor only if anchor < selected)

---

### 6.2: Already at anchor position (swipe down)
**Initial State:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:29  (SAME as anchor)
currentPage = 10
```

**User Action:** Swipe down

**Expected Behavior:**
```
anchorWord = 2:60:29  (UNCHANGED)
anchorPage = 10
selectedWord = 2:60:30  (next verse - NORMAL navigation)
currentPage = 10 or 11
```

**Visual:** Blue border moves away from anchor. Word 2:60:29 now shows ONLY red border.

**Rationale:** When already at anchor, swipes do normal navigation

**Requirement Source:** REQUIREMENTS line 70-81 (Down swipe jumps to anchor only if anchor > selected)

---

## Scenario 7: Anchor Scope (Auto-Removal)

### 7.1: Navigate out of scope (beyond 3 pages)
**Initial State:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:29
currentPage = 10
```

**User Action:** Page turn to page 14 (more than 3 pages away: |14-10| > 3)

**Expected Behavior:**
```
anchorWord = nil  (AUTO-REMOVED due to out of scope)
anchorPage = nil
selectedWord = (first verse on page 14)
currentPage = 14
```

**Visual:** No red border anywhere (anchor removed)

**Requirement Source:** REQUIREMENTS line 112-115 (Out of scope when 2+ pages away)

**NOTE:** Current code uses 3-page scope (commit f4827f1), requirements say +/-1 page. **WHICH IS CORRECT?**

---

### 7.2: Navigate within scope
**Initial State:**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:29
currentPage = 10
```

**User Action:** Page turn to page 12 (within 3 pages: |12-10| = 2 ≤ 3)

**Expected Behavior:**
```
anchorWord = 2:60:29  (UNCHANGED - still in scope)
anchorPage = 10
selectedWord = (first verse on page 12)
currentPage = 12
```

**Visual:**
- Page 10 not visible but anchor persists in memory
- Page 12 shows blue border on selected word
- If user navigates back to page 10, red border will be visible again

**Requirement Source:** REQUIREMENTS line 107-110 (In scope: current +/- 1 page) vs CODE (current +/- 3 pages)

---

## Scenario 8: Edge Cases

### 8.1: Rapid swipes
**Initial State:**
```
anchorWord = 2:60:20
anchorPage = 9
selectedWord = 2:60:40
currentPage = 11
```

**User Action:** Rapid swipe up → swipe down → swipe up (within 1 second)

**Expected Behavior:**
- First swipe up: Normal navigation (anchor is below) → selectedWord = 2:60:39
- Second swipe down: Anchor jump (anchor now below) → selectedWord = 2:60:20
- Third swipe up: Normal navigation (already at anchor) → selectedWord = 2:60:19

**Outcome:**
```
anchorWord = 2:60:20  (persists through rapid gestures)
selectedWord = 2:60:19
```

**Rationale:** Each gesture is evaluated independently using anchor position comparison

---

### 8.2: Anchor at page boundary (first verse of Quran)
**Initial State:**
```
anchorWord = 1:1:1  (Bismillah, first word)
anchorPage = 1
selectedWord = 2:1:1
currentPage = 50
```

**User Action:** Swipe up (anchor is above)

**Expected Behavior:**
```
anchorWord = 1:1:1  (UNCHANGED)
anchorPage = 1
selectedWord = 1:1:1  (jumps to first verse)
currentPage = 1
```

**Visual:** Page 1 loads, word 1:1:1 shows both borders

---

### 8.3: Anchor at page boundary (last verse of Quran)
**Initial State:**
```
anchorWord = 114:6:4  (last word)
anchorPage = 604
selectedWord = 2:1:1
currentPage = 50
```

**User Action:** Swipe down (anchor is below)

**Expected Behavior:**
```
anchorWord = 114:6:4  (UNCHANGED)
anchorPage = 604
selectedWord = 114:6:4  (jumps to last verse)
currentPage = 604
```

**Visual:** Page 604 loads, word 114:6:4 shows both borders

---

### 8.4: Mode switching (visible ↔ hidden)
**Initial State (hidden mode):**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = 2:60:35
currentPage = 10
pageHidden = true
```

**User Action:** Toggle to visible mode

**Expected Behavior:**
```
anchorWord = 2:60:29  (UNCHANGED - persists)
anchorPage = 10
selectedWord = 2:60:35  (UNCHANGED)
currentPage = 10
pageHidden = false
```

**Visual:** Anchor functionality not active in visible mode, but state persists in memory

**Requirement Source:** REQUIREMENTS line 125-133 (Anchor persists through mode switches)

---

## Scenario 9: What Currently Breaks

### 9.1: THE BUG - Visual indicator overlap
**Current State:**
```
anchorWord = 2:60:29
selectedWord = 2:60:29  (same word)
```

**Current Code (ContentView.swift:292-298):**
```swift
.overlay(RoundedRectangle().stroke(Color.blue, lineWidth: isSelected ? 2 : 0))
.overlay(RoundedRectangle().stroke(Color.red, lineWidth: isAnchor ? 2 : 0))
```

**Problem:** Red renders after blue, but BOTH have same cornerRadius and lineWidth, so visually only ONE color shows (likely blue due to rendering order).

**User Perception:** "Anchor disappeared" even though `anchorWord` is still set.

**Expected:** BOTH colors should be visible when both are true.

**Possible Fixes:**
- Different corner radius: Blue=4, Red=6 (both visible)
- Different line width: Blue=2, Red=3 (both visible)
- Conditional render: Show red if anchor, else show blue
- Composite indicator: Purple border when both (red + blue)

---

### 9.2: PREVIOUS BUG - Nil selector infinite loop
**Was Broken (before commit 02ef79a):**
```
anchorWord = 2:60:29
anchorPage = 10
selectedWord = nil
```

User swipe → jumpToAnchor() → selectedWord = 2:60:29 → navigate to page 11 → selectedWord = nil again → swipe → jumpToAnchor() → LOOP

**Fixed By:** Adding `fromNilSelector` parameter to clear anchor after nil selector jump.

**Problem With Fix:** Creates inconsistent behavior:
- Jump from nil selector → anchor cleared
- Jump from normal position → anchor persists

**Question:** Should anchor persist after jump in BOTH cases?

---

## Complete State Machine Summary

### State Transitions Table

| Current State | User Action | Next State | Notes |
|--------------|-------------|------------|-------|
| No anchor | Tap word A | Anchor=A, Selected=A | Creates anchor |
| Anchor=A, Selected=B | Tap word C | Anchor=C, Selected=C | Moves anchor |
| Anchor=A, Selected=B | Tap anchor A | Anchor=nil, Selected=A | Removes anchor |
| Anchor=A (above), Selected=B | Swipe up | Anchor=A, Selected=A | Jump to anchor |
| Anchor=A (below), Selected=B | Swipe down | Anchor=A, Selected=A | Jump to anchor |
| Anchor=A (below), Selected=B | Swipe up | Anchor=A, Selected=(B-1) | Normal nav |
| Anchor=A (above), Selected=B | Swipe down | Anchor=A, Selected=(B+1) | Normal nav |
| Anchor=A on current page, Selected=nil | Swipe down | Anchor=A, Selected=A | Jump to anchor |
| Anchor=A on current page, Selected=nil | Swipe up | Anchor=A, Selected=(first verse) | Normal nav |
| Anchor=A on previous page, Selected=nil | Swipe up | Anchor=A, Selected=A | Jump to anchor |
| Anchor=A on previous page, Selected=nil | Swipe down | Anchor=A, Selected=(first verse) | Normal nav |
| Anchor=A, Selected=A | Swipe up | Anchor=A, Selected=(A-1) | Normal nav |
| Anchor=A, Selected=A | Swipe down | Anchor=A, Selected=(A+1) | Normal nav |
| Anchor=A on page P, Selected=B | Navigate to page >P+3 | Anchor=nil, Selected=B | Out of scope |

---

## Open Questions That Need Answers

### Question 1: Scope Distance (RESOLVED)
**Correct:** +/- 1 page only (previous, current, next page)
**Current code:** Uses 3 pages - NEEDS FIX
**Location:** checkAndRemoveAnchorIfNeeded() in ContentView.swift

### Question 2: Nil Selector Behavior (RESOLVED)
**Correct behavior:** When selectedWord is nil (page just turned forward):
- If anchor on CURRENT page: Swipe down jumps to anchor, swipe up does normal nav
- If anchor on PREVIOUS page: Swipe up jumps to anchor, swipe down does normal nav
- Anchor always persists after jump (not cleared)
- Follows same directional logic as normal case

**Current code issue:** Commit 02ef79a clears anchor after nil selector jump, which is WRONG. Should persist.

### Question 3: Visual Indicator When Overlapping (RESOLVED)
**Correct:** When anchor and selection are same word, show ONLY red border
**Rationale:** Anchor is more important to show; user knows they're at the anchor
**Implementation:** Conditional rendering - if isAnchor, show red; else if isSelected, show blue
**Location:** ContentView.swift:292-298

### Question 4: Anchor Persistence After Jump (RESOLVED)
**Correct behavior:** Anchor always persists after jump (whether from nil selector or normal case)
- User can jump to anchor multiple times
- Anchor only removed by: tapping anchor, tapping different word, or going out of scope
- Consistent behavior in all scenarios

**Current code issue:** Commit 02ef79a clears anchor after nil selector jump, creating inconsistent behavior

---

## Recommendation: Answer Open Questions First

Before implementing any fix, we need clear answers to the 4 questions above. Once we have answers, the implementation becomes straightforward.

**APPROVED DECISIONS:**

1. **Scope:** +/- 1 page only (previous, current, next)
   - If anchor on page 10, in scope for pages 9, 10, 11
   - Navigate to page 8 or 12 → anchor removed
   - Current code uses 3 pages, needs to change to 1

2. **Visual:** When anchor and selection overlap, show ONLY red border
   - Red (anchor) takes priority over blue (selection)
   - User sees red = anchor is there

3. **Nil selector:** Follows directional logic (swipe toward anchor jumps, swipe away is normal)

4. **Persistence:** Anchor always persists after jump (can jump multiple times)
