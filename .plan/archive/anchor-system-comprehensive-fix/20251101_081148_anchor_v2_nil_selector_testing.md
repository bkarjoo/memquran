**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

# Testing Assignment: Anchor V2 Nil Selector Edge Case Verification

## Context
Development has completed a fix for the Anchor V2 nil selector edge case (commit 8297107). The fix handles vertical swipes when an anchor exists but no selector is set.

## Changes Made by Development
- Modified `ContentView.swift` (lines 598-658)
- Added nil selector handling: when `capturedAnchorWord != nil && capturedSelectedWord == nil`, vertical swipes now jump to the anchor regardless of direction
- Preserved existing logic for cases where both anchor and selector exist

## Testing Requirements
Verify all four test scenarios:

1. **Downward swipe with anchor below (visible verses)** - existing logic preserved
   - Set anchor to a word that's visible below current view
   - Also select a second word (selector)
   - Perform downward swipe
   - Expected: Should jump to anchor

2. **Upward swipe with anchor above (visible verses)** - existing logic preserved
   - Set anchor to a word that's visible above current view
   - Also select a second word (selector)
   - Perform upward swipe
   - Expected: Should jump to anchor

3. **Downward swipe with anchor below (nil selector)** - **NEW FIX**
   - Set anchor to a word that's visible below current view
   - Do NOT select a second word (selector should be nil)
   - Perform downward swipe
   - Expected: Should jump to anchor

4. **Upward swipe with anchor above (nil selector)** - **NEW FIX**
   - Set anchor to a word that's visible above current view
   - Do NOT select a second word (selector should be nil)
   - Perform upward swipe
   - Expected: Should jump to anchor

## Debug Output to Check
Look for console logs showing:
- "Swipe up -> jump to anchor (nil selector)"
- "Swipe down -> jump to anchor (nil selector)"

## Deliverables
In your response.md, document:
- Test results for all 4 scenarios (pass/fail)
- Any unexpected behavior observed
- Console log verification
- Recommendation: pass to review, return to development, or mark complete

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
