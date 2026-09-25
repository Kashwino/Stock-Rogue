extends Node
class_name RelicHooks
## The heist's relic switchboard. The floor emits these signals; the relics
## that react to events (rather than just changing a number) live here:
##   kill          Blood Ledger (a round back in the magazine)
##   hit_taken     (Golden Parachute is handled by the player before death)
##   reload        Hair Trigger (the next shot deals double)
##   room_cleared  Second Wind (the first cleared room heals 1)
##   heist_start   resets the per-job state
##   extract       Paper Trail (an A or better lifts every venue 2%)

signal kill(enemy: Node)
signal hit_taken(amount: int)
signal reload()
signal room_cleared(room: Node)
signal heist_start()
signal extract(result: Dictionary)

var floor_host: HeistFloor
var _second_wind_used := false

func _ready() -> void:
	kill.connect(_on_kill)
	reload.connect(_on_reload)
	room_cleared.connect(_on_room_cleared)
	heist_start.connect(_on_heist_start)
	extract.connect(_on_extract)

func _on_heist_start() -> void:
	_second_wind_used = false

func _on_kill(_enemy: Node) -> void:
	if RunState.has_relic(&"blood_ledger") and RunState.loadout:
		RunState.loadout.refund_round()

func _on_reload() -> void:
	if RunState.has_relic(&"hair_trigger") and floor_host and is_instance_valid(floor_host.player):
		floor_host.player.hair_trigger = true

func _on_room_cleared(_room: Node) -> void:
	if not RunState.has_relic(&"second_wind") or _second_wind_used or RunState.profile_value("no_healing", false):
		return
	var p: Player = floor_host.player if floor_host else null
	if p == null or not is_instance_valid(p) or p.is_dead():
		return
	_second_wind_used = true
	if p.health < p.max_health:
		p.health += 1
		p.health_changed.emit(p.health, p.max_health)
		floor_host.fx.chip(p.global_position, "SECOND WIND +1", Palette.UP)

func _on_extract(result: Dictionary) -> void:
	if not RunState.has_relic(&"paper_trail") or RunState.market == null:
		return
	if String(result.get("grade_name", "")) in ["S+", "S", "A"]:
		for a: CriminalAsset in RunState.market.assets:
			a.current_price *= 1.02
		result["paper_trail"] = true
