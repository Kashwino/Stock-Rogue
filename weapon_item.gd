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

@export var pierce: int = 0
@export var ricochets: int = 0
@export var knockback: float = 0.0
@export var noise_radius: float = 900.0

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

# --- Identity: a signature trait and fitted mods ---
## See WeaponTraits (set by ItemPool).
@export var trait_id: StringName = &""
## Fitted WeaponMods ids (1 slot on small weapons, 2 on big ones).
var mods: Array = []

func trait_text() -> String:
	return WeaponTraits.text_of(self)

func mod_slots() -> int:
	return 2 if slot == Slot.BIG else 1

func has_mod(id: StringName) -> bool:
	return id in mods

func can_take_mod(id: StringName) -> bool:
	return mods.size() < mod_slots() and id not in mods

## Stats after mods: what the player actually fires.
func eff_damage() -> int:
	return maxi(1, roundi(damage * 0.9)) if has_mod(&"suppressor") else damage

func eff_spread() -> float:
	return spread * (0.5 if has_mod(&"laser_sight") else 1.0)

func eff_mag() -> int:
	return int(ceil(mag_size * 1.5)) if has_mod(&"extended_mag") else mag_size

func eff_reload() -> float:
	return reload_time * (0.7 if has_mod(&"quick_hands") else 1.0)

func eff_noise() -> float:
	return noise_radius * (0.4 if has_mod(&"suppressor") else 1.0)
