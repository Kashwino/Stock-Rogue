extends Control
class_name CaseClosed
## CASE CLOSED: the endings gallery, from the home screen. A card for each of
## the eleven endings (in resolution order) plus BUSTED. Reached endings show
## their final image, title and count; the rest are dark silhouettes — with a
## one-line hint once you've reached any ending at all.

signal closed()

const CARD := Vector2(284, 168)
const GAP := Vector2(14, 12)

var _detail: Label
var _cards: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var seen := 0
	for id: StringName in Endings.ORDER:
		if Meta.has_seen_ending(id):
			seen += 1
	var title := VisualTheme.label("CASE CLOSED", "TitleLabel", 46, Palette.GOLD)
	title.position = Vector2(56, 22)
	add_child(title)
	var sub := VisualTheme.label("ENDINGS REACHED  %d / %d" % [seen, Endings.ORDER.size()], "KickerLabel", 18)
	sub.position = Vector2(60, 80)
	add_child(sub)
	var ids: Array = Endings.ORDER.duplicate()
	ids.append(&"busted")
	var x0 := (1280.0 - (4.0 * CARD.x + 3.0 * GAP.x)) * 0.5
	for i in ids.size():
		var card := _card(ids[i], i)
		card.position = Vector2(x0 + (i % 4) * (CARD.x + GAP.x), 112 + (i / 4) * (CARD.y + GAP.y))
		add_child(card)
		_cards.append(card)
	_detail = VisualTheme.label("", "", 17, Palette.PAPER)
	_detail.add_theme_font_override("font", VisualTheme.font("type"))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.position = Vector2(60, 650)
	_detail.size = Vector2(900, 56)
	add_child(_detail)
	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(1060, 652)
	back.size = Vector2(170, 56)
	back.pressed.connect(_close)
	add_child(back)
	if not _cards.is_empty():
		_cards[0].grab_focus.call_deferred()

func _card(id: StringName, index: int) -> Button:
	var busted := id == &"busted"
	var times := int(Meta.endings_seen.get(String(id), 0))
	if busted:
		times = maxi(times, int(Meta.stats.get("deaths", 0)))
	var known := times > 0
	var card := Button.new()
	card.size = CARD
	card.focus_mode = Control.FOCUS_ALL
	var edge: Color = Palette.GOLD_DIM if known else Color(0.25, 0.25, 0.28)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.PANEL_HI if state in ["hover", "focus"] else Palette.PANEL
		sb.border_color = Palette.GOLD if state in ["hover", "focus"] else edge
		sb.set_border_width_all(2 if state in ["hover", "focus"] else 1)
		sb.set_corner_radius_all(4)
		card.add_theme_stylebox_override(state, sb)
	var art := EndingArt.new()
	art.ending = id
	art.silhouette = not known
	art.position = Vector2(6, 6)
	art.size = Vector2(CARD.x - 12, 94)
	card.add_child(art)
	var number := "" if busted else "%02d  " % (index + 1)
	var name_text := Endings.title(id) if known or busted else "? ? ?"
	if busted:
		name_text = "BUSTED" + (" ×%d" % times if times > 0 else "")
	var name_label := VisualTheme.label(number + name_text, "", 17, Palette.GOLD if known else Palette.PAPER_DIM)
	name_label.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	name_label.position = Vector2(10, 104)
	name_label.size = Vector2(CARD.x - 20, 22)
	name_label.clip_text = true
	card.add_child(name_label)
	var note := ""
	if known:
		note = ("SEEN ×%d" % times) + ("  ·  EARLY ENDING" if Endings.is_early(id) else "") if not busted else "The front page always runs the story."
	elif Meta.any_ending_seen():
		note = String(Endings.DATA.get(id, {}).get("hint", "")) if not busted else "Everyone gets caught eventually."
	else:
		note = "Reach any ending for a hint."
	var note_label := VisualTheme.label(note, "", 14, Palette.PAPER_DIM)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.position = Vector2(10, 128)
	note_label.size = Vector2(CARD.x - 20, 38)
	note_label.custom_minimum_size = Vector2(CARD.x - 20, 0)
	card.add_child(note_label)
	card.focus_entered.connect(_show_detail.bind(id, known))
	card.mouse_entered.connect(_show_detail.bind(id, known))
	return card

func _show_detail(id: StringName, known: bool) -> void:
	if id == &"busted":
		_detail.text = "BUSTED — %d times. The front page always runs the story." % int(Meta.stats.get("deaths", 0))
	elif known:
		var lines := Endings.epilogue(id)
		_detail.text = String(lines[0]) if not lines.is_empty() else ""
	elif Meta.any_ending_seen():
		_detail.text = "LOCKED — " + String(Endings.DATA.get(id, {}).get("hint", ""))
	else:
		_detail.text = "LOCKED."

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
