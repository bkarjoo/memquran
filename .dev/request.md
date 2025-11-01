**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** issue-page-navigation-fixes

---

## Assignment: Complete Anchor System Fix (All Outstanding Issues)

After thorough analysis and user approval, we have identified all outstanding anchor system bugs. This is a **comprehensive fix** to address all issues in one cycle and break the fix-test-bug loop.

**CRITICAL: DO NOT FORGET THE REFERENCE DOCUMENTS**
These documents contain the complete approved specification. Read them before coding:

**Reference Documents:**
- **PRIMARY SPEC:** `.plan/COMPLETE_ANCHOR_BEHAVIOR_SPEC.md` (exhaustive specification, ALL scenarios documented)
- **Analysis:** `.plan/COMPREHENSIVE_ANALYSIS.md` (why we got stuck in fix-test cycle)
- **Quick Reference:** `.plan/ANCHOR_DOCS_INDEX.md` (index of all anchor documentation)

---

## Three Fixes Required

### Fix #1: Visual Indicator Priority (UI Bug)

**Problem:**
When anchor and selection point to same word, both red and blue borders render but only one is visible. User thinks anchor disappeared.

**Current Code (ContentView.swift:292-298):**
```swift
.overlay(
    RoundedRectangle(cornerRadius: 4)
        .stroke(Color.blue, lineWidth: isSelected ? 2 : 0)
)
.overlay(
    RoundedRectangle(cornerRadius: 4)
        .stroke(Color.red, lineWidth: isAnchor ? 2 : 0)
)
```

**Required Fix:**
Show ONLY red border when both anchor and selection are at same word. Red (anchor) takes priority.

```swift
.overlay(
    RoundedRectangle(cornerRadius: 4)
        .stroke(isAnchor ? Color.red : (isSelected ? Color.blue : Color.clear),
                lineWidth: (isAnchor || isSelected) ? 2 : 0)
)
```

**Location:** ContentView.swift:292-298

---

### Fix #2: Anchor Scope Distance (Logic Bug)

**Problem:**
Current code keeps anchor in scope for +/- 3 pages. User wants +/- 1 page only (previous, current, next).

**Current Code (ContentView.swift:1420-1424 approx):**
```swift
func checkAndRemoveAnchorIfNeeded() {
    guard let anchor = anchorWord, let aPage = anchorPage else { return }

    let distance = abs(currentPage - aPage)
    if distance > 3 {  // <-- WRONG: should be 1
        anchorWord = nil
        anchorPage = nil
    }
}
```

**Required Fix:**
Change threshold from 3 to 1.

```swift
func checkAndRemoveAnchorIfNeeded() {
    guard let anchor = anchorWord, let aPage = anchorPage else { return }

    let distance = abs(currentPage - aPage)
    if distance > 1 {  // Changed from 3 to 1
        print("🗑️ Removing anchor - out of scope (distance: \(distance))")
        anchorWord = nil
        anchorPage = nil
    }
}
```

**Location:** Find checkAndRemoveAnchorIfNeeded() function in ContentView.swift

---

### Fix #3: Remove Nil Selector Special Case (Consistency Bug)

**Problem:**
Current code clears anchor after jumping from nil selector scenario (commit 02ef79a). This creates inconsistent behavior:
- Jump with selection → anchor persists
- Jump from nil selector → anchor cleared

User wants consistent behavior: **anchor always persists after jump**.

**Current Code (ContentView.swift:1393-1397 and 1406-1410):**
```swift
if fromNilSelector {
    print("🔴 Clearing anchor after nil selector jump to prevent infinite loop")
    self.writeLog("🔴 Clearing anchor after nil selector jump to prevent infinite loop")
    self.anchorWord = nil
    self.anchorPage = nil
} else {
    // Clear anchor if user has navigated to it
    self.checkAndRemoveAnchorIfNeeded()
}
```

**Required Fix:**
Remove the entire `fromNilSelector` conditional. Always use `checkAndRemoveAnchorIfNeeded()`.

**Two locations to fix:**

**Location 1 (ContentView.swift ~line 1393-1401):**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    self.selectedWord = anchor
    // Always use scope check, never clear anchor just because of nil selector
    self.checkAndRemoveAnchorIfNeeded()
}
```

**Location 2 (ContentView.swift ~line 1404-1413):**
```swift
selectedWord = anchor
// Always use scope check, never clear anchor just because of nil selector
checkAndRemoveAnchorIfNeeded()
```

**Also remove the `fromNilSelector` parameter from function signature:**

**Location 3 (ContentView.swift ~line 1371):**
```swift
// BEFORE:
func jumpToAnchor(to anchor: WordIdentifier? = nil, onPage targetPage: Int? = nil, fromNilSelector: Bool = false)

// AFTER:
func jumpToAnchor(to anchor: WordIdentifier? = nil, onPage targetPage: Int? = nil)
```

**Location 4 - Remove parameter from call sites:**
Find all calls to `jumpToAnchor()` and remove the `fromNilSelector: true` parameter.
Likely in swipe gesture handlers (search for "jumpToAnchor").

---

## Expected Behavior After Fixes

### Scenario: Anchor and Selection Overlap
- **Before:** Blue border shows, user thinks anchor gone
- **After:** Red border shows, user knows anchor is there

### Scenario: Navigate 2 Pages Away
- **Before:** Anchor persists (scope = 3)
- **After:** Anchor removed (scope = 1)

### Scenario: Jump to Anchor from Nil Selector
- **Before:** Anchor cleared after jump
- **After:** Anchor persists, user can jump multiple times

---

## Testing Checklist

After implementing all three fixes, verify:

**Visual Tests:**
- [ ] Set anchor at word 2:60:29
- [ ] Navigate to that word (selection = anchor)
- [ ] Verify ONLY red border shows (not blue)

**Scope Tests:**
- [ ] Set anchor on page 10
- [ ] Navigate to page 11 → anchor should persist
- [ ] Navigate to page 12 → anchor should be REMOVED
- [ ] Navigate to page 9 → anchor should persist
- [ ] Navigate to page 8 → anchor should be REMOVED

**Nil Selector Tests:**
- [ ] Set anchor on page 10
- [ ] Turn page forward to page 11 (selectedWord becomes nil)
- [ ] Swipe up → should jump to anchor on page 10
- [ ] Verify anchor still exists (RED border visible)
- [ ] Turn page forward to 12
- [ ] Swipe up → should do NORMAL navigation (anchor still on page 10)
- [ ] Verify anchor still persists until page 13 (then removed)

**Regression Tests:**
- [ ] Normal anchor jumping (with selection) still works
- [ ] Directional swipes (up/down with anchor above/below) still work
- [ ] Tap to set anchor still works
- [ ] Tap anchor to remove still works
- [ ] No infinite loops
- [ ] No crashes

---

## Build and Commit

1. Implement all three fixes
2. Build the app - ensure no compilation errors
3. Test locally using the checklist above
4. Commit with message:
   ```
   Fix anchor system: visual priority, scope distance, and persistence

   - Show only red border when anchor and selection overlap
   - Change scope from +/- 3 pages to +/- 1 page
   - Remove nil selector special case - anchor always persists after jump
   - Ensures consistent behavior across all scenarios
   ```

---

## Files to Modify

- `MemQuran/ContentView.swift` (all three fixes are in this file)

---

## Success Criteria

- ✅ Red border visible when at anchor position
- ✅ Anchor removed when >1 page away
- ✅ Anchor persists after all jump types
- ✅ All test scenarios pass
- ✅ No regressions

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
