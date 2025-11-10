**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** remove-word-caching

**Requirements:** See `.lifecycle/remove-word-caching/requirements.md` for updated detailed specifications

## Assignment: Fix Critical SQLite Thread Safety Bug

**Context:**

Testing discovered a **CRITICAL** thread safety bug in the previous implementation (commit c585b08). The tester found SQLite multi-threading violations during app launch:

```
BUG IN CLIENT OF libsqlite3.dylib: illegal multi-threaded access to database connection
```

**Root Cause:**

The code review and requirements document incorrectly assumed that "SQLite handles its own thread safety." This is **FALSE**. SQLite database connections (`OpaquePointer`) are **NOT thread-safe by default** and require explicit synchronization.

The previous implementation removed `loadQueue.sync` blocks from MushafCache word operations and delegated directly to MushafDatabase, but MushafDatabase has NO thread safety mechanisms. This exposed the raw SQLite connections to concurrent access from multiple threads:

1. **Main thread** - UI calls from ContentView
2. **Background thread** - Async loading from ContentView (DispatchQueue.global)
3. **Init background thread** - MushafCache initialization

All three threads call MushafDatabase methods that access the same `layoutDB` and `wordsDB` pointers without synchronization, causing undefined behavior.

---

## What Needs to be Fixed

**File:** `MemQuran/MushafDatabase.swift`

MushafDatabase must be updated to add explicit thread safety to prevent concurrent access to SQLite connections.

---

## Implementation Requirements

### 1. Add Serial DispatchQueue

Add a private serial DispatchQueue to MushafDatabase:

```swift
public class MushafDatabase {
    private var layoutDB: OpaquePointer?
    private var wordsDB: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.memquran.database", qos: .userInitiated)

    // ... rest of implementation
}
```

### 2. Wrap ALL Public Database Methods

Wrap ALL public methods that access `layoutDB` or `wordsDB` with `dbQueue.sync { }` blocks.

**Methods that MUST be wrapped:**
- `getLinesForPage(_:)` - accesses layoutDB
- `getWords(from:to:)` - accesses wordsDB
- `getPageWords(_:)` - accesses both layoutDB and wordsDB
- `getPageForWord(_:)` - accesses wordsDB
- `getAllWords()` - accesses wordsDB (if method is kept)
- Any other public methods that access database connections

**Example Pattern:**

```swift
public func getLinesForPage(_ pageNumber: Int) -> [MushafLine] {
    return dbQueue.sync {
        // ... existing implementation (all current code goes inside this block)
    }
}

public func getWords(from firstId: Int, to lastId: Int) -> [QuranWord] {
    return dbQueue.sync {
        // ... existing implementation (all current code goes inside this block)
    }
}
```

### 3. Do NOT Touch MushafCache

The MushafCache changes from commit c585b08 are CORRECT. Do NOT modify MushafCache.swift. The issue is entirely in MushafDatabase.swift missing thread safety.

---

## Requirements Document Updated

The requirements document (`.lifecycle/remove-word-caching/requirements.md`) has been updated to reflect the correct thread safety implementation:

- Section 2 "MushafDatabase.swift Modifications" now specifies CRITICAL CHANGES REQUIRED
- Edge Cases section clarifies SQLite is NOT thread-safe by default
- Success Criteria updated to require runtime verification
- Testing Requirements updated to require checking runtime logs
- Notes for Implementation section now has detailed thread safety pattern

Please review the updated requirements document before implementing.

---

## Definition of Done

- [ ] `dbQueue` property added to MushafDatabase
- [ ] All public database methods wrapped with `dbQueue.sync { }`
- [ ] Build succeeds with no errors or warnings
- [ ] Runtime logs show ZERO SQLite multi-threading errors when running on device
- [ ] App launches successfully
- [ ] Basic smoke test: Navigate through a few pages without crashes

**Verification Method:**
1. Build and run on device (not simulator)
2. Launch app
3. Navigate through several pages
4. Check Xcode runtime logs for SQLite errors
5. Logs MUST show zero "illegal multi-threaded access to database connection" errors

---

## Important Notes

**Why Serial Queue (Not Alternatives):**
- **Serial DispatchQueue (chosen approach):** Simple, guarantees thread safety, minimal code changes
- **SQLITE_OPEN_FULLMUTEX:** Would require changing sqlite3_open to sqlite3_open_v2, less Swift-idiomatic
- **Thread-local connections:** Complex, overkill for read-only databases

**Performance Impact:**
- Serializing database access may have minor performance impact
- However, database operations are already fast (proven during testing)
- Thread safety correctness is more important than micro-optimization

**Previous Implementation Status:**
- Commit c585b08 is CORRECT for MushafCache changes
- The only issue is the missing thread safety in MushafDatabase
- This is a targeted fix, not a redesign

---

## Testing After Fix

After implementing thread safety in MushafDatabase:

1. Build and run on device
2. Monitor runtime logs during app launch and navigation
3. Verify ZERO SQLite multi-threading errors
4. If clean, the fix is ready for code review

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
