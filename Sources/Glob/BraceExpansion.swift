/// Expands brace patterns like `{a,b,c}` into multiple pattern strings.
///
/// For example:
/// - `*.{js,ts}` → `["*.js", "*.ts"]`
/// - `{foo,bar}/baz` → `["foo/baz", "bar/baz"]`
/// - `{a,{b,c}}` → `["a", "b", "c"]`
enum BraceExpansion {
	/// Expands a pattern containing brace syntax into all possible patterns.
	///
	/// - Parameters:
	///   - pattern: The pattern string that may contain brace expansion syntax
	///   - supportsEscapedCharacters: Whether backslash escapes are supported
	/// - Returns: An array of expanded pattern strings. If no braces are found, returns the original pattern.
	static func expand(_ pattern: String, supportsEscapedCharacters: Bool) -> [String] {
		guard let (prefix, alternatives, suffix) = findBraceGroup(in: pattern, supportsEscapedCharacters: supportsEscapedCharacters) else {
			// No brace group found, return the original pattern
			return [pattern]
		}

		// Recursively expand each alternative (to handle nested braces within alternatives)
		// Then recursively expand the suffix (to handle multiple brace groups)
		var results: [String] = []
		for alternative in alternatives {
			let expandedAlternative = expand(alternative, supportsEscapedCharacters: supportsEscapedCharacters)
			for alt in expandedAlternative {
				let combined = prefix + alt + suffix
				let expandedSuffix = expand(combined, supportsEscapedCharacters: supportsEscapedCharacters)
				results.append(contentsOf: expandedSuffix)
			}
		}

		return results
	}

	/// Finds the first top-level brace group in the pattern.
	///
	/// - Parameters:
	///   - pattern: The pattern string to search
	///   - supportsEscapedCharacters: Whether backslash escapes are supported
	/// - Returns: A tuple of (prefix before braces, alternatives inside braces, suffix after braces),
	///            or nil if no valid brace group is found.
	private static func findBraceGroup(
		in pattern: String,
		supportsEscapedCharacters: Bool
	) -> (prefix: String, alternatives: [String], suffix: String)? {
		var index = pattern.startIndex
		var braceStart: String.Index?
		var depth = 0
		var alternatives: [String] = []
		var currentAlternative = ""
		var prefix = ""
		var isEscaped = false

		while index < pattern.endIndex {
			let char = pattern[index]

			if isEscaped {
				if braceStart != nil {
					currentAlternative.append(char)
				} else {
					prefix.append("\\")
					prefix.append(char)
				}
				isEscaped = false
				index = pattern.index(after: index)
				continue
			}

			if supportsEscapedCharacters && char == "\\" {
				isEscaped = true
				index = pattern.index(after: index)
				continue
			}

			if char == "{" {
				if depth == 0 {
					braceStart = index
				} else {
					currentAlternative.append(char)
				}
				depth += 1
			} else if char == "}" {
				depth -= 1
				if depth == 0 {
					// End of top-level brace group
					alternatives.append(currentAlternative)

					// Treat any brace group as expansion (even single alternatives like {html})
					let suffix = String(pattern[pattern.index(after: index)...])
					return (prefix, alternatives, suffix)
				} else if depth < 0 {
					// Unmatched closing brace, treat as literal
					prefix.append(char)
					depth = 0
				} else {
					currentAlternative.append(char)
				}
			} else if char == "," && depth == 1 {
				// Comma at top level of braces separates alternatives
				alternatives.append(currentAlternative)
				currentAlternative = ""
			} else if braceStart != nil {
				currentAlternative.append(char)
			} else {
				prefix.append(char)
			}

			index = pattern.index(after: index)
		}

		// If we have an unclosed brace, treat everything as literal
		if braceStart != nil {
			return nil
		}

		return nil
	}
}
