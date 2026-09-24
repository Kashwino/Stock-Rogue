extends CanvasLayer
## The run map as a case wall: a corkboard with the stage header, the route's
## steps as pinned index cards joined by red string, and the current step up
## front — the hideout, the job leads as pinned case files, the collector's
## sit-down, or the stage hand-off. Built in code under one full-rect root.

signal heist_chosen(node)
signal hideout_requested()
signal hideout_skipped()
signal quota_faced()
signal stage_advanced()
signal run_complete()

const STEP_LABELS := {
	RunMap.StepKind.SHOP: "HIDEOUT",
	RunMap.StepKind.HEIST_CHOICE: "JOB",
	RunMap.StepKind.QUOTA_GATE: "BOOKS",
	RunMap.StepKind.ADVANCE: "MOVE UP",
}

var run_map: RunMap
var root: Control
var _string: CaseWallArt.RedString
var _route_anchor := Vector2.ZERO
var _busy := false

func _ready() -> void:
	for child in get_children():
		child.queue_free()

func bind_map(map: RunMap) -> void:
	run_map = map
	refresh()
	_maybe_stage_intro()

## Each stage opens with its intro card, once per run.
func _maybe_stage_intro() -> void:
	if run_map.is_complete() or run_map.current_step != 0:
		return
	if run_map.current_stage in RunState.stage_intros:
		return
	RunState.stage_intros.append(run_map.current_stage)
	StageIntro.present(self, run_map.current_stage)

func refresh() -> void:
	_busy = false
	if root:
		root.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	root.add_child(CaseWallArt.Corkboard.new())
	_string = CaseWallArt.RedString.new()
	_build_header()
	_build_quota_note()
	_build_wire()
	_build_route()
	root.add_child(_string)
	_build_footer()
	if run_map.is_complete():
		_center_button("FINISH RUN", _emit_complete)
		return
	var step: RunMap.Step = run_map.current()
	match step.kind:
		RunMap.StepKind.SHOP:
			_show_shop()
		RunMap.StepKind.HEIST_CHOICE:
			_show_choice(step)
		RunMap.StepKind.QUOTA_GATE:
			_show_quota()
		RunMap.StepKind.ADVANCE:
			_show_advance()
	_string.queue_redraw()

# ------------------------------------------------------------- chrome -------
func _paper(rect: Rect2, stock: Color = Palette.MANILA, tilt: float = 0.0) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.rotation = tilt
	p.pivot_offset = rect.size * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", VisualTheme.paper(stock, 0))
	root.add_child(p)
	return p

func _pin(at: Vector2, color: Color = Palette.STAMP_RED) -> void:
	var pin := CaseWallArt.Pin.new()
	pin.color = color
	pin.position = at - Vector2(8, 8)
	root.add_child(pin)

func _type(parent: Control, text: String, at: Vector2, size: int, color: Color = Palette.INK, bold := false, width := 0.0) -> Label:
	var l := VisualTheme.label(text, "", size, color)
	l.add_theme_font_override("font", VisualTheme.font("type_bold" if bold else "type"))
	l.position = at
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	parent.add_child(l)
	if width > 0.0:
		# The size grew to the unwrapped text when the label was made; shrink it
		# once the minimum-size cache has caught up with autowrap.
		l.set_deferred("size", Vector2(width, 0))
	return l

func _build_header() -> void:
	var stage_idx := run_map.current_stage
	var strip := _paper(Rect2(36, 22, 560, 84), Palette.PAPER, -0.012)
	_type(strip, "STAGE %d OF 4  ·  THE BOARD'S BOOKS" % (mini(stage_idx, 3) + 1), Vector2(22, 10), 18, Palette.STAMP_RED, true)
	var title := VisualTheme.label(("CASE WALL — " + run_map.stage_name()).to_upper(), "", 40, Palette.INK)
	title.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	title.position = Vector2(20, 28)
	strip.add_child(title)
	_pin(Vector2(56, 30))
	_pin(Vector2(578, 28))

func _build_quota_note() -> void:
	var note := _paper(Rect2(900, 16, 344, 128), Color("e8d36a"), 0.03)
	_type(note, "THE COLLECTOR — NEXT VISIT", Vector2(16, 10), 17, Palette.INK, true)
	var gold_need := roundi(run_map.current_quota())
	var idx_need := roundi(run_map.current_stock_quota())
	var gold_now := RunEconomy.gold
	var idx_now := roundi(RunState.empire_index())
	var g := _type(note, "CASH ON HAND   $%d / $%d" % [gold_now, gold_need], Vector2(16, 44), 18, Palette.STAMP_GREEN if gold_now >= gold_need else Palette.STAMP_RED, true)
	g.add_theme_font_override("font", VisualTheme.font("mono"))
	var i := _type(note, "BOARD INDEX    %d / %d" % [idx_now, idx_need], Vector2(16, 72), 18, Palette.STAMP_GREEN if idx_now >= idx_need else Palette.STAMP_RED, true)
	i.add_theme_font_override("font", VisualTheme.font("mono"))
	_type(note, "Both, or the Board cuts you off.", Vector2(16, 100), 15, Color("5a4a20"))
	_pin(Vector2(1072, 22), Color("2a5ad0"))

## The news wire: the latest story off the street, pending rumors, and any
## open Fence positions with their live value.
func _build_wire() -> void:
	var clip := _paper(Rect2(612, 18, 272, 132), Color("dcd6c4"), -0.02)
	_type(clip, "THE WIRE", Vector2(12, 6), 15, Palette.STAMP_RED, true)
	var story: Dictionary = RunState.news[0] if not RunState.news.is_empty() else {}
	var headline := MarketNews.line(story) if not story.is_empty() else "Quiet night on the street."
	var h := _type(clip, headline, Vector2(12, 26), 14, Palette.INK, true, 250)
	h.custom_minimum_size = Vector2(250, 0)
	var quotes := Positions.quotes()
	var y := 84.0
	if quotes.is_empty():
		_type(clip, "No open positions. The Fence takes longs and shorts.", Vector2(12, y), 12, Color("5a5040"), false, 250)
	else:
		for q: Dictionary in quotes.slice(0, 2):
			var l := _type(clip, Positions.describe(q), Vector2(12, y), 13, Palette.STAMP_GREEN if int(q["profit"]) >= 0 else Palette.STAMP_RED, true)
			l.add_theme_font_override("font", VisualTheme.font("mono"))
			y += 18.0
	_pin(Vector2(748, 22), Palette.STAMP_RED)

func _build_route() -> void:
	if run_map.is_complete():
		return
	var steps: Array = run_map.stages[run_map.current_stage]
	var n := steps.size()
	var w := 96.0
	var gap := minf(28.0, (1180.0 - n * w) / maxf(n - 1, 1))
	var x0 := 640.0 - (n * w + (n - 1) * gap) * 0.5
	var prev := Vector2.ZERO
	for i in n:
		var step: RunMap.Step = steps[i]
		var done := i < run_map.current_step
		var current := i == run_map.current_step
		var rect := Rect2(Vector2(x0 + i * (w + gap), 160), Vector2(w, 58))
		var stock := Palette.PAPER if not step.is_boss else Color("e6c2b8")
		var card := _paper(rect, stock if (done or current) else Palette.PAPER_DIM.darkened(0.3), (i % 3 - 1) * 0.02)
		var label: String = STEP_LABELS.get(step.kind, "?")
		if step.is_boss:
			label = "BOSS"
		if step.kind == RunMap.StepKind.ADVANCE and run_map.current_stage < 3:
			label = RunMap.name_of_stage(run_map.current_stage + 1).to_upper()
		var l := _type(card, label, Vector2(0, 16), 17, Palette.STAMP_RED if step.is_boss else Palette.INK, true, w)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if done:
			var stamp := StampArt.new()
			stamp.text = "DONE"
			stamp.font_size = 12
			stamp.ink = Palette.STAMP_GREEN
			stamp.tilt = -0.25
			card.add_child(stamp)
			stamp.position = Vector2(28, 18)
		var pin_at := rect.position + Vector2(w * 0.5, 4)
		_pin(pin_at, Palette.GOLD if current else Palette.STAMP_RED)
		if current:
			card.modulate = Color(1.15, 1.1, 1.0)
			_route_anchor = rect.position + Vector2(w * 0.5, rect.size.y)
		if i > 0:
			_string.points.append([prev, pin_at])
		prev = pin_at

func _build_footer() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.02, 0.02, 0.03, 0.9)
	bar.position = Vector2(0, 648)
	bar.size = Vector2(1280, 42)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var who: String = RunState.character_profile.display_name if RunState.character_profile else "The Operator"
	var guns: Array = []
	if RunState.loadout:
		for w in RunState.loadout.big + RunState.loadout.small:
			if w != null:
				guns.append(w.display_name)
	var line := VisualTheme.label("%s   ·   %d / %d HEALTH   ·   $%d   ·   %s" % [who.to_upper(), RunState.health, RunState.max_health, RunEconomy.gold, "  /  ".join(guns)], "", 18, Palette.PAPER)
	line.add_theme_font_override("font", VisualTheme.font("mono"))
	line.position = Vector2(24, 656)
	line.size = Vector2(1240, 26)
	line.clip_text = true
	root.add_child(line)
	var tape := TickerTape.new()
	tape.position = Vector2(0, 690)
	tape.size = Vector2(1280, 30)
	root.add_child(tape)

# -------------------------------------------------------------- steps -------
func _show_shop() -> void:
	var boss := run_map.next_heist_is_boss()
	var photo := CaseWallArt.BuildingSketch.new()
	photo.stage = run_map.current_stage
	photo.sign_text = "THE BACK ROOM"
	photo.seed_value = 404
	photo.position = Vector2(150, 262)
	photo.size = Vector2(300, 250)
	photo.rotation = -0.04
	root.add_child(photo)
	_pin(Vector2(300, 266))
	_string.points.append([_route_anchor, Vector2(300, 266)])
	var note := _paper(Rect2(530, 250, 600, 280), Palette.PAPER, 0.01)
	_type(note, ("THE BIG ONE IS NEXT." if boss else "THE HIDEOUT IS OPEN."), Vector2(28, 22), 30, Palette.INK, true)
	var lead_count := run_map.peek_next_heist_options().size()
	var body := "Gear up, work the market, then pick the next job. %d lead%s on the wire." % [lead_count, "" if lead_count == 1 else "s"]
	if boss:
		body = "One target left in %s. See the dealer, the Fence and the Black Market before you walk in." % run_map.stage_name()
	_type(note, body, Vector2(28, 70), 20, Palette.INK, false, 540)
	var enter := Button.new()
	enter.text = "ENTER THE HIDEOUT"
	enter.theme_type_variation = "PrimaryButton"
	enter.position = Vector2(560, 440)
	enter.size = Vector2(300, 70)
	enter.set_meta("qa_label", "ENTER HIDEOUT")
	enter.pressed.connect(_emit_hideout)
	root.add_child(enter)
	var skip := Button.new()
	skip.text = "STRAIGHT TO THE JOB"
	skip.position = Vector2(880, 440)
	skip.size = Vector2(240, 70)
	skip.pressed.connect(_emit_skip)
	root.add_child(skip)
	enter.grab_focus.call_deferred()

func _show_choice(step: RunMap.Step) -> void:
	var n := step.options.size()
	var w := 262.0 if n > 1 else 330.0
	var h := 392.0 if n > 1 else 410.0
	var gap := 26.0
	var x0 := 640.0 - (n * w + (n - 1) * gap) * 0.5
	var first: Button = null
	for i in n:
		var node: MapNode = step.options[i]
		var card := CaseFileCard.new()
		card.node = node
		card.index = i
		card.position = Vector2(x0 + i * (w + gap), 244)
		card.size = Vector2(w, h)
		card.base_tilt = [-0.03, 0.02, -0.015, 0.028][i % 4]
		card.set_meta("qa_label", "HEIST OPTION %d" % (i + 1))
		card.name = "HeistOption%d" % (i + 1)
		card.pressed.connect(_choose.bind(i))
		root.add_child(card)
		_string.points.append([_route_anchor, card.position + Vector2(w * 0.5, 6)])
		_pin(card.position + Vector2(w * 0.5, 6))
		if first == null:
			first = card
	if first:
		first.grab_focus.call_deferred()

func _show_quota() -> void:
	var scene := CaseWallArt.CollectorScene.new()
	scene.position = Vector2(40, 236)
	scene.size = Vector2(560, 400)
	root.add_child(scene)
	var ledger := _paper(Rect2(640, 244, 560, 330), Palette.PAPER, 0.012)
	_type(ledger, "THE LEDGER — %s" % run_map.stage_name().to_upper(), Vector2(28, 20), 24, Palette.INK, true)
	var gold_need := roundi(run_map.current_quota())
	var idx_need := roundi(run_map.current_stock_quota())
	var gold_ok := RunEconomy.gold >= gold_need
	var idx_ok := RunState.empire_index() >= idx_need
	var rows := [["Cash on hand", "$%d" % RunEconomy.gold, "$%d" % gold_need, gold_ok],
		["Board index", "%d" % roundi(RunState.empire_index()), "%d" % idx_need, idx_ok]]
	var y := 74.0
	_type(ledger, "                    YOU        OWED", Vector2(28, y), 18, Palette.PAPER_DIM.darkened(0.5), true)
	for row: Array in rows:
		y += 36.0
		var l := _type(ledger, "%-16s %-10s %s" % [row[0], row[1], row[2]], Vector2(28, y), 20, Palette.STAMP_GREEN if row[3] else Palette.STAMP_RED, true)
		l.add_theme_font_override("font", VisualTheme.font("mono"))
	var line := Story.collector_opening(gold_ok and idx_ok)
	_type(ledger, "\"" + line + "\"", Vector2(28, 186), 20, Palette.INK, false, 500)
	var open := Button.new()
	open.text = "OPEN THE BOOKS"
	open.theme_type_variation = "PrimaryButton"
	open.position = Vector2(760, 590)
	open.size = Vector2(320, 64)
	open.set_meta("qa_label", "OPEN THE BOOKS")
	open.pressed.connect(_on_open_books.bind(ledger, scene, gold_ok and idx_ok))
	root.add_child(open)
	open.grab_focus.call_deferred()

func _on_open_books(ledger: Control, scene: CaseWallArt.CollectorScene, passing: bool) -> void:
	if _busy:
		return
	_busy = true
	var stamp := StampArt.new()
	stamp.text = "PAID UP" if passing else "CUT OFF"
	stamp.ink = Palette.STAMP_GREEN if passing else Palette.STAMP_RED
	stamp.font_size = 54
	ledger.add_child(stamp)
	stamp.position = Vector2(300, 220)
	stamp.slam()
	scene.mood = 1 if passing else -1
	var reply := _type(ledger, Story.collector_verdict(passing), Vector2(28, 250), 18, Palette.STAMP_RED if not passing else Palette.INK, true, 280)
	reply.modulate.a = 0.0
	create_tween().tween_property(reply, "modulate:a", 1.0, 0.4).set_delay(0.3)
	await get_tree().create_timer(1.8).timeout
	quota_faced.emit()

func _show_advance() -> void:
	var next_stage := run_map.current_stage + 1
	var card := _paper(Rect2(220, 250, 840, 330), Palette.PAPER, -0.01)
	_type(card, "%s IS YOURS." % run_map.stage_name().to_upper(), Vector2(34, 26), 40, Palette.INK, true)
	var teaser := Story.stage_teaser(next_stage)
	_type(card, teaser, Vector2(34, 90), 22, Palette.INK, false, 760)
	var stamp := StampArt.new()
	stamp.text = "STAGE CLEARED"
	stamp.font_size = 44
	stamp.ink = Palette.STAMP_GREEN
	card.add_child(stamp)
	stamp.position = Vector2(470, 190)
	stamp.slam(0.2)
	var go := Button.new()
	go.text = "MOVE UP TO THE %s" % RunMap.name_of_stage(next_stage).to_upper()
	go.theme_type_variation = "PrimaryButton"
	go.position = Vector2(440, 594)
	go.size = Vector2(400, 50)
	go.pressed.connect(_emit_advance)
	root.add_child(go)
	go.grab_focus.call_deferred()

func _center_button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "PrimaryButton"
	b.position = Vector2(470, 360)
	b.size = Vector2(340, 80)
	b.pressed.connect(action)
	root.add_child(b)

# ------------------------------------------------------------- signals ------
func _choose(index: int) -> void:
	if _busy:
		return
	var node := run_map.choose_option(index)
	if node:
		_busy = true
		heist_chosen.emit(node)

func _emit_hideout() -> void:
	if not _busy:
		_busy = true
		hideout_requested.emit()

func _emit_skip() -> void:
	if not _busy:
		_busy = true
		hideout_skipped.emit()

func _emit_advance() -> void:
	if not _busy:
		_busy = true
		stage_advanced.emit()

func _emit_complete() -> void:
	run_complete.emit()


## A pinned case file for one heist lead. Flat Button so keyboard, mouse and
## touch all work; the folder is drawn in _draw, details are child labels.
class CaseFileCard extends Button:
	var node: MapNode
	var index := 0
	var base_tilt := 0.0

	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_ALL
		var clear := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, clear)
		pivot_offset = size * 0.5
		rotation = base_tilt
		mouse_entered.connect(_lift.bind(true))
		mouse_exited.connect(_lift.bind(false))
		focus_entered.connect(_lift.bind(true))
		focus_exited.connect(_lift.bind(false))
		_build()

	func _lift(up: bool) -> void:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "rotation", 0.0 if up else base_tilt, 0.12)
		tw.tween_property(self, "scale", Vector2(1.04, 1.04) if up else Vector2.ONE, 0.12)
		var audio := get_node_or_null("/root/Audio")
		if up and audio:
			audio.play_ui("ui_hover")

	func _draw() -> void:
		var r := Rect2(Vector2(0, 16), size - Vector2(0, 16))
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.45))
		var stock := Palette.MANILA if not node.is_boss() else Color("d9a58c")
		draw_rect(Rect2(Vector2(14, 0), Vector2(120, 24)), stock.darkened(0.08))
		draw_rect(r, stock)
		draw_rect(r, stock.darkened(0.35), false, 2.0)
		if has_focus() or is_hovered():
			draw_rect(r.grow(3), Palette.GOLD, false, 3.0)

	func _build() -> void:
		var f := VisualTheme.font("type_bold")
		var tab := VisualTheme.label("CASE %02d" % (index + 1), "", 15, Palette.INK)
		tab.add_theme_font_override("font", f)
		tab.position = Vector2(24, 2)
		add_child(tab)
		var photo := CaseWallArt.BuildingSketch.new()
		photo.stage = node.stage
		photo.sign_text = Venues.sign_name(node.venue_id, node.boss_id)
		photo.seed_value = hash(String(node.venue_id)) + index
		photo.boss = node.is_boss()
		photo.position = Vector2(18, 34)
		photo.size = Vector2(size.x - 36, 150)
		photo.rotation = 0.015
		add_child(photo)
		var title := VisualTheme.label(Venues.sign_name(node.venue_id, node.boss_id), "", 22, Palette.INK)
		title.add_theme_font_override("font", VisualTheme.font("heading_bold"))
		title.position = Vector2(16, 190)
		title.size = Vector2(size.x - 32, 28)
		title.clip_text = true
		add_child(title)
		var asset: CriminalAsset = RunState.market.get_asset(node.venue_id) if RunState.market else null
		var price := asset.current_price if asset else 0.0
		var ratio := (asset.current_price / maxf(asset.base_price, 0.01) - 1.0) if asset else 0.0
		var stock_line := VisualTheme.label("%s  $%.2f  %+.1f%%" % [Venues.ticker(node.venue_id), price, ratio * 100.0], "", 16, Palette.change(ratio).darkened(0.35))
		stock_line.add_theme_font_override("font", VisualTheme.font("mono"))
		stock_line.position = Vector2(16, 220)
		add_child(stock_line)
		var levels := ["LIGHT", "MODERATE", "HEAVY", "SEVERE", "MAXIMUM"]
		var sec := VisualTheme.label("SECURITY: " + levels[clampi(node.room_rarity, 0, 4)], "", 15, Palette.INK)
		sec.add_theme_font_override("font", f)
		sec.position = Vector2(16, 246)
		add_child(sec)
		var bars := HeistIntroCard.SecurityBars.new()
		bars.level = clampi(node.room_rarity, 0, 4)
		bars.position = Vector2(16, 270)
		bars.size = Vector2(128, 10)
		bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bars)
		if not node.is_boss():
			# CONTRACT (green) pumps the venue; HIT (red) crashes it.
			var chip := Label.new()
			chip.text = " %s " % (node.contract_label() if node.known() else "???")
			chip.add_theme_font_override("font", VisualTheme.font("heading_bold"))
			chip.add_theme_font_size_override("font_size", 16)
			chip.add_theme_color_override("font_color", Palette.PAPER)
			var chip_col := Palette.MUTED if not node.known() else (Palette.STAMP_RED if node.is_hit() else Palette.STAMP_GREEN)
			chip.add_theme_stylebox_override("normal", VisualTheme.box(chip_col, Color.TRANSPARENT, 0, 2, 3))
			chip.position = Vector2(26, 42)
			chip.size = Vector2(110, 24)
			chip.rotation = -0.05
			chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.tooltip_text = node.contract_detail()
			add_child(chip)
		# Objective, the contract's terms, then the modifiers as icons.
		var known := node.known() or node.is_boss()
		var obj_text := "OBJECTIVE: " + ("TAKE HIM DOWN" if node.is_boss() else (Objectives.title(node.objective) if known else "???"))
		var obj := VisualTheme.label(obj_text, "", 15, Palette.STAMP_RED if node.is_boss() else Palette.INK)
		obj.add_theme_font_override("font", VisualTheme.font("type_bold"))
		obj.position = Vector2(16, 288)
		add_child(obj)
		var detail := VisualTheme.label("", "", 14, Color("3a2a12"))
		detail.add_theme_font_override("font", VisualTheme.font("type"))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.position = Vector2(16, 308)
		detail.custom_minimum_size = Vector2(size.x - 32, 0)
		if node.is_boss():
			detail.text = Story.boss_title(node.boss_id)
		elif known:
			detail.text = node.contract_detail()
		else:
			detail.text = "A stranger's tip. Details unknown."
		add_child(detail)
		detail.set_deferred("size", Vector2(size.x - 32, 0))
		var icons := HBoxContainer.new()
		icons.position = Vector2(16, size.y - 44)
		icons.add_theme_constant_override("separation", 6)
		icons.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icons)
		if not node.is_boss():
			var ids: Array = [node.objective] + node.modifiers if known else [&"?"]
			for id in ids:
				var icon := ModIcon.new()
				icon.id = id
				icon.size = Vector2(30, 30)
				icons.add_child(icon)
			if known and node.modifiers.is_empty():
				icons.add_child(VisualTheme.label("STANDARD SECURITY", "", 13, Color("5a4a30")))
		tooltip_text = _card_tooltip()
		if node.is_boss() or node.is_valuable:
			var stamp := StampArt.new()
			stamp.text = "PRIORITY TARGET" if node.is_boss() else "HIGH VALUE"
			stamp.font_size = 20
			stamp.tilt = 0.18
			add_child(stamp)
			stamp.position = Vector2(size.x - stamp.size.x - 12, 150)
		for child in get_children():
			if child is Control and child is not HBoxContainer:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Icons keep their own tooltips and pass clicks through to the card.
		for child in find_children("*", "ModIcon", true, false):
			child.mouse_filter = Control.MOUSE_FILTER_PASS

	func _card_tooltip() -> String:
		if node.is_boss():
			return Story.boss_title(node.boss_id)
		if not node.known():
			return ModIcon.describe(&"?")
		var lines: Array = [Objectives.title(node.objective) + ": " + Objectives.brief(node.objective), node.contract_detail()]
		for m in node.modifiers:
			lines.append(ModIcon.describe(m))
		return "\n".join(lines)
