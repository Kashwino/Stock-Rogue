extends RefCounted
class_name Takedown
## The `melee` action (F, right mouse, pad B, touch MELEE):
##   STEALTH TAKEDOWN — from behind (within 45 px and 110° of his back) on an
##       unprovoked guard: a 0.45 s silent knife, you're untouchable during
##       it and it makes no noise. Not on Brutes, turrets, drones,
##       lieutenants or bosses. (A riot shield only guards the front.)
##   STAGGER EXECUTION — a guard hit into his last quarter of health staggers
##       for 1.2 s; melee on him is a 0.5 s point-blank shot with your gun:
##       loud unless suppressed, refunds 2 rounds, always an overkill.

const STEALTH := &"stealth"
const EXECUTION := &"execution"
const STEALTH_RANGE := 45.0
const BACK_CONE := deg_to_rad(55.0)       # half of the 110° cone behind him
const EXECUTION_RANGE := 70.0
const DURATION := {STEALTH: 0.45, EXECUTION: 0.5}
const STRIKE_AT := {STEALTH: 0.26, EXECUTION: 0.3}

## Can this guard be knifed from behind at all?
static func stealth_allowed(e: Enemy) -> bool:
	if e == null or e._dead or e is Boss or e.lieutenant:
		return false
	return not (e.kind in [Enemy.Kind.BRUTE, Enemy.Kind.TURRET, Enemy.Kind.DRONE])

## Is `from` behind `e` and close enough, with him none the wiser?
static func can_stealth(e: Enemy, from: Vector2) -> bool:
	if not stealth_allowed(e) or e._provoked or e.hunting:
		return false
	var off := from - e.global_position
	if off.length() > STEALTH_RANGE:
		return false
	var facing := Vector2.from_angle(e.sprite.global_rotation) if e.sprite else Vector2.RIGHT
	return absf(off.normalized().angle_to(-facing)) <= BACK_CONE

static func can_execute(e: Enemy, from: Vector2) -> bool:
	return e != null and not e._dead and e.is_staggered() and from.distance_to(e.global_position) <= EXECUTION_RANGE

## The best melee target near the player: [enemy, mode] or [].
static func find(player: Node2D) -> Array:
	if player == null or not player.is_inside_tree():
		return []
	var best: Array = []
	var best_d := INF
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e._dead:
			continue
		var d := player.global_position.distance_to(e.global_position)
		if d > EXECUTION_RANGE or d >= best_d:
			continue
		if can_execute(e, player.global_position):
			best = [e, EXECUTION]
			best_d = d
		elif can_stealth(e, player.global_position):
			best = [e, STEALTH]
			best_d = d
	return best

## Where the player ends up for the kill: right behind a stealth victim,
## a step in front of an execution.
static func strike_spot(e: Enemy, mode: StringName, from: Vector2) -> Vector2:
	if mode == STEALTH:
		var facing := Vector2.from_angle(e.sprite.global_rotation) if e.sprite else (e.global_position - from).normalized()
		return e.global_position - facing * 26.0
	var away := (from - e.global_position)
	return e.global_position + (away.normalized() if away.length() > 1.0 else Vector2.LEFT) * 34.0
