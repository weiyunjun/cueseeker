using System.Runtime.InteropServices;

namespace CueSeeker.Windows.Core;

internal static class NaturalSort
{
    public static int Compare(string left, string right)
    {
        try {
            return StrCmpLogicalW(left, right);
        } catch (DllNotFoundException) {
            return StringComparer.CurrentCultureIgnoreCase.Compare(left, right);
        } catch (EntryPointNotFoundException) {
            return StringComparer.CurrentCultureIgnoreCase.Compare(left, right);
        }
    }

    public static IComparer<string> Comparer { get; } = Comparer<string>.Create(Compare);

    [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)]
    private static extern int StrCmpLogicalW(string psz1, string psz2);
}
