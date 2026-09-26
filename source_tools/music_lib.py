"""Pequeña librería de composición para Fragmentos de Luz (fase 6).

Escribe MIDI con mido, lo interpreta con FluidSynth y el banco General MIDI FluidR3 (licencia MIT)
y lo mezcla con Pedalboard (reverb de sala, compresión suave y limitador).

Requisitos:  pip install mido pedalboard soundfile pyloudnorm numpy
             fluidsynth + FluidR3_GM.sf2   (Ubuntu: apt install fluidsynth fluid-soundfont-gm)
"""
from __future__ import annotations

import os
import random
import shutil
import subprocess
import tempfile

import mido
import numpy as np
import pyloudnorm
import soundfile
from pedalboard import (Compressor, Gain, HighpassFilter, HighShelfFilter, Limiter, LowShelfFilter, Pedalboard,
                        Reverb)

SOUNDFONT_CANDIDATES = [
    os.environ.get("FDL_SOUNDFONT", ""),
    "/usr/share/sounds/sf2/FluidR3_GM.sf2",
    "/usr/share/soundfonts/FluidR3_GM.sf2",
    r"C:\soundfonts\FluidR3_GM.sf2",
]
RATE = 44100
TPB = 480
NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# Programas General MIDI (base 0).
CELESTA, GLOCKENSPIEL, MUSIC_BOX, TUBULAR_BELLS = 8, 9, 10, 14
VIOLIN, VIOLA, CELLO, CONTRABASS, TREMOLO, PIZZICATO, HARP, TIMPANI = 40, 41, 42, 43, 44, 45, 46, 47
STRINGS, SLOW_STRINGS, CHOIR, OOHS = 48, 49, 52, 53
TRUMPET, TROMBONE, HORN, BRASS = 56, 57, 60, 61
OBOE, BASSOON, CLARINET, PICCOLO, FLUTE = 68, 70, 71, 72, 73
PAD_NEW_AGE, PAD_WARM, PAD_CHOIR, PAD_HALO = 88, 89, 91, 94


def soundfont() -> str:
    for path in SOUNDFONT_CANDIDATES:
        if path and os.path.exists(path):
            return path
    raise FileNotFoundError("No se encontró FluidR3_GM.sf2; define FDL_SOUNDFONT")


def pitch(name: str) -> int:
    """'F#5' -> 78, 'Bb3' -> 58 (C4 = 60)."""
    step = NAMES[name[0].upper()]
    rest = name[1:]
    while rest and rest[0] in "#b":
        step += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + step


def chord(*names: str) -> list[int]:
    return [pitch(n) for n in names]


class Track:
    def __init__(self, name: str, program: int, channel: int, volume: int, pan: int, reverb: int):
        self.name, self.program, self.channel = name, program, channel
        self.volume, self.pan, self.reverb = volume, pan, reverb
        self.notes: list[tuple[float, float, int, int]] = []
        self.cc: list[tuple[float, int, int]] = []


class Song:
    def __init__(self, bpm: float, beats_per_bar: int = 4, seed: int = 7):
        self.tempos: list[tuple[float, float]] = [(0.0, bpm)]
        self.bar = beats_per_bar
        self.tracks: dict[str, Track] = {}
        self.random = random.Random(seed)
        self.channels = [c for c in range(16) if c != 9]

    def tempo(self, beat: float, bpm: float) -> None:
        self.tempos.append((beat, bpm))

    def track(self, name: str, program: int, volume: int = 100, pan: int = 64, reverb: int = 20,
              drums: bool = False) -> Track:
        channel = 9 if drums else self.channels.pop(0)
        track = Track(name, program, channel, volume, pan, reverb)
        self.tracks[name] = track
        return track

    def note(self, track: str, start: float, duration: float, note: int | str, velocity: int = 80) -> None:
        value = pitch(note) if isinstance(note, str) else note
        self.tracks[track].notes.append((start, duration, value, velocity))

    def chord(self, track: str, start: float, duration: float, notes: list, velocity: int = 70) -> None:
        for n in notes:
            self.note(track, start, duration, n, velocity)

    def melody(self, track: str, start: float, text: str, velocity: int = 82, transpose: int = 0,
               legato: float = 0.96) -> float:
        """Texto 'A4:1 D5:1.5 r:0.5 ...' (nota:duración en tiempos). Devuelve el tiempo final."""
        beat = start
        for token in text.split():
            if token == "|":
                continue
            name, length = token.split(":")
            length = float(length)
            if name != "r":
                accent = 6 if abs((beat - start) % self.bar) < 0.01 else 0
                self.note(track, beat, length * legato, pitch(name) + transpose, min(127, velocity + accent))
            beat += length
        return beat

    def swell(self, track: str, start: float, duration: float, begin: int, end: int, steps: int = 12) -> None:
        for i in range(steps + 1):
            t = i / steps
            self.tracks[track].cc.append((start + duration * t, 11, int(begin + (end - begin) * t)))

    def expression(self, track: str, beat: float, value: int) -> None:
        self.tracks[track].cc.append((beat, 11, value))

    def length_beats(self) -> float:
        end = 0.0
        for track in self.tracks.values():
            for start, duration, _, _ in track.notes:
                end = max(end, start + duration)
        return end

    def seconds(self, beats: float) -> float:
        total, last_beat, bpm = 0.0, 0.0, self.tempos[0][1]
        for beat, new_bpm in sorted(self.tempos)[1:]:
            if beat >= beats:
                break
            total += (beat - last_beat) * 60.0 / bpm
            last_beat, bpm = beat, new_bpm
        return total + (beats - last_beat) * 60.0 / bpm

    def write(self, path: str, repeats: int = 1, loop_beats: float | None = None, humanize: float = 0.012) -> None:
        loop = loop_beats if loop_beats is not None else self.length_beats()
        midi = mido.MidiFile(ticks_per_beat=TPB)
        meta = mido.MidiTrack()
        midi.tracks.append(meta)
        events = []
        for r in range(repeats):
            for beat, bpm in self.tempos:
                events.append((beat + r * loop, mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(bpm))))
        self._flush(meta, events)
        for track in self.tracks.values():
            midi_track = mido.MidiTrack()
            midi.tracks.append(midi_track)
            ch = track.channel
            setup = [mido.Message("control_change", channel=ch, control=7, value=track.volume),
                     mido.Message("control_change", channel=ch, control=10, value=track.pan),
                     mido.Message("control_change", channel=ch, control=91, value=track.reverb),
                     mido.Message("control_change", channel=ch, control=93, value=0),
                     mido.Message("control_change", channel=ch, control=11, value=110)]
            if ch != 9:
                setup.append(mido.Message("program_change", channel=ch, program=track.program))
            events = [(0.0, m) for m in setup]
            # La humanización se decide una vez por nota: cada repetición del bucle suena igual.
            human = [(self.random.uniform(-humanize, humanize) if humanize else 0.0, self.random.randint(-5, 5))
                     for _ in track.notes]
            for r in range(repeats):
                offset = r * loop
                for (start, duration, note, velocity), (jitter, spread) in zip(track.notes, human):
                    vel = max(1, min(127, velocity + spread))
                    on = max(0.0, start + offset + jitter)
                    events.append((on, mido.Message("note_on", channel=ch, note=note, velocity=vel)))
                    events.append((on + max(0.05, duration), mido.Message("note_off", channel=ch, note=note, velocity=0)))
                for beat, control, value in track.cc:
                    events.append((beat + offset, mido.Message("control_change", channel=ch, control=control,
                                                               value=max(0, min(127, value)))))
            self._flush(midi_track, events)
        midi.save(path)

    @staticmethod
    def _flush(track: mido.MidiTrack, events: list) -> None:
        order = {"set_tempo": 0, "control_change": 1, "program_change": 1, "note_off": 2, "note_on": 3}
        events.sort(key=lambda e: (round(e[0] * TPB), order.get(e[1].type, 4)))
        last = 0
        for beat, message in events:
            tick = int(round(beat * TPB))
            message.time = tick - last
            last = tick
            track.append(message)


def render_midi(midi_path: str, wav_path: str, gain: float = 0.55) -> np.ndarray:
    fluid = shutil.which("fluidsynth")
    if not fluid:
        raise FileNotFoundError("fluidsynth no está instalado")
    subprocess.run([fluid, "-ni", "-q", "-g", str(gain), "-r", str(RATE),
                    "-o", "synth.reverb.active=0", "-o", "synth.chorus.active=0",
                    "-F", wav_path, soundfont(), midi_path], check=True)
    audio, rate = soundfile.read(wav_path, always_2d=True)
    assert rate == RATE
    return audio.astype(np.float32)


def master(audio: np.ndarray, room: float = 0.82, wet: float = 0.26, brightness: float = 1.5) -> np.ndarray:
    board = Pedalboard([
        HighpassFilter(cutoff_frequency_hz=35),
        LowShelfFilter(cutoff_frequency_hz=180, gain_db=-1.5),
        HighShelfFilter(cutoff_frequency_hz=6500, gain_db=brightness),
        Reverb(room_size=room, damping=0.45, wet_level=wet, dry_level=0.82, width=1.0),
        Compressor(threshold_db=-20, ratio=2.2, attack_ms=25, release_ms=250),
    ])
    return board(audio.T, RATE).T


def normalize(audio: np.ndarray, lufs: float, ceiling_db: float = -1.5) -> np.ndarray:
    """Normaliza a la sonoridad integrada pedida; si un pico supera el techo, baja toda la pista."""
    meter = pyloudnorm.Meter(RATE)
    loudness = meter.integrated_loudness(audio)
    if np.isfinite(loudness):
        audio = audio * (10 ** ((lufs - loudness) / 20.0))
    ceiling = 10 ** (ceiling_db / 20.0)
    peak = float(np.abs(audio).max())
    if peak > ceiling:
        audio = audio * (ceiling / peak)
    return audio.astype(np.float32)


def fade(audio: np.ndarray, fade_in: float = 0.0, fade_out: float = 0.0) -> np.ndarray:
    audio = audio.copy()
    if fade_in > 0:
        n = int(fade_in * RATE)
        audio[:n] *= np.linspace(0, 1, n)[:, None]
    if fade_out > 0:
        n = int(fade_out * RATE)
        audio[-n:] *= np.linspace(1, 0, n)[:, None] ** 1.5
    return audio


def write_ogg(audio: np.ndarray, path: str, quality: int = 5) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "out.wav")
        soundfile.write(wav, np.clip(audio, -1, 1), RATE, subtype="PCM_16")
        ffmpeg = shutil.which("ffmpeg")
        if not ffmpeg:
            raise FileNotFoundError("ffmpeg no está instalado")
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality), path],
                       check=True)


def render_song(song: Song, loop: bool, workdir: str, name: str, lufs: float = -28.0, room: float = 0.82,
                wet: float = 0.26, tail: float = 7.0, gain: float = 0.55) -> tuple[np.ndarray, float]:
    """Interpreta la canción. Con loop=True devuelve exactamente un ciclo que incluye la cola del anterior."""
    midi = os.path.join(workdir, name + ".mid")
    wav = os.path.join(workdir, name + ".wav")
    loop_beats = song.length_beats() if not loop else song.loop_beats
    if loop:
        song.write(midi, repeats=3, loop_beats=loop_beats)
    else:
        song.write(midi, repeats=1)
    audio = render_midi(midi, wav, gain=gain)
    audio = master(audio, room=room, wet=wet)
    seconds = song.seconds(loop_beats)
    if loop:
        start = int(round(seconds * RATE))
        end = int(round(2 * seconds * RATE))
        segment = audio[start:end].copy()
        # Costura sin clic: el final del ciclo se funde con lo que precede a su propio comienzo.
        blend = int(0.06 * RATE)
        ramp = np.linspace(0.0, 1.0, blend)[:, None] ** 0.5
        segment[-blend:] = segment[-blend:] * (1.0 - ramp) + audio[start - blend:start] * ramp
        audio = segment
    else:
        total = int((seconds + tail) * RATE)
        audio = np.pad(audio, ((0, max(0, total - len(audio))), (0, 0)))[:total]
        audio = fade(audio, 0.0, min(tail, 5.0))
    return normalize(audio, lufs), seconds
