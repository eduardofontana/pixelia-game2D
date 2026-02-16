extends Node2D

const PLAYER_SCENE_PATH: String = "res://scenes/player.tscn"
const KNIGHT_HIGHT_SCENE_PATH: String = "res://scenes/knight_hight.tscn"
const SELECTED_CHARACTER_ID_META_KEY: StringName = &"selected_character_id"
const SELECTED_CHARACTER_SCENE_META_KEY: StringName = &"selected_character_scene_path"
const Z_TERRAIN_FLOOR: int = 0
const Z_TERRAIN_DECORATION: int = 2
const Z_ACTOR: int = 10
const Z_ACTOR_HEALTHBAR: int = 5
const Z_PLAYER_BEHIND_WATER: int = 1
const WATER_SURFACE_ENTER_MARGIN_Y: float = 6.0
const WATER_FALL_SPEED_THRESHOLD: float = 8.0
const WATER_DEPTH_EXTENSION_Y: float = 420.0
const WATER_SPLASH_PARTICLE_COUNT: int = 12
const WATER_SPLASH_LIFETIME: float = 0.34
const WATER_SPLASH_Z_INDEX: int = Z_TERRAIN_DECORATION + 1
const WATER_SPLASH_COOLDOWN: float = 0.18

@onready var player_ref: CharacterBody2D = get_node_or_null("Player") as CharacterBody2D
@onready var hud_layer: CanvasLayer = get_node_or_null("HUD") as CanvasLayer

var water_cover_zones: Array[Rect2] = []
var player_is_behind_water: bool = false
var water_splash_cooldown_timer: float = 0.0


func _ready() -> void:
	_apply_selected_character_from_transition()
	_configure_level02_player_defaults()
	_rebind_player_dependents()
	_apply_level02_scene_ordering()
	_rebuild_water_cover_zones()
	_update_player_water_ordering()


func _physics_process(delta: float) -> void:
	water_splash_cooldown_timer = maxf(0.0, water_splash_cooldown_timer - delta)
	_update_player_water_ordering()


func _apply_selected_character_from_transition() -> void:
	var selected_scene_path: String = _resolve_selected_character_scene_path()
	if selected_scene_path.is_empty():
		return

	if player_ref != null and String(player_ref.scene_file_path).to_lower() == selected_scene_path.to_lower():
		return

	if not ResourceLoader.exists(selected_scene_path):
		push_warning("Level02: cena de personagem nao encontrada: %s" % selected_scene_path)
		return

	var loaded_scene: Resource = load(selected_scene_path)
	var selected_scene: PackedScene = loaded_scene as PackedScene
	if selected_scene == null:
		push_warning("Level02: recurso de personagem invalido: %s" % selected_scene_path)
		return

	var spawn_position: Vector2 = Vector2.ZERO
	var old_player_index: int = -1
	if player_ref != null:
		spawn_position = player_ref.position
		if player_ref.get_parent() == self:
			old_player_index = player_ref.get_index()
		if player_ref.get_parent() != null:
			player_ref.get_parent().remove_child(player_ref)
		player_ref.free()
		player_ref = null

	var next_player: CharacterBody2D = selected_scene.instantiate() as CharacterBody2D
	if next_player == null:
		push_warning("Level02: instancia de personagem invalida para %s" % selected_scene_path)
		return

	next_player.name = "Player"
	next_player.position = spawn_position
	if _node_has_property(next_player, &"enable_spawn_dialog"):
		next_player.set("enable_spawn_dialog", false)
	if _node_has_property(next_player, &"player_light_enabled"):
		next_player.set("player_light_enabled", true)
	add_child(next_player)

	if old_player_index >= 0 and old_player_index < get_child_count():
		move_child(next_player, old_player_index)

	player_ref = next_player
	if player_is_behind_water:
		_apply_player_behind_water_ordering(player_ref)
	else:
		_apply_actor_ordering(player_ref)


func _resolve_selected_character_scene_path() -> String:
	var tree_ref: SceneTree = get_tree()
	if tree_ref == null or tree_ref.root == null:
		return ""

	if tree_ref.root.has_meta(SELECTED_CHARACTER_SCENE_META_KEY):
		var path_meta: Variant = tree_ref.root.get_meta(SELECTED_CHARACTER_SCENE_META_KEY)
		var scene_path: String = String(path_meta)
		if not scene_path.is_empty():
			return scene_path

	if tree_ref.root.has_meta(SELECTED_CHARACTER_ID_META_KEY):
		var id_meta: Variant = tree_ref.root.get_meta(SELECTED_CHARACTER_ID_META_KEY)
		var character_id: String = String(id_meta).to_lower()
		if character_id == "knight_hight":
			return KNIGHT_HIGHT_SCENE_PATH
		if character_id == "player":
			return PLAYER_SCENE_PATH

	return ""


func _configure_level02_player_defaults() -> void:
	if player_ref == null:
		return

	if _node_has_property(player_ref, &"enable_spawn_dialog"):
		player_ref.set("enable_spawn_dialog", false)
	if _node_has_property(player_ref, &"player_light_enabled"):
		player_ref.set("player_light_enabled", true)
	if player_is_behind_water:
		_apply_player_behind_water_ordering(player_ref)
	else:
		_apply_actor_ordering(player_ref)

	var player_camera: Camera2D = player_ref.get_node_or_null("Camera2D") as Camera2D
	if player_camera != null:
		player_camera.make_current()


func _rebind_player_dependents() -> void:
	if player_ref == null:
		return

	if hud_layer != null and _node_has_property(hud_layer, &"player_path"):
		hud_layer.set("player_path", NodePath("../Player"))

	var nodes_to_rebind: Array[Node] = []
	nodes_to_rebind.append_array(get_tree().get_nodes_in_group("enemies"))
	if hud_layer != null:
		nodes_to_rebind.append(hud_layer)

	for node in nodes_to_rebind:
		if node == null:
			continue
		if _node_has_property(node, &"player_ref"):
			node.set("player_ref", null)
		if node.has_method("_retry_bind_player"):
			node.call("_retry_bind_player")
		elif node.has_method("_bind_player"):
			node.call("_bind_player")
		if node.has_method("_refresh_from_player"):
			node.call("_refresh_from_player")


func _node_has_property(target_node: Object, property_name: StringName) -> bool:
	if target_node == null:
		return false
	for property_data in target_node.get_property_list():
		if StringName(property_data.get("name", "")) == property_name:
			return true
	return false


func _apply_level02_scene_ordering() -> void:
	var floor_layer: CanvasItem = get_node_or_null("Construction/Terrain/Floor") as CanvasItem
	if floor_layer != null:
		floor_layer.z_index = Z_TERRAIN_FLOOR
		floor_layer.z_as_relative = false

	var decoration_layer: CanvasItem = get_node_or_null("Construction/Decoration") as CanvasItem
	if decoration_layer != null:
		decoration_layer.z_index = Z_TERRAIN_DECORATION
		decoration_layer.z_as_relative = false

	_apply_actor_ordering(player_ref)


func _apply_actor_ordering(actor: CharacterBody2D) -> void:
	if actor == null:
		return
	actor.z_index = Z_ACTOR
	actor.z_as_relative = false

	var health_bar_node: CanvasItem = actor.get_node_or_null("HealthBar") as CanvasItem
	if health_bar_node != null:
		health_bar_node.z_index = Z_ACTOR_HEALTHBAR
		health_bar_node.z_as_relative = false


func _rebuild_water_cover_zones() -> void:
	water_cover_zones.clear()

	var decoration_root: Node = get_node_or_null("Construction/Decoration")
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

	return Rect2(top_left, Vector2(world_size.x, world_size.y + WATER_DEPTH_EXTENSION_Y))


func _update_player_water_ordering() -> void:
	if player_ref == null:
		return

	var player_water_zone: Rect2 = _find_player_water_zone(player_ref)
	var should_be_behind_water: bool = player_water_zone.size.x > 0.0 and player_water_zone.size.y > 0.0
	if should_be_behind_water == player_is_behind_water:
		return

	if should_be_behind_water:
		_spawn_player_water_splash(player_ref.global_position.x, player_water_zone.position.y)

	player_is_behind_water = should_be_behind_water
	if player_is_behind_water:
		_apply_player_behind_water_ordering(player_ref)
	else:
		_apply_actor_ordering(player_ref)


func _find_player_water_zone(player_body: CharacterBody2D) -> Rect2:
	if player_body == null:
		return Rect2()
	if water_cover_zones.is_empty():
		return Rect2()
	if player_body.velocity.y <= WATER_FALL_SPEED_THRESHOLD:
		return Rect2()

	var player_position: Vector2 = player_body.global_position
	for water_zone in water_cover_zones:
		if not water_zone.has_point(player_position):
			continue
		var enter_surface_y: float = water_zone.position.y - WATER_SURFACE_ENTER_MARGIN_Y
		if player_position.y >= enter_surface_y:
			return water_zone
	return Rect2()


func _apply_player_behind_water_ordering(player_body: CharacterBody2D) -> void:
	if player_body == null:
		return

	player_body.z_index = Z_PLAYER_BEHIND_WATER
	player_body.z_as_relative = false

	var health_bar_node: CanvasItem = player_body.get_node_or_null("HealthBar") as CanvasItem
	if health_bar_node != null:
		health_bar_node.z_index = Z_PLAYER_BEHIND_WATER
		health_bar_node.z_as_relative = false


func _spawn_player_water_splash(world_x: float, water_surface_y: float) -> void:
	if water_splash_cooldown_timer > 0.0:
		return
	water_splash_cooldown_timer = WATER_SPLASH_COOLDOWN

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = self

	var splash_root := Node2D.new()
	splash_root.name = "WaterSplashFx"
	splash_root.global_position = Vector2(world_x, water_surface_y + 2.0)
	splash_root.z_as_relative = false
	splash_root.z_index = WATER_SPLASH_Z_INDEX
	scene_root.add_child(splash_root)

	var splash_tween: Tween = splash_root.create_tween()
	splash_tween.set_parallel(true)

	for i in range(WATER_SPLASH_PARTICLE_COUNT):
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
		var life_time: float = randf_range(WATER_SPLASH_LIFETIME * 0.72, WATER_SPLASH_LIFETIME)

		splash_tween.tween_property(droplet, "position", target_offset, life_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		splash_tween.tween_property(droplet, "modulate:a", 0.0, life_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		splash_tween.tween_property(droplet, "scale", Vector2.ONE * randf_range(0.1, 0.25), life_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	splash_tween.set_parallel(false)
	splash_tween.tween_interval(0.03)
	splash_tween.tween_callback(Callable(splash_root, "queue_free"))
