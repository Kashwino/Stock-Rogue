extends VBoxContainer
class_name PositionsPanel
## The Fence's second counter: open a LONG or SHORT on any venue with a gold
## stake. Positions settle at the end of the next job (see Positions). The
## venue list puts the next job's leads first, marked CONTRACT or HIT, and the
## wire's latest rumor sits on top: that is the opening.

var _list: VBoxContainer
var _venue: OptionButton
var _long: Button
var _short: Button
var _stakes: Array = []
var _open: Button
var _status: Label
var _side := "short"
var _stake := 0
var _ids: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(430, 0)
	add_theme_constant_override("separation", 8)
	var title := VisualTheme.label("POSITIONS", "HeadingLabel", 24, Palette.GOLD)
	add_child(title)
	var how := VisualTheme.label("Stake gold on a venue. Settles at the end of your next job:\nstake × (1 + %.1f × move). Shorts win when it falls." % Positions.leverage(), "", 15, Palette.PAPER_DIM)
	add_child(how)
	var rumor := _latest_rumor()
	if rumor != "":
		var tip := VisualTheme.label(rumor, "", 15, Palette.GOLD_PALE)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(420, 0)
		add_child(tip)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	add_child(_list)
	add_child(VisualTheme.label("OPEN A POSITION", "KickerLabel", 15))
	_venue = OptionButton.new()
	_venue.custom_minimum_size = Vector2(420, 44)
	add_child(_venue)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 8)
	add_child(sides)
	_long = _toggle("LONG", sides)
	_long.pressed.connect(_pick_side.bind("long"))
	_short = _toggle("SHORT", sides)
	_short.pressed.connect(_pick_side.bind("short"))
	var stakes := HBoxContainer.new()
	stakes.add_theme_constant_override("separation", 8)
	add_child(stakes)
	var options := Positions.stake_options()
	for amount: int in options:
		var b := _toggle("$%d" % amount, stakes)
		b.pressed.connect(_pick_stake.bind(amount))
		_stakes.append([b, amount])
	_stake = options[1] if options.size() > 1 else options[0]
	_open = Button.new()
	_open.text = "OPEN POSITION"
	_open.theme_type_variation = "PrimaryButton"
	_open.custom_minimum_size = Vector2(420, 50)
	_open.pressed.connect(_on_open)
	add_child(_open)
	_status = VisualTheme.label("", "", 15, Palette.PAPER_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 0)
	add_child(_status)
	_fill_venues()
	refresh()

func _toggle(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(130, 44)
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	return b

func _latest_rumor() -> String:
	for story: Dictionary in RunState.news:
		if story.get("kind", "") == "rumor":
			return "ON THE WIRE: " + String(story.get("text", "")).trim_prefix("RUMOR: ")
	return ""

## Next job's leads first (tagged), then every other listed venue.
func _fill_venues() -> void:
	_venue.clear()
	_ids.clear()
	var leads: Dictionary = {}
	if RunState.run_map:
		for node in RunState.run_map.peek_next_heist_options():
			if node is MapNode and node.venue_id != &"":
				leads[node.venue_id] = "BOSS" if node.is_boss() else node.contract_label()
	var ordered: Array = leads.keys()
	if RunState.market:
		for a: CriminalAsset in RunState.market.assets:
			if a.id not in ordered:
				ordered.append(a.id)
	for id: StringName in ordered:
		var a: CriminalAsset = RunState.market.get_asset(id) if RunState.market else null
		if a == null:
			continue
		var ratio := a.current_price / maxf(a.base_price, 0.01) - 1.0
		var tag: String = ("  · NEXT JOB: " + leads[id]) if leads.has(id) else ""
		_venue.add_item("%s  %.2f  %+.0f%%%s" % [Venues.ticker(id), a.current_price, ratio * 100.0, tag])
		_ids.append(id)
	if not _ids.is_empty():
		_venue.select(0)

func _pick_side(side: String) -> void:
	_side = side
	refresh()

func _pick_stake(amount: int) -> void:
	_stake = amount
	refresh()

func refresh() -> void:
	_long.button_pressed = _side == "long"
	_short.button_pressed = _side == "short"
	for pair: Array in _stakes:
		pair[0].button_pressed = pair[1] == _stake
	for c in _list.get_children():
		c.queue_free()
	var quotes := Positions.quotes()
	if quotes.is_empty():
		_list.add_child(VisualTheme.label("No open positions.  (%d slots)" % Positions.slots(), "", 16, Palette.PAPER_DIM))
	for q: Dictionary in quotes:
		var l := VisualTheme.label(Positions.describe(q), "", 17, Palette.UP if int(q["profit"]) >= 0 else Palette.DOWN)
		l.add_theme_font_override("font", VisualTheme.font("mono"))
		_list.add_child(l)
	var full := not Positions.can_open()
	_open.disabled = full or _ids.is_empty()
	if full:
		_status.text = "All %d slots in use. They settle after your next job." % Positions.slots()

func _on_open() -> void:
	if _venue.selected < 0 or _venue.selected >= _ids.size():
		return
	var result := Positions.open(_ids[_venue.selected], _side, _stake)
	_status.text = result["message"]
	if result["ok"]:
		Audio.play_ui("cash_register")
		var host := get_tree().current_scene
		if host and host.has_method("_refresh_gold_label"):
			host._refresh_gold_label()
		RunFlow.save()
	else:
		Audio.play_ui("ui_deny")
	refresh()
