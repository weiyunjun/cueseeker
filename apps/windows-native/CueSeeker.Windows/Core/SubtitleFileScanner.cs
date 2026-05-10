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

        List<string> subtitleFiles = [];
        Stack<string> pendingDirectories = new();
        pendingDirectories.Push(PathContract.NormalizePath(folder));

        while (pendingDirectories.Count > 0) {
            string directory = pendingDirectories.Pop();
            foreach (string child in EnumerateFileSystemEntries(directory)) {
                FileAttributes attributes;
                try {
                    attributes = File.GetAttributes(child);
                } catch (IOException) {
                    continue;
                } catch (UnauthorizedAccessException) {
                    continue;
                }

                if ((attributes & FileAttributes.Hidden) != 0 || (attributes & FileAttributes.ReparsePoint) != 0) {
                    continue;
                }

                if ((attributes & FileAttributes.Directory) != 0) {
                    pendingDirectories.Push(child);
                    continue;
                }

                if (SupportedSubtitleExtensions.Contains(Path.GetExtension(child))) {
                    subtitleFiles.Add(PathContract.NormalizePath(child));
                }
            }
        }

        return subtitleFiles
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ThenBy(path => path, StringComparer.Ordinal)
            .ToList();
    }

    private static IEnumerable<string> EnumerateFileSystemEntries(string directory)
    {
        try {
            return Directory.EnumerateFileSystemEntries(directory);
        } catch (IOException) {
            return [];
        } catch (UnauthorizedAccessException) {
            return [];
        }
    }
}
