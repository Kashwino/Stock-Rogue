extends CanvasLayer
## In-heist HUD (Brief 3: Noir Props), built in code under one full-rect
## Control root. Props on the heist table, pulp slants for action, and the
## ticker tape as the one straight element across the top:
##   top:           ticker tape (perforated paper; the robbed venue circled)
##   top-left:      the objective on a torn, paperclipped notepad page
##   top-centre:    slanted heat bar, five police badges, EXIT sign, heat log
##   top-right:     MAP / PAUSE typewriter keys (owned by the heist and the
##                  pause menu), the blueprint minimap, the ticker machine
##                  with the venue's chart, the trader feed as telegrams
##   right-centre:  THE RALLY combo slab
##   bottom-left:   health as a poker-chip stack, cash in a money clip with
##                  the loot multiplier on a luggage tag
##   bottom-centre: DOUBLE / TRIPLE / MASSACRE banners, cash-out captions,
##                  relics as matchbooks
##   bottom-right:  the gun, its rounds, the reserve's cartridge box
## Each corner cluster is anchored to its corner and scales about it (HUD
## scale); the whole HUD fades with HUD opacity; Minimal style swaps props for
## outlined text. With touch controls on screen the bottom corners belong to
## the thumbs, so the vitals move under the objective and the gun to the
## bottom centre. Nothing here pauses the tree.
##
## Call bind_hud(player, live_stock, loadout) once from the heist setup.

var root: Control
var ticker: TickerTape
var chips: HudProps.ChipStack
var money: HudProps.MoneyClip
var objective_note: HudPaper.ObjectiveNote
var heat: HudPulp.HeatBar
var minimap: HudPaper.BlueprintMap
var weapon_panel: HudProps.WeaponRack
var stock: HudPaper.TickerMachine
var stock_chart: StockChart
var trader_feed: TraderFeed
var boss_bar: BossBar
var multi_banner: HudPulp.Banner
var combo_panel: HudPulp.ComboSlab
var matchbooks: HudProps.Matchbooks
var _combo_popup: HudPulp.Caption

var _loadout = null
var _live = null
var _clusters: Dictionary = {}       # name -> [Control, pivot corner (0..1)]
var _touch_layout := false
var _layout_clock := 0.0

func _ready() -> void:
	for child in get_children():
		child.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	ticker = TickerTape.new()
	ticker.paper = true
	ticker.position = Vector2.ZERO
	ticker.size = Vector2(1280, 30)
	root.add_child(ticker)

	var top_left := _cluster("top_left", Vector2(0, 0), Vector2(310, 170))
	objective_note = HudPaper.ObjectiveNote.new()
	objective_note.size = Vector2(300, 160)
	objective_note.position = Vector2(4, 8)
	top_left.add_child(objective_note)

	var top_center := _cluster("top_center", Vector2(0.5, 0), Vector2(520, 120))
	heat = HudPulp.HeatBar.new()
	heat.size = Vector2(520, 120)
	top_center.add_child(heat)

	var top_right := _cluster("top_right", Vector2(1, 0), Vector2(248, 322))
	minimap = HudPaper.BlueprintMap.new()
	minimap.size = Vector2(248, 132)
	top_right.add_child(minimap)
	stock = HudPaper.TickerMachine.new()
	stock.position = Vector2(0, 134)
	stock.size = Vector2(248, 128)
	top_right.add_child(stock)
	stock_chart = stock.chart
	trader_feed = TraderFeed.new()
	trader_feed.telegram = true
	trader_feed.position = Vector2(4, 264)
	trader_feed.size = Vector2(244, 62)
	top_right.add_child(trader_feed)

	var right := _cluster("right", Vector2(1, 0.5), Vector2(272, 140))
	combo_panel = HudPulp.ComboSlab.new()
	combo_panel.size = Vector2(272, 140)
	combo_panel.pivot_offset = Vector2(272, 0)
	right.add_child(combo_panel)

	var bottom_left := _cluster("bottom_left", Vector2(0, 1), Vector2(316, 140))
	chips = HudProps.ChipStack.new()
	chips.size = Vector2(70, 138)
	bottom_left.add_child(chips)
	money = HudProps.MoneyClip.new()
	money.position = Vector2(72, 50)
	money.size = Vector2(236, 90)
	bottom_left.add_child(money)

	var bottom_center := _cluster("bottom_center", Vector2(0.5, 1), Vector2(800, 210))
	multi_banner = HudPulp.Banner.new()
	multi_banner.position = Vector2(140, 0)
	multi_banner.size = Vector2(520, 92)
	bottom_center.add_child(multi_banner)
	_combo_popup = HudPulp.Caption.new()
	_combo_popup.position = Vector2(0, 98)
	_combo_popup.size = Vector2(800, 46)
	bottom_center.add_child(_combo_popup)
	matchbooks = HudProps.Matchbooks.new()
	matchbooks.position = Vector2(230, 150)
	matchbooks.size = Vector2(340, 60)
	bottom_center.add_child(matchbooks)

	var bottom_right := _cluster("bottom_right", Vector2(1, 1), Vector2(340, 104))
	weapon_panel = HudProps.WeaponRack.new()
	weapon_panel.size = Vector2(340, 104)
	bottom_right.add_child(weapon_panel)

	boss_bar = BossBar.new()
	root.add_child(boss_bar)

	if has_node("/root/RunEconomy"):
		_update_gold(RunEconomy.gold)
		RunEconomy.gold_changed.connect(_update_gold)
	Settings.changed.connect(_apply_settings)
	root.resized.connect(_layout)
	_apply_settings()

## A corner-anchored group of widgets. `anchor` is where on the screen (and
## on the cluster) it pins: (0,0) top-left ... (1,1) bottom-right.
func _cluster(id: String, anchor: Vector2, size: Vector2) -> Control:
	var c := Control.new()
	c.name = id
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = size
	c.pivot_offset = size * anchor
	root.add_child(c)
	_clusters[id] = [c, anchor]
	return c

func _apply_settings() -> void:
	root.modulate.a = float(Settings.values.get("hud_opacity", 1.0))
	_layout()
	for w: CanvasItem in [chips, money, objective_note, heat, minimap, weapon_panel, stock, multi_banner, combo_panel, matchbooks, _combo_popup, ticker]:
		if w:
			w.queue_redraw()

## Touch controls take the bottom corners (see mobile_controls.gd).
static func touch_controls_shown() -> bool:
	var mode: int = Settings.values.get("touch_mode", 0)
	return mode == 1 or (mode == 0 and (DisplayServer.is_touchscreen_available() or TouchInput.touch_active))

func _process(delta: float) -> void:
	_layout_clock -= delta
	if _layout_clock <= 0.0:
		_layout_clock = 0.5
		if touch_controls_shown() != _touch_layout:
			_layout()

## Place every cluster for the screen size, the HUD scale and the input.
func _layout() -> void:
	if root == null:
		return
	var view := root.size if root.size.x > 0.0 else Vector2(1280, 720)
	var s := float(Settings.values.get("hud_scale", 1.0))
	var margin := 16.0
	_touch_layout = touch_controls_shown()
	var spots := {
		"top_left": Vector2(margin, 34),
		"top_center": Vector2(view.x * 0.5, 30),
		"top_right": Vector2(view.x - margin, 104),
		"right": Vector2(view.x - margin, 532),
		"bottom_left": Vector2(margin, view.y - 8),
		"bottom_center": Vector2(view.x * 0.5, view.y - 6),
		"bottom_right": Vector2(view.x - margin, view.y - 8),
	}
	if _touch_layout:
		# The thumbs own the bottom corners: vitals under the objective, the
		# gun bottom-centre, the combo on the left.
		spots["bottom_left"] = Vector2(margin, 206 + 140)
		spots["bottom_right"] = Vector2(view.x * 0.5 + 120, view.y - 8)
		spots["bottom_center"] = Vector2(view.x * 0.5, view.y - 112)
		spots["right"] = Vector2(margin + 272, 420)
	for id: String in _clusters:
		var c: Control = _clusters[id][0]
		var anchor: Vector2 = _clusters[id][1]
		if id == "right" and _touch_layout:
			anchor = Vector2(1, 0)
		c.scale = Vector2(s, s)
		c.pivot_offset = c.size * anchor
		c.position = spots[id] - c.size * anchor
	ticker.size = Vector2(view.x, 30)
	# The MELEE thumb button sits where the telegrams would: the chatter
	# steps aside while touch controls are up.
	if trader_feed:
		trader_feed.visible = not _touch_layout

## Wire the combo panel and its cash-out / panic-sell captions.
func bind_combo(combo: Combo) -> void:
	combo_panel.bind_combo(combo)
	combo.cashed.connect(_on_combo_cashed)
	combo.panicked.connect(_on_combo_panicked)

func _on_combo_cashed(points: int, tier: int, gold: int, pct: float) -> void:
	combo_popup("COMBO CASHED — %d pts · %s · +$%d · %+.1f%%" % [points, Combo.TIERS[tier], gold, pct * 100.0], Combo.TIER_COLORS[tier], false)

func _on_combo_panicked(points: int, _tier: int, gold: int) -> void:
	combo_popup("PANIC SELL — %d pts dumped · +$%d" % [points, gold], Palette.DANGER, true)

func combo_popup(text: String, color: Color, slam: bool) -> void:
	_combo_popup.show_line(text, color, slam)

## Call from the heist setup: hooks health + stock + loadout signals.
## Named bind_hud, not bind — `bind` is a built-in Callable method.
func bind_hud(player, live_stock, loadout = null) -> void:
	if player:
		_update_health(player.health, player.max_health)
		player.health_changed.connect(_update_health)
	if live_stock:
		_live = live_stock
		ticker.highlight = live_stock.venue_asset_id
		stock.set_venue(live_stock.venue_asset_id)
		live_stock.price_updated.connect(_update_stock)
		trader_feed.bind_stock(live_stock)
		_update_stock(0.0, 0.0, 1)
	if loadout:
		_loadout = loadout
		loadout.active_changed.connect(_update_weapon)
		loadout.ammo_changed.connect(_update_ammo)
		loadout.reload_started.connect(_on_reload_started)
		loadout.reload_finished.connect(_on_reload_finished)
		var w = loadout.get_active()
		if w:
			var a: Dictionary = loadout._active_ammo()
			weapon_panel.set_weapon(w, a["mag"], a["reserve"])

func bind_floor(floor_host: Node) -> void:
	minimap.floor_host = floor_host

## Heat readout pushed by the heist every few frames.
func set_heat(value: float, dispatch: float, fire_limit: float, timer: float) -> void:
	heat.set_values(value, dispatch, fire_limit, timer)

func set_wanted(stars: int) -> void:
	heat.set_stars(stars)

## A heat source ("CAMERA SPOTTED YOU +8") for the meter's log.
func log_heat(text: String) -> void:
	heat.push_source(text)

func set_objective(title: String, body: String) -> void:
	objective_note.set_objective(title, body)

func set_loot_multiplier(mult: float) -> void:
	money.set_loot_multiplier(mult)

func _on_reload_started(duration: float) -> void:
	weapon_panel.start_reload(duration)

func _on_reload_finished() -> void:
	if _loadout:
		var a: Dictionary = _loadout._active_ammo()
		weapon_panel.set_ammo(a["mag"], a["reserve"])

func _update_weapon(weapon, mag: int, reserve: int) -> void:
	weapon_panel.set_weapon(weapon, mag, reserve)

func _update_ammo(mag: int, reserve: int) -> void:
	weapon_panel.set_ammo(mag, reserve)

func _update_health(current: int, maxv: int) -> void:
	chips.set_health(clampi(current, 0, maxv), maxv)

func _update_gold(amount: int) -> void:
	money.set_gold(amount)

## The bills riffle when a floor pickup lands in the clip.
func flash_gold() -> void:
	if money and not Settings.values["low_effects"] and not HudKit.reduce_motion():
		money._riffle = 1.0
		money.animate(0.6)

## A "+$25" that flies from the pickup into the money clip.
func fly_gold(screen_pos: Vector2, amount: int) -> void:
	var l := VisualTheme.label("+$%d" % amount, "", 22, Palette.GOLD_PALE)
	l.add_theme_font_override("font", VisualTheme.font("type_bold"))
	l.add_theme_color_override("font_outline_color", Palette.HUD_INK)
	l.add_theme_constant_override("outline_size", 5)
	root.add_child(l)
	l.position = screen_pos - Vector2(20, 20)
	var target := gold_anchor()
	var tw := l.create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -24), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "scale", Vector2(0.6, 0.6), 0.45)
	tw.tween_callback(flash_gold)
	tw.tween_callback(l.queue_free)

## Where pickups should fly to (screen space): the money clip.
func gold_anchor() -> Vector2:
	return money.anchor() if money else Vector2(60, 640)

func _update_stock(_price: float, _delta: float, direction: int) -> void:
	if _live == null or RunState.market == null:
		return
	var a: CriminalAsset = RunState.market.get_asset(_live.venue_asset_id)
	if a == null:
		return
	var ratio := a.current_price / maxf(a.base_price, 0.01) - 1.0
	stock.set_price(a.current_price, ratio, direction > 0)
	if absf(_delta) > 0.001:
		stock_chart.refresh()
