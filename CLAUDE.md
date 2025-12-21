# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a single test by name (Swift Testing uses function names, not test prefixes)
swift test --filter PatternTests/constantPattern

# Run tests matching a pattern
swift test --filter FNMatchTests
```

## Architecture

This is a Swift Package providing glob pattern matching functionality. The main module is `Glob`.

### Core Components

**Pattern** (`Sources/Glob/Pattern.swift`): The main public type representing a parsed glob pattern. Contains:
- `Section` enum: The individual matching units (wildcards, constants, character classes, pattern lists)
- `CharacterClass` enum: For bracket expressions like `[a-z]` or named classes like `[:alpha:]`
- `options`: Configuration for parsing and matching behavior

**Parser** (`Sources/Glob/Pattern+Parser.swift`): Converts pattern strings into `Section` arrays using a token-based approach. Handles escaping, bracket expressions, and ksh-style pattern lists.

**Match** (`Sources/Glob/Pattern+Match.swift`): Implements pattern matching against strings. Uses an iterative approach with bounded recursion (only recurses for wildcards) to avoid stack overflow on long inputs.

**Options** (`Sources/Glob/Pattern+Options.swift`): Configures parsing and matching behavior. Includes presets for different implementations:
- `.default`: Feature-rich defaults with `**` support
- `.posix()`: POSIX glob behavior
- `.fnmatch(flags:)`: Match C fnmatch behavior with flag support
- `.vscode`: VSCode glob behavior
- `.go`: Go filepath.Match behavior

**Search** (`Sources/Glob/GlobSearch.swift`): Async file system search using `AsyncThrowingStream`. Searches directories in parallel using Swift concurrency.

### Key Design Decisions

- Wildcards: `*` matches within path components, `**` matches across path separators (when `supportsPathLevelWildcards` is enabled)
- Pattern parsing is separate from matching, allowing patterns to be reused
- Matching is designed to handle arbitrarily long input strings without stack overflow
- The `FNMDefinitions` target provides C fnmatch flag constants for interop

## Testing

Tests use Swift Testing framework (not XCTest). Tests are in `Tests/GlobTests/`. Key test files:
- `PatternTests.swift`: Core pattern matching tests
- `SearchTests.swift`: File system search tests
- `CompatibilityTests/`: Tests comparing behavior against other implementations (fnmatch, VSCode, Go, Fish shell)
- `FNMatchTests.swift`: Comprehensive compatibility tests against C fnmatch (many are wrapped in `withKnownIssue`)

When fixing compatibility issues, add or update tests in the appropriate compatibility test file. Always run the full test suite before committing.
