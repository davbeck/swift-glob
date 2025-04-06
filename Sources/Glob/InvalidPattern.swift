import Foundation

public struct InvalidPatternError: Error {
	/// The pattern that was being parsed
	public var pattern: String
	/// The location in the pattern where the error was encountered
	public var location: String.Index

	/// The reason that parsing failed
	public var underlyingError: PatternParsingError
}

public enum PatternParsingError: Error {
	/// The range contained a lower bound button not an upper bound (ie "[a-]")
	case rangeNotClosed
	/// The range was ended without any content (ie "[]")
	case rangeIsEmpty
	/// The range included a separator but no lower bound (ie "[-c]")
	case rangeMissingBounds

	/// An escape was started without an actual escaped character because the escape was at the end of the pattern
	case invalidEscapeCharacter

	/// A character class (like `[:alnum:]`) was used with an unrecognized name
	case invalidNamedCharacterClass(String)

	case patternListNotClosed

	case emptyPatternList
	
	case multiCharacterCollatingElementsNotSupported
}
