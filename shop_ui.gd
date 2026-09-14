extends CanvasLayer
## The Fence's Shop. Sells a fixed set of weapons + upgrades (heal, ammo, stat
## boosts) at fixed, deliberately expensive prices. Gold is scarce, so each
## purchase is a real decision. Buying applies to RunState (persists across the run).
##
## Call open_shop() to stock and show. Emits closed when the player leaves.

signal closed()

## Built entirely in code so the three-column layout is guaranteed and the
## buttons can't be broken by a mis-wired scene: shop on the LEFT, the live
## stock chart in the MIDDLE, five upgrade slots on the RIGHT (top to bottom).
## Scene is just: CanvasLayer (root) + this script.

var _root: Control
var _gold_label: Label
var _shop_column: VBoxContainer     # left: market operations
var _upgrade_column: VBoxContainer  # right: 5 upgrades
var _chart_holder: Control          # middle: stock chart lives here
var _leave_button: Button

# Fixed stock. Each entry: {kind, price, and the payload}.
# kinds: "heal", "ammo", "weapon", "upgrade", "perk", "pump".
var _stock: Array = []

## Run perks the Fence can sell (once each per run).
const PERKS := [
	{"id": &"recon", "price": 250, "name": "Recon Network",
		"desc": "Reveals ? nodes on the map before you commit"},
	{"id": &"inside_trader", "price": 300, "name": "Inside Trader",
		"desc": "+25% on positive stock swings from heist grades"},
]

func _ready() -> void:
	# The shop must keep processing itself if anything ever pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if self is CanvasLayer:
		layer = 70

	# CRITICAL: purge any children that came from the scene file. This script
	# used to live on a scene with its own panel/list/button — those nodes are
	# not managed by the rebuilt code, so they were never hidden and sat at
	# layer 70 covering the ENTIRE map with a black panel and one dead button.
	for c in get_children():
		c.queue_free()

	_build_ui()
	if self is CanvasLayer:
		hide()               # hiding the layer hides everything under it
	if _root:
		_root.process_mode = Node.PROCESS_MODE_ALWAYS
		_root.hide()
	print("[ShopUI] ready OK (purged old scene children)")

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 10)
	outer.offset_left = 40; outer.offset_top = 30
	outer.offset_right = -40; outer.offset_bottom = -30
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(outer)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "THE FENCE"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_gold_label)
	outer.add_child(header)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	outer.add_child(columns)

	_shop_column = _make_column(columns, "MARKET OPERATIONS", 1.2)
	_chart_holder = _make_chart_column(columns)
	_upgrade_column = _make_column(columns, "UPGRADES", 1.0)

	_leave_button = Button.new()
	_leave_button.text = "Leave the Fence"
	_leave_button.custom_minimum_size = Vector2(0, 40)
	_leave_button.pressed.connect(_on_leave)
	outer.add_child(_leave_button)

## A titled column that holds item rows.
func _make_column(parent: Control, heading_text: String, stretch: float) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_stretch_ratio = stretch
	wrap.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	wrap.add_child(heading)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(list)

	parent.add_child(wrap)
	return list

## The middle column: a header plus the stock chart.
func _make_chart_column(parent: Control) -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_stretch_ratio = 1.4
	wrap.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = "THE MARKET"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	wrap.add_child(heading)

	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(holder)

	# Create the chart with its script already attached, so entering the tree
	# fires its _ready() exactly once, the normal way.
	var chart: Control
	if ResourceLoader.exists("res://stock_chart.gd"):
		var cls = load("res://stock_chart.gd")
		chart = cls.new()
	else:
		chart = Control.new()
	chart.custom_minimum_size = Vector2(320, 260)
	holder.add_child(chart)

	parent.add_child(wrap)
	return holder

func open_shop() -> void:
	_build_stock()
	_render()
	var ops := _shop_column.get_child_count()
	var ups := _upgrade_column.get_child_count()
	if self is CanvasLayer:
		show()               # the CanvasLayer itself, in case it was hidden
	_root.show()
	print("[ShopUI] open_shop: ", ops, " ops + ", ups, " upgrades, visible=",
		_root.visible)

func _render() -> void:
	_update_gold()
	for c in _shop_column.get_children():
		c.queue_free()
	for c in _upgrade_column.get_children():
		c.queue_free()
	for i in _stock.size():
		var entry: Dictionary = _stock[i]
		var is_op: bool = entry["kind"] in [
			"pump_weak", "pump_all", "short_squeeze", "floor_price", "perk"]
		var target := _shop_column if is_op else _upgrade_column
		target.add_child(_make_row(entry, i))

func _make_row(entry: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.13)
	sb.border_color = Color(0.25, 0.26, 0.32)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = entry["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = entry["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.66, 0.72))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)
	row.add_child(info)

	var right := VBoxContainer.new()
	var price_lbl := Label.new()
	price_lbl.text = "⦿ " + str(entry["price"])
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(price_lbl)
	var buy := Button.new()
	buy.text = "Buy"
	buy.custom_minimum_size = Vector2(70, 0)
	buy.pressed.connect(_on_buy.bind(index, buy))
	right.add_child(buy)
	row.add_child(right)

	return panel

func _on_buy(index: int, button: Button) -> void:
	var entry: Dictionary = _stock[index]
	var econ = get_node_or_null("/root/RunEconomy")
	if econ == null or not econ.can_afford(entry["price"]):
		button.modulate = Color(1, 0.4, 0.4)
		var t := create_tween()
		t.tween_property(button, "modulate", Color.WHITE, 0.4)
		return
	econ.spend(entry["price"])
	_apply_purchase(entry)
	if entry["kind"] == "perk":
		button.disabled = true
		button.text = "Owned"
	else:
		button.text = "Bought"
	_update_gold()

func _build_stock() -> void:
	_stock.clear()
	var rs = get_node_or_null("/root/RunState")
	var qb: int = rs.run_map.quota_block if (rs and rs.run_map) else 0
	var scale := pow(1.55, qb)      # everything gets pricier as quotas climb

	# --- MARKET OPERATIONS (the main way to clear a stock quota) ---
	_stock.append({"kind": "pump_weak", "price": int(120 * scale),
		"name": "Spread Rumors",
		"desc": "+25% to your weakest venue. Repeatable."})

	_stock.append({"kind": "pump_all", "price": int(260 * scale),
		"name": "Market Manipulation",
		"desc": "+8% to EVERY venue at once. Moves the Index directly."})

	_stock.append({"kind": "short_squeeze", "price": int(200 * scale),
		"name": "Short Squeeze",
		"desc": "Doubles the distance of your best venue above baseline."})

	_stock.append({"kind": "floor_price", "price": int(230 * scale),
		"name": "Protection Money",
		"desc": "Lifts every venue below baseline back up to 1.00."})

	# --- RUN PERKS (one-time each) ---
	for perk: Dictionary in PERKS:
		if rs and not rs.has_perk(perk["id"]):
			_stock.append({"kind": "perk", "price": perk["price"],
				"perk_id": perk["id"], "name": perk["name"], "desc": perk["desc"]})

	# --- UPGRADES (right column, five of them top to bottom) ---
	_stock.append({"kind": "heal", "price": int(140 * scale), "amount": 1,
		"name": "Patch Kit", "desc": "Restore 1 health"})
	_stock.append({"kind": "ammo", "price": int(90 * scale), "amount": 120,
		"name": "Ammo Crate", "desc": "Refill reserve ammo for all weapons"})
	_stock.append({"kind": "upgrade_hp", "price": int(300 * scale),
		"name": "Kevlar Lining", "desc": "+1 max health (permanent this run)"})
	_stock.append({"kind": "upgrade_speed", "price": int(220 * scale),
		"name": "Combat Stims", "desc": "+12% move speed (permanent this run)"})
	_stock.append({"kind": "upgrade_firerate", "price": int(260 * scale),
		"name": "Filed Trigger", "desc": "Fire 12% faster (permanent this run)"})

func _apply_purchase(entry: Dictionary) -> void:
	var rs = get_node_or_null("/root/RunState")
	match entry["kind"]:
		"heal":
			if rs: rs.heal(int(entry.get("amount", 1)))
		"ammo":
			if rs and rs.loadout:
				# Top up every carried weapon's ammo type.
				for tag in ["big", "small"]:
					var arr = rs.loadout.big if tag == "big" else rs.loadout.small
					for w in arr:
						if w != null and w.uses_ammo:
							rs.loadout.scavenge(w.ammo_type, int(entry.get("amount", 90)))
		"weapon":
			if rs and rs.loadout:
				rs.loadout.equip(entry["item"])
		"perk":
			if rs:
				rs.add_perk(entry["perk_id"])
		"pump_weak":
			# +25% to the weakest venue (lowest current/base ratio).
			if rs and rs.market:
				var weakest = null
				var worst := INF
				for a in rs.market.assets:
					if a.base_price <= 0.0:
						continue
					var ratio: float = a.current_price / a.base_price
					if ratio < worst:
						worst = ratio
						weakest = a
				if weakest:
					weakest.current_price *= 1.25
		"pump_all":
			# +8% across the board — the most direct way to move the Index.
			if rs and rs.market:
				for a in rs.market.assets:
					a.current_price *= 1.08
		"short_squeeze":
			# Doubles how far your best venue sits ABOVE its baseline.
			if rs and rs.market:
				var best = null
				var top := -INF
				for a in rs.market.assets:
					if a.base_price <= 0.0:
						continue
					var ratio: float = a.current_price / a.base_price
					if ratio > top:
						top = ratio
						best = a
				if best and top > 1.0:
					best.current_price = best.base_price * (1.0 + (top - 1.0) * 2.0)
		"floor_price":
			# Lift every underwater venue back to baseline.
			if rs and rs.market:
				for a in rs.market.assets:
					if a.base_price > 0.0 and a.current_price < a.base_price:
						a.current_price = a.base_price
		"upgrade_hp":
			if rs and rs.has_method("add_max_health"):
				rs.add_max_health(1)
		"upgrade_speed":
			if rs:
				rs.add_stat_mod(&"move_speed", 0.0, 1.12)
		"upgrade_firerate":
			if rs:
				# Lower fire interval = faster; multiply by <1.
				rs.add_stat_mod(&"fire_rate", 0.0, 0.88)
		"upgrade":
			var u = entry["item"]
			if rs:
				# Record persistent mod so it re-applies each heist.
				if u.mode == UpgradeItem.ApplyMode.ADD:
					if u.stat == &"max_health":
						rs.add_max_health(int(u.amount))
					else:
						rs.add_stat_mod(u.stat, u.amount, 1.0)
				else:
					rs.add_stat_mod(u.stat, 0.0, u.amount)

func _update_gold() -> void:
	var econ = get_node_or_null("/root/RunEconomy")
	_gold_label.text = "⦿ " + str(econ.gold if econ else 0)

func _on_leave() -> void:
	print("[ShopUI] leave pressed")
	if self is CanvasLayer:
		hide()
	_root.hide()
	closed.emit()


