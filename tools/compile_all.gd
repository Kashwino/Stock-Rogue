extends Node
## Loads (compiles) every script under res:// and reports failures. Runs as a
## scene so autoload names resolve:
##   godot --headless --path . res://tools/compile_all.tscn
func _ready() -> void:
	var failures := 0
	var files: Array = []
	_walk("res://", files)
	for path: String in files:
		var res = load(path)
		if res == null or (res is GDScript and not res.can_instantiate()):
			failures += 1
			print("COMPILE FAIL ", path)
	print("COMPILED %d scripts, %d failures" % [files.size(), failures])
	get_tree().quit(1 if failures > 0 else 0)

func _walk(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		if not d.begins_with(".") and d != "node_modules" and d != "build":
			_walk(dir_path.path_join(d), out)
