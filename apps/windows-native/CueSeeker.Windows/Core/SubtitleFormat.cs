namespace CueSeeker.Windows.Core;

internal enum SubtitleFormat
{
    Srt,
    Ass,
}

internal static class SubtitleFormatExtensions
{
    public static string RawValue(this SubtitleFormat format)
    {
        return format == SubtitleFormat.Ass ? "ass" : "srt";
    }

    public static SubtitleFormat? FromExtension(string extension)
    {
        string normalized = extension.TrimStart('.').ToLowerInvariant();
        return normalized switch {
            "srt" => SubtitleFormat.Srt,
            "ass" => SubtitleFormat.Ass,
            _ => null,
        };
    }

    public static SubtitleFormat FromRawValue(string value)
    {
        return value.Equals("ass", StringComparison.OrdinalIgnoreCase)
            ? SubtitleFormat.Ass
            : SubtitleFormat.Srt;
    }
}
