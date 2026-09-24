extends RefCounted
class_name WeaponMods
## Weapon mods sold at the Black Market. Small weapons take one, big weapons
## two. A mod is fitted to the active weapon if it has room, otherwise to
## another carried weapon that does. Mods travel with the weapon (saved).
##   suppressor     noise -60%, damage -10%
##   extended_mag   +50% magazine
##   laser_sight    -50% spread, a visible laser line
##   hollow_points  +1 damage to unarmoured guards, -1 to armoured ones
##   quick_hands    reload -30%
##   incendiary     hits set guards burning (1 damage a second for 3 s)

## id: [name, description, base price, tag]
const DATA := {
	&"suppressor": ["Suppressor", "Gunshots carry 60% less far. Damage -10%.", 200, "SUP"],
	&"extended_mag": ["Extended Mag", "+50% magazine size.", 180, "EXT"],
	&"laser_sight": ["Laser Sight", "Spread halved, with a laser to show it.", 220, "LAS"],
	&"hollow_points": ["Hollow Points", "+1 damage to unarmoured guards, -1 to armoured.", 240, "HP"],
	&"quick_hands": ["Quick Hands", "Reload 30% faster.", 190, "QH"],
	&"incendiary": ["Incendiary Rounds", "Hits set guards burning: 1 damage a second for 3 s.", 260, "INC"],
}

static func name_of(id: StringName) -> String:
	return DATA[id][0] if DATA.has(id) else String(id)

static func tag_of(id: StringName) -> String:
	return DATA[id][3] if DATA.has(id) else "?"

## The weapon a new mod `id` would be fitted to, or null if none has room.
static func target_for(id: StringName) -> WeaponItem:
	if RunState.loadout == null:
		return null
	var active := RunState.loadout.get_active()
	if active and active.can_take_mod(id):
		return active
	for w in RunState.loadout.big + RunState.loadout.small:
		if w != null and w.can_take_mod(id):
			return w
	return null

static func install(id: StringName) -> WeaponItem:
	var w := target_for(id)
	if w:
		w.mods.append(id)
		if RunState.loadout:
			RunState.loadout.refresh_active()
	return w
