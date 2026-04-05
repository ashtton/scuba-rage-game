extends Control

const BASE_MAX_BUBBLES := 90
const SPAWN_INTERVAL := 0.11

var _rng := RandomNumberGenerator.new()
var _spawn_accumulator := 0.0
var _bubbles: Array[Dictionary] = []
var _max_bubbles := BASE_MAX_BUBBLES

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_update_density()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_prime_bubbles()
	queue_redraw()


func _process(delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	_spawn_accumulator += delta
	while _spawn_accumulator >= SPAWN_INTERVAL:
		_spawn_accumulator -= SPAWN_INTERVAL
		if _bubbles.size() < _max_bubbles:
			_spawn_bubble(true)

	for bubble in _bubbles:
		bubble.y -= bubble.speed * delta
		bubble.phase += bubble.phase_speed * delta
		bubble.x += sin(bubble.phase) * bubble.wobble * delta
		bubble.alpha = clampf(bubble.alpha + bubble.fade_in_speed * delta, 0.0, bubble.max_alpha)

	_bubbles = _bubbles.filter(func(bubble: Dictionary) -> bool:
		return bubble.y + bubble.radius > -20.0
	)

	queue_redraw()


func _draw() -> void:
	for bubble in _bubbles:
		draw_circle(Vector2(bubble.x, bubble.y), bubble.radius, Color(0.77, 0.95, 1.0, bubble.alpha))
		draw_arc(Vector2(bubble.x, bubble.y), bubble.radius, -2.3, -0.8, 12, Color(1, 1, 1, bubble.alpha * 0.45), 1.5)


func _prime_bubbles() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for i in int(_max_bubbles * 0.4):
		_spawn_bubble(false)


func _on_viewport_size_changed() -> void:
	_update_density()


func _update_density() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var area_factor := (viewport_size.x * viewport_size.y) / (1920.0 * 1080.0)
	_max_bubbles = int(clampf(BASE_MAX_BUBBLES * area_factor, 75.0, 190.0))


func _spawn_bubble(from_bottom: bool) -> void:
	var radius := _rng.randf_range(4.0, 16.0)
	var y := _rng.randf_range(radius, size.y + radius)
	if from_bottom:
		y = size.y + radius + _rng.randf_range(0.0, 120.0)

	_bubbles.append({
		"x": _rng.randf_range(0.0, size.x),
		"y": y,
		"radius": radius,
		"speed": _rng.randf_range(42.0, 124.0),
		"wobble": _rng.randf_range(8.0, 34.0),
		"phase": _rng.randf_range(0.0, TAU),
		"phase_speed": _rng.randf_range(1.2, 3.2),
		"alpha": _rng.randf_range(0.0, 0.15),
		"max_alpha": _rng.randf_range(0.18, 0.48),
		"fade_in_speed": _rng.randf_range(0.12, 0.38)
	})
