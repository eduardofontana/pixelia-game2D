extends "res://scripts/enemy_base.gd"

enum EnemyState {
	PATROL,
	CHASE,
	ATTACK_WINDUP
}

const MOVE_ACCELERATION: float = 820.0
const MOVE_DECELERATION: float = 1040.0
const MOVE_EPSILON: float = 3.0
const HEALTH_BAR_WIDTH: float = 28.0
const ATTACK_AREA_OFFSET_X: float = 12.0
const ATTACK_AREA_OFFSET_Y: float = 0.0
const HIT_KNOCKBACK_X: float = 96.0
const HIT_KNOCKBACK_Y: float = -78.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.45
const HOVER_WAVE_SPEED: float = 2.3
const HOVER_WAVE_AMPLITUDE: float = 8.0
const PATROL_REACHED_DISTANCE: float = 10.0
const VAMPIRE_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const HEALTH_PERCENT_FONT_SIZE: int = 11
const HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const HURT_SFX_PATH: String = "res://sounds/Injured.wav"
const HURT_SFX_VOLUME_DB: float = -8.0
const PLAYER_STRUCTURE_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const NON_PLAYER_COLLISION_REVERSE_COOLDOWN: float = 0.18
const DEATH_PARTICLE_COLOR: Color = Color(0.7, 0.85, 1.0, 1.0)
const DEATH_FADE_DURATION: float = 0.22
const DEATH_VFX = preload("res://scripts/death_vfx.gd")

@export var max_hp: int = 85
@export var patrol_distance_x: float = 96.0
@export var patrol_distance_y: float = 92.0
@export var patrol_speed: float = 42.0
@export var chase_speed: float = 52.0
@export var detection_radius: float = 136.0
@export var lose_interest_radius: float = 202.0
@export var max_chase_distance: float = 280.0
@export var attack_range: float = 24.0
@export var attack_damage: int = 6
@export var attack_windup_time: float = 0.26
@export var attack_cooldown: float = 1.15
@export var contact_damage: int = 5
@export var contact_damage_cooldown: float = 0.85
@export var sprite_faces_left: bool = true

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact_area: Area2D = $ContactArea
@onready var contact_collision: CollisionShape2D = $ContactArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

var enemy_state: int = EnemyState.PATROL
var spawn_position: Vector2 = Vector2.ZERO
var facing_direction: int = 1
var attack_cooldown_timer: float = 0.0
var attack_windup_timer: float = 0.0
var attack_did_hit: bool = false
var contact_damage_timer: float = 0.0
var hover_time: float = 0.0
var base_modulate_color: Color = Color(1, 1, 1, 1)
var patrol_target: Vector2 = Vector2.ZERO
var patrol_retarget_timer: float = 0.0
var non_player_reverse_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_configure_collision_filters()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	spawn_position = global_position
	current_hp = max_hp
	base_modulate_color = modulate
	hover_time = randf_range(0.0, 120.0)
	_bind_player()
	_update_attack_area_transform()
	_setup_health_fill_style()
	_apply_vampire_percent_font()
	_setup_hurt_sfx()
	_update_health_bar()
	_reset_patrol_target(true)
	_set_visual_alpha(1.0)
	_set_collision_enabled(true)
	if health_bar != null:
		health_bar.visible = false
	_play_animation(&"idle")


func _get_health_bar_width() -> float:
	return HEALTH_BAR_WIDTH


func _get_health_percent_font_size() -> int:
	return HEALTH_PERCENT_FONT_SIZE


func _get_health_percent_outline_size() -> int:
	return HEALTH_PERCENT_OUTLINE_SIZE


func _get_vampire_font_path() -> String:
	return VAMPIRE_FONT_PATH


func _get_hurt_sfx_path() -> String:
	return HURT_SFX_PATH


func _get_hurt_sfx_volume_db() -> float:
	return HURT_SFX_VOLUME_DB


func _get_max_hp_value() -> int:
	return max_hp


func _physics_process(delta: float) -> void:
	hover_time += delta
	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	contact_damage_timer = maxf(0.0, contact_damage_timer - delta)
	patrol_retarget_timer = maxf(0.0, patrol_retarget_timer - delta)
	non_player_reverse_timer = maxf(0.0, non_player_reverse_timer - delta)
	_update_health_bar_timer(delta)

	# State Machine central: processa apenas o estado ativo.
	match enemy_state:
		EnemyState.PATROL:
			_process_patrol(delta)
		EnemyState.CHASE:
			_process_chase(delta)
		EnemyState.ATTACK_WINDUP:
			_process_attack_windup(delta)

	move_and_slide()
	_resolve_non_player_collisions()
	_process_contact_damage()
	_update_visuals()


func _set_enemy_state(next_state: int) -> void:
	if enemy_state == next_state:
		return

	enemy_state = next_state
	if enemy_state == EnemyState.ATTACK_WINDUP:
		# Ao entrar no windup, reinicia o ataque de forma consistente.
		attack_windup_timer = attack_windup_time
		attack_did_hit = false


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
		_set_enemy_state(EnemyState.CHASE)
		return

	if patrol_retarget_timer <= 0.0 or global_position.distance_to(patrol_target) <= PATROL_REACHED_DISTANCE:
		_reset_patrol_target(false)

	var hover_offset: float = sin(hover_time * HOVER_WAVE_SPEED) * HOVER_WAVE_AMPLITUDE
	var target_position: Vector2 = patrol_target + Vector2(0.0, hover_offset)
	var to_target: Vector2 = target_position - global_position
	var target_velocity: Vector2 = Vector2.ZERO
	if to_target.length_squared() > 0.001:
		target_velocity = to_target.normalized() * patrol_speed
		if absf(target_velocity.x) > MOVE_EPSILON:
			facing_direction = 1 if target_velocity.x > 0.0 else -1

	velocity = velocity.move_toward(target_velocity, MOVE_ACCELERATION * delta)


func _process_chase(delta: float) -> void:
	if player_ref == null:
		_set_enemy_state(EnemyState.PATROL)
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	var distance_to_player: float = to_player.length()
	var distance_from_spawn: float = global_position.distance_to(spawn_position)

	if distance_to_player > lose_interest_radius or distance_from_spawn > max_chase_distance:
		_set_enemy_state(EnemyState.PATROL)
		_reset_patrol_target(true)
		return

	if absf(to_player.x) > 2.0:
		facing_direction = 1 if to_player.x > 0.0 else -1

	if distance_to_player > attack_range:
		var target_velocity: Vector2 = Vector2.ZERO
		if distance_to_player > 0.001:
			target_velocity = to_player.normalized() * chase_speed
		velocity = velocity.move_toward(target_velocity, MOVE_ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, MOVE_DECELERATION * delta)
		if attack_cooldown_timer <= 0.0:
			_set_enemy_state(EnemyState.ATTACK_WINDUP)


func _process_attack_windup(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, MOVE_DECELERATION * delta)

	if player_ref != null:
		var to_player_x: float = player_ref.global_position.x - global_position.x
		if absf(to_player_x) > 1.0:
			facing_direction = 1 if to_player_x > 0.0 else -1

	attack_windup_timer = maxf(0.0, attack_windup_timer - delta)
	if attack_windup_timer > 0.0:
		return

	if not attack_did_hit:
		_apply_attack_damage()
		attack_did_hit = true

	attack_cooldown_timer = attack_cooldown
	_set_enemy_state(EnemyState.CHASE)


func _apply_attack_damage() -> void:
	if attack_area == null:
		return

	for body in attack_area.get_overlapping_bodies():
		if _is_player_target(body) and body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)
			return

	if player_ref != null and player_ref.has_method("take_damage"):
		if global_position.distance_to(player_ref.global_position) <= (attack_range + 10.0):
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
		if global_position.distance_to(player_ref.global_position) <= (attack_range + 8.0):
			player_ref.take_damage(contact_damage, global_position)
			contact_damage_timer = contact_damage_cooldown


func _should_chase_player() -> bool:
	if player_ref == null:
		return false

	var distance_to_player: float = global_position.distance_to(player_ref.global_position)
	if distance_to_player > detection_radius:
		return false

	var distance_from_spawn: float = global_position.distance_to(spawn_position)
	return distance_from_spawn <= max_chase_distance


func _update_visuals() -> void:
	if animated_sprite == null:
		return

	animated_sprite.flip_h = facing_direction > 0 if sprite_faces_left else facing_direction < 0
	_update_attack_area_transform()
	_play_animation(&"idle")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _update_attack_area_transform() -> void:
	if attack_collision == null:
		return
	attack_collision.position = Vector2(ATTACK_AREA_OFFSET_X * float(facing_direction), ATTACK_AREA_OFFSET_Y)


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


func _set_visual_alpha(alpha: float) -> void:
	var next_color: Color = base_modulate_color
	next_color.a = clampf(alpha, 0.0, 1.0)
	modulate = next_color


func _set_collision_enabled(enabled: bool) -> void:
	if body_collision != null:
		body_collision.disabled = not enabled
	if contact_collision != null:
		contact_collision.disabled = not enabled
	if attack_collision != null:
		attack_collision.disabled = not enabled
	if attack_area != null:
		attack_area.monitoring = enabled
	if contact_area != null:
		contact_area.monitoring = enabled


func _configure_collision_filters() -> void:
	collision_layer = ENEMY_LAYER_MASK
	collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	if contact_area != null:
		contact_area.collision_layer = 0
		contact_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	if attack_area != null:
		attack_area.collision_layer = 0
		attack_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK


func _reset_patrol_target(immediate: bool) -> void:
	patrol_target = spawn_position + Vector2(
		randf_range(-patrol_distance_x, patrol_distance_x),
		randf_range(-patrol_distance_y, patrol_distance_y)
	)
	patrol_retarget_timer = randf_range(0.9, 2.0)
	if immediate:
		patrol_retarget_timer = 0.0


func _resolve_non_player_collisions() -> void:
	var hit_non_player: bool = false
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision == null:
			continue
		var collider: Node = collision.get_collider() as Node
		if collider == null:
			continue
		if collider == player_ref or collider.is_in_group("player"):
			continue
		hit_non_player = true
		break

	if not hit_non_player:
		return
	if non_player_reverse_timer > 0.0:
		return

	non_player_reverse_timer = NON_PLAYER_COLLISION_REVERSE_COOLDOWN
	facing_direction *= -1
	if enemy_state == EnemyState.PATROL:
		_reset_patrol_target(true)
	else:
		velocity.x *= -0.45



