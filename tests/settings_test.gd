extends Node
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var expected := {"master": 0.37, "sfx": 0.62, "fullscreen": true, "low_effects": true, "frame_cap": 30, "touch_mode": 1}
	if "write" in args:
		Meta.reset()
		assert(Meta.award_extraction("persistence-fixture", 12, 4, true) == 14)
		assert(Meta.purchase(&"fast_hands") == "Unlocked permanently.")
		Meta.intel += 8
		assert(Meta.purchase(&"room_training") == "Unlocked permanently.")
		assert(Meta.equip_starting_perk(&"fast_hands"))
		for key: String in expected:
			Settings.set_setting(key, expected[key])
		assert(Settings.last_save_error == OK, "settings write")
		print("TEST settings: wrote audio and video")
	else:
		assert(Meta.intel == 6 and Meta.starting_perk == &"fast_hands")
		assert(&"fast_hands" in Meta.unlocked_assets)
		assert(&"room_training" in Meta.unlocked_assets, "built rooms persist across processes")
		assert(Meta.award_extraction("persistence-fixture", 12, 4, true) == 0)
		print("TEST career: currency, unlock, equipped perk and receipt survived a fresh process")
		Meta.reset()
		for key: String in expected:
			assert(Settings.values[key] == expected[key], "settings cross-process reload: " + key)
		assert(Engine.max_fps == 30)
		assert(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.37)) < 0.01)
		assert(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.62)) < 0.01)
		print("TEST settings: audio/video persisted across separate processes and applied")
		for key: String in Settings.DEFAULTS:
			Settings.set_setting(key, Settings.DEFAULTS[key])
	get_tree().quit(0)
