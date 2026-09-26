extends Node
## Mezcla adaptativa del capítulo.
## Fase 6: banda sonora orquestal (OGG en assets/audio/music), pista de cinemática que se funde sobre
## la música de zona, voces en su propio bus con atenuación de música y nuevos efectos.

const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://assets/audio/voice/"
const ZONE_THEMES := ["exploration", "garden", "sanctuary"]
const LEGACY_THEMES := {"exploration": "music_exploration", "garden": "music_garden", "sanctuary": "music_sanctuary",
	"combat": "combat_tension", "title": "music_sanctuary", "finale": "music_sanctuary"}
const CUES := ["step", "jump", "pickup", "rune", "wrong", "solved", "lever", "chest", "portal", "story", "respawn", "land",
	"pulse", "hit", "enemy_hit", "enemy_alert", "step_0", "step_1", "step_2", "step_3", "dodge", "guardian_charge",
	"guardian_wave", "beacon_chime", "rune_0", "rune_1", "rune_2", "fragment_rise", "beacon_ignite", "island_chime",
	"gate_dissolve", "ui_move", "ui_select", "ui_back", "cine_whoosh",
	# Fase 7
	"destello", "skill_unlock", "double_jump", "glide", "nova", "shield_block", "shield_ready", "key_obtained",
	"prism_turn", "beam_on", "receptor_charge", "crystal_door", "vigia_charge", "vigia_shot", "orb_pop",
	"cefiro_charge", "cefiro_dash", "wind_gust", "crumble", "valve", "star_step", "constellation_complete",
	"heraldo_phase", "heraldo_laser", "heraldo_roar", "pillar_charge", "shield_break", "map_open", "travel"]

var music: AudioStreamPlayer
var wind: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var next_voice: int = 0
var themes: Array[AudioStreamPlayer] = []
var target_theme: int = 0
var ducked: bool = false
var tension: AudioStreamPlayer
var cinematic_music: AudioStreamPlayer
var cinematic_track: String = ""
var voice: AudioStreamPlayer
var voice_is_dialogue: bool = false
var voice_fade: Tween


static func music_path(track: String) -> String:
	for extension in ["ogg", "wav"]:
		var path: String = MUSIC_DIR + track + "." + extension
		if ResourceLoader.exists(path): return path
	if LEGACY_THEMES.has(track):
		return "res://assets/audio/%s.wav" % LEGACY_THEMES[track]
	# Fase 7: una pista que aún no existe usa la de exploración para no dejar la isla en silencio.
	if track != "exploration" and track != "":
		return music_path("exploration")
	return ""


static func looped(path: String) -> AudioStream:
	var source: AudioStream = load(path)
	if source is AudioStreamWAV:
		var stream: AudioStreamWAV = source.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		return stream
	if source is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = source.duplicate()
		ogg.loop = true
		return ogg
	return source


func loop_stream(path: String) -> AudioStream:
	return looped(path)


func _ready() -> void:
	for cue in CUES:
		for extension in ["wav", "ogg"]:
			var path: String = "res://assets/audio/%s.%s" % [cue, extension]
			if ResourceLoader.exists(path):
				cues[cue] = load(path)
				break
	for i in range(10):
		var player := AudioStreamPlayer.new()
		player.name = "Effect_%d" % i
		player.volume_db = -10
		player.bus = "Effects"
		add_child(player)
		voices.append(player)
	var level: Node = get_parent()
	var theme_names: Array = level.get("music_themes") if level and level.get("music_themes") is Array else ZONE_THEMES
	for theme in theme_names:
		var layer := AudioStreamPlayer.new()
		layer.name = "music_" + theme
		layer.stream = looped(music_path(theme))
		layer.bus = "Music"
		layer.volume_db = -50.0
		add_child(layer)
		layer.play()
		themes.append(layer)
	music = themes[0]
	tension = AudioStreamPlayer.new()
	tension.name = "CombatTension"
	tension.stream = looped(music_path("combat"))
	tension.bus = "Music"
	tension.volume_db = -60
	add_child(tension)
	tension.play()
	cinematic_music = AudioStreamPlayer.new()
	cinematic_music.name = "CinematicMusic"
	cinematic_music.bus = "Music"
	cinematic_music.volume_db = -60
	add_child(cinematic_music)
	voice = AudioStreamPlayer.new()
	voice.name = "VoiceOver"
	voice.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Effects"
	add_child(voice)
	wind = AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = looped("res://assets/audio/wind_soft.wav")
	wind.bus = "Ambience"
	wind.volume_db = -14
	add_child(wind)
	wind.play()
	GameEvents.sound_requested.connect(play_cue)
	GameEvents.voice_requested.connect(_on_voice_requested)
	GameEvents.zone_changed.connect(_on_zone_changed)
	if level and level.has_method("audio_spots"):
		# Fase 7: cada isla declara sus fuentes ambientales [nombre, posición, sonido, ganancia, distancia].
		for spot in level.audio_spots():
			spatial_loop(spot[0], spot[1], spot[2], spot[3], spot[4])
		if level.has_method("theme_for_zone"): target_theme = level.theme_for_zone(GameEvents.zone)
	else:
		for point in [Vector3(10, 0, -5), Vector3(-9, 0, -36), Vector3(9, 4, -90)]:
			spatial_loop("WaterfallAudio", point, "waterfall", -14.0, 20.0)
		spatial_loop("PortalHum", Vector3(0, 6, -90), "crystal_hum", -5.0, 12.0)


func _on_zone_changed(index: int, _title: String) -> void:
	var level: Node = get_parent()
	if level and level.has_method("theme_for_zone"):
		target_theme = clampi(level.theme_for_zone(index), 0, themes.size() - 1)
	else:
		target_theme = 1 if index == 1 else (2 if index == 3 else 0)


func spatial_loop(title: String, point: Vector3, cue: String, gain: float, distance: float) -> void:
	var source := AudioStreamPlayer3D.new()
	source.name = title
	source.position = point
	var cue_path := "res://assets/audio/%s.wav" % cue
	if not ResourceLoader.exists(cue_path): cue_path = "res://assets/audio/%s.ogg" % cue
	if not ResourceLoader.exists(cue_path): return
	source.stream = looped(cue_path)
	source.bus = "Ambience"
	source.volume_db = gain
	source.unit_size = 5.0
	source.max_distance = distance
	add_child(source, true)
	source.play()


func _process(delta: float) -> void:
	var hud: Node = get_parent().get_node_or_null("HUDLayer")
	var dialog_open: bool = hud != null and hud.dialog_open
	ducked = dialog_open
	var speaking: bool = voice.playing
	if voice_is_dialogue and speaking and not dialog_open:
		stop_voice(0.25)
	var cinematic_on: bool = cinematic_track != ""
	var duck: float = (-9.0 if speaking else (-6.0 if ducked else 0.0))
	var boss_zone: bool = (GameEvents.level == "auralia" and GameEvents.zone == 3) or get_parent().get("boss_active") == true
	var tension_gain: float = -60.0 if ducked or cinematic_on or GameEvents.active_threats == 0 else (-13.0 if boss_zone else -21.0)
	tension.volume_db = lerpf(tension.volume_db, tension_gain, 1.0 - exp(-delta * 2.5))
	for i in themes.size():
		var target: float = (-1.0 + duck) if i == target_theme and not cinematic_on else -55.0
		themes[i].volume_db = lerpf(themes[i].volume_db, target, 1.0 - exp(-delta * (1.6 if cinematic_on else 0.8)))
	var cinematic_target: float = (0.0 + duck * 0.7) if cinematic_on else -60.0
	cinematic_music.volume_db = lerpf(cinematic_music.volume_db, cinematic_target, 1.0 - exp(-delta * 1.4))
	if not cinematic_on and cinematic_music.playing and cinematic_music.volume_db < -55.0:
		cinematic_music.stop()


## Funde una pista de cinemática ("title", "garden", "combat", "finale"...) sobre la música de zona.
func set_cinematic_music(track: String) -> void:
	var path := music_path(track)
	if path == "":
		return
	if cinematic_track == track and cinematic_music.playing:
		return
	cinematic_track = track
	cinematic_music.stream = looped(path) if not track in ["finale", "finale2"] else load(path)
	cinematic_music.volume_db = -30.0
	cinematic_music.play()


func clear_cinematic_music() -> void:
	cinematic_track = ""


func _on_voice_requested(cue: String) -> void:
	if play_voice(cue) > 0.0:
		voice_is_dialogue = true


## Reproduce una línea de voz si existe. Devuelve su duración en segundos (0 si no hay archivo).
func play_voice(cue: String) -> float:
	var path := ""
	for extension in ["ogg", "wav"]:
		if ResourceLoader.exists(VOICE_DIR + cue + "." + extension):
			path = VOICE_DIR + cue + "." + extension
			break
	if path == "":
		return 0.0
	if voice_fade: voice_fade.kill()
	voice_is_dialogue = false
	voice.stream = load(path)
	voice.volume_db = 0.0
	voice.play()
	return voice.stream.get_length()


func stop_voice(fade: float = 0.3) -> void:
	if not voice.playing:
		return
	if voice_fade: voice_fade.kill()
	voice_fade = create_tween()
	voice_fade.tween_property(voice, "volume_db", -40.0, fade)
	voice_fade.tween_callback(voice.stop)
	voice_is_dialogue = false


func play_cue(cue: String) -> void:
	var is_step: bool = cue == "step"
	if is_step: cue = "step_%d" % randi_range(0, 3)
	if not cues.has(cue) and cue.begins_with("rune_"): cue = "rune"
	if not cues.has(cue): return
	var player: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	player.stream = cues[cue]
	player.volume_db = -17 if is_step else (-12 if cue in ["fragment_rise", "island_chime", "destello", "star_step"] else -9)
	player.pitch_scale = randf_range(0.94, 1.06) if is_step or cue == "island_chime" else 1.0
	player.play()
