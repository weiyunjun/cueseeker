using CueSeeker.Windows.Core;
using CueSeeker.Windows.Data;

namespace CueSeeker.Windows.Services;

internal sealed class SubtitleIndexer
{
    private readonly SubtitleFileScanner scanner = new();
    private readonly VideoMatcher matcher = new();

    public SubtitleIndexingResult Index(string folder, SubtitleDatabase database)
    {
        database.Migrate();
        database.AddSearchPath(folder);

        SubtitleIndexingResult result = new();
        IReadOnlyList<string> subtitleFiles = scanner.ScanSubtitleFiles(folder);
        result.ScannedSubtitleFiles = subtitleFiles.Count;

        Dictionary<string, SubtitleFileMetadata> existingFiles = database.SubtitleFiles()
            .ToDictionary(metadata => metadata.SubtitlePath, StringComparer.OrdinalIgnoreCase);
        HashSet<string> keptSubtitlePaths = new(StringComparer.OrdinalIgnoreCase);

        foreach (string subtitleFile in subtitleFiles) {
            string? videoFile = matcher.MatchingVideo(subtitleFile);
            if (videoFile is null) {
                result.SkippedMissingVideo++;
                continue;
            }

            FileInfo fileInfo = new(subtitleFile);
            long? fileSize = fileInfo.Exists ? fileInfo.Length : null;
            DateTimeOffset? modifiedAt = fileInfo.Exists ? new DateTimeOffset(fileInfo.LastWriteTimeUtc) : null;
            double? modifiedAtSeconds = modifiedAt.HasValue ? SubtitleDatabase.UnixSeconds(modifiedAt.Value) : null;

            if (existingFiles.TryGetValue(PathContract.NormalizePath(subtitleFile), out SubtitleFileMetadata? metadata)
                && IsUnchanged(metadata, videoFile, fileSize, modifiedAtSeconds)) {
                keptSubtitlePaths.Add(PathContract.NormalizePath(subtitleFile));
                result.SkippedUnchangedSubtitleFiles++;
                continue;
            }

            string contents;
            try {
                contents = File.ReadAllText(subtitleFile);
            } catch (IOException) {
                result.SkippedUnreadableSubtitle++;
                result.FailedFiles.Add(new SubtitleIndexingFailure(subtitleFile, "Subtitle file could not be read."));
                continue;
            } catch (UnauthorizedAccessException) {
                result.SkippedUnreadableSubtitle++;
                result.FailedFiles.Add(new SubtitleIndexingFailure(subtitleFile, "Subtitle file could not be read."));
                continue;
            }

            SubtitleFormat? format = SubtitleFormatExtensions.FromExtension(Path.GetExtension(subtitleFile));
            if (format is null) {
                continue;
            }

            IReadOnlyList<SubtitleCueGroup> cueGroups = SubtitleParsers.Parse(format.Value, contents);
            database.ReplaceCueGroups(subtitleFile, videoFile, format.Value, cueGroups, fileSize, modifiedAt);

            keptSubtitlePaths.Add(PathContract.NormalizePath(subtitleFile));
            result.IndexedSubtitleFiles++;
            result.IndexedSubtitleEntries += cueGroups.Count;
        }

        database.RemoveStaleEntries(folder, keptSubtitlePaths);
        database.RebuildLibraryPresentationSnapshot();
        return result;
    }

    private static bool IsUnchanged(SubtitleFileMetadata metadata, string videoFile, long? fileSize, double? modifiedAtSeconds)
    {
        if (metadata.VideoPath is null
            || !metadata.VideoPath.Equals(videoFile, StringComparison.OrdinalIgnoreCase)
            || metadata.FileSize != fileSize
            || !metadata.ModifiedAtSeconds.HasValue
            || !modifiedAtSeconds.HasValue) {
            return false;
        }

        return Math.Abs(metadata.ModifiedAtSeconds.Value - modifiedAtSeconds.Value) < 0.001;
    }
}
