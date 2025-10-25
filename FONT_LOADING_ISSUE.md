# Font Loading Issue - Analysis and Solution Proposal

## Problem Description

The app attempts to register 604 page-specific fonts (p1.ttf through p604.ttf) synchronously during app initialization (`init()` in MemQuranApp.swift). This causes:

1. **Slow app startup** - Registering 604 fonts blocks the main thread
2. **Rendering issues** - View renders before all fonts are registered
3. **Visual glitches** - Boxes (□) appear instead of Arabic text when fonts aren't ready
4. **Layout problems** - "Half page load" and "verses going off page" when font metrics unavailable

## Current Implementation

```swift
// MemQuranApp.swift lines 20-23
for i in 1...604 {
    fontNames.append("p\(i).ttf")
}
```

All 604 fonts are registered in `init()` before the app window appears.

## Root Cause

When `useQPCV1 = true`, each page requires its own font file (QCF_P001, QCF_P002, etc.). The app tries to register all fonts upfront, but:
- Font registration is synchronous
- The view starts rendering before registration completes
- Fonts not yet registered cause fallback to system font → boxes appear

## Proposed Solution: Lazy Font Loading

**Load fonts on-demand, only when needed for the current page.**

### Implementation Strategy

1. **Remove bulk font registration from init()**
   - Don't register all 604 fonts at startup
   - Only register base fonts (Kitab, UthmanTN, etc.) needed for UI

2. **Create a lazy font loader service**
   ```swift
   class FontLoader {
       static let shared = FontLoader()
       private var loadedFonts: Set<Int> = []

       func ensureFontLoaded(forPage page: Int) {
           guard !loadedFonts.contains(page) else { return }
           registerFont(name: "p\(page).ttf")
           loadedFonts.insert(page)
       }
   }
   ```

3. **Call before rendering each page**
   ```swift
   func loadPage(_ pageNumber: Int) {
       // Ensure font is loaded BEFORE rendering
       FontLoader.shared.ensureFontLoaded(forPage: pageNumber)

       // Then load page data...
   }
   ```

4. **Preload surrounding page fonts in background**
   ```swift
   DispatchQueue.global(qos: .userInitiated).async {
       for page in (pageNumber-2)...(pageNumber+2) {
           FontLoader.shared.ensureFontLoaded(forPage: page)
       }
   }
   ```

### Benefits

- **Fast startup** - Only loads 1-3 fonts initially (current page + maybe neighbors)
- **No blocking** - Fonts load on-demand as user navigates
- **Memory efficient** - Only keep fonts for visible/nearby pages in memory
- **Smooth navigation** - Preload surrounding pages in background

### Trade-offs

- First time viewing a page might have tiny delay (one font load)
- Need to handle font registration failures gracefully
- Slightly more complex than current "load everything" approach

### Alternative: Async Font Registration with Delay

If lazy loading is too complex, simpler alternative:

```swift
func registerCustomFonts() {
    // Register only base fonts synchronously
    registerBaseFonts()

    // Register page fonts asynchronously
    DispatchQueue.global(qos: .background).async {
        registerPageFonts()
    }
}
```

Then delay initial page render:
```swift
.onAppear {
    // Wait for current page font to be ready
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        loadPage(currentPage)
    }
}
```

**Downside:** Still loads all 604 fonts eventually, just doesn't block startup.

## Recommendation

**Implement lazy font loading** - it's the proper solution that scales and provides the best user experience.

## Implementation Steps

1. Create `FontLoader` class in new file
2. Remove 604-font loop from `MemQuranApp.init()`
3. Call `FontLoader.ensureFontLoaded()` in `loadPage()` before rendering
4. Add background preloading for ±2 pages around current
5. Test with cold start, navigation, and page jumps

## Expected Outcome

- App launches instantly (< 100ms)
- Current page renders correctly with proper font
- No boxes or layout issues
- Smooth navigation as fonts preload in background
