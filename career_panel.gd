extends PanelContainer
class_name CareerPanel
signal closed
var body: VBoxContainer
var message := ""

func _ready() -> void:
	custom_minimum_size = Vector2(980, 620)
	_rebuild.call_deferred()

func _rebuild() -> void:
	if body:
		remove_child(body)
		body.queue_free()
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var title := Label.new()
	title.text = "CRIMINAL NETWORK  /  %d INTEL" % Meta.intel
	title.add_theme_font_size_override("font_size", 30)
	body.add_child(title)
	var intro := Label.new()
	intro.text = "Escape to earn: 1 Intel / 2 kills (max 6), 1 / security device (max 4), +4 for the Auditor.\nUnlocks survive death. One starting perk applies to new runs."
	intro.add_theme_font_size_override("font_size", 20)
	body.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for id: StringName in Meta.CATALOG:
		var entry: Dictionary = Meta.CATALOG[id]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 86
		list.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = entry["name"] + "  /  " + str(entry["kind"]).to_upper() + "\n" + entry["detail"]
		label.add_theme_font_size_override("font_size", 20)
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(225, 74)
		var owned := id in Meta.unlocked_assets
		button.text = ("EQUIPPED" if Meta.starting_perk == id else "EQUIP " + entry["name"]) if owned and entry["kind"] == "perk" else ("UNLOCKED" if owned else "BUY " + entry["name"] + " · " + str(entry["cost"]))
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = owned and entry["kind"] == "weapon"
		button.pressed.connect(_choose.bind(id))
		row.add_child(button)
	var status := Label.new()
	status.text = message if message != "" else "Starting perk: " + (String(Meta.starting_perk).replace("_", " ") if Meta.starting_perk != &"" else "none")
	status.add_theme_font_size_override("font_size", 20)
	body.add_child(status)
	var back := Button.new()
	back.text = "BACK TO MENU"
	back.custom_minimum_size.y = 74
	back.pressed.connect(func(): closed.emit())
	body.add_child(back)

func _choose(id: StringName) -> void:
	if id in Meta.unlocked_assets:
		message = "Starting perk saved." if Meta.equip_starting_perk(&"" if Meta.starting_perk == id else id) else "Could not save on this device."
	else:
		message = Meta.purchase(id)
	# The pressed button must remain in the tree until touch dispatch completes.
	_rebuild.call_deferred()
