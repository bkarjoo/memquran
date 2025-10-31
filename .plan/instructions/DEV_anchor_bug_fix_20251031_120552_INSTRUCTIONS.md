# Development Team - Phase 3: Fix Bug - Up Swipe Anchor Creation

## Team Assignment
**Development Team**

## Phase/Version
**Phase 3** - Bug fix for up swipe anchor creation

## Context
**BUG IDENTIFIED:** Up swipe is incorrectly creating a NEW anchor on EVERY swipe instead of only auto-setting on the FIRST swipe when no anchor exists.

**REQUIRED READING:**
- `.plan/responses/code_review_3_RESPONSE.md` - Complete bug investigation with root cause and proposed fix

## Bug Summary
From code review investigation:
- **Root Cause:** Two sequential `if` statements cause anchor to be set AND immediately checked in same execution
- **Location:** `MemQuran/ContentView.swift` lines 566-586
- **Severity:** HIGH (core feature broken)
- **Fix:** Change second `if` to `else` and add anchor removal check when at anchor position

## Dependencies
- Code Review Phase 3 complete ✓ (bug investigation)

## Objectives
Fix the up swipe logic to:
1. First up swipe (no anchor): Set anchor + navigate backwards (NOT jump)
2. Second up swipe (anchor exists): Jump to anchor
3. Third up swipe (at anchor): Remove anchor + navigate backwards
4. Ensure anchor persists across multiple swipes (not recreated each time)

## Implementation Instructions

### Fix Location
**File:** `MemQuran/ContentView.swift`
**Lines:** 566-586 (approximate - in the up swipe gesture handler)

### Current Code (BROKEN):
```swift
if value.translation.height < 0 {
    // Swipe up logic with anchor support
    if anchorWord == nil {
        // No anchor exists - set current selection as anchor before navigating
        if let selected = selectedWord {
            anchorWord = selected
            anchorPage = currentPage
            writeLog("📍 Set anchor: \(selected.surah):\(selected.ayah):\(selected.position) on page \(currentPage)")
        }
    }

    if anchorWord != nil {
        // Anchor exists - jump to it
        writeLog("⬆️ Swipe up -> jump to anchor")
        jumpToAnchor()
    } else {
        // No anchor and no selection - navigate to previous verse
        writeLog("⬆️ Swipe up -> previous verse")
        previousVerse()
    }
}
```

**Problem:** Both `if` statements execute in sequence, causing immediate jump after setting anchor.

### Fixed Code (REQUIRED):
```swift
if value.translation.height < 0 {
    // Swipe up logic with anchor support
    if anchorWord == nil {
        // No anchor exists - set current selection as anchor, then navigate backwards
        if let selected = selectedWord {
            anchorWord = selected
            anchorPage = currentPage
            writeLog("📍 Set anchor: \(selected.surah):\(selected.ayah):\(selected.position) on page \(currentPage)")
        }
        // After setting anchor, navigate to previous verse (do NOT jump to anchor yet)
        writeLog("⬆️ Swipe up -> previous verse (anchor set for later return)")
        previousVerse()
    } else {
        // Anchor exists - check if we're at the anchor position
        if let anchor = anchorWord, selectedWord == anchor {
            // At anchor - remove it and navigate backwards
            writeLog("⬆️ At anchor -> removing anchor and navigating to previous verse")
            anchorWord = nil
            anchorPage = nil
            previousVerse()
        } else {
            // Not at anchor - jump to it
            writeLog("⬆️ Swipe up -> jump to anchor")
            jumpToAnchor()
        }
    }
}
```

### Key Changes:
1. **Line ~576:** Changed second `if` to `else` (mutually exclusive conditions)
2. **Lines ~576-579:** After setting anchor, call `previousVerse()` instead of checking for anchor
3. **Lines ~580-595:** Added check: if `selectedWord == anchorWord` (user is at anchor)
4. **Lines ~582-586:** If at anchor, remove it and navigate backwards
5. **Lines ~587-591:** If not at anchor, jump to it
6. **Updated log messages** for clarity

## Testing Requirements

### Manual Testing Checklist:
After implementing the fix, manually test this exact workflow:

1. **Setup:**
   - Enter hidden mode
   - Navigate to page 10
   - Reveal several words

2. **First Up Swipe (no anchor exists):**
   - Swipe up
   - ✅ **Verify:** Red square appears at last visible word (anchor set)
   - ✅ **Verify:** Blue square moves backwards (navigation happened)
   - ✅ **Verify:** Log shows "📍 Set anchor" and "⬆️ Swipe up -> previous verse (anchor set for later return)"
   - **❌ Expected NOT to happen:** Jump to anchor

3. **Navigate Forward:**
   - Swipe down 5-10 times to move forward in the Quran
   - ✅ **Verify:** Red square still visible at anchor position (anchor persists)
   - ✅ **Verify:** Blue square moves forward

4. **Second Up Swipe (anchor exists, not at anchor):**
   - Swipe up
   - ✅ **Verify:** Blue square jumps back to red square (jump to anchor)
   - ✅ **Verify:** Red square still there (anchor not removed)
   - ✅ **Verify:** Log shows "⬆️ Swipe up -> jump to anchor"
   - **❌ Expected NOT to happen:** New red square created at current position

5. **Third Up Swipe (at anchor position):**
   - Swipe up again (now at anchor)
   - ✅ **Verify:** Red square disappears (anchor removed)
   - ✅ **Verify:** Blue square moves backwards (navigation happened)
   - ✅ **Verify:** Log shows "⬆️ At anchor -> removing anchor and navigating to previous verse"

6. **Fourth Up Swipe (no anchor again):**
   - Swipe up again
   - ✅ **Verify:** New red square appears (anchor re-created - cycle restarts)
   - ✅ **Verify:** Blue square moves backwards
   - ✅ **Verify:** Cycle repeats correctly

### Expected Workflow Summary:
```
Swipe 1: Set anchor → Navigate back
Swipe 2: Jump to anchor
Swipe 3: Remove anchor → Navigate back
Swipe 4: Set new anchor → Navigate back
Swipe 5: Jump to new anchor
...cycle continues...
```

## Build and Test

### 1. Build the Project
```bash
xcodebuild -scheme "MemQuran iOS" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: Build succeeds with no errors

### 2. Run Manual Tests
Follow the testing checklist above in the simulator or on device

### 3. Check Logs
Monitor console output for correct log messages:
- "📍 Set anchor: X:Y:Z on page N"
- "⬆️ Swipe up -> previous verse (anchor set for later return)"
- "⬆️ Swipe up -> jump to anchor"
- "⬆️ At anchor -> removing anchor and navigating to previous verse"

## Success Criteria

- [ ] Code changes implemented exactly as specified
- [ ] Build succeeds with no errors
- [ ] Manual test workflow completed successfully (all 6 steps)
- [ ] Anchor persists across multiple swipes (not recreated)
- [ ] First up swipe navigates backwards (doesn't jump)
- [ ] Second up swipe jumps to anchor
- [ ] Third up swipe removes anchor and navigates backwards
- [ ] Logs show correct messages for each action
- [ ] No regressions in other anchor functionality (tap to set, tap to remove, out of scope removal)

## Verification Steps

### Before Claiming Fix Complete:

1. **Verify anchor persistence:**
   - Set anchor on page 10
   - Navigate to page 20
   - Swipe up - should jump back to page 10 anchor
   - Verify anchor is SAME one set initially (not new one)

2. **Verify cycle restart:**
   - Complete full cycle (set → jump → remove)
   - Verify next up swipe sets NEW anchor (cycle restarts)

3. **Verify 2-page mode:**
   - Switch to 2-page mode
   - Test same workflow
   - Verify anchor works correctly on both pages

4. **Verify mode persistence:**
   - Set anchor in hidden mode
   - Switch to visible mode
   - Switch back to hidden mode
   - Swipe up - should jump to anchor (not create new one)

## Known Issues

From code review investigation:

### Issue: `checkAndRemoveAnchorIfNeeded()` Name
The function `checkAndRemoveAnchorIfNeeded()` only checks if anchor is out of scope (not on current/previous page). It does NOT check if user is at anchor.

**Note:** This is CORRECT behavior. The "at anchor" check is now in the up swipe handler (as implemented in this fix).

**Optional:** Consider renaming to `checkAndRemoveOutOfScopeAnchor()` for clarity (NOT required for this fix).

## Response File Request

Document your fix in:
**File:** `.plan/responses/development_3_RESPONSE.md`

Include:
- Summary of changes made (file, lines, what changed)
- Code snippets showing before/after
- Build results (success/errors)
- Manual testing results for all 6 steps
- Log output examples
- Any deviations from instructions (with reasons)
- Issues encountered and solutions
- Verification steps completed
- **Status:** [Complete/Blocked/In Progress]

## GIT WORKFLOW

When you complete this phase:

1. **Commit your fix:**
   ```bash
   git add MemQuran/ContentView.swift
   git commit -m "Fix bug: Up swipe anchor creation logic

   Bug: Up swipe was creating new anchor on every swipe
   Root cause: Two sequential 'if' statements caused immediate jump after setting anchor

   Fix:
   - Changed second 'if' to 'else' for mutually exclusive conditions
   - First up swipe (no anchor): Set anchor + navigate backwards
   - Second up swipe (anchor exists): Jump to anchor
   - Third up swipe (at anchor): Remove anchor + navigate backwards
   - Anchor now persists across multiple swipes

   Testing:
   - Manual workflow tested (6-step cycle)
   - Anchor persistence verified
   - Logs show correct behavior

   Fixes: Phase 3 bug investigation

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

2. **Commit your response file:**
   ```bash
   git add .plan/responses/development_3_RESPONSE.md
   git commit -m "Complete Phase 3 development response - bug fix"
   ```

3. **Do NOT push yet** - Wait for testing team to verify fix

This ensures proper verification before merge.

## Next Steps After Fix

1. Testing team will re-test the fix
2. Code review team may review the fix
3. After approval, merge to main branch
4. Update TODO.md to reflect bug fix

## Contact Project Manager

If you encounter any issues or need clarification, report back to project manager before proceeding.
