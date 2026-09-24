extends CanvasLayer
## The run map. Shows the current step of the route: the hideout before a job,
## the heist options, the collector's quota check, or the stage hand-off.
## UI is built in code under one full-rect Control root.

signal heist_chosen(node)
signal hideout_requested()
signal hideout_skipped()
signal quota_faced()
signal stage_advanced()
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
	art.completed = run_map.heists_done
	root.add_child(art)
	_label("THE BOARD / " + run_map.stage_name().to_upper(), Vector2(48, 24), 30, VisualTheme.GOLD)
	_label("QUOTA  ⦿ %d  +  INDEX %d   ·   NOW ⦿ %d  /  INDEX %d" % [int(run_map.current_quota()), int(run_map.current_stock_quota()), RunEconomy.gold, int(RunState.empire_index())], Vector2(48, 66), 20, VisualTheme.TEAL)
	if run_map.is_complete():
		_button("FINISH RUN", Vector2(475, 350), Vector2(330, 90), _emit_complete)
		return
	var step: RunMap.Step = run_map.current()
	match step.kind:
		RunMap.StepKind.SHOP:
			_show_shop(step)
		RunMap.StepKind.HEIST_CHOICE:
			_show_choice(step)
		RunMap.StepKind.QUOTA_GATE:
			_show_quota()
		RunMap.StepKind.ADVANCE:
			_show_advance()

func _show_shop(_step: RunMap.Step) -> void:
	var boss := run_map.next_heist_is_boss()
	_label("THE HIDEOUT IS OPEN" if not boss else "THE BIG ONE IS NEXT", Vector2(48, 200), 34, VisualTheme.WHITE)
	_label("Gear up and work the market before you pick the next job.", Vector2(48, 250), 22, VisualTheme.TEAL)
	var enter := _button("ENTER THE HIDEOUT", Vector2(48, 320), Vector2(420, 84), _emit_hideout)
	enter.set_meta("qa_label", "ENTER HIDEOUT")
	_button("STRAIGHT TO THE JOB", Vector2(500, 320), Vector2(420, 84), _emit_skip)

func _show_choice(step: RunMap.Step) -> void:
	var positions := [Vector2(240, 190), Vector2(760, 190), Vector2(240, 390), Vector2(760, 390)]
	if step.options.size() == 1:
		positions = [Vector2(470, 275)]
	for i in step.options.size():
		var node: MapNode = step.options[i]
		var title := String(node.venue_id).replace("_", " ").to_upper()
		if node.is_boss():
			title = String(node.boss_id).to_upper() + " / BOSS"
		var text := "%02d  /  %s\n%s\n%s" % [i + 1, title, node.modifier_name(), node.modifier_detail()]
		var button := _button(text, positions[i], Vector2(330, 164), _choose.bind(i))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		button.set_meta("qa_label", "HEIST OPTION %d" % (i + 1))
		button.name = "HeistOption%d" % (i + 1)

func _show_quota() -> void:
	_label("THE COLLECTOR WANTS A WORD", Vector2(48, 200), 34, VisualTheme.WHITE)
	_label("Show ⦿ %d on hand and an empire index of %d, or the Board cuts you off." % [int(run_map.current_quota()), int(run_map.current_stock_quota())], Vector2(48, 250), 22, VisualTheme.TEAL)
	_button("OPEN THE BOOKS", Vector2(48, 320), Vector2(420, 84), _emit_quota)

func _show_advance() -> void:
	_label("%s IS YOURS" % run_map.stage_name().to_upper(), Vector2(48, 200), 34, VisualTheme.WHITE)
	_button("MOVE UP", Vector2(48, 320), Vector2(420, 84), _emit_advance)

func _choose(index: int) -> void:
	var node := run_map.choose_option(index)
	if node:
		heist_chosen.emit(node)

func _emit_hideout() -> void:
	hideout_requested.emit()

func _emit_skip() -> void:
	hideout_skipped.emit()

func _emit_quota() -> void:
	quota_faced.emit()

func _emit_advance() -> void:
	stage_advanced.emit()

func _emit_complete() -> void:
	run_complete.emit()

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
