# Remaining Work for swift-glob

This document summarizes the remaining issues, missing features, and context for continuing development on the swift-glob library.

## Current Status

- **103 tests pass** with **71 known issues** (tests wrapped in `withKnownIssue`)
- Core glob matching is fully functional
- ksh-style pattern lists (`@()`, `*()`, `+()`, `?()`, `!()`) are implemented with proper backtracking
- Brace expansion (`{a,b,c}`) is implemented and working

## Test Suite Breakdown

| Test Suite | Passing | Known Issues | Notes |
|------------|---------|--------------|-------|
| FNMatchTests | 64 | 54 | POSIX fnmatch compatibility |
| VSCodeTests | 15 | 15 | Windows path separators, bracket edge cases |
| FishShellTests | varies | 2 | Symlink/recursive glob edge cases |
| Other tests | all pass | 0 | Core functionality works |

---

## Missing Features

### 1. Equivalence Classes (`[=a=]`)

**Priority: Low** | **Effort: High**

POSIX equivalence classes match characters that are considered equivalent in the current locale. For example, `[[=a=]]` should match 'a', 'á', 'à', 'ä', 'â', etc.

**Current behavior:** Only matches the literal character (e.g., `[[=a=]]` only matches 'a').

**Implementation challenges:**
- Requires Unicode normalization (NFD decomposition)
- Locale-dependent behavior
- Platform differences (Apple vs GNU libc)
- No standard Swift API for locale-aware character equivalence

**Possible approaches:**
1. **Simple approach:** Expand common Latin equivalences statically (a=áàäâã, etc.)
2. **Full approach:** Use ICU or platform-specific APIs for proper locale support
3. **Document limitation:** Note that equivalence classes only work in C locale

**Affected tests:** 52 tests in FNMatchTests (26 in `multibyte_character_set()`, 26 in `character_vs_bytes()`)

**Files to modify:**
- `Sources/Glob/Pattern.swift` - Modify `CharacterClass` enum
- `Sources/Glob/Pattern+Parser.swift` - Already parses `[=X=]` syntax
- `Sources/Glob/Pattern+Match.swift` - Modify matching logic

---

### 2. Symlink Handling in Search

**Priority: Medium** | **Effort: Low**

The file search functionality has edge cases with symlinks:

1. **Symlinks not descended independently** - When the same directory is reachable via multiple symlinks, only one path is explored.

2. **Recursive glob boundary matching** - Pattern `**a2/**` should match `dir_a1/dir_a2/dir_a3` but currently includes extra results.

**Affected tests:** 2 FishShellTests

**Files to modify:**
- `Sources/Glob/GlobSearch.swift`

---

## Known Platform Differences

### Apple fnmatch vs POSIX

2 tests in `b_6_031_c()` fail due to Apple's fnmatch implementation differing from POSIX:

```swift
// Pattern: "\\/[" (escaped slash followed by unclosed bracket)
// POSIX says: should match "/["
// Apple says: returns error
```

**Resolution:** These are documented as known issues since they reflect Apple's behavior, not bugs in our code.

---

## Architecture Notes

### Key Files

| File | Purpose |
|------|---------|
| `Pattern.swift` | Main `Pattern` type with `Section` and `CharacterClass` enums |
| `Pattern+Parser.swift` | Token-based parser converting strings to sections |
| `Pattern+Match.swift` | Matching logic with backtracking support |
| `Pattern+Options.swift` | Configuration options for different glob flavors |
| `GlobSearch.swift` | Async file system search |
| `InvalidPattern.swift` | Error types for parsing failures |

### Pattern Matching Flow

1. **Parse:** `Pattern+Parser.swift` converts pattern string → `[Section]`
2. **Match:** `Pattern+Match.swift` matches sections against input string
3. **Backtracking:** For pattern lists, `allPossiblePrefixMatches()` generates all possible match lengths

### Key Design Decisions

- **Iterative matching:** Uses a loop instead of recursion for fixed-length sections to avoid stack overflow on long inputs
- **Bounded recursion:** Only recurses for wildcards (bounded by pattern complexity, not input length)
- **Greedy with backtracking:** Pattern lists try longest match first, then backtrack if needed

---

## Suggested Next Steps

### Quick Wins

1. **Fix VSCode `!` negation** - VSCode uses `!` for negation in ranges but current `.vscode` options use `^`. Simple option change.

2. **Document equivalence class limitation** - Add documentation noting that `[=X=]` only matches the literal character.

### Medium Effort

3. **Windows path separator support** - VSCode tests expect `\` to be treated as a path separator on Windows paths.

### Larger Effort

4. **Locale-aware equivalence classes** - Would require significant work for proper Unicode support.

5. **Symlink handling improvements** - Need to understand the expected behavior better.

---

## Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter FNMatchTests
swift test --filter VSCodeTests

# Run single test
swift test --filter "FNMatchTests/ksh_style_matching"
```

## Recent Changes

- **Brace expansion** - Added `{a,b,c}` syntax support for VSCode compatibility
- **Pattern list backtracking** - Fixed complex nested patterns like `@(foo|f|fo)*(f|of+(o))`
- **Collating symbols** - Added `[.X.]` syntax support
- **Equivalence class parsing** - Added `[=X=]` syntax (literal matching only)
- **Named character classes** - Full support for `[:alpha:]`, `[:digit:]`, etc.
