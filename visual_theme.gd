extends Node
class_name VisualTheme
## Shared visual language; game-state logic never depends on these decorations.
const INK := Color("0b1219")
const PANEL := Color("14232c")
const EDGE := Color("31464e")
const GOLD := Color("ecc879")
const TEAL := Color("69d6c4")
const WHITE := Color("eef1e9")

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Button and not node is OptionButton and not node is CheckButton and node.text != "":
		_style_button.call_deferred(node)

func _style_button(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var button := node as Button
	if button.text == "" or button.has_meta("item"):
		return
	var primary := button.text in ["PLAY", "RESUME", "QUICK HEIST", "Back to the map"]
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := panel(GOLD if primary else EDGE, 14)
		box.bg_color = Color("273a3f") if state in ["hover", "focus"] else PANEL
		if primary:
			box.bg_color = GOLD if state != "hover" else Color("ffe4a5")
		if state == "pressed":
			box.bg_color = Color("bb9954") if primary else Color("304d53")
		if state == "disabled":
			box.bg_color = Color("131c24")
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK if primary else GOLD)
	button.add_theme_color_override("font_pressed_color", INK if primary else GOLD)
	button.add_theme_color_override("font_focus_color", INK if primary else GOLD)
	button.add_theme_color_override("font_disabled_color", Color("779097"))
	button.add_theme_font_size_override("font_size", 22)

static func panel(accent: Color = EDGE, padding: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.043, 0.071, 0.094, 0.96)
	box.border_color = accent
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(padding)
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 6
	return box
