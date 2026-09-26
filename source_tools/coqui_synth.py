"""Síntesis con Coqui TTS (Tacotron2-DDC español, voz femenina M-AILABS «karen_savage») para Luma.

Se ejecuta con el Python del entorno de Coqui (pip install coqui-tts torch torchcodec "gruut[es]" "transformers<5"):
  python coqui_synth.py <carpeta_modelos> <texto> <salida.wav>
  python coqui_synth.py <carpeta_modelos> --batch <lista.json>     (lista de [texto, salida.wav]; carga el modelo una vez)
Modelos (GitHub coqui-ai/TTS, release v0.6.1_models):
  tts_models--es--mai--tacotron2-DDC  (MPL 2.0)
  vocoder_models--universal--libri-tts--fullband-melgan  (MPL 2.0)
"""
import json
import os
import sys

import torch

_torch_load = torch.load


def _trusted_load(*args, **kwargs):
    # Los checkpoints oficiales de Coqui (2022) requieren la carga completa de PyTorch.
    kwargs["weights_only"] = False
    return _torch_load(*args, **kwargs)


torch.load = _trusted_load
from TTS.utils.synthesizer import Synthesizer  # noqa: E402


def local_config(folder: str) -> str:
    config = json.load(open(os.path.join(folder, "config.json")))
    if "audio" in config and "stats_path" in config["audio"]:
        config["audio"]["stats_path"] = os.path.abspath(os.path.join(folder, "scale_stats.npy"))
    path = os.path.join(folder, "config_local.json")
    json.dump(config, open(path, "w"))
    return path


def main() -> None:
    base = sys.argv[1]
    if sys.argv[2] == "--batch":
        jobs = json.load(open(sys.argv[3], encoding="utf-8"))
    else:
        jobs = [[sys.argv[2], sys.argv[3]]]
    tts = os.path.join(base, "tts_models--es--mai--tacotron2-DDC")
    vocoder = os.path.join(base, "vocoder_models--universal--libri-tts--fullband-melgan")
    synth = Synthesizer(tts_checkpoint=os.path.join(tts, "model_file.pth"), tts_config_path=local_config(tts),
                        vocoder_checkpoint=os.path.join(vocoder, "model_file.pth"),
                        vocoder_config=local_config(vocoder), use_cuda=False)
    for text, output in jobs:
        synth.save_wav(synth.tts(text), output)
        print("COQUI", output, flush=True)


if __name__ == "__main__":
    main()
