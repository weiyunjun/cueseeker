#include <windows.h>

#include "cueseeker_playback.h"

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <cwctype>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>

namespace {

struct NativeString {
    char* value = nullptr;

    ~NativeString()
    {
        CueSeekerPlaybackFreeString(value);
    }
};

enum class Mode {
    Help,
    Inspect,
    RenderTest,
    Play,
};

struct CliOptions {
    Mode mode = Mode::Help;
    std::wstring mediaPath;
    std::optional<std::wstring> subtitlePath;
    std::optional<std::wstring> reportPath;
    CueSeekerPlaybackDecodePreference decodePreference = CUESEEKER_PLAYBACK_DECODE_AUTO;
    int64_t seekMs = 0;
    int64_t durationMs = 15000;
};

void writeUtf8ToStdout(const char* value)
{
    if (!value) {
        return;
    }
    std::fwrite(value, 1, std::strlen(value), stdout);
    std::fflush(stdout);
}

void writeUtf8ToStderr(const char* value)
{
    if (!value) {
        return;
    }
    std::fwrite(value, 1, std::strlen(value), stderr);
    std::fflush(stderr);
}

void printUsage()
{
    std::cout
        << "CueSeekerWindowsPlaybackLab\n"
        << "\n"
        << "Usage:\n"
        << "  CueSeekerWindowsPlaybackLab --inspect <media-file> [--subtitle <ass-file>]\n"
        << "  CueSeekerWindowsPlaybackLab --render-test\n"
        << "  CueSeekerWindowsPlaybackLab --play <media-file> [--subtitle <ass-file>] [--decode auto|software|d3d11va] [--seek-ms ms] [--duration-ms ms] [--report-path json-file]\n"
        << "\n"
        << "The lab is a command-line harness over CueSeeker.Playback.Native.\n";
}

CueSeekerPlaybackDecodePreference parseDecodePreference(std::wstring value)
{
    for (wchar_t& ch : value) {
        ch = static_cast<wchar_t>(std::towlower(ch));
    }
    if (value == L"auto") {
        return CUESEEKER_PLAYBACK_DECODE_AUTO;
    }
    if (value == L"software") {
        return CUESEEKER_PLAYBACK_DECODE_SOFTWARE;
    }
    if (value == L"d3d11va" || value == L"dxva") {
        return CUESEEKER_PLAYBACK_DECODE_D3D11VA;
    }
    throw std::runtime_error("Unknown --decode value");
}

CliOptions parseArgs(int argc, wchar_t** argv)
{
    CliOptions options;
    for (int i = 1; i < argc; ++i) {
        const std::wstring arg = argv[i];
        if (arg == L"--help" || arg == L"-h") {
            options.mode = Mode::Help;
            return options;
        }
        if (arg == L"--inspect") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--inspect requires a media file");
            }
            options.mode = Mode::Inspect;
            options.mediaPath = argv[++i];
            continue;
        }
        if (arg == L"--render-test") {
            options.mode = Mode::RenderTest;
            continue;
        }
        if (arg == L"--play") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--play requires a media file");
            }
            options.mode = Mode::Play;
            options.mediaPath = argv[++i];
            continue;
        }
        if (arg == L"--seek-ms") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--seek-ms requires a value");
            }
            options.seekMs = std::wcstoll(argv[++i], nullptr, 10);
            continue;
        }
        if (arg == L"--duration-ms") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--duration-ms requires a value");
            }
            options.durationMs = std::wcstoll(argv[++i], nullptr, 10);
            continue;
        }
        if (arg == L"--subtitle") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--subtitle requires an ASS subtitle file");
            }
            options.subtitlePath = argv[++i];
            continue;
        }
        if (arg == L"--report-path") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--report-path requires a JSON file path");
            }
            options.reportPath = argv[++i];
            continue;
        }
        if (arg == L"--decode") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--decode requires auto, software, or d3d11va");
            }
            options.decodePreference = parseDecodePreference(argv[++i]);
            continue;
        }

        throw std::runtime_error("Unknown argument");
    }

    return options;
}

const wchar_t* optionalPath(const std::optional<std::wstring>& value)
{
    return value ? value->c_str() : nullptr;
}

int runInspect(const CliOptions& options)
{
    NativeString report;
    NativeString error;
    const int result = CueSeekerPlaybackInspectJson(
        options.mediaPath.c_str(),
        optionalPath(options.subtitlePath),
        &report.value,
        &error.value);
    if (result != 0) {
        writeUtf8ToStderr("CueSeekerWindowsPlaybackLab failed: ");
        writeUtf8ToStderr(error.value);
        writeUtf8ToStderr("\n");
        return result;
    }
    writeUtf8ToStdout(report.value);
    return 0;
}

int runPlay(const CliOptions& options)
{
    CueSeekerPlaybackOptions playbackOptions = {};
    playbackOptions.media_path = options.mediaPath.c_str();
    playbackOptions.subtitle_path = optionalPath(options.subtitlePath);
    playbackOptions.report_path = optionalPath(options.reportPath);
    playbackOptions.seek_ms = options.seekMs;
    playbackOptions.duration_ms = options.durationMs;
    playbackOptions.decode_preference = options.decodePreference;

    NativeString error;
    const int result = CueSeekerPlaybackPlay(&playbackOptions, &error.value);
    if (result != 0) {
        writeUtf8ToStderr("CueSeekerWindowsPlaybackLab failed: ");
        writeUtf8ToStderr(error.value);
        writeUtf8ToStderr("\n");
        return result;
    }
    return 0;
}

} // namespace

int wmain(int argc, wchar_t** argv)
{
    try {
        const CliOptions options = parseArgs(argc, argv);
        switch (options.mode) {
        case Mode::Help:
            printUsage();
            return 0;
        case Mode::Inspect:
            return runInspect(options);
        case Mode::RenderTest: {
            NativeString error;
            const int result = CueSeekerPlaybackRunRenderTest(&error.value);
            if (result != 0) {
                writeUtf8ToStderr("CueSeekerWindowsPlaybackLab failed: ");
                writeUtf8ToStderr(error.value);
                writeUtf8ToStderr("\n");
            }
            return result;
        }
        case Mode::Play:
            return runPlay(options);
        }

        printUsage();
        return 2;
    } catch (const std::exception& error) {
        std::cerr << "CueSeekerWindowsPlaybackLab failed: " << error.what() << "\n";
        return 1;
    }
}
