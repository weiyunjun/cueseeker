using System.Runtime.InteropServices;
using Microsoft.UI.Xaml.Controls;
using WinRT;

namespace CueSeeker.Windows.Playback;

internal sealed class NativePlaybackHost
{
    public bool IsNativeLibraryAvailable {
        get {
            return EnsureNativeLibraryLoaded();
        }
    }

    public bool TryCaptureSwapChainPanel(SwapChainPanel panel, out nint nativePointer)
    {
        nativePointer = 0;
        if (panel is not IWinRTObject winrtObject) {
            return false;
        }

        nativePointer = winrtObject.NativeObject.ThisPtr;
        return nativePointer != 0;
    }

    public static string Inspect(string mediaPath, string? subtitlePath)
    {
        EnsureNativeLibraryLoaded();
        nint report = 0;
        nint error = 0;
        try {
            int result = CueSeekerPlaybackInspectJson(mediaPath, subtitlePath, out report, out error);
            if (result != 0) {
                throw new InvalidOperationException(ReadUtf8(error) ?? "Native inspect failed.");
            }
            return ReadUtf8(report) ?? string.Empty;
        } finally {
            CueSeekerPlaybackFreeString(report);
            CueSeekerPlaybackFreeString(error);
        }
    }

    public async Task<string> PlayAsync(
        string mediaPath,
        string? subtitlePath,
        string? reportPath,
        long seekMilliseconds,
        DecodePreference decodePreference,
        long durationMilliseconds = 0)
    {
        EnsureNativeLibraryLoaded();
        return await Task.Run(() => {
            NativePlaybackOptions options = new() {
                MediaPath = mediaPath,
                SubtitlePath = subtitlePath,
                ReportPath = reportPath,
                SeekMilliseconds = seekMilliseconds,
                DurationMilliseconds = durationMilliseconds,
                DecodePreference = decodePreference,
            };

            nint error = 0;
            try {
                int result = CueSeekerPlaybackPlay(ref options, out error);
                if (result != 0) {
                    throw new InvalidOperationException(ReadUtf8(error) ?? "Native playback failed.");
                }

                return reportPath ?? string.Empty;
            } finally {
                CueSeekerPlaybackFreeString(error);
            }
        });
    }

    private static bool EnsureNativeLibraryLoaded()
    {
        if (NativeLibrary.TryLoad("CueSeekerPlaybackNative.dll", out nint directHandle)) {
            NativeLibrary.Free(directHandle);
            return true;
        }

        string? nativePath = FindNativeLibraryPath();
        return nativePath is not null && NativeLibrary.TryLoad(nativePath, out _);
    }

    private static string? FindNativeLibraryPath()
    {
        DirectoryInfo? current = new(AppContext.BaseDirectory);
        while (current is not null) {
            string debugPath = Path.Combine(current.FullName, "apps", "windows-playback-lab", "build", "Debug", "CueSeekerPlaybackNative.dll");
            if (File.Exists(debugPath)) {
                return debugPath;
            }

            string releasePath = Path.Combine(current.FullName, "apps", "windows-playback-lab", "build", "Release", "CueSeekerPlaybackNative.dll");
            if (File.Exists(releasePath)) {
                return releasePath;
            }

            current = current.Parent;
        }

        return null;
    }

    private static string? ReadUtf8(nint value)
    {
        return value == 0 ? null : Marshal.PtrToStringUTF8(value);
    }

    [DllImport("CueSeekerPlaybackNative.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
    private static extern int CueSeekerPlaybackInspectJson(
        string mediaPath,
        string? subtitlePath,
        out nint reportJson,
        out nint errorMessage);

    [DllImport("CueSeekerPlaybackNative.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern int CueSeekerPlaybackPlay(
        ref NativePlaybackOptions options,
        out nint errorMessage);

    [DllImport("CueSeekerPlaybackNative.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void CueSeekerPlaybackFreeString(nint value);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NativePlaybackOptions
    {
        [MarshalAs(UnmanagedType.LPWStr)]
        public string MediaPath;

        [MarshalAs(UnmanagedType.LPWStr)]
        public string? SubtitlePath;

        [MarshalAs(UnmanagedType.LPWStr)]
        public string? ReportPath;

        public long SeekMilliseconds;
        public long DurationMilliseconds;
        public DecodePreference DecodePreference;
    }
}

internal enum DecodePreference
{
    Auto = 0,
    Software = 1,
    D3D11VA = 2,
}
