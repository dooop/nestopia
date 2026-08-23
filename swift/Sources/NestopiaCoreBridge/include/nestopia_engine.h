// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

#ifndef NESTOPIA_ENGINE_H
#define NESTOPIA_ENGINE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NestopiaEngine NestopiaEngine;

typedef enum NestopiaButton {
    NESTOPIA_BUTTON_A = 0x01,
    NESTOPIA_BUTTON_B = 0x02,
    NESTOPIA_BUTTON_SELECT = 0x04,
    NESTOPIA_BUTTON_START = 0x08,
    NESTOPIA_BUTTON_UP = 0x10,
    NESTOPIA_BUTTON_DOWN = 0x20,
    NESTOPIA_BUTTON_LEFT = 0x40,
    NESTOPIA_BUTTON_RIGHT = 0x80,
} NestopiaButton;

NestopiaEngine *nestopia_engine_create(const char *database_path);
void nestopia_engine_destroy(NestopiaEngine *engine);

bool nestopia_engine_load_rom(NestopiaEngine *engine, const char *rom_path, const char *battery_path);
void nestopia_engine_unload_rom(NestopiaEngine *engine);
bool nestopia_engine_is_loaded(const NestopiaEngine *engine);

bool nestopia_engine_run_frame(NestopiaEngine *engine);
double nestopia_engine_frame_duration(const NestopiaEngine *engine);

const uint32_t *nestopia_engine_video_buffer(const NestopiaEngine *engine);
size_t nestopia_engine_video_pixel_count(void);
const int16_t *nestopia_engine_audio_buffer(const NestopiaEngine *engine);
size_t nestopia_engine_audio_sample_count(const NestopiaEngine *engine);
uint32_t nestopia_engine_audio_sample_rate(void);

void nestopia_engine_set_button(NestopiaEngine *engine, unsigned player, NestopiaButton button, bool pressed);
void nestopia_engine_reset_inputs(NestopiaEngine *engine);
void nestopia_engine_reset(NestopiaEngine *engine, bool hard_reset);

bool nestopia_engine_save_state(NestopiaEngine *engine, const char *path);
bool nestopia_engine_load_state(NestopiaEngine *engine, const char *path);
bool nestopia_engine_add_game_genie_code(NestopiaEngine *engine, const char *code);
void nestopia_engine_clear_cheats(NestopiaEngine *engine);

const char *nestopia_engine_last_error(const NestopiaEngine *engine);

#ifdef __cplusplus
}
#endif

#endif
