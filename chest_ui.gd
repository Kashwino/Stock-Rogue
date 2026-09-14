extends CanvasLayer
## Chest reveal UI. Builds its ENTIRE interface in code, so the scene is just:
##   CanvasLayer (root) + this script.
## No child nodes, no unique names, nothing to wire up.
##
## Why: a CanvasLayer dispatches mouse input down the CONTROL tree. If the UI's
## contents hang directly off the CanvasLayer with no full-rect Control in
## between, nothing owns the mouse and buttons never receive clicks — while the
## keyboard still works, because _input bypasses the GUI system. Building the
## tree here guarantees the Control root exists.
##
## It also PAUSES the game while open, so the player can't shoot, move, or take
## damage while choosing an item.

signal item_chosen(item)

const CARD_SIZE := Vector2(160, 230)

var _root: Control
var _dim: ColorRect
var _chest_label: Label
var _card_row: HBoxContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_rarity: Label
var _detail_stats: Label

var _cards: Array = []
var _open: bool = false

func _ready() -> void:
	layer = 80
	# Must keep running while the tree is paused, or the UI would freeze itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()

# ------------------------------------------------------------------ build ---
func _build() -> void:
	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# PASS: the root doesn't consume clicks itself, but its presence is what
	# lets Godot route mouse events down to the cards.
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.04, 0.82)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE    # never eat a click
	_root.add_child(_dim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	_chest_label = Label.new()
	_chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_label.add_theme_font_size_override("font_size", 26)
	_chest_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_chest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_chest_label)

	# Cards live in a centred row.
	var row_center := CenterContainer.new()
	row_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row_center)

	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 20)
	_card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_center.add_child(_card_row)

	# Hover inspector under the cards.
	var detail_center := CenterContainer.new()
	detail_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(detail_center)

	_detail_panel = PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.08, 0.08, 0.11, 0.95)
	dsb.border_color = Color(0.3, 0.31, 0.38)
	dsb.set_border_width_all(2)
	dsb.set_corner_radius_all(6)
	dsb.content_margin_left = 18
	dsb.content_margin_right = 18
	dsb.content_margin_top = 12
	dsb.content_margin_bottom = 12
	_detail_panel.add_theme_stylebox_override("panel", dsb)
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.custom_minimum_size = Vector2(420, 0)
	detail_center.add_child(_detail_panel)

	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 4)
	dcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(dcol)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 18)
	_detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dcol.add_child(_detail_name)

	_detail_rarity = Label.new()
	_detail_rarity.add_theme_font_size_override("font_size", 13)
	_detail_rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dcol.add_child(_detail_rarity)

	_detail_stats = Label.new()
	_detail_stats.add_theme_font_size_override("font_size", 13)
	_detail_stats.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dcol.add_child(_detail_stats)

	_detail_panel.hide()

# ------------------------------------------------------------------- open ---
## items: Array of WeaponItem/UpgradeItem. tier_name: e.g. "Airdrop".
func open_chest(items: Array, tier_name: String = "") -> void:
	print("[ChestUI] open_chest called with ", items.size(), " items")
	if items.is_empty():
		push_warning("ChestUI: opened with no items — nothing to choose.")
		return

	var head: String = (tier_name.to_upper() + "  —  CLAIM ONE") if tier_name != "" \
		else "CLAIM ONE"
	_chest_label.text = head + "\n(click a card, or press 1 / 2 / 3)"

	_clear_cards()
	for i in items.size():
		var card := _make_card(items[i])
		_card_row.add_child(card)
		_cards.append(card)
		card.modulate.a = 0.0
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(i * 0.1)

	_root.show()
	_open = true
	# Freeze the heist: no shooting, no enemies, no damage while choosing.
	get_tree().paused = true

	if not _cards.is_empty():
		_cards[0].grab_focus()
	print("[ChestUI] built ", _cards.size(), " cards; paused=", get_tree().paused)

func _make_card(item) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.clip_text = false
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var col: Color = item.rarity_color()
	card.text = "%s\n\n%s" % [item.display_name, item.rarity_name()]
	card.add_theme_color_override("font_color", col)
	card.add_theme_color_override("font_hover_color", Color.WHITE)
	card.add_theme_color_override("font_focus_color", Color.WHITE)
	card.add_theme_font_size_override("font_size", 15)

	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.09, 0.12)
		if state == "hover" or state == "focus":
			sb.bg_color = Color(0.15, 0.15, 0.2)
		elif state == "pressed":
			sb.bg_color = Color(0.05, 0.05, 0.07)
		sb.border_color = col
		sb.set_border_width_all(4 if state != "normal" else 3)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		card.add_theme_stylebox_override(state, sb)

	card.pressed.connect(_claim.bind(item))
	card.mouse_entered.connect(_show_detail.bind(item))
	card.focus_entered.connect(_show_detail.bind(item))
	card.mouse_exited.connect(_hide_detail)
	card.set_meta("item", item)
	return card

# ------------------------------------------------------------------ input ---
## Keyboard fallback. Uses _input so nothing can consume the key first.
func _input(event: InputEvent) -> void:
	if not _open or _cards.is_empty():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index := -1
	match event.keycode:
		KEY_1: index = 0
		KEY_2: index = 1
		KEY_3: index = 2
	if index < 0 or index >= _cards.size():
		return
	var card: Control = _cards[index]
	if is_instance_valid(card) and card.has_meta("item"):
		_claim(card.get_meta("item"))
		get_viewport().set_input_as_handled()

# ----------------------------------------------------------------- detail ---
func _show_detail(item) -> void:
	_detail_name.text = item.display_name
	_detail_name.add_theme_color_override("font_color", item.rarity_color())
	_detail_rarity.text = item.rarity_name()
	_detail_rarity.add_theme_color_override("font_color", item.rarity_color())
	_detail_stats.text = _stats_text(item)
	_detail_panel.show()

func _hide_detail() -> void:
	_detail_panel.hide()

func _stats_text(item) -> String:
	if item is WeaponItem:
		var parts := [
			"Damage %d" % item.damage,
			"Fire rate %.2f/s" % (1.0 / maxf(item.fire_rate, 0.01)),
			"Reload %.1fs" % item.reload_time,
		]
		if item.pellets > 1:
			parts.append("%d pellets" % item.pellets)
		if not item.uses_ammo:
			parts.append("Infinite ammo")
		else:
			parts.append("Mag %d" % item.mag_size)
		return "  -  ".join(parts)
	elif item is UpgradeItem:
		return item.description
	return ""

# ------------------------------------------------------------------ claim ---
func _claim(item) -> void:
	if not _open:
		return
	print("[ChestUI] claiming: ", item.display_name if item else "<null>")
	_open = false
	get_tree().paused = false          # hand control back before anything else
	item_chosen.emit(item)
	_detail_panel.hide()
	_root.hide()
	_clear_cards()

## Safety: if this UI is ever removed while open, don't leave the game frozen.
func _exit_tree() -> void:
	if _open and is_inside_tree():
		get_tree().paused = false

func _clear_cards() -> void:
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
