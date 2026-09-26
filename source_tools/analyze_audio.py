"""Revisión objetiva de audio: sonoridad, picos, costura de bucle, crominancia por compás y espectrograma.

Uso: python source_tools/analyze_audio.py archivo.ogg [bpm beats_por_compás] [--png salida.png]
"""
import subprocess
import sys
import tempfile

import numpy as np
import pyloudnorm
import soundfile

NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def load(path: str) -> tuple[np.ndarray, int]:
    if path.endswith(".ogg"):
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, tmp.name], check=True)
            audio, rate = soundfile.read(tmp.name, always_2d=True)
    else:
        audio, rate = soundfile.read(path, always_2d=True)
    return audio, rate


def chroma(segment: np.ndarray, rate: int) -> np.ndarray:
    mono = segment.mean(axis=1)
    if len(mono) < 2048:
        return np.zeros(12)
    window = np.hanning(len(mono))
    spectrum = np.abs(np.fft.rfft(mono * window))
    freqs = np.fft.rfftfreq(len(mono), 1 / rate)
    result = np.zeros(12)
    mask = (freqs > 60) & (freqs < 2500)
    midi = 69 + 12 * np.log2(freqs[mask] / 440.0)
    classes = np.round(midi).astype(int) % 12
    np.add.at(result, classes, spectrum[mask] ** 2)
    return result / (result.sum() + 1e-12)


def main() -> None:
    path = sys.argv[1]
    numbers = [a for a in sys.argv[2:] if a.replace(".", "", 1).isdigit()]
    bpm = float(numbers[0]) if numbers else 0
    beats = int(numbers[1]) if len(numbers) > 1 else 4
    audio, rate = load(path)
    meter = pyloudnorm.Meter(rate)
    print(f"{path}: {len(audio) / rate:.2f}s  LUFS={meter.integrated_loudness(audio):.1f}  "
          f"peak={np.abs(audio).max():.3f}")
    seam = np.abs(audio[-1] - audio[0]).max()
    step = np.abs(np.diff(audio, axis=0)).mean()
    print(f"loop seam jump={seam:.4f} (typical sample step {step:.4f})")
    head = np.sqrt((audio[: rate // 2] ** 2).mean())
    tail = np.sqrt((audio[-rate // 2:] ** 2).mean())
    print(f"rms first 0.5s={head:.4f} last 0.5s={tail:.4f}")
    if bpm:
        bar = 60.0 / bpm * beats
        count = int(len(audio) / rate / bar)
        line = []
        for i in range(count):
            c = chroma(audio[int(i * bar * rate): int((i + 1) * bar * rate)], rate)
            top = [NAMES[k] for k in np.argsort(c)[::-1][:3]]
            line.append(f"{i + 1}:{'-'.join(top)}")
        print("bars:", "  ".join(line))
    if "--png" in sys.argv:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        out = sys.argv[sys.argv.index("--png") + 1]
        mono = audio.mean(axis=1)
        fig, axes = plt.subplots(2, 1, figsize=(14, 6), gridspec_kw={"height_ratios": [1, 3]})
        env = np.sqrt(np.convolve(mono ** 2, np.ones(2048) / 2048, mode="same"))
        axes[0].plot(np.arange(len(env))[::512] / rate, env[::512])
        axes[0].set_xlim(0, len(mono) / rate)
        axes[1].specgram(mono, NFFT=4096, Fs=rate, noverlap=3072, cmap="magma", vmin=-120)
        axes[1].set_ylim(0, 5000)
        plt.tight_layout()
        plt.savefig(out, dpi=60)


if __name__ == "__main__":
    main()
