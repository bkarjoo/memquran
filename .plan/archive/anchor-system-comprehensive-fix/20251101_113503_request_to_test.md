**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** issue-anchor-v2-nil-selector

**Test Assignment: Verify Anchor V2 Nil Selector Fix**

The development team has completed implementation of a fix for the infinite loop issue that occurred when jumping to anchor with nil selectedWord. Your task is to verify the fix works correctly.

**Background:**
The issue was an infinite loop that occurred when:
1. User had an anchor set but no selectedWord selected
2. jumpToAnchor() was triggered
3. After jumping, navigating to next page would clear selectedWord again
4. This re-triggered the nil selector condition, causing infinite loop

**Solution Implemented:**
- Modified `jumpToAnchor()` in ContentView.swift to accept `fromNilSelector` parameter
- When jumping from nil selector scenario, anchor is immediately cleared after successful jump
- This prevents re-triggering the condition on subsequent navigation

**Test Scenarios to Verify:**

1. **Basic Nil Selector Jump:**
   - Set an anchor on a word (e.g., page 5)
   - Navigate away without selecting any word (selectedWord = nil)
   - Trigger swipe gesture to jump back to anchor
   - Verify: Jump should succeed and user should land on anchor page
   - Verify: After jump, user can navigate freely without getting stuck

2. **Navigation After Jump:**
   - After performing nil selector jump (scenario 1)
   - Navigate to next page using swipe
   - Verify: No automatic jump back occurs
   - Verify: User can continue navigating normally

3. **Normal Anchor Functionality:**
   - Set an anchor while having a selectedWord
   - Navigate and trigger normal anchor jump
   - Verify: Normal anchor behavior remains unaffected

4. **Edge Cases:**
   - Test rapid swipes after nil selector jump
   - Test jumping to anchors at page boundaries
   - Test with multiple anchor sets/clears

**Build Status:**
Build successful for both iOS and macOS targets. App launches successfully in simulator.

**Testing Notes:**
- The fix specifically addresses the swipe gesture handlers (lines 1392, 1398 in ContentView.swift)
- Focus on verifying the anchor is properly cleared after nil selector jumps
- Ensure no regression in normal anchor functionality

**Expected Outcome:**
All test scenarios should pass without infinite loops or navigation issues. Document any edge cases or unexpected behaviors discovered during testing.

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**