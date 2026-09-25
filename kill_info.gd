extends RefCounted
class_name KillInfo
## How a death happened, classified the moment it happens. Hit-stop, camera
## punch, death motion, kill sounds, gore and the combo all read this.
##
##   STANDARD   an ordinary kill
##   CRIT       Marksman crits, unprovoked victims, Hair Trigger shots
##   OVERKILL   damage beyond the remaining health >= 2, point-blank
##              shotgun blasts, the Hand Cannon
##   EXPLOSIVE  grenades, Volatile elites, explosive props
##   BURN       the Incendiary mod
##   TAKEDOWN   stealth takedowns and stagger executions (Phase 4)
## MULTI is a count on top: 2+ kills within 0.4 s or from one shot/blast.

const STANDARD := &"standard"
const CRIT := &"crit"
const OVERKILL := &"overkill"
const EXPLOSIVE := &"explosive"
const BURN := &"burn"
const TAKEDOWN := &"takedown"

## Hit-stop per class (seconds of near-freeze).
const HIT_STOP := {
	STANDARD: 0.05, CRIT: 0.07, OVERKILL: 0.09, EXPLOSIVE: 0.12, BURN: 0.05, TAKEDOWN: 0.12,
}
## Point-blank range for shotgun overkills (px from the muzzle).
const POINT_BLANK := 90.0

var kill_class: StringName = STANDARD
var crit := false
var overkill := false
var multi := 1                    # kills in this chain (2+ = MULTI)
var by_player := false
var source: StringName = &""      # bullet / blast / burn / takedown / execution / other
var weapon_id: StringName = &""
var dir := Vector2.ZERO           # travel direction of whatever killed him
var force := 0.0                  # how hard the killing blow pushed
var excess := 0                   # damage beyond the remaining health
var shot := 0                     # shot / blast id (one trigger pull, one explosion)
var position := Vector2.ZERO
var victim: Node = null           # freed at end of frame; read it right away
var victim_kind := -1
var unprovoked := false
var corpse: Node2D = null
var prop := false                 # killed by an explosive prop (Phase 5)
var stealth := false              # silent stealth takedown (Phase 4)
var last_round := false           # the killing round was the last in the mag

static var _shot_counter := 0

## A fresh id for one trigger pull or one explosion.
static func next_shot_id() -> int:
	_shot_counter += 1
	return _shot_counter

## Build the record for a death from the victim's last hit.
static func classify(victim_node: Node, hit: Dictionary, over: int) -> KillInfo:
	var k := KillInfo.new()
	k.victim = victim_node
	if victim_node is Node2D:
		k.position = (victim_node as Node2D).global_position
	if victim_node != null and "kind" in victim_node:
		k.victim_kind = int(victim_node.kind)
	k.source = StringName(hit.get("source", &"other"))
	k.by_player = bool(hit.get("by_player", false))
	k.weapon_id = StringName(hit.get("weapon", &""))
	k.dir = hit.get("dir", Vector2.ZERO)
	k.force = float(hit.get("force", 0.0))
	k.shot = int(hit.get("shot", 0))
	k.unprovoked = bool(hit.get("unprovoked", false))
	k.prop = bool(hit.get("prop", false))
	k.stealth = bool(hit.get("stealth", false))
	k.last_round = bool(hit.get("last_round", false))
	k.excess = maxi(over, 0)
	var pellets := int(hit.get("pellets", 1))
	var point_blank := bool(hit.get("point_blank", false))
	k.overkill = k.excess >= 2 or (point_blank and pellets > 1) or k.weapon_id == &"handcannon" \
			or k.source == &"execution"
	k.crit = bool(hit.get("crit", false)) or (k.unprovoked and k.by_player)
	match k.source:
		&"takedown", &"execution":
			k.kill_class = TAKEDOWN
		&"blast":
			k.kill_class = EXPLOSIVE
		&"burn":
			k.kill_class = BURN
		_:
			if k.overkill:
				k.kill_class = OVERKILL
			elif k.crit:
				k.kill_class = CRIT
			else:
				k.kill_class = STANDARD
	return k

func hit_stop_seconds() -> float:
	return float(HIT_STOP.get(kill_class, 0.05))

## Gibs and bone crunches: a violent death.
func is_violent() -> bool:
	return kill_class in [OVERKILL, EXPLOSIVE] or overkill

func label() -> String:
	return String(kill_class).to_upper()
