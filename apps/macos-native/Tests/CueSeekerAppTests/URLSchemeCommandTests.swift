import Testing
@testable import CueSeekerApp

@Test
func urlSchemeCommandParsesEncodedSearchKeyword() {
    #expect(
        URLSchemeCommand(urlString: "cueseeker://search?q=%E5%A4%A7%E4%B8%88%E5%A4%AB")
            == .search(keyword: "大丈夫")
    )
}

@Test
func urlSchemeCommandTrimsKeywordAndAcceptsCaseInsensitiveRoute() {
    #expect(
        URLSchemeCommand(urlString: "CUESEEKER://SEARCH/?q=%20hello%20")
            == .search(keyword: "hello")
    )
}

@Test
func urlSchemeCommandParsesPositiveCueID() {
    #expect(
        URLSchemeCommand(urlString: "cueseeker://cue?id=123456")
            == .cue(id: 123_456)
    )
    #expect(
        URLSchemeCommand(urlString: "CUESEEKER://CUE/?id=%31")
            == .cue(id: 1)
    )
}

@Test(arguments: [
    "https://search?q=hello",
    "cueseeker://play?q=hello",
    "cueseeker://search",
    "cueseeker://search?q=",
    "cueseeker://search?q=%20%0A",
    "cueseeker://search?q=one&q=two",
    "cueseeker://search?q=hello&scope=all",
    "cueseeker://user@search?q=hello",
    "cueseeker://search:42?q=hello",
    "cueseeker://search/path?q=hello",
    "cueseeker://search?q=hello#fragment",
    "cueseeker://search?q=%ZZ",
    "cueseeker://cue",
    "cueseeker://cue?id=",
    "cueseeker://cue?id=0",
    "cueseeker://cue?id=-1",
    "cueseeker://cue?id=+1",
    "cueseeker://cue?id=%201",
    "cueseeker://cue?id=1.0",
    "cueseeker://cue?id=9223372036854775808",
    "cueseeker://cue?id=1&id=2",
    "cueseeker://cue?id=1&scope=all",
    "cueseeker://cue/path?id=1",
    "cueseeker://cue?id=1#fragment"
])
func urlSchemeCommandRejectsInvalidInput(_ urlString: String) {
    #expect(URLSchemeCommand(urlString: urlString) == nil)
}
