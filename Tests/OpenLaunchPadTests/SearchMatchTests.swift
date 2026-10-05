import Testing
@testable import OpenLaunchPad

struct SearchMatchTests {
    @Test
    func classifiesWhereTheQueryMatches() {
        #expect(SearchMatch("Safari", query: "safari") == .exact)
        #expect(SearchMatch("Safari", query: "saf") == .prefix)
        #expect(SearchMatch("Visual Studio Code", query: "studio") == .wordPrefix)
        #expect(SearchMatch("Visual Studio Code", query: "studio co") == .wordPrefix)
        #expect(SearchMatch("Gmail", query: "mail") == .substring)
        #expect(SearchMatch("Safari", query: "chrome") == nil)
    }

    @Test
    func findsWordPrefixesInChineseNames() {
        #expect(SearchMatch("系统设置", query: "系统") == .prefix)
        #expect(SearchMatch("系统设置", query: "设置") == .wordPrefix)
    }

    @Test
    func ordersBestMatchFirst() {
        #expect([SearchMatch.substring, .exact, .wordPrefix, .prefix].sorted() == [.exact, .prefix, .wordPrefix, .substring])
    }
}
