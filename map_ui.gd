extends CanvasLayer
## Run map screen. Reads a RunMap and shows the CURRENT step: either 2-4 heist
## option cards to choose from, a (skippable) shop, a quota gate, or advance.
## Emits signals the game loop reacts to (launch a heist, open shop, etc.).
##
## Locations (Town/City/World/Doomsday) are shown as data labels now; theme later
## by assigning per-stage colors via STAGE_COLORS.

signal heist_chosen(node)          # player picked a heist option (a MapNode)
signal shop_opened()
signal shop_skipped()
signal quota_reached(quota: float)
signal run_advanced()
signal run_complete()

@onready var stage_label: Label = %StageLabel
@onready var quota_label: Label = %QuotaLabel
@onready var step_title: Label = %StepTitle
@onready var card_row: HBoxContainer = %CardRow
@onready var action_row: HBoxContainer = %ActionRow   # holds shop/skip/advance buttons

var run_map: RunMap = null
var _cards: Array = []

func _ready() -> void:
	_ensure_control_root()

## Godot routes mouse input down the CONTROL tree. This scene is a CanvasLayer
## with Controls parented straight to it — with no full-rect Control root in
## between, buttons render fine but NEVER receive clicks (keyboard would still
## work). Exactly the bug that killed the chest UI. This inserts the missing
## root at runtime and moves the existing Controls into it, preserving order.
func _ensure_control_root() -> void:
	# Only skip if the layer has exactly ONE Control child and it's full-rect —
	# i.e. a genuine root. A full-rect background sitting NEXT TO the button
	# rows must not fool this check (that's how the chest's first fix failed).
	var control_children: Array = []
	for c in get_children():
		if c is Control:
			control_children.append(c)
	if control_children.size() == 1:
		var only: Control = control_children[0]
		if only.anchor_right == 1.0 and only.anchor_bottom == 1.0:
			return

	var root := Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	move_child(root, 0)

	for c: Control in control_children:
		remove_child(c)
		root.add_child(c)
		# Full-rect decorations (backgrounds) default to STOP and would eat
		# every click before it reaches the buttons — never let them.
		if c is ColorRect or c is TextureRect or c is Panel:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pass # Debug logging removed.

# Per-stage accent colors (theme hook — reskin locations later).
const STAGE_COLORS := {
	"Town":     Color(0.5, 0.75, 0.55),
	"City":     Color(0.55, 0.6, 0.9),
	"World":    Color(0.85, 0.6, 0.35),
	"Doomsday": Color(0.9, 0.35, 0.35),
	"Complete": Color(0.8, 0.8, 0.8),
}

## NOTE: bind_map, not bind — `bind` is a built-in Callable method.
func bind_map(map: RunMap) -> void:
	run_map = map
	refresh()

## Show the current step of the run.
func refresh() -> void:
	_clear_cards()
	_clear_actions()
	show()

	if run_map == null or run_map.is_complete():
		_show_complete()
		return

	var stage := run_map.stage_name()
	stage_label.text = stage.to_upper()
	stage_label.add_theme_color_override("font_color", STAGE_COLORS.get(stage, Color.WHITE))
	quota_label.text = "Next quota: GOLD %d  +  Index %d  (now %d)" % [
		int(run_map.current_quota()), int(run_map.current_stock_quota()),
		int(RunState.empire_index())]

	var step: RunMap.Step = run_map.current()
	if step == null:
		_show_complete()
		return

	match step.kind:
		RunMap.StepKind.HEIST_CHOICE:
			_show_heist_choice(step)
		RunMap.StepKind.SHOP:
			_show_shop(step)
		RunMap.StepKind.QUOTA_GATE:
			_show_quota_gate()
		RunMap.StepKind.ADVANCE:
			_show_advance()

# --- Heist choice ---
func _show_heist_choice(step: RunMap.Step) -> void:
	step_title.text = "CHOOSE YOUR SCORE"
	for i in step.options.size():
		var node = step.options[i]
		var card := _make_heist_card(node, i)
		card_row.add_child(card)
		_cards.append(card)
		_animate_in(card, i)

func _make_heist_card(node: MapNode, index: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 260)
	card.set_meta("qa_label", "HEIST OPTION %d" % (index + 1))

	var is_mystery := (node.type == MapNode.Type.MYSTERY and not node.revealed \
		and not RunState.has_perk(&"recon"))   # Recon perk reveals ? nodes
	var accent := Color(0.7, 0.55, 0.95) if is_mystery else _rarity_color(node.room_rarity)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.12)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 14; sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	if is_mystery:
		title.text = "?"
	else:
		title.text = node.label()
	title.add_theme_color_override("font_color", accent)
	vb.add_child(title)

	# Detail: venue + rarity (hidden for mystery). Hook: a "Recon" upgrade could
	# force-show rarity even on mystery nodes later.
	var detail := Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_mystery:
		detail.text = "Unknown score.\nHigh risk."
	else:
		detail.text = String(node.venue_id).to_upper() + "\n" + _rarity_name(node.room_rarity)
	vb.add_child(detail)
	var tag := Label.new()
	tag.text = node.modifier_name() + "\n" + node.modifier_detail()
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 19)
	tag.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tag)

	if node.is_valuable and not is_mystery:
		var star := Label.new()
		star.text = "★ VALUABLE"
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
		vb.add_child(star)

	card.gui_input.connect(_on_card_input.bind(index))
	card.mouse_entered.connect(func(): card.position.y = -8)
	card.mouse_exited.connect(func(): card.position.y = 0)
	return card

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var node = run_map.choose_option(index)
		if node:
			hide()
			heist_chosen.emit(node)

# --- Shop (skippable) ---
func _show_shop(step: RunMap.Step) -> void:
	step_title.text = "A BREAK — THE FENCE'S SHOP"
	var enter := Button.new()
	enter.custom_minimum_size.y = 74
	enter.text = "Enter Shop"
	enter.pressed.connect(func():
		pass # Debug logging removed.
		hide()
		shop_opened.emit())
	action_row.add_child(enter)

	if step.skippable:
		var skip := Button.new()
		skip.custom_minimum_size.y = 74
		skip.text = "Skip (look for a way around…)"
		skip.pressed.connect(func():
			hide(); shop_skipped.emit())
		action_row.add_child(skip)

# --- Quota gate ---
func _show_quota_gate() -> void:
	step_title.text = "QUOTA CHECK — GOLD %d and Index %d required (you: GOLD %d, %d)" % [
		int(run_map.current_quota()), int(run_map.current_stock_quota()),
		get_node("/root/RunEconomy").gold, int(RunState.empire_index())]
	var proceed := Button.new()
	proceed.custom_minimum_size.y = 74
	proceed.text = "Face the quota"
	proceed.pressed.connect(func():
		quota_reached.emit(run_map.current_quota()))
	action_row.add_child(proceed)

# --- Advance ---
func _show_advance() -> void:
	step_title.text = "MOVE TO THE NEXT CITY"
	var go := Button.new()
	go.custom_minimum_size.y = 74
	go.text = "Advance"
	go.pressed.connect(func():
		run_advanced.emit())
	action_row.add_child(go)

func _show_complete() -> void:
	step_title.text = "RUN COMPLETE"
	stage_label.text = "DOOMSDAY CLEARED"
	var done := Button.new()
	done.custom_minimum_size.y = 74
	done.text = "Finish"
	done.pressed.connect(func(): run_complete.emit())
	action_row.add_child(done)

# --- Helpers ---
func _animate_in(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	card.position.y = 30
	var t := create_tween().set_parallel(true)
	var d := index * 0.1
	t.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(d)
	t.tween_property(card, "position:y", 0.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)

func _clear_cards() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()

func _clear_actions() -> void:
	for c in action_row.get_children():
		c.queue_free()

func _rarity_color(rarity: int) -> Color:
	# Reuse the room rarity feel: common grey -> boss red.
	var colors := [
		Color(0.75, 0.75, 0.78), Color(0.4, 0.8, 0.45), Color(0.4, 0.6, 0.95),
		Color(0.9, 0.6, 0.3), Color(0.85, 0.4, 0.9), Color(0.6, 0.6, 0.6),
		Color(0.9, 0.3, 0.3),
	]
	return colors[clampi(rarity, 0, colors.size() - 1)]

func _rarity_name(rarity: int) -> String:
	var names := ["Common", "Uncommon", "Rare", "Pumped", "Elite", "Chest", "Boss"]
	return names[clampi(rarity, 0, names.size() - 1)]
