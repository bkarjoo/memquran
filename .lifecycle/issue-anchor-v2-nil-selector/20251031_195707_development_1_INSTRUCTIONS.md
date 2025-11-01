# Development Team - Phase 1: Anchor Point Core Implementation

## Team Assignment
**Development Team**

## Phase/Version
**Phase 1** - Core anchor point functionality

## Context
The code review team has completed their analysis of the codebase architecture (see `.plan/responses/code_review_1_RESPONSE.md`). We now understand:
- Selection system uses `WordIdentifier` struct and `selectedWord` state variable
- Blue rounded corner square drawn via RoundedRectangle overlay
- Up swipe currently calls `previousVerse()` at line 555 in ContentView.swift
- Hidden mode visibility controlled by `isWordVisible()` function
- Navigation patterns exist in `jumpToBookmark()` that we can follow

## Dependencies
- Code review Phase 1 complete ✓

## Objectives
Implement the core anchor point navigation feature for hidden mode:
1. Add anchor point state management
2. Add visual indicator for anchor point (red rounded corner square)
3. Implement anchor point selection via word tap
4. Modify up swipe to jump to anchor point when it exists
5. Handle anchor point removal logic

## Deliverables

### 1. Add Anchor Point State Variables
**File:** `MemQuran/ContentView.swift`
**Location:** Around line 390 (near `selectedWord` state)

Add these state variables:
```swift
@State private var anchorWord: WordIdentifier? = nil
@State private var anchorPage: Int? = nil
```

### 2. Add Visual Indicator for Anchor Point
**File:** `MemQuran/ContentView.swift`
**Location:** Around lines 276-279 (in JustifiedLineView where selection overlay is)

Modify the overlay to show red square for anchor point:
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

Add logic to determine `isAnchor`:
```swift
let isAnchor = anchorWord == wordId
```

### 3. Modify Word Tap Handler for Anchor Point Selection
**File:** `MemQuran/ContentView.swift`
**Location:** Lines 958-968 (`handleWordTap` function)

Add anchor point logic:
- Only works in hidden mode (`isTextHidden == true`)
- Clicking on any visible word (except last visible word) sets it as anchor
- Clicking on last visible word removes anchor (if exists) or does nothing
- Clicking on anchor point itself removes it

**Requirements:**
- Check if tapped word is the last visible word
- Check if tapped word is the current anchor
- Set/remove anchor accordingly

### 4. Implement Up Swipe Navigation to Anchor
**File:** `MemQuran/ContentView.swift`
**Location:** Lines 553-556 (up swipe handler in DragGesture.onEnded)

Modify up swipe logic:
```swift
if value.translation.height < 0 {
    // Swipe up
    if anchorWord != nil {
        writeLog("⬆️ Swipe up -> jump to anchor")
        jumpToAnchor()
    } else {
        writeLog("⬆️ Swipe up -> previous verse")
        previousVerse()
    }
}
```

### 5. Implement `jumpToAnchor()` Function
**File:** `MemQuran/ContentView.swift`
**Location:** Add after `jumpToBookmark()` function (around line 1240)

Create function following the pattern of `jumpToBookmark()`:
```swift
func jumpToAnchor() {
    guard let anchor = anchorWord, let targetPage = anchorPage else {
        return
    }

    // Handle cross-page navigation
    if targetPage != currentPage {
        isAutoNavigating = true
        currentPage = targetPage

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.selectedWord = anchor
            // Clear anchor if user has navigated to it
            self.checkAndRemoveAnchorIfNeeded()
        }
    } else {
        selectedWord = anchor
        checkAndRemoveAnchorIfNeeded()
    }
}
```

### 6. Implement Anchor Removal Logic
**File:** `MemQuran/ContentView.swift`
**Location:** Add helper functions near `jumpToAnchor()`

Create function to check if anchor should be removed:
```swift
func checkAndRemoveAnchorIfNeeded() {
    guard let anchor = anchorWord, let aPage = anchorPage else { return }

    // Remove anchor if:
    // 1. User has reached the anchor point and swipes up again
    // 2. User swipes right beyond the anchor (anchor becomes visible before nav)
    // 3. Anchor is no longer on current or previous page

    let previousPageNum: Int
    if shouldShowTwoPages {
        previousPageNum = currentPage - 2
    } else {
        previousPageNum = currentPage - 1
    }

    // Check if anchor is out of scope (not on current or previous page)
    if aPage != currentPage && aPage != previousPageNum && aPage != actualDisplayedPage && aPage != (actualDisplayedPage - 1) {
        writeLog("🔴 Anchor out of scope - removing")
        anchorWord = nil
        anchorPage = nil
    }
}
```

Call this function:
- In `loadPage()` after page changes
- After navigation functions complete

### 7. Implement Automatic Anchor Setting on Up Swipe
**File:** `MemQuran/ContentView.swift`
**Location:** In up swipe handler (line ~555)

Before navigating, set last visible word as anchor:
```swift
if value.translation.height < 0 {
    // Swipe up
    if isTextHidden && anchorWord == nil {
        // Set current selection as anchor before navigating
        if let selected = selectedWord {
            anchorWord = selected
            anchorPage = currentPage
            writeLog("📍 Set anchor: \(selected.surah):\(selected.ayah):\(selected.position)")
        }
    }

    if anchorWord != nil {
        jumpToAnchor()
    } else {
        previousVerse()
    }
}
```

## Success Criteria
- [ ] Anchor state variables added to ContentView
- [ ] Red rounded corner square appears on anchor point
- [ ] Blue rounded corner square still appears on selection
- [ ] Tapping visible word (not last visible) sets anchor
- [ ] Tapping last visible word removes anchor
- [ ] Tapping anchor point itself removes anchor
- [ ] Up swipe jumps to anchor when anchor exists
- [ ] Up swipe calls previousVerse() when no anchor exists
- [ ] On up swipe, last visible word automatically becomes anchor
- [ ] Anchor removed when out of scope (not on current/previous page)
- [ ] Anchor works in hidden mode only
- [ ] Anchor persists when switching between visible/hidden mode

## Testing Instructions
Manual testing scenarios:
1. Enter hidden mode, select a word, verify red square appears
2. Swipe up, verify last visible word becomes anchor (red square)
3. Swipe up again, verify navigation to anchor point
4. Swipe up at anchor, verify anchor is removed
5. Navigate to next page, verify anchor removed (out of scope)
6. Switch to visible mode and back, verify anchor persists
7. Test in 2-page mode

## Response File Request
Document your work in:
**File:** `.plan/responses/development_1_RESPONSE.md`

Include:
- Summary of implementation
- Code changes made (file paths and line numbers)
- Any deviations from instructions (with reasons)
- Issues encountered and solutions
- Testing results
- Known limitations or edge cases
- Recommendations for next phase
- **Status:** [Complete/Blocked/In Progress]

## GIT WORKFLOW

When you complete this phase:

1. **Commit your code changes:**
   ```bash
   git add MemQuran/ContentView.swift
   git commit -m "Implement Phase 1: Anchor point navigation core functionality

   - Add anchor state variables (anchorWord, anchorPage)
   - Add red visual indicator for anchor point
   - Implement anchor selection via word tap in hidden mode
   - Modify up swipe to jump to anchor when exists
   - Implement jumpToAnchor() function
   - Add anchor removal logic for out-of-scope detection
   - Auto-set last visible word as anchor on up swipe

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

2. **Commit your response file:**
   ```bash
   git add .plan/responses/development_1_RESPONSE.md
   git commit -m "Complete Phase 1 development response"
   ```

3. **Do NOT push yet** - Wait for test team and code review approval

This ensures all work is version-controlled and traceable.
