extends CanvasLayer
class_name ResultsScreen

## Post-heist job report: a typed sheet on the desk, the grade slammed on as a
## rubber stamp, the numbers, the stock move and the money. Built in code
## under one full-rect Control root; pauses the tree while shown and emits
## `continued` when dismissed.

signal continued

const GRADE_COLORS := {
	"S+": Palette.GOLD, "S": Palette.GOLD, "A": Palette.STAMP_GREEN,
	"B": Color("2a5a9a"), "C": Color("6a6a6a"), "D": Palette.STAMP_RED,
}
const VERDICTS := {
	"S+": "They'll tell stories about this one.",
	"S": "Professional work.",
	"A": "Clean enough. You got paid.",
	"B": "Messy, but you walked out.",
	"C": "That could have gone better.",
	"D": "You're lucky to be breathing.",
}

var _root: Control
var _sheet: PaperSheet
var _rows: VBoxContainer
var _title: Label
var _sub: Label
var _stamp: StampArt
var _verdict: Label
var _stock_label: Label
var _continue_button: Button
var _shown: bool = false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_sheet = PaperSheet.new()
	_sheet.stock = Palette.PAPER
	_sheet.position = Vector2(250, 26)
	_sheet.size = Vector2(780, 640)
	_sheet.rotation = -0.012
	_root.add_child(_sheet)
	_title = _type("JOB REPORT", Vector2(90, 24), 34, true)
	_title.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	_sub = _type("", Vector2(90, 70), 18, false)
	_rows = VBoxContainer.new()
	_rows.position = Vector2(90, 118)
	_rows.custom_minimum_size = Vector2(430, 0)
	_rows.add_theme_constant_override("separation", 4)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_rows)
	_verdict = _type("", Vector2(90, 470), 22, true)
	_verdict.custom_minimum_size = Vector2(620, 0)
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stock_label = _type("", Vector2(90, 520), 26, true)
	_stock_label.add_theme_font_override("font", VisualTheme.font("mono"))
	_stamp = StampArt.new()
	_stamp.text = "A"
	_stamp.font_size = 120
	_stamp.tilt = -0.18
	_sheet.add_child(_stamp)
	_continue_button = Button.new()
	_continue_button.text = "BACK TO THE CASE WALL"
	_continue_button.theme_type_variation = "PrimaryButton"
	_continue_button.position = Vector2(440, 574)
	_continue_button.size = Vector2(300, 54)
	_continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_continue_button.set_meta("qa_label", "Back to the map")
	_continue_button.pressed.connect(_on_continue)
	_sheet.add_child(_continue_button)

func _type(text: String, at: Vector2, size: int, bold: bool) -> Label:
	var l := VisualTheme.label(text, "", size, Palette.INK)
	l.add_theme_font_override("font", VisualTheme.font("type_bold" if bold else "type"))
	l.position = at
	_sheet.add_child(l)
	return l

func show_result(result: Dictionary, venue_name: String = "") -> void:
	var g: String = result.get("grade_name", "?")
	var venue := StringName(venue_name)
	_title.text = "JOB REPORT — " + Venues.sign_name(venue, StringName(result.get("boss_id", "")))
	_sub.text = "CASE %s  ·  %s  ·  FILED BY THE FENCE" % [str(RunFlow.heists_completed + 1).pad_zeros(3), Venues.display_name(venue).to_upper()]
	var stats: Dictionary = result.get("stats", {})
	var b: Dictionary = result.get("breakdown", {})
	for c in _rows.get_children():
		c.queue_free()
	_add_row("Hits taken", str(stats.get("hits_taken", 0)))
	_add_row("Accuracy", "%d%%" % int(b.get("accuracy", 0.0) * 100))
	_add_row("Time on site", _fmt_time(stats.get("time_seconds", 0.0)))
	_add_row("Guards down", "%d / %d" % [stats.get("kills", 0), stats.get("enemies_total", 0)])
	if result.has("loot"):
		_add_row("Loot banked", "$%d" % int(result["loot"]))
	_add_row("Intel banked", "+%d" % int(result.get("intel", 0)) if result.get("meta_saved", true) else "not saved on this device")
	var short_result: Dictionary = result.get("short", {})
	if not short_result.is_empty():
		_add_row("Short settled", "$%d back (%+d)" % [short_result["payout"], short_result["profit"]])
	for line: String in result.get("extra_rows", []):
		var parts := line.split("|")
		_add_row(parts[0], parts[1] if parts.size() > 1 else "")
	_verdict.text = "\"" + VERDICTS.get(g, "") + "\""
	var delta: float = result.get("stock_delta", 1.0)
	var pct: float = (delta - 1.0) * 100.0
	_stock_label.text = "%s  %s%.0f%%   ·   INDEX %d" % [Venues.ticker(venue), "+" if pct >= 0.0 else "", pct, roundi(RunState.empire_index())]
	_stock_label.add_theme_color_override("font_color", Palette.STAMP_GREEN if pct >= 0.0 else Palette.STAMP_RED)
	_stamp.set_text(g)
	_stamp.ink = GRADE_COLORS.get(g, Palette.INK)
	_stamp.position = Vector2(560, 150)
	_root.show()
	_shown = true
	get_tree().paused = true
	_stamp.slam(0.35)
	_continue_button.grab_focus()

func _add_row(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := VisualTheme.label(label.to_upper(), "", 20, Color("4a4030"))
	l.add_theme_font_override("font", VisualTheme.font("type"))
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var v := VisualTheme.label(value, "", 20, Palette.INK)
	v.add_theme_font_override("font", VisualTheme.font("type_bold"))
	row.add_child(v)
	_rows.add_child(row)

func _fmt_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	return "%d:%02d" % [m, s]

func _on_continue() -> void:
	if not _shown:
		return
	_shown = false
	get_tree().paused = false
	_root.hide()
	continued.emit()

## Never leave the game frozen if this is torn down while visible.
func _exit_tree() -> void:
	if _shown and is_inside_tree():
		get_tree().paused = false
