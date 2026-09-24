extends Area2D
class_name WorldChest

## A physical chest in a room. Player walks into range, a prompt shows, pressing
## "interact" (E) opens the loot reveal UI with items rolled at the chest's tier.
## Chest kind (weapon/upgrade) is fixed per chest; tier comes from room rarity.

signal opened(chest: WorldChest)

enum Kind { WEAPON, UPGRADE }

@export var kind: Kind = Kind.WEAPON
## Chest tier for the roll (set from room rarity by whatever spawns this).
@export var tier: LootRoller.ChestTier = LootRoller.ChestTier.TRUNK
@export var reveal_count: int = 3

@onready var prompt = get_node_or_null("Prompt")   # optional "Press E" child
@onready var sprite: Node2D = $Sprite        # chest visual

## A fixed reward (a boss's unique weapon) instead of a random roll.
var fixed_items: Array = []

var _player_in_range: bool = false
var _used: bool = false
var _chest_ui = null                         # set by spawner, or found at open time
var _ring: PulseRing

func _ready() -> void:
	if sprite is Polygon2D:
		sprite.polygon = PackedVector2Array()
	for child in sprite.get_children():
		if child is CanvasItem:
			child.hide()
	var illustration := PropArt.new()
	illustration.kind = "chest"
	illustration.tone = VisualTheme.GOLD if kind == Kind.WEAPON else VisualTheme.TEAL
	sprite.add_child(illustration)
	_ring = PulseRing.new()
	_ring.color = illustration.tone
	_ring.radius = 52.0
	add_child(_ring)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.hide()

## Optionally hand the chest a ChestUI instance to use. If not set, it will try
## to find one in the scene under the group "chest_ui".
func set_chest_ui(ui) -> void:
	_chest_ui = ui

func _process(_delta: float) -> void:
	if _player_in_range and not _used and Input.is_action_just_pressed("interact"):
		_open()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _used:
		_player_in_range = true
		if prompt:
			prompt.show()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if prompt:
			prompt.hide()

func _open() -> void:
	var ui = _chest_ui if _chest_ui else _find_chest_ui()
	if ui == null:
		push_warning("WorldChest: no ChestUI found to open — is one in the 'chest_ui' group?")
		return

	_used = true
	Audio.play("chest_open", global_position)
	if _ring:
		_ring.active = false
	if prompt:
		prompt.hide()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Weapon chests exclude the starter pistol -- every player already has it.
	var pool: Array = ItemPool.rewardable_weapons() if kind == Kind.WEAPON else ItemPool.upgrades()
	var items := LootRoller.roll_items(pool, tier, reveal_count, rng) if fixed_items.is_empty() else fixed_items.duplicate()
	if items.is_empty():
		push_warning("WorldChest: loot roll returned nothing — pool size "
			+ str(pool.size()) + ". Falling back to the raw pool.")
		items = pool.slice(0, mini(reveal_count, pool.size()))

	ui.open_chest(items, LootRoller.tier_name(tier))
	opened.emit(self)

	# Dim/consume the chest visually.
	if sprite and sprite is CanvasItem:
		sprite.modulate = Color(0.5, 0.5, 0.5)

func _find_chest_ui():
	var nodes := get_tree().get_nodes_in_group("chest_ui")
	return nodes[0] if nodes.size() > 0 else null

## Map a room's rarity (0..6: Common..Boss) to a chest loot tier.
## Rarer rooms -> better chest tier.
static func tier_from_room_rarity(room_rarity: int) -> LootRoller.ChestTier:
	# RoomRarity: COMMON UNCOMMON RARE PUMPED ELITE CHEST BOSS
	match room_rarity:
		0: return LootRoller.ChestTier.JUNKPILE   # Common
		1: return LootRoller.ChestTier.TRUNK      # Uncommon
		2: return LootRoller.ChestTier.TRUCK      # Rare
		3: return LootRoller.ChestTier.TRUCK      # Pumped
		4: return LootRoller.ChestTier.STORAGE    # Elite
		5: return LootRoller.ChestTier.STORAGE    # Chest room itself
		6: return LootRoller.ChestTier.AIRDROP    # Boss
	return LootRoller.ChestTier.TRUNK
