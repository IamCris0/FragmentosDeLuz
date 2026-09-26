"""Voces de las fases 6 y 7 con Coqui TTS y Piper TTS (offline) y procesado de estudio con Pedalboard.

Uso:  python source_tools/build_voices.py [id ...]
Requisitos: pip install piper-tts pedalboard soundfile pyloudnorm numpy scipy
Modelos:
  Luma  -> Coqui TTS Tacotron2-DDC español (M-AILABS, voz femenina) + vocoder MelGAN, MPL 2.0.
           Se ejecuta con el Python de Coqui indicado en FDL_COQUI_PYTHON y los modelos en FDL_COQUI_MODELS
           (ver coqui_synth.py). El modelo Piper mls_10246 se descartó: repetía y alargaba frases.
  Neri y el cronista -> Piper voice-es-carlfm-x-low (dominio público), GitHub rhasspy/piper v0.0.2,
           en source_assets/voices/ o en la variable FDL_VOICES.
Salida: godot/assets/audio/voice/<id>.ogg  (id = "vo_" + id de la historia o de la cinemática)

Luma suena como un espíritu: coro suave, un armónico brillante muy bajo y reverberación.
Neri se sube dos semitonos para rejuvenecer la voz base. El cronista baja tres y resuena en sala.
Fase 7: Maren (la farolera, un eco de luz) usa la voz de Coqui dos semitonos y medio más grave, más cálida,
lejana y con un eco una octava por debajo. Las voces de Coqui se sintetizan en lote (el modelo se carga una vez).
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
import soundfile
from pedalboard import (Chorus, Compressor, Delay, HighpassFilter, HighShelfFilter, LowShelfFilter, Pedalboard,
                        PitchShift, Reverb)
from scipy.signal import resample_poly

sys.path.insert(0, os.path.dirname(__file__))
from music_lib import RATE, normalize, write_ogg  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "godot", "assets", "audio", "voice")
VOICE_DIRS = [os.environ.get("FDL_VOICES", ""), os.path.join(ROOT, "source_assets", "voices"), "/home/claude/tts"]
PIPER = os.environ.get("FDL_PIPER", "piper")
COQUI_PYTHON = os.environ.get("FDL_COQUI_PYTHON", "/home/claude/coquienv/bin/python")
COQUI_MODELS = os.environ.get("FDL_COQUI_MODELS", "/home/claude/coqui")

MODELS = {
    "luma": ("voice-es-mls_10246-low", "es-mls_10246-low.onnx", 1.06, 0.5),
    "neri": ("voice-es-carlfm-x-low", "es-carlfm-x-low.onnx", 1.14, 0.55),
    "cronista": ("voice-es-carlfm-x-low", "es-carlfm-x-low.onnx", 1.2, 0.5),
}

LINES = {
    # Prólogo (narración por viñeta; coincide con los textos en pantalla).
    "vo_prologue_0": ("cronista", "Antes de la tormenta, el faro mantenía unidas las islas suspendidas."),
    "vo_prologue_1": ("cronista", "Una señal imposible partió el núcleo en siete fragmentos de luz."),
    "vo_prologue_2": ("cronista", "Años después, Neri encuentra el eco perdido en su escáner."),
    "vo_prologue_3": ("cronista", "En las ruinas espera Luma, y con ella, la última ruta hacia el faro."),
    # Diálogos del capítulo (story ids).
    "vo_arrival": ("neri", "La señal de mi escáner termina aquí. Islas que no deberían flotar. Un faro que no debería "
                           "seguir encendido. Hay ecos moviéndose entre las ruinas. Si el escáner responde, quizás "
                           "pueda empujarlos con una descarga de luz."),
    "vo_luma_intro": ("luma", "Llegaste siguiendo una señal, Neri. Yo llevo cien años esperando una respuesta. Cuando "
                              "el faro se apagó, nuestra ciudad se partió en el cielo. No todo lo que quedó aquí quiere "
                              "volver a despertar. Los ecos del faro se alimentan de energía viva: si se acercan "
                              "demasiado, usa tu pulso de luz. Recupera los siete fragmentos de su núcleo. En el jardín, "
                              "despierta primero la ola, después el sol, y al final la estrella. El puente recordará el "
                              "camino."),
    "vo_garden_hint": ("luma", "El agua recuerda. El sol despierta. La estrella guía. Ola, sol, estrella. Una nota fuera "
                               "de lugar devuelve el jardín al silencio."),
    "vo_relic": ("cronista", "Quien encuentre esta reliquia: no reconstruya nuestros muros. Encienda el faro, para que "
                             "los que aún flotan lejos puedan volver a casa. El consejo de Auralia."),
    "vo_ending": ("luma", "Los fragmentos se elevan de tu escáner, y el cielo responde. Una luz tras otra aparece en las "
                          "islas distantes. No has devuelto la ciudad al pasado. Le has dado un mañana."),
    # Memorias de Auralia (coleccionables de la fase 6).
    "vo_lore_1": ("luma", "Los faroleros de Auralia cantaban al encender la luz. Decían que el faro no iluminaba el camino: lo recordaba."),
    "vo_lore_2": ("luma", "Aquí crecían jardines que sonaban con el viento. Cada flor guardaba una nota, y cada nota, un nombre."),
    "vo_lore_3": ("luma", "Los engranajes no movían piedras: movían mareas de luz. Cuando se detuvieron, las islas empezaron a alejarse unas de otras."),
    "vo_lore_4": ("luma", "Desde el Paso del Cielo, los viajeros veían otras islas brillar como faroles lejanos. Esperaban una señal para volver."),
    "vo_lore_5": ("luma", "La noche de la fractura, alguien envió una señal imposible desde el faro. Nadie supo quién. Luma nunca dejó de escucharla."),
    # Cinemáticas.
    "vo_cine_arrival_1": ("luma", "Siete fragmentos. Un faro dormido desde hace cien años."),
    "vo_cine_arrival_2": ("luma", "Y, por fin, alguien ha escuchado la señal."),
    "vo_cine_garden_1": ("luma", "El jardín recuerda su melodía."),
    "vo_cine_garden_2": ("luma", "El camino al Paso del Cielo está abierto."),
    "vo_cine_guardian_1": ("luma", "Ese eco nació del núcleo roto. Interrumpe su carga con tu pulso de luz."),
    "vo_cine_finale_1": ("luma", "Los siete fragmentos vuelven a casa."),
    "vo_cine_finale_2": ("luma", "El faro vuelve a cantar."),
    "vo_cine_finale_3": ("luma", "Una luz tras otra, las islas lejanas responden."),
    "vo_cine_finale_4": ("luma", "No has devuelto la ciudad al pasado, Neri. Le has dado un mañana."),
    "vo_cine_finale_5": ("neri", "Alguien más vio la señal. Vamos, Luma."),
    # --- Capítulo II · La Señal Imposible (fase 7) ---
    "vo_ch2_call": ("luma", "¿Lo sientes, Neri? La luz del faro ha llegado más lejos que nunca. Tres islas le responden: "
                            "unas grutas de cristal, unos picos donde aún sopla el viento, y el viejo Observatorio. "
                            "La señal imposible sigue sonando allí arriba. El portal del faro ya puede llevarte hasta ellas. "
                            "Guarda cada destello que encuentres: con ellos encenderás tu constelación."),
    "vo_map_intro": ("luma", "Esta es la carta del archipiélago, Neri. Cada isla que despiertes quedará unida a las demás "
                             "por un hilo de luz. Las Grutas Prismáticas nos esperan primero. Cuando recuperes las llaves "
                             "del prisma y del viento, el Observatorio abrirá su cúpula, y sabremos quién envió la señal."),
    "vo_grutas_arrival": ("luma", "Estas grutas eran el taller de los talladores de luz. Mira esos emisores: todavía guardan "
                                  "un rayo dormido. Gira los prismas: la flecha dorada marca hacia dónde saldrá la luz. Si "
                                  "el rayo alcanza un receptor, el cristal recordará lo que debía abrir."),
    "vo_grutas_luma_prism": ("luma", "Sigue el rayo con la mirada: nace en el emisor, se dobla en cada prisma y se detiene "
                                     "al tocar piedra, o un receptor. Gira el prisma hasta que su flecha mire hacia el receptor."),
    "vo_grutas_luma_heart": ("luma", "Más allá del salón, el corazón prismático espera dos rayos a la vez. Y si ves una "
                                     "cornisa demasiado alta, quizá tu constelación tenga una estrella para ella."),
    "vo_grutas_luma_done": ("luma", "Las grutas brillan como hace cien años. Cuando quieras, cualquier portal nos devolverá "
                                    "a la carta del archipiélago."),
    "vo_grutas_heart": ("luma", "¡El corazón prismático late otra vez! La Llave del Prisma está despertando sobre el altar. "
                                "Tómala, Neri."),
    "vo_grutas_key": ("luma", "La Llave del Prisma. Siento cómo el Observatorio responde, muy lejos. Una llave menos, Neri. "
                              "El portal del fondo se ha encendido: nos llevará de vuelta a la carta."),
    "vo_cefiro_arrival": ("luma", "Aquí arriba el viento todavía recuerda a los faroleros. Toma: guardé este hilo de luz "
                                  "para ti. Si mantienes el salto en el aire, se abrirá como unas alas. Planea sobre el "
                                  "vacío y busca las corrientes que suben: dentro de ellas, el viento te llevará hacia arriba."),
    "vo_cefiro_luma_glide": ("luma", "Salta y mantén pulsado: las alas de luz frenan la caída y te dejan avanzar mucho más "
                                     "lejos. Si una nube de piedra tiembla, salta enseguida."),
    "vo_cefiro_luma_mills": ("luma", "Tres válvulas, tres molinos. Cuando los tres giren, el viento se reunirá en el centro "
                                     "y podrás subir hasta la cumbre planeando."),
    "vo_cefiro_luma_done": ("luma", "¿Oyes los molinos? Vuelven a cantar. Solo queda el Observatorio, Neri."),
    "vo_cefiro_key": ("luma", "La Llave del Viento. Dos llaves, Neri. El Observatorio ya puede oírnos: el portal de la "
                              "cumbre nos llevará a la carta."),
    "vo_observatorio_arrival": ("luma", "Conozco este lugar. Aquí trabajaba Maren, la farolera que me creó. La señal nace "
                                        "bajo esa cúpula, Neri. No sé qué nos espera arriba. Pero esta vez no voy a "
                                        "quedarme esperando: vamos juntos."),
    "vo_observatorio_luma_stars": ("luma", "La estela muestra a La Farolera. Empieza por la estrella mayor, la del asa, "
                                           "y recorre el contorno del farol sin saltarte ninguna."),
    "vo_observatorio_luma_dome": ("luma", "Si el Heraldo se esconde tras su escudo, busca el pilar que brille. La luz de "
                                          "las estrellas es lo único que lo atraviesa."),
    "vo_observatorio_luma_done": ("luma", "Maren me dejó cuidando la luz. Ahora sé que no estaba sola: te tenía a ti, "
                                          "aunque aún no lo supiera."),
    # Memorias del archipiélago.
    "vo_lore_g1": ("luma", "Los talladores de luz trabajaban de noche. No cortaban el cristal: lo convencían. Decían que un "
                           "prisma bien orientado podía llevar una promesa hasta la otra punta del archipiélago."),
    "vo_lore_g2": ("luma", "El corazón prismático nunca se apagó del todo. Cuando el faro cayó, los talladores sellaron su "
                           "luz aquí para que la señal tuviera dónde apoyarse. Ahora vuelve a latir."),
    "vo_lore_c1": ("luma", "Los guardianes del viento no tenían alas. Tenían paciencia: esperaban al borde del acantilado "
                           "hasta que el aire subía, y entonces se dejaban llevar."),
    "vo_lore_c2": ("luma", "Los molinos no molían grano: cantaban. Cada aspa daba una nota al viento, y la canción llevaba "
                           "las noticias de isla en isla. Cuando callaron, el archipiélago dejó de hablar."),
    "vo_lore_o1": ("luma", "Maren fue la última farolera de Auralia. Construyó a Luma con restos de estrellas, para que "
                           "alguien siguiera escuchando cuando ella ya no pudiera."),
    "vo_lore_o2": ("maren", "La noche del eclipse encerré al Heraldo bajo la cúpula con mi propia luz. Antes de apagarme, "
                            "apunté el telescopio al futuro y envié una señal. Que alguien la escuche."),
    # Cinemáticas del capítulo II.
    "vo_cine_grutas_1": ("luma", "Aquí la luz no se pierde, Neri. Se dobla."),
    "vo_cine_grutas_2": ("luma", "Guía los rayos hasta el corazón, y la Llave del Prisma despertará."),
    "vo_cine_grutas_3": ("luma", "El corazón prismático recuerda."),
    "vo_cine_cefiro_1": ("luma", "Los molinos callaron hace cien años."),
    "vo_cine_cefiro_2": ("luma", "Despiértalos, y el viento te llevará a la cumbre."),
    "vo_cine_cefiro_3": ("luma", "¡Los tres molinos cantan! La gran corriente te espera."),
    "vo_cine_obs_1": ("luma", "La señal nace aquí. Bajo esa cúpula."),
    "vo_cine_obs_2": ("luma", "Vamos juntos, Neri."),
    "vo_cine_obs_3": ("luma", "La Farolera. Maren la dibujaba en todas partes."),
    "vo_cine_obs_4": ("luma", "¡El eco que apagó el faro! Enciende los pilares estelares: su luz rompe el escudo."),
    "vo_cine_obs_5": ("luma", "Maren. Te esperé cien años."),
    "vo_cine_obs_6": ("neri", "Prisma, viento y estrella. Todas en su sitio."),
    "vo_cine_obs_7": ("luma", "¡La luz sube hasta el cielo!"),
    "vo_maren_1": ("maren", "Por fin alguien respondió a la señal."),
    "vo_maren_2": ("maren", "Soy Maren. La noche del eclipse encerré aquí al Heraldo, y envié mi luz hacia el futuro."),
    "vo_maren_3": ("maren", "Y cuidaste la luz, pequeña. Neri: toma la llave y alinea el telescopio."),
    "vo_maren_4": ("maren", "Las islas vuelven a acercarse. Cuida de Luma por mí."),
    # Viñetas opcionales del capítulo II (se oyen solo si existen las ilustraciones, ver docs/PROMPTS_IA.md).
    "vo_ch2_comic_0": ("cronista", "Cuando el faro volvió a cantar, su luz cruzó el cielo más lejos que nunca. Y algo le respondió."),
    "vo_ch2_comic_1": ("cronista", "Tres islas despertaron: unas grutas de cristal, unos picos donde aún sopla el viento, y un viejo "
                                   "observatorio bajo las estrellas."),
    "vo_ch2_comic_2": ("cronista", "En el escáner de Neri, cada destello encendía una estrella nueva. Juntas dibujaban un camino."),
    "vo_ch2_comic_3": ("cronista", "Luma no dudó. Esta vez no esperarían a que la señal los encontrara. Irían a buscarla."),
    "vo_ch2_ending_0": ("cronista", "Maren sonrió por última vez bajo la cúpula. Su luz no se apagó: se quedó en el telescopio, "
                                    "apuntando al futuro."),
    "vo_ch2_ending_1": ("cronista", "Desde el Observatorio, un rayo unió las islas. Prisma, viento y estrella volvieron a hablar "
                                    "entre ellas."),
    "vo_ch2_ending_2": ("cronista", "Luma ya no esperaba una respuesta. Por primera vez en cien años, era ella quien la escribía."),
    "vo_ch2_ending_3": ("cronista", "Y en el borde del escáner de Neri, una señal nueva parpadeó. Mucho más lejos."),
}
COQUI_VOICES = ("luma", "maren")


def model_path(folder: str, filename: str) -> str:
    for base in VOICE_DIRS:
        if base and os.path.exists(os.path.join(base, folder, filename)):
            return os.path.join(base, folder, filename)
    raise FileNotFoundError(f"Falta el modelo {folder}/{filename}")


def coqui_batch(keys: list[str], work: str) -> dict:
    """Sintetiza todas las líneas de Coqui en una sola ejecución (sin red: los modelos son locales)."""
    import json
    jobs = [[LINES[key][1], os.path.join(work, key + ".coqui.wav")] for key in keys]
    if not jobs:
        return {}
    listing = os.path.join(work, "coqui_jobs.json")
    with open(listing, "w", encoding="utf-8") as handle:
        json.dump(jobs, handle, ensure_ascii=False)
    env = dict(os.environ, HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1")
    subprocess.run([COQUI_PYTHON, os.path.join(os.path.dirname(__file__), "coqui_synth.py"), COQUI_MODELS, "--batch", listing],
                   check=True, capture_output=True, env=env)
    return {key: path for key, (_, path) in zip(keys, jobs)}


def synthesize(voice: str, text: str, work: str, coqui_wav: str = "") -> np.ndarray:
    wav = os.path.join(work, "line.wav")
    if voice in COQUI_VOICES:
        if not coqui_wav:
            coqui_wav = coqui_batch([k for k, v in LINES.items() if v == (voice, text)][:1], work).popitem()[1]
        audio, rate = soundfile.read(coqui_wav, dtype="float32")
        audio = resample_poly(audio, RATE, rate).astype(np.float32)
        return np.stack([audio, audio], axis=0)
    folder, filename, length, noise = MODELS[voice]
    subprocess.run([PIPER, "-m", model_path(folder, filename), "-f", wav, "--length-scale", str(length),
                    "--noise-scale", str(noise), "--noise-w-scale", "0.6", "--sentence-silence", "0.38"],
                   input=text.encode("utf-8"), check=True, capture_output=True)
    audio, rate = soundfile.read(wav, dtype="float32")
    audio = resample_poly(audio, RATE, rate).astype(np.float32)
    return np.stack([audio, audio], axis=0)


def process(voice: str, audio: np.ndarray) -> np.ndarray:
    lead = np.zeros((2, int(0.08 * RATE)), dtype=np.float32)
    tail = np.zeros((2, int(1.1 * RATE)), dtype=np.float32)
    audio = np.concatenate([lead, audio, tail], axis=1)
    if voice == "luma":
        body = Pedalboard([PitchShift(1.0), HighpassFilter(110), LowShelfFilter(250, -2.0), HighShelfFilter(4200, 2.0),
                           Compressor(-22, 2.5, 8, 120)])(audio, RATE)
        shimmer = Pedalboard([PitchShift(12), HighpassFilter(1800)])(body, RATE) * 0.07
        mixed = Pedalboard([Chorus(rate_hz=0.6, depth=0.18, centre_delay_ms=9, feedback=0.1, mix=0.3),
                            Delay(delay_seconds=0.19, feedback=0.15, mix=0.07),
                            Reverb(room_size=0.6, damping=0.5, wet_level=0.2, dry_level=0.86, width=0.9)])(body + shimmer, RATE)
    elif voice == "maren":
        body = Pedalboard([PitchShift(-2.5), HighpassFilter(90), LowShelfFilter(260, 1.5), HighShelfFilter(5200, -2.5),
                           Compressor(-22, 2.5, 8, 140)])(audio, RATE)
        ghost = Pedalboard([PitchShift(-12), HighpassFilter(160), HighShelfFilter(2500, -6.0)])(body, RATE) * 0.1
        mixed = Pedalboard([Chorus(rate_hz=0.35, depth=0.12, centre_delay_ms=12, feedback=0.05, mix=0.22),
                            Delay(delay_seconds=0.31, feedback=0.22, mix=0.12),
                            Reverb(room_size=0.88, damping=0.4, wet_level=0.3, dry_level=0.78, width=1.0)])(body + ghost, RATE)
    elif voice == "neri":
        mixed = Pedalboard([PitchShift(2.0), HighpassFilter(95), LowShelfFilter(220, -1.5), HighShelfFilter(4000, 2.0),
                            Compressor(-20, 2.5, 6, 120),
                            Reverb(room_size=0.28, damping=0.6, wet_level=0.08, dry_level=0.95, width=0.6)])(audio, RATE)
    else:
        mixed = Pedalboard([PitchShift(-3.0), HighpassFilter(70), LowShelfFilter(200, 2.0), HighShelfFilter(5000, -1.5),
                            Compressor(-22, 2.5, 8, 150),
                            Reverb(room_size=0.72, damping=0.55, wet_level=0.2, dry_level=0.85, width=1.0)])(audio, RATE)
    mixed = mixed.T
    # Recorta el silencio final dejando la cola de reverberación.
    energy = np.abs(mixed).max(axis=1)
    last = np.nonzero(energy > 0.002)[0]
    end = min(len(mixed), (last[-1] if len(last) else len(mixed)) + int(0.25 * RATE))
    return mixed[:end]


def main(ids: list[str]) -> None:
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        keys = ids or list(LINES)
        coqui = coqui_batch([key for key in keys if LINES[key][0] in COQUI_VOICES], work)
        for key in keys:
            voice, text = LINES[key]
            audio = process(voice, synthesize(voice, text, work, coqui.get(key, "")))
            audio = normalize(audio, -19.0, ceiling_db=-1.0)
            write_ogg(audio, os.path.join(OUT, key + ".ogg"), quality=4)
            print("VOICE", key, voice, round(len(audio) / RATE, 2))


if __name__ == "__main__":
    main(sys.argv[1:])
