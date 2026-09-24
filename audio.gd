extends Node
## Autoload "Audio". One place for every sound:
##   play(id, at)     SFX; positional when `at` is a Vector2 (pooled 2D players)
##   play_ui(id)      interface sounds on the UI bus
##   loop(id, on)     looping one-shots (alarm, heartbeat, van engine)
##   music(track)     crossfade to a looping track
##   music_layers(a, b) + set_intensity(0..1)   two synced heist layers
## Per-sound voice limits keep a firefight from stacking fifty gunshots, and
## every play gets ±6% pitch variance. Buses: Master / Music / SFX / UI.
## All audio is generated placeholder audio: see assets/audio/README.md.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

## ids with numbered variants: footstep -> footstep_1..3
const VARIANTS := {"footstep": 3}
## Max simultaneous voices per id (default 3).
const LIMITS := {
	"shot_pistol": 5, "shot_smg": 6, "shot_lmg": 6, "shot_rifle": 4, "shot_enemy": 6,
	"shot_shotgun": 3, "impact_wall": 4, "impact_body": 4, "footstep": 2, "case_tick": 2,
	"ui_hover": 2, "typewriter": 2, "loot_0": 3, "loot_1": 3,
}
## Mix offsets in dB so generated sounds sit together.
const GAIN := {
	"shot_enemy": -7.0, "footstep": -14.0, "impact_wall": -8.0, "impact_body": -6.0,
	"ui_hover": -12.0, "ui_click": -6.0, "case_tick": -10.0, "mag_out": -8.0, "mag_in": -8.0,
	"dry_fire": -6.0, "camera_spot": -4.0, "stock_up": -10.0, "stock_down": -10.0, "heartbeat": -2.0,
	"alarm": -10.0, "van_engine": -6.0, "drone": -12.0, "typewriter": -8.0, "death_enemy": -4.0,
	"paper": -6.0, "radio": -6.0,
}
const POSITIONAL_POOL := 24
const FLAT_POOL := 10
const UI_POOL := 4

var _cache: Dictionary = {}
var _pos: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _ui: Array[AudioStreamPlayer] = []
var _voices: Dictionary = {}        # id -> Array of players currently owned
var _loops: Dictionary = {}         # id -> AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _track := ""
var _layered := false
var _intensity := 0.0
var _intensity_target := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in POSITIONAL_POOL:
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		p.max_distance = 1500.0
		p.attenuation = 1.6
		add_child(p)
		_pos.append(p)
	for i in FLAT_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_flat.append(p)
	for i in UI_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"UI"
		add_child(p)
		_ui.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = &"Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = &"Music"
	add_child(_music_b)
	get_tree().node_added.connect(_on_node_added)
	# The AI hearing bus doubles as a sound cue: a body hitting the floor.
	var noise_bus := get_node_or_null("/root/Noise")
	if noise_bus:
		noise_bus.heard.connect(_on_noise)

func _on_noise(at: Vector2, _radius: float, kind: StringName) -> void:
	if kind == &"death":
		play("impact_body", at, -6.0, 0.55)

# ------------------------------------------------------------------ SFX -----
func _stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path := SFX_DIR + id + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("Audio: missing sound '%s'" % id)
	_cache[id] = s
	return s

func _resolve(id: String) -> String:
	if VARIANTS.has(id):
		return "%s_%d" % [id, _rng.randi_range(1, VARIANTS[id])]
	return id

func _free_voice(id: String) -> bool:
	var owned: Array = _voices.get(id, [])
	owned = owned.filter(func(p): return is_instance_valid(p) and p.playing)
	_voices[id] = owned
	return owned.size() < int(LIMITS.get(id, 3))

func _claim(id: String, player: Node) -> void:
	if not _voices.has(id):
		_voices[id] = []
	_voices[id].append(player)

## Play a sound effect. Pass a world position for positional audio.
func play(id: String, at: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _free_voice(id):
		return
	var s := _stream(_resolve(id))
	if s == null:
		return
	var gain: float = GAIN.get(id, 0.0) + volume_db
	var jitter := _rng.randf_range(0.94, 1.06) * pitch
	if at is Vector2:
		var p := _pick(_pos) as AudioStreamPlayer2D
		p.global_position = at
		p.stream = s
		p.volume_db = gain
		p.pitch_scale = jitter
		p.play()
		_claim(id, p)
	else:
		var p := _pick(_flat) as AudioStreamPlayer
		p.stream = s
		p.volume_db = gain
		p.pitch_scale = jitter
		p.play()
		_claim(id, p)

func play_ui(id: String, pitch: float = 1.0) -> void:
	var s := _stream(_resolve(id))
	if s == null:
		return
	var p := _pick(_ui) as AudioStreamPlayer
	p.stream = s
	p.volume_db = GAIN.get(id, 0.0)
	p.pitch_scale = pitch * _rng.randf_range(0.97, 1.03)
	p.play()

## Prefer an idle player; otherwise steal the one that has played longest.
func _pick(pool: Array) -> Node:
	var best: Node = pool[0]
	var best_pos := -1.0
	for p in pool:
		if not p.playing:
			return p
		var pos: float = p.get_playback_position()
		if pos > best_pos:
			best_pos = pos
			best = p
	return best

## Start or stop a looping effect (alarm, heartbeat, engine).
func loop(id: String, on: bool, volume_db: float = 0.0) -> void:
	if not on:
		if _loops.has(id) and is_instance_valid(_loops[id]):
			var p: AudioStreamPlayer = _loops[id]
			var tw := p.create_tween()
			tw.tween_property(p, "volume_db", -40.0, 0.4)
			tw.tween_callback(p.stop)
		return
	var player: AudioStreamPlayer = _loops.get(id)
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_loops[id] = player
		var s := _stream(id)
		if s == null:
			return
		player.stream = _looped(s)
	player.volume_db = GAIN.get(id, 0.0) + volume_db
	if not player.playing:
		player.play()

func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var copy: AudioStreamWAV = s.duplicate()
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		copy.loop_end = int(s.get_length() * s.mix_rate)
		return copy
	return s

# ---------------------------------------------------------------- music -----
func _music_stream(track: String) -> AudioStream:
	var key := "music:" + track
	if _cache.has(key):
		return _cache[key]
	var path := MUSIC_DIR + track + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = _looped(load(path))
	_cache[key] = s
	return s

## Crossfade to a single looping track ("" stops the music).
func music(track: String, fade: float = 1.2) -> void:
	if track == _track and not _layered:
		return
	_track = track
	_layered = false
	var old := _music_a if _music_a.playing else null
	var incoming := _music_b if old == _music_a else _music_a
	if old == null:
		incoming = _music_a
	_fade_out(_music_b if incoming == _music_a else _music_a, fade)
	if track == "":
		_fade_out(incoming, fade)
		return
	var s := _music_stream(track)
	if s == null:
		return
	incoming.stream = s
	incoming.volume_db = -40.0
	incoming.play()
	var tw := incoming.create_tween()
	tw.tween_property(incoming, "volume_db", 0.0, fade)

## Two layers that play in lockstep; set_intensity crossfades between them.
func music_layers(calm: String, tense: String) -> void:
	var key := calm + "+" + tense
	if _layered and _track == key:
		return
	_track = key
	_layered = true
	var a := _music_stream(calm)
	var b := _music_stream(tense)
	if a == null or b == null:
		return
	_music_a.stream = a
	_music_b.stream = b
	_intensity = 0.0
	_intensity_target = 0.0
	_music_a.volume_db = -40.0
	_music_b.volume_db = -60.0
	_music_a.play()
	_music_b.play()
	var tw := _music_a.create_tween()
	tw.tween_property(_music_a, "volume_db", 0.0, 1.5)

func set_intensity(value: float) -> void:
	_intensity_target = clampf(value, 0.0, 1.0)

func stop_music(fade: float = 1.0) -> void:
	_track = ""
	_layered = false
	_fade_out(_music_a, fade)
	_fade_out(_music_b, fade)

func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	if not p.playing:
		return
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", -50.0, fade)
	tw.tween_callback(p.stop)

func _process(delta: float) -> void:
	if not _layered or not _music_a.playing:
		return
	_intensity = move_toward(_intensity, _intensity_target, delta * (0.8 if _intensity_target > _intensity else 0.25))
	_music_a.volume_db = linear_to_db(maxf(1.0 - _intensity * 0.75, 0.001))
	_music_b.volume_db = linear_to_db(maxf(_intensity, 0.001))
	# Keep the layers locked together after pauses and hitches.
	if absf(_music_a.get_playback_position() - _music_b.get_playback_position()) > 0.08:
		_music_b.seek(_music_a.get_playback_position())

# ------------------------------------------------------------- UI hooks -----
## Every button in the game ticks on hover and clicks on press.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.mouse_entered.connect(_on_button_hover.bind(node))
		node.pressed.connect(_on_button_pressed.bind(node))

func _on_button_hover(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.disabled:
		play_ui("ui_hover")

func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button):
		play_ui("ui_click")
