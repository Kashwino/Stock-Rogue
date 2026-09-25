extends Button
class_name TypewriterKey
## MAP and PAUSE as round typewriter keys in brass rings (Brief 3). Real
## buttons: hover lifts the key, a press sinks it with a click.

var icon_name := ""
var caption := ""
var _hover := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	button_down.connect(_on_down)
	button_up.connect(queue_redraw)
	set_meta("qa_label", caption)

func _on_hover(on: bool) -> void:
	_hover = on
	queue_redraw()

func _on_down() -> void:
	Audio.play_ui("ui_click")
	queue_redraw()

func _draw() -> void:
	var r := minf(size.x, size.y - 14.0) * 0.5
	var c := Vector2(size.x * 0.5, r + 2)
	var lift := -2.0 if is_pressed() else (2.0 if _hover else 0.0)
	if HudKit.minimal():
		draw_arc(c, r - 2, 0, TAU, 24, Palette.PAPER, 2.0, true)
		HudKit.draw_icon(self, icon_name, c, r * 0.42, Palette.PAPER)
	else:
		HudKit.draw_typewriter_key(self, c, r, "", lift, icon_name)
	HudKit.text_centered(self, VisualTheme.font("heading_bold"), Vector2(size.x * 0.5, size.y - 6), caption, 13, Palette.PAPER_CREAM)
