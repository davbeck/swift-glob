// XCTExpectFailure is only available on Apple platforms
// https://github.com/apple/swift-corelibs-xctest/issues/438
#if !os(macOS) && !os(iOS) && !os(watchOS) && !os(tvOS)
	func XCTExpectFailure(_ tests: () throws -> Void) rethrows {}
#endif
