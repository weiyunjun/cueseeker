using System.Runtime.InteropServices;
using Microsoft.UI.Xaml.Controls;
using WinRT;

namespace CueSeeker.Windows.Playback;

internal sealed class NativePlaybackHost
{
    public bool IsNativeLibraryAvailable {
        get {
            if (!NativeLibrary.TryLoad("CueSeekerPlaybackNative.dll", out nint handle)) {
                return false;
            }
            NativeLibrary.Free(handle);
            return true;
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
    private static extern void CueSeekerPlaybackFreeString(nint value);
}
