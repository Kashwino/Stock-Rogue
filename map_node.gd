extends RefCounted
class_name MapNode

## A single heist option on the run map. Mystery (?) nodes hide their true type
## until reached. Boss nodes carry the stage boss id and use a signature building.

enum Type { HEIST, SHOP, MYSTERY, QUOTA_GATE, BOSS, ADVANCE }

var type: Type = Type.HEIST
var revealed: bool = true            # false for ? nodes until reached
var hidden_type: Type = Type.HEIST   # what a MYSTERY resolves into when revealed
var completed: bool = false

# Heist-specific (ignored for non-heist nodes):
var stage: int = 0
var room_rarity: int = 0             # heist difficulty 0..4
var venue_id: StringName = &""       # which stock this heist moves
var is_valuable: bool = false        # flagged high-reward
var boss_id: StringName = &""        # landlord / auditor / ambassador / chairman
var modifier: StringName = &""
## CONTRACT: the venue hired you, success pumps it. HIT: the job is against
## the venue, success crashes it (scaled by grade; damage you take softens it).
var contract: StringName = &"contract"
const MODIFIERS := {
	&"heavy_police": ["HEAVY POLICE RESPONSE", "Loot x1.5. Police deploy at half the heat, twice as often."],
	&"lockdown": ["LOCKDOWN", "Fire exits sealed. Escape through the main door."],
	&"insider": ["INSIDER", "Full building layout revealed on your map."],
}

func modifier_name() -> String:
	return MODIFIERS[modifier][0] if MODIFIERS.has(modifier) else "STANDARD SECURITY"

func modifier_detail() -> String:
	return MODIFIERS[modifier][1] if MODIFIERS.has(modifier) else "Normal loot and police response."

func is_hit() -> bool:
	return contract == &"hit"

func contract_label() -> String:
	return "HIT" if is_hit() else "CONTRACT"

func contract_detail() -> String:
	var t := Venues.ticker(venue_id)
	if is_hit():
		return "Against %s: a clean job crashes it." % t
	var n: int = int(RunState.contract_counts.get(String(venue_id), 0))
	if n > 0:
		return "%s hired you again: pump x%.2f." % [t, pow(0.65, n)]
	return "%s hired you: a clean job pumps it." % t

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

func is_boss() -> bool:
	return display_type() == Type.BOSS

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
