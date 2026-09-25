extends VBoxContainer
class_name SettingsPanel
## Settings in four tabs so everything fits a phone in landscape:
##   SOUND    volumes, Dynamic music
##   DISPLAY  low effects, post-processing, shadows, fullscreen, frame rate,
##            touch controls
##   EFFECTS  screen shake, reduce flashing, damage numbers, tips, gore, blood
##   HUD      style (Noir Props / Minimal), scale, opacity, reduce motion,
##            combo panel size
## Every change applies immediately and persists (Settings autoload).
signal closed
var status: Label
var pages: Dictionary = {}
var tabs: Dictionary = {}
var current := ""

const PAGE_SIZE := Vector2(900, 330)

func _ready() -> void:
	custom_minimum_size = Vector2(900, 0)
	add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	add_child(head)
	var title := VisualTheme.label("SETTINGS", "HeadingLabel", 30)
	title.custom_minimum_size = Vector2(190, 0)
	head.add_child(title)
	for tab: String in ["SOUND", "DISPLAY", "EFFECTS", "HUD"]:
		var b := Button.new()
		b.text = tab
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(160, 48)
		b.pressed.connect(show_page.bind(tab))
		head.add_child(b)
		tabs[tab] = b
	var holder := Control.new()
	holder.custom_minimum_size = PAGE_SIZE
	add_child(holder)
	for tab: String in tabs:
		var page := HBoxContainer.new()
		page.add_theme_constant_override("separation", 36)
		page.size = PAGE_SIZE
		page.hide()
		holder.add_child(page)
		pages[tab] = page
	_build_sound(_columns("SOUND"))
	_build_display(_columns("DISPLAY"))
	_build_effects(_columns("EFFECTS"))
	_build_hud(_columns("HUD"))
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
	show_page("SOUND")
	# Keyboard / controller: land on the page's first control whenever the
	# panel opens.
	visibility_changed.connect(_focus_default)
	_focus_default.call_deferred()

## Two columns on a tab's page: [left, right].
func _columns(tab: String) -> Array:
	var out: Array = []
	for i in 2:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(432, 0)
		col.add_theme_constant_override("separation", 4)
		pages[tab].add_child(col)
		out.append(col)
	return out

func _build_sound(cols: Array) -> void:
	_slider(cols[0], "Master volume", "master")
	_slider(cols[0], "Effects volume", "sfx")
	_slider(cols[0], "Music volume", "music")
	_slider(cols[1], "Interface volume", "ui")
	_toggle(cols[1], "Dynamic music", "dynamic_music")

func _build_display(cols: Array) -> void:
	_toggle(cols[0], "Low effects", "low_effects")
	_toggle(cols[0], "Post-processing", "post_fx")
	_toggle(cols[0], "Dynamic shadows", "dynamic_shadows")
	var full := CheckButton.new()
	full.text = "Fullscreen (tap to apply)"
	full.button_pressed = Settings.values["fullscreen"]
	full.custom_minimum_size.y = 44
	full.toggled.connect(_on_fullscreen)
	cols[0].add_child(full)
	var rate := OptionButton.new()
	rate.add_item("60 FPS", 60)
	rate.add_item("30 FPS - battery saver", 30)
	rate.select(0 if Settings.values["frame_cap"] == 60 else 1)
	rate.custom_minimum_size = Vector2(360, 52)
	rate.item_selected.connect(_on_rate.bind(rate))
	cols[1].add_child(rate)
	var touch := OptionButton.new()
	for label in ["Touch controls: automatic", "Touch controls: on", "Touch controls: off"]:
		touch.add_item(label)
	touch.select(int(Settings.values["touch_mode"]))
	touch.custom_minimum_size = Vector2(360, 52)
	touch.item_selected.connect(_on_touch)
	cols[1].add_child(touch)

func _build_effects(cols: Array) -> void:
	_slider(cols[0], "Screen shake", "shake")
	_toggle(cols[0], "Reduce flashing", "reduce_flashing")
	_toggle(cols[0], "Damage numbers", "damage_numbers")
	_toggle(cols[0], "Tutorial tips", "tips")
	_choice(cols[1], ["Gore: off", "Gore: low", "Gore: full"], "gore")
	_choice(cols[1], ["Blood: red", "Blood: noir (ink with a red rim)"], "blood_style")

func _build_hud(cols: Array) -> void:
	_choice(cols[0], ["HUD: Noir Props", "HUD: Minimal (outlined text only)"], "hud_style")
	_slider(cols[0], "HUD scale", "hud_scale", 0.75, 1.5)
	_slider(cols[0], "HUD opacity", "hud_opacity", 0.5, 1.0)
	_toggle(cols[1], "Reduce motion", "reduce_motion")
	_slider(cols[1], "Combo panel size", "combo_hud_scale", 0.75, 1.5)

func show_page(tab: String) -> void:
	current = tab
	for t: String in pages:
		pages[t].visible = t == tab
		tabs[t].set_pressed_no_signal(t == tab)
	_focus_default()

func _focus_default() -> void:
	if not is_visible_in_tree() or not pages.has(current):
		return
	for c: Node in pages[current].find_children("*", "Control", true, false):
		var control := c as Control
		if control.focus_mode != Control.FOCUS_NONE and (control is Range or control is BaseButton):
			control.grab_focus.call_deferred()
			return

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

func _choice(parent: Control, labels: Array, key: String) -> void:
	var option := OptionButton.new()
	for label in labels:
		option.add_item(label)
	option.select(int(Settings.values[key]))
	option.custom_minimum_size = Vector2(400, 52)
	option.item_selected.connect(_on_choice.bind(key))
	parent.add_child(option)

func _slider(parent: Control, text: String, key: String, lo := 0.0, hi := 1.0) -> void:
	var label := VisualTheme.label(text + "  %d%%" % roundi(float(Settings.values[key]) * 100.0), "", 18)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
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
