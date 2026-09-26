extends RefCounted
## Texto de los créditos finales y del menú. Edita este archivo para poner tu nombre o tu estudio.

const STUDIO := "Equipo de Fragmentos de Luz"

const EPILOGUE := [
	"Los fragmentos se elevaron del escáner y el cielo respondió.",
	"Una luz tras otra apareció en las islas distantes.",
	"«No has devuelto la ciudad al pasado. Le has dado un mañana.»",
	"Neri cruzó el umbral. Al otro lado, alguien había visto la señal.",
]

## Fase 7: epílogo del capítulo II (Observatorio Estelar).
const EPILOGUE_II := [
	"El telescopio giró por primera vez en cien años y apuntó al corazón del cielo.",
	"La señal imposible se apagó: por fin alguien la había respondido.",
	"«Gracias por escuchar, Neri. Cuida de Luma por mí.»",
	"Una a una, las islas del archipiélago se acercaron a la luz del faro.",
]

const SECTIONS := [
	["FRAGMENTOS DE LUZ", ["Capítulo I · El Faro Dormido", "Capítulo II · La Señal Imposible"]],
	["Creación y dirección", [STUDIO]],
	["Dirección de arte y referencias", ["Miora · hojas de personaje, isla, zonas y props"]],
	["Personaje de Neri", ["Base y animaciones: Quaternius (CC0)", "Universal Base Characters · Universal Animation Library", "Adaptación y vestuario en Blender"]],
	["Luma, archivista de Auralia", ["Modelado procedural en Blender", "Animación procedural en Godot"]],
	["Mundo y efectos", ["Generadores de Blender y Godot del proyecto", "Shaders de portal, faro, cascadas, viento y espíritu"]],
	["El archipiélago", ["Grutas Prismáticas · Picos del Céfiro · Observatorio Estelar", "Cielos, nubes, cristal, rayos de luz y viento por shaders", "Vigías, Céfiros y el Heraldo del Eclipse modelados en Blender"]],
	["Constelación de Neri", ["Doce estrellas en tres ramas: Luz, Viento y Corazón"]],
	["Música original", ["Compuesta por procedimientos (MIDI)", "Interpretada con el banco FluidR3 GM (licencia MIT)"]],
	["Voces sintetizadas", ["Luma y Maren: Coqui TTS · Tacotron2-DDC español (MPL 2.0), corpus M-AILABS", "Neri y el cronista: Piper TTS (MIT) · voz carlfm (dominio público)"]],
	["Tipografías", ["Cinzel y Cinzel Decorative · Nunito (SIL Open Font License)"]],
	["Motor", ["Godot Engine 4.7 · Blender 5"]],
	["Gracias por jugar", ["La historia de Auralia continuará."]],
]
