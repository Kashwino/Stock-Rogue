extends RefCounted
class_name Layers
## Physics layer bit values. Every collision layer/mask in the project is set in
## code from these constants — never trust a .tscn for layers.
##   bit 1 (1)   WALLS     room walls, sealed gaps, shutters (StaticBody2D)
##   bit 2 (2)   ENEMIES   guards, rivals, civilians (CharacterBody2D)
##   bit 3 (4)   PLAYER    the player / hideout walker, and flipped-boss
##                         allies in the finale (enemy rounds hit them,
##                         yours pass through)
##   bit 4 (8)   SECURITY  cameras + alarm panels (shootable StaticBody2D)
##   bit 5 (16)  PROPS     furniture/cover: blocks walking, bullets and sight,
##                         but flying drones pass over it
##   bit 6 (32)  FLYERS    drones (bullet-targetable, never block walkers)

const WALLS := 1
const ENEMIES := 2
const PLAYER := 4
const SECURITY := 8
const PROPS := 16
const FLYERS := 32

## Anything that stops a walker, a bullet or a line of sight.
const SOLID := WALLS | PROPS
