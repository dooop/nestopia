// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

#ifndef NES_ENGINE_H
#define NES_ENGINE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NESEngine NESEngine;

typedef enum NESButton {
    NES_BUTTON_A = 0x01,
    NES_BUTTON_B = 0x02,
    NES_BUTTON_SELECT = 0x04,
    NES_BUTTON_START = 0x08,
    NES_BUTTON_UP = 0x10,
    NES_BUTTON_DOWN = 0x20,
    NES_BUTTON_LEFT = 0x40,
    NES_BUTTON_RIGHT = 0x80,
} NESButton;

NESEngine *nes_engine_create(const char *database_path);
void nes_engine_destroy(NESEngine *engine);

bool nes_engine_load_rom(NESEngine *engine, const char *rom_path, const char *battery_path);
void nes_engine_unload_rom(NESEngine *engine);
bool nes_engine_is_loaded(const NESEngine *engine);

bool nes_engine_run_frame(NESEngine *engine);
double nes_engine_frame_duration(const NESEngine *engine);

const uint32_t *nes_engine_video_buffer(const NESEngine *engine);
size_t nes_engine_video_pixel_count(void);
const int16_t *nes_engine_audio_buffer(const NESEngine *engine);
size_t nes_engine_audio_sample_count(const NESEngine *engine);
uint32_t nes_engine_audio_sample_rate(void);

void nes_engine_set_button(NESEngine *engine, unsigned player, NESButton button, bool pressed);
void nes_engine_reset_inputs(NESEngine *engine);
void nes_engine_reset(NESEngine *engine, bool hard_reset);

bool nes_engine_save_state(NESEngine *engine, const char *path);
bool nes_engine_load_state(NESEngine *engine, const char *path);
bool nes_engine_add_game_genie_code(NESEngine *engine, const char *code);
void nes_engine_clear_cheats(NESEngine *engine);

const char *nes_engine_last_error(const NESEngine *engine);

#ifdef __cplusplus
}
#endif

#endif
