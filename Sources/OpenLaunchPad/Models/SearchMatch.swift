import Foundation

/// How well a name matches a search query, best first.
enum SearchMatch: Int, Comparable, Sendable {
    case exact
    case prefix
    case wordPrefix
    case substring

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    init?(_ text: String, query: String) {
        guard let range = text.range(of: query, options: Self.options) else { return nil }
        if range.lowerBound == text.startIndex {
            self = range.upperBound == text.endIndex ? .exact : .prefix
            return
        }

        var startsWord = false
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, word, _, stop in
            if text.range(of: query, options: Self.options.union(.anchored), range: word.lowerBound..<text.endIndex) != nil {
                startsWord = true
                stop = true
            }
        }
        self = startsWord ? .wordPrefix : .substring
    }

    static func < (lhs: SearchMatch, rhs: SearchMatch) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
