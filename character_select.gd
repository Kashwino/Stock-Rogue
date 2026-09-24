extends CanvasLayer
class_name CharacterSelect

## The pre-run flow, styled as a criminal dossier:
##   PHASE 1 — CASE FILES: three game files. An active file resumes its run;
##             an empty one moves on to crew selection. Files can be burned.
##   PHASE 2 — THE CREW: five specialists on mugshot cards. The Operator walks
##             free; four are locked behind feats tracked in Meta.
## Scene: CanvasLayer root + this script. Everything is built in code.

const CREW := [
	{
		"id": &"operator", "name": "THE OPERATOR", "role": "All-rounder", "unlocked": true,
		"blurb": "Steady hands, no habits, no records. The one every fence trusts.",
		"hearts": 3, "trait": "Volatility x1.0 to x2.5",
		"profile": "res://crew_operator.tres",
	},
	{
		"id": &"ghost", "name": "THE GHOST", "role": "Infiltrator", "unlocked": false,
		"blurb": "Nobody ever heard them coming. Nobody ever heard them leave.",
		"hearts": 2, "trait": "Volatility x1.5 to x3.0\nSilent movement, gunshots -40%, cameras slower. Starts with a Silenced 9mm.",
		"unlock": "Slip out a fire exit 5 times",
		"profile": "res://crew_ghost.tres",
	},
	{
		"id": &"wolf", "name": "THE WOLF", "role": "Heavy", "unlocked": false,
		"blurb": "Doesn't case the place. Doesn't need to.",
		"hearts": 4, "trait": "Volatility x0.8 to x2.0\n+25% damage. Getting hit makes noise.",
		"unlock": "Put down 3 bosses",
		"profile": "res://crew_wolf.tres",
	},
	{
		"id": &"broker", "name": "THE BROKER", "role": "Market fixer", "unlocked": false,
		"blurb": "Half the trades on the feed are theirs. The other half are lies.",
		"hearts": 2, "trait": "Volatility x2.0 to x4.0\nSwings x1.5, 3 positions, leverage 3, Fence -25%.",
		"unlock": "Reach Index 350 in one run",
		"profile": "res://crew_broker.tres",
	},
	{
		"id": &"legend", "name": "THE LEGEND", "role": "One last job", "unlocked": false,
		"blurb": "Retired once already. This time it's personal — and it's all in.",
		"hearts": 1, "trait": "Volatility x3.0 flat\nNo healing. Gold and stock gains x2. Starts with a Classified+ weapon.",
		"unlock": "Retire — win a full run",
		"profile": "res://crew_legend.tres",
	},
]

var _root: Control
var _phase_holder: Control
var _chosen_slot: int = -1

func _ready() -> void:
	layer = 60
	for child in get_children():
		child.queue_free()
	_build_frame()
	_show_case_files()

func _build_frame() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	var bg := MenuBackdrop.new()
	_root.add_child(bg)
	var desk := CaseWallArt.Corkboard.new()
	desk.modulate = Color(1, 1, 1, 0.92)
	_root.add_child(desk)
	_phase_holder = Control.new()
	_phase_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_phase_holder)

func _clear_phase() -> void:
	for c in _phase_holder.get_children():
		c.queue_free()

func _title(kicker: String, title: String) -> void:
	var strip := Panel.new()
	strip.position = Vector2(40, 24)
	strip.size = Vector2(620, 88)
	strip.rotation = -0.01
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", VisualTheme.paper(Palette.PAPER, 0))
	_phase_holder.add_child(strip)
	var k := VisualTheme.label(kicker, "", 18, Palette.STAMP_RED)
	k.add_theme_font_override("font", VisualTheme.font("type_bold"))
	k.position = Vector2(22, 10)
	strip.add_child(k)
	var t := VisualTheme.label(title, "", 42, Palette.INK)
	t.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	t.position = Vector2(20, 28)
	strip.add_child(t)

func _back_button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = Vector2(40, 636)
	b.size = Vector2(300, 60)
	b.pressed.connect(action)
	_phase_holder.add_child(b)

# ------------------------------------------------------- phase 1: files -----
func _show_case_files() -> void:
	_clear_phase()
	_title("PROPERTY OF THE FENCE — EYES ONLY", "CASE FILES")
	var first: Button = null
	for i in RunSave.SLOT_COUNT:
		var card := _make_file_card(i)
		card.position = Vector2(110 + i * 370, 150)
		_phase_holder.add_child(card)
		if first == null:
			first = card
	_back_button("< BACK TO THE STREET", _to_home)
	if first:
		first.grab_focus.call_deferred()

func _to_home() -> void:
	RunFlow.queue_scene("res://home_screen.tscn")

func _make_file_card(i: int) -> Button:
	var data := RunSave.peek(i)
	var active := not data.is_empty()
	var card := DossierCard.new()
	card.size = Vector2(320, 440)
	card.stock = Palette.MANILA
	card.base_tilt = [-0.02, 0.015, -0.01][i]
	card.pressed.connect(_on_file_chosen.bind(i))
	card.tab_text = "CASE FILE %02d" % (i + 1)
	var lines: Array = []
	if active:
		var stage_names := ["Town", "City", "World", "Doomsday"]
		var st: int = clampi(int(data.get("stage", 0)), 0, 3)
		var profile_path: String = data.get("profile_path", "")
		var who := "The Operator"
		for c: Dictionary in CREW:
			if c.get("profile", "") == profile_path:
				who = String(c["name"]).capitalize()
		lines = ["SUBJECT: %s" % who, "LAST SEEN: %s" % stage_names[st], "CASH: $%d" % int(data.get("gold", 0)),
			"HEISTS: %d" % int(data.get("heists_completed", 0)), "", "Open the file to pick", "the job back up."]
		card.stamp_text = "ACTIVE"
		card.stamp_color = Palette.STAMP_RED
	else:
		lines = ["A clean folder.", "No history, no heat,", "no name on it yet.", "", "Open it to put a", "crew together."]
		card.stamp_text = "EMPTY"
		card.stamp_color = Palette.MUTED
	card.body_lines = lines
	if active:
		var burn := Button.new()
		burn.text = "BURN FILE"
		burn.theme_type_variation = "DangerButton"
		burn.position = Vector2(24, 368)
		burn.size = Vector2(150, 46)
		burn.add_theme_font_size_override("font_size", 18)
		burn.pressed.connect(_burn.bind(i))
		card.add_child(burn)
	return card

func _burn(i: int) -> void:
	RunSave.delete_slot(i)
	_show_case_files()

func _on_file_chosen(i: int) -> void:
	_chosen_slot = i
	RunSave.slot = i
	if RunSave.slot_has_run(i):
		RunFlow.continue_run()
	else:
		_show_crew()

# -------------------------------------------------------- phase 2: crew -----
func _show_crew() -> void:
	_clear_phase()
	_title("CASE FILE %02d — RECRUITMENT" % (_chosen_slot + 1), "CHOOSE YOUR SPECIALIST")
	var first: Button = null
	for i in CREW.size():
		var c: Dictionary = CREW[i]
		var card := _make_crew_card(c)
		card.position = Vector2(28 + i * 248, 136)
		card.base_tilt = [-0.02, 0.012, -0.008, 0.018, -0.014][i]
		_phase_holder.add_child(card)
		if first == null and not card.disabled:
			first = card
	_back_button("< CASE FILES", _show_case_files)
	if first:
		first.grab_focus.call_deferred()

func _make_crew_card(c: Dictionary) -> Button:
	var unlocked: bool = c["unlocked"] or Meta.is_specialist_unlocked(c["id"])
	var card := DossierCard.new()
	card.size = Vector2(232, 490)
	card.stock = Palette.PAPER if unlocked else Color("8a857a")
	card.tab_text = String(c["role"]).to_upper()
	card.disabled = not unlocked
	card.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	if unlocked:
		card.pressed.connect(_on_crew_chosen.bind(c))
	var portrait := PortraitArt.new()
	portrait.who = c["id"]
	portrait.unlocked = unlocked
	portrait.position = Vector2(26, 44)
	portrait.size = Vector2(180, 150)
	card.add_child(portrait)
	var name_l := VisualTheme.label(c["name"], "", 24, Palette.INK)
	name_l.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	name_l.position = Vector2(16, 200)
	card.add_child(name_l)
	var hearts := HudWidgets.Hearts.new()
	hearts.position = Vector2(16, 236)
	hearts.size = Vector2(200, 30)
	hearts.set_health(c["hearts"], c["hearts"])
	card.add_child(hearts)
	var body := VisualTheme.label(c["trait"] + ("\n\n" + c["blurb"] if unlocked else ""), "", 15, Color("2a2418"))
	body.add_theme_font_override("font", VisualTheme.font("type"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(200, 0)
	body.position = Vector2(16, 272)
	body.size = Vector2(200, 170)
	card.add_child(body)
	if unlocked:
		card.stamp_text = "HIRE"
		card.stamp_color = Palette.STAMP_GREEN
	else:
		card.stamp_text = "LOCKED"
		card.stamp_color = Palette.STAMP_RED
		var how := VisualTheme.label(c.get("unlock", ""), "", 16, Palette.STAMP_RED)
		how.add_theme_font_override("font", VisualTheme.font("type_bold"))
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size = Vector2(200, 0)
		how.position = Vector2(16, 426)
		how.size = Vector2(200, 50)
		card.add_child(how)
	return card

func _on_crew_chosen(c: Dictionary) -> void:
	var profile = null
	var path: String = c.get("profile", "")
	if path != "" and ResourceLoader.exists(path):
		profile = load(path)
	RunSave.delete_run()          # fresh job in this file
	RunFlow.start_new_run(profile)


## A paper dossier card: tabbed folder drawn behind child content, a rubber
## stamp in the corner, hover tilt. Flat Button so mouse/keys/touch all work.
class DossierCard extends Button:
	var stock := Palette.MANILA
	var tab_text := ""
	var stamp_text := ""
	var stamp_color := Palette.STAMP_RED
	var body_lines: Array = []
	var base_tilt := 0.0
	var _stamp: StampArt

	func _ready() -> void:
		text = ""
		var clear := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, clear)
		pivot_offset = size * 0.5
		rotation = base_tilt
		mouse_entered.connect(_lift.bind(true))
		mouse_exited.connect(_lift.bind(false))
		focus_entered.connect(_lift.bind(true))
		focus_exited.connect(_lift.bind(false))
		var y := 60.0
		for line: String in body_lines:
			var l := VisualTheme.label(line, "", 19, Palette.INK)
			l.add_theme_font_override("font", VisualTheme.font("type"))
			l.position = Vector2(22, y)
			add_child(l)
			y += 30.0
		if stamp_text != "":
			_stamp = StampArt.new()
			_stamp.text = stamp_text
			_stamp.ink = stamp_color
			_stamp.font_size = 26
			_stamp.tilt = -0.2
			add_child(_stamp)
			if disabled:
				_stamp.position = Vector2(size.x * 0.5 - _stamp.size.x * 0.5, 96)
			else:
				_stamp.position = Vector2(size.x - _stamp.size.x - 10, size.y - _stamp.size.y - 16)
			_stamp.slam(randf_range(0.05, 0.3))
		for child in get_children():
			if child is Control and not child is Button:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _lift(up: bool) -> void:
		if disabled:
			return
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "rotation", 0.0 if up else base_tilt, 0.12)
		tw.tween_property(self, "scale", Vector2(1.04, 1.04) if up else Vector2.ONE, 0.12)
		var audio := get_node_or_null("/root/Audio")
		if up and audio:
			audio.play_ui("hover")

	func _draw() -> void:
		var r := Rect2(Vector2(0, 18), size - Vector2(0, 18))
		draw_rect(Rect2(r.position + Vector2(7, 9), r.size), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(Vector2(14, 0), Vector2(150, 26)), stock.darkened(0.08))
		draw_rect(r, stock)
		draw_rect(r, stock.darkened(0.35), false, 2.0)
		draw_string(VisualTheme.font("type_bold"), Vector2(24, 19), tab_text, HORIZONTAL_ALIGNMENT_LEFT, 140, 15, Palette.INK)
		if (has_focus() or is_hovered()) and not disabled:
			draw_rect(r.grow(3), Palette.GOLD, false, 3.0)
		if disabled:
			draw_rect(r, Color(0, 0, 0, 0.18))
