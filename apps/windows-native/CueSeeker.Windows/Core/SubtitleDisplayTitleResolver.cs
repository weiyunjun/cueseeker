namespace CueSeeker.Windows.Core;

internal static class SubtitleDisplayTitleResolver
{
    public static string DisplayTitle(string subtitlePath)
    {
        string fallback = Path.GetFileName(subtitlePath);
        string? parent = Path.GetDirectoryName(subtitlePath);
        if (string.IsNullOrWhiteSpace(parent)) {
            return fallback;
        }

        string parentTitle = Path.GetFileName(parent.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
        string extension = Path.GetExtension(subtitlePath);
        if (string.IsNullOrWhiteSpace(parentTitle) || !SubtitleFileScanner.SupportedSubtitleExtensions.Contains(extension)) {
            return fallback;
        }

        try {
            List<string> siblings = Directory.EnumerateFiles(parent)
                .Where(path => Path.GetExtension(path).Equals(extension, StringComparison.OrdinalIgnoreCase))
                .Where(path => {
                    FileAttributes attributes = File.GetAttributes(path);
                    return (attributes & FileAttributes.Directory) == 0
                        && (attributes & FileAttributes.Hidden) == 0;
                })
                .OrderBy(path => Path.GetFileName(path), NaturalSort.Comparer)
                .ThenBy(path => path, NaturalSort.Comparer)
                .Select(PathContract.NormalizePath)
                .ToList();

            int index = siblings.FindIndex(path => path.Equals(PathContract.NormalizePath(subtitlePath), StringComparison.OrdinalIgnoreCase));
            if (index < 0) {
                return fallback;
            }

            int width = Math.Max(2, siblings.Count.ToString().Length);
            return $"{parentTitle} - {(index + 1).ToString().PadLeft(width, '0')}";
        } catch (IOException) {
            return fallback;
        } catch (UnauthorizedAccessException) {
            return fallback;
        }
    }
}
