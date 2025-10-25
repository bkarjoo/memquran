# Visibility System Audit

## Goal
Remove per-word `isHidden` property and calculate visibility based on:
1. Page-level hidden state (from navigation)
2. Selected word position (everything before = visible, after = hidden)

---

## Model Definition

### Models.swift
- **Line 19**: `var isHidden: Bool` - Property definition in WordData model
- **Line 36**: `self.isHidden = false` - Default value in initializer
- **Action**: Remove property from model (requires migration)

---

## WordDataCache.swift

### toggleAllWordsHidden() function
- **Line 150-160**: `func toggleAllWordsHidden(on page: Int, hidden: Bool)` - Sets isHidden for all words on a page
- **Line 155**: `wordData.isHidden = hidden` - The actual assignment
- **Action**: DELETE entire function - no longer needed

---

## ContentView.swift - READS (Visibility Checks)

### Display/Rendering
- **Line 267**: `let isHidden = wordData?.isHidden ?? pageHidden` - Main visibility check in JustifiedLineView
- **Line 270**: `.opacity(isHidden ? 0 : 1)` - Uses computed isHidden
- **Line 271**: `.allowsHitTesting(!isHidden)` - Uses computed isHidden
- **Action**: Replace with new `isWordVisible()` function

### unhideWord() function
- **Line 978-981**: Checks if word is hidden, then unhides it
  ```swift
  if wordData.isHidden {
      wordData.isHidden = false
  ```
- **Action**: REMOVE - word visibility will be calculated, not stored

### nextWord() function
- **Line 1212-1215**: Unhides word when moving forward
  ```swift
  if wordData.isHidden {
      wordData.isHidden = false
  ```
- **Action**: REMOVE - visibility calculated from selection

- **Line 1218-1221**: Hides word when at start of verse (check before hiding)
  ```swift
  if !wordData.isHidden {
      wordData.isHidden = true
  ```
- **Action**: REMOVE - no need to hide/unhide

### previousWord() function
- **Line 1373-1378**: Hides current word when going backwards in hidden mode
  ```swift
  if !wordData.isHidden {
      wordData.isHidden = true
  ```
- **Action**: REMOVE - selection position determines visibility

- **Line 1394-1399**: Hides current word at first position
  ```swift
  if !wordData.isHidden {
      wordData.isHidden = true
  ```
- **Action**: REMOVE

### previousVerse() function
- **Line 1617-1622**: Hides words in current verse when at start of page
  ```swift
  if !wordData.isHidden {
      wordData.isHidden = true
  ```
- **Action**: REMOVE

### unhideWordsBetween() function
- **Line 1763-1766**: Unhides words between positions
  ```swift
  if wordData.isHidden {
      wordData.isHidden = false
  ```
- **Action**: DELETE entire function - no longer needed

### hideWordsBetween() function
- **Line 1806-1809**: Hides words between positions
  ```swift
  if !wordData.isHidden {
      wordData.isHidden = true
  ```
- **Action**: DELETE entire function - no longer needed

---

## ContentView.swift - WRITES (Mass Operations)

### loadPage() function
- **Line 946**: `wordDataCache.toggleAllWordsHidden(on: actualPage, hidden: applyHidden)` - 2-page mode, odd page
- **Line 947**: `wordDataCache.toggleAllWordsHidden(on: evenPage, hidden: applyHidden)` - 2-page mode, even page
- **Line 953**: `wordDataCache.toggleAllWordsHidden(on: actualPage, hidden: applyHidden)` - Single page mode
- **Action**: DELETE all three calls - page-level state handles this

### nextVerse() function (old backward navigation code)
- **Line 1838**: `self.wordDataCache.toggleAllWordsHidden(on: oddPage, hidden: false)` - Unhide odd page
- **Line 1840**: `self.wordDataCache.toggleAllWordsHidden(on: evenPage, hidden: false)` - Unhide even page
- **Line 1844**: `self.wordDataCache.toggleAllWordsHidden(on: self.currentPage, hidden: false)` - Unhide current page
- **Action**: DELETE - obsolete backward navigation code (replaced by loadNextPageVisible flag)

### toggleAllWordsHidden() function
- **Line 1935-1951**: `func toggleAllWordsHidden(hidden: Bool)` - Called when isTextHidden changes
- **Line 1942**: `wordDataCache.toggleAllWordsHidden(on: oddPage, hidden: hidden)` - 2-page mode, odd
- **Line 1944**: `wordDataCache.toggleAllWordsHidden(on: evenPage, hidden: hidden)` - 2-page mode, even
- **Line 1949**: `wordDataCache.toggleAllWordsHidden(on: currentPage, hidden: hidden)` - Single page
- **Action**: DELETE entire function - onChange handler can just update page-level state instead

### .onChange(of: isTextHidden) handler
- **Line 777**: `toggleAllWordsHidden(hidden: newValue)` - Called when mode changes
- **Action**: REPLACE with updating currentPageHidden and leftPageHidden state variables

---

## ContentView_OLD.swift

### Old implementation (for reference only)
- **Line 57**: Old visibility check
- **Line 152**: Old onChange handler
- **Line 396-411**: Old toggleAllWordsHidden implementation
- **Action**: NO ACTION - this is old code, ignore

---

## Implementation Plan

### Step 1: Add new visibility calculation function
```swift
func isWordVisible(wordId: WordIdentifier, pageHidden: Bool, selectedWord: WordIdentifier?) -> Bool {
    // If not in hidden mode, everything is visible
    if !pageHidden {
        return true
    }

    // If no selection, everything is hidden
    guard let selected = selectedWord else {
        return false
    }

    // Word is visible if it comes before or at the selected word
    // Compare: surah, then ayah, then position
    if wordId.surah < selected.surah {
        return true
    } else if wordId.surah == selected.surah {
        if wordId.ayah < selected.ayah {
            return true
        } else if wordId.ayah == selected.ayah {
            return wordId.position <= selected.position
        }
    }

    return false
}
```

### Step 2: Update visibility check in JustifiedLineView
Replace line 267 with call to new function

### Step 3: Remove all WRITE operations
Delete all code that sets isHidden

### Step 4: Remove helper functions
Delete unhideWord(), unhideWordsBetween(), hideWordsBetween(), toggleAllWordsHidden()

### Step 5: Update .onChange(of: isTextHidden)
Replace toggleAllWordsHidden call with state variable updates

### Step 6: Remove WordDataCache.toggleAllWordsHidden()
Delete the function from WordDataCache.swift

### Step 7: Remove isHidden from Model
Delete property from Models.swift (requires data migration discussion)

---

## Files to Modify
1. ContentView.swift (main changes)
2. WordDataCache.swift (remove toggleAllWordsHidden)
3. Models.swift (remove isHidden property - later)
