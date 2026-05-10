#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef _WIN32
#ifdef CUESEEKER_PLAYBACK_NATIVE_EXPORTS
#define CUESEEKER_PLAYBACK_API __declspec(dllexport)
#else
#define CUESEEKER_PLAYBACK_API __declspec(dllimport)
#endif
#else
#define CUESEEKER_PLAYBACK_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef enum CueSeekerPlaybackDecodePreference {
    CUESEEKER_PLAYBACK_DECODE_AUTO = 0,
    CUESEEKER_PLAYBACK_DECODE_SOFTWARE = 1,
    CUESEEKER_PLAYBACK_DECODE_D3D11VA = 2,
} CueSeekerPlaybackDecodePreference;

typedef struct CueSeekerPlaybackOptions {
    const wchar_t* media_path;
    const wchar_t* subtitle_path;
    const wchar_t* report_path;
    int64_t seek_ms;
    int64_t duration_ms;
    CueSeekerPlaybackDecodePreference decode_preference;
    void* swap_chain_panel;
    int32_t render_width;
    int32_t render_height;
    void* renderer_presenter;
} CueSeekerPlaybackOptions;

CUESEEKER_PLAYBACK_API int CueSeekerPlaybackInspectJson(
    const wchar_t* media_path,
    const wchar_t* subtitle_path,
    char** report_json,
    char** error_message);

CUESEEKER_PLAYBACK_API int CueSeekerPlaybackPlay(
    const CueSeekerPlaybackOptions* options,
    char** error_message);

CUESEEKER_PLAYBACK_API int CueSeekerPlaybackCreateSwapChainPanelPresenter(
    void* swap_chain_panel,
    int32_t render_width,
    int32_t render_height,
    void** renderer_presenter,
    char** error_message);

CUESEEKER_PLAYBACK_API void CueSeekerPlaybackDestroyPresenter(void* renderer_presenter);

CUESEEKER_PLAYBACK_API int CueSeekerPlaybackRunRenderTest(char** error_message);

CUESEEKER_PLAYBACK_API void CueSeekerPlaybackFreeString(char* value);

#ifdef __cplusplus
}
#endif
