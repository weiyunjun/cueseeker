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
    "cueseeker://search?q=%ZZ"
])
func urlSchemeCommandRejectsInvalidInput(_ urlString: String) {
    #expect(URLSchemeCommand(urlString: urlString) == nil)
}
