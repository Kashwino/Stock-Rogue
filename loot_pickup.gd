extends Area2D
class_name LootPickup

## A valuable sitting on the floor — cash, jewellery, a briefcase. Walk over it
## to collect. HeistFloor scatters these through rooms at spawn, with value and
## quantity scaling to each room's rarity, so dangerous rooms are worth robbing.

signal collected(value: int)

@export var value: int = 20
@export var pickup_radius: float = 34.0

var _kind := 0                 # 0 cash, 1 jewels, 2 briefcase, 3 artwork
var _taken := false
var _bob_time := 0.0
var _visual: LootArt

# Value bands -> which valuable it looks like.
const KINDS := [
	{"max": 25, "color": Color(0.5, 0.85, 0.5), "label": "$"},        # cash
	{"max": 60, "color": Color(0.55, 0.85, 1.0), "label": "◆"},       # jewels
	{"max": 140, "color": Color(0.85, 0.7, 0.35), "label": "▮"},      # briefcase
	{"max": 99999, "color": Color(0.9, 0.5, 0.9), "label": "◈"},      # artwork
]

func _ready() -> void:
	# Player is layer 4; only the player should trip a pickup.
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = pickup_radius
	shape.shape = circle
	add_child(shape)

	_pick_kind()
	_build_visual()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _pick_kind() -> void:
	for i in KINDS.size():
		if value <= KINDS[i]["max"]:
			_kind = i
			return
	_kind = KINDS.size() - 1

func _build_visual() -> void:
	_visual = LootArt.new()
	_visual.kind = _kind
	_visual.material = StreetArt._unshaded()
	add_child(_visual)

func _process(delta: float) -> void:
	if Settings.values["low_effects"]:
		return
	# Gentle bob and a breathing glow so pickups catch the eye in the dark.
	_bob_time += delta
	if _visual:
		_visual.position.y = sin(_bob_time * 3.0) * 3.0
		_visual.glow = 0.75 + 0.25 * sin(_bob_time * 4.0)
		_visual.queue_redraw()


## Drawn valuables: cash, jewels, a briefcase, a painting. Each glows gold.
class LootArt extends Node2D:
	var kind := 0
	var glow := 1.0
	func _draw() -> void:
		for i in 4:
			draw_circle(Vector2.ZERO, 30.0 - i * 6.0, Palette.with_alpha(Palette.LOOT_GLOW, 0.05 * glow + i * 0.02))
		draw_circle(Vector2(3, 6), 14, Color(0, 0, 0, 0.3))
		match kind:
			0:
				for i in 3:
					var r := Rect2(Vector2(-14 + i * 2, -9 + i * 3), Vector2(26, 13))
					draw_rect(r, Color("5a9a5a"))
					draw_rect(r, Color("2a5a2a"), false, 1.0)
					draw_rect(Rect2(r.position + Vector2(10, 0), Vector2(5, 13)), Color("e8e0b0"))
			1:
				var gem := PackedVector2Array([Vector2(0, -13), Vector2(12, -3), Vector2(0, 13), Vector2(-12, -3)])
				draw_colored_polygon(gem, Color("7ad0ff"))
				draw_polyline(gem + PackedVector2Array([gem[0]]), Color("dff4ff"), 1.5, true)
				draw_line(Vector2(-12, -3), Vector2(12, -3), Color("dff4ff"), 1.0)
				draw_circle(Vector2(-4, -6), 2.5 * glow, Color.WHITE)
			2:
				draw_rect(Rect2(-16, -10, 32, 22), Color("6a4424"))
				draw_rect(Rect2(-16, -10, 32, 22), Color("2a1808"), false, 1.5)
				draw_rect(Rect2(-6, -15, 12, 6), Color("2a1808"), false, 2.0)
				draw_rect(Rect2(-3, -1, 6, 4), Palette.GOLD)
			_:
				draw_rect(Rect2(-16, -13, 32, 26), Palette.GOLD)
				draw_rect(Rect2(-12, -9, 24, 18), Color("2a4a6a"))
				draw_circle(Vector2(-3, 1), 5, Color("e0a040"))
				draw_rect(Rect2(-16, -13, 32, 26), Palette.GOLD_DIM, false, 1.5)

func _on_body_entered(body: Node) -> void:
	_try_collect(body)

func _on_area_entered(area: Node) -> void:
	_try_collect(area)

func _try_collect(who: Node) -> void:
	if _taken:
		return
	if not who.is_in_group("player"):
		return
	_taken = true
	collected.emit(value)
	_collect_anim()

func _collect_anim() -> void:
	# Pop toward the HUD-ish corner, fading, then free.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)
