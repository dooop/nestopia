cmake_minimum_required(VERSION 3.22.1)
project(nes LANGUAGES C CXX)

get_filename_component(PROJECT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../.." ABSOLUTE)
set(NESTOPIA_CORE "${PROJECT_ROOT}/nestopia/source/core")
set(COMMON_BRIDGE "${PROJECT_ROOT}/swift/Sources/NESCoreBridge")

file(GLOB_RECURSE NESTOPIA_SOURCES CONFIGURE_DEPENDS "${NESTOPIA_CORE}/*.cpp")
list(FILTER NESTOPIA_SOURCES EXCLUDE REGEX "NstVideoFilter(2xSaI|HqX|ScaleX|xBR)\\.cpp$")

add_library(
    nes
    SHARED
    nes_jni.cpp
    "${COMMON_BRIDGE}/nes_engine.cpp"
    ${NESTOPIA_SOURCES}
)

target_include_directories(
    nes
    PRIVATE
    "${COMMON_BRIDGE}/include"
    "${NESTOPIA_CORE}"
    "${NESTOPIA_CORE}/api"
)

target_compile_definitions(
    nes
    PRIVATE
    NST_NO_HQ2X
    NST_NO_SCALEX
    NST_NO_2XSAI
    NST_NO_XBR
)

target_compile_options(nes PRIVATE -Wno-c++11-narrowing)
target_link_libraries(nes PRIVATE log z)
