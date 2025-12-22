# Remaining Work for swift-glob

This document summarizes the remaining issues, missing features, and context for continuing development on the swift-glob library.

## Current Status

- **103 tests pass** with **14 known issues** (tests wrapped in `withKnownIssue`)
- Core glob matching is fully functional
- ksh-style pattern lists (`@()`, `*()`, `+()`, `?()`, `!()`) are implemented with proper backtracking
- Brace expansion (`{a,b,c}`) is implemented and working
- VSCode compatibility is fully implemented
- Equivalence classes (`[[=a=]]`) are implemented using Unicode NFD decomposition

## Test Suite Breakdown

| Test Suite | Passing | Known Issues | Notes |
|------------|---------|--------------|-------|
| FNMatchTests | 64 | 12 | POSIX fnmatch compatibility (locale-dependent ranges) |
| VSCodeTests | 15 | 0 | Full VSCode compatibility |
| FishShellTests | varies | 2 | Symlink/recursive glob edge cases |
| Other tests | all pass | 0 | Core functionality works |

---

## Remaining Known Issues

### 1. Locale-Dependent Character Ranges

**Priority: Low** | **Effort: High**

In some locales (e.g., German `de_DE`), character ranges like `[a-z]` should include accented characters like ä, ö, ü because of locale-specific collation order.

**Current behavior:** Character ranges use Unicode scalar comparison, which doesn't include accented characters in `[a-z]`.

**Affected tests:** 12 tests in FNMatchTests:
- 6 in `character_vs_bytes()` - German umlauts in `[a-z]` and `[A-Z]` ranges
- 6 in `multibyte_character_set()` - Same issue in UTF-8 locale

**Implementation challenges:**
- Requires locale-aware collation for range comparisons
- No standard Swift API for locale-aware character ordering
- Would need platform-specific implementation

---

### 2. Symlink Handling in Search

**Priority: Medium** | **Effort: Medium**

The file search functionality has edge cases with symlinks:

1. **Symlinks not descended independently** - When the same directory is reachable via multiple symlinks, only one path is explored.

2. **Recursive glob boundary matching** - Pattern `**a2/**` should match `dir_a1/dir_a2/dir_a3` but currently includes extra results (`dir_a1/dir_a2/` itself). This is a semantic difference from Fish shell where trailing `/**` requires at least one component, vs VSCode where it can match empty.

**Affected tests:** 2 FishShellTests

**Files to modify:**
- `Sources/Glob/GlobSearch.swift`

**Note:** The `**a2/**` issue cannot be easily fixed without breaking VSCode compatibility, which expects `**/foo/**` to match `bar/foo`.

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

- **Equivalence classes** - Full support for `[[=a=]]` syntax using Unicode NFD decomposition to match accented characters (e.g., `[[=a=]]` matches 'a', 'á', 'à', 'ä', 'â', etc.)
- **Unclosed bracket handling** - Added `unclosedBracketBehavior` option; in fnmatch mode, unclosed `[` is treated as a literal character
- **VSCode full compatibility** - All VSCode tests pass:
  - Windows path separator support (`\` treated as path separator in input)
  - Bracket expressions cannot match path separators (`foo[/]bar` doesn't match `foo/bar`)
  - Both `!` and `^` supported for range negation
- **Brace expansion** - Added `{a,b,c}` syntax support for VSCode compatibility
- **Pattern list backtracking** - Fixed complex nested patterns like `@(foo|f|fo)*(f|of+(o))`
- **Collating symbols** - Added `[.X.]` syntax support
- **Named character classes** - Full support for `[:alpha:]`, `[:digit:]`, etc.
