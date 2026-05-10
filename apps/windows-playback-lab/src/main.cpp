#include <windows.h>
#include <audioclient.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <propkeydef.h>
#include <functiondiscoverykeys_devpkey.h>
#include <mmdeviceapi.h>
#include <propsys.h>
#include <wrl/client.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <memory>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
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
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
#include <libavutil/samplefmt.h>
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
    out << "  }\n";
}
#endif

void inspectMedia(const std::string& path)
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
    std::cout << "    \"path_classification\": \"local_or_mounted_path\"\n";
    std::cout << "  },\n";
    printPlatformReport(std::cout);
    printD3DReport(std::cout);
    printWasapiReport(std::cout);
    printLibassReport(std::cout);
    printFfmpegBuildReport(std::cout);
    printStreamReport(std::cout, format.get());
    std::cout << "}\n";
#else
    std::cout << "{\n";
    std::cout << "  \"schema\": \"cueseeker.windows_playback_lab.report.v0\",\n";
    std::cout << "  \"request\": {\n";
    std::cout << "    \"path\": \"" << jsonEscape(path) << "\",\n";
    std::cout << "    \"path_classification\": \"local_or_mounted_path\"\n";
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

int findBestVideoStream(AVFormatContext* format)
{
    const int streamIndex = av_find_best_stream(format, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (streamIndex < 0) {
        throw std::runtime_error("No playable video stream found: " + avError(streamIndex));
    }
    return streamIndex;
}

void playVideo(const std::string& path, int64_t seekMs, int64_t durationMs)
{
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
    const AVCodec* decoder = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!decoder) {
        throw std::runtime_error("No decoder found for video codec " + codecName(stream->codecpar->codec_id));
    }

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

    if (seekMs > 0) {
        const int64_t target = av_rescale_q(seekMs, AVRational { 1, 1000 }, stream->time_base);
        if (av_seek_frame(format.get(), streamIndex, target, AVSEEK_FLAG_BACKWARD) >= 0) {
            avcodec_flush_buffers(codec.get());
        }
    }

    const int frameWidth = codec->width > 0 ? codec->width : stream->codecpar->width;
    const int frameHeight = codec->height > 0 ? codec->height : stream->codecpar->height;
    if (frameWidth <= 0 || frameHeight <= 0) {
        throw std::runtime_error("Video stream has invalid dimensions");
    }

    D3D11Renderer renderer;
    renderer.initialize(
        std::min(frameWidth, 1280),
        std::min(frameHeight, 720),
        L"CueSeeker Windows Playback Lab - software video path");

    std::unique_ptr<AVFrame, FrameDeleter> frame(av_frame_alloc());
    std::unique_ptr<AVFrame, FrameDeleter> bgraFrame(av_frame_alloc());
    std::unique_ptr<AVPacket, PacketDeleter> packet(av_packet_alloc());
    if (!frame || !bgraFrame || !packet) {
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
    std::cerr << "Audio output is not implemented in this bootstrap.\n";
    std::cerr << "ASS overlay is not implemented in this bootstrap.\n";

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

            const auto frameFormat = static_cast<AVPixelFormat>(frame->format);
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

            if (!renderer.pumpMessages()) {
                running = false;
                break;
            }

            renderer.renderFrame(bgraFrame->data[0], frameWidth, frameHeight, bgraFrame->linesize[0]);
            av_frame_unref(frame.get());

            if (durationMs > 0) {
                const auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - wallStart).count();
                if (elapsedMs >= durationMs) {
                    running = false;
                    break;
                }
            }
        }
    };

    while (running && renderer.pumpMessages()) {
        result = av_read_frame(format.get(), packet.get());
        if (result == AVERROR_EOF) {
            avcodec_send_packet(codec.get(), nullptr);
            receiveFrames();
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

        av_packet_unref(packet.get());
    }
}
#else
void playVideo(const std::string&, int64_t, int64_t)
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
    int64_t seekMs = 0;
    int64_t durationMs = 15000;
};

void printUsage()
{
    std::cout
        << "CueSeekerWindowsPlaybackLab\n"
        << "\n"
        << "Usage:\n"
        << "  CueSeekerWindowsPlaybackLab --inspect <media-file>\n"
        << "  CueSeekerWindowsPlaybackLab --render-test\n"
        << "  CueSeekerWindowsPlaybackLab --play <media-file> [--seek-ms ms] [--duration-ms ms]\n"
        << "\n"
        << "The first --play path uses FFmpeg software video decode and D3D11 presentation.\n"
        << "WASAPI audio output, D3D11VA/DXVA, and libass overlay are intentionally next steps.\n";
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

        throw std::runtime_error("Unknown argument: " + wideToUtf8(arg));
    }

    return options;
}

} // namespace

int wmain(int argc, wchar_t** argv)
{
    try {
#if CUESEEKER_HAS_FFMPEG_SDK
        avformat_network_init();
#endif
        ComInit com;

        const CliOptions options = parseArgs(argc, argv);
        switch (options.mode) {
        case CliOptions::Mode::Help:
            printUsage();
            return 0;
        case CliOptions::Mode::Inspect:
            inspectMedia(options.mediaPath);
            return 0;
        case CliOptions::Mode::RenderTest:
            runRenderTest();
            return 0;
        case CliOptions::Mode::Play:
            playVideo(options.mediaPath, options.seekMs, options.durationMs);
            return 0;
        }

        printUsage();
        return 2;
    } catch (const std::exception& error) {
        std::cerr << "CueSeekerWindowsPlaybackLab failed: " << error.what() << "\n";
        return 1;
    }
}
