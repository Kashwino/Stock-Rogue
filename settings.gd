extends Node
## One source of truth for menu and mid-heist settings.
signal changed
signal save_failed(message: String)
const PATH := "user://settings.cfg"
const WEB_KEY := "stock-rogue-settings-v1"
const DEFAULTS := {"master": 0.8, "music": 0.7, "sfx": 0.8, "ui": 0.8, "fullscreen": false,
	"low_effects": false, "frame_cap": 60, "touch_mode": 0, "shake": 1.0, "dynamic_shadows": false,
	"post_fx": true, "reduce_flashing": false, "damage_numbers": true, "tips": true,
	"gore": 2, "blood_style": 0, "dynamic_music": true}
## Gore: 0 off (sparks and dust, bodies fade), 1 low (particles and short-lived
## marks), 2 full (decals that stay, pools, gibs, footprints).
## Blood style: 0 red, 1 noir (ink-black with a red rim).
const GORE_OFF := 0
const GORE_LOW := 1
const GORE_FULL := 2
const AUDIO_KEYS := {"master": "Master", "music": "Music", "sfx": "SFX", "ui": "UI"}
const FLOAT_KEYS := ["master", "music", "sfx", "ui", "shake"]
const BOOL_KEYS := ["fullscreen", "low_effects", "dynamic_shadows", "post_fx", "reduce_flashing", "damage_numbers", "tips", "dynamic_music"]
var values: Dictionary = DEFAULTS.duplicate()
var last_save_error: int = OK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()
	if not OS.has_feature("web"):
		apply_display_from_gesture()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key: String in DEFAULTS:
			values[key] = cfg.get_value("audio" if AUDIO_KEYS.has(key) else "video", key, DEFAULTS[key])
	if OS.has_feature("web"):
		var saved = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('" + WEB_KEY + "')}catch(e){return null}})()", true)
		if saved is String:
			var data = JSON.parse_string(saved)
			if data is Dictionary:
				for key: String in DEFAULTS:
					values[key] = data.get(key, values[key])
	_sanitize()

func _sanitize() -> void:
	for key: String in FLOAT_KEYS:
		if not (values[key] is float or values[key] is int) or not is_finite(float(values[key])):
			values[key] = DEFAULTS[key]
		values[key] = clampf(float(values[key]), 0.0, 1.0)
	for key: String in BOOL_KEYS:
		if not values[key] is bool:
			values[key] = DEFAULTS[key]
	if values["frame_cap"] not in [30, 60]:
		values["frame_cap"] = 60
	if values["touch_mode"] not in [0, 1, 2]:
		values["touch_mode"] = 0
	if not (values["gore"] is int or values["gore"] is float) or int(values["gore"]) not in [0, 1, 2]:
		values["gore"] = DEFAULTS["gore"]
	values["gore"] = int(values["gore"])
	if not (values["blood_style"] is int or values["blood_style"] is float) or int(values["blood_style"]) not in [0, 1]:
		values["blood_style"] = DEFAULTS["blood_style"]
	values["blood_style"] = int(values["blood_style"])

func set_setting(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = value
	_sanitize()
	apply()
	save()
	changed.emit()

func apply() -> void:
	for bus: String in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for key: String in AUDIO_KEYS:
		var index := AudioServer.get_bus_index(AUDIO_KEYS[key])
		var value: float = values[key]
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	Engine.max_fps = int(values["frame_cap"])

func apply_display_from_gesture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)

func save() -> bool:
	var cfg := ConfigFile.new()
	for key: String in DEFAULTS:
		cfg.set_value("audio" if AUDIO_KEYS.has(key) else "video", key, values[key])
	last_save_error = cfg.save(PATH)
	if OS.has_feature("web"):
		# Synchronous same-origin fallback also survives closing a browser tab
		# immediately after moving a slider, before IndexedDB's async flush.
		var ok = JavaScriptBridge.eval("(()=>{try{localStorage.setItem('" + WEB_KEY + "'," + JSON.stringify(JSON.stringify(values)) + ");return true}catch(e){return false}})()", true)
		if ok == true:
			last_save_error = OK
	if last_save_error != OK:
		save_failed.emit("Settings could not be saved on this device.")
	return last_save_error == OK
