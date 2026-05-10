namespace CueSeeker.Windows.Core;

internal static class PathContract
{
    public static string NormalizePath(string path)
    {
        return Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    public static bool PathIsUnderFolder(string path, string folder)
    {
        string normalizedPath = NormalizePath(path);
        string normalizedFolder = NormalizePath(folder);
        return normalizedPath.Equals(normalizedFolder, StringComparison.OrdinalIgnoreCase)
            || normalizedPath.StartsWith(normalizedFolder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
            || normalizedPath.StartsWith(normalizedFolder + Path.AltDirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
    }
}
