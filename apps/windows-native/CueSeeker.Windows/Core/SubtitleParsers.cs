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
        List<SubtitleCueGroup> groups = [];
        foreach ((string[] lines, int eventIndex) in SplitSrtBlocks(contents).Select((lines, index) => (lines, index))) {
            if (lines.Length == 0) {
                continue;
            }

            int? sequenceNumber = int.TryParse(lines[0].Trim(), out int sequence) ? sequence : null;
            int timeLineIndex = sequenceNumber.HasValue ? 1 : 0;
            if (timeLineIndex >= lines.Length) {
                continue;
            }

            string timeLine = lines[timeLineIndex].Trim();
            int separatorIndex = timeLine.IndexOf("-->", StringComparison.Ordinal);
            if (separatorIndex < 0) {
                continue;
            }

            string startTimecode = timeLine[..separatorIndex].Trim();
            string endTimecode = timeLine[(separatorIndex + "-->".Length)..].Trim();
            if (!TryParseSrtTime(startTimecode, out int startMilliseconds)
                || !TryParseSrtTime(endTimecode, out int endMilliseconds)
                || endMilliseconds < startMilliseconds) {
                continue;
            }

            string text = string.Join("\n", lines.Skip(timeLineIndex + 1).Select(line => line.Trim()))
                .Trim();
            if (text.Length == 0) {
                continue;
            }

            SubtitleCueLine cueLine = new(
                eventIndex,
                SubtitleFormat.Srt,
                null,
                null,
                startTimecode,
                endTimecode,
                startMilliseconds,
                endMilliseconds,
                text,
                null,
                null,
                0);

            groups.Add(new SubtitleCueGroup(
                sequenceNumber,
                startTimecode,
                endTimecode,
                startMilliseconds,
                endMilliseconds,
                text,
                [cueLine]));
        }

        return groups;
    }

    private static IReadOnlyList<SubtitleCueGroup> ParseAss(string contents)
    {
        AssParser parser = new(contents);
        return parser.Parse();
    }

    private static IReadOnlyList<string[]> SplitSrtBlocks(string contents)
    {
        string normalized = NormalizeNewlines(contents);
        List<string[]> blocks = [];
        List<string> current = [];

        foreach (string line in normalized.Split('\n', StringSplitOptions.None)) {
            if (string.IsNullOrWhiteSpace(line)) {
                if (current.Count > 0) {
                    blocks.Add(current.ToArray());
                    current.Clear();
                }
            } else {
                current.Add(line);
            }
        }

        if (current.Count > 0) {
            blocks.Add(current.ToArray());
        }

        return blocks;
    }

    private static bool TryParseSrtTime(string text, out int milliseconds)
    {
        string[] hourParts = text.Trim().Split(':', StringSplitOptions.None);
        if (hourParts.Length != 3
            || !int.TryParse(hourParts[0], out int hours)
            || !int.TryParse(hourParts[1], out int minutes)
            || minutes is < 0 or >= 60) {
            milliseconds = 0;
            return false;
        }

        string[] secondParts = hourParts[2].Split([',', '.'], StringSplitOptions.None);
        if (secondParts.Length != 2
            || !int.TryParse(secondParts[0], out int seconds)
            || seconds is < 0 or >= 60
            || !int.TryParse(secondParts[1], out int fraction)
            || fraction is < 0 or >= 1000) {
            milliseconds = 0;
            return false;
        }

        milliseconds = (((hours * 60) + minutes) * 60 + seconds) * 1_000 + fraction;
        return true;
    }

    private static bool TryParseAssTime(string text, out int milliseconds)
    {
        string[] hourParts = text.Trim().Split(':', StringSplitOptions.None);
        if (hourParts.Length != 3
            || !int.TryParse(hourParts[0], out int hours)
            || !int.TryParse(hourParts[1], out int minutes)
            || minutes is < 0 or >= 60) {
            milliseconds = 0;
            return false;
        }

        string[] secondParts = hourParts[2].Split('.', StringSplitOptions.None);
        if (secondParts.Length != 2
            || !int.TryParse(secondParts[0], out int seconds)
            || seconds is < 0 or >= 60
            || !int.TryParse(secondParts[1], out int fraction)) {
            milliseconds = 0;
            return false;
        }

        milliseconds = secondParts[1].Length switch {
            1 => fraction * 100,
            2 => fraction * 10,
            3 => fraction,
            _ => -1,
        };
        if (milliseconds is < 0 or >= 1000) {
            milliseconds = 0;
            return false;
        }

        milliseconds += (((hours * 60) + minutes) * 60 + seconds) * 1_000;
        return true;
    }

    private static string CleanAssText(string text)
    {
        string cleaned = AssOverrideRegex().Replace(text, string.Empty);
        return cleaned
            .Replace("\\N", "\n", StringComparison.Ordinal)
            .Replace("\\n", "\n", StringComparison.Ordinal)
            .Trim();
    }

    private static string NormalizeNewlines(string contents)
    {
        return contents
            .Replace("\uFEFF", string.Empty, StringComparison.Ordinal)
            .Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace('\r', '\n');
    }

    private static string? ValueNamed(string name, IReadOnlyList<string> fields, IReadOnlyList<string> format)
    {
        for (int index = 0; index < format.Count && index < fields.Count; index++) {
            if (format[index].Equals(name, StringComparison.OrdinalIgnoreCase)) {
                return fields[index];
            }
        }

        return null;
    }

    private static List<string> ParseFormat(string text)
    {
        return text.Split(',')
            .Select(part => part.Trim().ToLowerInvariant())
            .ToList();
    }

    private static string[] SplitFields(string text, int expectedCount)
    {
        return text.Split([','], expectedCount, StringSplitOptions.None)
            .Select(field => field.Trim())
            .ToArray();
    }

    [GeneratedRegex(@"\{[^}]*\}")]
    private static partial Regex AssOverrideRegex();

    [GeneratedRegex(@"\\an([1-9])")]
    private static partial Regex InlineAlignmentRegex();

    [GeneratedRegex(@"\\pos\(([-0-9.]+),\s*([-0-9.]+)\)")]
    private static partial Regex InlinePositionRegex();

    [GeneratedRegex(@"\\move\(([-0-9.]+),\s*([-0-9.]+),")]
    private static partial Regex InlineMoveRegex();

    private sealed class AssParser
    {
        private readonly string contents;
        private Section section = Section.Unknown;
        private double? playResX;
        private double? playResY;
        private List<string> styleFormat = [];
        private readonly Dictionary<string, AssStyle> styles = new(StringComparer.Ordinal);
        private List<string> eventFormat = [];
        private readonly List<ParsedCueLine> parsedLines = [];

        public AssParser(string contents)
        {
            this.contents = contents;
        }

        private enum Section
        {
            Unknown,
            ScriptInfo,
            Styles,
            Events,
        }

        public IReadOnlyList<SubtitleCueGroup> Parse()
        {
            foreach (string rawLine in NormalizeNewlines(contents).Split('\n', StringSplitOptions.None)) {
                ParseLine(rawLine);
            }

            return GroupedCueLines();
        }

        private void ParseLine(string rawLine)
        {
            string line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith(';')) {
                return;
            }

            if (line.StartsWith('[') && line.EndsWith(']')) {
                section = line.ToLowerInvariant() switch {
                    "[script info]" => Section.ScriptInfo,
                    "[v4+ styles]" => Section.Styles,
                    "[events]" => Section.Events,
                    _ => Section.Unknown,
                };
                return;
            }

            switch (section) {
                case Section.ScriptInfo:
                    ParseScriptInfo(line);
                    break;
                case Section.Styles:
                    ParseStyleLine(line);
                    break;
                case Section.Events:
                    ParseEventLine(line);
                    break;
            }
        }

        private void ParseScriptInfo(string line)
        {
            int separator = line.IndexOf(':');
            if (separator < 0) {
                return;
            }

            string key = line[..separator].Trim().ToLowerInvariant();
            string value = line[(separator + 1)..].Trim();
            if (key == "playresx" && double.TryParse(value, out double x)) {
                playResX = x;
            } else if (key == "playresy" && double.TryParse(value, out double y)) {
                playResY = y;
            }
        }

        private void ParseStyleLine(string line)
        {
            if (line.StartsWith("Format:", StringComparison.OrdinalIgnoreCase)) {
                styleFormat = ParseFormat(line["Format:".Length..]);
                return;
            }

            if (!line.StartsWith("Style:", StringComparison.OrdinalIgnoreCase) || styleFormat.Count == 0) {
                return;
            }

            string[] fields = SplitFields(line["Style:".Length..], styleFormat.Count);
            string? name = ValueNamed("name", fields, styleFormat);
            if (fields.Length != styleFormat.Count || string.IsNullOrEmpty(name)) {
                return;
            }

            styles[name] = new AssStyle(
                TryParseInt(ValueNamed("alignment", fields, styleFormat)),
                TryParseDouble(ValueNamed("marginl", fields, styleFormat)),
                TryParseDouble(ValueNamed("marginr", fields, styleFormat)),
                TryParseDouble(ValueNamed("marginv", fields, styleFormat)));
        }

        private void ParseEventLine(string line)
        {
            if (line.StartsWith("Format:", StringComparison.OrdinalIgnoreCase)) {
                eventFormat = ParseFormat(line["Format:".Length..]);
                return;
            }

            if (!line.StartsWith("Dialogue:", StringComparison.OrdinalIgnoreCase) || eventFormat.Count == 0) {
                return;
            }

            int eventIndex = parsedLines.Count;
            string[] fields = SplitFields(line["Dialogue:".Length..], eventFormat.Count);
            string? startTimecode = ValueNamed("start", fields, eventFormat);
            string? endTimecode = ValueNamed("end", fields, eventFormat);
            string? rawText = ValueNamed("text", fields, eventFormat);
            if (fields.Length != eventFormat.Count
                || startTimecode is null
                || endTimecode is null
                || rawText is null
                || !TryParseAssTime(startTimecode, out int startMilliseconds)
                || !TryParseAssTime(endTimecode, out int endMilliseconds)
                || endMilliseconds < startMilliseconds) {
                return;
            }

            string content = CleanAssText(rawText);
            if (content.Length == 0) {
                return;
            }

            string? sourceStyle = ValueNamed("style", fields, eventFormat);
            int? sourceLayer = TryParseInt(ValueNamed("layer", fields, eventFormat));
            (double? displayX, double? displayY) = LayoutProjection(
                rawText,
                sourceStyle,
                TryParseDouble(ValueNamed("marginl", fields, eventFormat)),
                TryParseDouble(ValueNamed("marginr", fields, eventFormat)),
                TryParseDouble(ValueNamed("marginv", fields, eventFormat)));

            parsedLines.Add(new ParsedCueLine(
                eventIndex,
                string.IsNullOrEmpty(sourceStyle) ? null : sourceStyle,
                sourceLayer,
                startTimecode.Trim(),
                endTimecode.Trim(),
                startMilliseconds,
                endMilliseconds,
                content,
                displayX,
                displayY));
        }

        private IReadOnlyList<SubtitleCueGroup> GroupedCueLines()
        {
            return parsedLines
                .GroupBy(line => new CueGroupKey(line.StartTimecode, line.EndTimecode, line.StartMilliseconds, line.EndMilliseconds))
                .Select(group => {
                    ParsedCueLine[] sortedLines = group
                        .OrderBy(line => line, Comparer<ParsedCueLine>.Create(SortCueLines))
                        .ToArray();
                    SubtitleCueLine[] cueLines = sortedLines.Select((line, displayOrder) => new SubtitleCueLine(
                        line.EventIndex,
                        SubtitleFormat.Ass,
                        line.SourceStyle,
                        line.SourceLayer,
                        line.StartTimecode,
                        line.EndTimecode,
                        line.StartMilliseconds,
                        line.EndMilliseconds,
                        line.Content,
                        line.DisplayX,
                        line.DisplayY,
                        displayOrder)).ToArray();

                    CueGroupKey key = group.Key;
                    return new SubtitleCueGroup(
                        null,
                        key.StartTimecode,
                        key.EndTimecode,
                        key.StartMilliseconds,
                        key.EndMilliseconds,
                        string.Join("\n", cueLines.Select(line => line.Content)),
                        cueLines);
                })
                .OrderBy(group => group.StartMilliseconds)
                .ThenBy(group => group.EndMilliseconds)
                .ThenBy(group => group.CueLines.FirstOrDefault()?.EventIndex ?? 0)
                .ToList();
        }

        private (double? X, double? Y) LayoutProjection(string rawText, string? styleName, double? eventMarginL, double? eventMarginR, double? eventMarginV)
        {
            if (InlinePosition(rawText) is { } position) {
                return position;
            }

            AssStyle? style = styleName is null ? null : styles.GetValueOrDefault(styleName);
            int? alignment = InlineAlignment(rawText) ?? style?.Alignment;
            if (!alignment.HasValue || !playResY.HasValue) {
                return (null, null);
            }

            double marginL = Positive(eventMarginL) ?? style?.MarginL ?? 0;
            double marginR = Positive(eventMarginR) ?? style?.MarginR ?? 0;
            double marginV = Positive(eventMarginV) ?? style?.MarginV ?? 0;
            double y = alignment.Value switch {
                7 or 8 or 9 => marginV,
                4 or 5 or 6 => playResY.Value / 2,
                _ => playResY.Value - marginV,
            };

            double? x = null;
            if (playResX.HasValue) {
                x = alignment.Value switch {
                    1 or 4 or 7 => marginL,
                    3 or 6 or 9 => playResX.Value - marginR,
                    _ => playResX.Value / 2,
                };
            }

            return (x, y);
        }

        private static int SortCueLines(ParsedCueLine left, ParsedCueLine right)
        {
            if (left.DisplayY.HasValue && right.DisplayY.HasValue && !left.DisplayY.Value.Equals(right.DisplayY.Value)) {
                return left.DisplayY.Value.CompareTo(right.DisplayY.Value);
            }

            if (left.DisplayY.HasValue != right.DisplayY.HasValue) {
                return left.DisplayY.HasValue ? -1 : 1;
            }

            if (left.DisplayX.HasValue && right.DisplayX.HasValue && !left.DisplayX.Value.Equals(right.DisplayX.Value)) {
                return left.DisplayX.Value.CompareTo(right.DisplayX.Value);
            }

            if (left.DisplayX.HasValue != right.DisplayX.HasValue) {
                return left.DisplayX.HasValue ? -1 : 1;
            }

            return left.EventIndex.CompareTo(right.EventIndex);
        }

        private static int? InlineAlignment(string text)
        {
            Match match = InlineAlignmentRegex().Match(text);
            return match.Success ? int.Parse(match.Groups[1].Value) : null;
        }

        private static (double X, double Y)? InlinePosition(string text)
        {
            Match position = InlinePositionRegex().Match(text);
            if (position.Success && double.TryParse(position.Groups[1].Value, out double x) && double.TryParse(position.Groups[2].Value, out double y)) {
                return (x, y);
            }

            Match move = InlineMoveRegex().Match(text);
            if (move.Success && double.TryParse(move.Groups[1].Value, out x) && double.TryParse(move.Groups[2].Value, out y)) {
                return (x, y);
            }

            return null;
        }

        private static double? Positive(double? value)
        {
            return value.HasValue && value.Value >= 0 ? value : null;
        }

        private static int? TryParseInt(string? value)
        {
            return int.TryParse(value, out int parsed) ? parsed : null;
        }

        private static double? TryParseDouble(string? value)
        {
            return double.TryParse(value, out double parsed) ? parsed : null;
        }
    }

    private sealed record AssStyle(int? Alignment, double? MarginL, double? MarginR, double? MarginV);

    private sealed record ParsedCueLine(
        int EventIndex,
        string? SourceStyle,
        int? SourceLayer,
        string StartTimecode,
        string EndTimecode,
        int StartMilliseconds,
        int EndMilliseconds,
        string Content,
        double? DisplayX,
        double? DisplayY);

    private sealed record CueGroupKey(string StartTimecode, string EndTimecode, int StartMilliseconds, int EndMilliseconds);
}
