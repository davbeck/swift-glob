# swift-glob

A native Swift implementation of glob patterns.

## Project goals

- Fast matching against patterns, even as the complexity of a pattern and the length of the path increase.
- Concurrent searching of directory hierarchies.
- Configurable pattern matching behavior. There are lots of different implimentations of glob pattern matching with different features and behavior. Switching to a Swift based library may mean matching existing behavior from other tools.
- Ergonomic API that is accessible to users of varying skill levels and fits in to all types of Swift projects.

In other words, the project seeks to be _the_ glob library for Swift that can be used both in low level tools and in high level apps.
