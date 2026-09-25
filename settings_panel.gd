extends VBoxContainer
class_name SettingsPanel
## Settings, laid out in two columns so it fits a phone in landscape:
## volumes and shake on the left, display/effects toggles on the right.
## Every change applies immediately and persists (Settings autoload).
signal closed
var status: Label

func _ready() -> void:
	custom_minimum_size = Vector2(900, 0)
	add_theme_constant_override("separation", 10)
	var title := VisualTheme.label("SETTINGS", "HeadingLabel", 30)
	add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 36)
	add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 2)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	_slider(left, "Master volume", "master")
	_slider(left, "Effects volume", "sfx")
	_slider(left, "Music volume", "music")
	_slider(left, "Interface volume", "ui")
	_slider(left, "Screen shake", "shake")
	_toggle(right, "Low effects", "low_effects")
	_toggle(right, "Post-processing", "post_fx")
	_toggle(right, "Dynamic shadows", "dynamic_shadows")
	_toggle(right, "Reduce flashing", "reduce_flashing")
	_toggle(right, "Damage numbers", "damage_numbers")
	_toggle(right, "Tutorial tips", "tips")
	_toggle(right, "Dynamic music", "dynamic_music")
	var full := CheckButton.new()
	full.text = "Fullscreen (tap to apply)"
	full.button_pressed = Settings.values["fullscreen"]
	full.custom_minimum_size.y = 44
	full.toggled.connect(_on_fullscreen)
	right.add_child(full)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	add_child(options)
	var rate := OptionButton.new()
	rate.add_item("60 FPS", 60)
	rate.add_item("30 FPS - battery saver", 30)
	rate.select(0 if Settings.values["frame_cap"] == 60 else 1)
	rate.custom_minimum_size = Vector2(300, 52)
	rate.item_selected.connect(_on_rate.bind(rate))
	options.add_child(rate)
	var touch := OptionButton.new()
	for label in ["Touch controls: automatic", "Touch controls: on", "Touch controls: off"]:
		touch.add_item(label)
	touch.select(int(Settings.values["touch_mode"]))
	touch.custom_minimum_size = Vector2(360, 52)
	touch.item_selected.connect(_on_touch)
	options.add_child(touch)
	var gore_row := HBoxContainer.new()
	gore_row.add_theme_constant_override("separation", 12)
	add_child(gore_row)
	var gore := OptionButton.new()
	for label in ["Gore: off", "Gore: low", "Gore: full"]:
		gore.add_item(label)
	gore.select(int(Settings.values["gore"]))
	gore.custom_minimum_size = Vector2(300, 52)
	gore.item_selected.connect(_on_choice.bind("gore"))
	gore_row.add_child(gore)
	var blood := OptionButton.new()
	for label in ["Blood: red", "Blood: noir (ink with a red rim)"]:
		blood.add_item(label)
	blood.select(int(Settings.values["blood_style"]))
	blood.custom_minimum_size = Vector2(360, 52)
	blood.item_selected.connect(_on_choice.bind("blood_style"))
	gore_row.add_child(blood)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	add_child(foot)
	var back := Button.new()
	back.text = "BACK"
	back.theme_type_variation = "PrimaryButton"
	back.custom_minimum_size = Vector2(220, 56)
	back.pressed.connect(_on_back)
	foot.add_child(back)
	status = VisualTheme.label("Changes save automatically on this device.", "DimLabel", 16)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(status)
	Settings.save_failed.connect(_on_save_failed)
	# Keyboard / controller: land on the first slider whenever the panel opens.
	visibility_changed.connect(_focus_default)
	_focus_default.call_deferred()

func _focus_default() -> void:
	if not is_visible_in_tree():
		return
	var sliders := find_children("*", "HSlider", true, false)
	if not sliders.is_empty():
		(sliders[0] as Control).grab_focus.call_deferred()

func _on_back() -> void:
	closed.emit()

func _on_save_failed(message: String) -> void:
	if is_instance_valid(status):
		status.text = message

func _on_fullscreen(on: bool) -> void:
	Settings.set_setting("fullscreen", on)
	Settings.apply_display_from_gesture()

func _on_choice(index: int, key: String) -> void:
	Settings.set_setting(key, index)

func _on_rate(index: int, rate: OptionButton) -> void:
	Settings.set_setting("frame_cap", rate.get_item_id(index))

func _on_touch(index: int) -> void:
	Settings.set_setting("touch_mode", index)

func _slider(parent: Control, text: String, key: String) -> void:
	var label := VisualTheme.label(text + "  %d%%" % roundi(float(Settings.values[key]) * 100.0), "", 18)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Settings.values[key]
	slider.custom_minimum_size.y = 38
	slider.value_changed.connect(_on_slider.bind(key, text, label))
	parent.add_child(slider)

func _on_slider(v: float, key: String, text: String, label: Label) -> void:
	label.text = text + "  %d%%" % roundi(v * 100.0)
	Settings.set_setting(key, v)

func _toggle(parent: Control, text: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = Settings.values[key]
	toggle.custom_minimum_size.y = 44
	toggle.toggled.connect(_on_toggle.bind(key))
	parent.add_child(toggle)

func _on_toggle(on: bool, key: String) -> void:
	Settings.set_setting(key, on)
