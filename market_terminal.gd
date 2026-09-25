extends Node2D
class_name MarketTerminal
var used := false
var opened := false
var prompt: WorldPrompt
var ui: CanvasLayer
var _target: OptionButton
var _status: Label
var _trade_buttons: Array[Button] = []
var _ring: PulseRing

func _ready() -> void:
	add_to_group("market_terminal")
	var screen := PropArt.new()
	add_child(screen)
	_ring = PulseRing.new()
	_ring.color = Palette.NEON_CYAN
	_ring.radius = 46.0
	add_child(_ring)
	prompt = WorldPrompt.new()
	prompt.text = "MARKET TERMINAL\nUSE / E"
	prompt.color = Palette.NEON_CYAN
	prompt.position = Vector2(0, -62)
	add_child(prompt)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var near := player != null and global_position.distance_squared_to(player.global_position) < 110.0 * 110.0
	prompt.modulate = Color.WHITE if near else Color(0.6, 0.7, 0.75)
	prompt.visible = near and not opened
	if near and not used and Input.is_action_just_pressed("interact"):
		open_terminal()

func open_terminal() -> void:
	if opened or used or get_tree().paused:
		return
	opened = true
	Controls.release_all()
	ui = CanvasLayer.new()
	ui.layer = 100
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.04, 0.06, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(800, 0)
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)
	col.add_child(VisualTheme.label("LOBBY TERMINAL  ·  ONE MOVE PER HEIST", "KickerLabel", 20))
	col.add_child(VisualTheme.label("MARKET ACCESS", "TitleLabel", 48))
	_target = OptionButton.new()
	_target.custom_minimum_size.y = 64
	var scene := get_tree().current_scene
	var index := 0
	for asset: CriminalAsset in RunState.market.assets:
		_target.add_item("%s   %s   $%.2f" % [Venues.ticker(asset.id), Venues.display_name(asset.id), asset.current_price])
		_target.set_item_metadata(index, asset.id)
		if scene is HeistFloor and asset.id == scene.get("_venue"):
			_target.select(index)
		index += 1
	col.add_child(_target)
	_status = VisualTheme.label("", "MonoLabel", 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 40
	_status.text = "$%d ON HAND   ·   HEAT %.0f" % [RunEconomy.gold, scene.heat]
	col.add_child(_status)
	for key: String in MarketOps.OPERATIONS:
		var op: Dictionary = MarketOps.OPERATIONS[key]
		var button := Button.new()
		button.text = "%s   ·   $%d   ·   +%.0f HEAT\n%s" % [op["name"], op["cost"], op["heat"], op["detail"]]
		button.custom_minimum_size.y = 94
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(_trade.bind(key))
		col.add_child(button)
		_trade_buttons.append(button)
	var back := Button.new()
	back.text = "BACK TO HEIST"
	back.custom_minimum_size.y = 74
	back.pressed.connect(close_terminal)
	col.add_child(back)
	get_tree().paused = true
	VisualTheme.focus_first(col)

func _trade(operation: String) -> void:
	if used:
		return
	var result := MarketOps.execute(operation, _target.get_item_metadata(_target.selected))
	_status.text = result["message"]
	if result["ok"]:
		used = true
		var scene := get_tree().current_scene as HeistFloor
		scene.add_heat(float(result["heat"]), "Market manipulation")
		for button in _trade_buttons:
			button.disabled = true
		prompt.text = "TERMINAL LOCKED"
		_ring.active = false
		Audio.play("cash_register")

func close_terminal() -> void:
	if not opened:
		return
	opened = false
	Controls.release_all()
	ui.queue_free()
	_trade_buttons.clear()
	get_tree().paused = false

func _exit_tree() -> void:
	if opened:
		get_tree().paused = false
