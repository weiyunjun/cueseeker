namespace CueSeeker.Windows.Core;

internal sealed class SubtitleFileScanner
{
    public static readonly HashSet<string> SupportedSubtitleExtensions = new(StringComparer.OrdinalIgnoreCase) {
        ".srt",
        ".ass",
    };

    public IReadOnlyList<string> ScanSubtitleFiles(string folder)
    {
        if (!Directory.Exists(folder)) {
            return [];
        }

        return Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories)
            .Where(path => SupportedSubtitleExtensions.Contains(Path.GetExtension(path)))
            .Where(path => !IsHidden(path))
            .OrderBy(path => path, NaturalSort.Comparer)
            .Select(PathContract.NormalizePath)
            .ToList();
    }

    private static bool IsHidden(string path)
    {
        try {
            return (File.GetAttributes(path) & FileAttributes.Hidden) != 0;
        } catch (IOException) {
            return true;
        } catch (UnauthorizedAccessException) {
            return true;
        }
    }
}
