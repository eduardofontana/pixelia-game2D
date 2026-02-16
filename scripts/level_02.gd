extends "res://scripts/level_base.gd"

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


func _get_level_player_ref() -> CharacterBody2D:
	return player_ref


func _get_water_decoration_root_path() -> NodePath:
	return NodePath("Construction/Decoration")


func _get_actor_z_index() -> int:
	return Z_ACTOR


func _get_actor_health_bar_z_index() -> int:
	return Z_ACTOR_HEALTHBAR


func _get_player_behind_water_z_index() -> int:
	return Z_PLAYER_BEHIND_WATER


func _get_water_surface_enter_margin_y() -> float:
	return WATER_SURFACE_ENTER_MARGIN_Y


func _get_water_fall_speed_threshold() -> float:
	return WATER_FALL_SPEED_THRESHOLD


func _get_water_depth_extension_y() -> float:
	return WATER_DEPTH_EXTENSION_Y


func _get_water_splash_particle_count() -> int:
	return WATER_SPLASH_PARTICLE_COUNT


func _get_water_splash_lifetime() -> float:
	return WATER_SPLASH_LIFETIME


func _get_water_splash_z_index() -> int:
	return WATER_SPLASH_Z_INDEX


func _get_water_splash_cooldown() -> float:
	return WATER_SPLASH_COOLDOWN
