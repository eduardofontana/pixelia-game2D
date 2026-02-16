extends Node2D
class_name LevelBase

const DEFAULT_WATER_SURFACE_ENTER_MARGIN_Y: float = 6.0
const DEFAULT_WATER_FALL_SPEED_THRESHOLD: float = 8.0
const DEFAULT_WATER_DEPTH_EXTENSION_Y: float = 420.0
const DEFAULT_WATER_SPLASH_PARTICLE_COUNT: int = 12
const DEFAULT_WATER_SPLASH_LIFETIME: float = 0.34
const DEFAULT_WATER_SPLASH_COOLDOWN: float = 0.18
const DEFAULT_ACTOR_Z_INDEX: int = 10
const DEFAULT_ACTOR_HEALTH_BAR_Z_INDEX: int = 5
const DEFAULT_PLAYER_BEHIND_WATER_Z_INDEX: int = 1
const DEFAULT_WATER_SPLASH_Z_INDEX: int = 3

var water_cover_zones: Array[Rect2] = []
var player_is_behind_water: bool = false
var water_splash_cooldown_timer: float = 0.0


func _connect_signal_once(emitter: Object, signal_name: StringName, callback: Callable) -> void:
	if emitter == null:
		return
	if not emitter.has_signal(signal_name):
		return
	if emitter.is_connected(signal_name, callback):
		return
	emitter.connect(signal_name, callback)


func _node_has_property(target_node: Object, property_name: StringName) -> bool:
	if target_node == null:
		return false
	for property_data in target_node.get_property_list():
		if StringName(property_data.get("name", "")) == property_name:
			return true
	return false


func _get_level_player_ref() -> CharacterBody2D:
	return null


func _get_water_decoration_root_path() -> NodePath:
	return NodePath("")


func _get_actor_z_index() -> int:
	return DEFAULT_ACTOR_Z_INDEX


func _get_actor_health_bar_z_index() -> int:
	return DEFAULT_ACTOR_HEALTH_BAR_Z_INDEX


func _get_player_behind_water_z_index() -> int:
	return DEFAULT_PLAYER_BEHIND_WATER_Z_INDEX


func _get_water_surface_enter_margin_y() -> float:
	return DEFAULT_WATER_SURFACE_ENTER_MARGIN_Y


func _get_water_fall_speed_threshold() -> float:
	return DEFAULT_WATER_FALL_SPEED_THRESHOLD


func _get_water_depth_extension_y() -> float:
	return DEFAULT_WATER_DEPTH_EXTENSION_Y


func _get_water_splash_particle_count() -> int:
	return DEFAULT_WATER_SPLASH_PARTICLE_COUNT


func _get_water_splash_lifetime() -> float:
	return DEFAULT_WATER_SPLASH_LIFETIME


func _get_water_splash_z_index() -> int:
	return DEFAULT_WATER_SPLASH_Z_INDEX


func _get_water_splash_cooldown() -> float:
	return DEFAULT_WATER_SPLASH_COOLDOWN


func _apply_actor_ordering(actor: CharacterBody2D) -> void:
	if actor == null:
		return
	actor.z_index = _get_actor_z_index()
	actor.z_as_relative = false

	var health_bar_node: CanvasItem = actor.get_node_or_null("HealthBar") as CanvasItem
	if health_bar_node != null:
		health_bar_node.z_index = _get_actor_health_bar_z_index()
		health_bar_node.z_as_relative = false


func _rebuild_water_cover_zones() -> void:
	water_cover_zones.clear()

	var decoration_path: NodePath = _get_water_decoration_root_path()
	if decoration_path == NodePath(""):
		return

	var decoration_root: Node = get_node_or_null(decoration_path)
	if decoration_root == null:
		return

	for child in decoration_root.get_children():
		var water_sprite: AnimatedSprite2D = child as AnimatedSprite2D
		if water_sprite == null:
			continue
		if not String(water_sprite.name).to_lower().begins_with("water"):
			continue

		var zone_rect: Rect2 = _build_water_cover_zone_rect(water_sprite)
		if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
			continue
		water_cover_zones.append(zone_rect)


func _build_water_cover_zone_rect(water_sprite: AnimatedSprite2D) -> Rect2:
	if water_sprite == null or water_sprite.sprite_frames == null:
		return Rect2()

	var animation_name: StringName = water_sprite.animation
	if not water_sprite.sprite_frames.has_animation(animation_name):
		return Rect2()
	if water_sprite.sprite_frames.get_frame_count(animation_name) <= 0:
		return Rect2()

	var frame_texture: Texture2D = water_sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if frame_texture == null:
		return Rect2()

	var texture_size: Vector2 = frame_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()

	var global_scale_abs: Vector2 = Vector2(absf(water_sprite.global_scale.x), absf(water_sprite.global_scale.y))
	var world_size: Vector2 = Vector2(texture_size.x * global_scale_abs.x, texture_size.y * global_scale_abs.y)
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return Rect2()

	var top_left: Vector2 = water_sprite.global_position
	if water_sprite.centered:
		top_left -= world_size * 0.5

	return Rect2(top_left, Vector2(world_size.x, world_size.y + _get_water_depth_extension_y()))


func _update_player_water_ordering() -> void:
	var level_player: CharacterBody2D = _get_level_player_ref()
	if level_player == null:
		return

	var player_water_zone: Rect2 = _find_player_water_zone(level_player)
	var should_be_behind_water: bool = player_water_zone.size.x > 0.0 and player_water_zone.size.y > 0.0
	if should_be_behind_water == player_is_behind_water:
		return

	if should_be_behind_water:
		_spawn_player_water_splash(level_player.global_position.x, player_water_zone.position.y)

	player_is_behind_water = should_be_behind_water
	if player_is_behind_water:
		_apply_player_behind_water_ordering(level_player)
	else:
		_apply_actor_ordering(level_player)


func _find_player_water_zone(player_body: CharacterBody2D) -> Rect2:
	if player_body == null:
		return Rect2()
	if water_cover_zones.is_empty():
		return Rect2()
	if player_body.velocity.y <= _get_water_fall_speed_threshold():
		return Rect2()

	var player_position: Vector2 = player_body.global_position
	for water_zone in water_cover_zones:
		if not water_zone.has_point(player_position):
			continue
		var enter_surface_y: float = water_zone.position.y - _get_water_surface_enter_margin_y()
		if player_position.y >= enter_surface_y:
			return water_zone
	return Rect2()


func _apply_player_behind_water_ordering(player_body: CharacterBody2D) -> void:
	if player_body == null:
		return

	var behind_water_z_index: int = _get_player_behind_water_z_index()
	player_body.z_index = behind_water_z_index
	player_body.z_as_relative = false

	var health_bar_node: CanvasItem = player_body.get_node_or_null("HealthBar") as CanvasItem
	if health_bar_node != null:
		health_bar_node.z_index = behind_water_z_index
		health_bar_node.z_as_relative = false


func _spawn_player_water_splash(world_x: float, water_surface_y: float) -> void:
	if water_splash_cooldown_timer > 0.0:
		return
	water_splash_cooldown_timer = _get_water_splash_cooldown()

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = self

	var splash_root := Node2D.new()
	splash_root.name = "WaterSplashFx"
	splash_root.global_position = Vector2(world_x, water_surface_y + 2.0)
	splash_root.z_as_relative = false
	splash_root.z_index = _get_water_splash_z_index()
	scene_root.add_child(splash_root)

	var splash_tween: Tween = splash_root.create_tween()
	splash_tween.set_parallel(true)

	for i in range(_get_water_splash_particle_count()):
		var droplet := Polygon2D.new()
		droplet.polygon = PackedVector2Array([
			Vector2(-1.5, -1.5),
			Vector2(1.5, -1.5),
			Vector2(1.5, 1.5),
			Vector2(-1.5, 1.5)
		])
		droplet.color = Color(0.72, 0.9, 1.0, 0.9).lerp(Color(0.92, 0.98, 1.0, 1.0), randf_range(0.0, 0.4))
		droplet.scale = Vector2.ONE * randf_range(0.85, 1.35)
		splash_root.add_child(droplet)

		var launch_angle: float = randf_range(-2.7, -0.45)
		var travel_distance: float = randf_range(18.0, 46.0)
		var target_offset: Vector2 = Vector2(cos(launch_angle), sin(launch_angle)) * travel_distance
		target_offset.y += randf_range(6.0, 22.0)
		var life_time: float = randf_range(_get_water_splash_lifetime() * 0.72, _get_water_splash_lifetime())

		splash_tween.tween_property(droplet, "position", target_offset, life_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		splash_tween.tween_property(droplet, "modulate:a", 0.0, life_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		splash_tween.tween_property(droplet, "scale", Vector2.ONE * randf_range(0.1, 0.25), life_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	splash_tween.set_parallel(false)
	splash_tween.tween_interval(0.03)
	splash_tween.tween_callback(Callable(splash_root, "queue_free"))
