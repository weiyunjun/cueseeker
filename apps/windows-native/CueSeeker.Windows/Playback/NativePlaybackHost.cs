using System.Runtime.InteropServices;
using Microsoft.UI.Xaml.Controls;
using WinRT;

namespace CueSeeker.Windows.Playback;

internal sealed class NativePlaybackHost
{
    private readonly SemaphoreSlim playbackStartGate = new(1, 1);
    private readonly SemaphoreSlim playbackStateGate = new(1, 1);
    private nint swapChainPanelNative;
    private nint activePresenter;
    private int renderWidth = 1280;
    private int renderHeight = 720;
    private Task? activePlaybackTask;
    private static nint nativeLibraryHandle;

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
        if (nativePointer != 0) {
            swapChainPanelNative = nativePointer;
            UpdateRenderTargetSize(panel);
        }
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
        await playbackStartGate.WaitAsync();
        nint presenter = 0;
        Task<string>? playbackTask = null;
        try {
            await StopAsync();

            if (!EnsureNativeLibraryLoaded()) {
                throw new InvalidOperationException("Native playback backend is not available.");
            }
            if (swapChainPanelNative == 0) {
                throw new InvalidOperationException("Embedded playback surface is not ready.");
            }

            nint panelNative = swapChainPanelNative;
            int targetWidth = renderWidth;
            int targetHeight = renderHeight;
            nint createError = 0;
            try {
                int createResult = CueSeekerPlaybackCreateSwapChainPanelPresenter(panelNative, targetWidth, targetHeight, out presenter, out createError);
                if (createResult != 0) {
                    throw new InvalidOperationException(ReadUtf8(createError) ?? "Native playback presenter creation failed.");
                }
            } finally {
                CueSeekerPlaybackFreeString(createError);
            }

            playbackTask = Task.Run(() => {
                NativePlaybackOptions options = new() {
                    MediaPath = mediaPath,
                    SubtitlePath = subtitlePath,
                    ReportPath = reportPath,
                    SeekMilliseconds = seekMilliseconds,
                    DurationMilliseconds = durationMilliseconds,
                    DecodePreference = decodePreference,
                    SwapChainPanel = panelNative,
                    RenderWidth = targetWidth,
                    RenderHeight = targetHeight,
                    RendererPresenter = presenter,
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

            await playbackStateGate.WaitAsync();
            try {
                activePresenter = presenter;
                activePlaybackTask = playbackTask;
            } finally {
                playbackStateGate.Release();
            }
        } catch {
            if (presenter != 0) {
                CueSeekerPlaybackDestroyPresenter(presenter);
            }
            throw;
        } finally {
            playbackStartGate.Release();
        }

        try {
            return await playbackTask;
        } finally {
            await playbackStateGate.WaitAsync();
            try {
                if (activePresenter == presenter) {
                    activePresenter = 0;
                    activePlaybackTask = null;
                }
            } finally {
                playbackStateGate.Release();
            }
            CueSeekerPlaybackDestroyPresenter(presenter);
        }
    }

    public async Task StopAsync()
    {
        nint presenterToStop;
        Task? taskToWait;
        await playbackStateGate.WaitAsync();
        try {
            presenterToStop = activePresenter;
            taskToWait = activePlaybackTask;
            if (presenterToStop != 0) {
                CueSeekerPlaybackStopPresenter(presenterToStop);
            }
        } finally {
            playbackStateGate.Release();
        }

        if (taskToWait is not null) {
            try {
                await taskToWait;
            } catch {
                // Replacing playback should not surface the previous session's terminal error.
            }
        }
    }

    private static bool EnsureNativeLibraryLoaded()
    {
        if (nativeLibraryHandle != 0) {
            return true;
        }

        if (NativeLibrary.TryLoad("CueSeekerPlaybackNative.dll", out nativeLibraryHandle)) {
            return true;
        }

        string? nativePath = FindNativeLibraryPath();
        return nativePath is not null && NativeLibrary.TryLoad(nativePath, out nativeLibraryHandle);
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

    private void UpdateRenderTargetSize(SwapChainPanel panel)
    {
        double scale = panel.XamlRoot?.RasterizationScale ?? 1.0;
        double logicalWidth = panel.ActualWidth > 0 ? panel.ActualWidth : (double.IsNaN(panel.Width) ? 0 : panel.Width);
        double logicalHeight = panel.ActualHeight > 0 ? panel.ActualHeight : (double.IsNaN(panel.Height) ? 0 : panel.Height);
        int width = (int)Math.Round(logicalWidth * scale);
        int height = (int)Math.Round(logicalHeight * scale);
        renderWidth = width > 0 ? width : renderWidth;
        renderHeight = height > 0 ? height : renderHeight;
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
    private static extern int CueSeekerPlaybackCreateSwapChainPanelPresenter(
        nint swapChainPanel,
        int renderWidth,
        int renderHeight,
        out nint rendererPresenter,
        out nint errorMessage);

    [DllImport("CueSeekerPlaybackNative.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void CueSeekerPlaybackDestroyPresenter(nint rendererPresenter);

    [DllImport("CueSeekerPlaybackNative.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void CueSeekerPlaybackStopPresenter(nint rendererPresenter);

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
        public nint SwapChainPanel;
        public int RenderWidth;
        public int RenderHeight;
        public nint RendererPresenter;
    }
}

internal enum DecodePreference
{
    Auto = 0,
    Software = 1,
    D3D11VA = 2,
}
