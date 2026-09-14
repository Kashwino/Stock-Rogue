extends Node
const SOUNDS := {
	"shot": preload("res://audio/shot.wav"),
	"hit": preload("res://audio/hit.wav"),
	"pickup": preload("res://audio/pickup.wav"),
	"warning": preload("res://audio/warning.wav")
}
var players: Array[AudioStreamPlayer] = []
var cursor := 0

func _ready() -> void:
	for i in 8:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		players.append(player)

func play_sound(id: String) -> void:
	if not SOUNDS.has(id) or players.is_empty():
		return
	var player := players[cursor]
	cursor = (cursor + 1) % players.size()
	player.stream = SOUNDS[id]
	player.play()
