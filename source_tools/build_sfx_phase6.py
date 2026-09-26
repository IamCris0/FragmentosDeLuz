"""Efectos de la fase 6: notas de las runas, jingle del jardín, fragmentos que ascienden, encendido del faro,
campanas de las islas, disolución de la barrera y sonidos del menú.

Uso: python source_tools/build_sfx_phase6.py
Salida: godot/assets/audio/<efecto>.wav (PCM 16 bits, 44,1 kHz)
Las notas de las runas siguen el motivo OLA=La4, SOL=Re5, ESTRELLA=Fa#5 de la banda sonora.
"""
import json
import os
import sys
import tempfile

import numpy as np
import soundfile
from pedalboard import HighpassFilter, LowpassFilter, Pedalboard, Reverb

sys.path.insert(0, os.path.dirname(__file__))
from music_lib import (CELESTA, CHOIR, GLOCKENSPIEL, HARP, RATE, SLOW_STRINGS, TIMPANI, TUBULAR_BELLS, Song,  # noqa
                       chord, fade, normalize, pitch, render_midi)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "godot", "assets", "audio")
RNG = np.random.default_rng(1926)


def midi_clip(work: str, name: str, build, seconds: float, room: float = 0.6, wet: float = 0.3) -> np.ndarray:
    song = Song(120, 4, seed=5)
    build(song)
    path = os.path.join(work, name + ".mid")
    song.write(path, humanize=0.0)
    audio = render_midi(path, os.path.join(work, name + ".wav"), gain=0.7)
    total = int(seconds * RATE)
    audio = np.pad(audio, ((0, max(0, total - len(audio))), (0, 0)))[:total]
    board = Pedalboard([HighpassFilter(60), Reverb(room_size=room, wet_level=wet, dry_level=0.85, width=1.0)])
    return board(audio.T, RATE).T


def noise_sweep(seconds: float, start_hz: float, end_hz: float, attack: float, release: float) -> np.ndarray:
    n = int(seconds * RATE)
    noise = RNG.standard_normal((n, 2)).astype(np.float32) * 0.3
    out = np.zeros_like(noise)
    blocks = 24
    for b in range(blocks):
        a, z = b * n // blocks, (b + 1) * n // blocks
        t = b / (blocks - 1)
        cutoff = start_hz * (end_hz / start_hz) ** t
        board = Pedalboard([HighpassFilter(max(40.0, cutoff * 0.35)), LowpassFilter(cutoff)])
        out[a:z] = board(noise[a:z].T, RATE).T
    env = np.minimum(np.linspace(0, 1, n) / max(attack / seconds, 1e-3), 1.0)
    env *= np.clip((seconds - np.arange(n) / RATE) / release, 0, 1)
    return out * env[:, None]


def boom(seconds: float, f0: float = 52.0, f1: float = 30.0) -> np.ndarray:
    t = np.arange(int(seconds * RATE)) / RATE
    freq = f0 * (f1 / f0) ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    wave = np.sin(phase) * np.exp(-t * 1.4) * np.minimum(t / 0.02, 1)
    return np.stack([wave, wave], axis=1).astype(np.float32) * 0.8


def save(name: str, audio: np.ndarray, lufs: float) -> dict:
    audio = normalize(audio.astype(np.float32), lufs, ceiling_db=-1.0)
    path = os.path.join(OUT, name + ".wav")
    soundfile.write(path, audio, RATE, subtype="PCM_16")
    print("SFX", name, round(len(audio) / RATE, 2))
    return {"seconds": round(len(audio) / RATE, 2), "lufs": lufs}


def main() -> None:
    metrics = {}
    with tempfile.TemporaryDirectory() as work:
        for index, note in enumerate(("A4", "D5", "F#5")):
            def rune(song: Song, note=note) -> None:
                song.track("harp", HARP, 110, 54)
                song.track("celesta", CELESTA, 100, 74)
                song.track("glock", GLOCKENSPIEL, 60, 64)
                song.note("harp", 0, 2.0, note, 96)
                song.note("celesta", 0, 2.0, note, 88)
                song.note("glock", 0.06, 1.0, pitch(note) + 12, 50)
            metrics["rune_%d" % index] = save("rune_%d" % index, fade(midi_clip(work, "rune%d" % index, rune, 1.8, 0.7, 0.35), 0, 0.4), -22)

        def solved(song: Song) -> None:
            song.track("harp", HARP, 110, 50)
            song.track("celesta", CELESTA, 100, 78)
            song.track("strings", SLOW_STRINGS, 90, 64)
            song.track("choir", CHOIR, 70, 64)
            song.track("bells", TUBULAR_BELLS, 60, 70)
            for k, note in enumerate(("A4", "D5", "F#5", "A5")):
                song.note("harp", k * 0.24, 2.4, note, 96)
                song.note("celesta", k * 0.24, 2.4, note, 84)
            song.chord("strings", 0.9, 3.2, chord("D4", "F#4", "A4", "D5"), 78)
            song.chord("choir", 0.9, 3.2, chord("A4", "D5", "F#5"), 64)
            song.note("bells", 0.96, 3.0, "D5", 70)
        metrics["solved"] = save("solved", fade(midi_clip(work, "solved", solved, 4.2, 0.8, 0.35), 0, 1.2), -20)

        def rise(song: Song) -> None:
            song.track("celesta", CELESTA, 100, 64)
            song.track("glock", GLOCKENSPIEL, 80, 80)
            for k, note in enumerate(("D5", "E5", "F#5", "A5", "B5", "D6")):
                song.note("celesta", k * 0.11, 0.8, note, 70 + k * 4)
                if k % 2 == 1:
                    song.note("glock", k * 0.11, 0.6, pitch(note) + 12, 52)
        sparkle = midi_clip(work, "rise", rise, 1.5, 0.7, 0.4)
        air = noise_sweep(1.5, 1800, 9000, 0.35, 0.8) * 0.18
        metrics["fragment_rise"] = save("fragment_rise", fade(sparkle + air, 0, 0.5), -25)

        def ignite(song: Song) -> None:
            song.track("choir", CHOIR, 110, 64)
            song.track("strings", SLOW_STRINGS, 110, 64)
            song.track("timpani", TIMPANI, 110, 64)
            song.track("bells", TUBULAR_BELLS, 90, 64)
            song.track("celesta", CELESTA, 90, 80)
            song.chord("choir", 0.2, 8.0, chord("D4", "F#4", "A4", "D5", "F#5"), 92)
            song.chord("strings", 0.0, 8.0, chord("D3", "A3", "D4", "F#4", "A4"), 90)
            song.swell("choir", 0.2, 2.0, 40, 120)
            song.swell("strings", 0.0, 2.2, 30, 120)
            for i in range(16):
                song.note("timpani", i * 0.125, 0.2, "D2", 30 + i * 5)
            song.note("timpani", 2.0, 2.0, "D2", 120)
            song.note("bells", 2.0, 5.0, "D4", 100)
            song.note("bells", 2.02, 5.0, "A4", 80)
            for k, note in enumerate(("A5", "D6", "F#6", "A6")):
                song.note("celesta", 2.0 + k * 0.18, 3.0, note, 80)
        swell = midi_clip(work, "ignite", ignite, 6.0, 0.9, 0.35)
        hit = np.zeros_like(swell)
        start = int(1.0 * RATE)
        low = boom(3.5)
        hit[start:start + len(low)] += low[: len(hit) - start]
        whoosh = noise_sweep(6.0, 200, 5000, 0.95, 4.5) * 0.35
        metrics["beacon_ignite"] = save("beacon_ignite", fade(swell + hit * 0.6 + whoosh, 0, 1.5), -17)

        def island(song: Song) -> None:
            song.track("glock", GLOCKENSPIEL, 90, 64)
            song.track("celesta", CELESTA, 90, 64)
            song.note("glock", 0, 2.0, "A5", 70)
            song.note("celesta", 0, 2.0, "D6", 60)
        metrics["island_chime"] = save("island_chime", fade(midi_clip(work, "island", island, 2.8, 0.95, 0.55), 0, 0.8), -27)

        def dissolve(song: Song) -> None:
            song.track("harp", HARP, 110, 64)
            song.track("celesta", CELESTA, 70, 70)
            scale = ["D6", "C#6", "B5", "A5", "G5", "F#5", "E5", "D5", "C#5", "B4", "A4", "G4", "F#4", "E4", "D4"]
            for k, note in enumerate(scale):
                song.note("harp", k * 0.06, 1.2, note, 90 - k * 2)
                if k % 3 == 0:
                    song.note("celesta", k * 0.06, 1.2, note, 60)
        gliss = midi_clip(work, "dissolve", dissolve, 2.8, 0.8, 0.4)
        shimmer = noise_sweep(2.8, 9000, 1200, 0.3, 1.6) * 0.22
        metrics["gate_dissolve"] = save("gate_dissolve", fade(gliss + shimmer, 0, 0.8), -22)

        def ui_move(song: Song) -> None:
            song.track("harp", HARP, 100, 64)
            song.note("harp", 0, 0.5, "A5", 64)
        metrics["ui_move"] = save("ui_move", fade(midi_clip(work, "ui_move", ui_move, 0.45, 0.3, 0.12), 0, 0.2), -30)

        def ui_select(song: Song) -> None:
            song.track("celesta", CELESTA, 100, 64)
            song.track("harp", HARP, 90, 64)
            song.note("celesta", 0, 0.8, "A5", 80)
            song.note("celesta", 0.14, 0.9, "D6", 86)
            song.note("harp", 0.14, 0.9, "D5", 70)
        metrics["ui_select"] = save("ui_select", fade(midi_clip(work, "ui_select", ui_select, 0.9, 0.4, 0.2), 0, 0.3), -25)

        def ui_back(song: Song) -> None:
            song.track("harp", HARP, 100, 64)
            song.note("harp", 0, 0.6, "D5", 70)
            song.note("harp", 0.1, 0.6, "A4", 64)
        metrics["ui_back"] = save("ui_back", fade(midi_clip(work, "ui_back", ui_back, 0.6, 0.3, 0.15), 0, 0.25), -28)

        metrics["cine_whoosh"] = save("cine_whoosh", noise_sweep(1.4, 300, 6000, 0.9, 0.5), -26)
    target = os.path.join(ROOT, "blender", "phase6_sfx_metrics.json")
    with open(target, "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)


if __name__ == "__main__":
    main()
