using System.Text.RegularExpressions;

namespace CueSeeker.Windows.Data;

internal sealed partial class SearchQueryPlan
{
    private readonly string query;
    private readonly string[] queryTokens;
    private readonly MatchMode mode;

    private SearchQueryPlan(string query, string[] queryTokens, MatchMode mode)
    {
        this.query = query;
        this.queryTokens = queryTokens;
        this.mode = mode;
    }

    private enum MatchMode
    {
        Contains,
        PrefixToken,
        OrderedWholeTokens,
    }

    public static SearchQueryPlan? Create(string rawQuery)
    {
        string query = rawQuery.Trim();
        if (query.Length == 0) {
            return null;
        }

        string[] tokens = TokenRegex().Matches(query)
            .Select(match => match.Value.ToLowerInvariant())
            .ToArray();

        if (ContainsCjkSearchCharacter(query)) {
            return new SearchQueryPlan(query, tokens, MatchMode.Contains);
        }

        if (tokens.Length == 1) {
            return new SearchQueryPlan(query, tokens, MatchMode.PrefixToken);
        }

        if (tokens.Length > 1) {
            return new SearchQueryPlan(query, tokens, MatchMode.OrderedWholeTokens);
        }

        return new SearchQueryPlan(query, tokens, MatchMode.Contains);
    }

    public bool LineMatches(string line)
    {
        return mode switch {
            MatchMode.Contains => line.Contains(query, StringComparison.CurrentCultureIgnoreCase),
            MatchMode.PrefixToken => ContentTokens(line).Any(token => token.StartsWith(queryTokens[0], StringComparison.OrdinalIgnoreCase)),
            MatchMode.OrderedWholeTokens => MatchesOrderedWholeTokens(line),
            _ => false,
        };
    }

    private bool MatchesOrderedWholeTokens(string line)
    {
        string[] contentTokens = ContentTokens(line).Select(token => token.ToLowerInvariant()).ToArray();
        int queryIndex = 0;
        foreach (string token in contentTokens) {
            if (token == queryTokens[queryIndex]) {
                queryIndex++;
                if (queryIndex == queryTokens.Length) {
                    return true;
                }
            }
        }

        return false;
    }

    private static string[] ContentTokens(string value)
    {
        return TokenRegex().Matches(value)
            .Select(match => match.Value)
            .ToArray();
    }

    private static bool ContainsCjkSearchCharacter(string value)
    {
        return value.EnumerateRunes().Any(rune => {
            int codepoint = rune.Value;
            return (codepoint >= 0x3400 && codepoint <= 0x9FFF)
                || (codepoint >= 0x3040 && codepoint <= 0x30FF)
                || (codepoint >= 0xFF66 && codepoint <= 0xFF9D);
        });
    }

    [GeneratedRegex(@"[A-Za-z0-9]+")]
    private static partial Regex TokenRegex();
}
