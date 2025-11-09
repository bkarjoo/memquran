**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** immediate-cache-clearing

**Requirements:** See `.lifecycle/immediate-cache-clearing/requirements.md` for detailed specifications

## Assignment: Implement Immediate Cache Clearing

Based on real device testing by the end user, we discovered that disabling the "Cache Quran Data" setting provides immediate scrolling/navigation performance improvements due to reduced memory pressure. However, the current implementation doesn't clear the cache until app restart, creating a confusing UX.

**Your Task:**
Implement immediate cache clearing when the user toggles the setting to disabled.

**Implementation Summary:**
1. Add `clearWordCache()` method to MushafCache.swift (thread-safe with loadQueue.sync)
2. Add `.onChange` handler to the toggle in SettingsView.swift that calls clearWordCache() when disabled
3. Ensure existing on-demand loading in `getWords()` continues to work after cache is cleared

**Key Constraints:**
- Only clear cache when toggling to disabled (not when enabling)
- Don't bulk load words mid-session if user re-enables (wait for next app restart)
- Thread-safe implementation required (use loadQueue.sync)

**User Impact:**
This enhancement provides immediate memory relief (~3.3MB) and scrolling performance improvement without requiring app restart. User testing confirmed noticeable performance gains.

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
