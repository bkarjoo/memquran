# Anchor Point Navigation - Simplified Requirements V2

## Change Summary
**Date:** October 31, 2025
**Version:** 2.0
**Reason:** Original requirements (v1) were too complex with 2 creation methods and 5 removal methods. Simplified to more intuitive behavior.

## Changes from V1
- ❌ **REMOVED:** Automatic anchor creation on up swipe
- ❌ **REMOVED:** Anchor removal when at anchor and swipe up
- ❌ **REMOVED:** Anchor removal when navigate before anchor
- ✅ **CHANGED:** Up/down swipes now check anchor direction (above/below)
- ✅ **SIMPLIFIED:** Only 1 way to create anchor (tap), 3 ways to remove (tap anchor, tap other word, out of scope)

---

## Anchor Point Creation

### Only Method: Manual Tap
- User taps any visible word in hidden mode
- That word becomes the anchor (red rounded corner square)
- **Includes last visible word** (no restriction)
- Only works in hidden mode
- Only ONE anchor allowed at a time

---

## Anchor Point Removal

### Method 1: Tap on Anchor Itself
- User taps the anchor (red square)
- Anchor is removed
- No new anchor is created

### Method 2: Tap on Different Word
- User taps a different visible word
- Old anchor is removed
- New anchor is created at tapped word
- This MOVES the anchor (not removes it)

### Method 3: Out of Scope (Automatic)
- Anchor is automatically removed if it goes out of scope
- **Scope:** Current page +/- 1 page
  - If anchor on page 10, it's in scope on pages 9, 10, 11
  - If user navigates to page 8 or 12, anchor is removed
- This prevents orphaned anchors

### NOT Removed When:
- User navigates before the anchor (anchor stays)
- User switches between visible/hidden mode (anchor persists)
- User swipes past the anchor (anchor stays)

---

## Swipe Behavior with Anchor

### Up Swipe Logic
```
IF anchor exists AND anchor is ABOVE current position:
    Jump to anchor
ELSE:
    Normal navigation (previous verse/aya marker)
```

**Examples:**
- Current position: Verse 10, Anchor: Verse 5 (above) → Up swipe jumps to Verse 5
- Current position: Verse 10, Anchor: Verse 15 (below) → Up swipe goes to Verse 9 (normal)
- Current position: Verse 10, No anchor → Up swipe goes to Verse 9 (normal)

### Down Swipe Logic
```
IF anchor exists AND anchor is BELOW current position:
    Jump to anchor
ELSE:
    Normal navigation (next verse/aya marker)
```

**Examples:**
- Current position: Verse 10, Anchor: Verse 15 (below) → Down swipe jumps to Verse 15
- Current position: Verse 10, Anchor: Verse 5 (above) → Down swipe goes to Verse 11 (normal)
- Current position: Verse 10, No anchor → Down swipe goes to Verse 11 (normal)

### Determining "Above" vs "Below"
Compare word positions using (surah, ayah, position):
- **Above:** anchorWord < selectedWord (earlier in Quran)
- **Below:** anchorWord > selectedWord (later in Quran)
- Use existing `WordIdentifier` comparison logic

---

## Visual Indicators

### Anchor (Red Square)
- Red rounded corner square (2pt stroke)
- Only visible in hidden mode
- Shows where anchor is set

### Selection (Blue Square)
- Blue rounded corner square (2pt stroke)
- Shows current position (last visible word)
- Both red and blue can be visible simultaneously

---

## Scope Rules

### In Scope (Anchor Persists):
- Anchor on current page
- Anchor on previous page (current - 1)
- Anchor on next page (current + 1)

### Out of Scope (Anchor Removed):
- Anchor is 2+ pages away from current page
- Example: Current page 10, anchor on page 8 → Out of scope (removed)
- Example: Current page 10, anchor on page 12 → Out of scope (removed)

### 2-Page Mode Consideration:
- In 2-page mode, check both displayed pages (even and odd)
- Anchor in scope if on either displayed page or within +/-1 of displayed pages

---

## Mode Behavior

### Hidden Mode Only
- Anchor functionality ONLY works in hidden mode
- In visible mode: Anchors not functional (but persist in memory)

### Mode Switching
- Switching to visible mode: Anchor persists (not removed)
- Switching back to hidden mode: Anchor reappears and is functional
- Anchor state survives mode switches

---

## Persistence

### Session-Only
- Anchors exist only during app session
- NOT persisted to database
- NOT synced to cloud
- Anchors lost when app closes/restarts

### In-Memory State
- Stored in `@State private var anchorWord: WordIdentifier?`
- Stored in `@State private var anchorPage: Int?`

---

## Comparison: V1 vs V2

| Feature | V1 (Complex) | V2 (Simplified) |
|---------|--------------|-----------------|
| **Creation Methods** | 2 (auto + manual) | 1 (manual only) |
| **Removal Methods** | 5 | 3 |
| **Up Swipe Behavior** | Auto-set anchor on first swipe, jump on second | Jump if anchor above, else normal |
| **Down Swipe Behavior** | Normal only | Jump if anchor below, else normal |
| **Last Word Restriction** | Can't manually select last word as anchor | Can select any visible word |
| **At Anchor Behavior** | Remove anchor on up swipe | Anchor stays (no special behavior) |
| **Navigate Before Anchor** | Removes anchor | Anchor stays |
| **Scope** | Current or previous page | Current +/- 1 page |
| **User Confusion** | High (complex rules) | Low (intuitive) |

---

## Implementation Impact

### Code Changes Required:
1. **Remove** automatic anchor creation on up swipe
2. **Remove** anchor removal when at anchor
3. **Remove** anchor removal when navigating before anchor
4. **Add** direction check (above/below) for up/down swipes
5. **Update** scope logic (current +/- 1 instead of current or previous)
6. **Update** tap handler to allow last visible word as anchor
7. **Simplify** up swipe logic (remove 3-step cycle)

### Tests to Update:
- Remove tests for automatic anchor creation
- Remove tests for "at anchor" removal
- Add tests for directional swipe behavior
- Add tests for scope (current +/- 1 page)
- Update tests for last visible word tapping

---

## User Benefits

### Simpler Mental Model
- ✅ Tap to set anchor (obvious)
- ✅ Swipe toward anchor to jump (intuitive)
- ✅ No automatic behavior to remember
- ✅ Fewer edge cases

### More Control
- ✅ User decides when to set anchor (not automatic)
- ✅ Can set anchor anywhere (including last visible word)
- ✅ Anchor stays until explicitly removed or out of scope
- ✅ Predictable behavior

### Better UX
- ✅ "Swipe toward anchor" is natural
- ✅ No confusion about when anchor is set
- ✅ No surprise anchor removal
- ✅ Consistent with user expectations

---

## Migration from V1

### For Users:
- **Breaking Change:** Up swipe no longer auto-sets anchor
- **User Impact:** Must manually tap to set anchor
- **Benefit:** More predictable, less confusing

### For Codebase:
- **Simplification:** Reduce code complexity
- **Maintainability:** Easier to understand and debug
- **Testing:** Fewer test scenarios needed

---

## Open Questions (To Be Resolved)

### Question 1: Left/Right Swipes
Current requirements don't specify left/right swipe behavior with anchors. Should they:
- A) Ignore anchor (normal page navigation)
- B) Jump to anchor if on different page
- C) Something else

**Recommendation:** A) Ignore anchor (keep page navigation separate)

### Question 2: Anchor at Exact Current Position
What if anchor and selection are at the same word?
- Current behavior: Both red and blue squares at same position
- Is this confusing? Should we handle it differently?

**Recommendation:** Keep as-is, both squares visible (user can see anchor is set)

---

## Status
**Status:** Draft - Awaiting approval
**Next Step:** Create development instructions for V2 implementation
**Estimated Complexity:** Moderate (simplifies some code, changes others)
