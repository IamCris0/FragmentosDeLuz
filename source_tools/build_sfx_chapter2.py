"""Efectos del Capítulo II · La Señal Imposible (fase 7).

Uso: python source_tools/build_sfx_chapter2.py            (todos)
     python source_tools/build_sfx_chapter2.py nova valve  (solo algunos)
Salida: godot/assets/audio/<efecto>.wav (PCM 16 bits, 44,1 kHz) y blender/chapter2_sfx_metrics.json

Los efectos musicales usan el leitmotiv de la Señal (Mi5-Si5-La5-Mi5) para que la moneda, las habilidades,
la constelación y la llave suenen a la misma historia. `updraft` es un bucle continuo sin costuras.
"""
import json
import os
import sys
import tempfile

import numpy as np
from pedalboard import HighpassFilter, LowpassFilter, Pedalboard, Reverb

sys.path.insert(0, os.path.dirname(__file__))
from build_sfx_phase6 import boom, midi_clip, noise_sweep, save  # noqa: E402
from music_lib import (BRASS, CELESTA, CHOIR, CONTRABASS, GLOCKENSPIEL, HARP, HORN, MUSIC_BOX, OOHS,  # noqa: E402
                       PAD_HALO, PAD_NEW_AGE, RATE, SLOW_STRINGS, STRINGS, TIMPANI, TREMOLO, TROMBONE, TUBULAR_BELLS,
                       Song, chord, fade, pitch)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RNG = np.random.default_rng(2207)
SIGNAL = ("E5", "B5", "A5", "E5")


# --- Síntesis -----------------------------------------------------------------------------------------

def silence(seconds: float) -> np.ndarray:
    return np.zeros((int(seconds * RATE), 2), dtype=np.float32)


def place(target: np.ndarray, clip: np.ndarray, at: float, gain: float = 1.0) -> np.ndarray:
    start = int(at * RATE)
    end = min(len(target), start + len(clip))
    if end > start:
        target[start:end] += clip[: end - start] * gain
    return target


def envelope(n: int, attack: float, release: float, curve: float = 1.6) -> np.ndarray:
    t = np.arange(n) / RATE
    total = n / RATE
    env = np.minimum(t / max(attack, 1e-4), 1.0)
    env *= np.clip((total - t) / max(release, 1e-4), 0, 1) ** curve
    return env


def glide_tone(seconds: float, f0: float, f1: float, attack: float = 0.01, release: float = 0.2,
               harmonics=(1.0, 0.35, 0.12), vibrato: float = 0.0, tremolo: float = 0.0) -> np.ndarray:
    """Tono con glissando exponencial y armónicos; vibrato/tremolo en Hz."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    freq = f0 * (f1 / f0) ** (t / seconds)
    if vibrato:
        freq = freq * (1 + 0.012 * np.sin(2 * np.pi * vibrato * t))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    wave = sum(a * np.sin(phase * (k + 1)) for k, a in enumerate(harmonics))
    wave = wave / sum(harmonics)
    if tremolo:
        wave *= 0.65 + 0.35 * np.sin(2 * np.pi * tremolo * t)
    wave *= envelope(n, attack, release)
    left = wave
    right = np.roll(wave, 18)
    return np.stack([left, right], axis=1).astype(np.float32)


def buzz(seconds: float, f0: float, f1: float, attack: float = 0.02, release: float = 0.3) -> np.ndarray:
    """Diente de sierra suavizado (el rayo del Heraldo)."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    freq = f0 * (f1 / f0) ** (t / seconds)
    phase = np.cumsum(freq) / RATE
    saw = 2 * (phase % 1.0) - 1
    saw = saw * envelope(n, attack, release)
    stereo = np.stack([saw, np.roll(saw, 31)], axis=1).astype(np.float32)
    return Pedalboard([LowpassFilter(2600), HighpassFilter(90)])(stereo.T, RATE).T


def band_noise(seconds: float, low: float, high: float, attack: float, release: float) -> np.ndarray:
    n = int(seconds * RATE)
    noise = RNG.standard_normal((n, 2)).astype(np.float32) * 0.35
    noise = Pedalboard([HighpassFilter(low), LowpassFilter(high)])(noise.T, RATE).T
    return noise * envelope(n, attack, release)[:, None]


def crackle(seconds: float, count: int, low: float = 900.0, high: float = 5000.0) -> np.ndarray:
    """Chasquidos de piedra y cristal distribuidos en el tiempo."""
    out = silence(seconds)
    for _ in range(count):
        at = RNG.uniform(0.0, seconds * 0.8)
        length = RNG.uniform(0.015, 0.06)
        click = band_noise(length, low, high, 0.001, length * 0.9) * RNG.uniform(0.5, 1.4)
        pan = RNG.uniform(0.3, 1.0)
        click[:, 0] *= pan
        click[:, 1] *= 1.3 - pan
        place(out, click, at)
    return out


def space(audio: np.ndarray, room: float = 0.6, wet: float = 0.25) -> np.ndarray:
    return Pedalboard([Reverb(room_size=room, wet_level=wet, dry_level=0.9, width=1.0)])(audio.T, RATE).T


def seamless(audio: np.ndarray, overlap: float) -> np.ndarray:
    """Convierte un clip en bucle: funde la cola sobre el inicio (potencia constante)."""
    n = int(overlap * RATE)
    body = audio[: len(audio) - n].copy()
    tail = audio[len(audio) - n:]
    k = np.linspace(0, 1, n)[:, None]
    body[:n] = body[:n] * np.sqrt(k) + tail * np.sqrt(1 - k)
    return body


# --- Efectos ------------------------------------------------------------------------------------------

def build(work: str, only: set) -> dict:
    metrics = {}

    def want(name: str) -> bool:
        return not only or name in only

    if want("destello"):
        def destello(song: Song) -> None:
            song.track("celesta", CELESTA, 100, 54)
            song.track("glock", GLOCKENSPIEL, 80, 74)
            song.note("celesta", 0.0, 1.0, "B5", 84)
            song.note("celesta", 0.09, 1.2, "E6", 92)
            song.note("glock", 0.09, 0.8, "E7", 58)
            song.note("glock", 0.18, 0.8, "B6", 46)
        sparkle = midi_clip(work, "destello", destello, 1.3, 0.75, 0.4)
        metrics["destello"] = save("destello", fade(sparkle + noise_sweep(1.3, 3000, 11000, 0.1, 0.9) * 0.12, 0, 0.5), -24)

    if want("skill_unlock"):
        def skill(song: Song) -> None:
            song.track("harp", HARP, 110, 50)
            song.track("celesta", CELESTA, 100, 78)
            song.track("choir", CHOIR, 80, 64)
            song.track("strings", SLOW_STRINGS, 80, 64)
            for k, note in enumerate(("E4", "G#4", "B4", "E5", "G#5", "B5")):
                song.note("harp", k * 0.08, 2.0, note, 90)
            for k, note in enumerate(SIGNAL):
                song.note("celesta", 0.55 + k * 0.16, 1.4, note, 86)
            song.chord("choir", 0.5, 2.2, chord("E4", "B4", "E5", "G#5"), 70)
            song.chord("strings", 0.5, 2.2, chord("E3", "B3", "G#4"), 64)
            song.swell("choir", 0.5, 0.8, 40, 110)
        clip = midi_clip(work, "skill", skill, 3.0, 0.85, 0.35)
        metrics["skill_unlock"] = save("skill_unlock", fade(clip + noise_sweep(3.0, 1200, 9000, 0.6, 2.0) * 0.14, 0, 1.0), -20)

    if want("double_jump"):
        air = noise_sweep(0.42, 700, 6000, 0.05, 0.3) * 0.9
        blip = glide_tone(0.3, 988, 1318, 0.005, 0.25, harmonics=(1.0, 0.2)) * 0.25
        metrics["double_jump"] = save("double_jump", space(place(air, blip, 0.02), 0.4, 0.2), -25)

    if want("glide"):
        wings = band_noise(1.1, 700, 2600, 0.25, 0.7)
        shimmer = glide_tone(1.1, 1318, 1480, 0.3, 0.7, harmonics=(1.0, 0.3), tremolo=7.0) * 0.12
        metrics["glide"] = save("glide", space(wings + shimmer, 0.7, 0.3), -29)

    if want("nova"):
        def nova(song: Song) -> None:
            song.track("choir", CHOIR, 110, 64)
            song.track("bells", TUBULAR_BELLS, 90, 64)
            song.track("glock", GLOCKENSPIEL, 80, 64)
            song.chord("choir", 0.0, 1.6, chord("E4", "B4", "E5", "G#5"), 96)
            song.note("bells", 0.0, 1.8, "E5", 96)
            for k, note in enumerate(("E6", "G#6", "B6", "E7")):
                song.note("glock", 0.05 + k * 0.05, 0.8, note, 70)
        body = midi_clip(work, "nova", nova, 2.0, 0.8, 0.3)
        low = silence(2.0)
        place(low, boom(1.5, 70, 32), 0.0)
        sweep = noise_sweep(2.0, 8000, 400, 0.02, 1.6) * 0.5
        metrics["nova"] = save("nova", fade(body + low * 0.8 + sweep, 0, 0.6), -18)

    if want("shield_block"):
        def block(song: Song) -> None:
            song.track("bells", TUBULAR_BELLS, 110, 64)
            song.track("glock", GLOCKENSPIEL, 90, 64)
            song.note("bells", 0.0, 1.3, "B5", 100)
            song.note("glock", 0.0, 0.9, "E7", 80)
        ring = midi_clip(work, "block", block, 1.3, 0.5, 0.25)
        hit = band_noise(0.12, 1500, 9000, 0.001, 0.1)
        metrics["shield_block"] = save("shield_block", fade(place(ring, hit, 0.0, 0.8), 0, 0.4), -20)

    if want("shield_ready"):
        def ready(song: Song) -> None:
            song.track("celesta", CELESTA, 100, 64)
            song.note("celesta", 0.0, 0.9, "B5", 70)
            song.note("celesta", 0.14, 1.0, "E6", 78)
        metrics["shield_ready"] = save("shield_ready", fade(midi_clip(work, "ready", ready, 1.1, 0.6, 0.3), 0, 0.4), -26)

    if want("key_obtained"):
        def key(song: Song) -> None:
            song.track("brass", BRASS, 100, 64)
            song.track("horn", HORN, 100, 50)
            song.track("strings", STRINGS, 100, 64)
            song.track("celesta", CELESTA, 100, 80)
            song.track("bells", TUBULAR_BELLS, 80, 64)
            song.track("timpani", TIMPANI, 100, 64)
            for k, note in enumerate(SIGNAL):
                song.note("celesta", k * 0.22, 1.2, note, 90)
                song.note("horn", k * 0.22, 0.5 if k < 3 else 2.4, pitch(note) - 12, 80)
            song.chord("brass", 0.9, 2.6, chord("E4", "G#4", "B4", "E5"), 92)
            song.chord("strings", 0.9, 2.8, chord("E3", "B3", "E4", "G#4", "B4"), 88)
            song.swell("brass", 0.9, 0.6, 50, 115)
            song.note("bells", 0.9, 3.0, "E5", 90)
            song.note("timpani", 0.9, 1.0, "E2", 105)
        metrics["key_obtained"] = save("key_obtained", fade(midi_clip(work, "key", key, 4.2, 0.85, 0.32), 0, 1.3), -18)

    if want("prism_turn"):
        tick = band_noise(0.05, 2500, 9000, 0.001, 0.045)
        grind = band_noise(0.35, 300, 1800, 0.03, 0.25) * 0.4
        chime = glide_tone(0.5, 2637, 2637, 0.003, 0.45, harmonics=(1.0, 0.1)) * 0.22
        clip = silence(0.6)
        place(clip, grind, 0.0)
        place(clip, tick, 0.28)
        place(clip, chime, 0.3)
        metrics["prism_turn"] = save("prism_turn", space(clip, 0.4, 0.2), -27)

    if want("beam_on"):
        hum = glide_tone(1.4, 220, 330, 0.08, 0.6, harmonics=(1.0, 0.5, 0.3, 0.15), tremolo=11.0) * 0.6
        high = glide_tone(1.4, 1320, 1760, 0.2, 0.7, harmonics=(1.0,)) * 0.15
        rush = noise_sweep(1.4, 800, 7000, 0.15, 0.9) * 0.25
        metrics["beam_on"] = save("beam_on", space(hum + high + rush, 0.6, 0.25), -24)

    if want("receptor_charge"):
        def charge(song: Song) -> None:
            song.track("celesta", CELESTA, 100, 64)
            song.track("pad", PAD_HALO, 80, 64)
            for k, note in enumerate(("E5", "G#5", "B5", "E6")):
                song.note("celesta", k * 0.13, 1.0, note, 70 + k * 6)
            song.chord("pad", 0.0, 1.4, chord("E4", "B4"), 70)
        clip = midi_clip(work, "charge", charge, 1.8, 0.7, 0.35)
        hum = glide_tone(1.8, 165, 330, 0.3, 0.8, harmonics=(1.0, 0.3), tremolo=6.0) * 0.18
        metrics["receptor_charge"] = save("receptor_charge", fade(clip + hum, 0, 0.5), -23)

    if want("crystal_door"):
        def door(song: Song) -> None:
            song.track("harp", HARP, 110, 64)
            song.track("celesta", CELESTA, 80, 70)
            scale = ["E6", "D#6", "B5", "A5", "G#5", "E5", "D#5", "B4", "A4", "G#4", "E4"]
            for k, note in enumerate(scale):
                song.note("harp", k * 0.07, 1.4, note, 92 - k * 3)
                if k % 2 == 0:
                    song.note("celesta", k * 0.07, 1.2, note, 60)
        gliss = midi_clip(work, "door", door, 2.6, 0.8, 0.4)
        shards = crackle(2.6, 26, 2500, 11000) * 0.5
        rumble = band_noise(2.6, 40, 220, 0.1, 1.8) * 0.6
        metrics["crystal_door"] = save("crystal_door", fade(gliss + shards + rumble, 0, 0.8), -21)

    if want("vigia_charge"):
        tone = glide_tone(1.0, 330, 1320, 0.05, 0.12, harmonics=(1.0, 0.4, 0.2), tremolo=14.0) * 0.6
        metrics["vigia_charge"] = save("vigia_charge", space(tone + band_noise(1.0, 2000, 8000, 0.8, 0.1) * 0.2, 0.4, 0.2), -25)

    if want("vigia_shot"):
        pew = glide_tone(0.4, 1600, 420, 0.003, 0.3, harmonics=(1.0, 0.5, 0.25))
        puff = band_noise(0.25, 1200, 7000, 0.002, 0.2) * 0.4
        metrics["vigia_shot"] = save("vigia_shot", space(place(pew, puff, 0.0), 0.3, 0.15), -24)

    if want("orb_pop"):
        pop = band_noise(0.12, 600, 6000, 0.001, 0.1)
        blip = glide_tone(0.35, 1800, 2600, 0.002, 0.3, harmonics=(1.0, 0.2)) * 0.35
        clip = silence(0.45)
        place(clip, pop, 0.0)
        place(clip, blip, 0.01)
        metrics["orb_pop"] = save("orb_pop", space(clip, 0.5, 0.25), -26)

    if want("cefiro_charge"):
        gust = noise_sweep(1.0, 300, 3200, 0.7, 0.15)
        whistle = glide_tone(1.0, 660, 1320, 0.4, 0.12, harmonics=(1.0,), vibrato=9.0) * 0.12
        metrics["cefiro_charge"] = save("cefiro_charge", space(gust + whistle, 0.5, 0.2), -24)

    if want("cefiro_dash"):
        metrics["cefiro_dash"] = save("cefiro_dash", space(noise_sweep(0.6, 5000, 500, 0.03, 0.45), 0.4, 0.2), -21)

    if want("wind_gust"):
        n = int(2.0 * RATE)
        rise = noise_sweep(2.0, 250, 1500, 0.8, 1.1)
        swell = np.sin(np.linspace(0, np.pi, n)) ** 1.5
        metrics["wind_gust"] = save("wind_gust", space(rise * swell[:, None], 0.8, 0.3), -26)

    if want("crumble"):
        rumble = band_noise(1.2, 40, 400, 0.02, 0.9)
        stones = crackle(1.2, 34, 600, 4000) * 0.9
        metrics["crumble"] = save("crumble", space(rumble + stones, 0.5, 0.2), -22)

    if want("valve"):
        def valve(song: Song) -> None:
            song.track("bells", TUBULAR_BELLS, 100, 64)
            song.track("timpani", TIMPANI, 100, 64)
            song.note("timpani", 0.62, 0.8, "A2", 100)
            song.note("bells", 0.62, 1.6, "E4", 80)
        clunk = midi_clip(work, "valve", valve, 1.8, 0.5, 0.25)
        creak = glide_tone(0.6, 140, 190, 0.05, 0.1, harmonics=(1.0, 0.8, 0.6, 0.4, 0.3), tremolo=23.0) * 0.4
        hiss = band_noise(1.2, 1500, 7000, 0.05, 0.9) * 0.35
        clip = clunk.copy()
        place(clip, creak, 0.0)
        place(clip, hiss, 0.6)
        metrics["valve"] = save("valve", fade(clip, 0, 0.4), -22)

    if want("star_step"):
        def step(song: Song) -> None:
            song.track("glock", GLOCKENSPIEL, 90, 64)
            song.track("box", MUSIC_BOX, 90, 64)
            song.note("glock", 0.0, 1.0, "B5", 72)
            song.note("box", 0.0, 1.0, "E6", 70)
        metrics["star_step"] = save("star_step", fade(midi_clip(work, "star", step, 1.3, 0.85, 0.45), 0, 0.5), -26)

    if want("constellation_complete"):
        def const(song: Song) -> None:
            song.track("celesta", CELESTA, 100, 64)
            song.track("harp", HARP, 100, 50)
            song.track("choir", OOHS, 90, 64)
            song.track("strings", SLOW_STRINGS, 90, 64)
            song.track("bells", TUBULAR_BELLS, 70, 64)
            for k, note in enumerate(SIGNAL):
                song.note("celesta", k * 0.3, 1.6, note, 90)
                song.note("harp", k * 0.3, 1.6, pitch(note) - 12, 80)
            song.chord("choir", 1.2, 3.0, chord("E4", "G#4", "B4", "E5"), 80)
            song.chord("strings", 1.2, 3.0, chord("E3", "B3", "G#4", "E5"), 76)
            song.swell("choir", 1.2, 1.0, 40, 110)
            song.note("bells", 1.2, 3.0, "B4", 80)
        clip = midi_clip(work, "constellation", const, 4.6, 0.9, 0.38)
        metrics["constellation_complete"] = save("constellation_complete",
                                                 fade(clip + noise_sweep(4.6, 2000, 10000, 1.2, 3.0) * 0.12, 0, 1.4), -19)

    if want("heraldo_phase"):
        def phase(song: Song) -> None:
            song.track("brass", TROMBONE, 110, 64)
            song.track("horn", HORN, 100, 64)
            song.track("strings", TREMOLO, 100, 64)
            song.track("bass", CONTRABASS, 100, 64)
            song.track("timpani", TIMPANI, 110, 64)
            song.chord("brass", 1.0, 2.4, chord("C3", "G3", "C4", "Eb4"), 104)
            song.chord("horn", 1.0, 2.4, chord("G3", "C4"), 96)
            song.chord("strings", 0.0, 3.2, chord("C3", "Eb3", "G3", "C4", "Db4"), 90)
            song.note("bass", 1.0, 2.4, "C2", 110)
            for i in range(12):
                song.note("timpani", i * 0.08, 0.1, "C2", 40 + i * 6)
            song.note("timpani", 1.0, 1.4, "C2", 124)
        clip = midi_clip(work, "phase", phase, 3.6, 0.9, 0.3)
        place(clip, boom(2.5, 58, 28), 0.5, 0.7)
        metrics["heraldo_phase"] = save("heraldo_phase", fade(clip, 0, 1.0), -17)

    if want("heraldo_laser"):
        charge = glide_tone(0.6, 200, 900, 0.05, 0.05, harmonics=(1.0, 0.5, 0.3), tremolo=18.0) * 0.5
        beam = buzz(0.9, 110, 95, 0.01, 0.5)
        sizzle = band_noise(0.9, 2500, 10000, 0.01, 0.6) * 0.3
        clip = silence(1.6)
        place(clip, charge, 0.0)
        place(clip, beam + sizzle, 0.55)
        metrics["heraldo_laser"] = save("heraldo_laser", space(clip, 0.6, 0.25), -21)

    if want("heraldo_roar"):
        def roar(song: Song) -> None:
            song.track("choir", CHOIR, 110, 64)
            song.track("brass", BRASS, 100, 64)
            song.track("bass", CONTRABASS, 100, 64)
            song.chord("choir", 0.0, 2.4, chord("C3", "Db3", "G3", "C4"), 100)
            song.chord("brass", 0.1, 2.2, chord("C3", "F#3", "C4"), 100)
            song.note("bass", 0.0, 2.4, "C2", 110)
            song.swell("choir", 0.0, 0.6, 50, 125)
        clip = midi_clip(work, "roar", roar, 3.0, 0.9, 0.3)
        growl = band_noise(3.0, 50, 500, 0.2, 1.5)
        growl *= (0.7 + 0.3 * np.sin(2 * np.pi * 9 * np.arange(len(growl)) / RATE))[:, None]
        metrics["heraldo_roar"] = save("heraldo_roar", fade(clip + growl * 0.8, 0, 0.9), -17)

    if want("pillar_charge"):
        def pillar(song: Song) -> None:
            song.track("bells", TUBULAR_BELLS, 100, 64)
            song.track("pad", PAD_NEW_AGE, 90, 64)
            song.note("bells", 0.0, 2.0, "B4", 90)
            song.note("bells", 0.4, 2.0, "E5", 96)
            song.chord("pad", 0.0, 2.0, chord("E4", "B4", "E5"), 76)
        clip = midi_clip(work, "pillar", pillar, 2.2, 0.8, 0.35)
        hum = glide_tone(2.2, 110, 220, 0.4, 0.9, harmonics=(1.0, 0.5, 0.25), tremolo=5.0) * 0.25
        metrics["pillar_charge"] = save("pillar_charge", fade(clip + hum, 0, 0.6), -22)

    if want("shield_break"):
        def shatter(song: Song) -> None:
            song.track("glock", GLOCKENSPIEL, 100, 64)
            song.track("celesta", CELESTA, 90, 64)
            for k, note in enumerate(("E7", "B6", "G#6", "E6", "B5", "G#5", "E5")):
                song.note("glock", k * 0.045, 0.8, note, 96 - k * 5)
                song.note("celesta", k * 0.045 + 0.02, 0.8, pitch(note) - 12, 70)
        clip = midi_clip(work, "shatter", shatter, 2.2, 0.8, 0.35)
        glass = band_noise(0.5, 3000, 12000, 0.001, 0.45)
        place(clip, glass, 0.0, 0.9)
        place(clip, crackle(1.4, 40, 3000, 12000), 0.05, 0.6)
        place(clip, boom(1.8, 64, 30), 0.0, 0.7)
        metrics["shield_break"] = save("shield_break", fade(clip, 0, 0.6), -18)

    if want("map_open"):
        def mapped(song: Song) -> None:
            song.track("harp", HARP, 110, 64)
            song.track("pad", PAD_HALO, 80, 64)
            for k, note in enumerate(("E4", "F#4", "G#4", "B4", "C#5", "E5", "F#5", "G#5", "B5")):
                song.note("harp", k * 0.06, 1.6, note, 70 + k * 3)
            song.chord("pad", 0.2, 2.0, chord("E4", "B4", "E5"), 70)
        clip = midi_clip(work, "map", mapped, 2.6, 0.85, 0.4)
        paper = band_noise(0.6, 1500, 7000, 0.05, 0.4) * 0.25
        metrics["map_open"] = save("map_open", fade(place(clip, paper, 0.0), 0, 0.8), -24)

    if want("travel"):
        def travel(song: Song) -> None:
            song.track("choir", OOHS, 100, 64)
            song.track("celesta", CELESTA, 90, 64)
            song.chord("choir", 0.0, 2.4, chord("E4", "B4", "E5"), 80)
            song.swell("choir", 0.0, 1.4, 30, 115)
            for k, note in enumerate(("B5", "E6", "G#6", "B6")):
                song.note("celesta", 1.0 + k * 0.1, 1.0, note, 76)
        clip = midi_clip(work, "travel", travel, 3.0, 0.9, 0.35)
        whoosh = noise_sweep(3.0, 200, 8000, 1.4, 1.2) * 0.45
        metrics["travel"] = save("travel", fade(clip + whoosh, 0, 0.9), -21)

    if want("updraft"):
        seconds, overlap = 7.0, 1.5
        n = int(seconds * RATE)
        t = np.arange(n) / RATE
        column = band_noise(seconds, 180, 1600, 0.0, 0.0001)
        airy = band_noise(seconds, 1800, 6000, 0.0, 0.0001) * 0.25
        loop_len = seconds - overlap
        mod = 0.75 + 0.25 * np.sin(2 * np.pi * t * 2 / loop_len) * np.sin(2 * np.pi * t * 3 / loop_len + 0.7)
        swirl = glide_tone(seconds, 310, 310, 0.0, 0.0001, harmonics=(1.0,), vibrato=0.6) * 0.05
        body = (column + airy) * mod[:, None] + swirl
        metrics["updraft"] = save("updraft", seamless(body, overlap), -30)
    return metrics


def main() -> None:
    only = set(sys.argv[1:])
    with tempfile.TemporaryDirectory() as work:
        metrics = build(work, only)
    target = os.path.join(ROOT, "blender", "chapter2_sfx_metrics.json")
    existing = {}
    if only and os.path.exists(target):
        with open(target, encoding="utf-8") as handle:
            existing = json.load(handle)
    existing.update(metrics)
    with open(target, "w", encoding="utf-8") as handle:
        json.dump(existing, handle, indent=2)


if __name__ == "__main__":
    main()
