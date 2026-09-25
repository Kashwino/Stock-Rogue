extends RefCounted
class_name Palette
## The single source of truth for colour. Noir-thriller: near-black ink, warm
## paper, gold as the signature accent; neon only on signage and effects.

# Core UI
const BG := Color("0b0b0f")
const PANEL := Color("1a1a21")
const PANEL_HI := Color("24242d")
const EDGE := Color("34343f")
const GOLD := Color("e8b842")
const GOLD_DIM := Color("8c7333")
const GOLD_PALE := Color("f3d98c")
const DANGER := Color("c73833")
const PAPER := Color("ece6d6")
const PAPER_DIM := Color("a9a397")
const MUTED := Color("6f6c75")
const INK := Color("121015")

# Market
const UP := Color("5fd37a")
const DOWN := Color("e0544c")

# Signage / effects
const NEON_CYAN := Color("37e3ff")
const NEON_MAGENTA := Color("ff3fb4")
const NEON_GREEN := Color("3dff8a")
const SODIUM := Color("ffab4a")
const POLICE_RED := Color("ff3030")
const POLICE_BLUE := Color("2f6bff")
const TEAL := Color("5ec4b8")

# Case-file props
const MANILA := Color("d9bf85")
const MANILA_DARK := Color("a88c52")
const CORK := Color("5a4128")
const STRING_RED := Color("b3262a")
const STAMP_RED := Color("c2302b")
const STAMP_GREEN := Color("3f9a54")

# Combat readability
const PLAYER_BULLET := Color("fff2c2")
const ENEMY_BULLET := Color("ff6a2a")
const LOOT_GLOW := Color("ffd76a")

# The Noir Props HUD (Brief 3): paper, ink, pencil, blueprint, chips, brass.
const PAPER_CREAM := Color("e6dcc3")
const PAPER_EDGE := Color("c9b991")
const HUD_INK := Color("15151a")
const RED_PENCIL := Color("b8322c")
const BLUEPRINT := Color("1e3a5f")
const BLUEPRINT_LINE := Color("9ec3e6")
const CHIP_RED := Color("a8322d")
const CHIP_GOLD := Color("e8b842")
const BRASS := Color("b08d57")

static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## Market change colour: green up, red down, paper flat.
static func change(delta: float) -> Color:
	if delta > 0.0005:
		return UP
	if delta < -0.0005:
		return DOWN
	return PAPER_DIM
