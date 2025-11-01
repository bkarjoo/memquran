# Code Review Team - Phase 1: Codebase Architecture Analysis

## Team Assignment
**Code Review Team**

## Phase/Version
**Phase 1** - Initial codebase analysis for anchor point feature

## Context
We are planning to implement an "Anchor Point Navigation" feature for hidden mode. This feature allows users to mark a reference point (anchor) and quickly return to it with an up swipe. Before we can create a detailed implementation plan, we need to understand the existing architecture.

## Dependencies
None - this is the first phase

## Objectives
Analyze the MemQuran codebase to understand how the current selection, navigation, and hidden mode systems work, so we can plan how to integrate the anchor point feature.

## Deliverables

Please investigate and document the following:

### 1. Selection System (Blue Rounded Corner Square)
- **Find:** Where is the blue rounded corner square indicator drawn?
- **Find:** What state variable(s) track the current selection?
- **Find:** What data structure represents a selected word position?
- **Report:** File paths, line numbers, variable names, and code snippets

### 2. Swipe Gesture Handling
- **Find:** Where are up/down/left/right swipe gestures handled?
- **Find:** What functions handle navigation when user swipes?
- **Find:** How does up swipe currently work (does it go to previous aya marker)?
- **Report:** File paths, line numbers, function names, and gesture logic

### 3. Hidden Mode Logic
- **Find:** How is visibility determined for words?
- **Find:** What code controls showing/hiding words?
- **Find:** How is "last visible word" calculated?
- **Report:** File paths, line numbers, and visibility logic

### 4. Word Tap Handling
- **Find:** Where does the code handle taps on words?
- **Find:** What happens when user taps a word in hidden mode?
- **Report:** File paths, line numbers, and tap handler logic

### 5. Data Models
- **Find:** What struct/class defines word position (WordPosition, Word, etc.)?
- **Find:** What properties does it have (page, line, position, etc.)?
- **Find:** What model represents aya markers?
- **Report:** Complete data structure definitions

### 6. Page Tracking
- **Find:** How does the app track current page and previous page?
- **Find:** What state variables hold page information?
- **Report:** Page state management details

## Success Criteria
- All 6 areas above are documented with specific file paths and line numbers
- Code snippets provided for key functions and data structures
- Clear explanation of how these systems currently work together
- Any potential integration challenges identified

## Response File Request
Please document your findings in:
**File:** `.plan/responses/code_review_1_RESPONSE.md`

Include in your response:
- Complete answers to all 6 investigation areas above
- File paths with line numbers
- Code snippets for key sections
- Summary of how the systems interconnect
- Any concerns or risks for anchor point integration
- **Status:** [Complete/Blocked/In Progress]

## GIT WORKFLOW

When you complete this phase:

1. **Commit your response file:**
   ```bash
   git add .plan/responses/code_review_1_RESPONSE.md
   git commit -m "Complete Phase 1 codebase analysis for anchor point feature

   - Documented selection system architecture
   - Identified swipe gesture handlers
   - Mapped hidden mode visibility logic
   - Found word tap handling code
   - Documented data models
   - Identified page tracking state

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

2. **Do NOT push yet** - Wait for project planner to review findings

This ensures all analysis is version-controlled and traceable.
