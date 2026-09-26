"""Banda sonora orquestal de Fragmentos de Luz (fase 6).

Uso:  python source_tools/build_music.py            (todas las pistas)
      python source_tools/build_music.py title garden

Pistas en godot/assets/audio/music/*.ogg:
  title        Menú y prólogo. Tema de Auralia (Re mayor, 76 bpm), bucle de 24 compases.
  exploration  Umbral y Paso del Cielo. Variación ligera en Sol mayor (92 bpm), bucle.
  garden       Jardín de Ecos. Vals místico sobre el motivo OLA-SOL-ESTRELLA (La-Re-Fa#), bucle.
  sanctuary    Faro. Si menor modal con coro y campanas (60 bpm), bucle.
  combat       Tensión y guardián. Re menor, ostinato de cuerdas y timbales (126 bpm), bucle.
  finale       Cinemática final y créditos. Reexposición triunfal del tema (sin bucle).

El motivo de las runas (OLA=La4, SOL=Re5, ESTRELLA=Fa#5) aparece en el jardín, en los efectos
de las runas y en el final, para que la música cuente la historia del capítulo.
"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from music_lib import (BRASS, CELESTA, CELLO, CHOIR, CLARINET, CONTRABASS, FLUTE, GLOCKENSPIEL, HARP, HORN,  # noqa: E402
                       MUSIC_BOX, OBOE, OOHS, PAD_HALO, PAD_WARM, PIZZICATO, SLOW_STRINGS, STRINGS, TIMPANI,
                       TREMOLO, TRUMPET, TUBULAR_BELLS, VIOLIN, Song, chord, pitch, render_song, write_ogg)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "godot", "assets", "audio", "music")

# Voicings compartidos (cuerdas en posición cerrada, bajo aparte).
V = {
    "D": chord("D4", "F#4", "A4"), "Bm": chord("B3", "D4", "F#4"), "G": chord("G3", "B3", "D4"),
    "A": chord("A3", "C#4", "E4"), "Asus4": chord("A3", "D4", "E4"), "Em": chord("G3", "B3", "E4"),
    "F#m": chord("F#3", "A3", "C#4"), "A7": chord("G3", "C#4", "E4"), "Dsus2": chord("D4", "E4", "A4"),
    "Gm": chord("G3", "Bb3", "D4"), "C": chord("G3", "C4", "E4"), "D/F#": chord("F#3", "A3", "D4"),
    "Am7": chord("G3", "C4", "E4"), "Csus2": chord("G3", "C4", "D4"), "F#": chord("F#3", "A#3", "C#4"),
    "F#sus4": chord("F#3", "B3", "C#4"), "Bsus4": chord("B3", "E4", "F#4"),
    "Dm": chord("D4", "F4", "A4"), "Bb": chord("Bb3", "D4", "F4"), "F": chord("F3", "A3", "C4"),
}
ROOTS = {"D": "D", "Bm": "B", "G": "G", "A": "A", "Asus4": "A", "Em": "E", "F#m": "F#", "A7": "A", "Dsus2": "D",
         "Gm": "G", "C": "C", "D/F#": "F#", "Am7": "A", "Csus2": "C", "F#": "F#", "F#sus4": "F#", "Bsus4": "B",
         "Dm": "D", "Bb": "Bb", "F": "F"}


def bass_note(symbol: str, octave: int = 2) -> int:
    return pitch(ROOTS[symbol] + str(octave))


def arpeggio(song: Song, track: str, start: float, symbol: str, beats: float, step: float = 0.5,
             velocity: int = 56, pattern=(0, 1, 2, 3, 4, 3, 2, 1), base_octave: int = 3) -> None:
    tones = sorted(set(n % 12 for n in V[symbol]))
    root = pitch(ROOTS[symbol] + str(base_octave)) % 12
    ordered = sorted(tones, key=lambda t: (t - root) % 12)
    ladder = []
    base = pitch(ROOTS[symbol] + str(base_octave))
    for octave in range(3):
        for tone in ordered:
            value = base + ((tone - root) % 12) + 12 * octave
            ladder.append(value)
    count = int(beats / step)
    for i in range(count):
        index = pattern[i % len(pattern)]
        song.note(track, start + i * step, step * 1.8, ladder[min(index, len(ladder) - 1)], velocity)


def pads(song: Song, track: str, start: float, progression: list, beats_per_chord: float, velocity: int = 58,
         octave: int = 0) -> None:
    for i, symbol in enumerate(progression):
        notes = [n + 12 * octave for n in V[symbol]]
        song.chord(track, start + i * beats_per_chord, beats_per_chord * 0.98, notes, velocity)


def bassline(song: Song, track: str, start: float, progression: list, beats_per_chord: float, velocity: int = 64,
             octave: int = 2) -> None:
    for i, symbol in enumerate(progression):
        song.note(track, start + i * beats_per_chord, beats_per_chord * 0.97, bass_note(symbol, octave), velocity)


def timpani_roll(song: Song, track: str, start: float, beats: float, note: str, v0: int = 30, v1: int = 96) -> None:
    hits = int(beats * 4)
    for i in range(hits):
        song.note(track, start + i * 0.25, 0.3, note, int(v0 + (v1 - v0) * i / max(1, hits - 1)))


# --- Tema de Auralia ------------------------------------------------------------------------------
THEME_A = ("A4:1 D5:1 E5:1 F#5:1 | F#5:1.5 E5:0.5 D5:1 B4:1 | D5:1 G5:1.5 F#5:0.5 E5:1 | E5:3 A4:1 | "
           "A4:1 D5:1 E5:1 F#5:1 | A5:1.5 F#5:0.5 D5:1 E5:1 | G5:1 F#5:1 E5:1 B4:1 | C#5:2 E5:2")
THEME_B = ("D5:1 G5:1 B5:1.5 A5:0.5 | A5:2 G5:1 E5:1 | F#5:1.5 E5:0.5 C#5:1 A4:1 | D5:2 B4:1 D5:1 | "
           "G5:1 F#5:1 E5:1 D5:1 | E5:1 A5:2 G5:1 | F#5:3 E5:1 | D5:4")
COUNTER_B = "B4:2 D5:2 | C#5:2 E5:2 | C#5:2 A4:2 | F#4:2 B4:2 | B4:2 G4:2 | C#5:2 A4:2 | A4:4 | F#4:4"
PROG_A = ["D", "Bm", "G", "A", "D", "Bm", "Em", "A"]
PROG_B = ["G", "A", "F#m", "Bm", "G", "A7", "D", "D"]


def title() -> Song:
    song = Song(76, 4, seed=11)
    song.track("strings", SLOW_STRINGS, 92, 58, 30)
    song.track("violins", STRINGS, 110, 70, 30)
    song.track("cello", CELLO, 88, 44, 25)
    song.track("contrabass", CONTRABASS, 80, 64, 20)
    song.track("harp", HARP, 84, 78, 30)
    song.track("flute", FLUTE, 88, 60, 30)
    song.track("horn", HORN, 88, 50, 35)
    song.track("choir", CHOIR, 76, 64, 40)
    song.track("celesta", CELESTA, 72, 88, 40)
    song.track("timpani", TIMPANI, 84, 64, 25)
    intro = ["D", "Bm", "G", "Asus4"]
    outro = ["G", "A", "Bm", "Asus4"]
    progression = intro + PROG_A + PROG_B + outro
    song.loop_beats = len(progression) * 4
    pads(song, "strings", 0, progression, 4, 54)
    song.swell("strings", 0, 8, 70, 108)
    for i, symbol in enumerate(progression):
        song.note("cello", i * 4, 3.9, bass_note(symbol, 3), 60)
        song.note("contrabass", i * 4, 3.9, bass_note(symbol, 2), 52)
        arpeggio(song, "harp", i * 4, symbol if symbol != "Asus4" else "A", 4, 0.5, 50 if i < 4 else 44)
    for i in range(4):
        for beat in (0, 2):
            song.note("celesta", i * 4 + beat, 1.5, max(V[intro[i]]) + 24, 44)
    song.swell("strings", 12, 4, 108, 84)
    song.melody("flute", 16, THEME_A, 76)
    song.melody("violins", 48, THEME_B, 92)
    song.melody("flute", 48, THEME_B, 58)
    song.melody("horn", 48, COUNTER_B, 70, transpose=-12)
    pads(song, "choir", 48, PROG_B, 4, 40, octave=1)
    song.swell("choir", 48, 32, 60, 100)
    song.swell("violins", 48, 4, 80, 115)
    timpani_roll(song, "timpani", 46, 2, "A2", 20, 70)
    song.note("timpani", 48, 1, "D2", 76)
    song.melody("flute", 80, "D5:2 E5:2 | F#5:2 E5:2 | D5:2 B4:2 | A4:4", 70)
    return song


def exploration() -> Song:
    song = Song(92, 4, seed=23)
    song.track("pizz", PIZZICATO, 96, 50, 20)
    song.track("harp", HARP, 72, 80, 25)
    song.track("pad", SLOW_STRINGS, 66, 64, 30)
    song.track("flute", FLUTE, 100, 58, 28)
    song.track("clarinet", CLARINET, 92, 70, 28)
    song.track("strings", STRINGS, 88, 60, 30)
    song.track("glock", GLOCKENSPIEL, 54, 90, 30)
    song.track("bass", CONTRABASS, 78, 64, 15)
    song.track("perc", 0, 70, 64, 10, drums=True)
    a = ["G", "D/F#", "Em", "C", "G", "D", "C", "D"]
    b = ["Em", "C", "G", "D", "Em", "C", "Am7", "D"]
    c = ["C", "D", "Bm", "Em", "C", "D", "Csus2", "D"]
    progression = a + b + a + c
    song.loop_beats = len(progression) * 4
    pads(song, "pad", 0, progression, 4, 46)
    for i, symbol in enumerate(progression):
        bar = i * 4
        root = bass_note(symbol, 3)
        fifth = root + 7
        for beat, value in ((0, root), (1, fifth), (2, root + 12), (3, fifth)):
            song.note("pizz", bar + beat, 0.4, value, 70 if beat == 0 else 58)
        song.note("bass", bar, 1.8, bass_note(symbol, 2), 60)
        song.note("bass", bar + 2, 1.8, bass_note(symbol, 2) + 7, 52)
        arpeggio(song, "harp", bar, symbol, 4, 0.25, 36, pattern=(0, 2, 4, 5, 4, 2, 1, 3), base_octave=4)
        for beat, drum, velocity in ((0, 64, 44), (1.5, 63, 30), (2, 64, 38), (3, 63, 28), (3.5, 63, 24)):
            song.note("perc", bar + beat, 0.2, drum, velocity)
        for beat in (0.5, 1.5, 2.5, 3.5):
            song.note("perc", bar + beat, 0.1, 70, 22)
    melody_a = ("D5:1 G5:1 A5:1 B5:1 | A5:2 F#5:1 D5:1 | E5:1 G5:1 B5:1.5 A5:0.5 | G5:3 E5:1 | "
                "D5:1 G5:1 A5:1 B5:1 | D6:2 C6:0.5 B5:0.5 A5:1 | G5:1 E5:1 C5:1 E5:1 | F#5:3 r:1")
    melody_b = ("B4:1.5 A4:0.5 G4:1 E4:1 | G4:2 E4:1 C4:1 | D4:1 G4:1 B4:1 D5:1 | C5:1.5 B4:0.5 A4:2 | "
                "B4:1 E5:1 D5:1 B4:1 | C5:2 G4:2 | A4:1 C5:1 E5:1 G5:1 | F#5:4")
    melody_c = "E5:2 G5:2 | F#5:2 A5:2 | B5:3 A5:1 | G5:4 | E5:2 C5:2 | D5:2 F#5:2 | G5:4 | A5:2 F#5:1 D5:1"
    song.melody("flute", 0, melody_a, 84)
    song.melody("clarinet", 32, melody_b, 80)
    song.melody("flute", 64, melody_a, 80)
    song.melody("clarinet", 64, melody_a, 60, transpose=-12)
    song.melody("strings", 96, melody_c, 92)
    song.melody("flute", 112, "E6:2 C6:2 | D6:2 F#6:2 | G6:4 | A6:2 F#6:1 D6:1", 58)
    song.swell("strings", 96, 32, 96, 122)
    for bar in range(0, 32, 4):
        song.note("glock", bar * 4, 1.0, V[progression[bar]][-1] + 24, 40)
    return song


def garden() -> Song:
    song = Song(72, 3, seed=31)
    song.track("celesta", CELESTA, 104, 70, 45)
    song.track("musicbox", MUSIC_BOX, 76, 96, 50)
    song.track("halo", PAD_HALO, 92, 64, 50)
    song.track("warm", PAD_WARM, 76, 64, 45)
    song.track("harp", HARP, 84, 40, 40)
    song.track("flute", FLUTE, 70, 60, 40)
    song.track("oohs", OOHS, 50, 64, 50)
    song.track("strings", SLOW_STRINGS, 82, 50, 35)
    song.track("bells", TUBULAR_BELLS, 50, 80, 50)
    chords = {
        "Dmaj7": chord("D4", "F#4", "A4", "C#5"), "Bm7": chord("B3", "D4", "F#4", "A4"),
        "Gmaj7": chord("G3", "B3", "D4", "F#4"), "Em9": chord("E3", "G3", "B3", "F#4"),
        "A13sus": chord("A3", "D4", "E4", "F#4"), "F#m7": chord("F#3", "A3", "C#4", "E4"),
        "E/G#": chord("G#3", "B3", "E4", "G#4"), "D/A": chord("A3", "D4", "F#4", "A4"),
        "Em7": chord("E3", "G3", "B3", "D4"), "A7sus4": chord("A3", "D4", "E4", "G4"),
    }
    cycle1 = ["Dmaj7", "Dmaj7", "Bm7", "Bm7", "Gmaj7", "Gmaj7", "Em9", "A13sus"]
    cycle2 = ["Dmaj7", "F#m7", "Gmaj7", "E/G#", "D/A", "Bm7", "Em7", "A7sus4"]
    progression = cycle1 + cycle2 + cycle2 + cycle2
    song.loop_beats = len(progression) * 3
    motif = [pitch("A4"), pitch("D5"), pitch("F#5")]
    for i, symbol in enumerate(progression):
        bar = i * 3
        notes = chords[symbol]
        song.chord("halo", bar, 2.95, notes, 48)
        song.chord("warm", bar, 2.95, [n - 12 for n in notes[:2]], 42)
        song.note("strings", bar, 2.9, notes[0] - 12, 44)
        # Motivo de las runas: se adapta a cada acorde manteniendo el contorno ascendente.
        pitch_classes = sorted(set(n % 12 for n in notes))
        shaped = []
        for m in motif:
            options = [m + d for d in range(-2, 3) if (m + d) % 12 in pitch_classes]
            shaped.append(min(options, key=lambda v: abs(v - m)) if options else m)
        for beat, value in enumerate(shaped):
            song.note("celesta", bar + beat, 1.2, value, 58 if beat == 0 else 48)
        if i % 2 == 1:
            for beat, value in enumerate(reversed(shaped)):
                song.note("musicbox", bar + beat + 0.5, 0.8, value + 12, 34)
        if i % 4 == 0:
            for k in range(10):
                song.note("harp", bar + k * 0.12, 1.5, notes[k % len(notes)] + 12 * (k // len(notes)), 40 + k * 2)
        if i % 8 == 0:
            song.note("bells", bar, 3, notes[0] + 12, 38)
    flute_one = ("F#5:3 | E5:2 C#5:1 | D5:3 | B4:2 G#4:1 | A4:3 | D5:1.5 C#5:1.5 | B4:3 | A4:2 D5:1")
    flute_two = ("A5:3 | A5:1.5 E5:1.5 | F#5:3 | E5:2 B4:1 | C#5:1.5 D5:1.5 | F#5:3 | E5:2 D5:1 | D5:3")
    song.swell("flute", 48, 3, 60, 100)
    song.melody("flute", 48, flute_one, 70, legato=1.0)
    song.melody("flute", 72, flute_two, 74, legato=1.0)
    song.swell("flute", 93, 3, 100, 50)
    for i, symbol in enumerate(cycle2):
        song.chord("oohs", 72 + i * 3, 2.95, chords[symbol][1:], 40)
    song.swell("oohs", 72, 24, 50, 100)
    return song


def sanctuary() -> Song:
    song = Song(60, 4, seed=41)
    song.track("choir", CHOIR, 90, 64, 50)
    song.track("strings", SLOW_STRINGS, 84, 54, 40)
    song.track("contrabass", CONTRABASS, 80, 64, 30)
    song.track("bells", TUBULAR_BELLS, 62, 74, 55)
    song.track("oboe", OBOE, 92, 66, 45)
    song.track("harp", HARP, 66, 84, 40)
    song.track("halo", PAD_HALO, 54, 64, 50)
    song.track("timpani", TIMPANI, 70, 64, 35)
    progression = ["Bm", "G", "D", "A", "Bm", "Em", "F#sus4", "F#", "G", "D/F#", "Em", "Bm", "G", "A", "Bsus4",
                   "Bm", "Bm", "G", "Em", "F#sus4"]
    song.loop_beats = len(progression) * 4
    pads(song, "strings", 0, progression, 4, 50)
    pads(song, "choir", 16, progression[4:], 4, 46, octave=1)
    song.swell("choir", 16, 32, 50, 104)
    pads(song, "halo", 0, progression, 4, 34)
    for i, symbol in enumerate(progression):
        song.note("contrabass", i * 4, 3.95, bass_note(symbol, 2), 56)
        if i % 4 == 0:
            song.note("bells", i * 4, 4, "B3" if i % 8 == 0 else "F#3", 58)
        if i % 2 == 1:
            arpeggio(song, "harp", i * 4, symbol, 4, 0.5, 34, pattern=(0, 2, 4, 2, 1, 3, 5, 3))
    lament = ("F#4:1 B4:1 C#5:1 D5:1 | D5:1.5 C#5:0.5 B4:1 G4:1 | B4:1 E5:1.5 D5:0.5 C#5:1 | C#5:4 | "
              "D5:1 G5:1 F#5:1 D5:1 | E5:2 B4:2 | C#5:2 E5:1 D5:1 | B4:4")
    song.melody("oboe", 16, lament, 80, legato=1.0)
    song.melody("oboe", 48, "D5:2 C#5:2 | B4:4 | G4:2 A4:2 | F#4:4", 70, legato=1.0)
    timpani_roll(song, "timpani", 58, 2, "F#2", 16, 58)
    song.note("timpani", 60, 1, "B1", 60)
    return song


def combat() -> Song:
    song = Song(126, 4, seed=53)
    song.track("ostinato", STRINGS, 100, 44, 18)
    song.track("contrabass", CONTRABASS, 96, 64, 15)
    song.track("tremolo", TREMOLO, 70, 86, 25)
    song.track("brass", BRASS, 92, 58, 25)
    song.track("horn", HORN, 96, 48, 28)
    song.track("trumpet", TRUMPET, 84, 76, 28)
    song.track("timpani", TIMPANI, 104, 64, 20)
    song.track("drums", 0, 100, 64, 12, drums=True)
    progression = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A", "Dm", "F", "Bb", "C", "Gm", "Bb", "A", "A"]
    progression = progression + progression
    song.loop_beats = len(progression) * 4
    for i, symbol in enumerate(progression):
        bar = i * 4
        root = bass_note(symbol, 2) + 12
        figure = [0, 0, 7, 0, 12, 0, 7, 3 if symbol in ("Dm", "Gm") else 4]
        for k, interval in enumerate(figure):
            song.note("ostinato", bar + k * 0.5, 0.42, root + interval, 88 if k % 4 == 0 else 66)
        song.note("contrabass", bar, 1.9, bass_note(symbol, 1) + 12, 84)
        song.note("contrabass", bar + 2, 1.9, bass_note(symbol, 1) + 12, 74)
        song.note("timpani", bar, 0.5, bass_note(symbol, 2), 96)
        song.note("timpani", bar + 2, 0.5, bass_note(symbol, 2), 80)
        for beat, drum, velocity in ((0, 36, 96), (1.5, 41, 70), (2, 36, 84), (3, 43, 64), (3.5, 41, 74)):
            song.note("drums", bar + beat, 0.2, drum, velocity)
        if i % 2 == 0:
            song.chord("brass", bar, 0.6, [n for n in V[symbol]], 92)
        if i >= 16:
            song.chord("tremolo", bar, 3.95, [V[symbol][-1] + 12, V[symbol][-1] + 24], 54)
    for bar in (0, 32, 64, 96):
        song.note("drums", bar, 1, 49, 82)
    heroic = "D4:2 F4:1 A4:1 | G4:3 F4:1 | E4:2 G4:2 | A4:4"
    call = "A4:2 D5:1 F5:1 | E5:3 D5:1 | C#5:4 | A4:4"
    for start in (16, 80):
        song.melody("horn", start, heroic, 94)
    for start in (48, 112):
        song.melody("trumpet", start, call, 96)
        song.melody("horn", start, call, 80, transpose=-12)
    for start in (28, 60, 92, 124):
        timpani_roll(song, "timpani", start, 4, "A2", 40, 110)
    return song


def finale() -> Song:
    song = Song(72, 4, seed=67)
    song.track("strings", SLOW_STRINGS, 96, 56, 30)
    song.track("violins", STRINGS, 100, 70, 28)
    song.track("cello", CELLO, 92, 42, 25)
    song.track("contrabass", CONTRABASS, 86, 64, 20)
    song.track("harp", HARP, 84, 82, 30)
    song.track("celesta", CELESTA, 84, 90, 40)
    song.track("flute", FLUTE, 100, 62, 30)
    song.track("horn", HORN, 94, 46, 32)
    song.track("brass", BRASS, 80, 58, 30)
    song.track("choir", CHOIR, 84, 64, 40)
    song.track("timpani", TIMPANI, 96, 64, 22)
    song.track("bells", TUBULAR_BELLS, 70, 76, 50)
    song.track("drums", 0, 80, 64, 20, drums=True)
    intro = ["Dsus2", "Bm", "G", "A"]
    build = ["G", "A", "Bm", "A"]
    coda = ["G", "Gm", "D", "D"]
    sections = intro + PROG_A + build + PROG_A + PROG_B + coda
    for i, symbol in enumerate(sections):
        bar = i * 4
        song.note("contrabass", bar, 3.9, bass_note(symbol, 2), 50 if i < 12 else 72)
        song.note("cello", bar, 3.9, bass_note(symbol, 3), 50 if i < 12 else 76)
    # 1) Recuerdo: celesta y arpa con el tema, cuerdas suaves.
    pads(song, "strings", 0, intro + PROG_A, 4, 44)
    for i, symbol in enumerate(intro + PROG_A):
        arpeggio(song, "harp", i * 4, symbol, 4, 0.5, 40)
    song.melody("celesta", 16, THEME_A, 70)
    for rune_beat, rune in enumerate(("A4", "D5", "F#5", "A5")):
        song.note("celesta", 4 + rune_beat * 0.75, 2.5, pitch(rune) + 12, 52)
    # 2) Crescendo: timbal, trompas y cuerdas que despiertan.
    pads(song, "strings", 48, build, 4, 66)
    song.swell("strings", 48, 16, 60, 120)
    song.melody("horn", 48, "D4:2 E4:2 | E4:2 C#4:2 | D4:2 F#4:2 | E4:4", 80)
    timpani_roll(song, "timpani", 56, 8, "A2", 24, 110)
    song.tempo(64, 76)
    # 3) Tutti: tema A en violines y flauta, metales y coro.
    song.note("drums", 64, 2, 49, 96)
    song.note("timpani", 64, 1, "D2", 116)
    song.melody("violins", 64, THEME_A, 100, transpose=12)
    song.melody("flute", 64, THEME_A, 92, transpose=12)
    song.melody("horn", 64, "F#4:4 | D4:4 | B3:4 | C#4:4 | F#4:4 | D4:4 | E4:4 | E4:4", 82)
    pads(song, "brass", 64, PROG_A, 4, 64)
    pads(song, "choir", 64, PROG_A, 4, 70, octave=1)
    pads(song, "strings", 64, PROG_A + PROG_B, 4, 74)
    for i, symbol in enumerate(PROG_A + PROG_B):
        arpeggio(song, "harp", 64 + i * 4, symbol, 4, 0.5, 52, base_octave=3)
        song.note("timpani", 64 + i * 4, 0.6, bass_note(symbol, 2), 84 if i % 4 == 0 else 64)
    # 4) Tema B: el clímax.
    song.note("drums", 96, 2, 57, 90)
    song.melody("violins", 96, THEME_B, 104, transpose=12)
    song.melody("flute", 96, THEME_B, 90)
    song.melody("horn", 96, COUNTER_B, 86)
    pads(song, "choir", 96, PROG_B, 4, 82, octave=1)
    pads(song, "brass", 96, PROG_B, 4, 74)
    song.swell("choir", 96, 32, 90, 124)
    # 5) Coda: plagal menor (Sol m -> Re) con campanas, acorde final largo.
    song.tempo(128, 66)
    pads(song, "strings", 128, coda, 4, 70)
    pads(song, "choir", 128, coda, 4, 72, octave=1)
    song.chord("brass", 128, 7.8, V["G"], 60)
    song.chord("brass", 136, 7.8, V["D"], 58)
    song.melody("flute", 128, "D6:4 | D6:2 C6:2 | A5:8", 70)
    for k, rune in enumerate(("A4", "D5", "F#5", "A5", "D6")):
        song.note("celesta", 136 + k * 0.5, 6, pitch(rune) + 12, 58)
        song.note("bells", 136 + k * 0.5, 6, pitch(rune), 44 + k * 4)
    song.chord("strings", 136, 12, chord("D3", "A3", "D4", "F#4", "A4", "D5"), 76)
    song.chord("choir", 136, 12, chord("D4", "F#4", "A4", "D5"), 60)
    song.swell("strings", 136, 12, 120, 40)
    song.swell("choir", 136, 12, 110, 30)
    song.note("timpani", 136, 1, "D2", 100)
    return song


BUILDERS = {"title": (title, True), "exploration": (exploration, True), "garden": (garden, True),
            "sanctuary": (sanctuary, True), "combat": (combat, True), "finale": (finale, False)}


def main(names: list[str]) -> None:
    metrics = {}
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        for name in names or list(BUILDERS):
            builder, loop = BUILDERS[name]
            song = builder()
            audio, seconds = render_song(song, loop, work, name, lufs=-27.0 if name != "combat" else -26.0,
                                         wet=0.3 if name in ("garden", "sanctuary") else 0.24)
            path = os.path.join(OUT, name + ".ogg")
            write_ogg(audio, path)
            metrics[name] = {"seconds": round(len(audio) / 44100, 2), "loop": loop, "loop_seconds": round(seconds, 3)}
            print("MUSIC", name, metrics[name])
    target = os.path.join(ROOT, "blender", "music_metrics.json")
    existing = json.load(open(target)) if os.path.exists(target) else {}
    existing.update(metrics)
    with open(target, "w", encoding="utf-8") as handle:
        json.dump(existing, handle, indent=2)


if __name__ == "__main__":
    main(sys.argv[1:])
