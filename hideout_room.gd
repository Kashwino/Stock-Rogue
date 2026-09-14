extends Node2D
class_name HideoutRoom

## The hideout: a walkable backroom between heists, visited instead of the old
## menu-based shop. Three stations to walk up to and press "interact" (E) on:
##   WEAPON DEALER      -- buy and equip weapons
##   STOCK MANIPULATION -- the market ops that move the empire index + perks
##   BLACK MARKET       -- combat upgrades, themed to whatever case is next
## Walk to the door and interact to head back out to the job board.
##
## Scene: Node2D root + this script. Everything -- room geometry, the player
## walker, stations, vendor panels -- is built in code, the same reliable
## pattern as every other screen in this project.
##
## Purchase callbacks are bound METHOD REFERENCES (e.g. _buy_patch_kit.bind()),
## never inline multi-line lambdas passed as a middle argument -- GDScript
## can't reliably close an indented lambda block and continue the same
## expression with more arguments afterward.

const GOLD := Color(0.91, 0.72, 0.26)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const PANEL := Color(0.10, 0.10, 0.13)
const PANEL_EDGE := Color(0.24, 0.24, 0.3)
const INK_SOFT := Color(0.62, 0.62, 0.7)
const RED := Color(0.85, 0.35, 0.35)

const ROOM_SIZE := Vector2(600, 420)
const WALL_THICK := 24.0

var _walker: HideoutWalker
var _stations: Array = []
var _active_panel: CanvasLayer = null
var _active_gold_label: Label = null
var _near_station: Dictionary = {}
var _near_door: bool = false
var _door_prompt: Label

var _rng := RandomNumberGenerator.new()
var _next_rarity: int = 1

func _ready() -> void:
	_rng.randomize()
	_check_input_actions()
	_build_room()
	_build_walker()
	_build_stations()
	_build_door()
	_build_hud_hint()
	print("[HideoutRoom] ready -- 3 stations + door built")

## If these actions aren't in the project's Input Map, movement/interaction
## fail completely but silently -- no crash, no error, the room just looks
## "broken". Surface that clearly instead of leaving it a mystery.
func _check_input_actions() -> void:
	var required := ["move_left", "move_right", "move_up", "move_down", "interact"]
	var missing: Array = []
	for a in required:
		if not InputMap.has_action(a):
			missing.append(a)
	if not missing.is_empty():
		push_error("[HideoutRoom] Missing Input Map actions: " + str(missing)
			+ " -- Project > Project Settings > Input Map. Movement/interact "
			+ "will not work until these exist.")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if not _near_station.is_empty():
			_open_station(_near_station["kind"])
		elif _near_door:
			_leave_hideout()

# ------------------------------------------------------------------ room ---
func _build_room() -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(ROOM_SIZE.x, 0),
		Vector2(ROOM_SIZE.x, ROOM_SIZE.y), Vector2(0, ROOM_SIZE.y)])
	floor_poly.color = Color(0.09, 0.085, 0.1)
	add_child(floor_poly)

	for x in range(0, int(ROOM_SIZE.x), 40):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 0), Vector2(x, ROOM_SIZE.y)])
		line.width = 1.0
		line.default_color = Color(1, 1, 1, 0.025)
		add_child(line)
	for y in range(0, int(ROOM_SIZE.y), 40):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(0, y), Vector2(ROOM_SIZE.x, y)])
		line.width = 1.0
		line.default_color = Color(1, 1, 1, 0.025)
		add_child(line)

	var walls := [
		Rect2(-WALL_THICK, -WALL_THICK, ROOM_SIZE.x + WALL_THICK * 2, WALL_THICK),
		Rect2(-WALL_THICK, ROOM_SIZE.y, ROOM_SIZE.x + WALL_THICK * 2, WALL_THICK),
		Rect2(-WALL_THICK, -WALL_THICK, WALL_THICK, ROOM_SIZE.y + WALL_THICK * 2),
		Rect2(ROOM_SIZE.x, -WALL_THICK, WALL_THICK, ROOM_SIZE.y + WALL_THICK * 2),
	]
	for r in walls:
		_add_wall(r)

	var trim := ColorRect.new()
	trim.position = Vector2(0, -6)
	trim.size = Vector2(ROOM_SIZE.x, 4)
	trim.color = GOLD_DIM
	add_child(trim)

func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.position
	add_child(body)
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.size * 0.5
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.size = rect.size
	visual.color = Color(0.04, 0.04, 0.05)
	body.add_child(visual)

# ---------------------------------------------------------------- walker ---
func _build_walker() -> void:
	_walker = HideoutWalker.new()
	_walker.position = ROOM_SIZE * 0.5 + Vector2(0, 110)
	add_child(_walker)

	var cam := Camera2D.new()
	cam.zoom = Vector2(1.15, 1.15)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	_walker.add_child(cam)
	# make_current() rather than setting `current = true` directly: it needs
	# the camera inside the tree first, which add_child just did.
	cam.make_current()

# -------------------------------------------------------------- stations ---
func _build_stations() -> void:
	_make_station(&"weapons", "WEAPON DEALER",
		"Guns for the next job", Vector2(ROOM_SIZE.x * 0.22, ROOM_SIZE.y * 0.32),
		Color(0.85, 0.4, 0.35))
	_make_station(&"stocks", "THE FENCE",
		"Move the market", Vector2(ROOM_SIZE.x * 0.5, ROOM_SIZE.y * 0.18),
		GOLD)
	_make_station(&"blackmarket", "BLACK MARKET",
		"Case-specific gear", Vector2(ROOM_SIZE.x * 0.78, ROOM_SIZE.y * 0.32),
		Color(0.6, 0.4, 0.85))

func _make_station(kind: StringName, title: String, subtitle: String,
		pos: Vector2, tint: Color) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 4
	add_child(area)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	shape.shape = circle
	area.add_child(shape)

	var kiosk := Polygon2D.new()
	kiosk.polygon = PackedVector2Array([
		Vector2(-34, -22), Vector2(34, -22), Vector2(34, 22), Vector2(-34, 22)])
	kiosk.color = tint.darkened(0.55)
	area.add_child(kiosk)
	var kiosk_edge := Polygon2D.new()
	kiosk_edge.polygon = PackedVector2Array([
		Vector2(-34, -22), Vector2(34, -22), Vector2(34, -17), Vector2(-34, -17)])
	kiosk_edge.color = tint
	area.add_child(kiosk_edge)

	var title_l := Label.new()
	title_l.text = title
	title_l.add_theme_font_size_override("font_size", 15)
	title_l.add_theme_color_override("font_color", tint)
	title_l.position = Vector2(-48, -54)
	area.add_child(title_l)

	var sub_l := Label.new()
	sub_l.text = subtitle
	sub_l.add_theme_font_size_override("font_size", 10)
	sub_l.add_theme_color_override("font_color", INK_SOFT)
	sub_l.position = Vector2(-48, -39)
	area.add_child(sub_l)

	var prompt := Label.new()
	prompt.text = "[E] Talk"
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.position = Vector2(-22, 28)
	prompt.hide()
	area.add_child(prompt)

	var entry := {"area": area, "prompt": prompt, "kind": kind}
	_stations.append(entry)
	area.body_entered.connect(_on_station_entered.bind(entry))
	area.body_exited.connect(_on_station_exited.bind(entry))

func _on_station_entered(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	_near_station = entry
	entry["prompt"].show()

func _on_station_exited(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	if _near_station == entry:
		_near_station = {}
	entry["prompt"].hide()

# ------------------------------------------------------------------ door ---
func _build_door() -> void:
	var area := Area2D.new()
	area.position = Vector2(ROOM_SIZE.x * 0.5, ROOM_SIZE.y - 16)
	area.collision_layer = 0
	area.collision_mask = 4
	add_child(area)

	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(76, 42)
	shape.shape = rs
	area.add_child(shape)

	var door_visual := Polygon2D.new()
	door_visual.polygon = PackedVector2Array([
		Vector2(-38, -21), Vector2(38, -21), Vector2(38, 21), Vector2(-38, 21)])
	door_visual.color = Color(0.4, 0.32, 0.12)
	area.add_child(door_visual)

	var label := Label.new()
	label.text = "OUT TO THE JOB BOARD"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", GOLD_DIM)
	label.position = Vector2(-60, -38)
	label.custom_minimum_size = Vector2(140, 0)
	area.add_child(label)

	_door_prompt = Label.new()
	_door_prompt.text = "[E] Leave"
	_door_prompt.add_theme_font_size_override("font_size", 12)
	_door_prompt.add_theme_color_override("font_color", Color.WHITE)
	_door_prompt.position = Vector2(-22, 24)
	_door_prompt.hide()
	area.add_child(_door_prompt)

	area.body_entered.connect(_on_door_entered)
	area.body_exited.connect(_on_door_exited)

func _on_door_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_near_door = true
		_door_prompt.show()

func _on_door_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_near_door = false
		_door_prompt.hide()

func _leave_hideout() -> void:
	if RunState.run_map:
		RunState.run_map.advance_step()
	RunFlow.save()
	get_tree().change_scene_to_file("res://map_ui_screen.tscn")

# --------------------------------------------------------------- overlay ---
func _build_hud_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var l := Label.new()
	l.text = "MOVE -- WASD / ARROWS      INTERACT -- E"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 14
	layer.add_child(l)

# ============================================================== STATIONS ===
func _open_station(kind: StringName) -> void:
	if _active_panel:
		return
	_walker.movement_enabled = false
	match kind:
		&"weapons": _active_panel = _build_weapon_dealer()
		&"stocks": _active_panel = _build_stock_manipulation()
		&"blackmarket": _active_panel = _build_black_market()
	if _active_panel:
		add_child(_active_panel)

func _close_panel() -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
	_active_gold_label = null
	_walker.movement_enabled = true

## Shared panel chrome: dim + centered frame + title + gold label + close.
## Returns {layer, body} where `body` is the VBoxContainer to fill with content.
func _panel_frame(title: String, kicker: String, accent: Color) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 36; sb.content_margin_right = 36
	sb.content_margin_top = 26; sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var header := HBoxContainer.new()
	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var k := Label.new()
	k.text = kicker
	k.add_theme_font_size_override("font_size", 11)
	k.add_theme_color_override("font_color", GOLD_DIM)
	head_col.add_child(k)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", accent)
	head_col.add_child(t)
	header.add_child(head_col)
	var gold_l := Label.new()
	gold_l.add_theme_font_size_override("font_size", 18)
	gold_l.add_theme_color_override("font_color", GOLD)
	header.add_child(gold_l)
	col.add_child(header)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = GOLD_DIM
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)

	var close := Button.new()
	close.text = "Back to the floor"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(_close_panel)
	col.add_child(close)

	_active_gold_label = gold_l
	_refresh_gold_label()
	return {"layer": layer, "body": body}

func _refresh_gold_label() -> void:
	if _active_gold_label == null:
		return
	var econ = get_node_or_null("/root/RunEconomy")
	_active_gold_label.text = "\u26FF " + str(econ.gold if econ else 0)

## A single buyable row. `on_buy` is a bound Callable taking no arguments
## (e.g. _buy_patch_kit, or _buy_weapon.bind(w)) -- never an inline lambda,
## so there's no risk of a multi-line block breaking the surrounding call.
func _item_row(body: VBoxContainer, name_text: String, desc_text: String,
		price: int, accent: Color, on_buy: Callable) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.13, 0.16)
	sb.border_color = PANEL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := Label.new()
	n.text = name_text
	n.add_theme_font_size_override("font_size", 15)
	n.add_theme_color_override("font_color", accent)
	info.add_child(n)
	var d := Label.new()
	d.text = desc_text
	d.add_theme_font_size_override("font_size", 11)
	d.add_theme_color_override("font_color", INK_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(d)
	row.add_child(info)

	var right := VBoxContainer.new()
	var price_l := Label.new()
	price_l.text = "\u26FF " + str(price)
	price_l.add_theme_color_override("font_color", GOLD)
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(price_l)
	var buy := Button.new()
	buy.text = "Buy"
	buy.custom_minimum_size = Vector2(74, 0)
	right.add_child(buy)
	row.add_child(right)

	buy.pressed.connect(_on_row_buy.bind(price, on_buy, buy))
	body.add_child(panel)

func _on_row_buy(price: int, on_buy: Callable, buy: Button) -> void:
	var econ = get_node_or_null("/root/RunEconomy")
	if econ == null or not econ.can_afford(price):
		buy.modulate = RED
		var tw := create_tween()
		tw.tween_property(buy, "modulate", Color.WHITE, 0.4)
		return
	econ.spend(price)
	on_buy.call()
	_refresh_gold_label()
	buy.text = "Bought"
	buy.disabled = true

# ============================================================ ALL VENDORS ===
## Every station -- Weapon Dealer, The Fence, Black Market -- follows the
## SAME shape: exactly 3 offers, randomly chosen each visit, with a paid
## reroll that gets pricier each use (resets next visit). `_offer_generator`
## is a bound Callable returning Array[Dictionary] of
##   {"name": String, "desc": String, "price": int, "accent": Color, "cb": Callable}
## so weapons (freshly rolled via LootRoller) and fixed named items (market
## ops, perks, upgrades) can share one render/reroll implementation even
## though they're generated completely differently underneath.

const REROLL_BASE_COST := 40
const REROLL_STEP := 25

var _offers_col: VBoxContainer = null
var _reroll_button: Button = null
var _reroll_cost: int = REROLL_BASE_COST
var _offer_generator: Callable = Callable()
var _current_offers: Array = []

## Shared entry point: builds the panel frame, intro line, reroll button, and
## the first roll of 3 offers. Each vendor just supplies its own generator.
func _open_vendor(title: String, kicker: String, accent: Color,
		intro_text: String, offer_generator: Callable) -> CanvasLayer:
	var frame := _panel_frame(title, kicker, accent)
	var body: VBoxContainer = frame["body"]

	if intro_text != "":
		var intro := Label.new()
		intro.text = intro_text
		intro.add_theme_font_size_override("font_size", 11)
		intro.add_theme_color_override("font_color", INK_SOFT)
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(intro)

	var reroll_row := HBoxContainer.new()
	reroll_row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(reroll_row)
	_reroll_cost = REROLL_BASE_COST
	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(0, 34)
	_reroll_button.pressed.connect(_on_reroll_offers)
	reroll_row.add_child(_reroll_button)

	_offers_col = VBoxContainer.new()
	_offers_col.add_theme_constant_override("separation", 10)
	body.add_child(_offers_col)

	_offer_generator = offer_generator
	_current_offers = _offer_generator.call()
	_render_offer_rows()
	_update_reroll_button()

	return frame["layer"]

func _render_offer_rows() -> void:
	for c in _offers_col.get_children():
		c.queue_free()
	for entry: Dictionary in _current_offers:
		_item_row(_offers_col, entry["name"], entry["desc"], entry["price"],
			entry["accent"], entry["cb"])

func _update_reroll_button() -> void:
	if _reroll_button:
		_reroll_button.text = "\u21BB Reroll stock (\u26FF %d)" % _reroll_cost

## Rerolling costs gold and gets pricier each use THIS visit -- resets to
## base cost next time you walk in. A real decision, not a free retry loop.
func _on_reroll_offers() -> void:
	var econ = get_node_or_null("/root/RunEconomy")
	if econ == null or not econ.can_afford(_reroll_cost):
		_reroll_button.modulate = RED
		var tw := create_tween()
		tw.tween_property(_reroll_button, "modulate", Color.WHITE, 0.4)
		return
	econ.spend(_reroll_cost)
	_refresh_gold_label()
	_reroll_cost += REROLL_STEP
	_current_offers = _offer_generator.call()
	_render_offer_rows()
	_update_reroll_button()

## Shuffle a pool and take the first `n` -- shared by every fixed-list vendor
## (Fence, Black Market). Weapon Dealer doesn't use this: LootRoller already
## produces exactly 3 independently-rarity-rolled items on its own.
func _sample_pool(pool: Array, n: int) -> Array:
	var copy := pool.duplicate()
	copy.shuffle()
	return copy.slice(0, mini(n, copy.size()))

# ---------------------------------------------------------- weapon dealer --
func _build_weapon_dealer() -> CanvasLayer:
	var frame := _panel_frame("WEAPON DEALER", "SEALED CASES -- QUOTA-GRADE STOCK",
		Color(0.85, 0.4, 0.35))
	var body: VBoxContainer = frame["body"]

	var intro := Label.new()
	intro.text = "Sealed off the truck. Nobody knows what's inside until it cracks -- but the grade only goes up the more heat you've weathered."
	intro.add_theme_font_size_override("font_size", 11)
	intro.add_theme_color_override("font_color", INK_SOFT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var qb: int = RunState.run_map.quota_block if RunState.run_map else 0
	_case_tier = _case_tier_for_quota(qb)
	_case_price = _case_price_for_quota(qb)
	_case_opened = [false, false, false]
	_case_results = [null, null, null]
	_spin_active = false

	var tier_l := Label.new()
	tier_l.text = "%s grade -- \u26FF %d each" % [LootRoller.tier_name(_case_tier), _case_price]
	tier_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_l.add_theme_font_size_override("font_size", 12)
	tier_l.add_theme_color_override("font_color", GOLD_DIM)
	body.add_child(tier_l)

	_case_stage = Control.new()
	_case_stage.custom_minimum_size = Vector2(STAGE_WIDTH, 230)
	_case_stage.clip_contents = true
	body.add_child(_case_stage)

	var result_l := Label.new()
	result_l.name = "CaseResultLabel"
	result_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_l.add_theme_font_size_override("font_size", 14)
	result_l.custom_minimum_size = Vector2(0, 20)
	body.add_child(result_l)
	_case_result_label = result_l

	_render_case_row()
	return frame["layer"]

## Case grade tracks QUOTA progress specifically -- clearing a quota gate is
## what earns better stock. Price climbs with it too, so better odds cost more.
func _case_tier_for_quota(qb: int) -> int:
	if qb >= 3: return LootRoller.ChestTier.AIRDROP
	if qb == 2: return LootRoller.ChestTier.STORAGE
	if qb == 1: return LootRoller.ChestTier.TRUCK
	return LootRoller.ChestTier.TRUNK

func _case_price_for_quota(qb: int) -> int:
	return int(200 * pow(1.6, qb))

func _render_case_row() -> void:
	for c in _case_stage.get_children():
		c.queue_free()
	_case_result_label.text = ""
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_case_stage.add_child(row)
	for i in CASE_COUNT:
		row.add_child(_make_case_card(i))

func _make_case_card(index: int) -> Control:
	if _case_opened[index]:
		return _make_result_card(_case_results[index])
	return _make_sealed_card(index)

func _make_sealed_card(index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(150, 210)
	card.focus_mode = Control.FOCUS_ALL
	card.disabled = _spin_active
	var edge := Color(0.6, 0.62, 0.68)
	_style_case_card(card, edge)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)

	var icon_wrap := CenterContainer.new()
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon_wrap)
	var icon := Label.new()
	icon.text = "\u25A3"
	icon.add_theme_font_size_override("font_size", 46)
	icon.add_theme_color_override("font_color", edge)
	icon_wrap.add_child(icon)

	var name_l := Label.new()
	name_l.text = "SEALED CASE"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 13)
	col.add_child(name_l)

	var price_l := Label.new()
	price_l.text = "\u26FF %d" % _case_price
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_l.add_theme_color_override("font_color", GOLD)
	col.add_child(price_l)

	card.pressed.connect(_on_case_pressed.bind(index, card))
	return card

func _make_result_card(w: WeaponItem) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 210)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.12)
	sb.border_color = w.rarity_color()
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var icon := Label.new()
	icon.text = "\u2726"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 40)
	icon.add_theme_color_override("font_color", w.rarity_color())
	col.add_child(icon)

	var name_l := Label.new()
	name_l.text = w.display_name
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.add_theme_color_override("font_color", w.rarity_color())
	col.add_child(name_l)

	var stats_l := Label.new()
	stats_l.text = "%s\ndmg %d" % [w.rarity_name(), w.damage]
	stats_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_l.add_theme_font_size_override("font_size", 10)
	stats_l.add_theme_color_override("font_color", INK_SOFT)
	col.add_child(stats_l)

	var tag := Label.new()
	tag.text = "EQUIPPED"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	col.add_child(tag)

	return card

func _style_case_card(card: Button, edge: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.09, 0.12)
		if state == "hover" or state == "focus":
			sb.bg_color = Color(0.15, 0.15, 0.19)
		elif state == "pressed":
			sb.bg_color = Color(0.05, 0.05, 0.07)
		elif state == "disabled":
			sb.bg_color = Color(0.08, 0.08, 0.1)
		sb.border_color = edge
		sb.set_border_width_all(3 if state != "normal" else 2)
		sb.set_corner_radius_all(6)
		card.add_theme_stylebox_override(state, sb)

func _on_case_pressed(index: int, card: Button) -> void:
	if _spin_active or _case_opened[index]:
		return
	var econ = get_node_or_null("/root/RunEconomy")
	if econ == null or not econ.can_afford(_case_price):
		card.modulate = RED
		var tw := create_tween()
		tw.tween_property(card, "modulate", Color.WHITE, 0.4)
		return
	econ.spend(_case_price)
	_refresh_gold_label()

	var pool: Array = ItemPool.rewardable_weapons()   # excludes the starter pistol
	var rolled: Array = LootRoller.roll_items(pool, _case_tier, 1, _rng)
	var w: WeaponItem = rolled[0] if not rolled.is_empty() else pool[0]

	_start_spin(index, w)

# ------------------------------------------------------- the classic spin --
const CASE_COUNT := 3
const STAGE_WIDTH := 488.0
const SPIN_SLOT_WIDTH := 64.0
const SPIN_SLOT_GAP := 6.0
const SPIN_SLOT_PITCH := SPIN_SLOT_WIDTH + SPIN_SLOT_GAP
const SPIN_SLOT_COUNT := 40
const SPIN_WINNER_INDEX := 32
const SPIN_DURATION := 4.0

var _case_tier: int = LootRoller.ChestTier.TRUNK
var _case_price: int = 200
var _case_opened: Array = [false, false, false]
var _case_results: Array = [null, null, null]
var _case_stage: Control = null
var _case_result_label: Label = null
var _spin_active: bool = false
var _spin_winner_slot: Control = null

## The classic CS:GO strip: a long row of colour-tinted slots scrolls fast
## under a fixed pointer, then decelerates hard until the true result -- fixed
## from the moment the case was bought -- lands exactly under it.
func _start_spin(index: int, w: WeaponItem) -> void:
	_spin_active = true

	for c in _case_stage.get_children():
		c.queue_free()

	var spinner := Control.new()
	spinner.set_anchors_preset(Control.PRESET_FULL_RECT)
	spinner.clip_contents = true
	_case_stage.add_child(spinner)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", SPIN_SLOT_GAP)
	spinner.add_child(strip)

	for i in SPIN_SLOT_COUNT:
		var slot: PanelContainer
		if i == SPIN_WINNER_INDEX:
			slot = _make_spin_slot(w.rarity_color())
			_spin_winner_slot = slot
		else:
			var r := LootRoller.roll_rarity(_case_tier, _rng)
			slot = _make_spin_slot(Rarity.color_of(r))
		strip.add_child(slot)

	# Fixed pointer, drawn on top of the strip, dead centre of the stage.
	var pointer := ColorRect.new()
	pointer.color = Color(1, 1, 1, 0.95)
	pointer.size = Vector2(3, 214)
	pointer.position = Vector2(STAGE_WIDTH * 0.5 - 1.5, 8)
	spinner.add_child(pointer)
	var pointer_glow := ColorRect.new()
	pointer_glow.color = Color(1, 0.85, 0.3, 0.25)
	pointer_glow.size = Vector2(40, 214)
	pointer_glow.position = Vector2(STAGE_WIDTH * 0.5 - 20, 8)
	spinner.add_child(pointer_glow)
	spinner.move_child(pointer_glow, 0)   # behind everything except the floor

	# Slot i's centre, if the strip's own position.x were 0, sits at
	# i*PITCH + SLOT_WIDTH/2. We want the WINNER slot's centre to land under
	# the pointer (STAGE_WIDTH/2) once the animation finishes, and the strip
	# to begin scrolled far enough right that slot 0 starts near the pointer.
	var pointer_x := STAGE_WIDTH * 0.5
	var winner_center := SPIN_WINNER_INDEX * SPIN_SLOT_PITCH + SPIN_SLOT_WIDTH * 0.5
	var target_x := pointer_x - winner_center
	var start_center := SPIN_SLOT_WIDTH * 0.5
	var start_x := pointer_x - start_center

	strip.position = Vector2(start_x, 8)

	var tw := create_tween()
	tw.tween_property(strip, "position:x", target_x, SPIN_DURATION) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_spin_landed.bind(index, w))

func _make_spin_slot(color: Color) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SPIN_SLOT_WIDTH, 214)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.35)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", sb)
	return slot

## Strip has stopped; the winner slot is (by construction) exactly under the
## pointer. Flash it, reveal what you got, then settle back into the case row.
func _on_spin_landed(index: int, w: WeaponItem) -> void:
	if RunState.loadout:
		RunState.loadout.equip(w)

	if _spin_winner_slot:
		var flash := create_tween()
		flash.tween_property(_spin_winner_slot, "scale", Vector2(1.25, 1.25), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		flash.tween_property(_spin_winner_slot, "scale", Vector2.ONE, 0.15)
		_spin_winner_slot.pivot_offset = Vector2(SPIN_SLOT_WIDTH * 0.5, 107)

	_case_result_label.text = "%s -- %s" % [w.rarity_name(), w.display_name]
	_case_result_label.add_theme_color_override("font_color", w.rarity_color())

	_case_opened[index] = true
	_case_results[index] = w
	_spin_active = false

	var settle := create_tween()
	settle.tween_interval(1.1)
	settle.tween_callback(_render_case_row)


# ----------------------------------------------------- stock manipulation --
func _build_stock_manipulation() -> CanvasLayer:
	return _open_vendor("THE FENCE", "STOCK MANIPULATION", GOLD,
		"Three moves on offer today. Pay for a fourth if none of them suit you.",
		_fence_offer_generator)

## 3 of up to 6 possible offers, sampled fresh every open and every reroll.
## Perks drop out of the pool once owned, so they naturally stop appearing.
func _fence_offer_generator() -> Array:
	var qb: int = RunState.run_map.quota_block if RunState.run_map else 0
	var scale := pow(1.55, qb)
	var pool: Array = [
		{"name": "Spread Rumors", "desc": "+25% to your weakest venue.",
			"price": int(120 * scale), "accent": GOLD, "cb": _op_pump_weak},
		{"name": "Market Manipulation", "desc": "+8% to EVERY venue. Moves the Index directly.",
			"price": int(260 * scale), "accent": GOLD, "cb": _op_pump_all},
		{"name": "Short Squeeze", "desc": "Doubles your best venue's distance above baseline.",
			"price": int(200 * scale), "accent": GOLD, "cb": _op_short_squeeze},
		{"name": "Protection Money", "desc": "Lifts every venue below baseline back to 1.00.",
			"price": int(230 * scale), "accent": GOLD, "cb": _op_floor_price},
	]
	if not RunState.has_perk(&"recon"):
		pool.append({"name": "Recon Network", "desc": "Reveals ? nodes on the map before you commit.",
			"price": 250, "accent": Color(0.55, 0.75, 1.0), "cb": _buy_perk.bind(&"recon")})
	if not RunState.has_perk(&"inside_trader"):
		pool.append({"name": "Inside Trader", "desc": "+25% on positive stock swings from heist grades.",
			"price": 300, "accent": Color(0.55, 0.75, 1.0), "cb": _buy_perk.bind(&"inside_trader")})
	return _sample_pool(pool, 3)

func _buy_perk(id: StringName) -> void:
	RunState.add_perk(id)

func _op_pump_weak() -> void:
	if not RunState.market: return
	var weakest = null
	var worst := INF
	for a in RunState.market.assets:
		if a.base_price <= 0.0: continue
		var ratio: float = a.current_price / a.base_price
		if ratio < worst: worst = ratio; weakest = a
	if weakest: weakest.current_price *= 1.25

func _op_pump_all() -> void:
	if not RunState.market: return
	for a in RunState.market.assets:
		a.current_price *= 1.08

func _op_short_squeeze() -> void:
	if not RunState.market: return
	var best = null
	var top := -INF
	for a in RunState.market.assets:
		if a.base_price <= 0.0: continue
		var ratio: float = a.current_price / a.base_price
		if ratio > top: top = ratio; best = a
	if best and top > 1.0:
		best.current_price = best.base_price * (1.0 + (top - 1.0) * 2.0)

func _op_floor_price() -> void:
	if not RunState.market: return
	for a in RunState.market.assets:
		if a.base_price > 0.0 and a.current_price < a.base_price:
			a.current_price = a.base_price

# ------------------------------------------------------------ black market --
func _build_black_market() -> CanvasLayer:
	_next_rarity = 1
	if RunState.run_map:
		var options: Array = RunState.run_map.peek_next_heist_options()
		for opt in options:
			_next_rarity = maxi(_next_rarity, int(opt.room_rarity))
	var tier_names := ["Light", "Light", "Moderate", "Moderate", "Heavy", "Heavy", "Maximum"]
	var tier_word: String = tier_names[clampi(_next_rarity, 0, tier_names.size() - 1)]

	return _open_vendor("BLACK MARKET", "GEAR FOR THE NEXT JOB",
		Color(0.6, 0.4, 0.85),
		"Word is the next case runs %s security. Gear up accordingly." % tier_word.to_lower(),
		_black_market_offer_generator)

## 3 of up to 6 possible offers. The 6th (Insider Blueprints) only enters the
## pool at all when the next case is genuinely dangerous -- case-specific,
## not just a flat extra item.
func _black_market_offer_generator() -> Array:
	var qb: int = RunState.run_map.quota_block if RunState.run_map else 0
	var scale := pow(1.4, qb)
	var pool: Array = [
		{"name": "Patch Kit", "desc": "Restore 1 health",
			"price": int(140 * scale), "accent": Color(0.85, 0.4, 0.4), "cb": _buy_patch_kit},
		{"name": "Ammo Crate", "desc": "Refill reserve ammo for all weapons",
			"price": int(90 * scale), "accent": Color(0.85, 0.4, 0.4), "cb": _buy_ammo_crate},
		{"name": "Kevlar Lining", "desc": "+1 max health, this run",
			"price": int(300 * scale), "accent": Color(0.6, 0.4, 0.85), "cb": _buy_kevlar},
		{"name": "Combat Stims", "desc": "+12% move speed, this run",
			"price": int(220 * scale), "accent": Color(0.6, 0.4, 0.85), "cb": _buy_stims},
		{"name": "Filed Trigger", "desc": "Fire 12% faster, this run",
			"price": int(260 * scale), "accent": Color(0.6, 0.4, 0.85), "cb": _buy_filed_trigger},
	]
	if _next_rarity >= 4:
		var tier_names := ["Light", "Light", "Moderate", "Moderate", "Heavy", "Heavy", "Maximum"]
		var tier_word: String = tier_names[clampi(_next_rarity, 0, tier_names.size() - 1)]
		pool.append({"name": "Insider Blueprints",
			"desc": "Advance intel on a %s job: +1 max health and +8%% fire rate." % tier_word.to_lower(),
			"price": int(480 * scale), "accent": Color(1.0, 0.65, 0.15), "cb": _buy_blueprints})
	return _sample_pool(pool, 3)

func _buy_patch_kit() -> void:
	RunState.heal(1)

func _buy_ammo_crate() -> void:
	if not RunState.loadout: return
	var w: WeaponItem = RunState.loadout.get_active()
	if w:
		RunState.loadout.scavenge(w.ammo_type, 120)

func _buy_kevlar() -> void:
	RunState.add_max_health(1)

func _buy_stims() -> void:
	RunState.add_stat_mod(&"move_speed", 0.0, 1.12)

func _buy_filed_trigger() -> void:
	RunState.add_stat_mod(&"fire_rate", 0.0, 0.88)

func _buy_blueprints() -> void:
	RunState.add_max_health(1)
	RunState.add_stat_mod(&"fire_rate", 0.0, 0.92)
