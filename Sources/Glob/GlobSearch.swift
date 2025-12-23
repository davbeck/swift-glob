public import struct Foundation.URL
public import struct Foundation.URLResourceKey
public import class Foundation.FileManager
import struct ObjectiveC.ObjCBool

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
	includingPropertiesForKeys keys: [URLResourceKey] = []
) -> AsyncThrowingStream<URL, any Error> {
	search(
		directory: baseURL,
		matching: { _, relativePath in
			for pattern in exclude {
				if pattern.match(relativePath) {
					return .init(matches: false, skipDescendents: true)
				}
			}

			if !include.isEmpty {
				guard include.contains(where: { $0.match(relativePath) }) else {
					// for patterns like `**/*.swift`, parent folders won't be matched but we don't want to skip those folder's descendants or we won't find the files that do match
					return .init(matches: false, skipDescendents: false)
				}
			}

			return .init(matches: true, skipDescendents: false)
		},
		includingPropertiesForKeys: keys
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
	includingPropertiesForKeys keys: [URLResourceKey] = []
) -> AsyncThrowingStream<URL, any Error> {
	AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
		let task = Task {
			do {
				// Track visited directories per exploration branch to detect symlink loops
				// Each branch tracks canonical paths it has visited on its way to the current location
				// This allows symlinks from different paths to be explored independently
				@Sendable func enumerate(
					directory: URL,
					relativePath relativeDirectoryPath: String,
					visitedOnPath: Set<String>
				) async throws {
					// Use path-based enumeration which works correctly with symlinks
					// The URL-based contentsOfDirectory(at:) fails on symlinks to directories
					let contentNames = try FileManager.default.contentsOfDirectory(atPath: directory.path)

					try await withThrowingTaskGroup(of: Void.self) { group in
						for name in contentNames {
							let url = directory.appendingPathComponent(name)

							// Fetch requested resource keys for the URL
							if !keys.isEmpty {
								_ = try? url.resourceValues(forKeys: Set(keys))
							}

							// Use fileExists to correctly detect if symlinks point to directories
							// resourceValues.isDirectory returns false for symlinks even when they point to directories
							var isDir: ObjCBool = false
							let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
							let isDirectory = exists && isDir.boolValue

							var relativePath = relativeDirectoryPath + name
							if isDirectory {
								relativePath += "/"
							}

							let matchResult = try matching(url, relativePath)

							if matchResult.matches {
								continuation.yield(url)
							}

							guard !matchResult.skipDescendents else { continue }

							if isDirectory {
								// Check if this is a symlink loop before descending
								// We use the resolved path to detect loops within this branch
								let resolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
								guard !visitedOnPath.contains(resolvedPath) else {
									// Already visited this directory on this path (symlink loop), skip
									continue
								}

								var newVisited = visitedOnPath
								newVisited.insert(resolvedPath)

								group.addTask {
									try await enumerate(
										directory: url,
										relativePath: relativePath,
										visitedOnPath: newVisited
									)
								}
							}
						}

						try await group.waitForAll()
					}
				}

				// Start with the base directory in the visited set
				let basePath = baseURL.resolvingSymlinksInPath().standardizedFileURL.path
				try await enumerate(directory: baseURL, relativePath: "", visitedOnPath: [basePath])

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
