import Foundation
import Testing
import CueSeekerCore

@Test
func semanticVersionParsesOptionalPrefixAndComparesNumerically() throws {
    let base = try #require(GitHubReleaseUpdateChecker.SemanticVersion(string: "0.1.0"))
    let lowerPrefixed = try #require(GitHubReleaseUpdateChecker.SemanticVersion(string: "v0.1.0"))
    let upperPrefixed = try #require(GitHubReleaseUpdateChecker.SemanticVersion(string: " V0.2.0 "))
    let doubleDigitMinor = try #require(GitHubReleaseUpdateChecker.SemanticVersion(string: "0.10.0"))
    let twoSegment = try #require(GitHubReleaseUpdateChecker.SemanticVersion(string: "0.1"))
    let twoSegmentHigher = try #require(GitHubReleaseUpdateChecker.SemanticVersion(string: "0.1.1"))

    #expect(base == lowerPrefixed)
    #expect(base == twoSegment)
    #expect(upperPrefixed > base)
    #expect(doubleDigitMinor > upperPrefixed)
    #expect(twoSegmentHigher > twoSegment)
    #expect(upperPrefixed.normalizedTagString == "v0.2.0")
    #expect(GitHubReleaseUpdateChecker.SemanticVersion(string: "0.3.0")?.normalizedTagString == "v0.3.0")
}

@Test
func semanticVersionRejectsMalformedStrings() {
    let invalidInputs = ["", "   ", "v", "V", "1..0", "1.2.", ".1.2", "1.2.a", "v1.0.0-beta.1"]
    for input in invalidInputs {
        #expect(GitHubReleaseUpdateChecker.SemanticVersion(string: input) == nil)
    }
}

@Test
func releaseResponseTreats404DraftAndPrereleaseAsUpToDate() {
    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 404,
            data: Data("{\"message\":\"Not Found\"}".utf8),
            currentVersion: "0.1.0"
        ) == .upToDate
    )

    let draftPayload = Data("""
    {
      "tag_name": "v9.9.9",
      "html_url": "https://github.com/weiyunjun/cueseeker/releases/tag/v9.9.9",
      "draft": true,
      "prerelease": false
    }
    """.utf8)
    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 200,
            data: draftPayload,
            currentVersion: "0.1.0"
        ) == .upToDate
    )

    let prereleasePayload = Data("""
    {
      "tag_name": "v9.9.9",
      "html_url": "https://github.com/weiyunjun/cueseeker/releases/tag/v9.9.9",
      "draft": false,
      "prerelease": true
    }
    """.utf8)
    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 200,
            data: prereleasePayload,
            currentVersion: "0.1.0"
        ) == .upToDate
    )
}

@Test
func releaseResponseDistinguishesEqualOlderHigherAndInvalidPayloads() {
    let sameVersionPayload = Data("""
    {
      "tag_name": "v0.1.0",
      "html_url": "https://github.com/weiyunjun/cueseeker/releases/tag/v0.1.0",
      "draft": false,
      "prerelease": false
    }
    """.utf8)
    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 200,
            data: sameVersionPayload,
            currentVersion: "0.1.0"
        ) == .upToDate
    )

    let olderVersionPayload = Data("""
    {
      "tag_name": "0.0.9",
      "html_url": "https://github.com/weiyunjun/cueseeker/releases/tag/0.0.9",
      "draft": false,
      "prerelease": false
    }
    """.utf8)
    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 200,
            data: olderVersionPayload,
            currentVersion: "0.1.0"
        ) == .upToDate
    )

    let higherVersionPayload = Data("""
    {
      "tag_name": "V0.2.0",
      "html_url": "https://github.com/weiyunjun/cueseeker/releases/tag/v0.2.0",
      "draft": false,
      "prerelease": false
    }
    """.utf8)
    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 200,
            data: higherVersionPayload,
            currentVersion: "0.1.0"
        ) == .updateAvailable(
            version: "v0.2.0",
            releaseURL: URL(string: "https://github.com/weiyunjun/cueseeker/releases/tag/v0.2.0")!
        )
    )

    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 500,
            data: higherVersionPayload,
            currentVersion: "0.1.0"
        ) == .failed
    )

    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 200,
            data: Data("{not-json".utf8),
            currentVersion: "0.1.0"
        ) == .failed
    )

    let missingURLPayload = Data("""
    {
      "tag_name": "v0.2.0",
      "draft": false,
      "prerelease": false
    }
    """.utf8)
    #expect(
        GitHubReleaseUpdateChecker.evaluateResponse(
            statusCode: 200,
            data: missingURLPayload,
            currentVersion: "0.1.0"
        ) == .failed
    )
}
