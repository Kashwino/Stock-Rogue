extends Node2D
class_name WorldPrompt
## A world-space interaction prompt in the Noir Props style (Brief 3): the
## thing's name on a small skewed slab, and under it the key to press as a
## typewriter key cap with a short skewed label. Takes the same text the old
## labels did: a line containing "USE / E" becomes the key line, with the
## key read from the current device (E, A or USE).
##   "ALARM PANEL\nHOLD USE / E  —  CUT THE LINE"
##   "MARKET TERMINAL\nUSE / E"
## Unshaded, drawn above the world; redraws only when its text changes.

var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
var color := Palette.GOLD:
	set(v):
		color = v
		queue_redraw()
var _device := ""

func _ready() -> void:
	z_index = 45
	z_as_relative = false
	material = StreetArt._unshaded()

func _process(_delta: float) -> void:
	if visible and TouchInput.device() != _device:
		_device = TouchInput.device()
		queue_redraw()

## Split the text into [title lines, key, action].
func parts() -> Array:
	var titles: Array = []
	var key := ""
	var action := ""
	for line: String in text.split("\n"):
		if line.contains("USE / E") or line.begins_with("INTERACT"):
			key = OnboardingHints.prompt("interact", TouchInput.device())
			var rest := line.replace("HOLD USE / E", "HOLD").replace("USE / E", "").replace("INTERACT:", "").strip_edges()
			rest = rest.replace("  —  ", " · ").replace(" — ", " · ").trim_prefix("·").strip_edges()
			action = rest.to_upper()
		elif line.strip_edges() != "":
			titles.append(line.strip_edges())
	return [titles, key, action]

func _draw() -> void:
	var p := parts()
	var pulp := VisualTheme.font("pulp")
	var y := 0.0
	for title: String in p[0]:
		var w := HudKit.text_width(pulp, title, 14) + 18.0
		var rect := Rect2(Vector2(-w * 0.5, y - 10.0), Vector2(w, 20.0))
		if not HudKit.minimal():
			draw_colored_polygon(HudKit.slant(rect), Color(0.04, 0.04, 0.05, 0.86))
			draw_line(rect.position + Vector2(-rect.size.y * HudKit.SKEW, 0), Vector2(rect.end.x - rect.size.y * HudKit.SKEW, rect.position.y), color, 2.0)
		HudKit.text(self, pulp, Vector2(-w * 0.5 + 9, y + 5), title, 14, color)
		y += 24.0
	var key: String = p[1]
	if key != "":
		var action: String = p[2]
		var total := (HudKit.text_width(pulp, action, 14) + 18.0 if action != "" else 0.0) + 26.0
		HudKit.draw_key_prompt(self, Vector2(-total * 0.5 + 12.0, y + 2.0), key, action, color)
