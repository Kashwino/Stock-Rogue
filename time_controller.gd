extends Node
## Autoload "TimeController": the one owner of Engine.time_scale.
## Hit-stop, slow-mo, kill moments and verdict swells are REQUESTS — a scale,
## a real-time duration and a priority. The strongest live request wins (ties
## go to the slower scale); requests never multiply together, the scale
## always returns to 1.0 when they run out, and while the tree is paused the
## game runs at normal speed (menus must never crawl) and no request is taken.
##
##   TimeController.hit_stop(0.07)            # a kill landing
##   TimeController.slow_mo(0.8, 0.3)         # a boss falling
##   TimeController.request(0.2, 1.5, PRIORITY_MOMENT, &"verdict")
##   TimeController.clear()                   # scene change, extraction

const PRIORITY_SLOW := 10       # room-clear beats, boss falls
const PRIORITY_MOMENT := 20     # verdict swells, finishers
const PRIORITY_HITSTOP := 30    # a few frames of near-freeze
const HITSTOP_SCALE := 0.06

## Live requests: {tag, scale, priority, until (usec, real time)}
var _requests: Array = []
var _was_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000

## Ask for `scale` for `seconds` of real time. A request with the same tag
## replaces the old one (its deadline only ever extends).
func request(scale: float, seconds: float, priority: int = PRIORITY_SLOW, tag: StringName = &"") -> void:
	if seconds <= 0.0 or get_tree().paused:
		return
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	if tag != &"":
		for r: Dictionary in _requests:
			if r["tag"] == tag:
				r["scale"] = clampf(scale, 0.01, 1.0)
				r["priority"] = priority
				r["until"] = maxi(int(r["until"]), until)
				_apply()
				return
	_requests.append({"tag": tag, "scale": clampf(scale, 0.01, 1.0), "priority": priority, "until": until})
	_apply()

func hit_stop(seconds: float) -> void:
	if _low_effects():
		return
	request(HITSTOP_SCALE, seconds, PRIORITY_HITSTOP, &"hit_stop")

func slow_mo(seconds: float, scale: float, tag: StringName = &"slow_mo") -> void:
	if _low_effects():
		return
	request(scale, seconds, PRIORITY_SLOW, tag)

## Drop one tagged request (e.g. a verdict swell once the card opens).
func release(tag: StringName) -> void:
	for i in range(_requests.size() - 1, -1, -1):
		if _requests[i]["tag"] == tag:
			_requests.remove_at(i)
	_apply()

## Back to normal speed now: scene changes, extraction, tests.
func clear() -> void:
	_requests.clear()
	Engine.time_scale = 1.0

func is_slowed() -> bool:
	return current_scale() < 1.0

func has(tag: StringName) -> bool:
	for r: Dictionary in _requests:
		if r["tag"] == tag and int(r["until"]) > Time.get_ticks_usec():
			return true
	return false

## The scale the live requests ask for right now.
func current_scale() -> float:
	var now := Time.get_ticks_usec()
	var best := {}
	for r: Dictionary in _requests:
		if int(r["until"]) <= now:
			continue
		if best.is_empty() or int(r["priority"]) > int(best["priority"]) \
				or (int(r["priority"]) == int(best["priority"]) and float(r["scale"]) < float(best["scale"])):
			best = r
	return 1.0 if best.is_empty() else float(best["scale"])

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	var paused := get_tree().paused
	if paused:
		# Nothing runs while paused: drop requests, full speed for the menus.
		if not _requests.is_empty():
			_requests.clear()
		Engine.time_scale = 1.0
		_was_paused = true
		return
	_was_paused = false
	var now := Time.get_ticks_usec()
	for i in range(_requests.size() - 1, -1, -1):
		if int(_requests[i]["until"]) <= now:
			_requests.remove_at(i)
	Engine.time_scale = current_scale()

func _low_effects() -> bool:
	return bool(Settings.values.get("low_effects", false))

func _exit_tree() -> void:
	Engine.time_scale = 1.0
