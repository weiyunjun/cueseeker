#include <windows.h>
#include <audioclient.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <propkeydef.h>
#include <functiondiscoverykeys_devpkey.h>
#include <mmdeviceapi.h>
#include <mmreg.h>
#include <psapi.h>
#include <propsys.h>
#include <wrl/client.h>

#include <algorithm>
#include <chrono>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <memory>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <thread>
#include <vector>

#if CUESEEKER_HAS_LIBASS_HEADER
extern "C" {
#include <ass/ass.h>
}
#elif CUESEEKER_HAS_LIBASS_SDK
extern "C" int ass_library_version(void);
#endif

#if CUESEEKER_HAS_FFMPEG_SDK
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}
#endif

using Microsoft::WRL::ComPtr;

namespace {

struct ComInit {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

    ~ComInit()
    {
        if (SUCCEEDED(hr)) {
            CoUninitialize();
        }
    }
};

std::string wideToUtf8(std::wstring_view value)
{
    if (value.empty()) {
        return {};
    }

    const int size = WideCharToMultiByte(
        CP_UTF8,
        0,
        value.data(),
        static_cast<int>(value.size()),
        nullptr,
        0,
        nullptr,
        nullptr);
    if (size <= 0) {
        throw std::runtime_error("WideCharToMultiByte failed");
    }

    std::string result(size, '\0');
    WideCharToMultiByte(
        CP_UTF8,
        0,
        value.data(),
        static_cast<int>(value.size()),
        result.data(),
        size,
        nullptr,
        nullptr);
    return result;
}

std::wstring utf8ToWide(std::string_view value)
{
    if (value.empty()) {
        return {};
    }

    const int size = MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        value.data(),
        static_cast<int>(value.size()),
        nullptr,
        0);
    if (size <= 0) {
        throw std::runtime_error("MultiByteToWideChar failed");
    }

    std::wstring result(size, L'\0');
    MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        value.data(),
        static_cast<int>(value.size()),
        result.data(),
        size);
    return result;
}

std::filesystem::path pathFromUtf8(const std::string& path)
{
    return std::filesystem::path(utf8ToWide(path));
}

std::string jsonEscape(std::string_view value)
{
    std::ostringstream out;
    for (const unsigned char ch : value) {
        switch (ch) {
        case '\\':
            out << "\\\\";
            break;
        case '"':
            out << "\\\"";
            break;
        case '\b':
            out << "\\b";
            break;
        case '\f':
            out << "\\f";
            break;
        case '\n':
            out << "\\n";
            break;
        case '\r':
            out << "\\r";
            break;
        case '\t':
            out << "\\t";
            break;
        default:
            if (ch < 0x20) {
                out << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(ch);
            } else {
                out << ch;
            }
            break;
        }
    }
    return out.str();
}

void writeUtf8TextFile(const std::string& path, std::string_view contents)
{
    const std::filesystem::path filePath = pathFromUtf8(path);
    std::error_code ec;
    if (filePath.has_parent_path()) {
        std::filesystem::create_directories(filePath.parent_path(), ec);
        if (ec) {
            throw std::runtime_error("Could not create report directory: " + ec.message());
        }
    }

    std::ofstream output(filePath, std::ios::binary);
    if (!output) {
        throw std::runtime_error("Could not open report file for writing");
    }
    output.write(contents.data(), static_cast<std::streamsize>(contents.size()));
    if (!output) {
        throw std::runtime_error("Could not write report file");
    }
}

std::string lowerAscii(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    return value;
}

uint64_t fileTimeTicks(const FILETIME& value)
{
    ULARGE_INTEGER result = {};
    result.LowPart = value.dwLowDateTime;
    result.HighPart = value.dwHighDateTime;
    return result.QuadPart;
}

uint64_t fileTimeDeltaMs(const FILETIME& start, const FILETIME& end)
{
    const uint64_t startTicks = fileTimeTicks(start);
    const uint64_t endTicks = fileTimeTicks(end);
    return endTicks > startTicks ? (endTicks - startTicks) / 10'000 : 0;
}

struct ProcessTelemetrySnapshot {
    bool memoryOk = false;
    bool cpuOk = false;
    uint64_t workingSetBytes = 0;
    uint64_t peakWorkingSetBytes = 0;
    uint64_t privateBytes = 0;
    FILETIME kernelTime = {};
    FILETIME userTime = {};
};

ProcessTelemetrySnapshot captureProcessTelemetry()
{
    ProcessTelemetrySnapshot snapshot;

    PROCESS_MEMORY_COUNTERS_EX memoryCounters = {};
    memoryCounters.cb = sizeof(memoryCounters);
    if (GetProcessMemoryInfo(
            GetCurrentProcess(),
            reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memoryCounters),
            sizeof(memoryCounters))) {
        snapshot.memoryOk = true;
        snapshot.workingSetBytes = static_cast<uint64_t>(memoryCounters.WorkingSetSize);
        snapshot.peakWorkingSetBytes = static_cast<uint64_t>(memoryCounters.PeakWorkingSetSize);
        snapshot.privateBytes = static_cast<uint64_t>(memoryCounters.PrivateUsage);
    }

    FILETIME creationTime = {};
    FILETIME exitTime = {};
    if (GetProcessTimes(GetCurrentProcess(), &creationTime, &exitTime, &snapshot.kernelTime, &snapshot.userTime)) {
        snapshot.cpuOk = true;
    }

    return snapshot;
}

struct ProcessTelemetry {
    ProcessTelemetrySnapshot start;
    ProcessTelemetrySnapshot end;
    uint64_t peakWorkingSetBytes = 0;
    uint64_t peakPrivateBytes = 0;
    int64_t wallElapsedMs = 0;
};

void startProcessTelemetry(ProcessTelemetry& telemetry)
{
    telemetry.start = captureProcessTelemetry();
    telemetry.end = telemetry.start;
    telemetry.peakWorkingSetBytes = telemetry.start.workingSetBytes;
    telemetry.peakPrivateBytes = telemetry.start.privateBytes;
}

void sampleProcessTelemetry(ProcessTelemetry& telemetry)
{
    telemetry.end = captureProcessTelemetry();
    if (telemetry.end.memoryOk) {
        telemetry.peakWorkingSetBytes = std::max(telemetry.peakWorkingSetBytes, telemetry.end.workingSetBytes);
        telemetry.peakWorkingSetBytes = std::max(telemetry.peakWorkingSetBytes, telemetry.end.peakWorkingSetBytes);
        telemetry.peakPrivateBytes = std::max(telemetry.peakPrivateBytes, telemetry.end.privateBytes);
    }
}

void finishProcessTelemetry(ProcessTelemetry& telemetry, std::chrono::steady_clock::time_point wallStart)
{
    sampleProcessTelemetry(telemetry);
    telemetry.wallElapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - wallStart)
                                  .count();
}

struct PlaybackReport {
    std::string mediaPath;
    std::optional<std::string> subtitlePath;
    int64_t seekMs = 0;
    int64_t requestedDurationMs = 0;
    bool success = false;
    std::string failureStage;
    std::string error;
    std::string completionReason = "unknown";
    std::string decodePathRequested = "software";
    std::string decodePathUsed = "software";
    int videoStreamIndex = -1;
    std::string videoCodec = "unknown";
    std::string videoDecoder = "unknown";
    std::string pixelFormat = "unknown";
    int videoWidth = 0;
    int videoHeight = 0;
    int audioStreamIndex = -1;
    std::string audioCodec = "none";
    std::string audioDecoder = "none";
    int audioInputSampleRate = 0;
    int audioInputChannels = 0;
    std::string audioOutput = "none";
    std::string audioEndpoint;
    std::string audioMixFormat;
    std::string subtitleOverlay = "none";
    int subtitleEvents = 0;
    int subtitleStyles = 0;
    int64_t firstFrameMs = -1;
    uint64_t videoFramesDecoded = 0;
    uint64_t videoFramesRendered = 0;
    uint64_t audioFramesDecoded = 0;
    uint64_t audioSampleFramesWritten = 0;
    ProcessTelemetry process;
};

void writePlaybackReport(const std::string& reportPath, const PlaybackReport& report)
{
    std::ostringstream out;
    out << "{\n";
    out << "  \"schema\": \"cueseeker.windows_playback_lab.playback_report.v0\",\n";
    out << "  \"request\": {\n";
    out << "    \"media_path\": \"" << jsonEscape(report.mediaPath) << "\",\n";
    if (report.subtitlePath) {
        out << "    \"subtitle_path\": \"" << jsonEscape(*report.subtitlePath) << "\",\n";
    } else {
        out << "    \"subtitle_path\": null,\n";
    }
    out << "    \"seek_ms\": " << report.seekMs << ",\n";
    out << "    \"duration_ms\": " << report.requestedDurationMs << "\n";
    out << "  },\n";
    out << "  \"playback\": {\n";
    out << "    \"success\": " << (report.success ? "true" : "false") << ",\n";
    if (report.failureStage.empty()) {
        out << "    \"failure_stage\": null,\n";
    } else {
        out << "    \"failure_stage\": \"" << jsonEscape(report.failureStage) << "\",\n";
    }
    if (report.error.empty()) {
        out << "    \"error\": null,\n";
    } else {
        out << "    \"error\": \"" << jsonEscape(report.error) << "\",\n";
    }
    out << "    \"completion_reason\": \"" << jsonEscape(report.completionReason) << "\",\n";
    out << "    \"first_frame_ms\": " << report.firstFrameMs << "\n";
    out << "  },\n";
    out << "  \"decode\": {\n";
    out << "    \"path_requested\": \"" << jsonEscape(report.decodePathRequested) << "\",\n";
    out << "    \"path_used\": \"" << jsonEscape(report.decodePathUsed) << "\",\n";
    out << "    \"fallback_used\": false\n";
    out << "  },\n";
    out << "  \"video\": {\n";
    out << "    \"stream_index\": " << report.videoStreamIndex << ",\n";
    out << "    \"codec\": \"" << jsonEscape(report.videoCodec) << "\",\n";
    out << "    \"decoder\": \"" << jsonEscape(report.videoDecoder) << "\",\n";
    out << "    \"pixel_format\": \"" << jsonEscape(report.pixelFormat) << "\",\n";
    out << "    \"width\": " << report.videoWidth << ",\n";
    out << "    \"height\": " << report.videoHeight << ",\n";
    out << "    \"frames_decoded\": " << report.videoFramesDecoded << ",\n";
    out << "    \"frames_rendered\": " << report.videoFramesRendered << "\n";
    out << "  },\n";
    out << "  \"audio\": {\n";
    out << "    \"stream_index\": " << report.audioStreamIndex << ",\n";
    out << "    \"codec\": \"" << jsonEscape(report.audioCodec) << "\",\n";
    out << "    \"decoder\": \"" << jsonEscape(report.audioDecoder) << "\",\n";
    out << "    \"input_sample_rate\": " << report.audioInputSampleRate << ",\n";
    out << "    \"input_channels\": " << report.audioInputChannels << ",\n";
    out << "    \"output\": \"" << jsonEscape(report.audioOutput) << "\",\n";
    if (report.audioEndpoint.empty()) {
        out << "    \"endpoint\": null,\n";
    } else {
        out << "    \"endpoint\": \"" << jsonEscape(report.audioEndpoint) << "\",\n";
    }
    if (report.audioMixFormat.empty()) {
        out << "    \"mix_format\": null,\n";
    } else {
        out << "    \"mix_format\": \"" << jsonEscape(report.audioMixFormat) << "\",\n";
    }
    out << "    \"frames_decoded\": " << report.audioFramesDecoded << ",\n";
    out << "    \"sample_frames_written\": " << report.audioSampleFramesWritten << "\n";
    out << "  },\n";
    out << "  \"subtitles\": {\n";
    out << "    \"overlay\": \"" << jsonEscape(report.subtitleOverlay) << "\",\n";
    out << "    \"external_ass_provided\": " << (report.subtitlePath ? "true" : "false") << ",\n";
    out << "    \"events\": " << report.subtitleEvents << ",\n";
    out << "    \"styles\": " << report.subtitleStyles << "\n";
    out << "  },\n";
    out << "  \"performance\": {\n";
    out << "    \"wall_elapsed_ms\": " << report.process.wallElapsedMs << ",\n";
    out << "    \"process_cpu_user_ms\": "
        << (report.process.start.cpuOk && report.process.end.cpuOk ? fileTimeDeltaMs(report.process.start.userTime, report.process.end.userTime) : 0)
        << ",\n";
    out << "    \"process_cpu_kernel_ms\": "
        << (report.process.start.cpuOk && report.process.end.cpuOk ? fileTimeDeltaMs(report.process.start.kernelTime, report.process.end.kernelTime) : 0)
        << ",\n";
    out << "    \"working_set_start_bytes\": " << report.process.start.workingSetBytes << ",\n";
    out << "    \"working_set_end_bytes\": " << report.process.end.workingSetBytes << ",\n";
    out << "    \"working_set_peak_bytes\": " << report.process.peakWorkingSetBytes << ",\n";
    out << "    \"private_bytes_start\": " << report.process.start.privateBytes << ",\n";
    out << "    \"private_bytes_end\": " << report.process.end.privateBytes << ",\n";
    out << "    \"private_bytes_peak\": " << report.process.peakPrivateBytes << "\n";
    out << "  }\n";
    out << "}\n";

    writeUtf8TextFile(reportPath, out.str());
}

void throwIfFailed(HRESULT hr, const char* context)
{
    if (FAILED(hr)) {
        std::ostringstream out;
        out << context << " failed with HRESULT 0x" << std::hex << static_cast<unsigned long>(hr);
        throw std::runtime_error(out.str());
    }
}

std::string featureLevelName(D3D_FEATURE_LEVEL level)
{
    switch (level) {
    case D3D_FEATURE_LEVEL_12_1:
        return "12_1";
    case D3D_FEATURE_LEVEL_12_0:
        return "12_0";
    case D3D_FEATURE_LEVEL_11_1:
        return "11_1";
    case D3D_FEATURE_LEVEL_11_0:
        return "11_0";
    case D3D_FEATURE_LEVEL_10_1:
        return "10_1";
    case D3D_FEATURE_LEVEL_10_0:
        return "10_0";
    default:
        return "unknown";
    }
}

#if CUESEEKER_HAS_FFMPEG_SDK
std::string avError(int errorCode)
{
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {};
    av_strerror(errorCode, buffer, sizeof(buffer));
    return buffer;
}

std::string mediaTypeName(AVMediaType type)
{
    const char* name = av_get_media_type_string(type);
    return name ? name : "unknown";
}

std::string codecName(AVCodecID codecId)
{
    const char* name = avcodec_get_name(codecId);
    return name ? name : "unknown";
}

std::string pixelFormatName(AVPixelFormat format)
{
    const char* name = av_get_pix_fmt_name(format);
    return name ? name : "unknown";
}

std::string sampleFormatName(AVSampleFormat format)
{
    const char* name = av_get_sample_fmt_name(format);
    return name ? name : "unknown";
}

std::string streamMetadata(AVStream* stream, const char* key)
{
    AVDictionaryEntry* entry = av_dict_get(stream->metadata, key, nullptr, 0);
    return entry && entry->value ? entry->value : "";
}

int64_t streamDurationMs(AVStream* stream)
{
    if (stream->duration == AV_NOPTS_VALUE) {
        return -1;
    }
    return av_rescale_q(stream->duration, stream->time_base, AVRational { 1, 1000 });
}

bool isAssCompatibleSubtitleCodec(AVCodecID codecId)
{
    return codecId == AV_CODEC_ID_ASS || codecId == AV_CODEC_ID_SSA;
}
#endif

std::string adapterDescription(const DXGI_ADAPTER_DESC1& desc)
{
    return wideToUtf8(desc.Description);
}

void printPlatformReport(std::ostream& out)
{
    out << "  \"platform\": {\n";
    out << "    \"windows_build_probe\": \"native-lab\",\n";
    out << "    \"process_architecture\": \"";
#if defined(_M_X64)
    out << "x64";
#elif defined(_M_ARM64)
    out << "arm64";
#else
    out << "unknown";
#endif
    out << "\"\n";
    out << "  },\n";
}

void printD3DReport(std::ostream& out)
{
    out << "  \"d3d11\": {\n";

    ComPtr<IDXGIFactory1> factory;
    HRESULT hr = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
    if (FAILED(hr)) {
        out << "    \"available\": false,\n";
        out << "    \"error\": \"CreateDXGIFactory1 failed\"\n";
        out << "  },\n";
        return;
    }

    D3D_FEATURE_LEVEL selectedLevel = D3D_FEATURE_LEVEL_10_0;
    const D3D_FEATURE_LEVEL levels[] = {
        D3D_FEATURE_LEVEL_12_1,
        D3D_FEATURE_LEVEL_12_0,
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    };

    ComPtr<ID3D11Device> device;
    ComPtr<ID3D11DeviceContext> context;
    hr = D3D11CreateDevice(
        nullptr,
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        levels,
        static_cast<UINT>(std::size(levels)),
        D3D11_SDK_VERSION,
        &device,
        &selectedLevel,
        &context);

    out << "    \"available\": " << (SUCCEEDED(hr) ? "true" : "false") << ",\n";
    if (FAILED(hr)) {
        out << "    \"error\": \"D3D11CreateDevice failed\",\n";
    } else {
        out << "    \"feature_level\": \"" << featureLevelName(selectedLevel) << "\",\n";
    }

    out << "    \"adapters\": [\n";
    for (UINT index = 0;; ++index) {
        ComPtr<IDXGIAdapter1> adapter;
        if (factory->EnumAdapters1(index, &adapter) == DXGI_ERROR_NOT_FOUND) {
            break;
        }

        DXGI_ADAPTER_DESC1 desc = {};
        adapter->GetDesc1(&desc);
        if (index > 0) {
            out << ",\n";
        }
        out << "      {\n";
        out << "        \"name\": \"" << jsonEscape(adapterDescription(desc)) << "\",\n";
        out << "        \"vendor_id\": " << desc.VendorId << ",\n";
        out << "        \"device_id\": " << desc.DeviceId << ",\n";
        out << "        \"dedicated_video_memory\": " << static_cast<unsigned long long>(desc.DedicatedVideoMemory) << ",\n";
        out << "        \"software\": " << ((desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) ? "true" : "false") << "\n";
        out << "      }";
    }
    out << "\n";
    out << "    ]\n";
    out << "  },\n";
}

std::string waveFormatName(WORD tag)
{
    switch (tag) {
    case WAVE_FORMAT_PCM:
        return "pcm";
    case WAVE_FORMAT_IEEE_FLOAT:
        return "float";
    case WAVE_FORMAT_EXTENSIBLE:
        return "extensible";
    default:
        return "unknown";
    }
}

void printWasapiReport(std::ostream& out)
{
    out << "  \"wasapi\": {\n";

    ComPtr<IMMDeviceEnumerator> enumerator;
    HRESULT hr = CoCreateInstance(
        __uuidof(MMDeviceEnumerator),
        nullptr,
        CLSCTX_ALL,
        IID_PPV_ARGS(&enumerator));
    if (FAILED(hr)) {
        out << "    \"default_render_endpoint\": null,\n";
        out << "    \"error\": \"MMDeviceEnumerator unavailable\"\n";
        out << "  },\n";
        return;
    }

    ComPtr<IMMDevice> endpoint;
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &endpoint);
    if (FAILED(hr)) {
        out << "    \"default_render_endpoint\": null,\n";
        out << "    \"error\": \"default render endpoint unavailable\"\n";
        out << "  },\n";
        return;
    }

    std::string friendlyName = "unknown";
    ComPtr<IPropertyStore> props;
    if (SUCCEEDED(endpoint->OpenPropertyStore(STGM_READ, &props))) {
        PROPVARIANT value;
        PropVariantInit(&value);
        if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &value)) && value.vt == VT_LPWSTR) {
            friendlyName = wideToUtf8(value.pwszVal);
        }
        PropVariantClear(&value);
    }

    ComPtr<IAudioClient> audioClient;
    hr = endpoint->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, &audioClient);
    if (FAILED(hr)) {
        out << "    \"default_render_endpoint\": \"" << jsonEscape(friendlyName) << "\",\n";
        out << "    \"error\": \"IAudioClient unavailable\"\n";
        out << "  },\n";
        return;
    }

    WAVEFORMATEX* mixFormat = nullptr;
    hr = audioClient->GetMixFormat(&mixFormat);
    if (FAILED(hr) || mixFormat == nullptr) {
        out << "    \"default_render_endpoint\": \"" << jsonEscape(friendlyName) << "\",\n";
        out << "    \"error\": \"mix format unavailable\"\n";
        out << "  },\n";
        return;
    }

    out << "    \"default_render_endpoint\": \"" << jsonEscape(friendlyName) << "\",\n";
    out << "    \"mix_format\": {\n";
    out << "      \"tag\": \"" << waveFormatName(mixFormat->wFormatTag) << "\",\n";
    out << "      \"channels\": " << mixFormat->nChannels << ",\n";
    out << "      \"sample_rate\": " << mixFormat->nSamplesPerSec << ",\n";
    out << "      \"bits_per_sample\": " << mixFormat->wBitsPerSample << "\n";
    out << "    }\n";
    out << "  },\n";

    CoTaskMemFree(mixFormat);
}

void printLibassReport(std::ostream& out)
{
    out << "  \"libass\": {\n";
#if CUESEEKER_HAS_LIBASS_SDK
    out << "    \"sdk_linked\": true,\n";
    out << "    \"version_hex\": \"0x" << std::hex << ass_library_version() << std::dec << "\"\n";
#else
    out << "    \"sdk_linked\": false,\n";
    out << "    \"note\": \"libass development package was not linked\"\n";
#endif
    out << "  },\n";
}

void printFfmpegBuildReport(std::ostream& out)
{
    out << "  \"ffmpeg\": {\n";
#if CUESEEKER_HAS_FFMPEG_SDK
    out << "    \"sdk_linked\": true,\n";
    out << "    \"version\": \"" << jsonEscape(av_version_info()) << "\",\n";
    out << "    \"configuration\": \"" << jsonEscape(avformat_configuration()) << "\"\n";
#else
    out << "    \"sdk_linked\": false,\n";
    out << "    \"note\": \"FFmpeg development package was not linked\"\n";
#endif
    out << "  },\n";
}

#if CUESEEKER_HAS_LIBASS_HEADER
struct AssLibraryDeleter {
    void operator()(ASS_Library* library) const
    {
        ass_library_done(library);
    }
};

struct AssRendererDeleter {
    void operator()(ASS_Renderer* renderer) const
    {
        ass_renderer_done(renderer);
    }
};

struct AssTrackDeleter {
    void operator()(ASS_Track* track) const
    {
        ass_free_track(track);
    }
};

void ignoreAssMessage(int, const char*, va_list, void*)
{
}

std::string assTrackTypeName(int trackType)
{
    switch (trackType) {
    case 1:
        return "ass";
    case 2:
        return "ssa";
    default:
        return "unknown";
    }
}

std::filesystem::path subtitlePathFromUtf8(const std::string& path)
{
    return pathFromUtf8(path);
}

std::vector<char> readAssProbeFile(const std::string& path, uintmax_t maxBytes)
{
    const std::filesystem::path filePath = subtitlePathFromUtf8(path);
    std::error_code ec;
    const bool exists = std::filesystem::exists(filePath, ec);
    if (ec) {
        throw std::runtime_error("Subtitle file status failed: " + ec.message());
    }
    if (!exists) {
        throw std::runtime_error("Subtitle file was not found");
    }
    const bool regularFile = std::filesystem::is_regular_file(filePath, ec);
    if (ec) {
        throw std::runtime_error("Subtitle file status failed: " + ec.message());
    }
    if (!regularFile) {
        throw std::runtime_error("Subtitle path is not a regular file");
    }

    const uintmax_t sizeBytes = std::filesystem::file_size(filePath, ec);
    if (ec) {
        throw std::runtime_error("Subtitle file size failed: " + ec.message());
    }
    if (sizeBytes == 0) {
        throw std::runtime_error("Subtitle file is empty");
    }
    if (sizeBytes > maxBytes) {
        throw std::runtime_error("Subtitle file exceeds the bootstrap probe size limit");
    }

    std::ifstream input(filePath, std::ios::binary);
    if (!input) {
        throw std::runtime_error("Subtitle file could not be opened");
    }

    std::vector<char> bytes(static_cast<size_t>(sizeBytes) + 1);
    input.read(bytes.data(), static_cast<std::streamsize>(sizeBytes));
    if (input.gcount() != static_cast<std::streamsize>(sizeBytes)) {
        throw std::runtime_error("Subtitle file could not be read completely");
    }
    bytes[static_cast<size_t>(sizeBytes)] = '\0';
    return bytes;
}
#endif

void printExternalAssError(
    std::ostream& out,
    const std::string& path,
    bool readable,
    std::optional<uintmax_t> sizeBytes,
    std::string_view errorCode,
    std::string_view error)
{
    out << "    \"external_ass\": {\n";
    out << "      \"provided\": true,\n";
    out << "      \"path\": \"" << jsonEscape(path) << "\",\n";
    out << "      \"path_classification\": \"local_or_mounted_path\",\n";
    out << "      \"readable\": " << (readable ? "true" : "false") << ",\n";
    if (sizeBytes) {
        out << "      \"size_bytes\": " << static_cast<unsigned long long>(*sizeBytes) << ",\n";
    }
    out << "      \"libass_parse_ok\": false,\n";
    out << "      \"error_code\": \"" << jsonEscape(errorCode) << "\",\n";
    out << "      \"error\": \"" << jsonEscape(error) << "\"\n";
    out << "    },\n";
}

void printExternalAssReport(std::ostream& out, const std::optional<std::string>& subtitlePath)
{
    if (!subtitlePath) {
        out << "    \"external_ass\": {\n";
        out << "      \"provided\": false\n";
        out << "    },\n";
        return;
    }

    constexpr uintmax_t maxAssProbeBytes = 32ull * 1024ull * 1024ull;
    const std::string& path = *subtitlePath;

#if !CUESEEKER_HAS_LIBASS_HEADER
    printExternalAssError(
        out,
        path,
        false,
        std::nullopt,
        "libass_unavailable",
        "libass headers and runtime were not linked into this build");
#else
    const std::filesystem::path filePath = subtitlePathFromUtf8(path);
    std::error_code ec;
    const bool exists = std::filesystem::exists(filePath, ec);
    if (ec) {
        printExternalAssError(out, path, false, std::nullopt, "file_status_failed", ec.message());
        return;
    }
    if (!exists) {
        printExternalAssError(out, path, false, std::nullopt, "file_not_found", "Subtitle file was not found");
        return;
    }
    const bool regularFile = std::filesystem::is_regular_file(filePath, ec);
    if (ec) {
        printExternalAssError(out, path, false, std::nullopt, "file_status_failed", ec.message());
        return;
    }
    if (!regularFile) {
        printExternalAssError(out, path, false, std::nullopt, "not_regular_file", "Subtitle path is not a regular file");
        return;
    }

    const uintmax_t sizeBytes = std::filesystem::file_size(filePath, ec);
    if (ec) {
        printExternalAssError(out, path, false, std::nullopt, "file_size_failed", ec.message());
        return;
    }
    if (sizeBytes == 0) {
        printExternalAssError(out, path, true, sizeBytes, "file_empty", "Subtitle file is empty");
        return;
    }
    if (sizeBytes > maxAssProbeBytes) {
        printExternalAssError(out, path, false, sizeBytes, "file_too_large", "Subtitle file exceeds the bootstrap probe size limit");
        return;
    }

    std::ifstream input(filePath, std::ios::binary);
    if (!input) {
        printExternalAssError(out, path, false, sizeBytes, "file_open_failed", "Subtitle file could not be opened");
        return;
    }

    std::vector<char> bytes(static_cast<size_t>(sizeBytes) + 1);
    input.read(bytes.data(), static_cast<std::streamsize>(sizeBytes));
    if (input.gcount() != static_cast<std::streamsize>(sizeBytes)) {
        printExternalAssError(out, path, false, sizeBytes, "file_read_failed", "Subtitle file could not be read completely");
        return;
    }
    bytes[static_cast<size_t>(sizeBytes)] = '\0';

    std::unique_ptr<ASS_Library, AssLibraryDeleter> library(ass_library_init());
    if (!library) {
        printExternalAssError(out, path, true, sizeBytes, "libass_init_failed", "ass_library_init failed");
        return;
    }
    ass_set_message_cb(library.get(), ignoreAssMessage, nullptr);

    std::unique_ptr<ASS_Renderer, AssRendererDeleter> renderer(ass_renderer_init(library.get()));
    if (!renderer) {
        printExternalAssError(out, path, true, sizeBytes, "libass_renderer_failed", "ass_renderer_init failed");
        return;
    }

    std::unique_ptr<ASS_Track, AssTrackDeleter> track(
        ass_read_memory(library.get(), bytes.data(), static_cast<size_t>(sizeBytes), nullptr));
    if (!track) {
        printExternalAssError(out, path, true, sizeBytes, "libass_parse_failed", "ass_read_memory failed");
        return;
    }

    out << "    \"external_ass\": {\n";
    out << "      \"provided\": true,\n";
    out << "      \"path\": \"" << jsonEscape(path) << "\",\n";
    out << "      \"path_classification\": \"local_or_mounted_path\",\n";
    out << "      \"readable\": true,\n";
    out << "      \"size_bytes\": " << static_cast<unsigned long long>(sizeBytes) << ",\n";
    out << "      \"libass_parse_ok\": true,\n";
    out << "      \"renderer_init_ok\": true,\n";
    out << "      \"track_type\": \"" << assTrackTypeName(track->track_type) << "\",\n";
    out << "      \"styles\": " << track->n_styles << ",\n";
    out << "      \"events\": " << track->n_events << ",\n";
    out << "      \"play_res_x\": " << track->PlayResX << ",\n";
    out << "      \"play_res_y\": " << track->PlayResY << ",\n";
    out << "      \"wrap_style\": " << track->WrapStyle << "\n";
    out << "    },\n";
#endif
}

#if CUESEEKER_HAS_FFMPEG_SDK
void printStreamReport(std::ostream& out, AVFormatContext* format)
{
    out << "  \"media\": {\n";
    out << "    \"format\": \"" << jsonEscape(format->iformat && format->iformat->name ? format->iformat->name : "unknown") << "\",\n";
    out << "    \"duration_ms\": " << (format->duration == AV_NOPTS_VALUE ? -1 : format->duration / 1000) << ",\n";
    out << "    \"bit_rate\": " << format->bit_rate << ",\n";
    out << "    \"streams\": [\n";

    for (unsigned int i = 0; i < format->nb_streams; ++i) {
        AVStream* stream = format->streams[i];
        AVCodecParameters* codecpar = stream->codecpar;
        if (i > 0) {
            out << ",\n";
        }
        out << "      {\n";
        out << "        \"index\": " << i << ",\n";
        out << "        \"type\": \"" << mediaTypeName(codecpar->codec_type) << "\",\n";
        out << "        \"codec\": \"" << codecName(codecpar->codec_id) << "\"";

        if (codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            out << ",\n";
            out << "        \"width\": " << codecpar->width << ",\n";
            out << "        \"height\": " << codecpar->height << ",\n";
            out << "        \"pixel_format\": \"" << pixelFormatName(static_cast<AVPixelFormat>(codecpar->format)) << "\"";
        } else if (codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            out << ",\n";
            out << "        \"sample_rate\": " << codecpar->sample_rate << ",\n";
            out << "        \"channels\": " << codecpar->ch_layout.nb_channels << ",\n";
            out << "        \"sample_format\": \"" << sampleFormatName(static_cast<AVSampleFormat>(codecpar->format)) << "\"";
        } else if (codecpar->codec_type == AVMEDIA_TYPE_ATTACHMENT) {
            out << ",\n";
            out << "        \"attachment_size\": " << codecpar->extradata_size;
        }

        out << "\n";
        out << "      }";
    }

    out << "\n";
    out << "    ]\n";
    out << "  },\n";
}

bool isFontAttachment(std::string filename, std::string mimeType)
{
    filename = lowerAscii(std::move(filename));
    mimeType = lowerAscii(std::move(mimeType));

    return mimeType.find("font") != std::string::npos ||
        filename.ends_with(".ttf") ||
        filename.ends_with(".otf") ||
        filename.ends_with(".ttc") ||
        filename.ends_with(".otc");
}

void printSubtitleReport(std::ostream& out, AVFormatContext* format, const std::optional<std::string>& subtitlePath)
{
    out << "  \"subtitles\": {\n";
    printExternalAssReport(out, subtitlePath);

    out << "    \"embedded_streams\": [\n";
    bool firstSubtitle = true;
    for (unsigned int i = 0; i < format->nb_streams; ++i) {
        AVStream* stream = format->streams[i];
        AVCodecParameters* codecpar = stream->codecpar;
        if (codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            continue;
        }
        if (!firstSubtitle) {
            out << ",\n";
        }
        firstSubtitle = false;
        out << "      {\n";
        out << "        \"index\": " << i << ",\n";
        out << "        \"codec\": \"" << codecName(codecpar->codec_id) << "\",\n";
        out << "        \"ass_compatible_header\": " << (isAssCompatibleSubtitleCodec(codecpar->codec_id) ? "true" : "false") << ",\n";
        out << "        \"codec_private_size\": " << codecpar->extradata_size << ",\n";
        out << "        \"duration_ms\": " << streamDurationMs(stream) << ",\n";
        out << "        \"language\": \"" << jsonEscape(streamMetadata(stream, "language")) << "\",\n";
        out << "        \"title\": \"" << jsonEscape(streamMetadata(stream, "title")) << "\"\n";
        out << "      }";
    }
    out << "\n";
    out << "    ],\n";

    out << "    \"attachments\": [\n";
    bool firstAttachment = true;
    for (unsigned int i = 0; i < format->nb_streams; ++i) {
        AVStream* stream = format->streams[i];
        AVCodecParameters* codecpar = stream->codecpar;
        if (codecpar->codec_type != AVMEDIA_TYPE_ATTACHMENT) {
            continue;
        }
        if (!firstAttachment) {
            out << ",\n";
        }
        firstAttachment = false;
        const std::string filename = streamMetadata(stream, "filename");
        const std::string mimeType = streamMetadata(stream, "mimetype");
        out << "      {\n";
        out << "        \"index\": " << i << ",\n";
        out << "        \"codec\": \"" << codecName(codecpar->codec_id) << "\",\n";
        out << "        \"attachment_size\": " << codecpar->extradata_size << ",\n";
        out << "        \"filename\": \"" << jsonEscape(filename) << "\",\n";
        out << "        \"mimetype\": \"" << jsonEscape(mimeType) << "\",\n";
        out << "        \"font_candidate\": " << (isFontAttachment(filename, mimeType) ? "true" : "false") << "\n";
        out << "      }";
    }
    out << "\n";
    out << "    ]\n";
    out << "  }\n";
}
#endif

void inspectMedia(const std::string& path, const std::optional<std::string>& subtitlePath)
{
#if CUESEEKER_HAS_FFMPEG_SDK
    AVFormatContext* rawFormat = nullptr;
    const int openResult = avformat_open_input(&rawFormat, path.c_str(), nullptr, nullptr);
    if (openResult < 0) {
        throw std::runtime_error("avformat_open_input failed: " + avError(openResult));
    }

    std::unique_ptr<AVFormatContext, void (*)(AVFormatContext*)> format(rawFormat, [](AVFormatContext* ctx) {
        avformat_close_input(&ctx);
    });

    const int infoResult = avformat_find_stream_info(format.get(), nullptr);
    if (infoResult < 0) {
        throw std::runtime_error("avformat_find_stream_info failed: " + avError(infoResult));
    }

    std::cout << "{\n";
    std::cout << "  \"schema\": \"cueseeker.windows_playback_lab.report.v0\",\n";
    std::cout << "  \"request\": {\n";
    std::cout << "    \"path\": \"" << jsonEscape(path) << "\",\n";
    std::cout << "    \"path_classification\": \"local_or_mounted_path\"";
    if (subtitlePath) {
        std::cout << ",\n";
        std::cout << "    \"subtitle_path\": \"" << jsonEscape(*subtitlePath) << "\",\n";
        std::cout << "    \"subtitle_path_classification\": \"local_or_mounted_path\"\n";
    } else {
        std::cout << "\n";
    }
    std::cout << "  },\n";
    printPlatformReport(std::cout);
    printD3DReport(std::cout);
    printWasapiReport(std::cout);
    printLibassReport(std::cout);
    printFfmpegBuildReport(std::cout);
    printStreamReport(std::cout, format.get());
    printSubtitleReport(std::cout, format.get(), subtitlePath);
    std::cout << "}\n";
#else
    std::cout << "{\n";
    std::cout << "  \"schema\": \"cueseeker.windows_playback_lab.report.v0\",\n";
    std::cout << "  \"request\": {\n";
    std::cout << "    \"path\": \"" << jsonEscape(path) << "\",\n";
    std::cout << "    \"path_classification\": \"local_or_mounted_path\"";
    if (subtitlePath) {
        std::cout << ",\n";
        std::cout << "    \"subtitle_path\": \"" << jsonEscape(*subtitlePath) << "\",\n";
        std::cout << "    \"subtitle_path_classification\": \"local_or_mounted_path\"\n";
    } else {
        std::cout << "\n";
    }
    std::cout << "  },\n";
    printPlatformReport(std::cout);
    printD3DReport(std::cout);
    printWasapiReport(std::cout);
    printLibassReport(std::cout);
    printFfmpegBuildReport(std::cout);
    std::cout << "  \"media\": {\n";
    std::cout << "    \"inspect_supported\": false,\n";
    std::cout << "    \"error\": \"FFmpeg development SDK was not linked into this build\"\n";
    std::cout << "  }\n";
    std::cout << "}\n";
#endif
}

struct Vertex {
    float x;
    float y;
    float u;
    float v;
};

LRESULT CALLBACK windowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
{
    switch (message) {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProc(hwnd, message, wparam, lparam);
    }
}

class D3D11Renderer {
public:
    void initialize(int width, int height, const wchar_t* title)
    {
        HINSTANCE instance = GetModuleHandleW(nullptr);
        WNDCLASSW klass = {};
        klass.lpfnWndProc = windowProc;
        klass.hInstance = instance;
        klass.lpszClassName = L"CueSeekerWindowsPlaybackLabWindow";
        klass.hCursor = LoadCursor(nullptr, IDC_ARROW);
        RegisterClassW(&klass);

        RECT rect = { 0, 0, width, height };
        AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, FALSE);

        hwnd_ = CreateWindowExW(
            0,
            klass.lpszClassName,
            title,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            rect.right - rect.left,
            rect.bottom - rect.top,
            nullptr,
            nullptr,
            instance,
            nullptr);
        if (!hwnd_) {
            throw std::runtime_error("CreateWindowExW failed");
        }

        createDeviceAndSwapChain(width, height);
        createPipeline();
        ShowWindow(hwnd_, SW_SHOW);
    }

    bool pumpMessages()
    {
        MSG message = {};
        while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
            if (message.message == WM_QUIT) {
                return false;
            }
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        return true;
    }

    void renderColor(float r, float g, float b)
    {
        const float color[] = { r, g, b, 1.0f };
        context_->ClearRenderTargetView(renderTarget_.Get(), color);
        swapChain_->Present(1, 0);
    }

    void renderFrame(const uint8_t* bgra, int width, int height, int stride)
    {
        ensureFrameTexture(width, height);

        D3D11_MAPPED_SUBRESOURCE mapped = {};
        throwIfFailed(context_->Map(frameTexture_.Get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped), "Map frame texture");
        auto* destination = static_cast<uint8_t*>(mapped.pData);
        for (int row = 0; row < height; ++row) {
            std::memcpy(destination + row * mapped.RowPitch, bgra + row * stride, static_cast<size_t>(width) * 4);
        }
        context_->Unmap(frameTexture_.Get(), 0);

        const float clear[] = { 0.0f, 0.0f, 0.0f, 1.0f };
        context_->ClearRenderTargetView(renderTarget_.Get(), clear);

        UINT strideBytes = sizeof(Vertex);
        UINT offset = 0;
        context_->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);
        context_->IASetInputLayout(inputLayout_.Get());
        context_->IASetVertexBuffers(0, 1, vertexBuffer_.GetAddressOf(), &strideBytes, &offset);
        context_->VSSetShader(vertexShader_.Get(), nullptr, 0);
        context_->PSSetShader(pixelShader_.Get(), nullptr, 0);
        context_->PSSetShaderResources(0, 1, frameView_.GetAddressOf());
        context_->PSSetSamplers(0, 1, sampler_.GetAddressOf());

        D3D11_VIEWPORT viewport = {};
        RECT client = {};
        GetClientRect(hwnd_, &client);
        viewport.Width = static_cast<float>(std::max<LONG>(1, client.right - client.left));
        viewport.Height = static_cast<float>(std::max<LONG>(1, client.bottom - client.top));
        viewport.MinDepth = 0.0f;
        viewport.MaxDepth = 1.0f;
        context_->RSSetViewports(1, &viewport);
        context_->OMSetRenderTargets(1, renderTarget_.GetAddressOf(), nullptr);
        context_->Draw(4, 0);
        swapChain_->Present(1, 0);
    }

private:
    void createDeviceAndSwapChain(int width, int height)
    {
        DXGI_SWAP_CHAIN_DESC desc = {};
        desc.BufferDesc.Width = width;
        desc.BufferDesc.Height = height;
        desc.BufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        desc.BufferDesc.RefreshRate.Numerator = 60;
        desc.BufferDesc.RefreshRate.Denominator = 1;
        desc.SampleDesc.Count = 1;
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        desc.BufferCount = 2;
        desc.OutputWindow = hwnd_;
        desc.Windowed = TRUE;
        desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

        const D3D_FEATURE_LEVEL levels[] = {
            D3D_FEATURE_LEVEL_12_1,
            D3D_FEATURE_LEVEL_12_0,
            D3D_FEATURE_LEVEL_11_1,
            D3D_FEATURE_LEVEL_11_0,
            D3D_FEATURE_LEVEL_10_1,
            D3D_FEATURE_LEVEL_10_0,
        };

        D3D_FEATURE_LEVEL selectedLevel = D3D_FEATURE_LEVEL_10_0;
        throwIfFailed(
            D3D11CreateDeviceAndSwapChain(
                nullptr,
                D3D_DRIVER_TYPE_HARDWARE,
                nullptr,
                D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                levels,
                static_cast<UINT>(std::size(levels)),
                D3D11_SDK_VERSION,
                &desc,
                &swapChain_,
                &device_,
                &selectedLevel,
                &context_),
            "D3D11CreateDeviceAndSwapChain");

        ComPtr<ID3D11Texture2D> backBuffer;
        throwIfFailed(swapChain_->GetBuffer(0, IID_PPV_ARGS(&backBuffer)), "GetBuffer");
        throwIfFailed(device_->CreateRenderTargetView(backBuffer.Get(), nullptr, &renderTarget_), "CreateRenderTargetView");
    }

    void createPipeline()
    {
        const char* shaderSource = R"(
struct VSIn {
    float2 pos : POSITION;
    float2 uv : TEXCOORD0;
};

struct PSIn {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

PSIn vs_main(VSIn input) {
    PSIn output;
    output.pos = float4(input.pos, 0.0f, 1.0f);
    output.uv = input.uv;
    return output;
}

Texture2D frameTexture : register(t0);
SamplerState frameSampler : register(s0);

float4 ps_main(PSIn input) : SV_TARGET {
    return frameTexture.Sample(frameSampler, input.uv);
}
)";

        ComPtr<ID3DBlob> vertexBlob;
        ComPtr<ID3DBlob> pixelBlob;
        ComPtr<ID3DBlob> errors;
        HRESULT hr = D3DCompile(
            shaderSource,
            std::strlen(shaderSource),
            nullptr,
            nullptr,
            nullptr,
            "vs_main",
            "vs_4_0",
            0,
            0,
            &vertexBlob,
            &errors);
        if (FAILED(hr)) {
            throw std::runtime_error(errors ? static_cast<const char*>(errors->GetBufferPointer()) : "vertex shader compile failed");
        }

        hr = D3DCompile(
            shaderSource,
            std::strlen(shaderSource),
            nullptr,
            nullptr,
            nullptr,
            "ps_main",
            "ps_4_0",
            0,
            0,
            &pixelBlob,
            &errors);
        if (FAILED(hr)) {
            throw std::runtime_error(errors ? static_cast<const char*>(errors->GetBufferPointer()) : "pixel shader compile failed");
        }

        throwIfFailed(device_->CreateVertexShader(vertexBlob->GetBufferPointer(), vertexBlob->GetBufferSize(), nullptr, &vertexShader_), "CreateVertexShader");
        throwIfFailed(device_->CreatePixelShader(pixelBlob->GetBufferPointer(), pixelBlob->GetBufferSize(), nullptr, &pixelShader_), "CreatePixelShader");

        const D3D11_INPUT_ELEMENT_DESC layout[] = {
            { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
            { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, sizeof(float) * 2, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        };
        throwIfFailed(
            device_->CreateInputLayout(layout, static_cast<UINT>(std::size(layout)), vertexBlob->GetBufferPointer(), vertexBlob->GetBufferSize(), &inputLayout_),
            "CreateInputLayout");

        const Vertex vertices[] = {
            { -1.0f, 1.0f, 0.0f, 0.0f },
            { 1.0f, 1.0f, 1.0f, 0.0f },
            { -1.0f, -1.0f, 0.0f, 1.0f },
            { 1.0f, -1.0f, 1.0f, 1.0f },
        };
        D3D11_BUFFER_DESC bufferDesc = {};
        bufferDesc.ByteWidth = sizeof(vertices);
        bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
        bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
        D3D11_SUBRESOURCE_DATA bufferData = {};
        bufferData.pSysMem = vertices;
        throwIfFailed(device_->CreateBuffer(&bufferDesc, &bufferData, &vertexBuffer_), "CreateBuffer");

        D3D11_SAMPLER_DESC samplerDesc = {};
        samplerDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
        samplerDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
        samplerDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
        samplerDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
        samplerDesc.MaxLOD = D3D11_FLOAT32_MAX;
        throwIfFailed(device_->CreateSamplerState(&samplerDesc, &sampler_), "CreateSamplerState");
    }

    void ensureFrameTexture(int width, int height)
    {
        if (frameTexture_ && frameWidth_ == width && frameHeight_ == height) {
            return;
        }

        frameTexture_.Reset();
        frameView_.Reset();
        frameWidth_ = width;
        frameHeight_ = height;

        D3D11_TEXTURE2D_DESC desc = {};
        desc.Width = static_cast<UINT>(width);
        desc.Height = static_cast<UINT>(height);
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.Usage = D3D11_USAGE_DYNAMIC;
        desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
        desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
        throwIfFailed(device_->CreateTexture2D(&desc, nullptr, &frameTexture_), "CreateTexture2D");
        throwIfFailed(device_->CreateShaderResourceView(frameTexture_.Get(), nullptr, &frameView_), "CreateShaderResourceView");
    }

    HWND hwnd_ = nullptr;
    ComPtr<ID3D11Device> device_;
    ComPtr<ID3D11DeviceContext> context_;
    ComPtr<IDXGISwapChain> swapChain_;
    ComPtr<ID3D11RenderTargetView> renderTarget_;
    ComPtr<ID3D11VertexShader> vertexShader_;
    ComPtr<ID3D11PixelShader> pixelShader_;
    ComPtr<ID3D11InputLayout> inputLayout_;
    ComPtr<ID3D11Buffer> vertexBuffer_;
    ComPtr<ID3D11SamplerState> sampler_;
    ComPtr<ID3D11Texture2D> frameTexture_;
    ComPtr<ID3D11ShaderResourceView> frameView_;
    int frameWidth_ = 0;
    int frameHeight_ = 0;
};

void runRenderTest()
{
    D3D11Renderer renderer;
    renderer.initialize(960, 540, L"CueSeeker Windows Playback Lab - D3D11 Render Test");

    const auto start = std::chrono::steady_clock::now();
    while (renderer.pumpMessages()) {
        const auto elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
        if (elapsed > 4.0) {
            break;
        }
        renderer.renderColor(
            static_cast<float>((std::sin(elapsed * 2.0) + 1.0) * 0.5),
            static_cast<float>((std::sin(elapsed * 2.7 + 1.0) + 1.0) * 0.5),
            static_cast<float>((std::sin(elapsed * 3.1 + 2.0) + 1.0) * 0.5));
    }
}

#if CUESEEKER_HAS_FFMPEG_SDK
struct CodecContextDeleter {
    void operator()(AVCodecContext* context) const
    {
        avcodec_free_context(&context);
    }
};

struct FrameDeleter {
    void operator()(AVFrame* frame) const
    {
        av_frame_free(&frame);
    }
};

struct PacketDeleter {
    void operator()(AVPacket* packet) const
    {
        av_packet_free(&packet);
    }
};

struct SwrContextDeleter {
    void operator()(SwrContext* context) const
    {
        swr_free(&context);
    }
};

class WasapiAudioOutput {
public:
    ~WasapiAudioOutput()
    {
        if (started_ && audioClient_) {
            audioClient_->Stop();
        }
        if (mixFormat_) {
            CoTaskMemFree(mixFormat_);
        }
    }

    void initialize()
    {
        ComPtr<IMMDeviceEnumerator> enumerator;
        throwIfFailed(
            CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&enumerator)),
            "CoCreateInstance(MMDeviceEnumerator)");

        ComPtr<IMMDevice> endpoint;
        throwIfFailed(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &endpoint), "GetDefaultAudioEndpoint");
        endpointName_ = readEndpointName(endpoint.Get());

        throwIfFailed(endpoint->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, &audioClient_), "IMMDevice::Activate(IAudioClient)");
        throwIfFailed(audioClient_->GetMixFormat(&mixFormat_), "IAudioClient::GetMixFormat");
        if (!mixFormat_) {
            throw std::runtime_error("IAudioClient::GetMixFormat returned no mix format");
        }

        outputSampleFormat_ = chooseOutputSampleFormat(mixFormat_);
        const int sampleBytes = av_get_bytes_per_sample(outputSampleFormat_);
        bytesPerFrame_ = sampleBytes * static_cast<int>(mixFormat_->nChannels);
        if (sampleBytes <= 0 || bytesPerFrame_ <= 0 || bytesPerFrame_ != mixFormat_->nBlockAlign) {
            std::ostringstream out;
            out << "Unsupported WASAPI mix block alignment: tag=" << waveFormatName(mixFormat_->wFormatTag)
                << ", channels=" << mixFormat_->nChannels
                << ", bits=" << mixFormat_->wBitsPerSample
                << ", block_align=" << mixFormat_->nBlockAlign;
            throw std::runtime_error(out.str());
        }

        constexpr REFERENCE_TIME bufferDuration = 10'000'000; // 1 second in 100 ns units.
        throwIfFailed(
            audioClient_->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, bufferDuration, 0, mixFormat_, nullptr),
            "IAudioClient::Initialize(shared)");
        throwIfFailed(audioClient_->GetBufferSize(&bufferFrameCount_), "IAudioClient::GetBufferSize");
        throwIfFailed(audioClient_->GetService(IID_PPV_ARGS(&renderClient_)), "IAudioClient::GetService(IAudioRenderClient)");
    }

    void writeInterleaved(const uint8_t* data, int frameCount)
    {
        if (frameCount <= 0) {
            return;
        }
        if (!data) {
            throw std::runtime_error("WASAPI write received null audio data");
        }
        if (!started_) {
            throwIfFailed(audioClient_->Start(), "IAudioClient::Start");
            started_ = true;
        }

        int framesRemaining = frameCount;
        const uint8_t* cursor = data;
        while (framesRemaining > 0) {
            UINT32 padding = 0;
            throwIfFailed(audioClient_->GetCurrentPadding(&padding), "IAudioClient::GetCurrentPadding");
            const UINT32 available = bufferFrameCount_ > padding ? bufferFrameCount_ - padding : 0;
            if (available == 0) {
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
                continue;
            }

            const UINT32 framesToWrite = std::min<UINT32>(available, static_cast<UINT32>(framesRemaining));
            BYTE* destination = nullptr;
            throwIfFailed(renderClient_->GetBuffer(framesToWrite, &destination), "IAudioRenderClient::GetBuffer");
            std::memcpy(destination, cursor, static_cast<size_t>(framesToWrite) * bytesPerFrame_);
            throwIfFailed(renderClient_->ReleaseBuffer(framesToWrite, 0), "IAudioRenderClient::ReleaseBuffer");

            cursor += static_cast<size_t>(framesToWrite) * bytesPerFrame_;
            framesRemaining -= static_cast<int>(framesToWrite);
        }
    }

    int sampleRate() const
    {
        return static_cast<int>(mixFormat_->nSamplesPerSec);
    }

    int channels() const
    {
        return static_cast<int>(mixFormat_->nChannels);
    }

    int bytesPerFrame() const
    {
        return bytesPerFrame_;
    }

    AVSampleFormat sampleFormat() const
    {
        return outputSampleFormat_;
    }

    std::string endpointName() const
    {
        return endpointName_;
    }

    std::string outputDescription() const
    {
        std::ostringstream out;
        out << waveFormatName(mixFormat_->wFormatTag)
            << ", " << channels() << " channels"
            << ", " << sampleRate() << " Hz"
            << ", " << mixFormat_->wBitsPerSample << " bits"
            << ", ffmpeg sample format " << sampleFormatName(outputSampleFormat_);
        return out.str();
    }

private:
    static std::string readEndpointName(IMMDevice* endpoint)
    {
        ComPtr<IPropertyStore> props;
        if (FAILED(endpoint->OpenPropertyStore(STGM_READ, &props))) {
            return "unknown";
        }

        PROPVARIANT value;
        PropVariantInit(&value);
        std::string friendlyName = "unknown";
        if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &value)) && value.vt == VT_LPWSTR) {
            friendlyName = wideToUtf8(value.pwszVal);
        }
        PropVariantClear(&value);
        return friendlyName;
    }

    static bool matchesExtensibleSubtype(const WAVEFORMATEX* format, WORD waveFormatTag)
    {
        if (format->wFormatTag != WAVE_FORMAT_EXTENSIBLE ||
            format->cbSize < sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX)) {
            return false;
        }

        const auto* extensible = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(format);
        const GUID& subtype = extensible->SubFormat;
        return subtype.Data1 == waveFormatTag &&
            subtype.Data2 == 0x0000 &&
            subtype.Data3 == 0x0010 &&
            subtype.Data4[0] == 0x80 &&
            subtype.Data4[1] == 0x00 &&
            subtype.Data4[2] == 0x00 &&
            subtype.Data4[3] == 0xaa &&
            subtype.Data4[4] == 0x00 &&
            subtype.Data4[5] == 0x38 &&
            subtype.Data4[6] == 0x9b &&
            subtype.Data4[7] == 0x71;
    }

    static AVSampleFormat chooseOutputSampleFormat(const WAVEFORMATEX* format)
    {
        const bool isFloat = format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT ||
            matchesExtensibleSubtype(format, WAVE_FORMAT_IEEE_FLOAT);
        const bool isPcm = format->wFormatTag == WAVE_FORMAT_PCM ||
            matchesExtensibleSubtype(format, WAVE_FORMAT_PCM);

        if (isFloat && format->wBitsPerSample == 32) {
            return AV_SAMPLE_FMT_FLT;
        }
        if (isPcm && format->wBitsPerSample == 16) {
            return AV_SAMPLE_FMT_S16;
        }
        if (isPcm && format->wBitsPerSample == 32) {
            return AV_SAMPLE_FMT_S32;
        }

        std::ostringstream out;
        out << "Unsupported WASAPI mix format for bootstrap audio output: tag="
            << waveFormatName(format->wFormatTag)
            << ", channels=" << format->nChannels
            << ", sample_rate=" << format->nSamplesPerSec
            << ", bits=" << format->wBitsPerSample;
        throw std::runtime_error(out.str());
    }

    ComPtr<IAudioClient> audioClient_;
    ComPtr<IAudioRenderClient> renderClient_;
    WAVEFORMATEX* mixFormat_ = nullptr;
    UINT32 bufferFrameCount_ = 0;
    int bytesPerFrame_ = 0;
    AVSampleFormat outputSampleFormat_ = AV_SAMPLE_FMT_NONE;
    std::string endpointName_ = "unknown";
    bool started_ = false;
};

#if CUESEEKER_HAS_LIBASS_HEADER
class AssOverlay {
public:
    void initialize(const std::string& subtitlePath, int frameWidth, int frameHeight)
    {
        constexpr uintmax_t maxAssProbeBytes = 32ull * 1024ull * 1024ull;
        subtitlePath_ = subtitlePath;
        fileBytes_ = readAssProbeFile(subtitlePath, maxAssProbeBytes);

        library_.reset(ass_library_init());
        if (!library_) {
            throw std::runtime_error("ass_library_init failed for subtitle overlay");
        }
        ass_set_message_cb(library_.get(), ignoreAssMessage, nullptr);
        ass_set_extract_fonts(library_.get(), 1);

        renderer_.reset(ass_renderer_init(library_.get()));
        if (!renderer_) {
            throw std::runtime_error("ass_renderer_init failed for subtitle overlay");
        }

        track_.reset(ass_read_memory(library_.get(), fileBytes_.data(), fileBytes_.size() - 1, nullptr));
        if (!track_) {
            throw std::runtime_error("ass_read_memory failed for subtitle overlay");
        }

        ass_set_frame_size(renderer_.get(), frameWidth, frameHeight);
        ass_set_storage_size(renderer_.get(), frameWidth, frameHeight);
        ass_set_fonts(renderer_.get(), nullptr, "Arial", ASS_FONTPROVIDER_AUTODETECT, nullptr, 1);
    }

    void composite(uint8_t* bgra, int frameWidth, int frameHeight, int stride, int64_t mediaMs)
    {
        if (!renderer_ || !track_) {
            return;
        }

        int detectChange = 0;
        ASS_Image* image = ass_render_frame(renderer_.get(), track_.get(), mediaMs, &detectChange);
        for (const ASS_Image* current = image; current != nullptr; current = current->next) {
            blendImage(current, bgra, frameWidth, frameHeight, stride);
        }
    }

    int eventCount() const
    {
        return track_ ? track_->n_events : 0;
    }

    int styleCount() const
    {
        return track_ ? track_->n_styles : 0;
    }

    const std::string& subtitlePath() const
    {
        return subtitlePath_;
    }

private:
    static void blendImage(const ASS_Image* image, uint8_t* bgra, int frameWidth, int frameHeight, int stride)
    {
        if (!image || image->w <= 0 || image->h <= 0) {
            return;
        }

        const int sourceX = std::max(0, -image->dst_x);
        const int sourceY = std::max(0, -image->dst_y);
        const int destX = std::max(0, image->dst_x);
        const int destY = std::max(0, image->dst_y);
        const int blendWidth = std::min(image->w - sourceX, frameWidth - destX);
        const int blendHeight = std::min(image->h - sourceY, frameHeight - destY);
        if (blendWidth <= 0 || blendHeight <= 0) {
            return;
        }

        const int sourceR = static_cast<int>((image->color >> 24) & 0xff);
        const int sourceG = static_cast<int>((image->color >> 16) & 0xff);
        const int sourceB = static_cast<int>((image->color >> 8) & 0xff);
        const int sourceAlpha = 255 - static_cast<int>(image->color & 0xff);

        for (int y = 0; y < blendHeight; ++y) {
            const uint8_t* mask = image->bitmap + static_cast<size_t>(sourceY + y) * image->stride + sourceX;
            uint8_t* dest = bgra + static_cast<size_t>(destY + y) * stride + static_cast<size_t>(destX) * 4;
            for (int x = 0; x < blendWidth; ++x) {
                const int alpha = (static_cast<int>(mask[x]) * sourceAlpha + 127) / 255;
                if (alpha <= 0) {
                    dest += 4;
                    continue;
                }

                dest[0] = static_cast<uint8_t>((sourceB * alpha + dest[0] * (255 - alpha) + 127) / 255);
                dest[1] = static_cast<uint8_t>((sourceG * alpha + dest[1] * (255 - alpha) + 127) / 255);
                dest[2] = static_cast<uint8_t>((sourceR * alpha + dest[2] * (255 - alpha) + 127) / 255);
                dest[3] = 255;
                dest += 4;
            }
        }
    }

    std::unique_ptr<ASS_Library, AssLibraryDeleter> library_;
    std::unique_ptr<ASS_Renderer, AssRendererDeleter> renderer_;
    std::unique_ptr<ASS_Track, AssTrackDeleter> track_;
    std::vector<char> fileBytes_;
    std::string subtitlePath_;
};
#endif

int findBestVideoStream(AVFormatContext* format)
{
    const int streamIndex = av_find_best_stream(format, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (streamIndex < 0) {
        throw std::runtime_error("No playable video stream found: " + avError(streamIndex));
    }
    return streamIndex;
}

int findBestAudioStream(AVFormatContext* format)
{
    const int streamIndex = av_find_best_stream(format, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    return streamIndex >= 0 ? streamIndex : -1;
}

void playVideo(
    const std::string& path,
    const std::optional<std::string>& subtitlePath,
    int64_t seekMs,
    int64_t durationMs,
    const std::optional<std::string>& reportPath)
{
    PlaybackReport report;
    report.mediaPath = path;
    report.subtitlePath = subtitlePath;
    report.seekMs = seekMs;
    report.requestedDurationMs = durationMs;

    AVFormatContext* rawFormat = nullptr;
    int result = avformat_open_input(&rawFormat, path.c_str(), nullptr, nullptr);
    if (result < 0) {
        throw std::runtime_error("avformat_open_input failed: " + avError(result));
    }

    std::unique_ptr<AVFormatContext, void (*)(AVFormatContext*)> format(rawFormat, [](AVFormatContext* ctx) {
        avformat_close_input(&ctx);
    });

    result = avformat_find_stream_info(format.get(), nullptr);
    if (result < 0) {
        throw std::runtime_error("avformat_find_stream_info failed: " + avError(result));
    }

    const int streamIndex = findBestVideoStream(format.get());
    AVStream* stream = format->streams[streamIndex];
    report.videoStreamIndex = streamIndex;
    report.videoCodec = codecName(stream->codecpar->codec_id);
    const AVCodec* decoder = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!decoder) {
        throw std::runtime_error("No decoder found for video codec " + codecName(stream->codecpar->codec_id));
    }
    report.videoDecoder = decoder->name ? decoder->name : "unknown";

    std::unique_ptr<AVCodecContext, CodecContextDeleter> codec(avcodec_alloc_context3(decoder));
    if (!codec) {
        throw std::runtime_error("avcodec_alloc_context3 failed");
    }

    result = avcodec_parameters_to_context(codec.get(), stream->codecpar);
    if (result < 0) {
        throw std::runtime_error("avcodec_parameters_to_context failed: " + avError(result));
    }

    result = avcodec_open2(codec.get(), decoder, nullptr);
    if (result < 0) {
        throw std::runtime_error("avcodec_open2 failed: " + avError(result));
    }

    const int audioStreamIndex = findBestAudioStream(format.get());
    AVStream* audioStream = audioStreamIndex >= 0 ? format->streams[audioStreamIndex] : nullptr;
    std::unique_ptr<AVCodecContext, CodecContextDeleter> audioCodec;
    std::unique_ptr<WasapiAudioOutput> audioOutput;
    std::unique_ptr<SwrContext, SwrContextDeleter> audioSwr;

    if (audioStream) {
        report.audioStreamIndex = audioStreamIndex;
        report.audioCodec = codecName(audioStream->codecpar->codec_id);
        const AVCodec* audioDecoder = avcodec_find_decoder(audioStream->codecpar->codec_id);
        if (!audioDecoder) {
            throw std::runtime_error("No decoder found for audio codec " + codecName(audioStream->codecpar->codec_id));
        }
        report.audioDecoder = audioDecoder->name ? audioDecoder->name : "unknown";

        audioCodec.reset(avcodec_alloc_context3(audioDecoder));
        if (!audioCodec) {
            throw std::runtime_error("avcodec_alloc_context3 failed for audio");
        }

        result = avcodec_parameters_to_context(audioCodec.get(), audioStream->codecpar);
        if (result < 0) {
            throw std::runtime_error("avcodec_parameters_to_context failed for audio: " + avError(result));
        }

        result = avcodec_open2(audioCodec.get(), audioDecoder, nullptr);
        if (result < 0) {
            throw std::runtime_error("avcodec_open2 failed for audio: " + avError(result));
        }
        if (audioCodec->sample_rate <= 0 || audioCodec->sample_fmt == AV_SAMPLE_FMT_NONE) {
            throw std::runtime_error("Audio stream has invalid sample format or sample rate");
        }
        report.audioInputSampleRate = audioCodec->sample_rate;
        report.audioInputChannels = audioCodec->ch_layout.nb_channels > 0
            ? audioCodec->ch_layout.nb_channels
            : audioStream->codecpar->ch_layout.nb_channels;

        audioOutput = std::make_unique<WasapiAudioOutput>();
        audioOutput->initialize();
        report.audioOutput = "wasapi_shared";
        report.audioEndpoint = audioOutput->endpointName();
        report.audioMixFormat = audioOutput->outputDescription();

        AVChannelLayout inputLayout = {};
        if (audioCodec->ch_layout.nb_channels > 0) {
            result = av_channel_layout_copy(&inputLayout, &audioCodec->ch_layout);
        } else if (audioStream->codecpar->ch_layout.nb_channels > 0) {
            result = av_channel_layout_copy(&inputLayout, &audioStream->codecpar->ch_layout);
        } else {
            result = AVERROR(EINVAL);
        }
        if (result < 0) {
            throw std::runtime_error("Audio stream has no usable channel layout: " + avError(result));
        }

        AVChannelLayout outputLayout = {};
        av_channel_layout_default(&outputLayout, audioOutput->channels());
        SwrContext* rawSwr = nullptr;
        result = swr_alloc_set_opts2(
            &rawSwr,
            &outputLayout,
            audioOutput->sampleFormat(),
            audioOutput->sampleRate(),
            &inputLayout,
            audioCodec->sample_fmt,
            audioCodec->sample_rate,
            0,
            nullptr);
        av_channel_layout_uninit(&inputLayout);
        av_channel_layout_uninit(&outputLayout);
        if (result < 0 || !rawSwr) {
            if (rawSwr) {
                swr_free(&rawSwr);
            }
            throw std::runtime_error("swr_alloc_set_opts2 failed: " + avError(result));
        }

        result = swr_init(rawSwr);
        if (result < 0) {
            swr_free(&rawSwr);
            throw std::runtime_error("swr_init failed: " + avError(result));
        }
        audioSwr.reset(rawSwr);
    }

    if (seekMs > 0) {
        const int64_t target = av_rescale_q(seekMs, AVRational { 1, 1000 }, stream->time_base);
        if (av_seek_frame(format.get(), streamIndex, target, AVSEEK_FLAG_BACKWARD) >= 0) {
            avcodec_flush_buffers(codec.get());
            if (audioCodec) {
                avcodec_flush_buffers(audioCodec.get());
            }
        }
    }

    const int frameWidth = codec->width > 0 ? codec->width : stream->codecpar->width;
    const int frameHeight = codec->height > 0 ? codec->height : stream->codecpar->height;
    if (frameWidth <= 0 || frameHeight <= 0) {
        throw std::runtime_error("Video stream has invalid dimensions");
    }
    report.videoWidth = frameWidth;
    report.videoHeight = frameHeight;
    if (codec->pix_fmt != AV_PIX_FMT_NONE) {
        report.pixelFormat = pixelFormatName(codec->pix_fmt);
    }

#if CUESEEKER_HAS_LIBASS_HEADER
    std::unique_ptr<AssOverlay> subtitleOverlay;
    if (subtitlePath) {
        subtitleOverlay = std::make_unique<AssOverlay>();
        subtitleOverlay->initialize(*subtitlePath, frameWidth, frameHeight);
        report.subtitleOverlay = "external_ass";
        report.subtitleEvents = subtitleOverlay->eventCount();
        report.subtitleStyles = subtitleOverlay->styleCount();
    }
#else
    if (subtitlePath) {
        throw std::runtime_error("ASS subtitle overlay requires building with the libass development SDK.");
    }
#endif

    D3D11Renderer renderer;
    renderer.initialize(
        std::min(frameWidth, 1280),
        std::min(frameHeight, 720),
        L"CueSeeker Windows Playback Lab - software video path");

    std::unique_ptr<AVFrame, FrameDeleter> frame(av_frame_alloc());
    std::unique_ptr<AVFrame, FrameDeleter> bgraFrame(av_frame_alloc());
    std::unique_ptr<AVFrame, FrameDeleter> audioFrame(audioCodec ? av_frame_alloc() : nullptr);
    std::unique_ptr<AVPacket, PacketDeleter> packet(av_packet_alloc());
    if (!frame || !bgraFrame || !packet || (audioCodec && !audioFrame)) {
        throw std::runtime_error("Failed to allocate FFmpeg frame or packet");
    }

    const int bgraSize = av_image_get_buffer_size(AV_PIX_FMT_BGRA, frameWidth, frameHeight, 1);
    if (bgraSize <= 0) {
        throw std::runtime_error("av_image_get_buffer_size failed");
    }
    std::vector<uint8_t> bgra(static_cast<size_t>(bgraSize));
    av_image_fill_arrays(
        bgraFrame->data,
        bgraFrame->linesize,
        bgra.data(),
        AV_PIX_FMT_BGRA,
        frameWidth,
        frameHeight,
        1);

    std::cerr << "CueSeeker Windows Playback Lab selected decode path: software\n";
    if (audioOutput) {
        std::cerr << "Audio output: WASAPI shared mode on " << audioOutput->endpointName() << "\n";
        std::cerr << "Audio mix: " << audioOutput->outputDescription() << "\n";
    } else {
        std::cerr << "Audio output: no audio stream found; playback is video-only.\n";
    }
#if CUESEEKER_HAS_LIBASS_HEADER
    if (subtitleOverlay) {
        std::cerr << "ASS overlay: external subtitle enabled from " << subtitleOverlay->subtitlePath()
                  << " (" << subtitleOverlay->eventCount() << " events, "
                  << subtitleOverlay->styleCount() << " styles)\n";
    } else {
        std::cerr << "ASS overlay: no external ASS subtitle path provided.\n";
    }
#else
    std::cerr << "ASS overlay: libass SDK is not linked in this build.\n";
#endif

    startProcessTelemetry(report.process);
    const auto wallStart = std::chrono::steady_clock::now();
    std::optional<double> mediaStart;
    bool running = true;
    std::unique_ptr<SwsContext, void (*)(SwsContext*)> swsGuard(nullptr, sws_freeContext);
    AVPixelFormat activeSwsFormat = AV_PIX_FMT_NONE;

    auto receiveFrames = [&]() {
        while (true) {
            const int receive = avcodec_receive_frame(codec.get(), frame.get());
            if (receive == AVERROR(EAGAIN) || receive == AVERROR_EOF) {
                break;
            }
            if (receive < 0) {
                throw std::runtime_error("avcodec_receive_frame failed: " + avError(receive));
            }
            ++report.videoFramesDecoded;

            const auto frameFormat = static_cast<AVPixelFormat>(frame->format);
            report.pixelFormat = pixelFormatName(frameFormat);
            if (!swsGuard || activeSwsFormat != frameFormat) {
                SwsContext* sws = sws_getContext(
                    frame->width,
                    frame->height,
                    frameFormat,
                    frameWidth,
                    frameHeight,
                    AV_PIX_FMT_BGRA,
                    SWS_BILINEAR,
                    nullptr,
                    nullptr,
                    nullptr);
                if (!sws) {
                    throw std::runtime_error("sws_getContext failed");
                }
                swsGuard.reset(sws);
                activeSwsFormat = frameFormat;
            }

            sws_scale(
                swsGuard.get(),
                frame->data,
                frame->linesize,
                0,
                frameHeight,
                bgraFrame->data,
                bgraFrame->linesize);

            const int64_t pts = frame->best_effort_timestamp;
            double mediaSeconds = 0.0;
            if (pts != AV_NOPTS_VALUE) {
                mediaSeconds = static_cast<double>(pts) * av_q2d(stream->time_base);
            }
            if (!mediaStart) {
                mediaStart = mediaSeconds;
            }
            const double relativeMedia = mediaSeconds - *mediaStart;
            const double relativeWall = std::chrono::duration<double>(std::chrono::steady_clock::now() - wallStart).count();
            if (relativeMedia > relativeWall && relativeMedia - relativeWall < 1.0) {
                std::this_thread::sleep_for(std::chrono::duration<double>(relativeMedia - relativeWall));
            }

#if CUESEEKER_HAS_LIBASS_HEADER
            if (subtitleOverlay) {
                const int64_t subtitleMs = static_cast<int64_t>(std::llround(mediaSeconds * 1000.0));
                subtitleOverlay->composite(bgraFrame->data[0], frameWidth, frameHeight, bgraFrame->linesize[0], subtitleMs);
            }
#endif

            if (!renderer.pumpMessages()) {
                running = false;
                report.completionReason = "window_closed";
                break;
            }

            renderer.renderFrame(bgraFrame->data[0], frameWidth, frameHeight, bgraFrame->linesize[0]);
            ++report.videoFramesRendered;
            if (report.firstFrameMs < 0) {
                report.firstFrameMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now() - wallStart)
                                          .count();
            }
            sampleProcessTelemetry(report.process);
            av_frame_unref(frame.get());

            if (durationMs > 0) {
                const auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - wallStart).count();
                if (elapsedMs >= durationMs) {
                    running = false;
                    report.completionReason = "duration_limit";
                    break;
                }
            }
        }
    };

    auto writeResampledAudio = [&](int outputFrames, const uint8_t** inputData, int inputFrames) {
        if (outputFrames <= 0) {
            return;
        }
        const int bufferSize = av_samples_get_buffer_size(
            nullptr,
            audioOutput->channels(),
            outputFrames,
            audioOutput->sampleFormat(),
            1);
        if (bufferSize < 0) {
            throw std::runtime_error("av_samples_get_buffer_size failed: " + avError(bufferSize));
        }

        std::vector<uint8_t> audioBuffer(static_cast<size_t>(bufferSize));
        uint8_t* outputData[] = { audioBuffer.data() };
        const int converted = swr_convert(audioSwr.get(), outputData, outputFrames, inputData, inputFrames);
        if (converted < 0) {
            throw std::runtime_error("swr_convert failed: " + avError(converted));
        }
        if (converted > 0) {
            audioOutput->writeInterleaved(audioBuffer.data(), converted);
            report.audioSampleFramesWritten += static_cast<uint64_t>(converted);
            sampleProcessTelemetry(report.process);
        }
    };

    auto receiveAudioFrames = [&]() {
        if (!audioCodec || !audioOutput || !audioSwr) {
            return;
        }

        while (running) {
            const int receive = avcodec_receive_frame(audioCodec.get(), audioFrame.get());
            if (receive == AVERROR(EAGAIN) || receive == AVERROR_EOF) {
                break;
            }
            if (receive < 0) {
                throw std::runtime_error("avcodec_receive_frame failed for audio: " + avError(receive));
            }
            ++report.audioFramesDecoded;

            const auto frameSampleFormat = static_cast<AVSampleFormat>(audioFrame->format);
            const int frameSampleRate = audioFrame->sample_rate > 0 ? audioFrame->sample_rate : audioCodec->sample_rate;
            if (frameSampleFormat != audioCodec->sample_fmt || frameSampleRate != audioCodec->sample_rate) {
                throw std::runtime_error("Dynamic audio format changes are not implemented in this bootstrap");
            }

            const int64_t delayed = swr_get_delay(audioSwr.get(), audioCodec->sample_rate);
            const int outputFrames = static_cast<int>(av_rescale_rnd(
                delayed + audioFrame->nb_samples,
                audioOutput->sampleRate(),
                audioCodec->sample_rate,
                AV_ROUND_UP));
            const uint8_t** inputData = const_cast<const uint8_t**>(audioFrame->extended_data);
            writeResampledAudio(outputFrames, inputData, audioFrame->nb_samples);
            av_frame_unref(audioFrame.get());
        }
    };

    auto flushAudioResampler = [&]() {
        if (!audioCodec || !audioOutput || !audioSwr) {
            return;
        }

        while (running) {
            const int64_t delayed = swr_get_delay(audioSwr.get(), audioCodec->sample_rate);
            const int outputFrames = static_cast<int>(av_rescale_rnd(
                delayed,
                audioOutput->sampleRate(),
                audioCodec->sample_rate,
                AV_ROUND_UP));
            if (outputFrames <= 0) {
                break;
            }
            writeResampledAudio(outputFrames, nullptr, 0);
        }
    };

    while (running) {
        if (!renderer.pumpMessages()) {
            report.completionReason = "window_closed";
            break;
        }

        result = av_read_frame(format.get(), packet.get());
        if (result == AVERROR_EOF) {
            avcodec_send_packet(codec.get(), nullptr);
            receiveFrames();
            if (audioCodec) {
                avcodec_send_packet(audioCodec.get(), nullptr);
                receiveAudioFrames();
                flushAudioResampler();
            }
            if (report.completionReason == "unknown") {
                report.completionReason = "eof";
            }
            break;
        }
        if (result < 0) {
            throw std::runtime_error("av_read_frame failed: " + avError(result));
        }

        if (packet->stream_index == streamIndex) {
            const int send = avcodec_send_packet(codec.get(), packet.get());
            if (send < 0 && send != AVERROR(EAGAIN)) {
                throw std::runtime_error("avcodec_send_packet failed: " + avError(send));
            }
            receiveFrames();
        }

        if (audioCodec && packet->stream_index == audioStreamIndex) {
            int send = avcodec_send_packet(audioCodec.get(), packet.get());
            if (send == AVERROR(EAGAIN)) {
                receiveAudioFrames();
                send = avcodec_send_packet(audioCodec.get(), packet.get());
            }
            if (send < 0) {
                throw std::runtime_error("avcodec_send_packet failed for audio: " + avError(send));
            }
            receiveAudioFrames();
        }

        av_packet_unref(packet.get());
    }

    if (report.completionReason == "unknown") {
        report.completionReason = "stopped";
    }
    report.success = true;
    finishProcessTelemetry(report.process, wallStart);
    if (reportPath) {
        writePlaybackReport(*reportPath, report);
        std::cerr << "Playback report: " << *reportPath << "\n";
    }
}
#else
void playVideo(
    const std::string&,
    const std::optional<std::string>&,
    int64_t,
    int64_t,
    const std::optional<std::string>&)
{
    throw std::runtime_error("Video playback requires building with the FFmpeg development SDK.");
}
#endif

struct CliOptions {
    enum class Mode {
        Help,
        Inspect,
        RenderTest,
        Play,
    };

    Mode mode = Mode::Help;
    std::string mediaPath;
    std::optional<std::string> subtitlePath;
    std::optional<std::string> reportPath;
    int64_t seekMs = 0;
    int64_t durationMs = 15000;
};

void printUsage()
{
    std::cout
        << "CueSeekerWindowsPlaybackLab\n"
        << "\n"
        << "Usage:\n"
        << "  CueSeekerWindowsPlaybackLab --inspect <media-file> [--subtitle <ass-file>]\n"
        << "  CueSeekerWindowsPlaybackLab --render-test\n"
        << "  CueSeekerWindowsPlaybackLab --play <media-file> [--subtitle <ass-file>] [--seek-ms ms] [--duration-ms ms] [--report-path json-file]\n"
        << "\n"
        << "Inspect reports embedded subtitle streams, attachments, and optional external ASS probe results.\n"
        << "The first --play path uses FFmpeg software video decode, D3D11 presentation,\n"
        << "WASAPI shared-mode audio output, and optional external ASS overlay.\n"
        << "D3D11VA/DXVA remains an intentionally separate next step.\n";
}

CliOptions parseArgs(int argc, wchar_t** argv)
{
    CliOptions options;
    for (int i = 1; i < argc; ++i) {
        const std::wstring arg = argv[i];
        if (arg == L"--help" || arg == L"-h") {
            options.mode = CliOptions::Mode::Help;
            return options;
        }
        if (arg == L"--inspect") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--inspect requires a media file");
            }
            options.mode = CliOptions::Mode::Inspect;
            options.mediaPath = wideToUtf8(argv[++i]);
            continue;
        }
        if (arg == L"--render-test") {
            options.mode = CliOptions::Mode::RenderTest;
            continue;
        }
        if (arg == L"--play") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--play requires a media file");
            }
            options.mode = CliOptions::Mode::Play;
            options.mediaPath = wideToUtf8(argv[++i]);
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
            options.subtitlePath = wideToUtf8(argv[++i]);
            continue;
        }
        if (arg == L"--report-path") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--report-path requires a JSON file path");
            }
            options.reportPath = wideToUtf8(argv[++i]);
            continue;
        }

        throw std::runtime_error("Unknown argument: " + wideToUtf8(arg));
    }

    return options;
}

void writePlaybackFailureReport(const CliOptions& options, std::string_view error)
{
    if (!options.reportPath) {
        return;
    }

    PlaybackReport report;
    report.mediaPath = options.mediaPath;
    report.subtitlePath = options.subtitlePath;
    report.seekMs = options.seekMs;
    report.requestedDurationMs = options.durationMs;
    report.success = false;
    report.failureStage = "exception";
    report.error = std::string(error);
    report.completionReason = "failed";
    writePlaybackReport(*options.reportPath, report);
}

} // namespace

int wmain(int argc, wchar_t** argv)
{
    CliOptions options;
    try {
#if CUESEEKER_HAS_FFMPEG_SDK
        avformat_network_init();
#endif
        ComInit com;

        options = parseArgs(argc, argv);
        switch (options.mode) {
        case CliOptions::Mode::Help:
            printUsage();
            return 0;
        case CliOptions::Mode::Inspect:
            inspectMedia(options.mediaPath, options.subtitlePath);
            return 0;
        case CliOptions::Mode::RenderTest:
            runRenderTest();
            return 0;
        case CliOptions::Mode::Play:
            playVideo(options.mediaPath, options.subtitlePath, options.seekMs, options.durationMs, options.reportPath);
            return 0;
        }

        printUsage();
        return 2;
    } catch (const std::exception& error) {
        std::cerr << "CueSeekerWindowsPlaybackLab failed: " << error.what() << "\n";
        if (options.mode == CliOptions::Mode::Play && options.reportPath) {
            try {
                writePlaybackFailureReport(options, error.what());
                std::cerr << "Playback failure report: " << *options.reportPath << "\n";
            } catch (const std::exception& reportError) {
                std::cerr << "CueSeekerWindowsPlaybackLab report write failed: " << reportError.what() << "\n";
            }
        }
        return 1;
    }
}
