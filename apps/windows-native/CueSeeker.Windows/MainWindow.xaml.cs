using System.Diagnostics;
using CueSeeker.Windows.Core;
using CueSeeker.Windows.Data;
using CueSeeker.Windows.Playback;
using CueSeeker.Windows.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace CueSeeker.Windows;

public sealed partial class MainWindow : Window
{
    private readonly NativePlaybackHost playbackHost = new();
    private readonly SubtitleDatabase database = new(SubtitleDatabase.DefaultPath);
    private readonly SubtitleIndexer indexer = new();
    private readonly HashSet<string> expandedLibraryFolders = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> collapsedSearchGroups = new(StringComparer.OrdinalIgnoreCase);
    private DecodePreference decodePreference;
    private string? currentVideoPath;
    private string? currentSubtitlePath;

    public MainWindow()
    {
        InitializeComponent();
        decodePreference = LoadDecodePreference();
        BackendStatusText.Text = playbackHost.IsNativeLibraryAvailable
            ? "Native backend available"
            : "Native backend not loaded";

        try {
            database.Migrate();
            RefreshLibrary();
            RefreshSearch();
        } catch (Exception error) {
            PlaybackStatusText.Text = $"Database initialization failed: {error.Message}";
        }
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

    private async void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        await ShowSettingsDialogAsync();
    }

    private void SearchModeButton_Click(object sender, RoutedEventArgs e)
    {
        SearchPanel.Visibility = Visibility.Visible;
        ShioriPanel.Visibility = Visibility.Collapsed;
    }

    private void ShioriModeButton_Click(object sender, RoutedEventArgs e)
    {
        SearchPanel.Visibility = Visibility.Collapsed;
        ShioriPanel.Visibility = Visibility.Visible;
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        RefreshSearch();
    }

    private void VideoFolderButton_Click(object sender, RoutedEventArgs e)
    {
        if (currentVideoPath is not null) {
            RevealInExplorer(currentVideoPath);
        }
    }

    private void SubtitleFolderButton_Click(object sender, RoutedEventArgs e)
    {
        if (currentSubtitlePath is not null) {
            RevealInExplorer(currentSubtitlePath);
        }
    }

    private async Task ShowSettingsDialogAsync()
    {
        ListView folderList = new() {
            SelectionMode = ListViewSelectionMode.Single,
            MinHeight = 180,
        };
        TextBlock statusText = new() {
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            TextWrapping = TextWrapping.Wrap,
            Text = "Manage indexed folders and run Index Now.",
        };

        void RefreshFolderList()
        {
            folderList.Items.Clear();
            foreach (string path in database.SearchPaths()) {
                folderList.Items.Add(path);
            }
        }

        RefreshFolderList();

        Button addFolderButton = new() { Content = "Add Folder" };
        Button removeFolderButton = new() { Content = "Remove Selected" };
        Button indexNowButton = new() { Content = "Index Now" };

        addFolderButton.Click += async (_, _) => {
            FolderPicker picker = new() {
                SuggestedStartLocation = PickerLocationId.VideosLibrary,
            };
            picker.FileTypeFilter.Add("*");
            InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
            global::Windows.Storage.StorageFolder? folder = await picker.PickSingleFolderAsync();
            if (folder is null) {
                return;
            }

            database.AddSearchPath(folder.Path);
            RefreshFolderList();
            RefreshLibrary();
            statusText.Text = $"Added {folder.Path}.";
        };

        removeFolderButton.Click += (_, _) => {
            if (folderList.SelectedItem is not string selectedPath) {
                return;
            }

            database.RemoveSearchPath(selectedPath);
            RefreshFolderList();
            RefreshLibrary();
            RefreshSearch();
            statusText.Text = $"Removed {selectedPath}. Local files were not deleted.";
        };

        indexNowButton.Click += async (_, _) => {
            IReadOnlyList<string> folders = database.SearchPaths();
            if (folders.Count == 0) {
                statusText.Text = "No folders configured.";
                return;
            }

            statusText.Text = "Indexing...";
            indexNowButton.IsEnabled = false;
            try {
                SubtitleIndexingResult[] results = await Task.Run(() => folders.Select(folder => indexer.Index(folder, database)).ToArray());
                int scanned = results.Sum(result => result.ScannedSubtitleFiles);
                int indexed = results.Sum(result => result.IndexedSubtitleFiles);
                int skippedMissingVideo = results.Sum(result => result.SkippedMissingVideo);
                int skippedUnchanged = results.Sum(result => result.SkippedUnchangedSubtitleFiles);
                statusText.Text = $"Indexed {indexed} of {scanned} subtitle files. Missing video: {skippedMissingVideo}. Unchanged: {skippedUnchanged}.";
                RefreshLibrary();
                RefreshSearch();
            } catch (Exception error) {
                statusText.Text = $"Index failed: {error.Message}";
            } finally {
                indexNowButton.IsEnabled = true;
            }
        };

        StackPanel libraryPanel = new() { Spacing = 10 };
        libraryPanel.Children.Add(new TextBlock { Text = "Indexed Folders", FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        libraryPanel.Children.Add(folderList);
        libraryPanel.Children.Add(new StackPanel {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            Children = {
                addFolderButton,
                removeFolderButton,
                indexNowButton,
            },
        });
        libraryPanel.Children.Add(statusText);

        ComboBox decodeCombo = new();
        decodeCombo.Items.Add("auto");
        decodeCombo.Items.Add("software");
        decodeCombo.Items.Add("d3d11va");
        decodeCombo.SelectedItem = DecodePreferenceToText(decodePreference);
        decodeCombo.SelectionChanged += (_, _) => {
            if (decodeCombo.SelectedItem is string selected) {
                decodePreference = DecodePreferenceFromText(selected);
                SaveDecodePreference(decodePreference);
            }
        };
        StackPanel decodePanel = new() { Spacing = 10, Visibility = Visibility.Collapsed };
        decodePanel.Children.Add(new TextBlock { Text = "Decode", FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        decodePanel.Children.Add(new TextBlock {
            Text = "Select the preferred native playback decode path.",
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        });
        decodePanel.Children.Add(decodeCombo);

        Button libraryTab = new() { Content = "Library", HorizontalAlignment = HorizontalAlignment.Stretch };
        Button decodeTab = new() { Content = "Decode", HorizontalAlignment = HorizontalAlignment.Stretch };
        libraryTab.Click += (_, _) => {
            libraryPanel.Visibility = Visibility.Visible;
            decodePanel.Visibility = Visibility.Collapsed;
        };
        decodeTab.Click += (_, _) => {
            libraryPanel.Visibility = Visibility.Collapsed;
            decodePanel.Visibility = Visibility.Visible;
        };

        Grid content = new() {
            ColumnDefinitions = {
                new ColumnDefinition { Width = new GridLength(150) },
                new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) },
            },
            MinWidth = 640,
            MinHeight = 360,
        };
        StackPanel categoryPanel = new() { Spacing = 8 };
        categoryPanel.Children.Add(libraryTab);
        categoryPanel.Children.Add(decodeTab);
        content.Children.Add(categoryPanel);

        Grid detail = new();
        detail.Children.Add(libraryPanel);
        detail.Children.Add(decodePanel);
        Grid.SetColumn(detail, 1);
        content.Children.Add(detail);

        ContentDialog dialog = new() {
            Title = "Settings",
            Content = content,
            CloseButtonText = "Close",
            XamlRoot = ((FrameworkElement)Content).XamlRoot,
        };
        await dialog.ShowAsync();
    }

    private void RefreshLibrary()
    {
        IReadOnlyList<LibraryFolderPresentation> groups = database.LibraryPresentation();
        LibraryStack.Children.Clear();
        LibraryEmptyText.Visibility = groups.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        if (groups.Count == 0) {
            LibraryStack.Children.Add(LibraryEmptyText);
            return;
        }

        foreach (LibraryFolderPresentation group in groups) {
            bool expanded = expandedLibraryFolders.Contains(group.FolderPath);
            Button folderButton = new() {
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Stretch,
                Padding = new Thickness(10, 8, 10, 8),
                Content = new Grid {
                    ColumnDefinitions = {
                        new ColumnDefinition { Width = GridLength.Auto },
                        new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) },
                    },
                    Children = {
                        new TextBlock {
                            Text = expanded ? "v" : ">",
                            Width = 18,
                            VerticalAlignment = VerticalAlignment.Center,
                        },
                        FolderText(group),
                    },
                },
            };
            if (folderButton.Content is Grid grid && grid.Children.Count > 1 && grid.Children[1] is FrameworkElement folderText) {
                Grid.SetColumn(folderText, 1);
            }
            folderButton.Click += (_, _) => {
                if (!expandedLibraryFolders.Add(group.FolderPath)) {
                    expandedLibraryFolders.Remove(group.FolderPath);
                }
                RefreshLibrary();
            };
            LibraryStack.Children.Add(folderButton);

            if (expanded) {
                AddEpisodeGrid(group);
            }
        }
    }

    private static StackPanel FolderText(LibraryFolderPresentation group)
    {
        StackPanel panel = new() { Spacing = 2 };
        panel.Children.Add(new TextBlock {
            Text = group.FolderTitle,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            TextTrimming = TextTrimming.CharacterEllipsis,
        });
        panel.Children.Add(new TextBlock {
            Text = group.Videos.Count == 1 ? "1 episode" : $"{group.Videos.Count} episodes",
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            FontSize = 12,
        });
        return panel;
    }

    private void AddEpisodeGrid(LibraryFolderPresentation group)
    {
        int columns = 4;
        int rankWidth = Math.Max(2, group.Videos.Count.ToString().Length);
        for (int rowStart = 0; rowStart < group.Videos.Count; rowStart += columns) {
            Grid row = new() {
                Margin = new Thickness(28, 2, 0, 6),
                ColumnSpacing = 8,
            };
            for (int column = 0; column < columns; column++) {
                row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            }

            for (int column = 0; column < columns && rowStart + column < group.Videos.Count; column++) {
                int index = rowStart + column;
                LibraryVideoPresentation video = group.Videos[index];
                Button button = new() {
                    Content = (index + 1).ToString().PadLeft(rankWidth, '0'),
                    MinWidth = 44,
                    Height = 36,
                    Tag = video,
                };
                button.Click += (_, _) => _ = StartPlaybackAsync(video.VideoPath, video.SubtitlePath, 0, "Library");
                Grid.SetColumn(button, column);
                row.Children.Add(button);
            }

            LibraryStack.Children.Add(row);
        }
    }

    private void RefreshSearch()
    {
        SearchResultsPanel.Children.Clear();
        SubtitleSearchPage page;
        try {
            page = database.SearchPage(SearchBox.Text, 100);
        } catch (Exception error) {
            SearchSummaryText.Text = $"Search failed: {error.Message}";
            return;
        }

        if (string.IsNullOrWhiteSpace(SearchBox.Text)) {
            SearchSummaryText.Text = "No query.";
            return;
        }

        SearchSummaryText.Text = $"Found {page.TotalCount} results in {page.FileSummaries.Count} files";
        Dictionary<string, List<SubtitleSearchResult>> resultsBySubtitle = page.Results
            .GroupBy(result => result.SubtitlePath, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.ToList(), StringComparer.OrdinalIgnoreCase);

        foreach (SubtitleSearchFileSummary summary in page.FileSummaries) {
            bool collapsed = collapsedSearchGroups.Contains(summary.SubtitlePath);
            Button header = new() {
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Stretch,
                Padding = new Thickness(8, 6, 8, 6),
                Content = $"{(collapsed ? ">" : "v")} {summary.SubtitleDisplayTitle}  {summary.MatchCount} {(summary.MatchCount == 1 ? "result" : "results")}",
            };
            header.Click += (_, _) => {
                if (!collapsedSearchGroups.Add(summary.SubtitlePath)) {
                    collapsedSearchGroups.Remove(summary.SubtitlePath);
                }
                RefreshSearch();
            };
            SearchResultsPanel.Children.Add(header);

            if (collapsed || !resultsBySubtitle.TryGetValue(summary.SubtitlePath, out List<SubtitleSearchResult>? results)) {
                continue;
            }

            foreach (SubtitleSearchResult result in results) {
                Button row = new() {
                    HorizontalAlignment = HorizontalAlignment.Stretch,
                    HorizontalContentAlignment = HorizontalAlignment.Stretch,
                    Padding = new Thickness(18, 8, 8, 8),
                    Content = new StackPanel {
                        Spacing = 3,
                        Children = {
                            new TextBlock {
                                Text = string.Join(Environment.NewLine, result.CueLines),
                                TextWrapping = TextWrapping.Wrap,
                            },
                            new TextBlock {
                                Text = FormatMilliseconds(result.StartMilliseconds),
                                FontSize = 12,
                                Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
                            },
                        },
                    },
                };
                row.Click += (_, _) => _ = StartPlaybackAsync(result.VideoPath, result.SubtitlePath, result.StartMilliseconds, "Search");
                SearchResultsPanel.Children.Add(row);
            }
        }
    }

    private async Task StartPlaybackAsync(string videoPath, string subtitlePath, int seekMilliseconds, string source)
    {
        currentVideoPath = videoPath;
        currentSubtitlePath = subtitlePath;
        VideoFolderButton.IsEnabled = true;
        SubtitleFolderButton.IsEnabled = true;
        string reportPath = Path.Combine(Path.GetDirectoryName(SubtitleDatabase.DefaultPath)!, "last-playback.json");
        PlaybackStatusText.Text = $"{source}: starting {Path.GetFileName(videoPath)} at {FormatMilliseconds(seekMilliseconds)}";
        try {
            _ = await playbackHost.PlayAsync(videoPath, subtitlePath, reportPath, seekMilliseconds, decodePreference);
            PlaybackStatusText.Text = $"{source}: playback ended. Report: {reportPath}";
        } catch (Exception error) {
            PlaybackStatusText.Text = $"{source}: playback failed: {error.Message}";
        }
    }

    private static void RevealInExplorer(string path)
    {
        if (!File.Exists(path)) {
            return;
        }

        Process.Start(new ProcessStartInfo {
            FileName = "explorer.exe",
            Arguments = $"/select,\"{path}\"",
            UseShellExecute = true,
        });
    }

    private static string FormatMilliseconds(int milliseconds)
    {
        TimeSpan value = TimeSpan.FromMilliseconds(milliseconds);
        return value.Hours > 0
            ? value.ToString(@"h\:mm\:ss")
            : value.ToString(@"m\:ss");
    }

    private static string DecodePreferenceToText(DecodePreference preference)
    {
        return preference switch {
            DecodePreference.Software => "software",
            DecodePreference.D3D11VA => "d3d11va",
            _ => "auto",
        };
    }

    private static DecodePreference DecodePreferenceFromText(string text)
    {
        return text switch {
            "software" => DecodePreference.Software,
            "d3d11va" => DecodePreference.D3D11VA,
            _ => DecodePreference.Auto,
        };
    }

    private static DecodePreference LoadDecodePreference()
    {
        string path = DecodePreferencePath();
        return File.Exists(path)
            ? DecodePreferenceFromText(File.ReadAllText(path).Trim())
            : DecodePreference.Auto;
    }

    private static void SaveDecodePreference(DecodePreference preference)
    {
        string path = DecodePreferencePath();
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, DecodePreferenceToText(preference));
    }

    private static string DecodePreferencePath()
    {
        return Path.Combine(Path.GetDirectoryName(SubtitleDatabase.DefaultPath)!, "decode-preference.txt");
    }
}
