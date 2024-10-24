import Foundation

/// The result of a custom matcher for searching directory components
public struct MatchResult {
	/// When true, the url will be added to the output
	var matches: Bool
	/// When true, the descendents of a directory will be skipped entirely
	///
	/// This has no effect if the url is not a directory.
	var skipDescendents: Bool
}

/// Recursively search the contents of a directory, filtering by the provided patterns
///
/// Searching is done asynchronously, with each subdirectory searched in parallel. Results are emitted as they are found.
///
/// The results are returned as they are matched and do not have a consistent order to them. If you need the results sorted, wait for the entire search to complete and then sort the results.
///
/// - Parameters:
///   - baseURL: The directory to search, defaults to the current working directory.
///   - include: When provided, only includes results that match these patterns.
///   - exclude: When provided, ignore results that match these patterns. If a directory matches an exclude pattern, none of it's descendents will be matched.
///   - keys: An array of keys that identify the properties that you want pre-fetched for each returned url. The values for these keys are cached in the corresponding URL objects. You may specify nil for this parameter. For a list of keys you can specify, see [Common File System Resource Keys](https://developer.apple.com/documentation/corefoundation/cfurl/common_file_system_resource_keys).
///   - skipHiddenFiles: When true, hidden files will not be returned.
/// - Returns: An async collection of urls.
public func search(
	directory baseURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
	include: [Pattern] = [],
	exclude: [Pattern] = [],
	includingPropertiesForKeys keys: [URLResourceKey] = [],
	skipHiddenFiles: Bool = true
) -> AsyncThrowingStream<URL, any Error> {
	search(
		directory: baseURL,
		matching: { _, relativePath in
			if !include.isEmpty {
				guard include.contains(where: { $0.match(relativePath) }) else {
					// for patterns like `**/*.swift`, parent folders won't be matched but we don't want to skip those folder's descendents or we won't find the files that do match
					return .init(matches: false, skipDescendents: false)
				}
			}

			for pattern in exclude {
				if pattern.match(relativePath) {
					return .init(matches: false, skipDescendents: true)
				}
			}

			return .init(matches: true, skipDescendents: false)
		},
		includingPropertiesForKeys: keys,
		skipHiddenFiles: skipHiddenFiles
	)
}

/// Recursively search the contents of a directory, filtering by the provided matching closure
///
/// Searching is done asynchronously, with each subdirectory searched in parallel. Results are emitted as they are found.
///
/// The results are returned as they are matched and do not have a consistent order to them. If you need the results sorted, wait for the entire search to complete and then sort the results.
///
/// - Parameters:
///   - baseURL: The directory to search, defaults to the current working directory.
///   - matching: The closure used to filter results. Both the url and the relative path are provided and you can use either one to match against.
///   - keys: An array of keys that identify the properties that you want pre-fetched for each returned url. The values for these keys are cached in the corresponding URL objects. You may specify nil for this parameter. For a list of keys you can specify, see [Common File System Resource Keys](https://developer.apple.com/documentation/corefoundation/cfurl/common_file_system_resource_keys).
///   - skipHiddenFiles: When true, hidden files will not be returned.
/// - Returns: An async collection of urls.
public func search(
	directory baseURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
	matching: @escaping @Sendable (_ url: URL, _ relativePath: String) throws -> MatchResult,
	includingPropertiesForKeys keys: [URLResourceKey] = [],
	skipHiddenFiles: Bool = true
) -> AsyncThrowingStream<URL, any Error> {
	AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
		let task = Task {
			do {
				@Sendable func enumerate(directory: URL, relativePath relativeDirectoryPath: String) async throws {
					do {
						var options: FileManager.DirectoryEnumerationOptions = []
						if skipHiddenFiles {
							options.insert(.skipsHiddenFiles)
                            #if !os(Linux)
                            options.insert(.producesRelativePathURLs)
                            #endif
						}
						let contents = try FileManager.default.contentsOfDirectory(
							at: directory,
							includingPropertiesForKeys: keys + [.isDirectoryKey],
							options: options
						)

						try await withThrowingTaskGroup(of: Void.self) { group in
							for url in contents {
								let relativePath = relativeDirectoryPath + url.lastPathComponent

								let matchResult = try matching(url, relativePath)

								if matchResult.matches {
                                    #if os(Linux)
                                    continuation.yield(url)
                                    #else
                                    if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                                        continuation.yield(directory.appending(path: url.relativePath))
                                    } else {
                                        continuation.yield(directory.appendingPathComponent(url.relativePath))
                                    }
                                    #endif
								}

								guard !matchResult.skipDescendents else { continue }

								let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
								if resourceValues.isDirectory == true {
									group.addTask {
										try await enumerate(directory: url, relativePath: relativePath + "/")
									}
								}
							}

							try await group.waitForAll()
						}
					} catch {
						throw error
					}
				}

				try await enumerate(directory: baseURL, relativePath: "")

				continuation.finish()
			} catch {
				continuation.finish(throwing: error)
			}
		}

		continuation.onTermination = { _ in
			task.cancel()
		}
	}
}
