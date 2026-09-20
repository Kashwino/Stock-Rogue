extends CanvasLayer
## In-game HUD: health, currency, and a live stock ticker.
## A CanvasLayer so it draws on top of the game and ignores the camera.
## Attach to the HUD root. Wire the label node paths via unique names (%).
##
## Call bind_hud(player, live_stock, loadout) once from the heist setup.

@onready var health_label: Label = %HealthLabel
@onready var currency_label: Label = %CurrencyLabel
@onready var stock_label: Label = %StockLabel
@onready var stock_name_label: Label = %StockNameLabel
@onready var weapon_label: Label = %WeaponLabel      # active weapon name
@onready var ammo_label: Label = %AmmoLabel          # "12 / 96" or "∞"
## Optional: a StockChart node named %StockChart in hud.tscn (top-right).
@onready var stock_chart = get_node_or_null("%StockChart")
## Optional: a TraderFeed node named %TraderFeed in hud.tscn (under the chart).
@onready var trader_feed = get_node_or_null("%TraderFeed")

var _flash_tween: Tween
var _loadout = null
var _gold_tween: Tween
var _display_gold := -1.0

func _ready() -> void:
	# Show current gold immediately, then listen for changes.
	if has_node("/root/RunEconomy"):
		var econ = get_node("/root/RunEconomy")
		_update_gold(econ.gold)
		econ.gold_changed.connect(_update_gold)
	_ensure_widget_scripts()

## The chart and feed are plain Control nodes in hud.tscn. If their scripts
## aren't attached, attach them here so the widgets work regardless of how the
## scene was set up — otherwise you get "Nonexistent function in base 'Control'".
func _ensure_widget_scripts() -> void:
	stock_chart = _with_script(stock_chart, "res://stock_chart.gd", "refresh")
	trader_feed = _with_script(trader_feed, "res://trader_feed.gd", "bind_stock")

func _with_script(node, path: String, probe: String):
	if node == null or node.has_method(probe):
		return node
	if not ResourceLoader.exists(path):
		push_warning("HUD: " + path + " missing — widget disabled.")
		return null
	node.set_script(load(path))
	# set_script does not re-run _ready(), so prime it manually.
	if node.has_method("_ready"):
		node._ready()
	return node

## Call from the heist setup: hooks health + stock + loadout signals.
## NOTE: named bind_hud, not bind — `bind` is a built-in Callable method and
## shadowing it invites "Nonexistent function 'bind'" errors.
func bind_hud(player, live_stock, loadout = null) -> void:
	if player:
		_update_health(player.health, player.max_health)
		player.health_changed.connect(_update_health)
	if live_stock:
		stock_name_label.text = String(live_stock.venue_asset_id).replace("_", " ").to_upper()
		live_stock.price_updated.connect(_update_stock)
		# Tell the chart which venue this heist is moving.
		if stock_chart:
			if stock_chart.has_method("refresh"):
				stock_chart.venue_id = live_stock.venue_asset_id
				stock_chart.refresh()
			else:
				push_error("HUD: %StockChart exists but stock_chart.gd is not "
					+ "attached to it. Select the node > Attach Script.")
		if trader_feed:
			if trader_feed.has_method("bind_stock"):
				trader_feed.bind_stock(live_stock)
			else:
				push_error("HUD: %TraderFeed exists but trader_feed.gd is not "
					+ "attached to it. Select the node > Attach Script.")
	if loadout:
		_loadout = loadout
		loadout.active_changed.connect(_update_weapon)
		loadout.ammo_changed.connect(_update_ammo)
		loadout.reload_started.connect(_on_reload_started)
		loadout.reload_finished.connect(_on_reload_finished)
		# Prime with the current active weapon + its ammo.
		var w = loadout.get_active()
		if w:
			weapon_label.text = w.display_name
			weapon_label.add_theme_color_override("font_color", w.rarity_color())
			_update_ammo_readout(loadout.active_ammo_readout())

func _on_reload_started(_duration: float) -> void:
	ammo_label.text = "RELOADING…"
	ammo_label.modulate = Color(1.0, 0.85, 0.3)

func _on_reload_finished() -> void:
	ammo_label.modulate = Color.WHITE
	if _loadout:
		_update_ammo_readout(_loadout.active_ammo_readout())

func _update_weapon(weapon, mag: int, reserve: int) -> void:
	if weapon == null:
		weapon_label.text = ""
		return
	weapon_label.text = weapon.display_name
	weapon_label.add_theme_color_override("font_color", weapon.rarity_color())
	# Also refresh ammo for the newly-active weapon.
	_update_ammo(mag, reserve)

func _update_ammo(mag: int, reserve: int) -> void:
	# reserve < 0 means bottomless (the mag itself is always a real, finite
	# number now). This used to check `mag < 0`, a leftover from before the
	# "infinite reserve, real mag" rework -- that's what was printing "6 / -1".
	if reserve < 0:
		ammo_label.text = str(mag) + " / \u221E"
	else:
		ammo_label.text = str(mag) + " / " + str(reserve)

func _update_ammo_readout(text: String) -> void:
	ammo_label.text = text

func _update_health(current: int, maxv: int) -> void:
	health_label.text = "HP  %d / %d" % [clampi(current, 0, maxv), maxv]
	var frame := get_node_or_null("Frame") as HUDFrame
	if frame:
		frame.health = current
		frame.max_health = maxv
		frame.queue_redraw()

func _update_gold(amount: int) -> void:
	if _gold_tween and _gold_tween.is_valid():
		_gold_tween.kill()
	if _display_gold < 0.0 or Settings.values["low_effects"]:
		_draw_gold(float(amount))
	else:
		_gold_tween = create_tween()
		_gold_tween.tween_method(_draw_gold, _display_gold, float(amount), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	currency_label.modulate = Color(1.0, 0.84, 0.0)   # gold color

func _draw_gold(value: float) -> void:
	_display_gold = value
	currency_label.text = "GOLD  " + str(roundi(value))

## Quick pop on the gold counter when a floor pickup is grabbed.
func flash_gold() -> void:
	if currency_label == null or Settings.values["low_effects"]:
		return
	currency_label.scale = Vector2(1.3, 1.3)
	currency_label.pivot_offset = currency_label.size * 0.5
	var t := create_tween()
	t.tween_property(currency_label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_stock(price: float, delta: float, direction: int) -> void:
	stock_label.text = "$%.0f" % price
	# A big jump (boss pump, grade payout) should hit the chart at once rather
	# than waiting for the next sample tick.
	if stock_chart and absf(delta) > 0.001:
		stock_chart.refresh()
	# Flash green on up, red on down, then fade back to white.
	var color := Color(0.3, 1.0, 0.4) if direction > 0 else Color(1.0, 0.35, 0.3)
	stock_label.modulate = color
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(stock_label, "modulate", Color.WHITE, 0.4)
