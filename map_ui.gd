extends CanvasLayer
signal heist_chosen(node)
signal shop_opened()
signal shop_skipped()
signal quota_reached(quota: float)
signal run_advanced()
signal run_complete()
var run_map: RunMap
var root: Control

func _ready() -> void:
	for child in get_children():
		child.queue_free()

func bind_map(map: RunMap) -> void:
	run_map = map
	refresh()

func refresh() -> void:
	if root:
		root.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var art := RouteMapArt.new()
	art.completed = RunFlow.heists_completed
	root.add_child(art)
	_label("THE TEN SCORES / " + run_map.stage_name().to_upper(), Vector2(48, 24), 30, VisualTheme.GOLD)
	_label("3 TOWN  /  3 CITY  /  3 CAPITAL  /  1 FINAL BOSS", Vector2(48, 66), 20, VisualTheme.TEAL)
	_label("GOLD %d   |   %d / 10 CLEARED" % [RunEconomy.gold, RunFlow.heists_completed], Vector2(840, 35), 22, VisualTheme.WHITE)
	if run_map.is_complete():
		_button("FINISH RUN", Vector2(475, 350), Vector2(330, 90), func(): run_complete.emit())
		return
	var step: RunMap.Step = run_map.current()
	var positions := [Vector2(240, 190), Vector2(760, 190), Vector2(240, 390), Vector2(760, 390)]
	if step.options.size() == 1:
		positions = [Vector2(470, 275)]
	for i in step.options.size():
		var node: MapNode = step.options[i]
		var title := String(node.venue_id).replace("_", " ").to_upper()
		if run_map.current_stage == 3:
			title = "THE AUDITOR / FINAL BOSS"
		var text := "%02d  /  %s\n%s\n%s" % [i + 1, title, node.modifier_name(), node.modifier_detail()]
		var button := _button(text, positions[i], Vector2(330, 164), _choose.bind(i))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		button.set_meta("qa_label", "HEIST OPTION %d" % (i + 1))
		button.name = "HeistOption%d" % (i + 1)
	var status := "No market contact in this district. Choose a location."
	if step.market_available and not step.market_visited:
		status = "A market contact is nearby. Optional visit; your heist choices stay open."
		_button("VISIT NIGHT MARKET", Vector2(750, 612), Vector2(400, 74), func(): shop_opened.emit())
	elif step.market_visited:
		status = "Night market visited. Choose your next score."
	_label(status, Vector2(48, 568), 21, VisualTheme.TEAL)
	_button("PREPARATION LOBBY", Vector2(48, 612), Vector2(360, 74), _lobby)

func _lobby() -> void:
	RunFlow.lobby_resume = true
	RunFlow.save()
	RunFlow.queue_scene(RunFlow.LOBBY_SCENE)

func _choose(index: int) -> void:
	var node := run_map.choose_option(index)
	if node:
		hide()
		heist_chosen.emit(node)

func _label(text: String, at: Vector2, font: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_color", color)
	root.add_child(label)

func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.pressed.connect(action)
	root.add_child(button)
	return button
