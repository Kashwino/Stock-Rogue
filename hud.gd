extends CanvasLayer
## In-heist HUD, built entirely in code under one full-rect Control root.
##   top:           ticker tape crawl (every venue; the robbed one boxed gold)
##   top-left:      drawn hearts, gold counter, live loot multiplier, objective
##   top-centre:    heat meter with fire-exit and police ticks + heat log
##   top-right:     MAP / PAUSE (pause menu owns its button), minimap, stock
##   bottom-centre: weapon panel (icon, name, magazine pips, reserve, reload)
## Everything is sized for phones: nothing under 15 px at 1280x720.
##
## Call bind_hud(player, live_stock, loadout) once from the heist setup.

var root: Control
var ticker: TickerTape
var hearts: HudWidgets.Hearts
var gold_label: Label
var loot_label: Label
var objective_title: Label
var objective_body: Label
var heat: HudWidgets.HeatMeter
var minimap: HudWidgets.Minimap
var weapon_panel: HudWidgets.WeaponPanel
var stock_name_label: Label
var stock_label: Label
var stock_change: Label
var stock_chart: StockChart
var trader_feed: TraderFeed
var boss_bar: BossBar
var multi_banner: HudWidgets.MultiBanner
var combo_panel: HudWidgets.ComboPanel
var _combo_popup: Label
var _popup_tween: Tween

var _loadout = null
var _live = null
var _gold_tween: Tween
var _display_gold := -1.0
var _flash_tween: Tween

func _ready() -> void:
	for child in get_children():
		child.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	ticker = TickerTape.new()
	ticker.position = Vector2.ZERO
	ticker.size = Vector2(1280, 30)
	root.add_child(ticker)

	var status := _panel(Rect2(14, 38, 318, 104))
	hearts = HudWidgets.Hearts.new()
	hearts.position = Vector2(12, 8)
	hearts.size = Vector2(294, 34)
	status.add_child(hearts)
	gold_label = VisualTheme.label("0", "", 26, Palette.GOLD)
	gold_label.add_theme_font_override("font", VisualTheme.font("mono"))
	gold_label.position = Vector2(14, 44)
	status.add_child(gold_label)
	loot_label = VisualTheme.label("LOOT x1.00", "", 16, Palette.PAPER_DIM)
	loot_label.add_theme_font_override("font", VisualTheme.font("mono"))
	loot_label.position = Vector2(14, 78)
	status.add_child(loot_label)

	var objective := _panel(Rect2(14, 150, 318, 92))
	objective_title = VisualTheme.label("OBJECTIVE", "KickerLabel", 16)
	objective_title.position = Vector2(12, 6)
	objective.add_child(objective_title)
	objective_body = VisualTheme.label("Grab the valuables.\nGet back to the car.", "", 17, Palette.PAPER)
	objective_body.position = Vector2(12, 28)
	objective_body.size = Vector2(296, 60)
	objective_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(objective_body)

	heat = HudWidgets.HeatMeter.new()
	heat.position = Vector2(372, 40)
	heat.size = Vector2(560, 110)
	root.add_child(heat)

	minimap = HudWidgets.Minimap.new()
	minimap.position = Vector2(1040, 104)
	minimap.size = Vector2(226, 150)
	root.add_child(minimap)

	var stock := _panel(Rect2(1040, 262, 226, 150))
	stock_name_label = VisualTheme.label("", "KickerLabel", 16)
	stock_name_label.position = Vector2(10, 4)
	stock_name_label.size = Vector2(206, 22)
	stock_name_label.clip_text = true
	stock.add_child(stock_name_label)
	stock_label = VisualTheme.label("$0", "", 24, Palette.PAPER)
	stock_label.add_theme_font_override("font", VisualTheme.font("mono"))
	stock_label.position = Vector2(10, 24)
	stock.add_child(stock_label)
	stock_change = VisualTheme.label("", "", 16, Palette.PAPER_DIM)
	stock_change.add_theme_font_override("font", VisualTheme.font("mono"))
	stock_change.position = Vector2(130, 30)
	stock.add_child(stock_change)
	stock_chart = StockChart.new()
	stock_chart.position = Vector2(6, 58)
	stock_chart.size = Vector2(214, 86)
	stock.add_child(stock_chart)

	trader_feed = TraderFeed.new()
	trader_feed.position = Vector2(1040, 418)
	trader_feed.size = Vector2(226, 86)
	root.add_child(trader_feed)

	boss_bar = BossBar.new()
	root.add_child(boss_bar)

	var relic_row := HudWidgets.RelicTokens.new()
	relic_row.position = Vector2(14, 248)
	relic_row.size = Vector2(318, 30)
	root.add_child(relic_row)

	multi_banner = HudWidgets.MultiBanner.new()
	root.add_child(multi_banner)
	combo_panel = HudWidgets.ComboPanel.new()
	root.add_child(combo_panel)
	_combo_popup = VisualTheme.label("", "", 24, Palette.GOLD)
	_combo_popup.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	_combo_popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_combo_popup.add_theme_constant_override("outline_size", 7)
	_combo_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_popup.position = Vector2(240, 508)
	_combo_popup.size = Vector2(800, 40)
	_combo_popup.pivot_offset = Vector2(400, 20)
	_combo_popup.modulate.a = 0.0
	root.add_child(_combo_popup)

	weapon_panel = HudWidgets.WeaponPanel.new()
	weapon_panel.position = Vector2(430, 638)
	weapon_panel.size = Vector2(400, 72)
	root.add_child(weapon_panel)

	if has_node("/root/RunEconomy"):
		_update_gold(RunEconomy.gold)
		RunEconomy.gold_changed.connect(_update_gold)

## Wire the combo panel and its cash-out / panic-sell popups.
func bind_combo(combo: Combo) -> void:
	combo_panel.bind_combo(combo)
	combo.cashed.connect(_on_combo_cashed)
	combo.panicked.connect(_on_combo_panicked)

func _on_combo_cashed(points: int, tier: int, gold: int, pct: float) -> void:
	combo_popup("COMBO CASHED — %d pts · %s · +$%d · %+.1f%%" % [points, Combo.TIERS[tier], gold, pct * 100.0], Combo.TIER_COLORS[tier], false)

func _on_combo_panicked(points: int, _tier: int, gold: int) -> void:
	combo_popup("PANIC SELL — %d pts dumped · +$%d" % [points, gold], Palette.DANGER, true)

func combo_popup(text: String, color: Color, slam: bool) -> void:
	_combo_popup.text = text
	_combo_popup.add_theme_color_override("font_color", color)
	if _popup_tween:
		_popup_tween.kill()
	_popup_tween = create_tween()
	_combo_popup.modulate.a = 1.0
	if slam and not Settings.values.get("reduce_flashing", false):
		_combo_popup.scale = Vector2(1.6, 1.6)
		_popup_tween.tween_property(_combo_popup, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_combo_popup.scale = Vector2.ONE
	_popup_tween.tween_interval(1.8)
	_popup_tween.tween_property(_combo_popup, "modulate:a", 0.0, 0.5)

func _panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", VisualTheme.box(Palette.with_alpha(Palette.BG, 0.82), Palette.with_alpha(Palette.GOLD_DIM, 0.55), 1, 2, 0))
	root.add_child(p)
	return p

## Call from the heist setup: hooks health + stock + loadout signals.
## Named bind_hud, not bind — `bind` is a built-in Callable method.
func bind_hud(player, live_stock, loadout = null) -> void:
	if player:
		_update_health(player.health, player.max_health)
		player.health_changed.connect(_update_health)
	if live_stock:
		_live = live_stock
		ticker.highlight = live_stock.venue_asset_id
		stock_name_label.text = Venues.display_name(live_stock.venue_asset_id).to_upper()
		live_stock.price_updated.connect(_update_stock)
		stock_chart.venue_id = live_stock.venue_asset_id
		stock_chart.refresh()
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
	heat.heat = value
	heat.dispatch = dispatch
	heat.fire_limit = fire_limit
	heat.timer = timer

func set_wanted(stars: int) -> void:
	heat.set_stars(stars)

## A heat source ("CAMERA SPOTTED YOU +8") for the meter's log.
func log_heat(text: String) -> void:
	heat.push_source(text)

func set_objective(title: String, body: String) -> void:
	objective_title.text = title
	objective_body.text = body

func set_loot_multiplier(mult: float) -> void:
	loot_label.text = "LOOT x%.2f" % mult
	loot_label.add_theme_color_override("font_color", Palette.UP if mult > 1.02 else (Palette.DOWN if mult < 0.98 else Palette.PAPER_DIM))

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
	hearts.set_health(clampi(current, 0, maxv), maxv)

func _update_gold(amount: int) -> void:
	if _gold_tween and _gold_tween.is_valid():
		_gold_tween.kill()
	if _display_gold < 0.0 or Settings.values["low_effects"]:
		_draw_gold(float(amount))
	else:
		_gold_tween = create_tween()
		_gold_tween.tween_method(_draw_gold, _display_gold, float(amount), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw_gold(value: float) -> void:
	_display_gold = value
	gold_label.text = "$ %d" % roundi(value)

## Quick pop on the gold counter when a floor pickup is grabbed.
func flash_gold() -> void:
	if gold_label == null or Settings.values["low_effects"]:
		return
	gold_label.pivot_offset = gold_label.size * Vector2(0.2, 0.5)
	gold_label.scale = Vector2(1.25, 1.25)
	var t := create_tween()
	t.tween_property(gold_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A "+$25" that flies from the pickup to the gold counter.
func fly_gold(screen_pos: Vector2, amount: int) -> void:
	var l := VisualTheme.label("+$%d" % amount, "", 22, Palette.GOLD_PALE)
	l.add_theme_font_override("font", VisualTheme.font("mono"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
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

## Where pickups should fly to (screen space).
func gold_anchor() -> Vector2:
	return gold_label.global_position + Vector2(40, 16) if gold_label else Vector2(60, 90)

func _update_stock(_price: float, delta: float, direction: int) -> void:
	if _live == null or RunState.market == null:
		return
	var a: CriminalAsset = RunState.market.get_asset(_live.venue_asset_id)
	if a == null:
		return
	stock_label.text = "$%.2f" % a.current_price
	var ratio := a.current_price / maxf(a.base_price, 0.01) - 1.0
	stock_change.text = "%+.1f%%" % (ratio * 100.0)
	stock_change.add_theme_color_override("font_color", Palette.change(ratio))
	if absf(delta) > 0.001:
		stock_chart.refresh()
	var color := Palette.UP if direction > 0 else Palette.DOWN
	stock_label.modulate = color.lightened(0.3)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(stock_label, "modulate", Color.WHITE, 0.4)
