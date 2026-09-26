# Fragmentos de Luz: base de produccion

## Carpeta de trabajo

Continuar todas las siguientes fases directamente en `C:\Users\gcris\OneDrive\Documentos\Proyectos\Game\FragmentosDeLuz`, por peticion del usuario. No trabajar en las entregas versionadas ni volver a copiar encima desde ellas: ahora son instantaneas anteriores. No modificar `SenalPerdida`.

Respaldo del contenido anterior a esta integracion: `C:\Users\gcris\Documents\Codex\Respaldos\FragmentosDeLuz_antes_fase3_20260915`. Incluye escenas, fuentes disponibles y configuracion, sin cache de Godot. Se conservo F2 para el diario y se anadio J como alternativa.

Respaldo previo a fase 5: `C:\Users\gcris\Documents\Codex\Respaldos\FragmentosDeLuz_antes_fase5_20260916`, sin cache de Godot. Implementacion iniciada el 16 y validada el 22 de septiembre de 2026, siempre en la carpeta principal.

Respaldo previo a fase 6: `respaldo_antes_fase6.zip` en la raiz del proyecto, con la version anterior de cada archivo que la fase 6 reemplazo.

Respaldo previo a fase 7: `respaldo_antes_fase7.zip` en la raiz, con la version anterior de cada archivo que la fase 7 modifico (los archivos nuevos no estan, porque no existian).

## Fase 7: Capitulo II · La Senal Imposible

Implementada el 25 de septiembre de 2026 en la carpeta principal. Tres islas nuevas, arbol de habilidades, carta del archipielago, jefe, guardado v4, musica, efectos, voces y huecos para ilustraciones externas.

### Arquitectura

- **Datos**
  - `scripts/level_data.gd`: fuente unica de las islas (orden, escenas, musica, llaves, refugios, zonas, enemigos, destellos, memorias y posicion en la carta). `requirement()` y `next_level()` definen el desbloqueo en cadena.
  - `scripts/skill_data.gd`: las 12 estrellas y el planeo de historia (`STORY_SKILLS`).
- **Estado**: `scripts/adventure_state.gd` (autoload `GameEvents`) incorpora:
  - `level`, `levels` (refugio, flags y `done` por isla), `destellos`, `destello_ids` y `skills`.
  - `award()`, idempotente por fuente, y `sync_awards()`, que da destellos retroactivos a partidas antiguas.
  - Los multiplicadores de cada habilidad (`pulse_radius()`, `dodge_cost()`...) y la egida (`shield_ready`/`shield_timer`).
  - `travel_to(id)` y `snapshot()`, que usan el guardado y las pruebas.
- **Guardado v4**: `scripts/save_store.gd`. Valida ids de enemigos, destellos y estrellas, limita valores y hace que una isla bloqueada vuelva a Auralia. `tools/qa_save_store.gd` cubre la migracion.
- **Islas**
  - `scripts/level_controller.gd` es la base comun: refugios, HUD, director, calidad, historias en cadena (`say_story`), `play_when_free`, `theme_for_zone()` y `audio_spots()` para `audio_manager.gd`.
  - Cada isla la extiende: `level_grutas.gd`, `level_cefiro.gd` y `level_observatorio.gd`.
- **Mecanismos**, en `scripts/`:
  - Luz: `beam_emitter`, `prism`, `beam_receptor` y `crystal_door`, que sirve tambien para puentes.
  - Plataformas: `mover`, `crumble_platform`, `carousel` (carrusel y anillos del orrery), `wind_zone` (corrientes y viento lateral, con `wind_zones` en el jugador), `valve` y `windmill_spin`.
  - Observatorio y cierre de isla: `star_tile`, `star_pillar`, `key_altar`, `level_gate`, `level_checkpoint`, `destello` y `luma_npc`.
- **Enemigos**
  - `enemy_vigia.gd` dispara orbes (`light_orb.gd`) que el pulso deshace.
  - `enemy_cefiro.gd` marca su linea antes de embestir.
  - `boss_heraldo.gd` es el jefe de tres fases. Un pilar cargado lo expone 6,5 s; un pulso a menos de radio+1,3 m rompe un nucleo; cada fase es mas rapida y anade un barrido de fuego. Si nadie le da `arena_center`, usa la isla que lo contiene.
- **Estilo**
  - `scripts/crystal_style.gd` sustituye en tiempo de ejecucion los materiales de los `.glb` por shaders: cristal, roca y eco.
  - Shaders nuevos: `crystal`, `light_beam`, `ghost`, `cloud_sea`, `sky_islands` (con via barata para el cubemap), `star_floor`, `eclipse_shield`, `light_wing`, `wind_column` y `starfield_ui`.
- **Interfaz**
  - `scripts/constellation_panel.gd`: arbol con leyenda de ramas; primera pulsacion prepara y la segunda enciende.
  - `scripts/archipelago_map.gd` (`scenes/archipelago_map.tscn`): carta 3D con panel de isla, constelacion y viaje.
  - `adventure_hud.gd` anade saldo de destellos, egida, brujula y retratos de dialogo.
- **Ilustraciones externas** (Gemini o ChatGPT)
  - `scripts/story_art.gd` busca imagenes opcionales y `scripts/comic_overlay.gd` muestra viñetas.
  - Rutas, formatos y prompts: `docs/PROMPTS_IA.md`.
  - Si una imagen no existe no pasa nada.
  - Una imagen recien copiada funciona antes de importarla, porque se carga del disco.
  - Donde aparecen:
    - Interludio: la primera vez que se abre la carta.
    - Epilogo: antes de los creditos del capitulo II.
    - Postales: en la carta.
    - Retratos: en el cuadro de dialogo.
    - Iconos: en la ficha de cada estrella.
- **Cinematicas**: el director admite `register(id, callable)` y cada isla registra las suyas. En el Observatorio, las esperas usan la duracion real de la voz (`say()` devuelve la duracion) para no cortar a Maren.

### Construccion de las islas

Las escenas `scenes/levels/*.tscn` se generan; no se editan a mano. Primero se exportan los modelos y despues se construyen las escenas:

```powershell
python .\source_tools\build_chapter2_assets.py            # modulo bpy; o: blender --background --python ... -- observatory_dome
godot --headless --path .\godot --import
godot --headless --path .\godot --script res://tools/build_levels.gd -- grutas cefiro observatorio
godot --path .\godot --script res://tools/preview_level.gd -- res://scenes/levels/cefiro.tscn prefijo teal "x,y,z,mx,my,mz[,fov]"
```

- `tools/level_kit.gd` agrupa las piezas comunes: islas, rampas (`walkway`), escaleras, nubes, viento, enemigos (con aserto contra `LevelData`), altares, refugios, entorno y mar de nubes.
- Las rampas deben terminar exactamente en el borde del suelo, que esta a -0,02 m: un escalon de 3 cm ya frena a Neri al subir.
- `tools/probe_floor.gd` lanza rayos para revisar estas uniones.
- La niebla volumetrica solo se activa si `kit.environment` la configuro (clave `volumetric`). `level_controller.apply_quality` la encendia siempre y usaba la densidad por defecto de Godot (0,05), que cubria las islas de bruma; `--qa-part=haze` del Cefiro captura la vista quitando capas para localizar problemas asi.
- `tools/qa_adventure.gd` se actualizo: tras los creditos del capitulo I, Luma hace la llamada del capitulo II antes de devolver el control.

### Audio de la fase 7

```powershell
python .\source_tools\build_music_chapter2.py        # map grutas grutas_deep cefiro cefiro_summit observatorio boss finale2
python .\source_tools\build_sfx_chapter2.py          # 29 efectos + updraft (bucle sin costura)
$env:FDL_PIPER="ruta\a\piper"; python .\source_tools\build_voices.py vo_maren_1 vo_ch2_call ...
```

- El leitmotiv de la Senal (Mi5-Si5-La5-Mi5) une la moneda, las estrellas, la constelacion, la llave y la musica.
- Maren usa la voz de Coqui 2,5 semitonos mas grave, con un eco una octava por debajo y sala amplia.
- `coqui_synth.py --batch lista.json` carga el modelo una sola vez.
- `build_voices.py` fija `HF_HUB_OFFLINE`, porque sin ello Coqui se quedaba esperando a la red.

### Pruebas de la fase 7

```powershell
godot --path .\godot res://scenes/levels/grutas.tscn -- --qa                 # grutas_report.json
godot --path .\godot res://scenes/levels/cefiro.tscn -- --qa                 # cefiro_report.json (--qa-part=mills: solo el tramo final)
godot --path .\godot res://scenes/levels/observatorio.tscn -- --qa           # observatorio_report.json (--qa-part=garden | dome)
godot --path .\godot res://scenes/levels/observatorio.tscn -- --qa --qa-cinematics --qa-part=cinematics   # cinematicas + final (tambien grutas y cefiro)
godot --path .\godot res://scenes/levels/grutas.tscn -- --qa --qa-skills     # skills_report.json
godot --path .\godot res://scenes/archipelago_map.tscn -- --qa --qa-map      # map_report.json
godot --path .\godot res://scenes/archipelago_map.tscn -- --qa --qa-art      # art_report.json (imagenes de ensayo en user://)
godot --headless --path .\godot --script res://tools/qa_save_store.gd
```

- Las pruebas de islas usan entradas reales: movimiento, saltos, planeo, interaccion y pulso. Recorren cada isla entera, resuelven sus mecanismos, recogen los seis destellos, vencen a los enemigos y al jefe, y cogen la llave.
- Si algo bloquea a Neri, el registro muestra `BLOCKED_AT` con la colision, la velocidad y el estado de entrada.
- Informes y capturas: `previews/levels/`.

## Fase 6: cinematicas, sonido y presentacion

Implementada y validada el 25 de septiembre de 2026 en la carpeta principal.

### Herramientas usadas

- Godot 4.7.2 (misma version del proyecto) para importar, construir y ejecutar todas las pruebas, con renderizado Vulkan por software para las capturas.
- Blender 5.0.1 como modulo de Python (`bpy`) para `build_luma_spirit.py`; el script tambien funciona con `blender --background --python` en Windows.
- Musica y efectos: MIDI escrito con `mido`, interpretado con FluidSynth y el banco General MIDI FluidR3 (licencia MIT), mezcla con Pedalboard y normalizacion con pyloudnorm. Salida OGG Vorbis.
- Voces: Coqui TTS 0.27 con el modelo Tacotron2-DDC espanol (M-AILABS, voz femenina) para Luma; Piper 1.8 con la voz `carlfm` (dominio publico) para Neri y el cronista. El modelo Piper `mls_10246` se descarto porque repetia y alargaba frases.
- Higgsfield, Magnific y Krea no tenian creditos, asi que no se genero ninguna imagen, video ni voz con ellos. Si se recargan, basta con sustituir los archivos manteniendo sus nombres (`assets/audio/music/*.ogg`, `assets/audio/voice/*.ogg`).

### Arquitectura

- `scenes/title_menu.tscn` + `scripts/title_menu.gd`: escena de entrada. Instancia `main_island.tscn`, quita el script raiz, el HUD y el audio, y la usa como fondo en vivo con camara en orbita. Con `--qa`, `--qa-prologue`, `--skip-prologue` o `--replay-prologue` pasa directamente al prologo, que a su vez decide si entra al juego. `--qa-menu` ejecuta su prueba.
- `scripts/cinematic_director.gd`: nodo `CinematicDirector` creado por `adventure.gd`. Camara propia, trayectorias Catmull-Rom (`path`, `shot`, `orbit`), franjas, titulos, subtitulos con voz (`say`) y fundidos. `play(id)` bloquea al jugador, oculta el HUD, activa `GameEvents.cinematic_active` y al terminar devuelve la camara con una mezcla de 1 s. Mantener E, Espacio, Esc o A/Start durante 0,75 s llama a `skip()`, que completa las tweens pendientes para que sus efectos se apliquen. Cada secuencia guarda `story_seen["cine_<id>"]`. Esta desactivado con `--qa` salvo con `--qa-cinematics`.
- Disparadores en `adventure.gd`: llegada (primera partida, antes del dialogo de Neri), jardin (`activate_rune` al resolver; la puerta queda sin colision al instante y se disuelve con `dissolve_gate`), guardian (al entrar en la zona 3 con el guardian vivo, esperando a que no haya dialogos) y final (`start_finale`, llamado por el portal). `finish_finale` devuelve el control o carga el menu. Si el juego se cierra durante el final, el portal lo vuelve a ofrecer (`cine_finale` aun no esta marcado).
- `scripts/credits_roll.gd` y `scripts/credits_data.gd`: creditos desplazables. Edita `credits_data.gd` para cambiar el nombre del estudio o los textos.
- `scripts/beacon_restoration.gd`: espera al director si hay una cinematica activa y enciende tambien las islas lejanas (luz, chispa y rayo por isla).
- `scripts/audio_manager.gd`: musica de zona (exploracion, jardin, santuario) desde `assets/audio/music/*.ogg` con respaldo a los WAV antiguos, capa de combate, pista de cinematica (`set_cinematic_music` / `clear_cinematic_music`), voz en el bus `Voice` (`play_voice`, `stop_voice`) que baja la musica, y nuevos efectos. Las runas piden `rune_0..2` (La, Re, Fa#).
- `scripts/luma_spirit.gd`: animacion procedural de `luma_spirit.glb` (flotacion, aletas, hoja, parpadeo, mirada, saludo y gestos al hablar) y borde luminoso `shaders/spirit_rim.gdshader`.
- `scripts/island_dressing.gd` (nodo `Dressing` de cada zona, `@tool`): raices de cristal, cristal-ancla, enredaderas (`shaders/vine.gdshader`) y material de acantilado (`shaders/cliff.gdshader`) para la roca de la zona. Lo generado no se guarda en las escenas (no activar "Editable Children" en `IslandCliff`, o el material se guardaria).
- `scripts/ambient_life.gd` (nodo `AmbientLife` de `main_island.tscn`): bandadas de aves y material de acantilado para las islas lejanas.
- `scripts/memory_orb.gd`: visual de las cinco Memorias de Auralia (`EchoMemory_1..5`, `interactable.gd` con `kind = "memory"` e `item_id = "lore_N"`). Se guardan en `story_seen`, por lo que el formato de guardado v3 no cambia. `GameEvents.lore_count()` y `LORE_TITLES` alimentan el diario.
- `scripts/settings_panel.gd`: ajustes compartidos. `Preferences` guarda ahora el volumen `Voice`, pantalla completa, sensibilidad e inversion de camara y dificultad (`gameplay/difficulty`: 0 Relato, mitad de dano en `GameEvents.damage_player`; 1 Aventura).
- `scripts/ui_theme.gd`: fuentes Cinzel y Nunito (`assets/fonts`, OFL) y estilos comunes.
- Mando: acciones con eventos de mando en `project.godot`, acciones nuevas `camera_left/right/up/down`, `ui_accept` con A y `ui_cancel` con B. El HUD cambia las indicaciones E/Q/C por X/Y/B cuando detecta un mando. `player_controller.gd` usa `interaction_lock` para que la pulsacion que cierra un dialogo no lo vuelva a abrir ni haga saltar.
- `tools/build_world.gd` incluye todo lo anterior (Luma, `Dressing`, `AmbientLife`, memorias), de modo que regenerar el mundo conserva la fase 6. Se comprobo regenerando en una copia y pasando la prueba del recorrido.
- Herramientas de revision: `tools/preview_model.gd` (modelo aislado) y `tools/preview_world.gd` (camara libre sobre el mundo) guardan una captura PNG.

### Regenerar los assets de la fase 6

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python .\source_tools\build_luma_spirit.py
# Requiere fluidsynth y FluidR3_GM.sf2 (define FDL_SOUNDFONT con su ruta), ademas de: pip install mido pedalboard soundfile pyloudnorm numpy scipy
python .\source_tools\build_music.py            # o solo algunas: python .\source_tools\build_music.py title finale
python .\source_tools\build_sfx_phase6.py
# Voces: FDL_PIPER (ejecutable piper), FDL_VOICES (carpeta con voice-es-carlfm-x-low), FDL_COQUI_PYTHON y FDL_COQUI_MODELS
python .\source_tools\build_voices.py            # o ids concretos: vo_luma_intro vo_cine_finale_4
python .\source_tools\analyze_audio.py .\godot\assets\audio\music\title.ogg 76 4   # sonoridad, costura del bucle y armonia por compas
```

La musica se normaliza a -27 LUFS (combate -26), las voces a -19 LUFS y los bucles se cortan del segundo ciclo de una interpretacion triple para incluir la cola de reverberacion, con un fundido de 60 ms en la costura. Los `.ogg.import` de las pistas en bucle tienen `loop=true` y sus `bpm`/`beat_count`; el final no hace bucle.

Descargas de modelos de voz (GitHub): `rhasspy/piper` release `v0.0.2`, archivo `voice-es-carlfm-x-low.tar.gz`; `coqui-ai/TTS` release `v0.6.1_models`, archivos `tts_models--es--mai--tacotron2-DDC.zip` y `vocoder_models--universal--libri-tts--fullband-melgan.zip`. Los modelos no se incluyen en el proyecto por su tamano.

### Pruebas de la fase 6

```powershell
godot --path .\godot -- --qa-menu                     # menu_report.json
godot --path .\godot -- --qa --qa-cinematics          # cinematic_report.json (necesita ventana; tarda unos 6 min)
godot --path .\godot -- --qa --qa-memories            # memories_report.json
godot --headless --path .\godot -- --qa --qa-gamepad  # gamepad_report.json
```

Las pruebas anteriores (`--qa`, `--qa-polish`, `--qa-combat`, `--qa-guardian`, `--qa-avatar`, `--qa-prologue`, `qa_save_store.gd`) se mantienen; se actualizaron tres comprobaciones: la escena de entrada ahora es el menu, la animacion de Luma se mide en su nodo `Luma_Float` y los bucles de musica aceptan OGG. La prueba de cinematicas no debe ejecutarse con `--headless`: la ventana de 64 x 64 deja los creditos sin ancho.

Una revision independiente del codigo encontro y se corrigio: A/B del mando no activaban botones (faltaban en `ui_accept`/`ui_cancel`), cerrar un dialogo con X lo reabria y con A hacia saltar, mantener pulsado para saltar el final saltaba tambien los creditos, el menu aceptaba clics durante su fundido, el sonido de la barrera sonaba al saltar la cinematica, y volver al menu no avisaba si fallaba el guardado.

## Fase 5: esquiva y guardian

- `player_controller.gd`: accion C, rodada de 0,5 s, coste 12, recarga 1,4 s y proteccion inicial de 0,3 s. Usa `move_and_slide`, no teletransporte. Solo se inicia en suelo; bloquea salto, pulso e interaccion durante la rodada. El bloqueo de dialogo cancela la esquiva y la velocidad horizontal.
- `guardian_sentinel.gd`: especializa el enemigo existente solo para `BeaconEcho`. Avisos de 1,35 / 1,15 / 0,95 s segun integridad; tres nucleos, ondas progresivamente mas rapidas, interrupcion por pulso y purificacion persistente.
- `resonance_wave.gd`: frente anular barrido entre frames, un impacto por onda, exclusion por altura y rayo contra cobertura solida. Permite saltar o atravesar el frente durante la proteccion de una esquiva. Los dialogos cancelan ondas activas.
- `adventure_state.gd`: senales `dodge_started`, `dodge_changed` y `guardian_changed`. No cambia el formato de guardado v3.
- `adventure_hud.gd`: medidor de esquiva y tres marcas de integridad del guardian. El HUD de combate se oculta durante modales y se recoloca a 800 x 640.
- `combat_feedback.gd`: polvo temporal con desvanecimiento durante la rodada; conserva los efectos del pulso.
- `beacon_restoration.gd` y `beacon.gdshader`: columna de luz, halos y aumento de luz ambiental al completar el capitulo. El nodo se crea desde `adventure.gd` y restaura el aspecto inmediatamente al cargar una partida completada.
- `audio_manager.gd`: mezcla gradual de `combat_tension.wav` segun amenaza, con atenuacion durante dialogos. Nuevos efectos `dodge`, `guardian_charge`, `guardian_wave` y `beacon_chime`.

El modelo se regenero con un undecimo clip, `dodge`, derivado de `Roll` de UAL Standard y retimado a 15 frames a 30 fps. La geometria conserva 23.397 triangulos y 65 huesos; no se hizo un nuevo modelado de rostro o ropa en esta fase.

Validacion dedicada: `godot --path .\godot -- --qa --qa-guardian`. El informe exige llegar a la ultima asercion para evitar resultados positivos tras una corrutina interrumpida por error. Supera 38 comprobaciones, incluidas colision de la rodada, salto, cobertura, esquiva sincronizada, cancelacion por dialogo, HUD estrecho y faro restaurado. El recorrido completo mantiene sus 57 comprobaciones superadas. Los fixtures trasladan temporalmente al guardian al umbral para aislar las pruebas; en el juego sigue situado en PortalFinal.

## Fase 4: progreso fiable

`scripts/save_store.gd` encapsula validacion, migracion y escritura temporal con reemplazo final. Solo una partida anterior valida se rota a `.bak`. Se recupera desde esa copia si el archivo principal falta o es invalido, y se impide sobrescribir versiones futuras. `GameEvents.save_game()` devuelve resultado y emite estado; el diario permite guardado manual. Salir desde pausa no cierra el juego si guardar falla.

Los identificadores del capitulo y puntos de control se validan expresamente. Al agregar capitulos, ampliar esa tabla o sustituirla por datos de cada nivel con una migracion versionada. El almacenamiento actual no es un sistema de sincronizacion entre procesos: evitar ejecutar dos versiones contra la misma partida a la vez. OneDrive contiene el proyecto, pero Godot guarda la partida en AppData local.

Prueba aislada: `godot --headless --path .\godot --script res://tools/qa_save_store.gd -- --qa`. Cubre 22 casos, incluyendo archivos incompletos, respaldo recuperable, versiones antiguas/futuras, tipos incorrectos y destino no escribible. No modifica la partida real.

Resuelto en fase 5: el prologo utiliza el recurso de audio importado sin duplicarlo en ejecucion y configura `edit/loop_mode=2` (Forward) en su `.wav.import`. La prueba comprueba reproduccion al cruzar el limite final del archivo, ademas de las cuatro vinetas a 1440 x 900 y 800 x 640. El cierre final validado no presenta las anteriores referencias de audio no liberadas.

## Alcance del pulido

Fase 3, 2026-09-15. Esta entrega conserva el primer capitulo de cuatro zonas e integra un cuerpo humanoide externo CC0, diez clips retargeteados, combate con aviso/interrupcion y un prologo que presenta cada vineta por separado con movimiento y musica. Corrige enemigos inactivos por el orden de carga, aturdimiento, dano acumulado, regeneracion inmediata, repeticion de guardados del tutorial y continuidad de dialogos. Conserva follaje, audio sintetizado, mecanismos, HUD y contenido de las fases anteriores. No incluye voces grabadas, nuevos capitulos, combate avanzado con combos ni animacion facial.

Neri usa Superhero Male y Hair SimpleParted del paquete gratuito Quaternius Universal Base Characters Standard. Se ajustaron proporciones, materiales, ropa y accesorios en Blender, conservando 65 huesos. La salida contiene una malla, diez superficies de material y 23.397 triangulos. Se eliminaron caras ocultas bajo la ropa y se recalcularon normales; las prendas usan una sola superficie para evitar capas casi coincidentes. Los bordes de mangas se recortan por planos y el faldon tiene pesos de muslo/pelvis. Es una interpretacion mas adulta que la hoja de Miora. La siguiente pasada artistica puede centrarse en ropa hecha a medida, rostro, expresiones y apoyo de pies con IK.

## Nodos principales

- `GameEvents`: autoload de `scripts/adventure_state.gd`, progreso, objetivos, senales y guardado.
- `Preferences`: autoload con buses de volumen, calidad y persistencia independiente.
- `PrologueComic`: escena inicial `scenes/prologue_comic.tscn`; muestra el comic 2D y luego cambia a `main_island.tscn`.
- `Player`: `CharacterBody3D`, colision, modelo GLB con `Skeleton3D` y `AnimationPlayer`, `AnimationTree`, pivote de camara, `SpringArm3D` y pulso defensivo con `Q`.
- `EnemySentinel`: `Area3D` con estados de patrulla, persecucion, aviso, recuperacion y aturdimiento. Busca al jugador despues de la carga y comprueba suelo, obstaculos, altura y linea de vision. Los identificadores de purificacion quedan en el guardado v3. Las partidas anteriores se pueden leer, aunque no contienen esos identificadores individuales.
- `BeaconEcho`: utiliza `guardian_sentinel.gd`; crea `ResonanceWave` durante su ataque. El resto de ecos mantiene su comportamiento de corta distancia.
- `BeaconRestoration`: nodo de la escena principal, con `BeaconColumn`, `RestoredLight` y dos halos animados.
- `CombatFeedback`: anillos y luz de pulso temporales. El HUD usa `damage_edge.gdshader` para mostrar dano sin tapar el centro.
- `Zones`: Entrance, Puzzle, Elevated y PortalFinal. Cada zona conserva su escena editable.
- `EnvironmentLife`: aplica materiales animados a las superficies importadas, configura la calidad y anima detalles ambientales.
- `AudioManager`: tres reproductores musicales sincronizados, viento, voces de efectos y `AudioStreamPlayer3D` para cascadas y portal.
- HUD: `CanvasLayer` con `TextureProgressBar`, contador, objetivo, tutorial, pulso, amenaza, interaccion, dialogos, diario, pausa y ajustes.

## Regenerar sin perder trabajo

Los archivos `.blend`, `.glb`, `.tscn`, shaders y scripts se entregan editables. Antes de ejecutar generadores, guarda una copia: regeneran recursos con nombres existentes. Los cambios manuales de las escenas generadas no se conservan automaticamente. Para ampliar niveles sin ese riesgo, crea escenas adicionales e instancialas desde una escena propia, o incorpora el cambio al generador de forma deliberada.

Desde la raiz de esta carpeta, usando Blender 5.2.1 y Godot 4.7.2:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python .\source_tools\build_adventure_assets.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python .\source_tools\build_neri_quaternius.py
& 'C:\Users\gcris\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' .\source_tools\build_audio.py
& 'C:\Users\gcris\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' .\source_tools\build_audio_polish.py
& 'C:\Users\gcris\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' .\source_tools\build_combat_audio.py
# Con el ejecutable de Godot disponible como godot:
godot --headless --editor --path .\godot --import --quit
godot --headless --path .\godot --script res://tools/build_world.gd
godot --path .\godot -- --qa
godot --path .\godot -- --qa --qa-polish
godot --path .\godot -- --qa --qa-combat
godot --path .\godot -- --qa --qa-guardian
godot --path .\godot -- --qa --qa-avatar
godot --path .\godot -- --qa --qa-prologue
godot --headless --path .\godot --script res://tools/qa_save_store.gd -- --qa
```

El generador de Neri lee `source_assets/quaternius/`, sin necesitar red, y produce `blender/neri_quaternius.blend`, sus metricas y `godot/assets/characters/neri_quaternius.glb`. Si solo editas a Neri no hace falta reconstruir el entorno ni el audio. El antiguo `adventurer.glb` se conserva porque Luma aun lo utiliza como holograma. El generador de audio original debe ejecutarse antes del de pulido. Las pruebas visuales necesitan una ventana grafica; no usar `--headless` con ellas. Las pruebas usan entradas de movimiento y colisiones reales, pero no sustituyen sesiones manuales largas. Los archivos de informe indican cada comprobacion y cualquier fallo.

Los clips idle, walk, run, jump, fall, land, interact, wave, pulse, hurt y dodge se derivan de UAL Standard. El nombre interno wave corresponde a Idle_Talking_Loop, un gesto conversacional, no a un saludo de mano. Se omite desplazamiento global del esqueleto para que CharacterBody3D controle el movimiento y se ajusta la duracion de las acciones a los tiempos del controlador.

`build_combat_audio.py` sintetiza cinco WAV originales con NumPy y semilla reproducible: esquiva (0,5 s), carga (1,35 s), onda (1,1 s), faro (4 s) y tension (16 s en bucle). Escribe metricas en `blender/combat_audio_metrics.json`. Los efectos no necesitan fuentes externas ni claves de servicios.

El prologo se puede repetir con `Ver_prologo.cmd` o `godot --path .\godot -- --replay-prologue`. No borra la partida.

## Datos locales y rendimiento

Partida: `user://fragmentos_save.json`. Preferencias: `user://preferences.cfg`. En Windows, Godot guarda estos datos bajo `%APPDATA%\Godot\app_userdata\Fragmentos de Luz - El Faro Dormido`. Los modos de prueba omiten la persistencia del usuario.

Calidad baja reduce resolucion 3D, particulas y sombras; los otros perfiles permiten priorizar detalle. El capitulo se verifico en Windows con renderizado Forward+ y la GPU disponible, no en dispositivos moviles. El contador de FPS al final de un informe es una muestra puntual, no una garantia de rendimiento.

Antes de ampliar el mapa: medir llamadas de dibujo y tiempos de GPU durante un recorrido prolongado, consolidar superficies estaticas, definir presupuesto por zona y probar guardado y carga entre futuros capitulos. Mantener las interfaces actuales de senales evita acoplar el HUD a cada nivel.

## Registro de bitmaps de fases anteriores

Herramienta: skill `imagegen` con el generador integrado.

Assets conservados:

- `godot/assets/environment/stone_painted.png`: textura raster de piedra usada en el nivel. Archivo original de la sesion anterior: `C:\Users\gcris\.codex\generated_images\01a098f8-db8d-7530-8fff-23531933a26f\exec-1df7ac17-756f-4042-8a48-9164d5c8ee84.png`.
- `godot/assets/story/prologue_comic.png`: comic 2D de cuatro vinetas para el arranque. Archivo original de esta sesion: `C:\Users\gcris\.codex\generated_images\01a098f8-db8d-7530-8fff-23531933a26f\call_I36zGvMUQvFdCTGxu2C9CiZN.png`.

Prompt enviado:

> Use case: stylized-concept. Asset type: seamless square albedo texture for a 3D fantasy adventure's ancient stone pathways. Orthographic top-down surface fills every pixel, no perspective, no border. A continuous fine-grained cool grey-green weathered limestone surface, hand-painted animation-film style with broad subtle painterly tonal variation, occasional small angular cracks, very sparse moss along cracks. No separate paving blocks, no grid, no deep black gaps, no repeated symbols, no text. Medium-dark stone with restrained teal moss, low contrast, no directional lighting or cast shadows, no photo realism, no fine noisy grain. Seamlessly tileable horizontally and vertically. Texture only, no rendered object. Square bitmap.

Se inspecciono el resultado aplicado al pavimento dentro de Godot. El arte recibido de Miora permanece como referencia; no son modelos 3D importables por si solos. Los generadores locales producen los props y el audio, y adaptan el cuerpo externo de Neri.

Prompt del prologo:

> Use case: illustration-story. Asset type: 2D prologue comic splash for a Godot fantasy adventure game. Primary request: a four-panel horizontal comic page introducing Fragmentos de Luz, with no written text inside the image. Scene/backdrop: floating ancient island city above clouds, broken lighthouse beacon, teal energy crystals, golden dusk, purple storm haze. Subject: Panel 1 shows Auralia floating peacefully with a bright lighthouse; Panel 2 shows the beacon shattering into seven golden fragments; Panel 3 shows young adventurer Neri with short brown hair, blue tunic, small green canvas backpack, wrist crystal scanner, discovering a signal map; Panel 4 shows Neri arriving through an ancient stone arch as a small teal holographic guide waits. Style/medium: polished 2D comic illustration, stylized fantasy adventure, clean readable silhouettes, soft painterly shading, consistent teal-gold-purple palette. Composition/framing: 16:9 landscape page divided into four cinematic comic panels with clear gutters, each panel readable at game intro size. Lighting/mood: hopeful but mysterious, dramatic volumetric sky light, glowing teal crystals, warm gold highlights. Color palette: teal, antique gold, indigo, soft purple storm clouds, cool stone. Constraints: no text, no logos, no watermark, no speech bubbles, no UI elements; Neri must match the existing reference concept: short tunic, slim trousers, ankle boots, small backpack, wrist scanner.

## Assets externos revisados

Se verifico el paquete KayKit Character Pack: Adventurers desde la libreria de Godot/GitHub. Tiene licencia CC0, personajes riggeados y muchas animaciones, pero su estetica sigue siendo low-poly por piezas; por eso no se sustituyo a Neri en esta fase. Queda descargado para inspeccion local en `C:\Users\gcris\Documents\Codex\kaykit_adventurers_inspect_20260914`.

En fase 3 se incorporaron [Universal Base Characters Standard](https://quaternius.com/packs/universalbasecharacters.html) y [Universal Animation Library Standard](https://quaternius.com/packs/universalanimationlibrary.html), ambos de Quaternius con licencia CC0. Las fuentes utilizadas y las licencias originales estan incluidas en `source_assets/quaternius/`. No se usaron los cuerpos regular/teen de paquetes de pago ni assets sin licencia verificada.

## Documentacion de referencia

La configuracion ambiental y los efectos se apoyan en la [documentacion de entorno y posprocesado de Godot](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html). Las fuentes locales usan [AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html) para la atenuacion espacial. Estos enlaces describen las funciones del motor, no certifican la calidad artistica ni el rendimiento de este proyecto.

Se ajustaron SSAO, distancia de sombras y sesgo del sol; se usa profundidad de sombras de 32 bits y filtrado medio para reducir ruido en ropa y accesorios. Referencia: [luces y sombras](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html). La calidad baja sigue desactivando sombras. Las capturas de control se realizaron con sombras activadas; los argumentos internos de diagnostico `--qa-no-shadows`, `--qa-no-sun-shadow` y `--qa-no-ssao` no forman parte del arranque normal.
