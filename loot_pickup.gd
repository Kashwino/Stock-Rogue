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
var _visual: Node2D

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
	collision_mask = 4
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
	_visual = Node2D.new()
	add_child(_visual)
	var illustration := PropArt.new()
	illustration.kind = "loot"
	_visual.add_child(illustration)

func _process(delta: float) -> void:
	if Settings.values["low_effects"]:
		return
	# Gentle bob + spin so pickups catch the eye.
	_bob_time += delta
	if _visual:
		_visual.position.y = sin(_bob_time * 3.0) * 3.0
		_visual.scale.x = cos(_bob_time * 2.0) * 0.25 + 0.9

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
