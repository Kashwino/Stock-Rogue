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
	var view := get_viewport().get_visible_rect().size
	var data := {"scene": scene.scene_file_path if scene else "", "paused": get_tree().paused,
		"settings": Settings.values, "fps_cap": Engine.max_fps, "controls": controls,
		"viewport": [view.x, view.y], "touch_visible": Controls._root.visible,
		"master_db": AudioServer.get_bus_volume_db(0),
		"left": [Controls.left_origin.x, Controls.left_origin.y],
		"right": [Controls.right_origin.x, Controls.right_origin.y],
		"move": [TouchInput.move.x, TouchInput.move.y], "firing": TouchInput.firing}
	if scene is HeistFloor and is_instance_valid(scene.player):
		data["position"] = [scene.player.global_position.x, scene.player.global_position.y]
		data["shots"] = scene.player.shots_fired
		data["elapsed"] = scene.active_elapsed
		data["heat"] = scene.heat
		data["active_enemies"] = scene.director.active_count
		data["all_enemies"] = scene.director.enemies.size()
	JavaScriptBridge.eval("window.stockRogueQA = " + JSON.stringify(data), true)
func _collect(node: Node, out: Array) -> void:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is HSlider):
		var rect: Rect2 = node.get_global_rect()
		out.append({"text": node.text if node is Button else node.name, "type": node.get_class(),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	for child in node.get_children():
		_collect(child, out)
