cmake_minimum_required(VERSION 3.16)
project(lame_enc_ffi C)

set(LAME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../lame")

# Generate config.h from platform-specific config
if(WIN32)
    configure_file(
        "${LAME_DIR}/configMS.h"
        "${CMAKE_CURRENT_BINARY_DIR}/config.h"
        COPYONLY
    )
elseif(APPLE)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/configMac.h"
        "${CMAKE_CURRENT_BINARY_DIR}/config.h"
        COPYONLY
    )
else()
    configure_file(
        "${LAME_DIR}/configMS.h"
        "${CMAKE_CURRENT_BINARY_DIR}/config.h"
        COPYONLY
    )
endif()

# LAME libmp3lame source files
set(LAME_SOURCES
    ${LAME_DIR}/libmp3lame/VbrTag.c
    ${LAME_DIR}/libmp3lame/bitstream.c
    ${LAME_DIR}/libmp3lame/encoder.c
    ${LAME_DIR}/libmp3lame/fft.c
    ${LAME_DIR}/libmp3lame/gain_analysis.c
    ${LAME_DIR}/libmp3lame/id3tag.c
    ${LAME_DIR}/libmp3lame/lame.c
    ${LAME_DIR}/libmp3lame/mpglib_interface.c
    ${LAME_DIR}/libmp3lame/newmdct.c
    ${LAME_DIR}/libmp3lame/presets.c
    ${LAME_DIR}/libmp3lame/psymodel.c
    ${LAME_DIR}/libmp3lame/quantize.c
    ${LAME_DIR}/libmp3lame/quantize_pvt.c
    ${LAME_DIR}/libmp3lame/reservoir.c
    ${LAME_DIR}/libmp3lame/set_get.c
    ${LAME_DIR}/libmp3lame/tables.c
    ${LAME_DIR}/libmp3lame/takehiro.c
    ${LAME_DIR}/libmp3lame/util.c
    ${LAME_DIR}/libmp3lame/vbrquantize.c
    ${LAME_DIR}/libmp3lame/version.c
)

# SSE intrinsics (x86/x64 only)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|i[3-6]86")
    list(APPEND LAME_SOURCES ${LAME_DIR}/libmp3lame/vector/xmm_quantize_sub.c)
endif()

# mpglib sources (needed by mpglib_interface.c)
set(MPGLIB_SOURCES
    ${LAME_DIR}/mpglib/common.c
    ${LAME_DIR}/mpglib/dct64_i386.c
    ${LAME_DIR}/mpglib/decode_i386.c
    ${LAME_DIR}/mpglib/interface.c
    ${LAME_DIR}/mpglib/layer1.c
    ${LAME_DIR}/mpglib/layer2.c
    ${LAME_DIR}/mpglib/layer3.c
    ${LAME_DIR}/mpglib/tabinit.c
)

# FFI wrapper
set(FFI_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/lame_enc_ffi.c
)

add_library(lame_enc_ffi SHARED
    ${LAME_SOURCES}
    ${MPGLIB_SOURCES}
    ${FFI_SOURCES}
)

target_include_directories(lame_enc_ffi PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}    # config.h
    ${LAME_DIR}/include            # lame.h
    ${LAME_DIR}/libmp3lame         # internal headers
    ${LAME_DIR}/mpglib             # mpglib headers
    ${LAME_DIR}                    # for mpglib/mpg123.h includes
    ${CMAKE_CURRENT_SOURCE_DIR}    # lame_enc_ffi.h
)

target_compile_definitions(lame_enc_ffi PRIVATE
    HAVE_CONFIG_H
    HAVE_MPGLIB
)

if(MSVC)
    target_compile_definitions(lame_enc_ffi PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_compile_options(lame_enc_ffi PRIVATE /W3 /wd4244 /wd4305 /wd4018)
else()
    target_compile_options(lame_enc_ffi PRIVATE -Wall -Wno-sign-compare -Wno-unused-variable)
endif()

if(WIN32)
    set_target_properties(lame_enc_ffi PROPERTIES
        OUTPUT_NAME "lame_enc_ffi"
        PREFIX ""
    )
else()
    set_target_properties(lame_enc_ffi PROPERTIES
        OUTPUT_NAME "lame_enc_ffi"
    )
endif()
