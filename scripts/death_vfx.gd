extends RefCounted

const MIN_PARTICLES: int = 4
const MAX_PARTICLES: int = 32
const DEFAULT_PARTICLES: int = 12


static func play_fade_and_burst(owner: Node2D, fade_target: CanvasItem, world_position: Vector2, particle_color: Color = Color(1.0, 0.42, 0.42, 1.0), particle_amount: int = DEFAULT_PARTICLES, fade_duration: float = 0.26) -> Tween:
	if owner == null:
		return null

	spawn_burst(owner, world_position, particle_color, particle_amount)
	return fade_out(owner, fade_target, fade_duration)


static func fade_out(owner: Node2D, target: CanvasItem, duration: float = 0.26) -> Tween:
	if owner == null:
		return null

	var tween: Tween = owner.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)

	if target == null:
		tween.tween_interval(maxf(0.01, duration))
		return tween

	var start_color: Color = target.modulate
	var flash_color: Color = start_color.lerp(Color(1.0, 0.55, 0.55, start_color.a), 0.55)
	target.modulate = flash_color

	var end_color: Color = Color(start_color.r, start_color.g, start_color.b, 0.0)
	tween.tween_property(target, "modulate", end_color, maxf(0.01, duration))
	return tween


static func spawn_burst(owner: Node2D, world_position: Vector2, base_color: Color = Color(1.0, 0.42, 0.42, 1.0), particle_amount: int = DEFAULT_PARTICLES) -> void:
	if owner == null:
		return

	var scene_root: Node = owner.get_tree().current_scene
	if scene_root == null:
		scene_root = owner.get_parent()
	if scene_root == null:
		return

	var burst_root: Node2D = Node2D.new()
	burst_root.name = "DeathBurstFx"
	burst_root.global_position = world_position
	if owner is CanvasItem:
		var owner_item: CanvasItem = owner as CanvasItem
		burst_root.z_as_relative = false
		burst_root.z_index = owner_item.z_index + 1
	scene_root.add_child(burst_root)

	var count: int = clampi(particle_amount, MIN_PARTICLES, MAX_PARTICLES)
	var tween: Tween = burst_root.create_tween()
	tween.set_parallel(true)

	for i in range(count):
		var shard: Polygon2D = Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(-1.6, -1.6),
			Vector2(1.6, -1.6),
			Vector2(1.6, 1.6),
			Vector2(-1.6, 1.6)
		])
		shard.color = base_color.lerp(Color(1.0, 1.0, 1.0, 1.0), randf_range(0.0, 0.32))
		shard.modulate = Color(1, 1, 1, 1)
		shard.scale = Vector2.ONE * randf_range(0.8, 1.45)
		shard.rotation = randf_range(0.0, TAU)
		burst_root.add_child(shard)

		var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var distance: float = randf_range(12.0, 40.0)
		var target_position: Vector2 = (direction * distance) + Vector2(0.0, randf_range(-12.0, 8.0))
		var move_time: float = randf_range(0.22, 0.34)
		tween.tween_property(shard, "position", target_position, move_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "modulate", Color(1, 1, 1, 0), move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(shard, "scale", Vector2.ONE * randf_range(0.08, 0.24), move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.set_parallel(false)
	tween.tween_interval(0.04)
	tween.tween_callback(Callable(burst_root, "queue_free"))
