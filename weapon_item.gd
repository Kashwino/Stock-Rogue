extends Resource
class_name WeaponItem

## A weapon the player can pick from a Weapon chest. Big weapons take a big slot
## (2 max), small weapons the small slot (1 max). Ammo stats feed the ammo +
## scavenging system.

enum Slot { BIG, SMALL }

@export var id: StringName = &""
@export var display_name: String = "Pistol"
@export var rarity: Rarity.Tier = Rarity.Tier.STANDARD
@export var slot: Slot = Slot.SMALL

# --- Combat stats ---
@export var damage: int = 1
@export var fire_rate: float = 0.15          # seconds between shots (lower = faster)
@export var bullet_speed: float = 600.0
@export var spread: float = 0.0              # radians of random spread per shot
@export var pellets: int = 1                 # >1 for shotguns

# --- Ammo / scavenging ---
@export var uses_ammo: bool = true           # false = infinite (e.g. starter pistol)
@export var reload_time: float = 0.9         # seconds; ALL weapons reload (even infinite)
@export var mag_size: int = 12               # rounds per magazine
@export var max_reserve: int = 96            # max carried reserve ammo
@export var ammo_type: StringName = &"light" # scavenged ammo is matched by type

func rarity_name() -> String:
	return Rarity.name_of(rarity)

func rarity_color() -> Color:
	return Rarity.color_of(rarity)

func slot_name() -> String:
	return "Big" if slot == Slot.BIG else "Small"
