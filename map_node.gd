extends RefCounted
class_name MapNode

## A single node on the run map. Nodes stack vertically within a stage and the
## player advances upward. Mystery (?) nodes hide their true type until reached.

enum Type { HEIST, SHOP, MYSTERY, QUOTA_GATE, BOSS, ADVANCE }

var type: Type = Type.HEIST
var revealed: bool = true            # false for ? nodes until reached
var hidden_type: Type = Type.HEIST   # what a MYSTERY resolves into when revealed
var completed: bool = false

# Heist-specific (ignored for non-heist nodes):
var room_rarity: int = 0             # maps to Room.RoomRarity
var venue_id: StringName = &""       # which stock this heist moves
var is_valuable: bool = false        # flagged high-reward (may be a disguised boss)
var modifier: StringName = &""
const MODIFIERS := {
	&"heavy_police": ["HEAVY POLICE RESPONSE", "2x loot. Police deploy at half the heat, twice as often."],
	&"lockdown": ["LOCKDOWN", "Fire exits sealed. Escape through the main door."],
	&"insider": ["INSIDER", "Full building layout revealed on your map."],
}

func modifier_name() -> String:
	return MODIFIERS[modifier][0] if MODIFIERS.has(modifier) else "STANDARD SECURITY"

func modifier_detail() -> String:
	return MODIFIERS[modifier][1] if MODIFIERS.has(modifier) else "Normal loot and police response."

func _init(t: Type = Type.HEIST) -> void:
	type = t

## The type the player currently perceives (MYSTERY stays hidden until revealed).
func display_type() -> Type:
	if type == Type.MYSTERY and not revealed:
		return Type.MYSTERY
	if type == Type.MYSTERY and revealed:
		return hidden_type
	return type

## Reveal a mystery node, turning it into its hidden type.
func reveal() -> void:
	revealed = true

func label() -> String:
	match display_type():
		Type.HEIST:      return "HEIST" + ("  ★" if is_valuable else "")
		Type.SHOP:       return "SHOP"
		Type.MYSTERY:    return "?"
		Type.QUOTA_GATE: return "QUOTA"
		Type.BOSS:       return "BOSS"
		Type.ADVANCE:    return "ADVANCE"
	return "?"

## True if entering this node is actual combat (heist or boss).
func is_combat() -> bool:
	var d := display_type()
	return d == Type.HEIST or d == Type.BOSS
