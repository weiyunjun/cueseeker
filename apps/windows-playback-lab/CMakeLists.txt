cmake_minimum_required(VERSION 3.25)

project(CueSeekerWindowsPlaybackLab LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT WIN32)
    message(FATAL_ERROR "CueSeekerWindowsPlaybackLab currently targets Windows only.")
endif()

macro(cueseeker_find_library out_var library_name)
    find_library(
        ${out_var}
        NAMES ${library_name} lib${library_name}
        HINTS ${FFMPEG_ROOT} ${LIBASS_ROOT}
        PATH_SUFFIXES msvc-lib lib lib/x64 lib/Win64
    )

endmacro()

set(FFMPEG_ROOT "$ENV{FFMPEG_ROOT}" CACHE PATH "FFmpeg development package root")
set(LIBASS_ROOT "$ENV{LIBASS_ROOT}" CACHE PATH "libass development package root")

find_path(
    FFMPEG_INCLUDE_DIR
    NAMES libavformat/avformat.h
    HINTS ${FFMPEG_ROOT}
    PATH_SUFFIXES include
)

find_path(
    LIBASS_INCLUDE_DIR
    NAMES ass/ass.h
    HINTS ${LIBASS_ROOT}
    PATH_SUFFIXES include
)

foreach(ffmpeg_library IN ITEMS avformat avcodec avutil swscale swresample)
    cueseeker_find_library(FFMPEG_${ffmpeg_library}_LIBRARY ${ffmpeg_library})
    if(FFMPEG_${ffmpeg_library}_LIBRARY)
        list(APPEND FFMPEG_LIBRARIES ${FFMPEG_${ffmpeg_library}_LIBRARY})
    endif()
endforeach()

cueseeker_find_library(LIBASS_LIBRARY ass)

set(CUESEEKER_HAS_FFMPEG_SDK OFF)
if(FFMPEG_INCLUDE_DIR AND FFMPEG_avformat_LIBRARY AND FFMPEG_avcodec_LIBRARY AND FFMPEG_avutil_LIBRARY AND FFMPEG_swscale_LIBRARY AND FFMPEG_swresample_LIBRARY)
    set(CUESEEKER_HAS_FFMPEG_SDK ON)
else()
    message(WARNING "FFmpeg development package was not found. Building Windows lab without FFmpeg inspect/playback support.")
endif()

set(CUESEEKER_HAS_LIBASS_SDK OFF)
if(LIBASS_LIBRARY)
    set(CUESEEKER_HAS_LIBASS_SDK ON)
else()
    message(WARNING "libass import library was not found. Building Windows lab without libass probing.")
endif()

add_executable(CueSeekerWindowsPlaybackLab
    src/main.cpp
)

target_compile_definitions(CueSeekerWindowsPlaybackLab PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
    UNICODE
    _UNICODE
    CUESEEKER_HAS_FFMPEG_SDK=$<BOOL:${CUESEEKER_HAS_FFMPEG_SDK}>
    CUESEEKER_HAS_LIBASS_SDK=$<BOOL:${CUESEEKER_HAS_LIBASS_SDK}>
    CUESEEKER_HAS_LIBASS_HEADER=$<BOOL:${LIBASS_INCLUDE_DIR}>
)

if(CUESEEKER_HAS_FFMPEG_SDK)
    target_include_directories(CueSeekerWindowsPlaybackLab PRIVATE ${FFMPEG_INCLUDE_DIR})
    target_link_libraries(CueSeekerWindowsPlaybackLab PRIVATE ${FFMPEG_LIBRARIES})
endif()

if(CUESEEKER_HAS_LIBASS_SDK)
    if(LIBASS_INCLUDE_DIR)
        target_include_directories(CueSeekerWindowsPlaybackLab PRIVATE ${LIBASS_INCLUDE_DIR})
    endif()
    target_link_libraries(CueSeekerWindowsPlaybackLab PRIVATE ${LIBASS_LIBRARY})
endif()

target_link_libraries(CueSeekerWindowsPlaybackLab PRIVATE
    d3d11
    dxgi
    d3dcompiler
    dxguid
    ole32
    propsys
)

if(MSVC)
    target_compile_options(CueSeekerWindowsPlaybackLab PRIVATE /W4 /permissive-)
endif()
