extends Node
## Autoload as "Noise". A tiny event bus for sound in the building.
##
## Anything that makes a sound calls Noise.emit_noise(position, radius, kind).
## Enemies connect to `heard` and decide for themselves whether they're close
## enough and whether their role lets them react. Keeping this central means
## the player doesn't need to know about enemies, and enemies don't need to
## scan the tree for gunshots.

## position: where the sound came from
## radius: how far it carries (world units)
## kind: &"gunshot", &"death", &"sprint"
signal heard(position: Vector2, radius: float, kind: StringName)

# Default carry distances. Gunshots are loud, footsteps barely register.
const RADIUS := {
	&"gunshot": 900.0,
	&"death": 700.0,
	&"sprint": 260.0,
}

func emit_noise(position: Vector2, kind: StringName = &"gunshot",
		radius: float = -1.0) -> void:
	var r: float = radius if radius > 0.0 else RADIUS.get(kind, 500.0)
	heard.emit(position, r, kind)

## Convenience wrappers so call sites read clearly.
func gunshot(position: Vector2) -> void:
	emit_noise(position, &"gunshot")

func death(position: Vector2) -> void:
	emit_noise(position, &"death")

func sprint(position: Vector2) -> void:
	emit_noise(position, &"sprint")
