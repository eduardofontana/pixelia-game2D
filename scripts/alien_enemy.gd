extends CharacterBody2D

enum EnemyState {
	PATROL,
	CHASE
}

const PLAYER_STRUCTURE_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const GROUND_CHECK_COLLISION_MASK: int = 1
const ATTACK_AREA_OFFSET_X: float = 20.0
const ATTACK_AREA_OFFSET_Y: float = -2.0
const CONTACT_RADIUS: float = 18.0
const ATTACK_RADIUS: float = 24.0
const HEALTH_BAR_WIDTH: float = 28.0
const HEALTH_PERCENT_FONT_SIZE: int = 10
const HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const VAMPIRE_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const LEDGE_CHECK_FORWARD_DISTANCE: float = 16.0
const LEDGE_CHECK_DOWN_START_Y: float = 4.0
const LEDGE_CHECK_DOWN_DISTANCE: float = 56.0
const DEATH_PARTICLE_COLOR: Color = Color(0.7, 0.9, 0.84, 1.0)
const DEATH_FADE_DURATION: float = 0.22
const HIT_KNOCKBACK_X: float = 96.0
const HIT_KNOCKBACK_Y: float = -84.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.3
const HIT_STUN_TIME: float = 0.16
const HURT_SFX_PATH: String = "res://sounds/Gore_Wet_7.wav"
const HURT_SFX_VOLUME_DB: float = -7.5
const DEATH_VFX = preload("res://scripts/death_vfx.gd")

@export var player_path: NodePath
@export var max_hp: int = 95
@export var patrol_distance_x: float = 120.0
@export var patrol_speed: float = 44.0
@export var chase_speed: float = 64.0
@export var detection_radius: float = 180.0
@export var lose_interest_radius: float = 260.0
@export var max_chase_distance: float = 330.0
@export var attack_range: float = 30.0
@export var attack_height_tolerance: float = 34.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.9
@export var contact_damage: int = 7
@export var contact_damage_cooldown: float = 0.7
@export var health_bar_visible_time: float = 3.2
@export var sprite_faces_left: bool = true

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: Node2D = get_node_or_null("HealthBar")
@onready var health_fill: Control = get_node_or_null("HealthBar/Bg/Fill")
@onready var health_percent_label: Label = get_node_or_null("HealthBar/PercentLabel")

var player_ref: CharacterBody2D = null
var enemy_state: int = EnemyState.PATROL
var spawn_position: Vector2 = Vector2.ZERO
var patrol_direction: int = 1
var facing_direction: int = 1
var current_hp: int = 1
var gravity: float = 980.0
var attack_cooldown_timer: float = 0.0
var contact_damage_timer: float = 0.0
var health_bar_timer: float = 0.0
var health_fill_style: StyleBoxFlat = null
var hit_stun_timer: float = 0.0
var is_dying: bool = false
var hurt_sfx_player: AudioStreamPlayer = null

var contact_area: Area2D = null
var contact_collision: CollisionShape2D = null
var attack_area: Area2D = null
var attack_collision: CollisionShape2D = null


func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	current_hp = max_hp
	gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	_bind_player()
	_create_hit_areas()
	_configure_collision_filters()
	_setup_health_fill_style()
	_apply_vampire_percent_font()
	_setup_hurt_sfx()
	_update_health_bar()
	if health_bar != null:
		health_bar.visible = false
	_play_animation(&"idle")


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	contact_damage_timer = maxf(0.0, contact_damage_timer - delta)
	health_bar_timer = maxf(0.0, health_bar_timer - delta)
	hit_stun_timer = maxf(0.0, hit_stun_timer - delta)
	_update_health_bar_timer()

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)

	if hit_stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
	else:
		match enemy_state:
			EnemyState.PATROL:
				_process_patrol(delta)
			EnemyState.CHASE:
				_process_chase(delta)

	move_and_slide()
	_process_contact_damage()
	_update_visuals()


func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	if is_dying or amount <= 0:
		return

	current_hp = maxi(0, current_hp - amount)
	_play_hurt_sfx()
	_apply_hit_knockback(from_position)
	hit_stun_timer = maxf(hit_stun_timer, HIT_STUN_TIME)
	_show_health_bar()
	_update_health_bar()

	if current_hp <= 0:
		_handle_death()


func _handle_death() -> void:
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	_set_collision_enabled(false)
	if health_bar != null:
		health_bar.visible = false
	set_physics_process(false)

	var fade_target: CanvasItem = animated_sprite
	if fade_target == null:
		fade_target = self
	var death_tween: Tween = DEATH_VFX.play_fade_and_burst(self, fade_target, global_position, DEATH_PARTICLE_COLOR, 12, DEATH_FADE_DURATION)
	if death_tween != null:
		death_tween.finished.connect(Callable(self, "queue_free"))
	else:
		queue_free()


func _process_patrol(delta: float) -> void:
	if _should_chase_player():
		enemy_state = EnemyState.CHASE
		return

	var left_bound: float = spawn_position.x - patrol_distance_x
	var right_bound: float = spawn_position.x + patrol_distance_x
	if global_position.x <= left_bound:
		patrol_direction = 1
	elif global_position.x >= right_bound:
		patrol_direction = -1
	elif is_on_floor() and not _has_floor_ahead(patrol_direction):
		patrol_direction *= -1

	var target_speed: float = patrol_speed * float(patrol_direction)
	velocity.x = move_toward(velocity.x, target_speed, 780.0 * delta)
	if absf(velocity.x) > 1.0:
		facing_direction = 1 if velocity.x > 0.0 else -1


func _process_chase(delta: float) -> void:
	if player_ref == null:
		enemy_state = EnemyState.PATROL
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	var distance_to_player: float = to_player.length()
	var distance_from_spawn: float = absf(global_position.x - spawn_position.x)
	if distance_to_player > lose_interest_radius or distance_from_spawn > max_chase_distance:
		enemy_state = EnemyState.PATROL
		return

	if absf(to_player.x) > 1.0:
		facing_direction = 1 if to_player.x > 0.0 else -1

	var in_attack_range: bool = absf(to_player.x) <= attack_range and absf(to_player.y) <= attack_height_tolerance
	if in_attack_range:
		velocity.x = move_toward(velocity.x, 0.0, 980.0 * delta)
		if attack_cooldown_timer <= 0.0:
			_apply_attack_damage()
			attack_cooldown_timer = attack_cooldown
		return

	if is_on_floor() and not _has_floor_ahead(facing_direction):
		velocity.x = move_toward(velocity.x, 0.0, 980.0 * delta)
		return

	var target_speed: float = 0.0
	if absf(to_player.x) > 2.0:
		target_speed = chase_speed * sign(to_player.x)
	velocity.x = move_toward(velocity.x, target_speed, 920.0 * delta)


func _apply_attack_damage() -> void:
	if attack_area == null:
		return

	for body in attack_area.get_overlapping_bodies():
		if _is_player_target(body) and body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)
			return

	if player_ref != null and player_ref.has_method("take_damage"):
		if _is_player_within_attack_fallback(player_ref):
			player_ref.take_damage(attack_damage, global_position)


func _process_contact_damage() -> void:
	if contact_area == null or contact_damage_timer > 0.0:
		return

	for body in contact_area.get_overlapping_bodies():
		if _is_player_target(body) and body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)
			contact_damage_timer = contact_damage_cooldown
			return

	if player_ref != null and player_ref.has_method("take_damage"):
		if global_position.distance_to(player_ref.global_position) <= (attack_range + 8.0):
			player_ref.take_damage(contact_damage, global_position)
			contact_damage_timer = contact_damage_cooldown


func _update_visuals() -> void:
	if animated_sprite == null:
		return

	animated_sprite.flip_h = facing_direction > 0 if sprite_faces_left else facing_direction < 0
	_update_attack_area_transform()

	if absf(velocity.x) > 4.0:
		_play_animation(&"walk")
	else:
		_play_animation(&"idle")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _setup_health_fill_style() -> void:
	if health_fill == null:
		return

	var panel_style: StyleBox = health_fill.get_theme_stylebox("panel")
	if not (panel_style is StyleBoxFlat):
		return

	health_fill_style = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	health_fill.add_theme_stylebox_override("panel", health_fill_style)


func _apply_vampire_percent_font() -> void:
	if health_percent_label == null:
		return

	if ResourceLoader.exists(VAMPIRE_FONT_PATH):
		var loaded_font: Resource = load(VAMPIRE_FONT_PATH)
		if loaded_font is Font:
			health_percent_label.add_theme_font_override("font", loaded_font as Font)

	health_percent_label.add_theme_font_size_override("font_size", HEALTH_PERCENT_FONT_SIZE)
	health_percent_label.add_theme_constant_override("outline_size", HEALTH_PERCENT_OUTLINE_SIZE)
	health_percent_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 0.98))
	health_percent_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))


func _update_health_bar() -> void:
	if health_fill == null:
		return

	var ratio: float = 0.0
	if max_hp > 0:
		ratio = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)

	health_fill.size.x = HEALTH_BAR_WIDTH * ratio
	if health_fill_style != null:
		if ratio > 0.55:
			health_fill_style.bg_color = Color(0.24, 0.86, 0.44, 0.95)
		elif ratio > 0.3:
			health_fill_style.bg_color = Color(0.94, 0.74, 0.23, 0.95)
		else:
			health_fill_style.bg_color = Color(0.9, 0.2, 0.22, 0.95)

	if health_percent_label != null:
		var percent_value: int = int(round(ratio * 100.0))
		health_percent_label.text = "%d%%" % percent_value


func _show_health_bar() -> void:
	health_bar_timer = health_bar_visible_time
	if health_bar != null:
		health_bar.visible = true


func _update_health_bar_timer() -> void:
	if health_bar == null or not health_bar.visible:
		return
	if health_bar_timer <= 0.0:
		health_bar.visible = false


func _create_hit_areas() -> void:
	contact_area = Area2D.new()
	contact_area.name = "ContactArea"
	contact_area.collision_layer = 0
	contact_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	contact_area.monitoring = true
	contact_area.monitorable = false
	add_child(contact_area)

	contact_collision = CollisionShape2D.new()
	contact_collision.name = "CollisionShape2D"
	var contact_shape := CircleShape2D.new()
	contact_shape.radius = CONTACT_RADIUS
	contact_collision.shape = contact_shape
	contact_area.add_child(contact_collision)

	attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	attack_area.collision_layer = 0
	attack_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	attack_area.monitoring = true
	attack_area.monitorable = false
	add_child(attack_area)

	attack_collision = CollisionShape2D.new()
	attack_collision.name = "CollisionShape2D"
	var attack_shape := CircleShape2D.new()
	attack_shape.radius = ATTACK_RADIUS
	attack_collision.shape = attack_shape
	attack_area.add_child(attack_collision)
	_update_attack_area_transform()


func _update_attack_area_transform() -> void:
	if attack_collision == null:
		return
	attack_collision.position = Vector2(ATTACK_AREA_OFFSET_X * float(facing_direction), ATTACK_AREA_OFFSET_Y)


func _configure_collision_filters() -> void:
	collision_layer = ENEMY_LAYER_MASK
	collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	if contact_area != null:
		contact_area.collision_layer = 0
		contact_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	if attack_area != null:
		attack_area.collision_layer = 0
		attack_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK


func _set_collision_enabled(enabled: bool) -> void:
	if body_collision != null:
		body_collision.disabled = not enabled
	if contact_collision != null:
		contact_collision.disabled = not enabled
	if attack_collision != null:
		attack_collision.disabled = not enabled
	if contact_area != null:
		contact_area.monitoring = enabled
	if attack_area != null:
		attack_area.monitoring = enabled


func _should_chase_player() -> bool:
	if player_ref == null:
		return false
	if global_position.distance_to(player_ref.global_position) > detection_radius:
		return false
	return absf(global_position.x - spawn_position.x) <= max_chase_distance


func _bind_player() -> void:
	if not player_path.is_empty():
		player_ref = get_node_or_null(player_path) as CharacterBody2D
	else:
		var parent_node: Node = get_parent()
		if parent_node != null:
			player_ref = parent_node.get_node_or_null("Player") as CharacterBody2D

	if player_ref == null:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0] as CharacterBody2D

	if player_ref == null:
		call_deferred("_retry_bind_player")


func _retry_bind_player() -> void:
	if player_ref != null:
		return

	var parent_node: Node = get_parent()
	if parent_node != null:
		player_ref = parent_node.get_node_or_null("Player") as CharacterBody2D
	if player_ref == null:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0] as CharacterBody2D


func _is_player_target(node: Node) -> bool:
	if node == null:
		return false
	if player_ref != null and node == player_ref:
		return true
	return node.is_in_group("player")


func _is_player_within_attack_fallback(player: CharacterBody2D) -> bool:
	if player == null:
		return false
	var delta_pos: Vector2 = player.global_position - global_position
	return absf(delta_pos.x) <= (attack_range + 8.0) and absf(delta_pos.y) <= (attack_height_tolerance + 12.0)


func _apply_hit_knockback(from_position: Vector2) -> void:
	if from_position == Vector2.INF:
		return

	var push_dir: float = 0.0
	if global_position.x > from_position.x:
		push_dir = 1.0
	elif global_position.x < from_position.x:
		push_dir = -1.0
	if is_zero_approx(push_dir):
		push_dir = float(facing_direction)
		if is_zero_approx(push_dir):
			push_dir = 1.0

	velocity.x = push_dir * HIT_KNOCKBACK_X * DAMAGE_KNOCKBACK_MULTIPLIER
	velocity.y = minf(velocity.y, HIT_KNOCKBACK_Y * DAMAGE_KNOCKBACK_MULTIPLIER)


func _setup_hurt_sfx() -> void:
	if hurt_sfx_player != null:
		return

	hurt_sfx_player = AudioStreamPlayer.new()
	hurt_sfx_player.name = "HurtSfx"
	hurt_sfx_player.bus = "SFX"
	hurt_sfx_player.volume_db = HURT_SFX_VOLUME_DB
	add_child(hurt_sfx_player)

	if ResourceLoader.exists(HURT_SFX_PATH):
		var loaded_stream: Resource = load(HURT_SFX_PATH)
		if loaded_stream is AudioStream:
			hurt_sfx_player.stream = loaded_stream


func _play_hurt_sfx() -> void:
	if hurt_sfx_player == null or hurt_sfx_player.stream == null:
		return
	hurt_sfx_player.stop()
	hurt_sfx_player.play()


func _has_floor_ahead(direction: int) -> bool:
	if direction == 0:
		return true

	var ray_start: Vector2 = global_position + Vector2(float(direction) * LEDGE_CHECK_FORWARD_DISTANCE, LEDGE_CHECK_DOWN_START_Y)
	var ray_end: Vector2 = ray_start + Vector2(0.0, LEDGE_CHECK_DOWN_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = GROUND_CHECK_COLLISION_MASK
	query.exclude = [get_rid()]

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()
