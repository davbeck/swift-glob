extension Unicode.GeneralCategory {
	var isPrintable: Bool {
		switch self {
		case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber, .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation, .otherPunctuation, .spaceSeparator, .lineSeparator, .paragraphSeparator, .surrogate, .privateUse, .unassigned, .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
			true
		case .control, .format:
			false
		@unknown default:
			true
		}
	}

	/// Returns true if this category represents a combining mark (diacritical marks, accents, etc.)
	var isCombiningMark: Bool {
		switch self {
		case .nonspacingMark, .spacingMark, .enclosingMark:
			true
		default:
			false
		}
	}
}
