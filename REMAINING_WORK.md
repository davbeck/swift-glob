# Remaining Work for swift-glob

This document summarizes the remaining issues, missing features, and context for continuing development on the swift-glob library.

## Current Status

- **103 tests pass** with **1 known issue** (tests wrapped in `withKnownIssue`)
- Core glob matching is fully functional
- ksh-style pattern lists (`@()`, `*()`, `+()`, `?()`, `!()`) are implemented with proper backtracking
- Brace expansion (`{a,b,c}`) is implemented and working
- VSCode compatibility is fully implemented
- Equivalence classes (`[[=a=]]`) are implemented using Unicode NFD decomposition
- Trailing `/**` behavior is configurable (Fish shell vs VSCode semantics)
- Diacritic-insensitive character ranges available via `diacriticInsensitiveRanges` option

## Test Suite Breakdown

| Test Suite | Passing | Known Issues | Notes |
|------------|---------|--------------|-------|
| FNMatchTests | 76 | 0 | POSIX fnmatch compatibility (locale-like ranges via option) |
| VSCodeTests | 15 | 0 | Full VSCode compatibility |
| FishShellTests | varies | 1 | Symlink edge case |
| Other tests | all pass | 0 | Core functionality works |

---

## Remaining Known Issues

### 1. Symlink Handling in Search

**Priority: Medium** | **Effort: Medium**

The file search functionality has an edge case with symlinks:

**Symlinks not descended independently** - When the same directory is reachable via multiple symlinks, only one path is explored.

**Affected tests:** 1 FishShellTests (`symlinksAreDescendedIntoIndependently`)

**Files to modify:**
- `Sources/Glob/GlobSearch.swift`

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

- **Diacritic-insensitive character ranges** - Added `diacriticInsensitiveRanges` option to enable locale-like behavior for character ranges. When enabled, `[a-z]` matches accented characters like ä, ö, ü because they are compared as their base characters. Available in `.fnmatch()` preset via the `diacriticInsensitiveRanges` parameter.
- **Trailing path wildcard control** - Added `trailingPathWildcardRequiresComponent` option to control whether trailing `/**` patterns require at least one path component (Fish shell behavior) or can match empty (VSCode behavior)
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
