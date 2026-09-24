extends RefCounted
class_name WeaponTraits
## One signature trait per weapon, shown on case reveals, chest cards and the
## job board. Stat-shaped traits (pierce, ricochet, knockback, quiet) are baked
## into the weapon's numbers in ItemPool; the rest are handled by the player
## (bursts, tightening, the snub's last round, fire rate at low health) and by
## the bullet (crits on unprovoked guards, fried electronics, elite damage,
## marks, paying pellets, venue lifts).

const FOR_WEAPON := {
	&"pistol": &"bottomless", &"snub38": &"last_round", &"tommygun": &"tightens",
	&"smg": &"quick_empty", &"burstcarbine": &"burst", &"shotgun": &"blowback",
	&"silenced9mm": &"suppressed", &"rifle": &"assassin", &"combatshotgun": &"ricochet_pellets",
	&"handcannon": &"piercing", &"squadlmg": &"steadies", &"ricochet": &"double_bounce",
	&"breacher": &"door_kicker", &"rail_dividend": &"rail", &"ghost_wire": &"whisper",
	&"nailgun": &"nails", &"scatter_note": &"paying_pellets", &"circuit_smg": &"fries_electronics",
	&"margin_call": &"elite_hunter", &"hostile_takeover": &"desperate", &"eviction_notice": &"eviction",
	&"red_pen": &"red_mark", &"diplomatic_pouch": &"gold_fan", &"golden_gavel": &"gavel",
}

const TEXT := {
	&"bottomless": "Bottomless reserve; the magazine reloads itself.",
	&"last_round": "The last round in the cylinder deals triple damage.",
	&"tightens": "Tightens up after half a second of sustained fire.",
	&"quick_empty": "Reloads 40% faster from an empty magazine.",
	&"burst": "Fires three-round bursts.",
	&"blowback": "Knocks guards back hard.",
	&"suppressed": "Suppressed: barely heard past the next room.",
	&"assassin": "Triple damage against guards who haven't noticed you.",
	&"ricochet_pellets": "Pellets ricochet once.",
	&"piercing": "Rounds punch through one guard.",
	&"steadies": "Steadies the longer you fire, but slows you down.",
	&"double_bounce": "Rounds ricochet twice.",
	&"door_kicker": "Blows guards off their feet.",
	&"rail": "Pierces three guards in a line.",
	&"whisper": "Whisper-quiet at full auto.",
	&"nails": "Nails pierce one guard.",
	&"paying_pellets": "Every pellet that lands pays $1.",
	&"fries_electronics": "Fries electronics: cameras and drones drop in one hit.",
	&"elite_hunter": "Double damage against elites and lieutenants.",
	&"desperate": "Fires faster when you're down to two hearts or less.",
	&"eviction": "Blasts shove everything back.",
	&"red_mark": "Marks what it hits: marked guards take +1 damage from everything.",
	&"gold_fan": "Fires a fan of three gold rounds.",
	&"gavel": "Kills with it lift the venue 2%.",
}

static func text_of(weapon: WeaponItem) -> String:
	return TEXT.get(weapon.trait_id, "") if weapon else ""
