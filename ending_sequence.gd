extends CanvasLayer
class_name EndingSequence
## A winning ending (or an early one: a boss's deal): the city pans by in the
## rain while the epilogue types out, the ending's title slams down with the
## run's numbers and verdicts, the credits roll, a NEW SPECIALIST card
## follows on a first win, then home. The eleven endings live in endings.gd.
## Parented to the root; pauses nothing (the heist is already gone).

var summary: Dictionary = {}
var ending: StringName = &"retired"
## Stop and hide the scene underneath (off for tests and screenshots).
var freeze_beneath := true
var _root: Control
var _city: Control
var _stage := 0
var _title_block: Control
var _credits: VBoxContainer
var _credits_clip: Control
var _button: Button
var _narration: Narration

static func play(host: Node, run_summary: Dictionary) -> EndingSequence:
	var seq := EndingSequence.new()
	seq.summary = run_summary
	seq.ending = StringName(run_summary.get("ending", "retired"))
	if not Endings.has(seq.ending):
		seq.ending = &"retired"
	host.get_tree().root.add_child(seq)
	return seq

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	# The heist beneath stops dead and its HUD goes dark: the ending owns the
	# screen until it hands off to the home screen.
	var beneath := get_tree().current_scene
	if beneath and freeze_beneath:
		beneath.process_mode = Node.PROCESS_MODE_DISABLED
		for layer_node: Node in beneath.find_children("*", "CanvasLayer", true, false):
			layer_node.visible = false
	Audio.loop("alarm", false)
	Audio.loop("heartbeat", false)
	Audio.music(Endings.theme(ending), 1.5)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Palette.BG
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	# The city, twice as wide as the screen, drifting past.
	_city = Control.new()
	_city.position = Vector2.ZERO
	_city.size = Vector2(2600, 720)
	_city.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_city)
	var skyline := MenuBackdrop.new()
	_city.add_child(skyline)
	var pan := create_tween()
	pan.tween_property(_city, "position:x", -1320.0, 34.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	_narration = Narration.new()
	_narration.lines = Endings.epilogue(ending)
	_narration.hold = 2.4
	_narration.position = Vector2(140, 210)
	_narration.size = Vector2(1000, 300)
	_narration.finished.connect(_show_title)
	_root.add_child(_narration)
	_button = Button.new()
	_button.text = "SKIP"
	_button.position = Vector2(1100, 640)
	_button.size = Vector2(150, 56)
	_button.pressed.connect(_on_button)
	_root.add_child(_button)
	_button.grab_focus.call_deferred()

func _on_button() -> void:
	match _stage:
		0:
			_narration.skip_all()
		1:
			_roll_credits()
		2:
			_finish()

## The ending's title, stamped over the city, with the run's numbers.
func _show_title() -> void:
	if _stage != 0:
		return
	_stage = 1
	_narration.hide()
	_button.text = "CREDITS"
	_title_block = Control.new()
	_title_block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_block)
	_root.move_child(_button, -1)
	var data: Dictionary = Endings.DATA.get(ending, {})
	var family := Endings.family(ending)
	var ink: Color = {"rule": Palette.GOLD, "collapse": Palette.DANGER, "escape": Palette.NEON_CYAN}.get(family, Palette.PAPER)
	var kicker := VisualTheme.label(String(data.get("kicker", "ENDING")), "KickerLabel", 22)
	kicker.position = Vector2(90, 90)
	_title_block.add_child(kicker)
	var title_text := Endings.title(ending)
	var title := VisualTheme.label(title_text, "TitleLabel", 104 if title_text.length() <= 16 else 80, ink)
	title.position = Vector2(84, 120)
	_title_block.add_child(title)
	var who := VisualTheme.label(String(summary.get("who", "The Operator")).to_upper(), "", 28, Palette.GOLD_PALE)
	who.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	who.position = Vector2(92, 250)
	_title_block.add_child(who)
	var facts := [
		"HEISTS PULLED ....... %d" % int(summary.get("heists", 0)),
		"BOARD INDEX ......... %d" % roundi(float(summary.get("index", 1.0))),
		"CASH ON HAND ........ $%d" % int(summary.get("gold", 0)),
		"GUARDS DOWN ......... %d" % int(summary.get("kills", 0)),
	]
	if summary.has("clout"):
		facts.append("CLOUT EARNED ........ +%d" % int(summary["clout"]))
	var rep: Array = summary.get("reputation", [0, 0, 0])
	facts.append("FEAR %d · LOYALTY %d · GREED %d" % [int(rep[0]), int(rep[1]), int(rep[2])])
	var stats := VisualTheme.label("\n".join(facts), "", 22, Palette.PAPER)
	stats.add_theme_font_override("font", VisualTheme.font("mono"))
	stats.position = Vector2(92, 320)
	_title_block.add_child(stats)
	var stamp := StampArt.new()
	stamp.text = String(data.get("stamp", "CASE CLOSED"))
	stamp.ink = {"rule": Palette.GOLD, "collapse": Palette.STAMP_RED}.get(family, Palette.STAMP_GREEN)
	stamp.font_size = 44
	stamp.tilt = -0.14
	_title_block.add_child(stamp)
	stamp.position = Vector2(760, 330)
	stamp.slam(0.5)
	_title_block.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_title_block, "modulate:a", 1.0, 0.6)
	tw.tween_interval(6.0)
	tw.tween_callback(_roll_credits)
	Audio.play_ui("stamp")

func _roll_credits() -> void:
	if _stage != 1:
		return
	_stage = 2
	_button.text = "BACK TO THE STREET"
	_button.size = Vector2(300, 56)
	_button.position = Vector2(950, 640)
	var fade := create_tween()
	fade.tween_property(_title_block, "modulate:a", 0.0, 0.6)
	_credits_clip = Control.new()
	_credits_clip.position = Vector2(0, 0)
	_credits_clip.size = Vector2(1280, 720)
	_credits_clip.clip_contents = true
	_credits_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_credits_clip)
	_root.move_child(_button, -1)
	_credits = VBoxContainer.new()
	_credits.custom_minimum_size = Vector2(1280, 0)
	_credits.add_theme_constant_override("separation", 14)
	_credits.position = Vector2(0, 740)
	_credits_clip.add_child(_credits)
	for entry: Array in credits_lines():
		var l := VisualTheme.label(entry[0], "", entry[1], entry[2])
		l.add_theme_font_override("font", VisualTheme.font("heading_bold" if entry[1] >= 30 else "type_bold"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(1280, 0)
		_credits.add_child(l)
	var roll := create_tween()
	roll.tween_property(_credits, "position:y", -1500.0, 26.0)
	roll.tween_callback(_finish)

## [text, size, colour] rows for the roll.
static func credits_lines() -> Array:
	var gold := Palette.GOLD
	var paper := Palette.PAPER
	var dim := Palette.PAPER_DIM
	return [
		["STOCK ROGUE", 64, gold],
		["a noir heist roguelike on a crooked stock exchange", 20, dim],
		["", 20, dim],
		["A GAME BY", 18, dim],
		[Story.CREDITS_NAME, 44, paper],
		["", 20, dim],
		["DESIGN · CODE · ART · SOUND · MUSIC", 18, dim],
		[Story.CREDITS_NAME, 30, paper],
		["every sprite, room, sound and note generated in-engine", 18, dim],
		["", 20, dim],
		["TYPE", 18, dim],
		["Oswald  ·  Barlow Semi Condensed  ·  Courier Prime  ·  IBM Plex Mono", 20, paper],
		["under the SIL Open Font License", 16, dim],
		["", 20, dim],
		["MADE WITH", 18, dim],
		["Godot Engine", 30, paper],
		["", 20, dim],
		["THE BOARD WOULD LIKE TO THANK", 18, dim],
		["every crew that missed a quota", 20, paper],
		["", 20, dim],
		["", 20, dim],
		["THANKS FOR PLAYING", 44, gold],
	]

func _finish() -> void:
	if _stage == 3:
		return
	_stage = 3
	var fresh: Array = summary.get("new_specialists", [])
	if not fresh.is_empty():
		var popup := SpecialistPopup.present(self, fresh)
		if popup:
			popup.finished.connect(_go_home)
			return
	_go_home()

func _go_home() -> void:
	RunFlow.queue_scene("res://home_screen.tscn")
	queue_free()
