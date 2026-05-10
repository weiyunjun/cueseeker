namespace CueSeeker.Windows.Core;

internal sealed record SubtitleCueGroup(
    int StartMilliseconds,
    int EndMilliseconds,
    string SearchContent,
    IReadOnlyList<string> CueLines);

internal sealed record SubtitleIndexingFailure(string Path, string Reason);

internal sealed class SubtitleIndexingResult
{
    public int ScannedSubtitleFiles { get; set; }
    public int IndexedSubtitleFiles { get; set; }
    public int IndexedSubtitleEntries { get; set; }
    public int SkippedUnchangedSubtitleFiles { get; set; }
    public int SkippedMissingVideo { get; set; }
    public int SkippedUnreadableSubtitle { get; set; }
    public List<SubtitleIndexingFailure> FailedFiles { get; } = [];
}

internal sealed record SubtitleSearchResult(
    long EntryId,
    string SubtitlePath,
    SubtitleFormat SubtitleFormat,
    string VideoPath,
    string VideoName,
    int StartMilliseconds,
    int EndMilliseconds,
    string Content,
    IReadOnlyList<string> CueLines);

internal sealed record SubtitleSearchFileSummary(
    string SubtitlePath,
    string SubtitleFileName,
    string SubtitleDisplayTitle,
    int MatchCount);

internal sealed record SubtitleSearchPage(
    IReadOnlyList<SubtitleSearchResult> Results,
    int TotalCount,
    IReadOnlyList<SubtitleSearchFileSummary> FileSummaries);

internal sealed record LibraryVideo(
    string VideoPath,
    string VideoName,
    double? Duration,
    string SubtitlePath,
    SubtitleFormat SubtitleFormat);

internal sealed record LibraryVideoPresentation(
    string VideoPath,
    string VideoName,
    double? Duration,
    string SubtitlePath,
    SubtitleFormat SubtitleFormat,
    string DisplayTitle,
    string FileExtension);

internal sealed record LibraryFolderPresentation(
    string FolderPath,
    string FolderTitle,
    IReadOnlyList<LibraryVideoPresentation> Videos);
