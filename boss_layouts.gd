extends RefCounted
class_name BossLayouts
## Hand-authored signature buildings for the four stage bosses, as data the
## FloorGenerator consumes (generate_authored). Everything else — dressing,
## crews, loot, chests, security, exits — runs through the normal pipeline.
##
## Each room: id (node name), size (small 1x1 / medium 2x1 / large 2x2 on the
## 600x450 module grid), cell (top-left module), role (start / boss / weapon /
## upgrade / "" for an ordinary room), type (RoomArt dressing), title, and an
## optional counter (local position of a solid service counter).

const LAYOUTS := {
	# Town: a run-down tenement, the Landlord's rent office on the top floor.
	&"landlord": {
		"name": "TENEMENT ROW",
		"stage": 0,
		"exits": 1,
		"rooms": [
			{"id": "Stoop", "size": "small", "cell": Vector2i(1, 3), "role": "start", "type": "lobby", "title": "STOOP"},
			{"id": "Laundry", "size": "small", "cell": Vector2i(0, 3), "type": "storage", "title": "LAUNDRY"},
			{"id": "PawnCounter", "size": "small", "cell": Vector2i(2, 3), "type": "pawnshop", "title": "PAWN COUNTER", "counter": Vector2(300, 125)},
			{"id": "Stairwell", "size": "medium", "cell": Vector2i(0, 2), "type": "warehouse", "title": "STAIRWELL"},
			{"id": "Lockup", "size": "small", "cell": Vector2i(2, 2), "role": "weapon", "type": "vault", "title": "LOCKUP"},
			{"id": "RentOffice", "size": "large", "cell": Vector2i(0, 0), "role": "boss", "type": "boss_office", "title": "RENT OFFICE"},
			{"id": "Boiler", "size": "small", "cell": Vector2i(2, 1), "role": "upgrade", "type": "vault", "title": "BOILER ROOM"},
			{"id": "Rooftop", "size": "small", "cell": Vector2i(2, 0), "type": "garage", "title": "ROOF ACCESS"},
		],
	},
	# City: the Marlowe Exchange, the Board's accounting house.
	&"auditor": {
		"name": "MARLOWE EXCHANGE",
		"stage": 1,
		"exits": 2,
		"rooms": [
			{"id": "Lobby", "size": "small", "cell": Vector2i(1, 2), "role": "start", "type": "lobby", "title": "LOBBY", "counter": Vector2(300, 125)},
			{"id": "Cashier", "size": "small", "cell": Vector2i(0, 2), "type": "bank_hall", "title": "CASHIER"},
			{"id": "Security", "size": "small", "cell": Vector2i(2, 2), "type": "office", "title": "SECURITY"},
			{"id": "Records", "size": "small", "cell": Vector2i(0, 1), "role": "weapon", "type": "vault", "title": "RECORDS"},
			{"id": "Trading", "size": "small", "cell": Vector2i(1, 1), "type": "cubicles", "title": "TRADING"},
			{"id": "Offices", "size": "small", "cell": Vector2i(2, 1), "type": "office", "title": "OFFICES"},
			{"id": "Vault", "size": "small", "cell": Vector2i(0, 0), "role": "upgrade", "type": "vault", "title": "VAULT"},
			{"id": "Auditor", "size": "large", "cell": Vector2i(1, -1), "role": "boss", "type": "boss_office", "title": "AUDIT CHAMBER"},
		],
	},
	# World: an embassy, the ballroom upstairs behind the consulate.
	&"ambassador": {
		"name": "EMBASSY OF VALDORIA",
		"stage": 2,
		"exits": 2,
		"rooms": [
			{"id": "Gate", "size": "small", "cell": Vector2i(1, 3), "role": "start", "type": "lobby", "title": "EMBASSY GATE", "counter": Vector2(300, 125)},
			{"id": "Checkpoint", "size": "small", "cell": Vector2i(0, 3), "type": "embassy_hall", "title": "CHECKPOINT"},
			{"id": "Motorpool", "size": "small", "cell": Vector2i(2, 3), "type": "lounge", "title": "MOTOR POOL"},
			{"id": "Archive", "size": "small", "cell": Vector2i(0, 2), "role": "weapon", "type": "vault", "title": "DIPLOMATIC ARCHIVE"},
			{"id": "Consulate", "size": "medium", "cell": Vector2i(1, 2), "type": "embassy_hall", "title": "CONSULATE"},
			{"id": "Cellar", "size": "small", "cell": Vector2i(0, 1), "role": "upgrade", "type": "vault", "title": "WINE CELLAR"},
			{"id": "Terrace", "size": "small", "cell": Vector2i(0, 0), "type": "bar", "title": "TERRACE BAR"},
			{"id": "Ballroom", "size": "large", "cell": Vector2i(1, 0), "role": "boss", "type": "boss_office", "title": "BALLROOM"},
		],
	},
	# Doomsday: the Exchange tower, the trading floor under the ticker wall.
	&"chairman": {
		"name": "THE EXCHANGE",
		"stage": 3,
		"exits": 3,
		"rooms": [
			{"id": "Lobby", "size": "small", "cell": Vector2i(2, 3), "role": "start", "type": "lobby", "title": "TOWER LOBBY", "counter": Vector2(300, 125)},
			{"id": "Security", "size": "small", "cell": Vector2i(1, 3), "type": "glass_hall", "title": "SECURITY DESK"},
			{"id": "Elevators", "size": "small", "cell": Vector2i(3, 3), "type": "glass_hall", "title": "ELEVATORS"},
			{"id": "ExecFloor", "size": "medium", "cell": Vector2i(0, 2), "type": "exec_office", "title": "EXECUTIVE FLOOR"},
			{"id": "Atrium", "size": "medium", "cell": Vector2i(2, 2), "type": "glass_hall", "title": "ATRIUM"},
			{"id": "Servers", "size": "small", "cell": Vector2i(0, 1), "role": "upgrade", "type": "vault", "title": "SERVER VAULT"},
			{"id": "Suite", "size": "small", "cell": Vector2i(3, 1), "type": "exec_office", "title": "CHAIRMAN'S SUITE"},
			{"id": "Boardroom", "size": "small", "cell": Vector2i(0, 0), "type": "meeting", "title": "BOARDROOM"},
			{"id": "Archive", "size": "small", "cell": Vector2i(3, 0), "role": "weapon", "type": "vault", "title": "BOARD ARCHIVE"},
			{"id": "TradingFloor", "size": "large", "cell": Vector2i(1, 0), "role": "boss", "type": "trading_floor", "title": "THE TRADING FLOOR"},
		],
	},
}

static func has_layout(boss_id: StringName) -> bool:
	return LAYOUTS.has(boss_id)

static func layout(boss_id: StringName) -> Dictionary:
	return LAYOUTS.get(boss_id, LAYOUTS[&"auditor"])

## The stage whose materials dress this building.
static func stage_of(boss_id: StringName) -> int:
	return int(layout(boss_id).get("stage", 1))
