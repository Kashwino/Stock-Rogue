extends PanelContainer
class_name CareerPanel
## The Connections board: spend Clout (earned at the end of every run) on
## weapons for the reward pool, one starting perk and a coat. The right
## column tracks the feats that hire the other specialists.
## Reachable from the home screen and the case files.

signal closed
var category := ""
var body: VBoxContainer
var message := ""

func _ready() -> void:
	custom_minimum_size = Vector2(1120, 620)
	_rebuild.call_deferred()

func _rebuild() -> void:
	if body:
		remove_child(body)
		body.queue_free()
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	var title := VisualTheme.label("CONNECTIONS", "HeadingLabel", 32, Palette.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var bank := VisualTheme.label("%d CLOUT" % Meta.clout, "", 28, Palette.GOLD_PALE)
	bank.add_theme_font_override("font", VisualTheme.font("mono"))
	head.add_child(bank)
	var intro := VisualTheme.label("Clout comes at the end of every run: stages cleared, stage bosses, the index you reached, +8 for retiring. Unlocks survive death.", "", 17, Palette.PAPER_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(1060, 0)
	body.add_child(intro)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for kind in ["weapon", "perk", "coat"]:
		var kicker := VisualTheme.label({"weapon": "WEAPONS FOR THE REWARD POOL", "perk": "STARTING PERK (EQUIP ONE)", "coat": "COATS"}[kind], "KickerLabel", 16)
		list.add_child(kicker)
		for id: StringName in Meta.CATALOG:
			var entry: Dictionary = Meta.CATALOG[id]
			if entry["kind"] != kind:
				continue
			list.add_child(_row(id, entry))
	cols.add_child(_crew_column())
	var status := VisualTheme.label(message if message != "" else _equipped_line(), "", 17, Palette.PAPER)
	body.add_child(status)
	var back := Button.new()
	back.text = "BACK TO MENU"
	back.custom_minimum_size.y = 60
	back.pressed.connect(_on_back)
	body.add_child(back)

func _equipped_line() -> String:
	var perk := String(Meta.CATALOG[Meta.starting_perk]["name"]) if Meta.CATALOG.has(Meta.starting_perk) else "none"
	var coat := String(Meta.CATALOG[Meta.coat]["name"]) if Meta.CATALOG.has(Meta.coat) else "your own"
	return "Starting perk: %s   ·   Coat: %s" % [perk, coat]

func _row(id: StringName, entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 64
	row.add_theme_constant_override("separation", 12)
	if entry["kind"] == "coat":
		var swatch := ColorRect.new()
		swatch.color = Color(entry["color"])
		swatch.custom_minimum_size = Vector2(26, 26)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
	var label := VisualTheme.label(String(entry["name"]) + "\n" + String(entry["detail"]), "", 17, Palette.PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(250, 58)
	button.add_theme_font_size_override("font_size", 17)
	var owned := id in Meta.unlocked_assets
	match entry["kind"]:
		"perk":
			button.text = ("EQUIPPED" if Meta.starting_perk == id else "EQUIP " + entry["name"]) if owned else "BUY %s · %d" % [entry["name"], entry["cost"]]
		"coat":
			button.text = ("WEARING" if Meta.coat == id else "WEAR " + entry["name"]) if owned else "BUY %s · %d" % [entry["name"], entry["cost"]]
		_:
			button.text = "UNLOCKED" if owned else "BUY %s · %d" % [entry["name"], entry["cost"]]
			button.disabled = owned
	button.pressed.connect(_choose.bind(id))
	row.add_child(button)
	return row

## The crew: who is hired and how close the rest are.
func _crew_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 6)
	col.add_child(VisualTheme.label("THE CREW", "KickerLabel", 16))
	for c: Dictionary in CharacterSelect.CREW:
		var id: StringName = c["id"]
		var hired := Meta.is_specialist_unlocked(id)
		var line := String(c["name"]) + ("  —  HIRED" if hired else "")
		var l := VisualTheme.label(line, "", 18, Palette.GOLD if hired else Palette.PAPER)
		col.add_child(l)
		if not hired and Meta.UNLOCKS.has(id):
			var how := VisualTheme.label("%s   (%s)" % [Meta.UNLOCKS[id][2], Meta.unlock_progress(id)], "", 15, Palette.PAPER_DIM)
			how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			how.custom_minimum_size = Vector2(290, 0)
			col.add_child(how)
	return col

func _choose(id: StringName) -> void:
	var kind: String = Meta.CATALOG[id]["kind"] if Meta.CATALOG.has(id) else ""
	if id in Meta.unlocked_assets:
		if kind == "perk":
			message = "Starting perk saved." if Meta.equip_starting_perk(&"" if Meta.starting_perk == id else id) else "Could not save on this device."
		elif kind == "coat":
			message = "Coat saved." if Meta.equip_coat(&"" if Meta.coat == id else id) else "Could not save on this device."
	else:
		message = Meta.purchase(id)
	# The pressed button must remain in the tree until touch dispatch completes.
	_rebuild.call_deferred()

func _on_back() -> void:
	closed.emit()
