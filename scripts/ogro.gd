extends CharacterBody2D

enum EnemyState {
	PATROL,
	CHASE,
	ATTACK
}

const PLAYER_STRUCTURE_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const ATTACK_AREA_OFFSET_X: float = 26.0
const ATTACK_AREA_OFFSET_Y: float = -4.0
const CONTACT_RADIUS: float = 22.0
const ATTACK_RADIUS: float = 30.0
const HEALTH_BAR_WIDTH: float = 28.0
const HEALTH_PERCENT_FONT_SIZE: int = 10
const HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const VAMPIRE_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const DEATH_SQUASH_TIME: float = 0.1
const DEATH_STRETCH_TIME: float = 0.12
const DEATH_RISE_Y: float = -8.0
const HIT_KNOCKBACK_X: float = 110.0
const HIT_KNOCKBACK_Y: float = -95.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.25
const HURT_SFX_PATH: String = "res://sounds/Zombie.wav"
const HURT_SFX_VOLUME_DB: float = -6.0
const DEATH_PARTICLE_COLOR: Color = Color(0.62, 0.86, 0.52, 1.0)
const DEATH_FADE_DURATION: float = 0.24
const DEATH_VFX = preload("res://scripts/death_vfx.gd")

@export var player_path: NodePath
@export var max_hp: int = 140
@export var patrol_distance_x: float = 140.0
@export var patrol_speed: float = 36.0
@export var chase_speed: float = 54.0
@export var detection_radius: float = 210.0
@export var lose_interest_radius: float = 300.0
@export var max_chase_distance: float = 360.0
@export var attack_range: float = 42.0
@export var attack_height_tolerance: float = 38.0
@export var attack_damage: int = 12
@export var attack_windup_time: float = 0.45
@export var attack_cooldown: float = 1.2
@export var contact_damage: int = 8
@export var contact_damage_cooldown: float = 0.9
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
var attack_windup_timer: float = 0.0
var contact_damage_timer: float = 0.0
var attack_hit_applied: bool = false
var attack_animation_finished: bool = false
var is_dying: bool = false
var health_bar_timer: float = 0.0
var health_fill_style: StyleBoxFlat = null
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
	if animated_sprite != null and not animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
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
	_update_health_bar_timer(delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)

	match enemy_state:
		EnemyState.PATROL:
			_process_patrol(delta)
		EnemyState.CHASE:
			_process_chase(delta)
		EnemyState.ATTACK:
			_process_attack(delta)

	move_and_slide()
	_process_contact_damage()
	_update_visuals()


func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	if is_dying:
		return
	if amount <= 0:
		return

	current_hp = maxi(0, current_hp - amount)
	_play_hurt_sfx()
	_apply_hit_knockback(from_position)
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
	_play_death_animation_then_fade()


func _process_patrol(delta: float) -> void:
	if _should_chase_player():
		_set_enemy_state(EnemyState.CHASE)
		return

	var left_bound: float = spawn_position.x - patrol_distance_x
	var right_bound: float = spawn_position.x + patrol_distance_x
	if global_position.x <= left_bound:
		patrol_direction = 1
	elif global_position.x >= right_bound:
		patrol_direction = -1

	var target_velocity_x: float = patrol_speed * float(patrol_direction)
	velocity.x = move_toward(velocity.x, target_velocity_x, 780.0 * delta)
	if absf(velocity.x) > 1.0:
		facing_direction = 1 if velocity.x > 0.0 else -1


func _process_chase(delta: float) -> void:
	if player_ref == null:
		_set_enemy_state(EnemyState.PATROL)
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	var distance_to_player: float = to_player.length()
	var distance_from_spawn: float = global_position.distance_to(spawn_position)
	if distance_to_player > lose_interest_radius or distance_from_spawn > max_chase_distance:
		_set_enemy_state(EnemyState.PATROL)
		return

	if absf(to_player.x) > 1.0:
		facing_direction = 1 if to_player.x > 0.0 else -1

	var can_attack: bool = absf(to_player.x) <= attack_range \
		and absf(to_player.y) <= attack_height_tolerance \
		and attack_cooldown_timer <= 0.0
	if can_attack:
		_set_enemy_state(EnemyState.ATTACK)
		return

	var target_velocity_x: float = 0.0
	if absf(to_player.x) > 2.0:
		target_velocity_x = chase_speed * sign(to_player.x)
	velocity.x = move_toward(velocity.x, target_velocity_x, 920.0 * delta)


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)

	if player_ref != null:
		var to_player_x: float = player_ref.global_position.x - global_position.x
		if absf(to_player_x) > 1.0:
			facing_direction = 1 if to_player_x > 0.0 else -1

	attack_windup_timer = maxf(0.0, attack_windup_timer - delta)
	if not attack_hit_applied and attack_windup_timer <= attack_windup_time * 0.45:
		_apply_attack_damage()
		attack_hit_applied = true

	if not attack_animation_finished:
		return

	if not attack_hit_applied:
		_apply_attack_damage()
		attack_hit_applied = true

	attack_cooldown_timer = attack_cooldown
	_set_enemy_state(EnemyState.CHASE)


func _set_enemy_state(next_state: int) -> void:
	if enemy_state == next_state:
		return
	enemy_state = next_state

	if enemy_state == EnemyState.ATTACK:
		attack_windup_timer = attack_windup_time
		attack_hit_applied = false
		attack_animation_finished = false
		if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"attack"):
			animated_sprite.play(&"attack")
			animated_sprite.frame = 0
			animated_sprite.frame_progress = 0.0


func _update_visuals() -> void:
	if animated_sprite == null:
		return

	animated_sprite.flip_h = facing_direction > 0 if sprite_faces_left else facing_direction < 0
	_update_attack_area_transform()

	match enemy_state:
		EnemyState.ATTACK:
			_play_animation(&"attack")
		EnemyState.CHASE:
			_play_animation(&"walk")
		EnemyState.PATROL:
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


func _update_health_bar_timer(delta: float) -> void:
	if health_bar == null or not health_bar.visible:
		return
	health_bar_timer = maxf(0.0, health_bar_timer - delta)
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
	if contact_area == null:
		return
	if contact_damage_timer > 0.0:
		return

	for body in contact_area.get_overlapping_bodies():
		if _is_player_target(body) and body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)
			contact_damage_timer = contact_damage_cooldown
			return

	if player_ref != null and player_ref.has_method("take_damage"):
		var fallback_distance: float = attack_range + 10.0
		if global_position.distance_to(player_ref.global_position) <= fallback_distance:
			player_ref.take_damage(contact_damage, global_position)
			contact_damage_timer = contact_damage_cooldown


func _is_player_within_attack_fallback(player: CharacterBody2D) -> bool:
	if player == null:
		return false
	var delta_pos: Vector2 = player.global_position - global_position
	return absf(delta_pos.x) <= (attack_range + 8.0) and absf(delta_pos.y) <= (attack_height_tolerance + 12.0)


func _should_chase_player() -> bool:
	if player_ref == null:
		return false
	if global_position.distance_to(player_ref.global_position) > detection_radius:
		return false
	return global_position.distance_to(spawn_position) <= max_chase_distance


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


func _on_animated_sprite_animation_finished() -> void:
	if enemy_state != EnemyState.ATTACK:
		return
	if animated_sprite == null:
		return
	if animated_sprite.animation != &"attack":
		return
	attack_animation_finished = true


func _play_death_animation_then_fade() -> void:
	if animated_sprite == null:
		_play_death_fade_and_burst()
		return

	var base_scale: Vector2 = animated_sprite.scale
	var base_position: Vector2 = animated_sprite.position
	var squash_scale: Vector2 = Vector2(base_scale.x * 1.18, base_scale.y * 0.82)
	var stretch_scale: Vector2 = Vector2(base_scale.x * 0.86, base_scale.y * 1.2)
	var lean_degrees: float = 8.0 * float(facing_direction)

	var pre_death_tween: Tween = create_tween()
	pre_death_tween.set_trans(Tween.TRANS_QUAD)
	pre_death_tween.set_ease(Tween.EASE_OUT)
	pre_death_tween.tween_property(animated_sprite, "scale", squash_scale, DEATH_SQUASH_TIME)
	pre_death_tween.parallel().tween_property(animated_sprite, "rotation_degrees", lean_degrees, DEATH_SQUASH_TIME)
	pre_death_tween.tween_property(animated_sprite, "scale", stretch_scale, DEATH_STRETCH_TIME)
	pre_death_tween.parallel().tween_property(animated_sprite, "position", base_position + Vector2(0.0, DEATH_RISE_Y), DEATH_STRETCH_TIME)
	pre_death_tween.tween_callback(Callable(self, "_play_death_fade_and_burst"))


func _play_death_fade_and_burst() -> void:
	var fade_target: CanvasItem = animated_sprite
	if fade_target == null:
		fade_target = self
	var death_tween: Tween = DEATH_VFX.play_fade_and_burst(self, fade_target, global_position, DEATH_PARTICLE_COLOR, 14, DEATH_FADE_DURATION)
	if death_tween != null:
		death_tween.finished.connect(Callable(self, "queue_free"))
	else:
		queue_free()


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
