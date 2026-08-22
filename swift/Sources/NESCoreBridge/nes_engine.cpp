// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

#include "nes_engine.h"

#include "NstApiCartridge.hpp"
#include "NstApiCheats.hpp"
#include "NstApiEmulator.hpp"
#include "NstApiInput.hpp"
#include "NstApiMachine.hpp"
#include "NstApiSound.hpp"
#include "NstApiUser.hpp"
#include "NstApiVideo.hpp"

#include <array>
#include <cstdio>
#include <fstream>
#include <memory>
#include <string>

namespace {
constexpr std::size_t videoWidth = Nes::Api::Video::Output::WIDTH;
constexpr std::size_t videoHeight = Nes::Api::Video::Output::HEIGHT;
constexpr std::uint32_t audioSampleRate = 44100;

bool NST_CALLBACK audioLock(void *, Nes::Api::Sound::Output &) { return true; }
bool NST_CALLBACK videoLock(void *, Nes::Api::Video::Output &) { return true; }
void NST_CALLBACK audioUnlock(void *, Nes::Api::Sound::Output &) {}
void NST_CALLBACK videoUnlock(void *, Nes::Api::Video::Output &) {}
void NST_CALLBACK fileIO(void *context, Nes::Api::User::File &file);
}

struct NESEngine {
    Nes::Api::Emulator emulator;
    Nes::Api::Machine machine{emulator};
    Nes::Api::Cartridge::Database database{emulator};
    Nes::Api::Input input{emulator};
    Nes::Api::Sound sound{emulator};
    Nes::Api::Video video{emulator};
    Nes::Api::Cheats cheats{emulator};
    Nes::Api::Sound::Output audioOutput;
    Nes::Api::Video::Output videoOutput;
    Nes::Api::Input::Controllers controllers;
    std::array<std::uint32_t, videoWidth * videoHeight> videoBuffer{};
    std::array<std::int16_t, Nes::Api::Sound::Output::MAX_LENGTH> audioBuffer{};
    std::string batteryPath;
    std::string lastError;
    std::size_t audioSamples = 0;
    bool loaded = false;
};

namespace {
void setError(NESEngine *engine, const char *message)
{
    if (engine != nullptr) engine->lastError = message;
}

void NST_CALLBACK fileIO(void *context, Nes::Api::User::File &file)
{
    auto *engine = static_cast<NESEngine *>(context);
    if (engine == nullptr || engine->batteryPath.empty()) return;

    switch (file.GetAction()) {
        case Nes::Api::User::File::LOAD_BATTERY:
        case Nes::Api::User::File::LOAD_EEPROM: {
            std::ifstream stream(engine->batteryPath, std::ios::in | std::ios::binary);
            if (stream.good()) file.SetContent(stream);
            break;
        }
        case Nes::Api::User::File::SAVE_BATTERY:
        case Nes::Api::User::File::SAVE_EEPROM: {
            std::ofstream stream(engine->batteryPath, std::ios::out | std::ios::binary | std::ios::trunc);
            if (stream.good()) file.GetContent(stream);
            break;
        }
        default:
            break;
    }
}
}

NESEngine *nes_engine_create(const char *databasePath)
{
    auto engine = std::make_unique<NESEngine>();

    Nes::Api::Sound::Output::lockCallback.Set(audioLock, engine.get());
    Nes::Api::Sound::Output::unlockCallback.Set(audioUnlock, engine.get());
    Nes::Api::Video::Output::lockCallback.Set(videoLock, engine.get());
    Nes::Api::Video::Output::unlockCallback.Set(videoUnlock, engine.get());
    Nes::Api::User::fileIoCallback.Set(fileIO, engine.get());

    if (databasePath != nullptr && databasePath[0] != '\0') {
        std::ifstream databaseStream(databasePath, std::ios::in | std::ios::binary);
        if (databaseStream.good() && NES_SUCCEEDED(engine->database.Load(databaseStream))) {
            engine->database.Enable();
        }
    }

    return engine.release();
}

void nes_engine_destroy(NESEngine *engine)
{
    if (engine == nullptr) return;
    nes_engine_unload_rom(engine);
    Nes::Api::Sound::Output::lockCallback.Unset();
    Nes::Api::Sound::Output::unlockCallback.Unset();
    Nes::Api::Video::Output::lockCallback.Unset();
    Nes::Api::Video::Output::unlockCallback.Unset();
    Nes::Api::User::fileIoCallback.Unset();
    delete engine;
}

bool nes_engine_load_rom(NESEngine *engine, const char *romPath, const char *batteryPath)
{
    if (engine == nullptr || romPath == nullptr) return false;
    if (engine->loaded) nes_engine_unload_rom(engine);

    engine->batteryPath = batteryPath == nullptr ? "" : batteryPath;
    engine->lastError.clear();
    std::ifstream romStream(romPath, std::ios::in | std::ios::binary);
    if (!romStream.good()) {
        setError(engine, "The ROM could not be opened.");
        return false;
    }

    const Nes::Result loadResult = engine->machine.Load(romStream, Nes::Api::Machine::FAVORED_NES_NTSC);
    if (NES_FAILED(loadResult)) {
        engine->lastError = "Nestopia rejected the ROM (error " + std::to_string(loadResult) + ").";
        return false;
    }

    engine->machine.SetMode(engine->machine.GetDesiredMode());
    if (NES_FAILED(engine->sound.SetSampleRate(audioSampleRate))) {
        setError(engine, "Nestopia could not configure audio.");
        engine->machine.Unload();
        return false;
    }
    engine->sound.SetVolume(Nes::Api::Sound::ALL_CHANNELS, 100);
    engine->sound.SetSpeaker(Nes::Api::Sound::SPEAKER_MONO);

    engine->audioSamples = audioSampleRate / (engine->machine.GetMode() == Nes::Api::Machine::PAL ? 50 : 60);
    engine->audioOutput.samples[0] = engine->audioBuffer.data();
    engine->audioOutput.length[0] = static_cast<Nes::uint>(engine->audioSamples);
    engine->audioOutput.samples[1] = nullptr;
    engine->audioOutput.length[1] = 0;

    engine->video.EnableUnlimSprites(true);
    engine->videoOutput.pixels = engine->videoBuffer.data();
    engine->videoOutput.pitch = static_cast<long>(videoWidth * sizeof(std::uint32_t));
    Nes::Api::Video::RenderState renderState;
    renderState.filter = Nes::Api::Video::RenderState::FILTER_NONE;
    renderState.width = videoWidth;
    renderState.height = videoHeight;
    renderState.bits.count = 32;
    renderState.bits.mask.r = 0x000000FF;
    renderState.bits.mask.g = 0x0000FF00;
    renderState.bits.mask.b = 0x00FF0000;
    if (NES_FAILED(engine->video.SetRenderState(renderState))) {
        setError(engine, "Nestopia could not configure video.");
        engine->machine.Unload();
        return false;
    }

    engine->input.ConnectController(0, Nes::Api::Input::PAD1);
    engine->input.ConnectController(1, Nes::Api::Input::PAD2);
    engine->machine.Power(true);
    engine->loaded = true;
    return true;
}

void nes_engine_unload_rom(NESEngine *engine)
{
    if (engine == nullptr || !engine->loaded) return;
    engine->machine.Unload();
    engine->loaded = false;
    engine->batteryPath.clear();
    nes_engine_reset_inputs(engine);
}

bool nes_engine_is_loaded(const NESEngine *engine) { return engine != nullptr && engine->loaded; }

bool nes_engine_run_frame(NESEngine *engine)
{
    if (engine == nullptr || !engine->loaded) return false;
    engine->audioOutput.length[0] = static_cast<Nes::uint>(engine->audioSamples);
    const Nes::Result result = engine->emulator.Execute(&engine->videoOutput, &engine->audioOutput, &engine->controllers);
    if (NES_FAILED(result)) {
        engine->lastError = "Nestopia failed while running a frame (error " + std::to_string(result) + ").";
        return false;
    }
    return true;
}

double nes_engine_frame_duration(const NESEngine *engine)
{
    return engine != nullptr && engine->machine.GetMode() == Nes::Api::Machine::PAL ? 1.0 / 50.0 : 1.0 / 60.0;
}

const uint32_t *nes_engine_video_buffer(const NESEngine *engine) { return engine == nullptr ? nullptr : engine->videoBuffer.data(); }
size_t nes_engine_video_pixel_count(void) { return videoWidth * videoHeight; }
const int16_t *nes_engine_audio_buffer(const NESEngine *engine) { return engine == nullptr ? nullptr : engine->audioBuffer.data(); }
size_t nes_engine_audio_sample_count(const NESEngine *engine) { return engine == nullptr ? 0 : engine->audioSamples; }
uint32_t nes_engine_audio_sample_rate(void) { return audioSampleRate; }

void nes_engine_set_button(NESEngine *engine, unsigned player, NESButton button, bool pressed)
{
    if (engine == nullptr || player >= Nes::Api::Input::NUM_PADS) return;
    if (pressed) engine->controllers.pad[player].buttons |= button;
    else engine->controllers.pad[player].buttons &= ~button;
}

void nes_engine_reset_inputs(NESEngine *engine)
{
    if (engine == nullptr) return;
    for (unsigned player = 0; player < Nes::Api::Input::NUM_PADS; ++player) {
        engine->controllers.pad[player].buttons = 0;
    }
}

void nes_engine_reset(NESEngine *engine, bool hardReset)
{
    if (engine != nullptr && engine->loaded) engine->machine.Reset(hardReset);
}

bool nes_engine_save_state(NESEngine *engine, const char *path)
{
    if (engine == nullptr || !engine->loaded || path == nullptr) return false;
    std::ofstream stream(path, std::ios::out | std::ios::binary | std::ios::trunc);
    return stream.good() && NES_SUCCEEDED(engine->machine.SaveState(stream));
}

bool nes_engine_load_state(NESEngine *engine, const char *path)
{
    if (engine == nullptr || !engine->loaded || path == nullptr) return false;
    std::ifstream stream(path, std::ios::in | std::ios::binary);
    return stream.good() && NES_SUCCEEDED(engine->machine.LoadState(stream));
}

bool nes_engine_add_game_genie_code(NESEngine *engine, const char *code)
{
    if (engine == nullptr || code == nullptr) return false;
    Nes::Api::Cheats::Code decoded;
    return NES_SUCCEEDED(Nes::Api::Cheats::GameGenieDecode(code, decoded)) && NES_SUCCEEDED(engine->cheats.SetCode(decoded));
}

void nes_engine_clear_cheats(NESEngine *engine)
{
    if (engine != nullptr) engine->cheats.ClearCodes();
}

const char *nes_engine_last_error(const NESEngine *engine)
{
    return engine == nullptr ? "The engine is unavailable." : engine->lastError.c_str();
}
