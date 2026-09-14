extends RefCounted
class_name Rarity

## The 5-rarity ladder shared by weapons and upgrades.
## Standard < Restricted < Classified < Covert < Top Secret.

enum Tier { STANDARD, RESTRICTED, CLASSIFIED, COVERT, TOP_SECRET }

const NAMES := {
	Tier.STANDARD:   "Standard",
	Tier.RESTRICTED: "Restricted",
	Tier.CLASSIFIED: "Classified",
	Tier.COVERT:     "Covert",
	Tier.TOP_SECRET: "Top Secret",
}

# Display colors for each rarity (tune to taste).
const COLORS := {
	Tier.STANDARD:   Color(0.75, 0.75, 0.78),   # grey
	Tier.RESTRICTED: Color(0.4, 0.8, 0.45),      # green
	Tier.CLASSIFIED: Color(0.35, 0.6, 0.95),     # blue
	Tier.COVERT:     Color(0.7, 0.45, 0.95),     # purple
	Tier.TOP_SECRET: Color(1.0, 0.65, 0.15),     # orange/gold
}

static func name_of(t: int) -> String:
	return NAMES.get(t, "?")

static func color_of(t: int) -> Color:
	return COLORS.get(t, Color.WHITE)
