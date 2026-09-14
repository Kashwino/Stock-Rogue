extends VBoxContainer
class_name SettingsPanel
signal closed
var status: Label

func _ready() -> void:
	custom_minimum_size = Vector2(480, 0)
	add_theme_constant_override("separation", 12)
	_label("SETTINGS", 28)
	_slider("Master volume", "master")
	_slider("Effects volume", "sfx")
	_toggle("Low effects", "low_effects")
	var rate := OptionButton.new()
	rate.add_item("60 FPS", 60)
	rate.add_item("30 FPS - battery saver", 30)
	rate.select(0 if Settings.values["frame_cap"] == 60 else 1)
	rate.custom_minimum_size.y = 56
	rate.item_selected.connect(func(i): Settings.set_setting("frame_cap", rate.get_item_id(i)))
	add_child(rate)
	var touch := OptionButton.new()
	for label in ["Touch controls: automatic", "Touch controls: on", "Touch controls: off"]:
		touch.add_item(label)
	touch.select(int(Settings.values["touch_mode"]))
	touch.custom_minimum_size.y = 56
	touch.item_selected.connect(func(i): Settings.set_setting("touch_mode", i))
	add_child(touch)
	var full := CheckButton.new()
	full.text = "Fullscreen (tap to apply)"
	full.button_pressed = Settings.values["fullscreen"]
	full.custom_minimum_size.y = 52
	full.toggled.connect(func(on):
		Settings.set_setting("fullscreen", on)
		Settings.apply_display_from_gesture())
	add_child(full)
	status = _label("Changes save automatically on this device.", 18)
	Settings.save_failed.connect(func(message): status.text = message)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size.y = 64
	back.pressed.connect(func(): closed.emit())
	add_child(back)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func _slider(text: String, key: String) -> void:
	var label := _label(text + "  %d%%" % roundi(float(Settings.values[key]) * 100.0), 20)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Settings.values[key]
	slider.custom_minimum_size.y = 44
	slider.value_changed.connect(func(v):
		label.text = text + "  %d%%" % roundi(v * 100.0)
		Settings.set_setting(key, v))
	add_child(slider)

func _toggle(text: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = Settings.values[key]
	toggle.custom_minimum_size.y = 52
	toggle.toggled.connect(func(on): Settings.set_setting(key, on))
	add_child(toggle)
