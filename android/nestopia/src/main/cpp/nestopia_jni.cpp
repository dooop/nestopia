// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

#include <jni.h>
#include <cstdint>
#include <string>

#include "nestopia_engine.h"

namespace {
NestopiaEngine *fromHandle(jlong handle) { return reinterpret_cast<NestopiaEngine *>(handle); }

std::string toString(JNIEnv *env, jstring value)
{
    if (value == nullptr) return {};
    const char *characters = env->GetStringUTFChars(value, nullptr);
    std::string result(characters == nullptr ? "" : characters);
    if (characters != nullptr) env->ReleaseStringUTFChars(value, characters);
    return result;
}
}

extern "C" JNIEXPORT jlong JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_create(JNIEnv *env, jobject, jstring databasePath)
{
    const std::string database = toString(env, databasePath);
    return reinterpret_cast<jlong>(nestopia_engine_create(database.c_str()));
}

extern "C" JNIEXPORT void JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_destroy(JNIEnv *, jobject, jlong handle)
{
    nestopia_engine_destroy(fromHandle(handle));
}

extern "C" JNIEXPORT jboolean JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_loadROM(JNIEnv *env, jobject, jlong handle, jstring romPath, jstring savePath)
{
    const std::string rom = toString(env, romPath);
    const std::string save = toString(env, savePath);
    return nestopia_engine_load_rom(fromHandle(handle), rom.c_str(), save.c_str());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_runFrame(JNIEnv *, jobject, jlong handle)
{
    return nestopia_engine_run_frame(fromHandle(handle));
}

extern "C" JNIEXPORT jdouble JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_frameDuration(JNIEnv *, jobject, jlong handle)
{
    return nestopia_engine_frame_duration(fromHandle(handle));
}

extern "C" JNIEXPORT void JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_copyVideo(JNIEnv *env, jobject, jlong handle, jintArray destination)
{
    const uint32_t *source = nestopia_engine_video_buffer(fromHandle(handle));
    if (source == nullptr || destination == nullptr) return;
    const jsize count = static_cast<jsize>(nestopia_engine_video_pixel_count());
    jint *pixels = env->GetIntArrayElements(destination, nullptr);
    if (pixels == nullptr) return;
    for (jsize index = 0; index < count; ++index) {
        const uint32_t rgba = source[index];
        const uint32_t red = rgba & 0xFF;
        const uint32_t green = (rgba >> 8) & 0xFF;
        const uint32_t blue = (rgba >> 16) & 0xFF;
        pixels[index] = static_cast<jint>(0xFF000000u | (red << 16) | (green << 8) | blue);
    }
    env->ReleaseIntArrayElements(destination, pixels, 0);
}

extern "C" JNIEXPORT jint JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_copyAudio(JNIEnv *env, jobject, jlong handle, jshortArray destination)
{
    const int16_t *source = nestopia_engine_audio_buffer(fromHandle(handle));
    const jsize count = static_cast<jsize>(nestopia_engine_audio_sample_count(fromHandle(handle)));
    if (source == nullptr || destination == nullptr) return 0;
    const jsize capacity = env->GetArrayLength(destination);
    const jsize copied = count < capacity ? count : capacity;
    env->SetShortArrayRegion(destination, 0, copied, reinterpret_cast<const jshort *>(source));
    return copied;
}

extern "C" JNIEXPORT void JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_setButton(JNIEnv *, jobject, jlong handle, jint player, jint button, jboolean pressed)
{
    nestopia_engine_set_button(fromHandle(handle), static_cast<unsigned>(player), static_cast<NestopiaButton>(button), pressed);
}

extern "C" JNIEXPORT void JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_reset(JNIEnv *, jobject, jlong handle, jboolean hardReset)
{
    nestopia_engine_reset(fromHandle(handle), hardReset);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_saveState(JNIEnv *env, jobject, jlong handle, jstring path)
{
    const std::string value = toString(env, path);
    return nestopia_engine_save_state(fromHandle(handle), value.c_str());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_loadState(JNIEnv *env, jobject, jlong handle, jstring path)
{
    const std::string value = toString(env, path);
    return nestopia_engine_load_state(fromHandle(handle), value.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_net_sourceforge_nestopia_internal_NativeNestopia_lastError(JNIEnv *env, jobject, jlong handle)
{
    return env->NewStringUTF(nestopia_engine_last_error(fromHandle(handle)));
}
