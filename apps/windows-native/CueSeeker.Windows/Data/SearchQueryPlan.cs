using System.Text;

namespace CueSeeker.Windows.Data;

internal sealed class SearchQueryPlan
{
    private readonly LineMatchMode lineMatchMode;
    private readonly string[] queryTokens;
    private readonly string lineQuery;

    private SearchQueryPlan(string ftsQuery, LineMatchMode lineMatchMode, string lineQuery, string[] queryTokens)
    {
        FtsQuery = ftsQuery;
        this.lineMatchMode = lineMatchMode;
        this.lineQuery = lineQuery;
        this.queryTokens = queryTokens;
    }

    private enum LineMatchMode
    {
        LatinPrefix,
        OrderedLatinTokens,
        CjkSubstring,
        ExplicitFts,
    }

    public string FtsQuery { get; }

    public static SearchQueryPlan? Create(string rawQuery, int limit)
    {
        string query = rawQuery.Trim();
        if (query.Length == 0 || limit <= 0) {
            return null;
        }

        bool hasExplicitPhrase = query.Length >= 2 && query[0] == '"' && query[^1] == '"';
        bool hasFtsSyntax = hasExplicitPhrase || query.Contains('*', StringComparison.Ordinal) || ContainsFtsOperator(query);
        bool hasCjk = ContainsCjkSearchCharacter(query);
        string[] tokens = hasCjk ? [] : TokenizeLatinTokens(query);
        if (!hasFtsSyntax && !hasCjk && tokens.Length == 0) {
            return null;
        }

        if (hasFtsSyntax) {
            return new SearchQueryPlan(query, LineMatchMode.ExplicitFts, query, tokens);
        }

        if (hasCjk) {
            string segmented = SegmentCjkForFts(query).Trim();
            return new SearchQueryPlan($"\"{EscapeFtsPhrase(segmented)}\"", LineMatchMode.CjkSubstring, query, []);
        }

        if (tokens.Length > 1) {
            return new SearchQueryPlan(string.Join(" AND ", tokens), LineMatchMode.OrderedLatinTokens, query, tokens);
        }

        return new SearchQueryPlan($"{tokens[0]}*", LineMatchMode.LatinPrefix, query, tokens);
    }

    public bool LineMatches(string line)
    {
        return lineMatchMode switch {
            LineMatchMode.LatinPrefix => TokenizeLatinTokens(line).Any(token => token.StartsWith(queryTokens[0], StringComparison.Ordinal)),
            LineMatchMode.OrderedLatinTokens => MatchesOrderedWholeTokens(line, queryTokens),
            LineMatchMode.CjkSubstring => line.Contains(lineQuery, StringComparison.CurrentCulture),
            LineMatchMode.ExplicitFts => MatchesExplicitFtsLineFallback(line, lineQuery),
            _ => false,
        };
    }

    public static string SegmentCjkForFts(string text)
    {
        StringBuilder segmented = new();
        foreach (Rune rune in text.EnumerateRunes()) {
            segmented.Append(rune);
            if (IsCjkSearchCharacter(rune.Value)) {
                segmented.Append(' ');
            }
        }

        return segmented.ToString();
    }

    public static int SearchCandidateBatchLimit(int limit)
    {
        int expanded = limit > int.MaxValue / 5 ? int.MaxValue : limit * 5;
        return Math.Max(expanded, 100);
    }

    private static bool MatchesExplicitFtsLineFallback(string line, string query)
    {
        string trimmed = query.Trim();
        if (trimmed.Length >= 2 && trimmed[0] == '"' && trimmed[^1] == '"') {
            string phrase = trimmed[1..^1];
            return line.Contains(phrase, StringComparison.CurrentCultureIgnoreCase);
        }

        HashSet<string> operators = ["AND", "OR", "NOT", "NEAR"];
        string[] tokens = TokenizeLatinTokens(trimmed)
            .Where(token => !operators.Contains(token.ToUpperInvariant()))
            .ToArray();
        if (tokens.Length == 0) {
            return false;
        }

        string[] lineTokens = TokenizeLatinTokens(line);
        if (trimmed.Contains(" OR ", StringComparison.OrdinalIgnoreCase)) {
            return tokens.Any(token => lineTokens.Any(candidate => candidate == token || candidate.StartsWith(token, StringComparison.Ordinal)));
        }

        return tokens.All(token => lineTokens.Any(candidate => candidate == token || candidate.StartsWith(token, StringComparison.Ordinal)));
    }

    private static bool MatchesOrderedWholeTokens(string content, string[] tokens)
    {
        if (tokens.Length == 0) {
            return false;
        }

        string[] contentTokens = TokenizeLatinTokens(content);
        if (contentTokens.Length < tokens.Length) {
            return false;
        }

        int queryIndex = 0;
        foreach (string token in contentTokens) {
            if (token == tokens[queryIndex]) {
                queryIndex++;
                if (queryIndex == tokens.Length) {
                    return true;
                }
            }
        }

        return false;
    }

    private static string[] TokenizeLatinTokens(string text)
    {
        List<string> tokens = [];
        StringBuilder current = new();
        bool containsApostrophe = false;

        void FlushToken()
        {
            if (current.Length > 0) {
                tokens.Add(current.ToString());
                current.Clear();
            }
            containsApostrophe = false;
        }

        for (int index = 0; index < text.Length; index++) {
            char character = text[index];
            if (IsAsciiLetterOrDigit(character)) {
                current.Append(char.ToLowerInvariant(character));
            } else if (character == '\'' && current.Length > 0 && !containsApostrophe && index + 1 < text.Length && IsAsciiLetterOrDigit(text[index + 1])) {
                current.Append(character);
                containsApostrophe = true;
            } else {
                FlushToken();
            }
        }

        FlushToken();
        return tokens.ToArray();
    }

    private static bool ContainsFtsOperator(string text)
    {
        HashSet<string> operators = ["AND", "OR", "NOT", "NEAR"];
        StringBuilder current = new();

        void Flush()
        {
            current.Clear();
        }

        foreach (char character in text) {
            if (IsAsciiWordCharacter(character)) {
                current.Append(character);
            } else {
                if (operators.Contains(current.ToString())) {
                    return true;
                }
                Flush();
            }
        }

        return operators.Contains(current.ToString());
    }

    private static bool ContainsCjkSearchCharacter(string text)
    {
        return text.EnumerateRunes().Any(rune => IsCjkSearchCharacter(rune.Value));
    }

    private static bool IsCjkSearchCharacter(int value)
    {
        return (value >= 0x3400 && value <= 0x4DBF)
            || (value >= 0x4E00 && value <= 0x9FFF)
            || (value >= 0xF900 && value <= 0xFAFF)
            || (value >= 0x3040 && value <= 0x309F)
            || (value >= 0x30A0 && value <= 0x30FF)
            || (value >= 0x31F0 && value <= 0x31FF)
            || (value >= 0xFF66 && value <= 0xFF9F);
    }

    private static bool IsAsciiLetterOrDigit(char character)
    {
        return (character >= 'A' && character <= 'Z')
            || (character >= 'a' && character <= 'z')
            || (character >= '0' && character <= '9');
    }

    private static bool IsAsciiWordCharacter(char character)
    {
        return IsAsciiLetterOrDigit(character) || character == '_';
    }

    private static string EscapeFtsPhrase(string text)
    {
        return text.Replace("\"", "\"\"", StringComparison.Ordinal);
    }
}
