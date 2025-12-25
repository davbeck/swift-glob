# Glob Pattern Features

This document describes the glob pattern features supported by swift-glob, including which implementations support each feature and the options to enable or disable them.

## Table of Contents

- [Wildcards](#wildcards)
- [Bracket Expressions](#bracket-expressions)
- [Pattern Lists (Extended Glob)](#pattern-lists-extended-glob)
- [Brace Expansion](#brace-expansion)
- [Escape Characters](#escape-characters)
- [Implementation Comparison](#implementation-comparison)
- [Options Reference](#options-reference)
- [Unsupported Features](#unsupported-features)

---

## Wildcards

### Component Wildcard (`*`)

Matches zero or more characters within a single path component. Does **not** match path separators.

```swift
"*.swift"      // matches "file.swift", not "dir/file.swift"
"src/*.ts"     // matches "src/app.ts", not "src/lib/app.ts"
```

**Support:** All implementations

### Path-Level Wildcard (`**`)

Matches zero or more path components, crossing path separators. Can match zero components, so `foo/**/bar` matches both `foo/bar` and `foo/x/y/bar`.

```swift
"**/*.swift"     // matches "file.swift", "src/file.swift", "src/lib/file.swift"
"src/**/test.ts" // matches "src/test.ts", "src/a/b/c/test.ts"
```

**Support:**

| Implementation | Supported | Notes |
|----------------|-----------|-------|
| Default | Yes | |
| POSIX | No | Not part of POSIX standard |
| fnmatch | No | Not part of fnmatch |
| VSCode | Yes | |
| Go | No | |
| Bash | Optional | Requires `shopt -s globstar` |
| Zsh | Yes | |

**Option:** `supportsPathLevelWildcards: Bool`

### Single Character Match (`?`)

Matches exactly one character, but does **not** match path separators.

```swift
"file?.txt"    // matches "file1.txt", "fileA.txt", not "file10.txt"
"???.swift"    // matches any 3-character filename with .swift extension
```

**Support:** All implementations

---

## Bracket Expressions

Bracket expressions match a single character from a defined set.

### Simple Character Sets

```swift
"[abc]"        // matches 'a', 'b', or 'c'
"[a-z]"        // matches any lowercase letter
"[A-Za-z0-9]"  // matches any alphanumeric character
```

### Negated Character Sets

Matches any character **not** in the set.

```swift
"[!abc]"       // matches any character except 'a', 'b', 'c'
"[^0-9]"       // matches any non-digit (when ^ negation is enabled)
```

**Option:** `rangeNegationCharacter`
- `.exclamationMark` - Only `!` for negation (POSIX, fnmatch)
- `.caret` - Only `^` for negation (Go)
- `.both` - Either `!` or `^` (VSCode, Bash, Zsh)

### Named POSIX Character Classes

```swift
"[[:alpha:]]"    // alphabetic characters (A-Z, a-z)
"[[:alnum:]]"    // alphanumeric (letters and digits)
"[[:digit:]]"    // digits (0-9)
"[[:lower:]]"    // lowercase letters
"[[:upper:]]"    // uppercase letters
"[[:space:]]"    // whitespace characters
"[[:blank:]]"    // space and tab only
"[[:xdigit:]]"   // hexadecimal digits (0-9, A-F, a-f)
"[[:punct:]]"    // punctuation characters
"[[:graph:]]"    // printable characters except space
"[[:print:]]"    // all printable characters
"[[:cntrl:]]"    // control characters
```

**Support:** All implementations (part of POSIX standard)

### Collating Symbols (POSIX)

```swift
"[[.a.]]"        // matches 'a'
"[a-[.x.]]"      // range from 'a' to 'x'
```

In the C locale (and this library), collating symbols match single characters only.

### Equivalence Classes (POSIX)

Matches characters that are equivalent after removing diacritics.

```swift
"[[=a=]]"        // matches 'a', 'á', 'à', 'ä', 'â', etc.
"[a-[=z=]]"      // range using equivalence class bound
```

### Edge Case Handling

**Empty Bracket Expression `[]`**

**Option:** `emptyRangeBehavior`
- `.error` - Throws a parsing error (Default, Go)
- `.allow` - Empty set, matches nothing
- `.treatClosingBracketAsCharacter` - Treats `]` as first character in set (fnmatch, VSCode, Bash)

**Unclosed Bracket Expression `[abc`**

**Option:** `unclosedBracketBehavior`
- `.error` - Throws a parsing error (Default, Go)
- `.treatAsLiteral` - Treats `[` as literal character (fnmatch, Bash)

**Hyphen at Start/End `[-abc]` or `[abc-]`**

**Option:** `supportsRangeSeparatorAtBeginningAndEnd: Bool`
- `true` - Hyphen at edges is treated as literal (Default, most implementations)
- `false` - Throws an error (Go)

**Bracket Expressions and Path Separators**

**Option:** `bracketExpressionsCannotMatchPathSeparators: Bool`
- `false` - Bracket expressions can match `/` (Default, POSIX)
- `true` - Bracket expressions never match path separators (VSCode)

---

## Pattern Lists (Extended Glob)

KSH-style pattern lists provide extended pattern matching capabilities.

### Zero or One `?(pattern|pattern)`

Matches zero or one occurrence of any alternative.

```swift
"?(foo)"         // matches "" or "foo"
"?(foo|bar).txt" // matches ".txt", "foo.txt", or "bar.txt"
```

### Zero or More `*(pattern|pattern)`

Matches zero or more occurrences of any alternative.

```swift
"*(ab)"          // matches "", "ab", "abab", "ababab", ...
"*(foo|bar)"     // matches "", "foo", "bar", "foobar", "barfoobar", ...
```

### One or More `+(pattern|pattern)`

Matches one or more occurrences of any alternative.

```swift
"+(ab)"          // matches "ab", "abab", "ababab", ... (not "")
"+(foo|bar)"     // matches "foo", "bar", "foobar", ... (not "")
```

### Exactly One `@(pattern|pattern)`

Matches exactly one of the alternatives.

```swift
"@(foo|bar)"     // matches "foo" or "bar" only
"@(*.js|*.ts)"   // matches files ending in .js or .ts
```

### Negation `!(pattern|pattern)`

Matches anything **except** the given patterns.

```swift
"!(*.txt)"       // matches any string that doesn't end in .txt
"!(foo|bar)"     // matches anything except "foo" or "bar"
```

### Nesting

Pattern lists can be nested arbitrarily.

```swift
"@(foo|*(bar|@(baz)))"  // complex nested pattern
"@(src|lib)/**/*.ts"    // practical nested example
```

**Support:**

| Implementation | Supported | Notes |
|----------------|-----------|-------|
| Default | Yes | |
| POSIX | No | Not part of POSIX standard |
| fnmatch | Optional | FNM_EXTMATCH flag |
| VSCode | No | Uses brace expansion instead |
| Go | No | |
| Bash | Yes | Requires `shopt -s extglob` |
| Zsh | Yes | Built-in |

**Option:** `supportsPatternLists: Bool`

---

## Brace Expansion

Brace expansion allows specifying alternatives within a pattern using `{a,b,c}` syntax.

```swift
"*.{js,ts}"           // matches "*.js" or "*.ts"
"{src,lib}/*.swift"   // matches "src/*.swift" or "lib/*.swift"
"{a,b}/{x,y}"         // matches "a/x", "a/y", "b/x", or "b/y"
"{a,{b,c}}"           // matches "a", "b", or "c" (nested)
```

A string matches if it matches **any** of the alternatives.

Internally, brace expansion is parsed as a `PatternListStyle.one` (equivalent to `@()`).

**Support:**

| Implementation | Supported | Notes |
|----------------|-----------|-------|
| Default | No | Must be explicitly enabled |
| POSIX | No | |
| fnmatch | No | |
| VSCode | Yes | Primary alternative mechanism |
| Go | No | |
| Bash | Yes | Always enabled in interactive mode |
| Zsh | Yes | Always enabled |

**Option:** `supportsBraceExpansion: Bool`

---

## Escape Characters

When enabled, the backslash character escapes the following character, treating it literally.

```swift
"\\*"            // matches literal "*"
"\\?"            // matches literal "?"
"\\["            // matches literal "["
"\\\\"           // matches literal "\"
"file\\[1\\].txt" // matches "file[1].txt"
```

**Support:**

| Implementation | Supported | Notes |
|----------------|-----------|-------|
| Default | Yes | |
| POSIX | Yes | |
| fnmatch | Optional | Disabled with FNM_NOESCAPE |
| VSCode | Yes | |
| Go | Yes | |
| Bash | Yes | |
| Zsh | Yes | |

**Option:** `supportsEscapedCharacters: Bool`

---

## Path-Related Features

### Path Separator

The character used as a path separator (typically `/`). Path separators have special meaning:
- `*` and `?` do not match across them
- `**` crosses them (when enabled)
- Leading periods are checked after separators

**Option:** `pathSeparator: Character?`
- `"/"` - Unix-style (Default)
- `nil` - No path separator (pattern treats all characters equally)

**Option:** `additionalPathSeparators: Set<Character>`
- `[]` - Default
- `["\\"]` - Also treat `\` as path separator (VSCode, Windows)

### Leading Period (Hidden Files)

When enabled, wildcards do not match a leading `.` character (hidden files on Unix).

```swift
// With requiresExplicitLeadingPeriods = true
"*"              // does NOT match ".hidden"
".*"             // matches ".hidden"
"[.]hidden"      // matches ".hidden"

// With requiresExplicitLeadingPeriods = false
"*"              // matches ".hidden"
```

**Option:** `requiresExplicitLeadingPeriods: Bool`

**Support:**

| Implementation | Default |
|----------------|---------|
| Default | `true` |
| POSIX | `true` |
| fnmatch | `false` (unless FNM_PERIOD) |
| VSCode | `true` |
| Go | `false` |
| Bash | `true` |
| Zsh | `true` |

### Trailing Path Separator

Controls whether a trailing `/` is ignored when matching.

```swift
// With matchesTrailingPathSeparator = true
"foo*"           // matches "foo/"

// With matchesTrailingPathSeparator = false
"foo*"           // does NOT match "foo/" (needs explicit "/")
```

**Option:** `matchesTrailingPathSeparator: Bool`

### Match Leading Directories

Allows patterns to match just the beginning of a path (`FNM_LEADING_DIR` behavior).

```swift
// With matchLeadingDirectories = true
"foo"            // matches "foo/bar/baz"
```

**Option:** `matchLeadingDirectories: Bool`

### Trailing `/**` Behavior

Controls whether trailing `/**` must match at least one path component.

```swift
// With trailingPathWildcardRequiresComponent = true
"foo/**"         // does NOT match "foo" or "foo/" (Fish shell behavior)

// With trailingPathWildcardRequiresComponent = false
"foo/**"         // matches "foo", "foo/", "foo/bar" (VSCode behavior)
```

**Option:** `trailingPathWildcardRequiresComponent: Bool`

---

## Implementation Comparison

| Feature | Default | POSIX | fnmatch | VSCode | Go | Bash | Zsh |
|---------|---------|-------|---------|--------|-----|------|-----|
| `*` wildcard | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| `**` wildcard | Yes | No | No | Yes | No | Optional | Yes |
| `?` wildcard | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Bracket expressions | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Named classes `[:alpha:]` | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Equivalence classes `[=a=]` | Yes | Yes | Yes | No | No | No | No |
| Pattern lists | Yes | No | Optional | No | No | Yes | Yes |
| Brace expansion | No | No | No | Yes | No | Yes | Yes |
| Escape characters | Yes | Yes | Optional | Yes | Yes | Yes | Yes |
| Path separator | `/` | `/` | None | `/` `\` | `/` | `/` | `/` |
| Leading period special | Yes | Yes | Optional | Yes | No | Yes | Yes |
| Negation character | `!` | `!` | `!` | Both | `^` | Both | Both |
| Empty `[]` handling | Error | Error | Literal `]` | Literal `]` | Error | Literal `]` | Error |
| Unclosed `[` handling | Error | Error | Literal | Literal `]` | Error | Literal | Error |

---

## Options Reference

### Using Presets

The library provides presets for common implementations:

```swift
// Full-featured defaults
Pattern("**/*.swift")

// POSIX glob behavior
Pattern("*.txt", options: .posix())

// C fnmatch compatibility
Pattern("*.txt", options: .fnmatch(flags: FNM_PATHNAME | FNM_PERIOD))

// VSCode glob behavior
Pattern("**/*.{js,ts}", options: .vscode)

// Go filepath.Match behavior
Pattern("*.txt", options: .go)

// Bash with extglob
Pattern("@(foo|bar)", options: .bash)

// Bash with globstar
Pattern("**/*.sh", options: .bashGlobstar)

// Zsh behavior
Pattern("**/*.zsh", options: .zsh)
```

### Individual Options

```swift
var options = Pattern.Options()

// Path handling
options.pathSeparator = "/"                              // Path separator character
options.additionalPathSeparators = ["\\"]                // Additional separators
options.supportsPathLevelWildcards = true                // Enable **
options.matchLeadingDirectories = false                  // FNM_LEADING_DIR
options.matchesTrailingPathSeparator = true              // Ignore trailing /
options.trailingPathWildcardRequiresComponent = true     // Trailing /** requires component
options.bracketExpressionsCannotMatchPathSeparators = false  // VSCode behavior

// Character matching
options.requiresExplicitLeadingPeriods = true            // Hidden file handling
options.diacriticInsensitiveRanges = false               // [a-z] matches accented chars

// Bracket expressions
options.emptyRangeBehavior = .error                      // .allow, .treatClosingBracketAsCharacter
options.unclosedBracketBehavior = .error                 // .treatAsLiteral
options.supportsRangeSeparatorAtBeginningAndEnd = true   // Allow [-abc]
options.rangeNegationCharacter = .exclamationMark        // .caret, .both

// Feature flags
options.supportsEscapedCharacters = true                 // Enable \ escaping
options.supportsPatternLists = true                      // Enable @() ?() etc.
options.supportsBraceExpansion = false                   // Enable {a,b,c}
```

---

## Unsupported Features

The following features are **not** supported by swift-glob:

### Zsh Extended Features
- `#` operator for zero or more matches (use `*()` pattern list instead)
- `^` prefix negation operator (use `!()` pattern list instead)
- `~` exclusion operator
- Case-insensitive modifiers `(#i)`, `(#l)`, etc.
- Numeric ranges `<1-100>`
- Glob qualifiers `(.)`, `(/)`, etc.

### Locale-Dependent Behavior
- Full locale collation for character ranges (uses Unicode scalar comparison)
- Multi-character collating symbols (only single characters supported)
- Locale-specific equivalence classes (uses diacritic removal only)
