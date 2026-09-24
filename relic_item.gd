extends Resource
class_name RelicItem
## A relic: a run-long passive with a hook into the heist (kills, hits,
## reloads, cleared rooms, the start and end of a job). Owned relics live in
## RunState.relics by id; effects are applied where they matter and through
## RelicHooks. Some stack (buying another copy adds its effect again).

@export var id: StringName = &""
@export var display_name := "Relic"
@export var description := ""
@export var rarity: Rarity.Tier = Rarity.Tier.RESTRICTED
@export var stacks := false
## Two-letter mark drawn on HUD tokens and cards.
@export var mark := "??"

func rarity_name() -> String:
	return Rarity.name_of(rarity) + " relic"

func rarity_color() -> Color:
	return Rarity.color_of(rarity)
