"""Original short combat cues and a seamless tension layer, deterministic seed."""
import json
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot/assets/audio'
RATE = 32000
rng = np.random.default_rng(91626)
metrics = {}


def save(name, audio):
    audio = audio / max(1.0, float(np.max(np.abs(audio))) / .7)
    pcm = (np.clip(audio, -.99, .99) * 32767).astype('<i2')
    with wave.open(str(OUT / (name + '.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    metrics[name] = {'seconds': len(audio) / RATE, 'peak': float(np.max(np.abs(audio)))}


t = np.arange(int(.5 * RATE)) / RATE
noise = np.convolve(rng.normal(size=len(t)), np.ones(9) / 9, mode='same')
save('dodge', noise * np.sin(np.pi * t / .5) ** 2 + .08 * np.sin(2 * np.pi * (180 * t + 250 * t*t)) * np.exp(-t*8))
t = np.arange(int(1.35 * RATE)) / RATE
envelope = np.sin(np.pi * t / 1.35) ** 2
save('guardian_charge', envelope * (.24 * np.sin(2*np.pi*(130*t + 55*t*t)) + .13*np.sin(2*np.pi*390*t)))
t = np.arange(int(1.1 * RATE)) / RATE
noise = np.convolve(rng.normal(size=len(t)), np.ones(16)/16, mode='same')
save('guardian_wave', (1-np.exp(-t*80))*np.exp(-t*5)*(.6*noise + .25*np.sin(2*np.pi*(90*t - 20*t*t))))
t = np.arange(4 * RATE) / RATE
chime = np.zeros_like(t)
for index, note in enumerate([62, 66, 69, 74, 78]):
    elapsed = np.maximum(t-index*.19, 0)
    envelope = (1-np.exp(-elapsed*45))*np.exp(-elapsed*1.8)
    hz = 440*2**((note-69)/12)
    chime += .17*np.sin(2*np.pi*hz*elapsed)*envelope
save('beacon_chime', chime * np.minimum((4-t)*4, 1))
layer = np.zeros(16 * RATE)
for beat in range(32):
    t = np.arange(int(.45*RATE)) / RATE
    envelope = (1-np.exp(-t*120))*np.exp(-t*16)
    pulse = np.sin(2*np.pi*(82*t-55*t*t))*envelope*(.5 if beat%4==0 else .2)
    start = int(beat*.5*RATE)
    layer[start:start+len(pulse)] += pulse
save('combat_tension', layer)
(ROOT / 'blender/combat_audio_metrics.json').write_text(json.dumps(metrics, indent=2), encoding='utf-8')
print(json.dumps(metrics))
