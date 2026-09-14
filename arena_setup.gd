extends Node2D
## Attach this to the arena ROOT node. It assembles a playable heist:
## builds the market, wires the LiveStock to the player + room + a venue,
## loads the character profile, and connects the HeistController.
##
## Expected children (adjust the @export paths in the Inspector to match):
##   - Player   (Player)
##   - Room     (Room)
##   - Node     (LiveStock)   <- your node with live_stock.gd
## Optionally a HeistController node.

@export var player_path: NodePath = ^"Player"
@export var room_path: NodePath = ^"Room"
@export var live_stock_path: NodePath = ^"Node"          # your LiveStock node
@export var hud_path: NodePath = ^"HUD"                   # the HUD CanvasLayer
@export var results_path: NodePath = ^"ResultsScreen"    # the ResultsScreen CanvasLayer
@export var character_profile: CharacterProfile          # assign main_character.tres
@export var venue_asset_id: StringName = &"bank_job"     # which stock this heist moves
@export var par_time: float = 90.0                       # target time for full speed marks

var market: CriminalMarket
var _player: Player
var _room: Room
var _live: LiveStock
var _hud: CanvasLayer
var _results: CanvasLayer
var _loadout: Loadout
var _sequencer: HeistSequencer
var _cum_kills: int = 0
var _cum_enemies: int = 0
var _heist_start: float = 0.0

func _ready() -> void:
	_player = get_node(player_path)
	_room = get_node(room_path)
	_live = get_node(live_stock_path)

	# 0. If launched from the run flow, take this heist's rarity/venue from the
	#    chosen map node, and use the persistent character profile.
	if RunFlow.pending_heist != null:
		_room.rarity = RunFlow.pending_heist.room_rarity
		venue_asset_id = RunFlow.pending_heist.venue_id
	if RunState.character_profile:
		character_profile = RunState.character_profile

	# 1. Build the market and roster.
	market = CriminalMarket.new()
	market.assets = Roster.build()
	add_child(market)
	market.setup()

	# 2. Wire the live stock driver to this venue + the player.
	_live.venue_asset_id = venue_asset_id
	_live.setup(market, _player, character_profile)

	# 3. Hand the same LiveStock to the player and room so their calls land.
	_player.live_stock = _live
	_room.live_stock = _live

	# 3b. Use the PERSISTENT loadout from RunState (survives across heists).
	#     Falls back to a fresh Sidearm loadout if the run wasn't started properly.
	if RunState.loadout != null:
		_loadout = RunState.loadout
	else:
		_loadout = Loadout.new()
		add_child(_loadout)
		_loadout.equip(ItemPool.weapons()[0])
		RunState.loadout = _loadout
	_player.loadout = _loadout

	# 3c. Connect any ChestUI's pick to equip/apply logic.
	var chest_uis := get_tree().get_nodes_in_group("chest_ui")
	if chest_uis.size() > 0:
		chest_uis[0].item_chosen.connect(on_item_claimed)

	# 4. Apply persistent health + upgrades from RunState onto the player.
	if RunState.active:
		RunState.apply_to_player(_player)
	elif character_profile:
		_player.max_health = character_profile.base_health
		_player.health = character_profile.base_health
		_player.health_changed.emit(_player.health, _player.max_health)

	# 5. Listen for live price changes (hook your ticker UI here).
	_live.price_updated.connect(_on_price_updated)

	# 5b. Bind the HUD so it shows health, currency, stock, and weapon/ammo.
	_hud = get_node_or_null(hud_path)
	if _hud and _hud.has_method("bind_hud"):
		_hud.bind_hud(_player, _live, _loadout)

	# 5c. Grab the results screen and show it when the heist ends.
	_results = get_node_or_null(results_path)
	if _results:
		_results.continued.connect(_on_results_continued)

	# 6. Run the multi-room heist via the sequencer (reuses the one Room node).
	_heist_start = Time.get_ticks_msec() / 1000.0
	_cum_kills = 0
	_cum_enemies = 0
	_room.enemy_killed.connect(func(_k): _cum_kills += 1)

	_sequencer = HeistSequencer.new()
	add_child(_sequencer)
	_sequencer.room_changed.connect(_on_room_changed)
	_sequencer.heist_complete.connect(_on_heist_complete)

	var stage := RunState.run_map.current_stage if RunState.run_map else 0
	var rarity := RunFlow.pending_heist.room_rarity if RunFlow.pending_heist else 0
	var run_seed := RunFlow.run_seed
	var heist_index := RunState.run_map.current_step if RunState.run_map else 0
	var start_room := RunFlow.room_index   # resume point
	_sequencer.setup(_room, stage, rarity, run_seed, heist_index, start_room)

func _on_room_changed(index: int, total: int, is_miniboss: bool) -> void:
	# Boundary save each room; tally the enemies for the final grade.
	RunFlow.on_room_entered(index)
	_cum_enemies += _room.enemy_total()
	if is_miniboss:
		pass # Debug logging removed.

func _on_heist_complete() -> void:
	var elapsed := (Time.get_ticks_msec() / 1000.0) - _heist_start
	var stats := {
		"hits_taken": _player.hits_taken,
		"shots_fired": _player.shots_fired,
		"shots_hit": _player.shots_hit,
		"kills": _cum_kills,
		"enemies_total": _cum_enemies,
		"time_seconds": elapsed,
		"par_time": par_time * _sequencer.total_rooms(),   # par scales with length
	}
	var result := HeistGrader.grade_heist(stats)
	var asset := market.get_asset(venue_asset_id)
	if asset:
		asset.current_price = max(asset.current_price * result["stock_delta"], 0.01)
	result["stats"] = stats
	if _results:
		_results.show_result(result, String(venue_asset_id))

func _on_results_continued() -> void:
	# Sync post-heist health back into the run, then return to the map.
	RunState.sync_from_player(_player)
	RunFlow.on_heist_finished()

## Connect a chest UI's item_chosen signal to this to equip/apply the pick.
func on_item_claimed(item) -> void:
	if item is WeaponItem:
		_loadout.equip(item)
		pass # Debug logging removed.
	elif item is UpgradeItem:
		item.apply_to(_player)
		pass # Debug logging removed.

func _on_price_updated(price: float, delta: float, direction: int) -> void:
	# Placeholder: print live stock moves so you can see it working.
	# Replace with a real ticker label update later.
	var arrow := "up" if direction > 0 else "down"
	pass # Debug logging removed.
