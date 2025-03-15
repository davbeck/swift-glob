import Testing

@testable import Glob

struct StressTest {
	@Test func longSearchStrings() async throws {
		let glob = try Glob.Pattern("*/A*")
		_ = glob.match(String(repeating: "a", count: 9999))
	}
}
