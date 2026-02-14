extends AnimatableBody2D

@export var move_speed: float = 58.0
@export var forward_direction: int = 1
@export var max_forward_distance: float = 0.0
@export var collision_rearm_time: float = 0.08

var start_position: Vector2 = Vector2.ZERO
var forward_sign: int = 1
var returning_to_start: bool = false
var collision_rearm_timer: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	sync_to_physics = false
	start_position = global_position
	forward_sign = 1 if forward_direction >= 0 else -1


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return

	collision_rearm_timer = maxf(0.0, collision_rearm_timer - delta)
	var speed_value: float = maxf(0.0, move_speed)
	if speed_value <= 0.0:
		return

	if returning_to_start:
		_move_back_to_start(delta, speed_value)
		return

	var motion: Vector2 = Vector2(float(forward_sign) * speed_value * delta, 0.0)
	var collision: KinematicCollision2D = move_and_collide(motion)
	if collision != null and collision_rearm_timer <= 0.0:
		_begin_return_to_start()
		return

	if max_forward_distance > 0.0:
		var traveled: float = absf(global_position.x - start_position.x)
		if traveled >= max_forward_distance:
			_begin_return_to_start()


func _move_back_to_start(delta: float, speed_value: float) -> void:
	var next_x: float = move_toward(global_position.x, start_position.x, speed_value * delta)
	global_position = Vector2(next_x, global_position.y)
	if absf(global_position.x - start_position.x) <= 0.01:
		global_position = Vector2(start_position.x, global_position.y)
		returning_to_start = false
		collision_rearm_timer = maxf(0.0, collision_rearm_time)


func _begin_return_to_start() -> void:
	returning_to_start = true
	collision_rearm_timer = maxf(0.0, collision_rearm_time)
