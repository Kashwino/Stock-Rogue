extends Node
## Opt-in read-only browser test telemetry. No commands or gameplay mutations.
var enabled := false
var clock := 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'", true) == true
	set_process(enabled)
func _process(delta: float) -> void:
	clock -= delta
	if clock > 0.0:
		return
	clock = 0.1
	var scene := get_tree().current_scene
	var controls: Array = []
	_collect(get_tree().root, controls)
	var view := get_window().size
	var transform := get_viewport().get_final_transform()
	var left := transform * Controls.left_origin
	var right := transform * Controls.right_origin
	var data := {"scene": scene.scene_file_path if scene else "", "paused": get_tree().paused,
		"settings": Settings.values, "fps_cap": Engine.max_fps, "controls": controls,
		"viewport": [view.x, view.y], "touch_visible": Controls._root.visible,
		"master_db": AudioServer.get_bus_volume_db(0),
		"left": [left.x, left.y],
		"right": [right.x, right.y],
		"move": [TouchInput.move.x, TouchInput.move.y], "firing": TouchInput.firing}
	if scene is HideoutRoom:
		data["position"] = [scene._walker.position.x, scene._walker.position.y]
	if RunState.run_map:
		data["route_stage"] = RunState.run_map.current_stage
		data["route_step"] = RunState.run_map.current_step
	data["transition"] = Transition.busy
	data["intel"] = Meta.clout
	data["clout"] = Meta.clout
	data["unlocks"] = Meta.unlocked_assets
	data["starting_perk"] = String(Meta.starting_perk)
	data["perks"] = RunState.perks
	data["profile"] = String(RunState.character_profile.id) if RunState.character_profile else ""
	data["health"] = RunState.health
	data["fps"] = Engine.get_frames_per_second()
	data["frame"] = Engine.get_process_frames()
	if scene is HeistFloor and is_instance_valid(scene.player):
		data["position"] = [scene.player.global_position.x, scene.player.global_position.y]
		data["shots"] = scene.player.shots_fired
		data["elapsed"] = scene.active_elapsed
		data["heat"] = scene.heat
		data["entrance"] = [scene.generator.entrance["inside_pos"].x, scene.generator.entrance["inside_pos"].y]
		data["entered"] = scene.car.armed
		data["active_enemies"] = scene.director.active_count
		data["all_enemies"] = scene.director.enemies.size()
		data["modifier"] = String(scene.modifier)
		data["modifiers"] = scene.modifiers.map(func(m): return String(m))
		data["objective"] = String(scene.objective)
		data["security_count"] = get_tree().get_nodes_in_group("security").size()
		data["map_visible"] = scene.tactical_map.visible
		data["map_revealed"] = scene.tactical_map.full_reveal
		data["short"] = ShortBook.quote()
		data["terminal_position"] = [scene.generator.start_room.position.x + 430, scene.generator.start_room.position.y + 270]
	JavaScriptBridge.eval("window.stockRogueQA = " + JSON.stringify(data), true)
func _collect(node: Node, out: Array) -> void:
	if node is TouchScreenButton and node.is_visible_in_tree():
		var rect: Rect2 = get_viewport().get_final_transform() * node.global_transform * Rect2(-46, -46, 92, 92)
		var labels := {"interact": "USE", "swap_weapon": "SWAP", "reload": "RELOAD", "dodge": "DODGE"}
		out.append({"text": labels.get(String(node.action), String(node.action)), "type": "TouchScreenButton", "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is HSlider or node.has_meta("qa_label")):
		var rect: Rect2 = get_viewport().get_final_transform() * node.get_global_rect()
		out.append({"text": node.get_meta("qa_label", node.text if node is Button else node.name), "type": node.get_class(),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	for child in node.get_children():
		_collect(child, out)
