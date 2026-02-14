extends Area2D

@export_range(0.0, 720.0, 1.0) var rotate_speed_deg_per_sec: float = 180.0


func _process(delta: float) -> void:
	if not visible:
		return
	rotation_degrees = wrapf(rotation_degrees + (rotate_speed_deg_per_sec * delta), 0.0, 360.0)
