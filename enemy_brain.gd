extends RefCounted
class_name EnemyBrain
## Behaviour plug-in for the archetypes that need more than "keep your distance
## and shoot" (Enemy.brain, see EnemyBrains for the concrete ones). The guard
## keeps its senses, provoke gate, alert states and separation; a brain takes
## over movement and attacks. Hooks return true when they handled the frame.

var e: Enemy

## After the archetype is applied. The guard may not be in the tree yet.
func setup() -> void:
	pass

## Every awake physics frame, before the alert-state logic.
func tick(_delta: float) -> void:
	pass

## HUNTING. Return true when movement and attacks were handled here.
func hunt(_delta: float, _sees: bool, _to_player: Vector2, _dist: float) -> bool:
	return false

## IDLE / INVESTIGATING. Return true to override the default.
func calm(_delta: float) -> bool:
	return false

## The provoke gate just opened (room entered, shot heard, shot at, radioed in).
func on_provoked() -> void:
	pass

## Took damage (after shields and armour).
func on_hurt() -> void:
	pass

## True when a bullet travelling along `dir` is stopped (riot shields).
func deflects(_dir: Vector2) -> bool:
	return false

func on_death() -> void:
	pass

## Physics mask for this archetype's sight and steering (drones fly over props).
func solid_mask() -> int:
	return Layers.SOLID
