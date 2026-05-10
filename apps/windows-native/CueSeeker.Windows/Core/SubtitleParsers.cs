using System.Text.RegularExpressions;

namespace CueSeeker.Windows.Core;

internal static partial class SubtitleParsers
{
    public static IReadOnlyList<SubtitleCueGroup> Parse(SubtitleFormat format, string contents)
    {
        return format == SubtitleFormat.Ass ? ParseAss(contents) : ParseSrt(contents);
    }

    private static IReadOnlyList<SubtitleCueGroup> ParseSrt(string contents)
    {
        string normalized = contents.Replace("\r\n", "\n").Replace('\r', '\n');
        string[] blocks = normalized.Split("\n\n", StringSplitOptions.RemoveEmptyEntries);
        List<SubtitleCueGroup> groups = [];

        foreach (string block in blocks) {
            string[] lines = block.Split('\n', StringSplitOptions.None)
                .Select(line => line.TrimEnd())
                .Where(line => line.Length > 0)
                .ToArray();

            int timingIndex = Array.FindIndex(lines, line => line.Contains("-->", StringComparison.Ordinal));
            if (timingIndex < 0) {
                continue;
            }

            string[] parts = lines[timingIndex].Split("-->", StringSplitOptions.TrimEntries);
            if (parts.Length != 2 || !TryParseSrtTime(parts[0], out int start) || !TryParseSrtTime(parts[1], out int end)) {
                continue;
            }

            string[] textLines = lines.Skip(timingIndex + 1)
                .Select(CleanSearchText)
                .Where(line => line.Length > 0)
                .ToArray();
            if (textLines.Length == 0) {
                continue;
            }

            groups.Add(new SubtitleCueGroup(start, end, string.Join("\n", textLines), textLines));
        }

        return groups;
    }

    private static IReadOnlyList<SubtitleCueGroup> ParseAss(string contents)
    {
        string normalized = contents.Replace("\r\n", "\n").Replace('\r', '\n');
        bool inEvents = false;
        List<string> fields = [];
        List<(int Start, int End, string Text)> events = [];

        foreach (string rawLine in normalized.Split('\n', StringSplitOptions.None)) {
            string line = rawLine.TrimEnd();
            if (line.Equals("[Events]", StringComparison.OrdinalIgnoreCase)) {
                inEvents = true;
                continue;
            }

            if (inEvents && line.StartsWith('[']) && line.EndsWith(']')) {
                inEvents = false;
            }

            if (!inEvents) {
                continue;
            }

            if (line.StartsWith("Format:", StringComparison.OrdinalIgnoreCase)) {
                fields = line["Format:".Length..]
                    .Split(',')
                    .Select(part => part.Trim())
                    .ToList();
                continue;
            }

            if (!line.StartsWith("Dialogue:", StringComparison.OrdinalIgnoreCase) || fields.Count == 0) {
                continue;
            }

            string payload = line["Dialogue:".Length..].TrimStart();
            string[] values = payload.Split([','], fields.Count, StringSplitOptions.None);
            int startIndex = fields.FindIndex(field => field.Equals("Start", StringComparison.OrdinalIgnoreCase));
            int endIndex = fields.FindIndex(field => field.Equals("End", StringComparison.OrdinalIgnoreCase));
            int textIndex = fields.FindIndex(field => field.Equals("Text", StringComparison.OrdinalIgnoreCase));
            if (startIndex < 0 || endIndex < 0 || textIndex < 0 || values.Length <= Math.Max(startIndex, Math.Max(endIndex, textIndex))) {
                continue;
            }

            if (!TryParseAssTime(values[startIndex], out int start) || !TryParseAssTime(values[endIndex], out int end)) {
                continue;
            }

            string text = CleanAssText(values[textIndex]);
            if (string.IsNullOrWhiteSpace(text)) {
                continue;
            }

            events.Add((start, end, text));
        }

        return events
            .GroupBy(item => (item.Start, item.End))
            .OrderBy(group => group.Key.Start)
            .ThenBy(group => group.Key.End)
            .Select(group => {
                string[] lines = group.SelectMany(item => item.Text.Split('\n', StringSplitOptions.RemoveEmptyEntries))
                    .Select(CleanSearchText)
                    .Where(line => line.Length > 0)
                    .ToArray();
                return new SubtitleCueGroup(group.Key.Start, group.Key.End, string.Join("\n", lines), lines);
            })
            .Where(group => group.CueLines.Count > 0)
            .ToList();
    }

    private static bool TryParseSrtTime(string text, out int milliseconds)
    {
        Match match = SrtTimeRegex().Match(text.Trim());
        if (!match.Success) {
            milliseconds = 0;
            return false;
        }

        milliseconds =
            int.Parse(match.Groups[1].Value) * 3_600_000 +
            int.Parse(match.Groups[2].Value) * 60_000 +
            int.Parse(match.Groups[3].Value) * 1_000 +
            int.Parse(match.Groups[4].Value);
        return true;
    }

    private static bool TryParseAssTime(string text, out int milliseconds)
    {
        Match match = AssTimeRegex().Match(text.Trim());
        if (!match.Success) {
            milliseconds = 0;
            return false;
        }

        milliseconds =
            int.Parse(match.Groups[1].Value) * 3_600_000 +
            int.Parse(match.Groups[2].Value) * 60_000 +
            int.Parse(match.Groups[3].Value) * 1_000 +
            int.Parse(match.Groups[4].Value.PadRight(3, '0')[..3]);
        return true;
    }

    private static string CleanAssText(string text)
    {
        string withoutOverrides = AssOverrideRegex().Replace(text, string.Empty);
        return withoutOverrides
            .Replace("\\N", "\n", StringComparison.Ordinal)
            .Replace("\\n", "\n", StringComparison.Ordinal)
            .Replace("\\h", " ", StringComparison.Ordinal);
    }

    private static string CleanSearchText(string text)
    {
        return WhitespaceRegex().Replace(text.Trim(), " ");
    }

    [GeneratedRegex(@"^(\d+):(\d{2}):(\d{2}),(\d{3})")]
    private static partial Regex SrtTimeRegex();

    [GeneratedRegex(@"^(\d+):(\d{2}):(\d{2})\.(\d{1,3})")]
    private static partial Regex AssTimeRegex();

    [GeneratedRegex(@"\{[^}]*\}")]
    private static partial Regex AssOverrideRegex();

    [GeneratedRegex(@"[ \t]+")]
    private static partial Regex WhitespaceRegex();
}
