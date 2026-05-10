using CueSeeker.Windows.Playback;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace CueSeeker.Windows;

public sealed partial class MainWindow : Window
{
    private readonly NativePlaybackHost playbackHost = new();

    public MainWindow()
    {
        InitializeComponent();
        BackendStatusText.Text = playbackHost.IsNativeLibraryAvailable
            ? "Native backend available"
            : "Native backend not loaded";
    }

    private void PlaybackSurface_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is not SwapChainPanel panel) {
            return;
        }

        PlaybackSurfaceStatusText.Text = playbackHost.TryCaptureSwapChainPanel(panel, out nint panelNative)
            ? $"SwapChainPanel ready: 0x{panelNative.ToInt64():X}"
            : "SwapChainPanel native pointer unavailable";
    }
}
