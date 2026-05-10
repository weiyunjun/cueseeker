using System.Text.RegularExpressions;

namespace CueSeeker.Windows.Core;

internal sealed partial class VideoMatcher
{
    private static readonly string[] DefaultVideoExtensions = [".mp4", ".mkv", ".webm", ".avi", ".mov"];

    public string? MatchingVideo(string subtitlePath)
    {
        string directory = Path.GetDirectoryName(subtitlePath) ?? string.Empty;
        string subtitleBaseName = Path.GetFileNameWithoutExtension(subtitlePath);

        foreach (string baseName in CandidateBaseNames(subtitleBaseName)) {
            foreach (string extension in DefaultVideoExtensions) {
                string candidate = Path.Combine(directory, baseName + extension);
                if (File.Exists(candidate)) {
                    return PathContract.NormalizePath(candidate);
                }
            }
        }

        return null;
    }

    public IReadOnlyList<string> CandidateBaseNames(string subtitleBaseName)
    {
        List<string> candidates = [subtitleBaseName];
        Match match = LanguageSuffixRegex().Match(subtitleBaseName);
        if (match.Success && match.Index > 0) {
            candidates.Add(subtitleBaseName[..match.Index]);
        }

        return candidates;
    }

    [GeneratedRegex(@"\.[A-Za-z]{2,5}(-[A-Za-z]{2,5})?$")]
    private static partial Regex LanguageSuffixRegex();
}
