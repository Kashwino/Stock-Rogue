extends Node
var sounds: Dictionary = {}
const SOUND_PATHS := {
	"shot": "res://audio/shot.wav",
	"hit": "res://audio/hit.wav",
	"pickup": "res://audio/pickup.wav",
	"warning": "res://audio/warning.wav"
}
var players: Array[AudioStreamPlayer] = []
var cursor := 0

func _ready() -> void:
	for id: String in SOUND_PATHS:
		sounds[id] = load(SOUND_PATHS[id])
	for i in 8:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		players.append(player)

func play_sound(id: String) -> void:
	if not sounds.has(id) or players.is_empty():
		return
	var player := players[cursor]
	cursor = (cursor + 1) % players.size()
	player.stream = sounds[id]
	player.play()
