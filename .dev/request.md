**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** remove-word-caching

**Requirements:** See `.lifecycle/remove-word-caching/requirements.md` for detailed specifications

## Assignment: Remove Word Caching System from MushafCache

**Context:**
User tested the app with "Cache Quran Data" disabled and found absolutely no performance advantage to caching words in memory. The requirements document has been reviewed and approved by the review team, and is now ready for implementation.

**Task:** Implement the removal of the word caching system from `MushafCache.swift` according to the detailed specifications in the requirements document.

**Key Implementation Points:**

1. **Follow Option A** (recommended): Keep the `MushafCache` interface but delegate word operations to `MushafDatabase`
2. **Critical: Format Conversion** - `MushafDatabase.getPageWords()` returns tuples `[(line: Int, words: [QuranWord])]` but `MushafCache.getPageWords()` must return dictionary `[Int: [QuranWord]]`. See requirements lines 112-121 for working code example.
3. **Thread Safety** - Remove `loadQueue.sync` blocks from word operations (lines 116, 124, 141-143) but KEEP for page layout operations (line 109, ensurePagesLoaded methods)
4. **ContentView Helper** - Don't forget to verify the helper function `getWordsForPage()` at ContentView.swift:1596 still works after changes
5. **Test File Decision** - Evaluate `CacheDataSettingTests.swift` and decide whether to remove or update it

**Implementation Approach:**
- Follow the implementation order suggested in requirements section "Implementation Recommendations"
- Make atomic commits for each logical change
- Test incrementally as you go

**Expected Outcomes:**
- Memory footprint reduced by ~3.3 MB (77,800 words × ~45 bytes each)
- Performance matches current "cache disabled" mode (already verified as acceptable)
- All existing functionality preserved (bookmarks, navigation, search, display)
- Page layout caching remains fully functional

**Testing Requirements:**
- Run full test suite before and after changes
- Verify memory reduction using Instruments or test suite's `getMemoryUsage()` method
- Test all word-related features: display, bookmarks, navigation, search
- Ensure thread safety maintained (no crashes under concurrent access)

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
