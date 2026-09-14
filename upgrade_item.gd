extends Resource
class_name UpgradeItem

## A passive upgrade from an Upgrade (Vault) chest. Applies a modifier to the
## player. Kept simple: a stat id + an amount, applied additively or as a mult.

enum ApplyMode { ADD, MULTIPLY }

@export var id: StringName = &""
@export var display_name: String = "Kevlar Lining"
@export var description: String = "+1 max health"
@export var rarity: Rarity.Tier = Rarity.Tier.STANDARD

## Which player stat this touches. Interpreted by the code that applies it.
## Examples: "max_health", "move_speed", "fire_rate", "damage", "dodge_cooldown".
@export var stat: StringName = &"max_health"
@export var mode: ApplyMode = ApplyMode.ADD
@export var amount: float = 1.0

func rarity_name() -> String:
	return Rarity.name_of(rarity)

func rarity_color() -> Color:
	return Rarity.color_of(rarity)

## Apply this upgrade to a player node. Returns true if the stat existed.
func apply_to(player) -> bool:
	if not (stat in player):
		push_warning("UpgradeItem: player has no stat '" + str(stat) + "'")
		return false
	var current = player.get(stat)
	var new_val = current + amount if mode == ApplyMode.ADD else current * amount
	player.set(stat, new_val)
	# If we bumped max_health, also heal by the difference so it's felt.
	if stat == &"max_health" and mode == ApplyMode.ADD:
		player.health = min(player.health + int(amount), player.max_health)
		player.health_changed.emit(player.health, player.max_health)
	return true
