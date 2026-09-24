extends Node
## Dev tool: renders a scene (optionally after a scripted setup) and saves PNGs.
## Run under a real/virtual display (not --headless):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- shot=home out=/tmp/home.png
## Presets live in _setup(); frames= controls how long to wait before capturing.

var args := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for raw: String in OS.get_cmdline_user_args():
		var parts := raw.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	_run.call_deferred()

func _run() -> void:
	var shot: String = args.get("shot", "home")
	var out: String = args.get("out", "/tmp/shot.png")
	var frames := int(args.get("frames", "90"))
	var scene := await _setup(shot)
	for i in frames:
		await get_tree().process_frame
	var extra: String = args.get("then", "")
	if extra != "" and is_instance_valid(scene) and scene.has_method(extra):
		scene.call(extra)
		for i in 30:
			await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(out)
	print("SHOT SAVED ", out, " ", image.get_size())
	get_tree().quit(0)

func _setup(shot: String) -> Node:
	var path := ""
	match shot:
		"home": path = "res://home_screen.tscn"
		"select": path = "res://character_select.tscn"
		"map", "hideout", "heist":
			RunSave.slot = RunSave.SLOT_COUNT
			RunFlow.run_seed = int(args.get("seed", "4817"))
			RunState.start_run(load("res://main_character.tres"), RunFlow.run_seed)
			if args.has("stage"):
				RunState.run_map.current_stage = int(args["stage"])
			path = {"map": "res://map_ui_screen.tscn", "hideout": "res://hideout_room.tscn", "heist": "res://heist_floor.tscn"}[shot]
			if shot == "heist":
				var step = RunState.run_map.current()
				RunFlow.pending_heist = RunState.run_map.first_heist_option() if RunState.run_map.has_method("first_heist_option") else MapNode.new()
		_:
			path = shot
	var packed: PackedScene = load(path)
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	return scene
