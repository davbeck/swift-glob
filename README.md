# swift-glob

A native Swift implementation of glob patterns, those patterns used to match and filter files.

## Project goals

- Fast matching against patterns, even as the complexity of a pattern and the length of the path increase.
- Concurrent searching of directory hierarchies and thread safety.
- Configurable pattern matching behavior. There are lots of different implimentations of glob pattern matching with different features and behavior. Switching to a Swift based library may mean matching existing behavior from other tools.
- Ergonomic API that is accessible to users of varying skill levels and fits in to all types of Swift projects.

In other words, the project seeks to be _the_ glob library for Swift that can be used both in low level tools and in high level apps.

By creating a glob matching implimentation in native Swift with strict compatibility with existing things like POSIX, it allows tools to be migrated to Swift, behavior to be customized and exteded, and implimentations to be made more performant and concurrent.

## Status

Basic pattern matching and director search is working and in my tests searching a large hiearchy of files and folders with about 10 exclude patterns runs very quickly. However there are still some features missing like [grouping](https://github.com/davbeck/swift-glob/issues/1). The [tests to match `fnmatch` behavior](https://github.com/davbeck/swift-glob/pull/5) has 588 failing tests as of this writing.

A 1.0.0 release is dependent on compatibility tests with `fnmatch` passing.

## Usage

### Searching files

`search` performs a recursive enumeration of all files in the given directory, filtering them by the include and exclude patterns.

```swift
let output = try await Glob.search(
  directory: searchURL,
  include: [
    Glob.Pattern("**/*.swift"),
  ],
  exclude: [
    Glob.Pattern("**/*.generated.swift"),
  ],
  skipHiddenFiles: true
)

// output is an async sequence
// you can iterate it as files are found:
for try await url in output {
  // do something with the file
}
// or convert the results to an array and wait for the search to finish:
output.reduce(into: [URL]()) { $0.append($1) }
```

There is also a version of search that takes a `matching` closure instead of include and exclude patterns if you need more control over how files are matched.

### Matching file names (and other strings)

You can use a pattern directly to match against a string.

```swift
let pattern = try Glob.Pattern("Hello *!")
pattern.match("Hello World!") // returns true
```

### Configuration

`Glob.Pattern` takes an `Options` argument that can be used to customize how the pattern is parsed and how matches are evaluated. Several configurations are provided such as `Glob.Pattern.Options.posix()` that attempt to match the behavior of other glob algorithms.

```swift
let pattern = try Glob.Pattern("**/*.swift", options: .posix())
pattern.match("a/b/c/d/file.swift") // returns false because posix glob patters don't support ** (path level wildcard) matching.
```

The default configuration tries to use sensible defaults that most developers would expect with as many features enabled as possible. You can customize either the default or any configuration by creating a mutable copy:

```swift
var options = Glob.Pattern.Options.default
options.pathSeparator = #"\"# // use windows path separator
```

## Contributing

Contributions are highly encouraged. Here are some ways you can contribute:

**Writing code:** if you see a missing piece of functionality or bug, I welcome pull requests. It's best to open an issue first to make sure you don't waste any effort in case what you are building is already being worked on or going in a different direction. Even if you aren't up to writing an implimentation, creating a PR with a failing test goes a long way towards getting something off the ground.

There are already a good number of failing tests (wrapped in `XCTExpectFailure`). These would be a good place to start.

**Improving documentation:** if you find something that isn't clear it's likely that other people would find it unclear as well.

**Submitting issues:** if you find a bug or an inconsistentcy in how patterns are matched, pleas file an issue.

If you have any questions, either open an issue on Github or reach out on [Mastodon](https://tnku.co/@david).

By participating in this project you agree to abide by the [Contributor Code of Conduct](CODE_OF_CONDUCT.md).
