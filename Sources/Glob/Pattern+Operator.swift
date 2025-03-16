public extension Pattern {
	static func ~= (lhs: Pattern, rhs: some StringProtocol) -> Bool {
		lhs.match(rhs)
	}
}
