extends Node2D

@export_file("*.tscn") var next_scene_path := ""
@export var level_title := "Level 01"
@export var mechanic_name := "Vent Ladder"
@export_multiline var intro_message := "Hold left click to charge. Release to launch at the cursor."
@export var intro_duration := 4.0
@export var checkpoint_duration := 2.2
@export var death_depth := 2400.0
@export var camera_left := 0
@export var camera_top := -1200
@export var camera_right := 1920
@export var camera_bottom := 2400

const BATTERY_FILL_MAX_HEIGHT := 104.0

@onready var player: SubmarinePlayer = $World/Player
@onready var battery_fill: ColorRect = $HUD/BatteryHUD/BatteryShell/BatteryClip/BatteryFill
@onready var battery_value: Label = $HUD/BatteryHUD/BatteryValue
@onready var battery_status: Label = $HUD/BatteryHUD/BatteryStatus
@onready var cooldown_value: Label = $HUD/BatteryHUD/CooldownValue
@onready var message_label: Label = $HUD/MessagePlate/MessageLabel
@onready var level_value: Label = $HUD/LevelPlate/LevelValue
@onready var mechanic_value: Label = $HUD/LevelPlate/MechanicValue

var _message_time_left := 0.0
var _battery_current := 0.0
var _battery_max := 1.0
var _transitioning := false
var _active_checkpoint = null


func _ready() -> void:
	player.set_spawn_point(player.global_position)
	player.death_depth = death_depth
	_configure_camera()

	level_value.text = level_title
	mechanic_value.text = mechanic_name

	player.battery_changed.connect(_on_player_battery_changed)
	player.cooldown_changed.connect(_on_player_cooldown_changed)
	player.died.connect(_on_player_died)

	for checkpoint in get_tree().get_nodes_in_group("level_checkpoint"):
		if checkpoint is Area2D and is_ancestor_of(checkpoint) and checkpoint.has_signal("reached"):
			checkpoint.connect("reached", _on_checkpoint_reached)

	_on_player_battery_changed(player.current_battery, player.max_battery)
	_on_player_cooldown_changed(0.0, player.boost_cooldown, false)
	_show_message(intro_message, intro_duration)


func _process(delta: float) -> void:
	if _message_time_left <= 0.0:
		return

	_message_time_left = maxf(_message_time_left - delta, 0.0)
	if _message_time_left == 0.0:
		message_label.text = ""


func _on_player_battery_changed(current_battery: float, max_battery: float) -> void:
	_battery_current = current_battery
	_battery_max = max_battery
	battery_value.text = "%04d" % int(round(current_battery))
	_refresh_battery_ui()


func _on_player_cooldown_changed(current_cooldown: float, max_cooldown: float, is_stunned: bool) -> void:
	if is_stunned:
		var stun_seconds := snappedf(current_cooldown, 0.1)
		cooldown_value.text = "STUNNED %.1fs" % maxf(stun_seconds, 0.1)
		cooldown_value.modulate = Color("ff8f88")
		return

	if current_cooldown <= 0.0:
		cooldown_value.text = "READY"
		cooldown_value.modulate = Color("98f5c3")
		return

	var seconds_left := snappedf(current_cooldown, 0.1)
	cooldown_value.text = "COOLDOWN %.1fs" % minf(seconds_left, max_cooldown)
	cooldown_value.modulate = Color("ffd59e")


func _on_player_died(reason: String) -> void:
	_show_message(reason, 1.8)


func _on_checkpoint_reached(checkpoint: Node) -> void:
	if checkpoint == _active_checkpoint:
		return

	if _active_checkpoint != null and _active_checkpoint.has_method("set_active"):
		_active_checkpoint.set_active(false)

	_active_checkpoint = checkpoint
	if _active_checkpoint.has_method("set_active"):
		_active_checkpoint.set_active(true)
	if checkpoint.has_method("get_spawn_point"):
		player.set_spawn_point(checkpoint.get_spawn_point())
	player.refill_battery()
	var checkpoint_name := str(checkpoint.get("checkpoint_name"))
	_show_message("%s stabilized. Battery restored." % checkpoint_name, checkpoint_duration)


func _show_message(text: String, duration: float) -> void:
	message_label.text = text
	_message_time_left = duration


func _refresh_battery_ui() -> void:
	var display_ratio := clampf(_battery_current / maxf(_battery_max, 0.001), 0.0, 1.0)
	if display_ratio > 0.55:
		battery_fill.color = Color("78f08a")
	elif display_ratio > 0.25:
		battery_fill.color = Color("ffd166")
	else:
		battery_fill.color = Color("ff6b6b")

	var fill_height := BATTERY_FILL_MAX_HEIGHT * display_ratio
	battery_fill.size.y = fill_height
	battery_fill.position.y = BATTERY_FILL_MAX_HEIGHT - fill_height

	if display_ratio > 0.55:
		battery_status.text = "HEALTHY"
		battery_status.modulate = Color("ddffe2")
	elif display_ratio > 0.25:
		battery_status.text = "LOW"
		battery_status.modulate = Color("fff0b0")
	else:
		battery_status.text = "CRITICAL"
		battery_status.modulate = Color("ffd1d1")


func _configure_camera() -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	if camera == null:
		return

	camera.limit_left = camera_left
	camera.limit_top = camera_top
	camera.limit_right = camera_right
	camera.limit_bottom = camera_bottom
