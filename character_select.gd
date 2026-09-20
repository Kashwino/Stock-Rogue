extends CanvasLayer
class_name CharacterSelect

## The pre-run flow, styled as a criminal dossier:
##   PHASE 1 — CASE FILES: three game files. An active file resumes its run;
##             an empty one moves on to crew selection. Files can be burned.
##   PHASE 2 — THE CREW: five specialists on wanted-poster cards. One walks
##             free; four are locked behind feats.
##
## Scene: CanvasLayer root + this script. Everything is built in code.

const GOLD := Color(0.91, 0.72, 0.26)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const PAPER := Color(0.86, 0.82, 0.72)
const INK := Color(0.10, 0.10, 0.12)
const BG := Color(0.045, 0.045, 0.06)
const PANEL := Color(0.10, 0.10, 0.13)
const PANEL_EDGE := Color(0.24, 0.24, 0.3)
const RED := Color(0.78, 0.22, 0.2)

const CREW := [
	{
		"id": &"operator", "name": "THE OPERATOR", "mono": "O",
		"role": "All-rounder", "unlocked": true,
		"blurb": "Steady hands, no habits, no records. The one every fence trusts.",
		"hearts": "♥♥♥", "trait": "volatility x1.0 to x2.5",
		"profile": "res://main_character.tres",
	},
	{
		"id": &"ghost", "name": "THE GHOST", "mono": "G",
		"role": "Infiltrator", "unlocked": false,
		"blurb": "Nobody ever heard them coming. Nobody ever heard them leave.",
		"hearts": "♥♥", "trait": "volatility x1.5 to x3.0\nsilent movement, guards hear nothing",
		"unlock": "Slip out a fire exit 5 times",
	},
	{
		"id": &"wolf", "name": "THE WOLF", "mono": "W",
		"role": "Heavy", "unlocked": false,
		"blurb": "Doesn't case the place. Doesn't need to.",
		"hearts": "♥♥♥♥", "trait": "volatility x0.8 to x2.0\nhits harder, bleeds louder",
		"unlock": "Put down 3 bosses",
	},
	{
		"id": &"broker", "name": "THE BROKER", "mono": "B",
		"role": "Market fixer", "unlocked": false,
		"blurb": "Half the trades on the feed are theirs. The other half are lies.",
		"hearts": "♥♥", "trait": "volatility x2.0 to x4.0\nstock swings amplified both ways",
		"unlock": "Reach Index 350 in one run",
	},
	{
		"id": &"legend", "name": "THE LEGEND", "mono": "L",
		"role": "One last job", "unlocked": false,
		"blurb": "Retired once already. This time it's personal — and it's all in.",
		"hearts": "♥", "trait": "volatility x3.0 flat\none life, all in",
		"unlock": "Retire — win a full run",
	},
]

var _root: Control
var _phase_holder: Control
var _chosen_slot: int = -1

func _ready() -> void:
	layer = 60
	_build_frame()
	_show_case_files()

# ------------------------------------------------------------------ frame ---
func _build_frame() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	var bg := MenuBackdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Faint diagonal caution stripes along the top and bottom edges.
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

	_phase_holder = Control.new()
	_phase_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_phase_holder)

func _clear_phase() -> void:
	for c in _phase_holder.get_children():
		c.queue_free()

func _title_block(parent: Control, kicker: String, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 60; col.offset_right = -60
	col.offset_top = 34; col.offset_bottom = -30
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(col)

	var k := Label.new()
	k.text = kicker
	k.add_theme_font_size_override("font_size", 18)
	k.add_theme_color_override("font_color", GOLD_DIM)
	col.add_child(k)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", GOLD)
	col.add_child(t)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = GOLD_DIM
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	return col

func _back_button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 74)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	parent.add_child(b)

# ------------------------------------------------------- phase 1: files -----
func _show_case_files() -> void:
	_clear_phase()
	var col := _title_block(_phase_holder, "PROPERTY OF THE FENCE — EYES ONLY",
		"CASE FILES")

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)

	for i in RunSave.SLOT_COUNT:
		row.add_child(_make_file_card(i))

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(foot)
	_back_button(foot, "← Back to the street", func():
		RunFlow.queue_scene("res://home_screen.tscn"))

func _make_file_card(i: int) -> Control:
	var data := RunSave.peek(i)
	var active := not data.is_empty()

	var card := Button.new()
	card.custom_minimum_size = Vector2(240, 300)
	card.focus_mode = Control.FOCUS_ALL
	_style_card(card, GOLD if active else PANEL_EDGE)
	card.pressed.connect(_on_file_chosen.bind(i))

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 16; inner.offset_right = -16
	inner.offset_top = 16; inner.offset_bottom = -14
	inner.add_theme_constant_override("separation", 8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	# Manila-folder tab.
	var tab := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = PAPER
	tsb.set_corner_radius_all(3)
	tsb.content_margin_left = 10; tsb.content_margin_right = 10
	tsb.content_margin_top = 3; tsb.content_margin_bottom = 3
	tab.add_theme_stylebox_override("panel", tsb)
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_l := Label.new()
	tab_l.text = "CASE FILE %02d" % (i + 1)
	tab_l.add_theme_font_size_override("font_size", 18)
	tab_l.add_theme_color_override("font_color", INK)
	tab.add_child(tab_l)
	inner.add_child(tab)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 17)
	inner.add_child(status)

	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", Color(0.62, 0.62, 0.7))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(detail)

	if active:
		status.text = "JOB IN PROGRESS"
		status.add_theme_color_override("font_color", GOLD)
		var stage_names := ["Town", "City", "Capital", "Final Boss"]
		var st: int = clampi(int(data.get("stage", 0)), 0, 3)
		detail.text = "Reached: %s\nGold on hand: ⦿ %d\n\nOpen the file to pick the job back up." % [
			stage_names[st], int(data.get("gold", 0))]

		# Burn button for an active file.
		var burn := Button.new()
		burn.text = "🔥 Burn file"
		burn.add_theme_font_size_override("font_size", 18)
		burn.custom_minimum_size = Vector2(0, 30)
		burn.pressed.connect(func():
			RunSave.delete_slot(i)
			_show_case_files())
		inner.add_child(burn)
	else:
		status.text = "EMPTY"
		status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.58))
		detail.text = "A clean folder. No history, no heat, no name on it yet.\n\nOpen it to put a crew together."

	return card

func _on_file_chosen(i: int) -> void:
	_chosen_slot = i
	RunSave.slot = i
	if RunSave.slot_has_run(i):
		# Resume the job exactly where the file left off.
		RunFlow.continue_run()
	else:
		RunFlow.open_preparation()

# -------------------------------------------------------- phase 2: crew -----
func _show_crew() -> void:
	_clear_phase()
	var col := _title_block(_phase_holder,
		"CASE FILE %02d — RECRUITMENT" % (_chosen_slot + 1), "CHOOSE YOUR SPECIALIST")

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)

	for c: Dictionary in CREW:
		row.add_child(_make_crew_card(c))

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(foot)
	_back_button(foot, "← Case files", _show_case_files)

func _make_crew_card(c: Dictionary) -> Control:
	var unlocked: bool = c["unlocked"]
	var card := Button.new()
	card.custom_minimum_size = Vector2(196, 340)
	card.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	card.disabled = not unlocked
	_style_card(card, GOLD if unlocked else Color(0.2, 0.2, 0.24))
	if unlocked:
		card.pressed.connect(_on_crew_chosen.bind(c))

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 14; inner.offset_right = -14
	inner.offset_top = 16; inner.offset_bottom = -14
	inner.add_theme_constant_override("separation", 7)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	# Monogram medallion — the "mugshot".
	var med_wrap := CenterContainer.new()
	med_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(med_wrap)
	var med := PanelContainer.new()
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.16, 0.16, 0.2) if unlocked else Color(0.11, 0.11, 0.13)
	msb.border_color = GOLD if unlocked else Color(0.3, 0.3, 0.34)
	msb.set_border_width_all(2)
	msb.set_corner_radius_all(40)
	med.add_theme_stylebox_override("panel", msb)
	med.custom_minimum_size = Vector2(80, 80)
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	med_wrap.add_child(med)
	var portrait := PortraitArt.new()
	portrait.unlocked = unlocked
	med.add_child(portrait)

	var name_l := Label.new()
	name_l.text = c["name"]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color",
		Color.WHITE if unlocked else Color(0.5, 0.5, 0.56))
	inner.add_child(name_l)

	var role_l := Label.new()
	role_l.text = "— %s —" % c["role"]
	role_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_l.add_theme_font_size_override("font_size", 18)
	role_l.add_theme_color_override("font_color", GOLD_DIM)
	inner.add_child(role_l)

	# Health and trait on their own lines so nothing crowds the card edge.
	var hearts_l := Label.new()
	hearts_l.text = c["hearts"]
	hearts_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hearts_l.add_theme_font_size_override("font_size", 18)
	hearts_l.add_theme_color_override("font_color",
		Color(0.9, 0.45, 0.45) if unlocked else Color(0.45, 0.38, 0.4))
	inner.add_child(hearts_l)

	var trait_l := Label.new()
	trait_l.text = c["trait"]
	trait_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_l.add_theme_font_size_override("font_size", 18)
	trait_l.add_theme_color_override("font_color",
		Color(0.85, 0.6, 0.6) if unlocked else Color(0.42, 0.42, 0.48))
	inner.add_child(trait_l)

	var blurb := Label.new()
	blurb.text = c["blurb"]
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 18)
	blurb.add_theme_color_override("font_color",
		Color(0.6, 0.6, 0.68) if unlocked else Color(0.36, 0.36, 0.42))
	blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(blurb)

	if unlocked:
		var hire := Label.new()
		hire.text = "▸ TAKE THE JOB"
		hire.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hire.add_theme_font_size_override("font_size", 18)
		hire.add_theme_color_override("font_color", GOLD)
		inner.add_child(hire)
	else:
		# Red LOCKED stamp, slightly askew like it was slammed on.
		var stamp := Label.new()
		stamp.text = "L O C K E D"
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_theme_font_size_override("font_size", 15)
		stamp.add_theme_color_override("font_color", RED)
		stamp.rotation = -0.07
		stamp.pivot_offset = Vector2(80, 10)
		inner.add_child(stamp)
		var how := Label.new()
		how.text = c.get("unlock", "")
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.add_theme_font_size_override("font_size", 18)
		how.add_theme_color_override("font_color", Color(0.55, 0.4, 0.4))
		inner.add_child(how)

	return card

func _on_crew_chosen(c: Dictionary) -> void:
	var profile = null
	var path: String = c.get("profile", "")
	if path != "" and ResourceLoader.exists(path):
		profile = load(path)
	RunSave.delete_run()          # fresh job in this file
	RunFlow.start_new_run(profile)

# ------------------------------------------------------------------ style ---
func _style_card(card: Button, edge: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL
		if state == "hover" or state == "focus":
			sb.bg_color = Color(0.14, 0.14, 0.18)
		elif state == "pressed":
			sb.bg_color = Color(0.07, 0.07, 0.09)
		elif state == "disabled":
			sb.bg_color = Color(0.075, 0.075, 0.095)
		sb.border_color = edge if state != "hover" and state != "focus" \
			else Color(1.0, 0.85, 0.4)
		sb.set_border_width_all(2 if state == "normal" or state == "disabled" else 3)
		sb.set_corner_radius_all(6)
		card.add_theme_stylebox_override(state, sb)
