extends Node
class_name KillFeedback
## The heist's kill desk. Every death arrives here already classified
## (KillInfo). Player kills get the full treatment: hit-stop sized to the
## class, a camera punch toward the body, the red X on the crosshair, the
## kill-confirm flash (Corpse), and the MULTI chain with its banner. Kill
## sounds, gore and the combo listen to `killed`.

signal killed(info: KillInfo)

## Kills this close together (game time) — or from one shot or blast — chain.
const MULTI_WINDOW := 0.4
## Camera punch strength (px) per class.
const PUNCH := {
	KillInfo.STANDARD: 5.0, KillInfo.CRIT: 7.0, KillInfo.OVERKILL: 9.0,
	KillInfo.EXPLOSIVE: 12.0, KillInfo.BURN: 4.0, KillInfo.TAKEDOWN: 8.0,
}
const TRAUMA := {
	KillInfo.STANDARD: 0.2, KillInfo.CRIT: 0.24, KillInfo.OVERKILL: 0.32,
	KillInfo.EXPLOSIVE: 0.45, KillInfo.BURN: 0.15, KillInfo.TAKEDOWN: 0.3,
}

var host: HeistFloor
var chain := 0
var best_multi := 0
var by_class: Dictionary = {}
var _clock := 0.0
var _last_kill := -10.0
var _last_shot := 0

func _process(delta: float) -> void:
	_clock += delta

func on_kill(info: KillInfo) -> void:
	if info == null:
		return
	if info.by_player:
		var same_shot := info.shot != 0 and info.shot == _last_shot
		if same_shot or _clock - _last_kill <= MULTI_WINDOW:
			chain += 1
		else:
			chain = 1
		_last_kill = _clock
		_last_shot = info.shot
		info.multi = chain
		best_multi = maxi(best_multi, chain)
		by_class[info.kill_class] = int(by_class.get(info.kill_class, 0)) + 1
		_feedback(info)
	Audio.play_kill(info, host.floor_surface() if host else "concrete")
	killed.emit(info)

func _feedback(info: KillInfo) -> void:
	TimeController.hit_stop(info.hit_stop_seconds())
	if host == null:
		return
	host.fx.add_trauma(float(TRAUMA.get(info.kill_class, 0.2)))
	if is_instance_valid(host.player):
		host.fx.punch(info.position - host.player.global_position, float(PUNCH.get(info.kill_class, 5.0)))
	if host.crosshair:
		host.crosshair.kill()
	if chain >= 2 and host.hud and host.hud.get("multi_banner"):
		host.hud.multi_banner.show_count(chain)
