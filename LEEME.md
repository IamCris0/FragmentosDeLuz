# Fragmentos de Luz: El Faro Dormido y La Señal Imposible

Capítulo jugable construido a partir de las referencias visuales y guías recibidas de Miora. Es una aventura 3D estilizada en Godot 4 con assets producidos en Blender, menú principal con la isla en vivo, prólogo tipo cómic narrado, cinemáticas en tiempo real, recorrido de tercera persona, tutorial contextual, enemigos de eco, pulso defensivo, historia, puzzle de runas, ascensor, guardián final, HUD, guardado local, banda sonora orquestal, voces y soporte de mando. **Fase 6, validada el 25 de septiembre de 2026:** cinemáticas, menú principal, nueva Luma, música, voces, memorias coleccionables, dificultad, islas mejoradas y mando. **Fase 7, 25 de septiembre de 2026:** Capítulo II · *La Señal Imposible*, con tres islas nuevas, la Constelación de Neri (árbol de habilidades), la Carta del archipiélago, un jefe, voces, música y efectos nuevos. Son dos capítulos jugables, todavía no una campaña terminada.

## Abrir

Abre `Abrir_demo.cmd`. El lanzador prepara los recursos nuevos (la primera vez tarda algo más porque importa la música y las voces) y abre el **menú principal**: Continuar, Nueva partida, Ver prólogo, Ajustes, Créditos y Salir. Para editarlo, abre `Abrir_editor.cmd` y selecciona `godot/project.godot`.

`Ver_prologo.cmd` permite volver a ver el cómic sin borrar tu partida (también desde el menú, "Ver prólogo"). Las versiones del proyecto comparten el guardado del mismo capítulo; usa Nueva partida solo cuando quieras reiniciarlo.

Esta es la carpeta principal para continuar las siguientes fases: `C:\Users\gcris\OneDrive\Documentos\Proyectos\Game\FragmentosDeLuz`. Las carpetas con nombres de fase son versiones anteriores, no la ubicación de trabajo actual. Los archivos que la fase 6 reemplazó están guardados en `respaldo_antes_fase6.zip`.

## Fase 7: Capítulo II · La Señal Imposible

Al terminar el Capítulo I, Luma siente que la luz del faro ha llegado más lejos que nunca: tres islas responden. El portal del faro abre la **Carta del archipiélago** y desde ahí se viaja entre islas. Las partidas anteriores se conservan: quien ya había completado el capítulo I recibe la llamada al cargar.

- **Carta del archipiélago**: mapa 3D en vivo sobre el mar de nubes con las cuatro islas unidas por hilos de luz. Muestra destellos, memorias y llaves de cada isla. Las islas se desbloquean en orden (Auralia → Grutas → Céfiro → Observatorio).
- **Grutas Prismáticas** · *La luz que se dobla*:
  - Emisores, prismas giratorios (`E`) y receptores de cristal abren puertas y levantan un puente de luz.
  - Los **Vigías** disparan orbes que el pulso deshace.
  - El Corazón Prismático necesita dos rayos a la vez para despertar la **Llave del Prisma**.
- **Picos del Céfiro** · *El viento que recuerda*:
  - Luma regala el **planeo**: mantén saltar en el aire.
  - Hay corrientes ascendentes, nubes de piedra que se desmoronan, nubes que flotan, un carrusel sobre el vacío y viento lateral.
  - Tres válvulas despiertan los molinos y la gran corriente que sube a la cumbre.
  - Los **Céfiros** marcan su embestida antes de lanzarse.
  - Aquí está la **Llave del Viento**.
- **Observatorio Estelar** · *La señal imposible*:
  - Puzle de la constelación «La Farolera»: pisa las estrellas en orden; un error la apaga.
  - Se cruza por los anillos giratorios del orrery.
  - Jefe final, el **Heraldo del Eclipse**. Enciende el pilar estelar que brilla para romper su escudo y purifica sus tres núcleos con el pulso. Cada fase es más rápida y añade un barrido de fuego.
  - Después aparece **Maren**, la última farolera, se alinea el telescopio con la **Llave de la Estrella** y llegan el final del Capítulo II y sus créditos.
- **Constelación de Neri** (`K`, cruceta arriba o desde la pausa y la carta): doce estrellas en tres ramas que se encienden con **destellos**. Cada isla esconde seis y también se ganan con ecos, memorias y llaves; las partidas antiguas reciben los que ya habían ganado.
  - **Luz**: Pulso amplio, Pulso veloz, Destello cegador y **Nova** (mantén `Q`).
  - **Viento**: Rodada ágil, Zancada, **Doble salto** y Planeo sereno.
  - **Corazón**: Vitalidad (130 de energía), Brasa interior, **Égida de luz** (absorbe un golpe) y **Brújula de destellos** (señala el destello más cercano).
  - Para encender una estrella, pulsa una vez para prepararla y otra para confirmar.
- **Escenarios nuevos**:
  - Cielos propios por isla (nocturno violeta, amanecer y noche estrellada) y mar de nubes animado.
  - Cristales facetados con brillo interior, rayos de luz, columnas de viento, alas de luz y suelo de constelaciones.
  - Dieciocho modelos nuevos hechos en Blender: prismas, emisores, molinos, válvulas, cúpula, telescopio, pilares, enemigos, jefe y Maren.
- **Cinemáticas nuevas**: llegada a cada isla, corazón prismático, molinos, constelación, aparición del Heraldo, Maren y el final del capítulo.
- **Sonido**:
  - Ocho pistas nuevas (carta, grutas y su versión profunda, céfiro y cumbre, observatorio, jefe y final). Todas giran alrededor del motivo de la Señal (Mi–Si–La–Mi).
  - Treinta efectos nuevos.
  - 48 líneas de voz nuevas: Luma, Neri, el cronista y la nueva voz de Maren.
- **Guardado v4**: guarda la isla actual, el refugio de cada isla, los destellos y las estrellas. Las partidas v1 a v3 se migran solas.
- **Ilustraciones con Gemini o ChatGPT** (opcional): el juego ya tiene huecos para un interludio y un epílogo en viñetas, postales de las islas, retratos de diálogo e iconos de habilidades. Si copias las imágenes en su carpeta aparecen solas, y si no, todo sigue igual. Los prompts listos para copiar están en `docs/PROMPTS_IA.md`.

## Fase 6: cinemáticas, sonido y presentación

- **Menú principal** con Auralia en vivo de fondo (cámara en órbita lenta, aves, cristales), logotipo en Cinzel Decorative y navegación con teclado, ratón o mando. Si terminaste el capítulo, el faro aparece encendido.
- **Cuatro cinemáticas en el motor**, con franjas panorámicas, títulos, subtítulos y voz. Se saltan manteniendo `E`, `Espacio`, `Esc` o `A`/`Start` del mando. Cada una se ve una vez por partida:
  1. *Llegada a Auralia*: vuelo sobre las islas y el faro hasta Neri.
  2. *El jardín despierta*: al resolver las runas, la barrera se disuelve de abajo arriba con un borde dorado.
  3. *Eco del Faro*: al entrar en la zona del faro, el guardián despierta y Luma explica cómo vencerlo.
  4. *Final*: los siete fragmentos suben desde el escáner, el faro se enciende, las islas lejanas responden con luces, Luma aparece junto a Neri y comienzan el epílogo y los créditos. Después puedes seguir explorando o volver al menú. Si cierras el juego a mitad del final, el portal lo vuelve a ofrecer.
- **Luma rediseñada** como el espíritu del cómic: visor oscuro con ojos luminosos, corona dorada con hoja, collar con gema, túnica con estela y aletas. Flota, parpadea, mira a Neri, saluda al acercarte y se anima al hablar.
- **Banda sonora nueva de seis pistas** (título, exploración, jardín, santuario, combate y final). El motivo de las runas OLA–SOL–ESTRELLA (La–Re–Fa#) suena en el jardín, en cada runa y en el final.
- **Voces**: Luma, Neri y un cronista narran el prólogo, los diálogos, las memorias y las cinemáticas. Tienen volumen propio ("Voces") y bajan la música mientras hablan.
- **Memorias de Auralia**: cinco ecos dorados escondidos en las zonas cuentan la historia de la ciudad. El diario lleva la cuenta (x / 5).
- **Dificultad**: *Relato* (mitad de daño) o *Aventura* (equilibrio original), en Ajustes.
- **Islas mejoradas**: acantilados pintados con estratos y vetas de cristal, raíces de cristal colgantes con brillo, enredaderas que se mecen y bandadas de aves.
- **Mando**: movimiento, cámara con el stick derecho y todas las acciones. El HUD cambia las indicaciones a los botones del mando cuando lo usas.
- **Ajustes** compartidos por el menú y la pausa: cinco volúmenes, calidad, dificultad, pantalla completa, sensibilidad de cámara e inversión vertical.
- **Tipografías** nuevas en todo el juego: Cinzel para títulos y Nunito para textos.

## Fase 5: el guardián del faro

Neri puede esquivar con `C`: consume 12 de energía, dura 0,5 segundos y tiene 1,4 segundos de recarga. Los primeros 0,3 segundos protegen del daño. Se inicia desde el suelo, respeta las paredes y usa una animación esquelética de rodada, sonido y una breve estela de polvo. Los diálogos interrumpen inmediatamente el desplazamiento.

El guardián final carga una onda circular con aviso previo. Sus ataques se aceleran al perder cada uno de sus tres núcleos. Puedes saltar la onda, sincronizar la esquiva, cubrirte tras un obstáculo sólido o interrumpir al guardián con `Q`. El HUD muestra su integridad y el estado de la recarga de esquiva. El tutorial introduce estas acciones antes del encuentro final.

El combate incorpora una capa musical adaptativa y cuatro efectos nuevos. Al completar el capítulo se enciende el faro con luz, halos animados y una señal musical; su estado restaurado reaparece al cargar una partida completada. Se corrigió también el bucle musical del prólogo y su advertencia de audio al cerrar la prueba.

Esta fase conserva la forma del personaje de fase 3: añade la rodada y su integración, no un nuevo esculpido de rostro o ropa.

## Fase 4: guardado fiable

El diario incluye Guardar partida y el estado del último guardado. Las escrituras se preparan en un archivo temporal antes de reemplazar la partida, y el guardado anterior válido se conserva en `fragmentos_save.json.bak`. Si el principal falta o está dañado se intenta recuperar esa copia. Las versiones de partida 1 y 2 se migran; una versión posterior a la admitida no se sobrescribe. Si guardar falla, el botón de salida muestra un aviso y mantiene el juego abierto.

La recuperación vuelve a un punto de control seguro. Una partida con energía agotada se reanuda con 60 de energía y una breve protección. Esto protege el progreso local, pero no sustituye un respaldo externo ni resuelve conflictos entre dos instancias abiertas simultáneamente.

## Controles

| Acción | Teclado y ratón | Mando |
|---|---|---|
| Mover | `WASD` | Stick izquierdo |
| Cámara | Botón derecho y arrastrar; rueda para la distancia | Stick derecho |
| Correr | `Shift` | `LB`, `L3` o gatillo izquierdo |
| Saltar (en el aire: doble salto con la estrella) | `Espacio` | `A` |
| Planear (tras recibirlo en el Céfiro) | Mantener `Espacio` en el aire | Mantener `A` en el aire |
| Hablar, leer, activar | `E` | `X` |
| Pulso de luz (mantener: Nova) | `Q` | `Y` o `RB` |
| Esquivar | `C` | `B` o gatillo derecho |
| Pausa | `Esc` | `Start` |
| Diario | `J` o `F2` | `Select` / `Back` |
| Constelación de Neri | `K` | Cruceta arriba |
| Saltar cinemática | Mantener `E`, `Espacio` o `Esc` | Mantener `A` o `Start` |

En los menús: flechas o stick y cruceta para moverte, `Enter`/`A` para aceptar y `Esc`/`B` para volver.

## Recorrido del capítulo

1. **Prólogo cómic**: cuatro viñetas narradas introducen Auralia, la fractura del faro, Neri y Luma. Después, la cinemática de llegada.
2. **Umbral de Auralia**: arco antiguo, Luma, tutorial de movimiento/pulso, dos fragmentos y el primer eco.
3. **Jardín de Resonancia**: tres resonadores, enemigos de eco y el orden correcto `OLA -> SOL -> ESTRELLA`. El cofre entrega el fragmento de la reliquia.
4. **Paso del Cielo**: ascensor, rampa elevada, plataforma de balcón, puente, dos fragmentos y presión de enemigos.
5. **Portal Final**: último fragmento y guardián con tres núcleos y ondas de resonancia. El faro requiere siete fragmentos, puzzle resuelto y guardián purificado; al completarlo empieza la cinemática final y se ilumina el santuario.

Opcional: cinco **Memorias de Auralia** (una en el Umbral, dos en el Jardín, una en el Paso del Cielo y una junto al faro).

La secuencia incorrecta reinicia el puzzle. Los fragmentos y la reliquia no se duplican. Hay guardado de progreso en `user://fragmentos_save.json` y guardado manual desde el diario. Los volúmenes y la calidad se conservan por separado en `user://preferences.cfg`. Las pruebas automáticas no modifican estas partidas ni preferencias.

## Sistemas incluidos

- Neri: humanoide Quaternius CC0 adaptado en Blender, 23.397 triángulos, 65 huesos con dedos y pies articulados, once clips derivados de Universal Animation Library, túnica, mochila y escáner. `CharacterBody3D`, `SpringArm3D` y `AnimationTree` para movimiento, cámara, pulso, esquiva y transiciones. El archivo editable es `blender/neri_quaternius.blend`.
- HUD: energía, contador 0/7, objetivo contextual, zona actual, tutorial, medidores de pulso y esquiva, integridad del guardián, amenaza cercana, prompt `[E]`, diálogos de Luma, pausa, diario, volumen y reinicio de partida.
- Enemigos: cinco ecos con patrulla, persecución limitada por suelo y obstáculos, aviso dorado antes de atacar, recuperación, aturdimiento real y purificación persistente. Puedes alejarte del ataque o interrumpirlo con Q. El daño tiene un breve periodo de protección y retrasa la regeneración; agotar la energía devuelve al punto de control. Los diálogos detienen los ataques.
- Mundo: cuatro zonas con nombres, geometría modular, árboles, cristales, columnas, puentes, plataformas y fragmentos coleccionables.
- Interacción: Luma, piedra de memoria, cinco Memorias de Auralia, resonadores, cofre de reliquia, palanca, ascensor y portal.
- Presentación: menú principal en vivo, prólogo de cuatro viñetas narrado, cuatro cinemáticas en tiempo real con créditos, iluminación cálida sobre piedra fría, acantilados pintados con raíces de cristal y enredaderas, aves, hierba y follaje con viento, estandartes, faroles, motas luminosas, engranajes, cristales flotantes, Luma como espíritu animado, ecos animados y portal animado. Pulso visible en el mundo y señal de daño en los bordes de pantalla.
- Audio: banda sonora orquestal de seis pistas (bucles sin cortes y final de dos minutos), música adaptativa por zona, capa de combate, pista propia para cada cinemática, voces con su propio bus, cascadas y portal con sonido espacial, viento, pasos, runas afinadas con el motivo del capítulo, encendido del faro, campanas de las islas, disolución de la barrera y sonidos de menú. La música baja durante diálogos y voces.
- Ajustes (menú y pausa): volumen general, música, ambiente, efectos y voces; calidad gráfica; dificultad; pantalla completa; sensibilidad e inversión de la cámara.

## Estructura

| Carpeta | Contenido |
|---|---|
| `blender/` | Archivos editables de Neri, Luma (`luma_spirit.blend`), entorno y métricas de producción y audio. |
| `godot/assets/` | GLB importados, texturas, cielo, interfaz y audio. |
| `godot/assets/audio/music/` | Banda sonora de la fase 6 (OGG). |
| `godot/assets/audio/voice/` | Voces de Luma, Neri y el cronista (OGG). |
| `godot/assets/fonts/` | Cinzel, Cinzel Decorative y Nunito con su licencia OFL. |
| `godot/assets/story/` | Imagen del prólogo cómic y, si las añades, viñetas y postales del capítulo II (`docs/PROMPTS_IA.md`). |
| `godot/scenes/levels/` | Islas del capítulo II: `grutas.tscn`, `cefiro.tscn`, `observatorio.tscn`. |
| `godot/scenes/archipelago_map.tscn` | Carta del archipiélago. |
| `docs/PROMPTS_IA.md` | Prompts para Gemini y ChatGPT: ilustraciones, iconos, tráiler y guiones. |
| `previews/levels/` | Capturas e informes de las pruebas de las islas, la carta y la constelación. |
| `godot/assets/enemies/` | GLB del eco enemigo. |
| `godot/scenes/` | Menú principal, prólogo, escena principal y cuatro zonas. |
| `godot/assets/characters/` | Neri (`player.tscn`) y Luma (`luma_spirit.glb`). |
| `godot/assets/ui/hud.tscn` | HUD, pausa, diálogo y diario (los ajustes se construyen en `scripts/settings_panel.gd`). |
| `godot/scripts/` | Estado global, jugador, interacciones, HUD, menú, cinemáticas, créditos, audio y ambientación. |
| `godot/shaders/` | Portal, faro, cascada, barrera que se disuelve, viento, estandartes, acantilados, enredaderas y borde de Luma. |
| `godot/tools/` | Constructor de mundo, pruebas automáticas y capturas de revisión. |
| `previews/adventure/` | Capturas del menú, las cinemáticas, las memorias y el recorrido, e informes de las pruebas. |
| `referencias/` | Imágenes y textos recibidos como dirección artística. |
| `source_tools/` | Generadores reproducibles de Blender, música, efectos y voces. Ver `DESARROLLO.md`. |
| `source_assets/quaternius/` | Cuerpo, cabello, animaciones y licencias CC0 usados para generar a Neri. |

## Verificación

**Fase 7:** las pruebas nuevas recorren cada isla entera con entradas reales: moverse, saltar, planear, interactuar y usar el pulso. Además prueban la Constelación, la Carta, las cinemáticas, el final del Capítulo II y los huecos de ilustraciones.

| Informe (`previews/levels/`) | Comprobaciones | Qué cubre |
|---|---|---|
| `grutas_report.json` | 56 | Prismas, receptores, puertas y puente de luz, plataformas, Vigías y sus orbes, doble salto, llave, portal y guardado |
| `cefiro_report.json` | 48 | Planeo, corrientes, nubes que caen y que se mueven, Céfiros, válvulas, carrusel, gran corriente, viento lateral y llave |
| `observatorio_report.json` | 45 | Constelación (con error y reinicio), puente de estrellas, orrery, jefe de tres fases, memoria de Maren y llave |
| `*_cinematics_report.json` | 13 + 13 + 26 | Cada cinemática de las tres islas y el final del Capítulo II con epílogo y créditos, con el control bloqueado hasta el final |
| `skills_report.json` | 39 | Compra con coste y requisito, efecto medido de cada habilidad (pulso, nova, doble salto, planeo, égida, brújula), retrato de diálogo y guardado |
| `map_report.json`, `art_report.json` | 11, 9 | Carta a 800, 1024 y 1280 px; interludio, postales e iconos con imágenes de ensayo |
| `previews/adventure/save_report.json` | 30 | Guardado v4 y migración desde v1 a v3 |

Las pruebas del Capítulo I siguen pasando: recorrido 57, cinemáticas 39, menú 14, memorias 28, mando 19, presentación 34, guardián 38, combate 22, avatar 30 y prólogo.

Una revisión independiente del código encontró seis problemas, y todos se corrigieron:

- El final del Capítulo II devolvía el control durante los créditos.
- El mando podía salir de la Constelación hacia botones ocultos.
- `Enter` en el interludio podía activar «Viajar».
- Cerrar el juego durante el final impedía volver a verlo.
- La llamada del capítulo II podía abrirse sobre el diario.
- La luz de la Nova quedaba encendida tras un golpe.

Las pruebas también destaparon otros problemas, ya corregidos:

- La niebla volumétrica por defecto de Godot cubría las islas de bruma.
- La escalinata y la rampa de la cúpula tenían escalones invisibles de 3 cm.
- Una columna de la cúpula tapaba la entrada.

**Fase 6:** las once pruebas automáticas pasan sin fallos, con 302 comprobaciones más la del prólogo:

| Informe (`previews/adventure/`) | Comprobaciones | Qué cubre |
|---|---|---|
| `qa_report.json` | 57 | Recorrido completo, ahora con el menú como escena de entrada |
| `cinematic_report.json` | 38 | Las cuatro cinemáticas, franjas, cámara, saltar, puerta que se disuelve, guardián, faro, islas, créditos y regreso al juego |
| `menu_report.json` | 14 | Fondo en vivo, logotipo, foco de teclado/mando, ajustes, créditos y ventana de 800 × 640 |
| `memories_report.json` | 28 | Las cinco memorias alcanzables, voz, diario y dificultad |
| `gamepad_report.json` | 19 | Asignaciones, sticks, botones, menús con A, diálogos con X y A sin reabrir ni saltar |
| `polish_report.json` | 34 | Presentación, Luma animada y bucles OGG |
| `guardian_report.json`, `combat_report.json`, `avatar_report.json` | 38, 22, 30 | Pruebas de fases anteriores, sin cambios de criterio |
| `prologue_report.json`, `save_report.json` | 1, 22 | Prólogo con narración y bucle de música; guardado |

Además, una revisión independiente del código encontró seis problemas (sobre todo con el mando) y todos se corrigieron antes de estas pruebas. Las capturas `menu_*`, `cine_*` y `memory_*` muestran el juego real. Las pruebas usan movimiento y colisiones reales, pero no sustituyen una partida larga jugada a mano.

La validación de fases anteriores recorre las cuatro zonas, comprueba la escena de entrada, el personaje importado, sus 65 huesos y estados de animación, el input de pulso, cinco enemigos, la purificación del eco tutorial, la recogida de los siete fragmentos, el puzzle, la bisagra del cofre, la palanca, el ascensor, las rampas, el guardián como requisito del portal, la pausa, el diario y la recuperación por caída. El informe queda en `previews/adventure/qa_report.json`: 57 comprobaciones superadas en esta fase.

`guardian_report.json` añade 38 comprobaciones de rodada, gasto y recarga, invulnerabilidad temporal, colisiones, salto y cobertura frente a ondas, interrupción, dificultad del guardián, HUD a 800 × 640, bloqueo de diálogos y restauración del faro. `avatar_report.json` comprueba ocho clips en movimiento, incluida la nueva rodada, y el diario estrecho. `prologue_report.json` confirma el cruce real del final del audio hacia el comienzo del bucle.

La prueba adicional de presentación comprueba movimiento visual, vegetación, animación esquelética, salto y aterrizaje, reproducción y bucles musicales, mezcla independiente, fuentes de sonido espacial y ajustes a 1440 × 900 y 800 × 640. Informe: `previews/adventure/polish_report.json`. Las capturas muestran el juego real. No constituyen un análisis de rendimiento prolongado ni validan todas las tarjetas gráficas.

`combat_report.json` cubre aviso, esquiva, interrupción, daño, invulnerabilidad, diálogos, punto de control, persistencia y HUD estrecho. `avatar_report.json` comprueba reproducción y movimiento de los clips importados. `prologue_report.json` comprueba las cuatro viñetas, sus textos y música en dos tamaños de ventana.

`save_report.json` comprueba 22 casos de escritura, recuperación, migración y datos dañados con archivos temporales aislados de tu partida. El diario con sus dos acciones se revisa también a 800 × 640.

## Fuentes y límites

Cuerpo y cabello: [Quaternius Universal Base Characters Standard](https://quaternius.com/packs/universalbasecharacters.html). Animaciones: [Quaternius Universal Animation Library Standard](https://quaternius.com/packs/universalanimationlibrary.html). Ambos son CC0; las licencias originales están en `source_assets/quaternius/`. La base gratuita utilizada es Superhero Male, ajustada de proporciones y vestida para Neri: tiene un aspecto más adulto que la ilustración de Miora. No es una reproducción exacta de esa referencia ni incluye expresiones faciales o apoyo de pies con IK.

Música de la fase 6: compuesta por procedimientos en MIDI e interpretada con el banco FluidR3 GM (licencia MIT); no es una grabación con músicos. Voces: síntesis de voz offline. Luma usa Coqui TTS (Tacotron2-DDC español, MPL 2.0, corpus M-AILABS) y Neri y el cronista usan Piper TTS (MIT) con la voz carlfm (dominio público). Suenan naturales en ritmo y entonación, pero no sustituyen a actores de doblaje. Tipografías Cinzel y Nunito: SIL Open Font License (`godot/assets/fonts/OFL.txt`). Higgsfield, Magnific y Krea no tenían créditos durante esta fase, así que ninguna imagen, vídeo o voz se generó con ellos. La música y las voces se pueden reemplazar conservando los nombres de archivo.

Aún quedan por desarrollar nuevos capítulos, mayor variedad de enemigos y una pasada artística manual de ropa y rostro de Neri.

La tubería usa Blender 5.2.1 LTS y Godot 4.7.2 Forward+. Godot importa escenas 3D en GLB/glTF y sus nodos de cámara, animación y cuerpos físicos se mantienen editables dentro del proyecto. Referencias: [formatos 3D e importación GLB](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html), [AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html), [AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html).

Las imágenes de Miora se conservaron como referencias de arte. El cielo, el prólogo comic, la textura de piedra y el marco del medidor se generaron como bitmaps auxiliares para que el capítulo tenga una lectura visual propia y consistente.
