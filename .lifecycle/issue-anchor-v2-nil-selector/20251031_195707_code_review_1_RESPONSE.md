# Code Review Team - Phase 1: Codebase Architecture Analysis Response

## Status: Complete

## 1. Selection System (Blue Rounded Corner Square)

### Drawing the Selection Indicator
**File:** `MemQuran/ContentView.swift`
**Lines:** 276-279

```swift
.overlay(
    RoundedRectangle(cornerRadius: 4)
        .stroke(Color.blue, lineWidth: isSelected ? 2 : 0)
)
```

The blue rounded corner square is rendered as an overlay on each word in the `JustifiedLineView`. The selection is determined by comparing the word's identifier with the current `selectedWord`.

### State Variable Tracking Selection
**File:** `MemQuran/ContentView.swift`
**Line:** 390

```swift
@State private var selectedWord: WordIdentifier?
```

This is the main state variable in `ContentView` that tracks the currently selected word. It's an optional type, meaning it can be `nil` when no word is selected.

### Data Structure for Word Position
**File:** `MemQuran/ContentView.swift`
**Lines:** 59-67

```swift
struct WordIdentifier: Equatable, Hashable, Identifiable {
    let surah: Int
    let ayah: Int
    let position: Int

    var id: String {
        "\(surah):\(ayah):\(position)"
    }
}
```

The `WordIdentifier` struct represents a selected word position with three components:
- `surah`: The surah (chapter) number
- `ayah`: The ayah (verse) number within the surah
- `position`: The word position within the ayah

**Additional Context:** When rendering, this is compared against `QuranWord` instances to determine visibility:
**Lines:** 266-268
```swift
let wordId = WordIdentifier(surah: quranWord.surah, ayah: quranWord.ayah, position: quranWord.word)
let isSelected = selectedWord == wordId
```

## 2. Swipe Gesture Handling

### Gesture Detection Setup
**File:** `MemQuran/ContentView.swift`
**Lines:** 529-586

The app uses SwiftUI's `DragGesture` with a minimum distance of 20 points, attached via `highPriorityGesture()` to ensure gestures take priority over other interactions.

```swift
.highPriorityGesture(
    DragGesture(minimumDistance: 20)
        .onEnded { value in
            let horizontalAmount = abs(value.translation.width)
            let verticalAmount = abs(value.translation.height)
```

### Mode-Specific Navigation Logic

#### Normal Mode (isTextHidden = false)
**Lines:** 564-583
- Only horizontal swipes are processed
- Vertical swipes are ignored
- **Swipe left** (negative width) → `previousPage()`
- **Swipe right** (positive width) → `nextPage()`

#### Hidden Mode (isTextHidden = true)
**Lines:** 538-562
- Both horizontal and vertical swipes are processed
- **Horizontal swipes:**
  - **Swipe left** → `nextWord()` (single blue chevron)
  - **Swipe right** → `previousWord()` (single blue chevron)
- **Vertical swipes:**
  - **Swipe up** → `previousVerse()` (double green chevron)
  - **Swipe down** → `nextVerse()` (double green chevron)

### Navigation Functions

#### previousVerse()
**Lines:** 1550-1621
- Finds the previous verse's ayah marker (last word of previous verse)
- Uses helper function `findPreviousVerseMarker()` (lines 1426-1459)
- If at start of page in hidden mode, clears selection
- If not in hidden mode, navigates to previous page

#### Current Up Swipe Behavior
Currently, up swipe goes to the **previous** verse (moving backwards in the Quran), not to an anchor point.

## 3. Hidden Mode Logic

### Visibility Determination Function
**File:** `MemQuran/ContentView.swift`
**Lines:** 1462-1486

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

### Visibility Control
**Lines:** 270-274 (in JustifiedLineView)**
```swift
let wordIsVisible = isWordVisible(wordId, pageHidden, selectedWord)
Text(quranWord.text)
    .font(getFont(fontName: fontFamily, size: baseFontSize))
    .opacity(wordIsVisible ? 1 : 0)
    .allowsHitTesting(wordIsVisible)  // Pass through touches when hidden
```

### Hidden State Variable
**File:** `MemQuran/ContentView.swift`
**Line:** 401
```swift
@Binding var isTextHidden: Bool
```

This is passed down from the parent view and controls the page-level hidden state.

### "Last Visible Word" Calculation
The "last visible word" is simply the currently `selectedWord`. All words up to and including the selected word are visible. The visibility is calculated dynamically using the `isWordVisible()` function, which compares word positions (surah, ayah, position) to determine if a word should be shown.

**Key insight:** There is no stored "last visible word" state - visibility is purely calculated from the `selectedWord` position.

## 4. Word Tap Handling

### Tap Handler Setup
**File:** `MemQuran/ContentView.swift`
**Lines:** 281-283 (in JustifiedLineView)

```swift
.onTapGesture {
    onWordTap(wordId)
}
```

### Main Tap Handler Logic
**Lines:** 958-968 (handleWordTap function)

```swift
func handleWordTap(_ wordId: WordIdentifier) {
    // Toggle selection: if already selected, deselect; otherwise select
    if selectedWord == wordId {
        selectedWord = nil
    } else {
        selectedWord = wordId
        // Unhide the word when selected
        unhideWord(wordId)
    }
    writeLog("🔘 Word tapped: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
}
```

### Behavior in Hidden Mode
When a word is tapped:
1. The word becomes selected (blue outline appears)
2. `unhideWord()` is called (lines 970-991), which:
   - Creates or fetches `WordData` for the word
   - Records a `WordInteraction` timestamp
   - Saves to the database
3. All words up to and including the selected word become visible (via `isWordVisible()` calculation)

### Context Menu
**Lines:** 284-296
Right-clicking (or long-press) on a word shows a context menu with:
- "Mark Mistake" → `onMarkMistake(wordId)`
- "Add Bookmark" → `onAddBookmark(wordId)`

## 5. Data Models

### Primary Word Position Structures

#### WordIdentifier (UI/Selection)
**File:** `MemQuran/ContentView.swift`
**Lines:** 59-67
```swift
struct WordIdentifier: Equatable, Hashable, Identifiable {
    let surah: Int
    let ayah: Int
    let position: Int

    var id: String {
        "\(surah):\(ayah):\(position)"
    }
}
```
Used for: Selection tracking, navigation, UI state

#### QuranWord (Content)
**File:** `MemQuran/MushafModels.swift`
**Lines:** 23-39
```swift
public struct QuranWord {
    public let id: Int
    public let location: String  // "surah:ayah:word"
    public let surah: Int
    public let ayah: Int
    public let word: Int
    public let text: String
}
```
Used for: Storing the actual Arabic text and database ID

#### WordData (Persistence/Analytics)
**File:** `MemQuran/Models.swift`
**Lines:** 7-42
```swift
@Model
final class WordData {
    var surahNumber: Int = 0
    var ayahNumber: Int = 0
    var wordPosition: Int = 0

    // Layout properties
    var lineNumber: Int = 0
    var positionInLine: Int = 0

    // Single values
    var isBookmarked: Bool = false
    var isDemarcationPoint: Bool = false

    // Relationships (one-to-many)
    @Relationship(deleteRule: .cascade) var notes: [WordNote]?
    @Relationship(deleteRule: .cascade) var links: [WordLink]?
    @Relationship(deleteRule: .cascade) var mistakes: [WordMistake]?
    @Relationship(deleteRule: .cascade) var interactions: [WordInteraction]?
    @Relationship(deleteRule: .cascade) var bookmarks: [WordBookmark]?
}
```
Used for: Tracking mistakes, interactions, bookmarks, and notes

### Ayah Markers
**Important:** Ayah markers are NOT a separate data structure. They are simply the **last word** of each verse. The code identifies ayah markers by finding the last `WordIdentifier` with a specific `surah:ayah` combination.

**Example from findPreviousVerseMarker():**
**Lines:** 1442-1452
```swift
if isDifferentVerse {
    // Found a word from previous verse
    // Now find the last word of that verse (the ayah marker)
    previousVerseMarker = word

    // Continue forward while staying in the same verse to find the marker
    for nextIndex in (index + 1)..<currentIndex {
        let nextWord = allWords[nextIndex]
        if nextWord.surah == word.surah && nextWord.ayah == word.ayah {
            previousVerseMarker = nextWord
        }
    }
}
```

### Line Metadata
**File:** `MemQuran/MushafModels.swift`
**Lines:** 3-21
```swift
public struct MushafLine {
    public let pageNumber: Int
    public let lineNumber: Int
    public let lineType: String  // "ayah", "surah_name", "basmallah"
    public let isCentered: Bool
    public let firstWordId: Int?
    public let lastWordId: Int?
    public let surahNumber: Int?
}
```

## 6. Page Tracking

### State Variables
**File:** `MemQuran/ContentView.swift`

#### Current Page (User Setting)
**Line:** 385
```swift
@AppStorage("currentPage") private var currentPage: Int = 2  // Start at page 2 (Al-Baqarah)
```
This persists across app launches and represents the user's current position.

#### Actual Displayed Page (View State)
**Line:** 388
```swift
@State private var actualDisplayedPage: Int = 1  // The actual page number being displayed (odd in 2-page mode)
```
In 2-page mode, this ensures we always display odd-numbered pages on the right side.

#### Two-Page Mode Data
**Lines:** 399-400
```swift
@State private var linesLeft: [MushafLine] = []  // For even page (left side)
@State private var lineWordsLeft: [Int: [QuranWord]] = [:]  // For even page (left side)
```
Stores the content for the even (left) page when in 2-page mode.

### Page Management Logic

#### Loading a Page
**Lines:** 891-956 (loadPage function)
```swift
func loadPage(_ pageNumber: Int, selectWord: WordIdentifier? = nil) {
    // In 2-page mode, ensure we always have an odd page number
    let actualPage: Int
    if shouldShowTwoPages {
        actualPage = pageNumber % 2 == 0 ? pageNumber - 1 : pageNumber
    } else {
        actualPage = pageNumber
    }

    actualDisplayedPage = actualPage

    // Load fonts and data for both pages if in 2-page mode
    // ...

    lines = MushafCache.shared.getLinesForPage(actualPage)
    lineWords = MushafCache.shared.getPageWords(actualPage)

    if shouldShowTwoPages && evenPage <= 604 {
        linesLeft = MushafCache.shared.getLinesForPage(evenPage)
        lineWordsLeft = MushafCache.shared.getPageWords(evenPage)
    }
}
```

#### Navigation with Auto-Selection Flag
**Lines:** 391, 894-898
```swift
@State private var isAutoNavigating: Bool = false  // Track if we're auto-turning pages

// In loadPage:
if !isAutoNavigating && selectWord == nil {
    selectedWord = nil
}
isAutoNavigating = false  // Reset flag
```

This flag prevents clearing the selection when navigating to a word via bookmark or error jump.

### Previous Page Tracking
**Key Finding:** There is NO explicit "previous page" tracking variable. Navigation functions calculate the target page dynamically:

**Lines:** 1745-1756 (previousPage function)**
```swift
func previousPage() {
    if currentPage > 1 {
        if shouldShowTwoPages {
            // In 2-page mode, skip by 2 pages (always land on odd page)
            currentPage = max(1, currentPage - 2)
        } else {
            currentPage -= 1
        }

        writeLog("⬅️  Previous page: \(currentPage)")
    }
}
```

The previous page is calculated as:
- In single-page mode: `currentPage - 1`
- In 2-page mode: `currentPage - 2`

## Integration Summary

### How Systems Work Together

1. **Selection → Visibility:** The `selectedWord` state drives what is visible in hidden mode via the `isWordVisible()` function
2. **Gestures → Navigation:** Swipe gestures call navigation functions that modify `selectedWord` or `currentPage`
3. **Navigation → Loading:** Changes to `currentPage` trigger `loadPage()` via `onChange` (line 781)
4. **Word Taps → Interactions:** Tapping a word updates selection and records interactions in `WordData`
5. **Pages → Words:** `MushafCache` provides mappings from pages to lines to words

### Data Flow for Anchor Point Feature

To implement anchor point navigation, the following flow would be needed:

```
User sets anchor → Store WordIdentifier + currentPage
User swipes up → Check if anchor exists
  If yes → Navigate to anchor page + select anchor word
  If no → Fall back to previousVerse() behavior
```

## Potential Integration Challenges

### 1. Anchor State Management
**Challenge:** Need to add a new state variable to track the anchor point
```swift
@State private var anchorWord: WordIdentifier? = nil
@State private var anchorPage: Int? = nil
```

**Location:** These would go in `ContentView` around line 390 with other state variables

### 2. Gesture Conflict in Hidden Mode
**Challenge:** Up swipe currently calls `previousVerse()` (line 555)
```swift
if value.translation.height < 0 {
    // Swipe up -> click double right chevron (green) -> previous verse
    writeLog("⬆️ Swipe up -> previous verse")
    previousVerse()
}
```

**Solution:** Need to modify this to:
1. Check if anchor exists
2. If yes, navigate to anchor
3. If no, call `previousVerse()`

### 3. Cross-Page Navigation
**Challenge:** Anchor might be on a different page than current position
**Existing Solution:** The codebase already handles this well in `jumpToBookmark()` (lines 1206-1238) and `jumpToError()` (lines 1043-1180)

**Pattern to follow:**
```swift
isAutoNavigating = true
currentPage = targetPage
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    self.selectedWord = anchorWord
    // Additional logic here
}
```

### 4. Visual Feedback
**Challenge:** Need to distinguish anchor point from regular selection
**Current Selection:** Blue rounded rectangle with 2pt stroke (line 278)
**Recommendation:** Add a different color or icon overlay for anchor words (e.g., orange outline or anchor icon)

### 5. Anchor Persistence
**Challenge:** Should anchor persist across app sessions?
**Existing Pattern:** Use `@AppStorage` like `currentPage` (line 385)
```swift
@AppStorage("anchorSurah") private var anchorSurah: Int = 0
@AppStorage("anchorAyah") private var anchorAyah: Int = 0
@AppStorage("anchorPosition") private var anchorPosition: Int = 0
@AppStorage("anchorPage") private var anchorPageNum: Int = 0
```

### 6. Two-Page Mode Considerations
**Challenge:** Anchor might be on the left (even) page in 2-page mode
**Existing Solution:** `jumpToBookmark()` handles this (lines 1220-1226):
```swift
if shouldShowTwoPages {
    // Ensure we land on an odd page so both pages in the pair are visible
    displayPage = page % 2 == 0 ? page - 1 : page
}
```

## Recommendations for Phase 2

1. **Add anchor state variables** in `ContentView` near line 390
2. **Modify up swipe handler** (line 553-556) to check for anchor before calling `previousVerse()`
3. **Create `setAnchor()` function** to capture current selection and page
4. **Create `jumpToAnchor()` function** modeled after `jumpToBookmark()`
5. **Add visual indicator** for anchor point (different from selection)
6. **Add gesture/button** to set anchor (long-press on word, or dedicated button)
7. **Handle edge cases:**
   - What if user tries to set anchor when nothing is selected?
   - What if anchor page is unloaded from cache?
   - Should anchor clear when app restarts?
   - Should there be multiple anchors or just one?

## Files That Will Need Modification

1. **MemQuran/ContentView.swift** - Main changes here
   - Add anchor state (line ~390)
   - Modify up swipe gesture (line 553-556)
   - Add setAnchor() function
   - Add jumpToAnchor() function
   - Add visual indicator for anchor word

2. **Potentially MemQuran/Models.swift** - If anchors need persistence in database
   - Add `AnchorPoint` model if needed for advanced features

## Notes
- The codebase is well-structured for this feature
- Existing navigation patterns (bookmark, error jump) provide excellent templates
- The `WordIdentifier` struct is perfect for representing anchor points
- Hidden mode logic is clean and extensible
- No major architectural changes needed
