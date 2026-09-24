extends CanvasLayer
class_name OnboardingHints
## One-time contextual hints for a fresh save's first heists: each one fires
## once, when its moment comes, and is remembered in Meta.hints_seen. A slim
## card slides in under the heat bar for a few seconds; nothing pauses. The
## key names follow the player's hands (keyboard, controller or touch).

const ORDER := ["move", "provoke", "shoot", "reload", "loot", "heat", "extract", "fire_exit"]
const HOLD := 7.0

var host: Node
var _root: Control
var _card: Control
var _queue: Array = []
var _showing := ""
var _clock := 0.0
var _poll := 0.0
var _elapsed := 0.0

## Button names per device for an input action.
static func prompt(action: String, device: String) -> String:
	var table := {
		"keys": {"fire": "LEFT CLICK", "reload": "R", "swap_weapon": "Q", "interact": "E", "dodge": "SPACE", "pause": "ESC", "tactical_map": "TAB"},
		"pad": {"fire": "RT", "reload": "X", "swap_weapon": "Y", "interact": "A", "dodge": "LB", "pause": "START", "tactical_map": "VIEW"},
		"touch": {"fire": "the right thumb", "reload": "RELOAD", "swap_weapon": "SWAP", "interact": "USE", "dodge": "DODGE", "pause": "PAUSE", "tactical_map": "MAP"},
	}
	return String(table.get(device, table["keys"]).get(action, action.to_upper()))

## [title, body] for a hint on a device.
static func text(id: String, device: String) -> Array:
	var p := func(a: String) -> String: return prompt(a, device)
	match id:
		"move":
			var how := "WASD moves, the mouse aims."
			if device == "pad":
				how = "Left stick moves, right stick aims."
			elif device == "touch":
				how = "Left thumb moves, right thumb aims and fires."
			return ["MOVE", "%s %s rolls through trouble." % [how, p.call("dodge")]]
		"provoke":
			return ["GUARDS WAIT", "Guards hold fire until provoked: walk into their room, make noise or shoot, and they come for you."]
		"shoot":
			if device == "touch":
				return ["SHOOT", "Hold the right thumb to fire. Every shot is noise, and noise wakes the building."]
			return ["SHOOT", "%s fires. Every shot is noise, and noise wakes the building." % p.call("fire")]
		"reload":
			return ["RELOAD", "%s reloads. The Sidearm reloads itself at empty; bigger guns do not." % p.call("reload")]
		"loot":
			return ["LOOT", "Walk over valuables to bag them. The LOOT multiplier pays out at extraction."]
		"heat":
			return ["HEAT", "Cameras, alarms and radio calls raise HEAT. Past the red mark, vans drop reinforcements."]
		"extract":
			return ["GET OUT", "Back at the getaway car, hold still for four seconds to extract with the bag."]
		"fire_exit":
			return ["FIRE EXITS", "Green fire exits are a quiet way out while HEAT is under the EXITS mark: hold still at one."]
	return ["", ""]

func _ready() -> void:
	layer = 60
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

## Whether any hint is still unseen (the heist skips this node otherwise).
static func pending() -> bool:
	for id: String in ORDER:
		if id not in Meta.hints_seen:
			return true
	return false

func _process(delta: float) -> void:
	_elapsed += delta
	if _showing != "":
		_clock -= delta
		if _clock <= 0.0:
			_hide_card()
	elif not _queue.is_empty():
		_show(_queue.pop_front())
	_poll -= delta
	if _poll > 0.0 or host == null or not is_instance_valid(host):
		return
	_poll = 0.3
	for id: String in ORDER:
		if id not in Meta.hints_seen and id not in _queue and id != _showing and _due(id):
			_queue.append(id)

## Each hint's moment.
func _due(id: String) -> bool:
	var player: Node2D = host.get("player")
	if player == null or not is_instance_valid(player):
		return false
	match id:
		"move":
			return _elapsed > 1.0
		"provoke":
			return host.car != null and host.car.armed
		"shoot":
			for e: Node in get_tree().get_nodes_in_group("enemies"):
				if e.get("hunting") and (e as Node2D).global_position.distance_to(player.global_position) < 520.0:
					return true
			return false
		"reload":
			var loadout = player.get("loadout")
			if loadout == null:
				return false
			var w: WeaponItem = loadout.get_active()
			var ammo: Dictionary = loadout._active_ammo()
			return w != null and w.uses_ammo and int(ammo.get("mag", -1)) >= 0 and int(ammo["mag"]) <= maxi(1, int(w.eff_mag() * 0.34))
		"loot":
			for l: Node in get_tree().get_nodes_in_group("loot_pickups"):
				if (l as Node2D).global_position.distance_to(player.global_position) < 240.0:
					return true
			return false
		"heat":
			return float(host.heat) >= 3.0
		"extract":
			return int(host.loot_banked) > 0
		"fire_exit":
			if int(host.loot_banked) <= 0 or float(host.heat) >= host.fire_exit_limit():
				return false
			for g: Dictionary in host.generator.exits:
				if g.get("open", false) and player.global_position.distance_to(g["inside_pos"]) < 420.0:
					return true
			return false
	return false

func _show(id: String) -> void:
	if not Meta.take_hint(id):
		return
	_showing = id
	_clock = HOLD
	var words := text(id, TouchInput.device())
	_card = Card.new()
	_card.title = words[0]
	_card.body = words[1]
	_card.position = Vector2(360, 88)
	var text_h := VisualTheme.font("body").get_multiline_string_size(words[1], HORIZONTAL_ALIGNMENT_LEFT, 528, 17).y
	_card.size = Vector2(560, 44 + text_h)
	_card.modulate.a = 0.0
	_root.add_child(_card)
	var tw := _card.create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_card, "position:y", 96.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_ui("paper")

func _hide_card() -> void:
	_showing = ""
	if _card and is_instance_valid(_card):
		var old := _card
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 0.3)
		tw.tween_callback(old.queue_free)
	_card = null


## A slim manila strip: kicker title, one sentence.
class Card extends Control:
	var title := ""
	var body := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The HUD's own font/size pairs: their glyphs are already rendered, so
		# a tip never stalls a frame on a slow (software-GL) phone.
		var kicker := VisualTheme.label("TIP  ·  " + title, "KickerLabel", 16, Palette.STAMP_RED)
		kicker.position = Vector2(16, 8)
		add_child(kicker)
		var line := VisualTheme.label(body, "", 17, Palette.INK)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.position = Vector2(16, 30)
		add_child(line)
		line.set_deferred("size", Vector2(size.x - 32, 0))

	func _draw() -> void:
		draw_rect(Rect2(Vector2(4, 5), size), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2.ZERO, size), Palette.MANILA)
		draw_rect(Rect2(Vector2.ZERO, Vector2(6, size.y)), Palette.STAMP_RED)
		draw_rect(Rect2(Vector2.ZERO, size), Palette.MANILA_DARK, false, 1.5)
