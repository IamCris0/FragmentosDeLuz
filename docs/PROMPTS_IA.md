# Fragmentos de Luz · Prompts para Gemini y ChatGPT (Capítulo II)

Este documento reúne los prompts para producir, con Gemini y ChatGPT en paralelo, las ilustraciones, los iconos, el vídeo y los guiones del Capítulo II · *La Señal Imposible*.

El juego ya tiene preparados los huecos para estas imágenes:

- Si un archivo existe en la ruta indicada, el juego lo muestra.
- Si no existe, todo sigue funcionando con el arte actual.

Nada de lo que falte rompe el juego.

---

## 0. Cómo trabajar

### Reparto recomendado

| Tarea | Mejor en | Por qué |
|---|---|---|
| Retratos con fondo transparente, iconos, cambios pequeños sobre una imagen | ChatGPT (imagen) | Admite fondo transparente y edita bien sobre una imagen adjunta |
| Viñetas 16:9, postales, paisajes amplios | Gemini (Imagen / Nano Banana) | Formato 16:9 nativo y buena coherencia de escena |
| Vídeo del tráiler | Gemini (Veo) o ChatGPT (Sora) | Plano a plano, partiendo de las viñetas o postales como primer fotograma |
| Guiones, diálogos, ideas del Capítulo III | Cualquiera de los dos | Pega primero la «Biblia del mundo» (sección 9) |

Consejo: lanza el mismo prompt en los dos a la vez y quédate con el mejor resultado. Después pide variaciones solo al que acertó.

### Imágenes de referencia que conviene adjuntar

Adjuntarlas mantiene a los personajes y el estilo coherentes con el Capítulo I.

- `referencias/01_personaje.png`: hoja de personaje de Neri.
- `godot/assets/story/prologue_comic.png`: viñetas del prólogo. Son la referencia de estilo principal.
- Capturas del juego, útiles para las postales y para repintar escenarios:
  - `previews/levels/grutas_03_salon.png`
  - `previews/levels/cefiro_04_molinos.png`
  - `previews/levels/observatorio_02_constelacion.png`

### Bloque de estilo (pégalo al principio de cada prompt de imagen)

```
STYLE: painterly anime fantasy illustration for a cozy Ghibli-inspired adventure game, matching the attached reference
images. Soft cel shading with hand-painted textures, warm golden rim light, luminous teal and gold magical accents,
atmospheric depth, sea of clouds and floating islands, clean readable silhouettes. Palette: navy #2F3A56, forest green
#4A7B5F, leather brown #8C5E3C, slate #5C6370, teal #1ABFB3, gold #D4AF37. No text, no letters, no captions,
no watermark, no logo, no UI, no borders.
```

### Personajes (copia la descripción de quien aparezca)

```
NERI: a young teen explorer (about 14) with messy chestnut-brown hair and brown eyes; navy blue short tunic with subtle
teal tech stitching, brown leather belt, slim charcoal trousers, brown ankle boots with small teal crystal details,
dark fingerless gloves with a glowing teal gem, a wrist-mounted crystal scanner on the LEFT forearm glowing teal, and a
small green canvas backpack with a brass compass and crystal vials.

LUMA: a tiny floating light spirit the size of a cat: a smooth round dark-navy head like polished stone with two big
glowing cyan eyes and no mouth, a small teal crystal antenna on top, translucent teal crystal fins like little wings,
a soft cyan glow and a trail of sparkles.

MAREN: the last lamplighter of Auralia, appearing as an echo made of pale blue starlight (#CFE8FF): a tall graceful
woman in her sixties, long silver hair in a loose braid, kind tired eyes, a long hooded lamplighter's coat embroidered
with tiny stars and brass buttons, holding a tall brass lantern staff with a warm golden flame. Her figure is
semi-transparent and softly glowing, with drifting motes of light.

HERALDO DEL ECLIPSE (boss): a colossal floating eclipse entity: a black obsidian sphere core wrapped in a burning orange
corona, a cracked stone mask made of three horizontal slabs with glowing ember eye slits, a golden halo ring with
sixteen spikes, six violet crystal shards orbiting it, and a translucent orange-violet eclipse shield dome.

VIGÍA (enemy): a floating sentinel echo: a dark violet orb with a single glowing magenta eye, four short crystal spikes
and a crystal tail spike, orbited by a thin brass ring and a violet energy ring.

CÉFIRO (enemy): a wind creature like a small manta ray made of pale teal cloud-silk with glowing aqua edges, two tiny
bright eyes, and a long whip-like tail ending in a glowing orb.
```

### Islas (copia la que aparezca)

```
GRUTAS PRISMÁTICAS: violet crystal caves inside a floating island at night; tall crystal spires, prisms on bronze
stands bending golden beams of light, bronze beam emitters, a huge pulsing prismatic heart crystal in the deepest cavern.

PICOS DEL CÉFIRO: windswept cliffs above the sea of clouds at dawn; old stone windmill towers with wooden blades,
floating cloud-stones (some cracked and crumbling), upward wind currents visible as spiraling white streaks,
brass wind valves, a carousel of wooden arms turning over the void.

OBSERVATORIO ESTELAR: a marble island under a deep starry night; the floor is inlaid with gold constellation lines, an
orrery with rotating gold rings and a small ringed planet, a domed observatory with a teal-and-gold striped dome on
white columns, a giant brass telescope inside, three glowing star pillars.

AURALIA: the island of the restored lighthouse from Chapter I, a tall white stone tower with a golden lantern room
shining over ancient ruins, waterfalls and gardens.
```

### Dónde guardar cada imagen

Copia los archivos a la carpeta del proyecto con el nombre exacto de cada sección. Después abre el proyecto una vez con `Abrir_editor.cmd` para que Godot las importe.

- Formato: PNG, o también JPG o WEBP.
- Los retratos necesitan fondo transparente.

---

## 1. Retratos de diálogo (en el juego)

Asoman sobre el cuadro de diálogo cuando habla ese personaje.

**Rutas**

- `godot/assets/ui/portraits/luma.png`
- `godot/assets/ui/portraits/neri.png`
- `godot/assets/ui/portraits/maren.png`

**Formato**

- Cuadrado, 1024×1024.
- Fondo transparente.
- Busto en vista 3/4 mirando hacia la derecha.

Hazlos en ChatGPT (pide «transparent background»). Si usas Gemini, quita después el fondo con cualquier herramienta de recorte.

```
[STYLE]
[NERI]
Character portrait for a dialogue box: head and shoulders bust, three-quarter view facing RIGHT, warm confident smile,
soft teal glow from the wrist scanner lighting the chin from below. Centered, the head fills the upper two thirds.
Transparent background, no frame. Square 1024x1024.
```

```
[STYLE]
[LUMA]
Character portrait for a dialogue box: Luma floating, three-quarter view facing RIGHT, curious happy expression shown
only through the shape of the glowing eyes, fins slightly raised. Centered with some margin. Transparent background,
no frame. Square 1024x1024.
```

```
[STYLE]
[MAREN]
Character portrait for a dialogue box: head and shoulders bust, three-quarter view facing RIGHT, gentle melancholic
smile, the lantern flame just visible at the lower edge, her starlight body slightly translucent with glowing motes.
Transparent background, no frame. Square 1024x1024.
```

---

## 2. Interludio del Capítulo II (en el juego)

Son cuatro viñetas a pantalla completa. Se ven la primera vez que se abre la Carta del archipiélago, con texto y narración. La narración ya está grabada.

**Rutas**

- `godot/assets/story/chapter2_comic_1.png`
- `godot/assets/story/chapter2_comic_2.png`
- `godot/assets/story/chapter2_comic_3.png`
- `godot/assets/story/chapter2_comic_4.png`

**Formato**

- 16:9, 1920×1080 o mayor.
- Deja libre de detalles importantes el 25 % inferior: ahí va el texto.
- Alternativa: una sola imagen 2×2 llamada `chapter2_comic.png`, con finos márgenes blancos como el prólogo.

**Viñeta 1 · La señal imposible**

```
[STYLE]
Wide cinematic establishing shot at night above an endless sea of clouds. On the left, the restored lighthouse of
Auralia (tall white stone tower with a golden lantern room) sends a brilliant golden beam across the sky. Far away on
the right horizon three distant floating islands answer with tiny lights: a violet glow, a teal glint and a starlit
dome from which a pulsing ring-shaped signal of light spreads outward. Magical, hopeful, quiet. 16:9, keep the bottom
quarter calm (clouds) for subtitles.
```

**Viñeta 2 · El archipiélago**

```
[STYLE]
[GRUTAS PRISMÁTICAS] [PICOS DEL CÉFIRO] [OBSERVATORIO ESTELAR]
One panoramic painting showing the three islands floating in a row above the clouds like stops on a journey: left the
violet crystal cave island glowing from inside, center the windmill peaks with turning blades and wind streaks, right
the observatory dome under a field of stars. Faint golden threads of light connect them like lines on a map. Twilight
gradient sky from violet (left) to deep blue (right). 16:9, bottom quarter calm.
```

**Viñeta 3 · La constelación**

```
[STYLE]
[NERI] [LUMA]
Over-the-shoulder shot of Neri sitting on an old stone ledge at dusk, raising the left wrist scanner, which projects a
large holographic star map in teal and gold: a constellation with three branches (gold for light, aqua for wind, rose
for heart) growing from a bright central star. Small four-pointed golden sparkles float from the air into the
projection. Luma hovers beside Neri, its cyan eyes reflecting the stars. 16:9, bottom quarter darker for subtitles.
```

**Viñeta 4 · El viaje**

```
[STYLE]
[NERI] [LUMA]
Seen from behind: Neri and Luma step toward a swirling blue portal ring set in an ancient stone frame on the lighthouse
island. Through the portal we glimpse the archipelago: crystal caves, windmills and the observatory dome, linked by
threads of light. Morning light, wind in Neri's hair, adventurous mood. 16:9, bottom quarter calm.
```

---

## 3. Epílogo del Capítulo II (en el juego)

Son cuatro viñetas que se ven tras la cinemática final, antes de los créditos.

**Rutas**

- `godot/assets/story/chapter2_ending_1.png` a `chapter2_ending_4.png`
- Alternativa: una hoja 2×2 llamada `chapter2_ending.png`

**Formato:** igual que el interludio.

**Viñeta 1 · La farolera**

```
[STYLE]
[MAREN] [NERI] [LUMA]
Inside the observatory dome at night, under the giant brass telescope. Maren's starlight echo kneels and gently touches
Luma with one glowing hand while Neri watches with emotion. Her lantern bathes everyone in warm gold against the cool
blue starlight. Tender farewell. 16:9, bottom quarter calm.
```

**Viñeta 2 · El hilo de luz**

```
[STYLE]
[OBSERVATORIO ESTELAR]
Exterior wide shot: the observatory telescope fires a pillar of golden light into the starry sky; from the top of the
beam, threads of light fall and connect the violet crystal island, the windmill peaks and the distant lighthouse.
The islands seem to drift closer together. Epic and luminous. 16:9, bottom quarter calm.
```

**Viñeta 3 · Luma**

```
[STYLE]
[LUMA]
Quiet dawn on the observatory balcony: Luma alone at the marble railing above the sea of clouds, drawing small glowing
symbols in the air that rise like fireflies toward the horizon, as if writing a message. Soft pink and gold sunrise,
peaceful and bittersweet. 16:9, bottom quarter calm.
```

**Viñeta 4 · Más allá** (gancho para el Capítulo III)

```
[STYLE]
[NERI]
Close-up of Neri's wrist scanner screen showing the archipelago map drawn in teal light, and at the very edge of the
screen a new faint signal blinking in magenta. In the blurred background, beyond the clouds, the silhouette of an
unknown dark island with a single strange light. Mysterious, promising. 16:9, bottom quarter calm.
```

---

## 4. Postales de las islas (en el juego)

Aparecen en el panel de la Carta del archipiélago al elegir cada isla.

**Rutas**

- `godot/assets/story/postcards/auralia.png`
- `godot/assets/story/postcards/grutas.png`
- `godot/assets/story/postcards/cefiro.png`
- `godot/assets/story/postcards/observatorio.png`

**Formato**

- 16:9, unos 1600×900.
- El juego la recorta a 2:1: deja el motivo principal en el centro.
- Mejor sin personajes.

Si adjuntas la captura del juego de cada isla, pide «repaint this game screenshot as a finished illustration keeping the layout».

```
[STYLE]
[GRUTAS PRISMÁTICAS]
Postcard-like establishing view of the crystal cave island, seen from the entrance: a golden light beam bouncing between
two prisms toward a glowing receptor crystal, violet spires framing the path. Centered composition, 16:9.
```

```
[STYLE]
[PICOS DEL CÉFIRO]
Postcard-like establishing view of the windmill peaks at sunrise: three stone windmills with turning blades on a
plateau, a great spiral updraft rising in the middle, floating cloud-stones leading to the summit. Centered, 16:9.
```

```
[STYLE]
[OBSERVATORIO ESTELAR]
Postcard-like establishing view of the observatory island at night: grand marble stairs leading to a garden with a
glowing golden constellation drawn on the floor, the orrery rings beyond and the striped dome at the top.
Centered, 16:9.
```

```
[STYLE]
[AURALIA]
Postcard-like establishing view of Auralia at golden hour, the lighthouse fully lit and beaming, gardens, bridges and
waterfalls around it, other islands glowing in the distance. Centered, 16:9.
```

---

## 5. Iconos de la Constelación de Neri (en el juego)

Aparecen en la ficha de cada estrella del árbol de habilidades.

**Ruta:** `godot/assets/ui/skills/<id>.png`, un archivo por habilidad.

**Formato**

- Cuadrado, 512 o 1024.
- Sin texto.

Hazlos de uno en uno con el mismo bloque, que es más fiable que una hoja entera. Si prefieres una sola imagen, usa una cuadrícula exacta de 4×4 llamada `skills_sheet.png`, en el orden de la tabla. Las 3 últimas casillas van vacías.

Bloque común de iconos:

```
Game UI skill icon, part of a consistent set: round medallion with a thin gold filigree rim on a deep navy background,
a single glowing emblem in the center, painterly anime style, soft inner glow, strong readable silhouette at small
size, centered, no text, no letters. Square.
Emblem:
```

| Orden | id (nombre del archivo) | Estrella | Emblema (añádelo tras «Emblem:») | Color |
|---|---|---|---|---|
| 1 | `core` | Corazón del escáner | a teal crystal core set in a bracelet scanner, radiating light | teal and white |
| 2 | `pulse_wide` | Pulso amplio | a wide expanding ring of golden light | gold #F1D48B |
| 3 | `pulse_quick` | Pulso veloz | two quick concentric light rings with speed streaks | gold |
| 4 | `pulse_nova` | Nova | a supernova starburst with an outer ring | bright gold |
| 5 | `pulse_daze` | Destello cegador | a blinding four-pointed flash with small dizzy spirals | gold and white |
| 6 | `agile_roll` | Rodada ágil | a curved motion arc with a wind swoosh | aqua #8FE9D6 |
| 7 | `stride` | Zancada | a boot with small light wings at the heel | aqua |
| 8 | `double_jump` | Doble salto | two upward chevrons over a small air ring | aqua |
| 9 | `serene_glide` | Planeo sereno | calm spread wings of light over a small cloud | aqua |
| 10 | `vitality` | Vitalidad | a faceted heart-shaped crystal glowing | rose #F29E9E |
| 11 | `ember` | Brasa interior | a small warm ember flame inside a heart | rose and orange |
| 12 | `aegis` | Égida de luz | a hexagonal shield of light | rose and gold |
| 13 | `compass` | Brújula de destellos | a compass rose whose needle is a four-pointed star | rose and gold |

---

## 6. Hojas de personaje y enemigos (referencia, no entran en el juego)

Sirven para mantener la coherencia en los demás prompts, y para mejorar los modelos 3D en Blender o probar herramientas de imagen a 3D.

```
[STYLE]
[MAREN]
Character reference sheet on a light neutral background: front view, side profile and back view of Maren standing,
plus a close-up of the lantern staff and a color palette row. Clean turnaround, full body, consistent proportions.
Labels are NOT needed. 3:2.
```

```
[STYLE]
[LUMA]
Character reference sheet of Luma: front, side, back and three expressions (happy, worried, determined) conveyed only
by the eye shapes and fin poses. Light neutral background, no labels. 3:2.
```

```
[STYLE]
[VIGÍA] [CÉFIRO] [HERALDO DEL ECLIPSE]
Creature design sheet on a dark neutral background: the Vigía sentinel (front and side), the Céfiro wind creature
(top view and side view, tail extended) and the Heraldo del Eclipse boss (front view, with and without its eclipse
shield). Consistent scale markers are not needed; no labels. 16:9.
```

---

## 7. Arte clave del Capítulo II (promoción)

Sirve para la portada, redes o la página del juego. No entra en el juego.

**Formatos:** 16:9 para portada, 9:16 para móvil y 1:1 para redes.

Para la versión con título, pide primero la imagen sin texto y añade el rótulo después con la fuente del juego, `godot/assets/fonts`.

```
[STYLE]
[NERI] [LUMA] [HERALDO DEL ECLIPSE]
Epic key art: Neri stands on the edge of the observatory island's marble stairs, raising the glowing wrist scanner,
Luma at the shoulder. Behind them, towering in the night sky, the Heraldo del Eclipse spreads its burning corona
over the dome. Around them the three islands of the chapter (violet crystal caves, windmill peaks, starry
observatory) float in a spiral composition, linked by threads of golden light. Dramatic contrast between the warm
eclipse fire and the cool starlight. Leave clean space at the top for a title. 16:9.
```

---

## 8. Vídeo: tráiler del Capítulo II (unos 60 segundos)

Genera los planos uno a uno con Veo (Gemini) o Sora (ChatGPT). Para que los personajes no cambien, usa las viñetas o postales del juego como primer fotograma («image to video»).

**Montaje**

1. Monta los planos en cualquier editor.
2. Pon la música del juego debajo:
   - Del plano 1 al 6: `godot/assets/audio/music/observatorio.ogg`.
   - Del plano 7 en adelante: `boss.ogg`.
   - Cierre: `finale2.ogg`.
3. Añade las voces de Luma que ya existen en `godot/assets/audio/voice/`:
   - `vo_cine_obs_1.ogg`: «La señal nace aquí…».
   - `vo_cine_obs_4.ogg`: «¡El eco que apagó el faro!…».
   - `vo_maren_1.ogg`.

**Bloque común de vídeo** (pégalo delante de cada plano):

```
Cinematic animated shot in painterly anime fantasy style (cozy Ghibli-inspired adventure game), soft volumetric light,
gentle film grain, 24 fps, smooth camera, no text, no subtitles, no logos.
```

| Plano | Duración | Primer fotograma | Prompt |
|---|---|---|---|
| 1 | 6 s | `chapter2_comic_1` | Slow push-in toward the lighthouse as its golden beam sweeps across the night sky; far away a ring-shaped signal pulses from a distant dome. Clouds drift. |
| 2 | 5 s | `postcards/grutas` | Camera glides through violet crystal caves; a golden beam bends through two prisms and strikes a receptor crystal that blooms with light. |
| 3 | 5 s | captura o postal de Céfiro | Neri jumps off a cliff and opens wings of light, gliding into a spiral updraft between old windmills at sunrise; Luma follows. |
| 4 | 4 s | `postcards/cefiro` | A cloud-stone platform cracks and crumbles into the sea of clouds just after Neri leaps off it. Fast, playful. |
| 5 | 5 s | `postcards/observatorio` | Neri runs across a garden floor; each step lights a star of a golden constellation that draws itself as a lantern shape. |
| 6 | 4 s | ninguno | Close-up of Neri's wrist scanner projecting a holographic constellation that lights up branch by branch. |
| 7 | 6 s | arte clave | The Heraldo del Eclipse rises behind the observatory dome, its corona igniting, violet shards orbiting; the camera tilts up in awe. |
| 8 | 5 s | ninguno | Neri touches a star pillar; a column of starlight shatters the orange eclipse shield like glass. |
| 9 | 6 s | `chapter2_ending_1` | Maren's starlight echo smiles and touches Luma; motes of light rise. Emotional, slow. |
| 10 | 6 s | `chapter2_ending_2` | The telescope fires a pillar of light; threads of gold connect the islands. Camera pulls back to reveal the whole archipelago. |
| 11 | 4 s | `chapter2_ending_4` | Push-in on the scanner screen: a new magenta signal blinks at the edge of the map. Cut to black. |

Rótulos para el montaje:

- Tras el plano 1: «Una señal imposible».
- Tras el plano 6: «Enciende tu constelación».
- Al final: «Fragmentos de Luz · Capítulo II · La Señal Imposible».

**Teaser de 15 segundos:** planos 1, 7 y 11.

---

## 9. Guiones y textos (ChatGPT o Gemini)

Pega primero este bloque para que el modelo conozca el mundo:

```
BIBLIA DEL MUNDO — «Fragmentos de Luz»
Género: aventura 3D acogedora con plataformas, puzles de luz y combate suave (pulso de luz que purifica «ecos»).
Tono: esperanzador, poético, para todos los públicos; nada de violencia gráfica. Idioma: español neutro.
Mundo: Auralia era una ciudad de islas flotantes unidas por un faro. Hace cien años, en la noche del eclipse, el
Heraldo del Eclipse (un eco primordial) apagó el faro y las islas se separaron.
Personajes: Neri (joven exploradora/explorador con un escáner de cristal en la muñeca; valiente, curiosa, práctica);
Luma (pequeño espíritu de luz creado por Maren; esperó cien años escuchando la señal; tierna, sabia, algo melancólica);
Maren (la última farolera; encerró al Heraldo con su propia luz y envió una «señal imposible» hacia el futuro para que
alguien la escuchara; hoy es un eco de luz estelar).
Capítulo I · El Faro Dormido: Neri reúne siete fragmentos y enciende el faro.
Capítulo II · La Señal Imposible: Grutas Prismáticas (Llave del Prisma), Picos del Céfiro (Llave del Viento),
Observatorio Estelar (Llave de la Estrella, jefe Heraldo del Eclipse, aparición de Maren). Moneda: destellos.
Árbol de habilidades: Constelación de Neri (ramas Luz, Viento y Corazón).
Final del Capítulo II: el telescopio une las islas; en el escáner de Neri parpadea una señal nueva, mucho más lejos.
```

**Guion de la voz del tráiler**

```
Con la biblia anterior, escribe el texto de voz en off para un tráiler de 60 segundos del Capítulo II, sincronizado con
estos 11 planos: [pega la tabla de la sección 8]. Máximo 90 palabras en total, frases cortas, voz de Luma, tono épico y
cálido. Devuélvelo como tabla: plano, tiempo, texto.
```

**Ideas para el Capítulo III**

```
Con la biblia anterior, propón tres ideas para el Capítulo III que continúen la señal nueva del final. Para cada una:
título, isla o islas nuevas (2-3), mecánica principal nueva (que se pueda construir en Godot con geometría sencilla),
enemigo nuevo, jefe, giro de historia sobre Maren o Luma, y una habilidad nueva para la constelación. Tabla breve y
después un párrafo de sinopsis por idea.
```

**Frases de Luma durante la exploración**

```
Con la biblia anterior, escribe 30 frases breves (máximo 14 palabras) que Luma podría decir al explorar las tres islas
del Capítulo II: 10 por isla, mezclando pistas útiles, humor tierno y recuerdos de Maren. Sin repetir estructuras.
Formato: isla · situación · frase.
```

**Diálogos nuevos**

```
Con la biblia anterior, escribe un diálogo de 6-8 líneas entre Neri y Luma para cuando la jugadora encienda la última
estrella de la Constelación. Emotivo pero ligero; que Luma recuerde algo de Maren. Indica quién habla en cada línea.
```

Cuando tengas textos que te gusten, pásamelos y los integro en el juego con su voz.

---

## 10. Lista de control

**Retratos**

- [ ] `godot/assets/ui/portraits/luma.png`
- [ ] `godot/assets/ui/portraits/neri.png`
- [ ] `godot/assets/ui/portraits/maren.png`

**Viñetas**

- [ ] Interludio: `godot/assets/story/chapter2_comic_1.png` a `chapter2_comic_4.png`
- [ ] Epílogo: `godot/assets/story/chapter2_ending_1.png` a `chapter2_ending_4.png`

**Postales:** `godot/assets/story/postcards/`

- [ ] `auralia.png`
- [ ] `grutas.png`
- [ ] `cefiro.png`
- [ ] `observatorio.png`

**Iconos**

- [ ] 13 iconos en `godot/assets/ui/skills/`, con el id de la sección 5 como nombre

**Promoción y guiones**

- [ ] Arte clave (promoción)
- [ ] Tráiler y teaser
- [ ] Guiones (tráiler, Capítulo III, frases de Luma)

Después de copiar las imágenes, abre el proyecto una vez con `Abrir_editor.cmd` para que Godot las importe.
