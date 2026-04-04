extends Node

const SOUNDTRACK := preload("res://assets/soundtrack.mp3")

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "SoundtrackPlayer"
	_player.stream = SOUNDTRACK
	_player.bus = &"Master"
	_player.autoplay = false
	_player.volume_db = -6.0
	_player.finished.connect(_on_track_finished)
	add_child(_player)

	if not _player.playing:
		_player.play()


func _on_track_finished() -> void:
	_player.play()
