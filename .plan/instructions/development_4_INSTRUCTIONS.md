# Development Team - Phase 4: Implement Simplified Anchor Requirements V2

## Team Assignment
**Development Team**

## Phase/Version
**Phase 4** - Implement simplified anchor requirements

## Context
Requirements simplified. Read: `.plan/REQUIREMENTS_V2_ANCHOR_SIMPLIFIED.md`

## Changes Required

### 1. Remove Automatic Anchor Creation
**File:** `ContentView.swift` lines ~566-577

**Delete this entire block:**
```swift
if anchorWord == nil {
    if let selected = selectedWord {
        anchorWord = selected
        anchorPage = currentPage
        writeLog("📍 Set anchor: ...")
    }
    writeLog("⬆️ Swipe up -> previous verse (anchor set for later return)")
    previousVerse()
} else {
```

### 2. Implement Directional Swipe Logic
**File:** `ContentView.swift` lines ~566-591

**Replace up swipe logic with:**
```swift
if value.translation.height < 0 {
    // Up swipe
    if let anchor = anchorWord, anchor < selectedWord {
        // Anchor is above - jump to it
        writeLog("⬆️ Swipe up -> jump to anchor (above)")
        jumpToAnchor()
    } else {
        // No anchor or anchor below - normal navigation
        writeLog("⬆️ Swipe up -> previous verse")
        previousVerse()
    }
}
```

**Replace down swipe logic with:**
```swift
if value.translation.height > 0 {
    // Down swipe
    if let anchor = anchorWord, anchor > selectedWord {
        // Anchor is below - jump to it
        writeLog("⬇️ Swipe down -> jump to anchor (below)")
        jumpToAnchor()
    } else {
        // No anchor or anchor above - normal navigation
        writeLog("⬇️ Swipe down -> next verse")
        nextVerse()
    }
}
```

### 3. Enable Last Visible Word as Anchor
**File:** `ContentView.swift` lines ~990-1033

**In `handleWordTap()`, remove the check that prevents last visible word:**

**Change from:**
```swift
// Check if this is the last visible word (currently selected word)
if selectedWord == wordId {
    // Tapping last visible word removes anchor if it exists
    if anchorWord != nil {
        writeLog("🔴 Removed anchor (tapped last visible)")
        anchorWord = nil
        anchorPage = nil
    } else {
        // No anchor exists, toggle selection off
        selectedWord = nil
    }
    return
}
```

**To:**
```swift
// Tapping any word sets it as anchor (or toggles selection in visible mode)
if !isTextHidden {
    // Normal mode behavior
    if selectedWord == wordId {
        selectedWord = nil
    } else {
        selectedWord = wordId
        unhideWord(wordId)
    }
    return
}
```

**Then in hidden mode section:**
```swift
if isTextHidden {
    // Tapping anchor removes it
    if anchorWord == wordId {
        writeLog("🔴 Removed anchor (tapped anchor)")
        anchorWord = nil
        anchorPage = nil
        return
    }

    // Tapping any other word sets/moves anchor
    if isWordVisible(wordId: wordId, pageHidden: isTextHidden, selectedWord: selectedWord) {
        anchorWord = wordId
        anchorPage = currentPage
        writeLog("📍 Set anchor: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
        return
    }
}
```

### 4. Update Scope Logic
**File:** `ContentView.swift` lines ~1329-1350

**In `checkAndRemoveAnchorIfNeeded()`, change to:**
```swift
func checkAndRemoveAnchorIfNeeded() {
    guard let anchor = anchorWord, let aPage = anchorPage else { return }

    // Scope: current page +/- 1
    let inScope = abs(currentPage - aPage) <= 1

    // In 2-page mode, also check actualDisplayedPage
    let inScope2Page = shouldShowTwoPages ? abs(actualDisplayedPage - aPage) <= 1 : true

    if !inScope || !inScope2Page {
        writeLog("🔴 Anchor out of scope - removing")
        anchorWord = nil
        anchorPage = nil
    }
}
```

### 5. Implement WordIdentifier Comparison
**File:** `ContentView.swift` after WordIdentifier struct

**Add Comparable conformance:**
```swift
extension WordIdentifier: Comparable {
    static func < (lhs: WordIdentifier, rhs: WordIdentifier) -> Bool {
        if lhs.surah != rhs.surah {
            return lhs.surah < rhs.surah
        }
        if lhs.ayah != rhs.ayah {
            return lhs.ayah < rhs.ayah
        }
        return lhs.position < rhs.position
    }
}
```

## Testing Checklist
- [ ] Up swipe jumps to anchor when anchor is above
- [ ] Up swipe goes to previous verse when anchor is below or no anchor
- [ ] Down swipe jumps to anchor when anchor is below
- [ ] Down swipe goes to next verse when anchor is above or no anchor
- [ ] Can tap last visible word to set anchor
- [ ] Tapping anchor removes it
- [ ] Tapping other word moves anchor
- [ ] Scope is current page +/- 1
- [ ] No automatic anchor creation

## Response File
`.plan/responses/development_4_RESPONSE.md`

Include:
- Code changes made
- Build results
- Testing results
- Status: Complete/Blocked/In Progress

## Git Workflow
```bash
git add MemQuran/ContentView.swift
git commit -m "Implement simplified anchor requirements V2

- Remove automatic anchor creation on up swipe
- Add directional swipe logic (up/down check anchor direction)
- Allow last visible word as anchor
- Update scope to current page +/- 1
- Add WordIdentifier Comparable conformance

Co-Authored-By: Claude <noreply@anthropic.com>"
```
