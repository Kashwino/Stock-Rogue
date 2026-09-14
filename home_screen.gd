extends Control
## Home screen. Built entirely in code, same as every other menu in the
## game now -- the old scene relied on % unique names under a plain Control,
## which is why buttons kept going dead: no full-rect Control root meant
## Godot never routed clicks down to them. Scene is just this Control + script.

const GOLD := Color(0.91, 0.72, 0.18)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const BG := Color(0.045, 0.045, 0.06)
const PANEL := Color(0.10, 0.10, 0.13)
const PANEL_EDGE := Color(0.24, 0.24, 0.3)
const INK_SOFT := Color(0.62, 0.62, 0.7)


var _root: Control
var _main_menu: Control
var _settings_panel: Control


func _ready() -> void:
	get_tree().paused = false
	_build()
	_show_main_menu()

# ------------------------------------------------------------------ frame ---
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	_build_backdrop()
	_main_menu = _build_main_menu()
	_settings_panel = _build_settings_panel()
	_root.add_child(_main_menu)
	_root.add_child(_settings_panel)

## Dark backdrop with a subtle spotlight glow and caution stripes, so the
## menu reads as "criminal HQ at night" rather than a bare black rectangle.
func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Soft off-center glow behind the title, like a desk lamp over a case file.
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0, 0, 0, 0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 c = UV - vec2(0.5, 0.36);\n\tfloat d = length(c * vec2(1.0, 1.4));\n\tfloat glow = smoothstep(0.75, 0.0, d) * 0.10;\n\tCOLOR = vec4(vec3(0.9, 0.72, 0.3) * glow, glow);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	glow.material = mat
	_root.add_child(glow)

	for y_anchor in [0.0, 1.0]:
		var stripe := ColorRect.new()
		stripe.anchor_left = 0.0
		stripe.anchor_right = 1.0
		stripe.anchor_top = y_anchor
		stripe.anchor_bottom = y_anchor
		stripe.offset_top = -3 if y_anchor == 1.0 else 0
		stripe.offset_bottom = 0 if y_anchor == 1.0 else 3
		stripe.color = GOLD_DIM
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(stripe)

# ------------------------------------------------------------- main menu ---
func _build_main_menu() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var kicker := Label.new()
	kicker.text = "A CRIMINAL STOCK MARKET"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", GOLD_DIM)
	col.add_child(kicker)

	var title := Label.new()
	title.text = "STOCK ROGUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	col.add_child(title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(360, 2)
	rule.color = GOLD_DIM
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	col.add_child(spacer)

	col.add_child(_menu_button("PLAY", true, _on_play))
	col.add_child(_menu_button("QUICK HEIST", false, RunFlow.start_quick_test))
	if RunFlow.can_continue():
		col.add_child(_menu_button("CONTINUE", false, _on_continue))
	col.add_child(_menu_button("SETTINGS", false, _on_open_settings))
	if not OS.has_feature("web"):
		col.add_child(_menu_button("QUIT", false, _on_quit))

	var footer := Label.new()
	footer.text = "THE FENCE IS ALWAYS WATCHING THE TAPE"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.4, 0.4, 0.46))
	col.add_child(footer)

	return wrap

## A menu button styled like a stenciled stamp: gold outline, fills solid on
## hover. `primary` gets a slightly heavier treatment (this is "PLAY").
func _menu_button(text: String, primary: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 78 if primary else 68)
	b.add_theme_font_size_override("font_size", 20 if primary else 15)
	b.pressed.connect(action)

	var edge := GOLD if primary else PANEL_EDGE
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.11, 0.06) if (primary and state != "normal") \
			else (Color(0.14, 0.14, 0.18) if state != "normal" else PANEL)
		sb.border_color = Color(1.0, 0.85, 0.4) if state in ["hover", "focus"] else edge
		sb.set_border_width_all(3 if state != "normal" else 2)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", GOLD if primary else Color(0.85, 0.85, 0.88))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.6))
	return b

# ------------------------------------------------------------- settings ----
func _build_settings_panel() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := SettingsPanel.new()
	panel.closed.connect(_on_close_settings)
	center.add_child(panel)
	return center

# ------------------------------------------------------------ navigation ---
func _show_main_menu() -> void:
	_main_menu.show()
	_settings_panel.hide()

func _on_play() -> void:
	Settings.apply_display_from_gesture()
	get_tree().change_scene_to_file("res://character_select.tscn")

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://character_select.tscn")

func _on_open_settings() -> void:
	_main_menu.hide()
	_settings_panel.show()

func _on_close_settings() -> void:
	_settings_panel.hide()
	_main_menu.show()

func _on_quit() -> void:
	if OS.has_feature("web"):
		_on_open_settings()
	else:
		get_tree().quit()

