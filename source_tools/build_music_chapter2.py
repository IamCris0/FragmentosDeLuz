"""Banda sonora del Capítulo II · La Señal Imposible (fase 7).

Uso:  python source_tools/build_music_chapter2.py            (todas las pistas)
      python source_tools/build_music_chapter2.py grutas boss

Pistas en godot/assets/audio/music/*.ogg (mismo proceso que build_music.py: MIDI + FluidSynth + Pedalboard):
  map            Carta del Archipiélago. El tema de Auralia en caja de música y arpa (84 bpm), bucle.
  grutas         Grutas Prismáticas. Mi dórico, celesta y arpa en ostinato, flauta con el motivo de la señal.
  grutas_deep    Corazón Prismático. El mismo motivo en registro grave, coro y latido de timbal (60 bpm).
  cefiro         Picos del Céfiro. La mayor, pizzicato, flautín y cuerdas que ascienden por cuartas (104 bpm).
  cefiro_summit  Cumbre. Re mayor amplio con trompas y cuerdas (92 bpm).
  observatorio   Observatorio Estelar. Fa# menor con coro, celesta estelar y el tema de Auralia en menor (66 bpm).
  boss           Heraldo del Eclipse. Do menor, ostinato de cuerdas, metales y tambores (138 bpm).
  finale2        Final del Capítulo II y créditos. Tema de Maren y tema de Auralia combinados (sin bucle).

Leitmotiv del capítulo: «la señal» (Mi5-Si5-La5-Mi5), una quinta que sube y un paso que cae, como un
pulso que se repite. Aparece en todas las pistas del archipiélago y resuelve en el final.
"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from build_music import THEME_A, THEME_B, V, arpeggio, bass_note, bassline, pads, timpani_roll  # noqa: E402
from music_lib import (BRASS, CELESTA, CELLO, CHOIR, CLARINET, CONTRABASS, FLUTE, GLOCKENSPIEL, HARP, HORN,  # noqa: E402
                       MUSIC_BOX, OBOE, OOHS, PAD_HALO, PAD_NEW_AGE, PAD_WARM, PICCOLO, PIZZICATO, SLOW_STRINGS,
                       STRINGS, TIMPANI, TREMOLO, TRUMPET, TUBULAR_BELLS, VIOLIN, Song, chord, pitch, render_song,
                       write_ogg)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "godot", "assets", "audio", "music")

SIGNAL = "E5:0.5 B5:0.5 A5:1 E5:2"

C2 = {
    "Em9": chord("E3", "G3", "B3", "F#4"), "A6": chord("A3", "C#4", "F#4"), "Cmaj7": chord("C4", "E4", "G4", "B4"),
    "D6": chord("D4", "F#4", "B4"), "Bm7": chord("B3", "D4", "F#4", "A4"), "Gmaj9": chord("G3", "B3", "F#4", "A4"),
    "Esus": chord("E3", "A3", "B3"), "F#m": chord("F#3", "A3", "C#4"), "F#m7": chord("F#3", "A3", "C#4", "E4"),
    "Dmaj7": chord("D4", "F#4", "A4", "C#5"), "E": chord("E3", "G#3", "B3"), "C#m": chord("C#4", "E4", "G#4"),
    "A": chord("A3", "C#4", "E4"), "D": chord("D4", "F#4", "A4"), "E7": chord("E3", "G#3", "D4"),
    "Bm": chord("B3", "D4", "F#4"), "G": chord("G3", "B3", "D4"), "Cm": chord("C4", "Eb4", "G4"),
    "Ab": chord("Ab3", "C4", "Eb4"), "Bb": chord("Bb3", "D4", "F4"), "Fm": chord("F3", "Ab3", "C4"),
    "G7": chord("G3", "B3", "F4"), "Eb": chord("Eb3", "G3", "Bb3"), "C#m7": chord("C#4", "E4", "G#4", "B4"),
    "Aadd9": chord("A3", "C#4", "E4", "B4"), "Dsus2": chord("D4", "E4", "A4"), "Asus4": chord("A3", "D4", "E4"),
}
ROOT_OF = {"Em9": "E", "A6": "A", "Cmaj7": "C", "D6": "D", "Bm7": "B", "Gmaj9": "G", "Esus": "E", "F#m": "F#",
           "F#m7": "F#", "Dmaj7": "D", "E": "E", "C#m": "C#", "A": "A", "D": "D", "E7": "E", "Bm": "B", "G": "G",
           "Cm": "C", "Ab": "Ab", "Bb": "Bb", "Fm": "F", "G7": "G", "Eb": "Eb", "C#m7": "C#", "Aadd9": "A",
           "Dsus2": "D", "Asus4": "A"}


def root(symbol: str, octave: int) -> int:
    return pitch(ROOT_OF[symbol] + str(octave))


def pad2(song: Song, track: str, start: float, progression: list, beats: float, velocity: int, octave: int = 0) -> None:
    for i, symbol in enumerate(progression):
        song.chord(track, start + i * beats, beats * 0.98, [n + 12 * octave for n in C2[symbol]], velocity)


def broken(song: Song, track: str, start: float, symbol: str, beats: float, step: float, velocity: int,
           octave: int = 1, pattern=(0, 1, 2, 3, 2, 1)) -> None:
    notes = sorted(n + 12 * octave for n in C2[symbol])
    ladder = notes + [n + 12 for n in notes]
    for i in range(int(beats / step)):
        song.note(track, start + i * step, step * 1.6, ladder[pattern[i % len(pattern)] % len(ladder)], velocity)


def map_theme() -> Song:
    song = Song(84, 4, seed=101)
    song.track("musicbox", MUSIC_BOX, 88, 70, 45)
    song.track("harp", HARP, 90, 56, 35)
    song.track("strings", SLOW_STRINGS, 78, 64, 35)
    song.track("cello", CELLO, 70, 48, 30)
    song.track("flute", FLUTE, 70, 76, 40)
    song.track("halo", PAD_HALO, 52, 64, 50)
    progression = ["D", "Bm", "G", "A", "D", "Bm", "Em", "A", "G", "A", "F#m", "Bm", "G", "A", "D", "D"]
    song.loop_beats = len(progression) * 4
    pads(song, "strings", 0, progression, 4, 44)
    pads(song, "halo", 0, progression, 4, 30)
    for i, symbol in enumerate(progression):
        song.note("cello", i * 4, 3.9, bass_note(symbol, 3), 52)
        arpeggio(song, "harp", i * 4, symbol, 4, 0.5, 40, pattern=(0, 2, 4, 2, 5, 4, 2, 1))
    song.melody("musicbox", 0, THEME_A, 64, transpose=12)
    song.melody("flute", 32, THEME_B, 62)
    for k, start in enumerate((28, 60)):
        song.melody("musicbox", start, SIGNAL, 50, transpose=0 if k == 0 else 12)
    return song


def grutas() -> Song:
    song = Song(80, 4, seed=111)
    song.track("celesta", CELESTA, 96, 76, 45)
    song.track("harp", HARP, 86, 48, 40)
    song.track("halo", PAD_HALO, 80, 64, 55)
    song.track("strings", SLOW_STRINGS, 70, 64, 40)
    song.track("contrabass", CONTRABASS, 70, 64, 30)
    song.track("flute", FLUTE, 80, 70, 45)
    song.track("glock", GLOCKENSPIEL, 50, 90, 50)
    song.track("oohs", OOHS, 44, 60, 55)
    progression = ["Em9", "Em9", "A6", "A6", "Cmaj7", "D6", "Em9", "Esus",
                   "Em9", "Bm7", "Cmaj7", "Gmaj9", "A6", "Cmaj7", "D6", "Esus"]
    song.loop_beats = len(progression) * 4
    pad2(song, "halo", 0, progression, 4, 46)
    pad2(song, "strings", 32, progression[8:], 4, 40)
    for i, symbol in enumerate(progression):
        bar = i * 4
        song.note("contrabass", bar, 3.9, root(symbol, 2), 48)
        broken(song, "celesta", bar, symbol, 4, 1.0 / 3.0, 40, octave=1, pattern=(0, 2, 3, 5, 3, 2))
        if i % 2 == 0:
            broken(song, "harp", bar + 2, symbol, 2, 0.25, 34, octave=0, pattern=(0, 1, 2, 3, 4, 5, 6, 7))
        if i % 4 == 2:
            song.note("glock", bar + 1.5, 1.5, max(C2[symbol]) + 24, 36)
    song.melody("flute", 8, SIGNAL + " | B4:1 D5:1 E5:2 | " + SIGNAL + " | G5:2 F#5:1 D5:1 | E5:4", 70, legato=1.0)
    song.melody("flute", 40, "B5:2 A5:1 G5:1 | F#5:3 D5:1 | E5:2 B4:1 D5:1 | E5:4 | G5:1 A5:1 B5:2 | D6:2 B5:2 | A5:3 F#5:1 | E5:4", 66, legato=1.0)
    pad2(song, "oohs", 40, progression[10:14], 4, 36, octave=1)
    return song


def grutas_deep() -> Song:
    song = Song(60, 4, seed=121)
    song.track("oohs", OOHS, 88, 64, 55)
    song.track("halo", PAD_HALO, 80, 64, 55)
    song.track("cello", CELLO, 86, 50, 35)
    song.track("contrabass", CONTRABASS, 80, 64, 30)
    song.track("bells", TUBULAR_BELLS, 56, 76, 55)
    song.track("celesta", CELESTA, 70, 84, 50)
    song.track("timpani", TIMPANI, 70, 64, 30)
    progression = ["Em9", "Cmaj7", "A6", "Bm7", "Em9", "Cmaj7", "D6", "Esus", "Cmaj7", "D6", "Bm7", "Esus"]
    song.loop_beats = len(progression) * 4
    pad2(song, "halo", 0, progression, 4, 44)
    pad2(song, "oohs", 16, progression[4:], 4, 40)
    song.swell("oohs", 16, 16, 50, 100)
    for i, symbol in enumerate(progression):
        bar = i * 4
        song.note("contrabass", bar, 3.9, root(symbol, 1) + 12, 52)
        # Latido del corazón prismático.
        song.note("timpani", bar, 0.4, root(symbol, 2), 58)
        song.note("timpani", bar + 0.5, 0.4, root(symbol, 2), 40)
        if i % 4 == 0: song.note("bells", bar, 4, root(symbol, 4), 52)
        broken(song, "celesta", bar + 2, symbol, 2, 0.5, 30, octave=2, pattern=(3, 2, 1, 0))
    song.melody("cello", 16, "E3:0.5 B3:0.5 A3:1 E3:2 | G3:2 F#3:1 D3:1 | E3:4 | r:4 | B3:2 A3:1 G3:1 | F#3:3 D3:1 | E3:4 | r:4", 72, legato=1.0)
    return song


def cefiro() -> Song:
    song = Song(104, 4, seed=131)
    song.track("pizz", PIZZICATO, 92, 54, 20)
    song.track("strings", STRINGS, 84, 64, 28)
    song.track("piccolo", PICCOLO, 70, 72, 30)
    song.track("flute", FLUTE, 92, 60, 30)
    song.track("clarinet", CLARINET, 80, 44, 28)
    song.track("harp", HARP, 70, 84, 28)
    song.track("horn", HORN, 76, 52, 30)
    song.track("bass", CONTRABASS, 80, 64, 15)
    song.track("perc", 0, 66, 64, 12, drums=True)
    a = ["A", "E", "F#m", "D", "A", "E", "D", "E"]
    b = ["D", "A", "Bm", "E", "C#m", "F#m", "D", "E7"]
    progression = a + b + a + ["D", "E", "C#m", "F#m", "Bm", "E", "Aadd9", "Aadd9"]
    song.loop_beats = len(progression) * 4
    for i, symbol in enumerate(progression):
        bar = i * 4
        low = root(symbol, 3)
        for beat, value in ((0, low), (1, low + 7), (2, low + 12), (3, low + 7)):
            song.note("pizz", bar + beat, 0.35, value, 70 if beat == 0 else 54)
        song.note("bass", bar, 1.9, root(symbol, 2), 60)
        song.note("bass", bar + 2, 1.9, root(symbol, 2) + 7, 50)
        broken(song, "harp", bar, symbol, 4, 0.25, 32, octave=1, pattern=(0, 1, 2, 3, 4, 3, 2, 1))
        for beat, drum, velocity in ((0, 36, 40), (1, 42, 26), (2, 38, 30), (3, 42, 24), (3.5, 42, 20)):
            song.note("perc", bar + beat, 0.15, drum, velocity)
        if i % 2 == 0: song.note("perc", bar + 0.5, 0.2, 81, 26)
    pad2(song, "strings", 0, progression, 4, 40)
    # El viento sube por cuartas: motivo de la señal transportado a La.
    wind = "A5:0.5 E6:0.5 D6:1 A5:2 | B5:1 C#6:1 E6:2 | F#6:1.5 E6:0.5 C#6:1 B5:1 | A5:4"
    song.melody("flute", 0, wind + " | " + wind, 82)
    song.melody("piccolo", 32, "E6:1 F#6:1 A6:2 | G#6:2 E6:2 | F#6:1 E6:1 C#6:1 B5:1 | C#6:4 | A6:2 G#6:1 F#6:1 | E6:3 C#6:1 | D6:2 F#6:2 | E6:4", 70)
    song.melody("clarinet", 32, "C#5:4 | B4:4 | A4:4 | G#4:4 | E4:4 | A4:4 | F#4:4 | G#4:4", 60)
    song.melody("horn", 64, "A3:2 C#4:2 | E4:4 | D4:2 F#4:2 | E4:4 | A3:2 C#4:2 | E4:4 | D4:2 C#4:2 | B3:4", 70)
    song.melody("flute", 96, "F#5:2 A5:2 | B5:2 G#5:2 | A5:1 C#6:1 E6:2 | F#6:4 | D6:2 B5:2 | E6:2 G#5:2 | A5:4 | A5:4", 80)
    song.swell("strings", 96, 32, 80, 115)
    return song


def cefiro_summit() -> Song:
    song = Song(92, 4, seed=141)
    song.track("strings", STRINGS, 96, 64, 30)
    song.track("slow", SLOW_STRINGS, 80, 64, 35)
    song.track("horn", HORN, 92, 52, 32)
    song.track("trumpet", TRUMPET, 70, 76, 32)
    song.track("harp", HARP, 80, 80, 30)
    song.track("cello", CELLO, 86, 48, 28)
    song.track("timpani", TIMPANI, 80, 64, 25)
    song.track("choir", CHOIR, 70, 64, 40)
    progression = ["D", "A", "Bm", "G", "D", "A", "G", "A", "Bm", "G", "D", "A", "G", "A", "D", "D"]
    song.loop_beats = len(progression) * 4
    pads(song, "slow", 0, progression, 4, 50)
    pads(song, "choir", 32, progression[8:], 4, 44, octave=1)
    for i, symbol in enumerate(progression):
        bar = i * 4
        song.note("cello", bar, 3.9, bass_note(symbol, 2), 62)
        arpeggio(song, "harp", bar, symbol, 4, 0.5, 42)
        song.note("timpani", bar, 0.5, bass_note(symbol, 2), 60 if i % 4 else 80)
    song.melody("horn", 0, "D4:0.5 A4:0.5 G4:1 D4:2 | E4:2 F#4:2 | D4:3 B3:1 | A3:4 | D4:1 E4:1 F#4:2 | A4:2 G4:1 F#4:1 | E4:2 G4:2 | F#4:2 E4:2", 84)
    song.melody("strings", 32, "F#5:2 A5:2 | D6:3 C#6:1 | B5:2 A5:1 G5:1 | A5:4 | B5:2 D6:2 | A5:2 F#5:2 | G5:1 A5:1 B5:1 C#6:1 | D6:4", 92)
    song.melody("trumpet", 48, "A4:0.5 E5:0.5 D5:1 A4:2 | D5:4", 70)
    song.swell("strings", 32, 32, 90, 118)
    return song


def observatorio() -> Song:
    song = Song(66, 4, seed=151)
    song.track("choir", CHOIR, 84, 64, 55)
    song.track("halo", PAD_HALO, 80, 64, 55)
    song.track("newage", PAD_NEW_AGE, 60, 64, 55)
    song.track("celesta", CELESTA, 90, 80, 50)
    song.track("glock", GLOCKENSPIEL, 56, 44, 55)
    song.track("strings", SLOW_STRINGS, 80, 64, 45)
    song.track("contrabass", CONTRABASS, 70, 64, 35)
    song.track("oboe", OBOE, 86, 60, 45)
    song.track("harp", HARP, 70, 50, 40)
    progression = ["F#m7", "Dmaj7", "Bm7", "C#m7", "F#m7", "Dmaj7", "Asus4", "E",
                   "Dmaj7", "E", "C#m7", "F#m7", "Bm7", "Dmaj7", "E", "E"]
    song.loop_beats = len(progression) * 4
    pad2(song, "halo", 0, progression, 4, 42)
    pad2(song, "newage", 0, progression, 4, 28)
    pad2(song, "choir", 32, progression[8:], 4, 42)
    song.swell("choir", 32, 32, 50, 104)
    for i, symbol in enumerate(progression):
        bar = i * 4
        song.note("contrabass", bar, 3.9, root(symbol, 2), 50)
        broken(song, "celesta", bar, symbol, 4, 0.5, 34, octave=1, pattern=(0, 2, 4, 3, 5, 3, 2, 1))
        if i % 2 == 1: song.note("glock", bar + 3, 1.0, max(C2[symbol]) + 24, 34)
        if i % 4 == 0: broken(song, "harp", bar, symbol, 4, 0.25, 30, octave=0, pattern=(0, 1, 2, 3, 4, 5, 6, 7))
    # El tema de Auralia en menor, como un recuerdo de Maren.
    maren = "C#5:1 F#5:1 G#5:1 A5:1 | A5:1.5 G#5:0.5 F#5:1 D5:1 | F#5:1 B5:1.5 A5:0.5 G#5:1 | G#5:3 C#5:1"
    song.melody("oboe", 16, maren, 74, legato=1.0)
    song.melody("strings", 48, "F#5:0.5 C#6:0.5 B5:1 F#5:2 | A5:2 G#5:2 | F#5:4 | E5:4", 70, legato=1.0)
    return song


def boss() -> Song:
    song = Song(138, 4, seed=161)
    song.track("ostinato", STRINGS, 100, 44, 16)
    song.track("tremolo", TREMOLO, 80, 84, 22)
    song.track("contrabass", CONTRABASS, 96, 64, 14)
    song.track("brass", BRASS, 96, 58, 24)
    song.track("horn", HORN, 96, 48, 26)
    song.track("trumpet", TRUMPET, 86, 76, 26)
    song.track("choir", CHOIR, 90, 64, 35)
    song.track("timpani", TIMPANI, 108, 64, 18)
    song.track("drums", 0, 104, 64, 10, drums=True)
    song.track("glock", GLOCKENSPIEL, 60, 64, 35)
    loop = ["Cm", "Cm", "Ab", "Bb", "Cm", "Cm", "Fm", "G7", "Ab", "Eb", "Fm", "G7", "Cm", "Ab", "G7", "G7"]
    progression = loop + loop
    song.loop_beats = len(progression) * 4
    for i, symbol in enumerate(progression):
        bar = i * 4
        base = root(symbol, 2) + 12
        figure = [0, 12, 7, 0, 3 if symbol in ("Cm", "Fm") else 4, 12, 7, 10]
        for k, interval in enumerate(figure):
            song.note("ostinato", bar + k * 0.5, 0.42, base + interval, 90 if k % 3 == 0 else 64)
        song.note("contrabass", bar, 0.9, root(symbol, 1) + 12, 88)
        song.note("contrabass", bar + 1.5, 0.9, root(symbol, 1) + 12, 76)
        song.note("contrabass", bar + 3, 0.9, root(symbol, 1) + 12, 80)
        song.note("timpani", bar, 0.4, root(symbol, 2), 100)
        song.note("timpani", bar + 1.5, 0.4, root(symbol, 2), 76)
        for beat, drum, velocity in ((0, 36, 100), (0.75, 45, 60), (1.5, 36, 84), (2, 38, 90), (3, 47, 70), (3.5, 50, 76)):
            song.note("drums", bar + beat, 0.2, drum, velocity)
        if i % 2 == 0: song.chord("brass", bar, 0.5, C2[symbol], 94)
        if i >= 16: song.chord("tremolo", bar, 3.95, [max(C2[symbol]) + 12, max(C2[symbol]) + 24], 56)
    pad2(song, "choir", 16, loop, 4, 64, octave=1)
    song.swell("choir", 16, 64, 70, 120)
    eclipse = "C5:2 Eb5:1 G5:1 | Ab5:3 G5:1 | F5:2 D5:2 | G5:4"
    song.melody("horn", 0, eclipse, 92, transpose=-12)
    song.melody("trumpet", 32, "G4:0.5 D5:0.5 C5:1 G4:2 | Ab4:2 Bb4:2 | C5:3 Eb5:1 | D5:4", 96)
    song.melody("horn", 64, eclipse + " | " + eclipse, 96)
    song.melody("trumpet", 96, "C5:2 G5:2 | Ab5:2 Eb5:2 | F5:1 G5:1 Ab5:1 B5:1 | C6:4", 100)
    # Destellos de la señal en el glockenspiel, como esperanza dentro del combate.
    for start in (28, 60, 92, 124):
        song.melody("glock", start, "E6:0.5 B6:0.5 A6:1 E6:2", 50, transpose=-4)
        timpani_roll(song, "timpani", start, 4, "G2", 40, 112)
    for bar in (0, 64):
        song.note("drums", bar * 4 // 4, 1, 49, 90)
    return song


def finale2() -> Song:
    song = Song(70, 4, seed=171)
    song.track("strings", SLOW_STRINGS, 96, 56, 30)
    song.track("violins", STRINGS, 100, 70, 28)
    song.track("cello", CELLO, 92, 42, 25)
    song.track("contrabass", CONTRABASS, 86, 64, 20)
    song.track("harp", HARP, 84, 82, 30)
    song.track("celesta", CELESTA, 84, 90, 40)
    song.track("oboe", OBOE, 90, 66, 40)
    song.track("flute", FLUTE, 96, 62, 30)
    song.track("horn", HORN, 94, 46, 32)
    song.track("brass", BRASS, 80, 58, 30)
    song.track("choir", CHOIR, 86, 64, 40)
    song.track("timpani", TIMPANI, 96, 64, 22)
    song.track("bells", TUBULAR_BELLS, 70, 76, 50)
    song.track("drums", 0, 80, 64, 20, drums=True)
    # 1) Maren: el tema en menor, oboe sobre coro suave.
    intro = ["F#m7", "Dmaj7", "Bm7", "C#m7", "F#m7", "Dmaj7", "Asus4", "E"]
    pad2(song, "strings", 0, intro, 4, 42)
    pad2(song, "choir", 8, intro[2:], 4, 36)
    for i, symbol in enumerate(intro):
        song.note("contrabass", i * 4, 3.9, root(symbol, 2), 48)
        broken(song, "harp", i * 4, symbol, 4, 0.5, 34, octave=1)
    song.melody("oboe", 0, "C#5:1 F#5:1 G#5:1 A5:1 | A5:1.5 G#5:0.5 F#5:1 D5:1 | F#5:1 B5:1.5 A5:0.5 G#5:1 | G#5:3 C#5:1 | "
                "D5:1 F#5:1 A5:1 C#6:1 | B5:2 A5:2 | G#5:1 F#5:1 E5:1 D5:1 | E5:4", 74, legato=1.0)
    # 2) La señal responde: modulación a Re mayor, celesta y flauta.
    signal = ["D", "Bm", "G", "A", "D", "Bm", "G", "A"]
    pads(song, "strings", 32, signal, 4, 56)
    for i, symbol in enumerate(signal):
        song.note("cello", 32 + i * 4, 3.9, bass_note(symbol, 3), 58)
        arpeggio(song, "harp", 32 + i * 4, symbol, 4, 0.5, 42)
    for k in range(4):
        song.melody("celesta", 32 + k * 8, "D6:0.5 A6:0.5 G6:1 D6:2 | r:4", 60 + k * 5)
    song.melody("flute", 40, "F#5:1 A5:1 B5:2 | A5:4 | D5:1 F#5:1 G5:2 | E5:4", 72)
    timpani_roll(song, "timpani", 60, 4, "A2", 24, 110)
    song.tempo(62, 76)
    # 3) Tutti: el tema de Auralia con el motivo de la señal en los metales.
    song.note("drums", 64, 2, 49, 96)
    song.note("timpani", 64, 1, "D2", 116)
    tutti = ["D", "Bm", "G", "A", "D", "Bm", "Em", "A", "G", "A", "F#m", "Bm", "G", "A", "D", "D"]
    song.melody("violins", 64, THEME_A, 100, transpose=12)
    song.melody("flute", 64, THEME_A, 90, transpose=12)
    song.melody("violins", 96, THEME_B, 104, transpose=12)
    song.melody("horn", 64, "D4:0.5 A4:0.5 G4:1 D4:2 | r:4 | D4:0.5 A4:0.5 G4:1 D4:2 | r:4", 84)
    song.melody("horn", 96, "D4:0.5 A4:0.5 G4:1 D4:2 | E4:4 | F#4:4 | E4:4", 88)
    pads(song, "brass", 64, tutti, 4, 64)
    pads(song, "choir", 64, tutti, 4, 72, octave=1)
    pads(song, "strings", 64, tutti, 4, 74)
    song.swell("choir", 96, 32, 90, 124)
    for i, symbol in enumerate(tutti):
        arpeggio(song, "harp", 64 + i * 4, symbol, 4, 0.5, 52)
        song.note("contrabass", 64 + i * 4, 3.9, bass_note(symbol, 2), 72)
        song.note("timpani", 64 + i * 4, 0.6, bass_note(symbol, 2), 84 if i % 4 == 0 else 62)
    # 4) Coda: las tres llaves (La-Mi-Re) y el acorde final.
    song.tempo(128, 64)
    coda = ["G", "A", "D", "D"]
    pads(song, "strings", 128, coda, 4, 70)
    pads(song, "choir", 128, coda, 4, 70, octave=1)
    for k, note in enumerate(("A5", "E6", "D6", "A6", "D7")):
        song.note("celesta", 136 + k * 0.5, 6, note, 58)
        song.note("bells", 136 + k * 0.5, 6, pitch(note) - 12, 44 + k * 4)
    song.chord("strings", 136, 12, chord("D3", "A3", "D4", "F#4", "A4", "D5"), 76)
    song.chord("choir", 136, 12, chord("D4", "F#4", "A4", "D5"), 60)
    song.swell("strings", 136, 12, 120, 40)
    song.swell("choir", 136, 12, 110, 30)
    song.note("timpani", 136, 1, "D2", 100)
    return song


BUILDERS = {"map": (map_theme, True), "grutas": (grutas, True), "grutas_deep": (grutas_deep, True),
            "cefiro": (cefiro, True), "cefiro_summit": (cefiro_summit, True), "observatorio": (observatorio, True),
            "boss": (boss, True), "finale2": (finale2, False)}
WET = {"grutas": 0.34, "grutas_deep": 0.36, "observatorio": 0.36, "map": 0.3, "boss": 0.22}


def main(names: list[str]) -> None:
    metrics = {}
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        for name in names or list(BUILDERS):
            builder, loop = BUILDERS[name]
            song = builder()
            audio, seconds = render_song(song, loop, work, name, lufs=-26.0 if name == "boss" else -27.0,
                                         wet=WET.get(name, 0.26))
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
