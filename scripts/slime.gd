extends "res://scripts/enemy_base.gd"

enum EnemyState {
	PATROL,
	CHASE,
	ATTACK_WINDUP
}

const GROUND_ACCELERATION: float = 520.0
const GROUND_DECELERATION: float = 980.0
const MOVE_EPSILON: float = 2.5
const HEALTH_BAR_WIDTH: float = 28.0
const ATTACK_AREA_OFFSET_X: float = 12.0
const ATTACK_AREA_OFFSET_Y: float = 2.0
const HIT_KNOCKBACK_X: float = 74.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.45
const HEAD_BLOCK_X_RANGE: float = 11.0
const HEAD_BLOCK_MIN_Y_OFFSET: float = -24.0
const HEAD_BLOCK_MAX_Y_OFFSET: float = -10.0
const HEAD_BLOCK_PUSH_X: float = 70.0
const HEAD_BLOCK_COOLDOWN: float = 0.18
const HEAD_BLOCK_IGNORE_ASCENT_SPEED: float = -24.0
const VAMPIRE_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const HEALTH_PERCENT_FONT_SIZE: int = 11
const HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const HURT_SFX_PATH: String = "res://sounds/Gore_Wet_7.wav"
const HURT_SFX_VOLUME_DB: float = -7.5
const PLAYER_STRUCTURE_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const GROUND_CHECK_COLLISION_MASK: int = 1
const LEDGE_CHECK_FORWARD_DISTANCE: float = 14.0
const LEDGE_CHECK_DOWN_START_Y: float = 4.0
const LEDGE_CHECK_DOWN_DISTANCE: float = 56.0
const NON_PLAYER_COLLISION_TURN_COOLDOWN: float = 0.2
const HOLE_FALL_KILL_MARGIN_Y: float = 170.0
const DEATH_PARTICLE_COLOR: Color = Color(0.58, 0.96, 0.52, 1.0)
const DEATH_FADE_DURATION: float = 0.24
const DEATH_VFX = preload("res://scripts/death_vfx.gd")

@export var max_hp: int = 95
@export var patrol_distance: float = 54.0
@export var patrol_speed: float = 23.0
@export var chase_speed: float = 32.0
@export var patrol_turn_time_min: float = 0.9
@export var patrol_turn_time_max: float = 1.8
@export var sprite_faces_left: bool = true
@export var hits_to_trigger_idle: int = 3
@export var detection_radius: float = 110.0
@export var lose_interest_radius: float = 164.0
@export var max_chase_distance: float = 220.0
@export var attack_range: float = 18.0
@export var attack_damage: int = 7
@export var attack_windup_time: float = 0.24
@export var attack_cooldown: float = 0.95
@export var contact_damage: int = 7
@export var contact_damage_cooldown: float = 0.7
@export var third_hit_idle_cooldown: float = 1.15

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact_area: Area2D = $ContactArea
@onready var contact_collision: CollisionShape2D = $ContactArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

var enemy_state: int = EnemyState.PATROL
var spawn_position: Vector2 = Vector2.ZERO
var patrol_direction: int = 1
var facing_direction: int = 1
var attack_cooldown_timer: float = 0.0
var attack_windup_timer: float = 0.0
var attack_did_hit: bool = false
var contact_damage_timer: float = 0.0
var base_modulate_color: Color = Color(1, 1, 1, 1)
var patrol_turn_timer: float = 0.0
var hurt_idle_timer: float = 0.0
var hit_counter: int = 0
var idle_lock_x: float = 0.0
var head_block_timer: float = 0.0
var non_player_turn_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_configure_collision_filters()
	spawn_position = global_position
	health_bar_visible_time = 3.0
	current_hp = max_hp
	base_modulate_color = modulate
	_bind_player()
	_update_attack_area_transform()
	_setup_health_fill_style()
	_apply_vampire_percent_font()
	_setup_hurt_sfx()
	_update_health_bar()
	_reset_patrol_turn_timer()
	_set_visual_alpha(1.0)
	_set_collision_enabled(true)
	idle_lock_x = global_position.x
	if health_bar != null:
		health_bar.visible = false
	_play_idle_animation()


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
	if not is_on_floor():
		velocity += get_gravity() * delta

	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	contact_damage_timer = maxf(0.0, contact_damage_timer - delta)
	head_block_timer = maxf(0.0, head_block_timer - delta)
	patrol_turn_timer = maxf(0.0, patrol_turn_timer - delta)
	hurt_idle_timer = maxf(0.0, hurt_idle_timer - delta)
	non_player_turn_timer = maxf(0.0, non_player_turn_timer - delta)
	_update_health_bar_timer(delta)

	if global_position.y > (spawn_position.y + HOLE_FALL_KILL_MARGIN_Y):
		_handle_death()
		return

	# State Machine central: processa apenas o estado ativo.
	match enemy_state:
		EnemyState.PATROL:
			_process_patrol(delta)
		EnemyState.CHASE:
			_process_chase(delta)
		EnemyState.ATTACK_WINDUP:
			_process_attack_windup(delta)

	_stop_before_ledge()
	move_and_slide()
	_resolve_non_player_collisions()
	if hurt_idle_timer > 0.0:
		global_position.x = idle_lock_x
		velocity.x = 0.0

	_process_contact_damage()
	_process_head_block_player()
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
	if hurt_idle_timer > 0.0:
		# Durante o cooldown do 3o hit, ignora dano para manter o idle "travado".
		return

	current_hp = maxi(0, current_hp - amount)
	_play_hurt_sfx()
	hit_counter += 1
	var idle_hit_target: int = maxi(1, hits_to_trigger_idle)
	var should_enter_idle: bool = hit_counter >= idle_hit_target
	if should_enter_idle:
		hit_counter = 0
		# 3o hit: entra em idle temporario e trava a posicao para nao "escorregar".
		hurt_idle_timer = maxf(third_hit_idle_cooldown, 0.0)
		_set_enemy_state(EnemyState.PATROL)
		patrol_turn_timer = 0.0
		idle_lock_x = global_position.x
		velocity = Vector2.ZERO
	else:
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
	var death_tween: Tween = DEATH_VFX.play_fade_and_burst(self, fade_target, global_position, DEATH_PARTICLE_COLOR, 14, DEATH_FADE_DURATION)
	if death_tween != null:
		death_tween.finished.connect(Callable(self, "queue_free"))
	else:
		queue_free()


func _process_patrol(delta: float) -> void:
	if hurt_idle_timer > 0.0:
		velocity = Vector2.ZERO
		global_position.x = idle_lock_x
		return

	if _should_chase_player():
		_set_enemy_state(EnemyState.CHASE)
		return

	if patrol_turn_timer <= 0.0:
		if randf() < 0.35:
			patrol_direction *= -1
		_reset_patrol_turn_timer()

	var left_limit: float = spawn_position.x - patrol_distance
	var right_limit: float = spawn_position.x + patrol_distance
	if global_position.x <= left_limit:
		patrol_direction = 1
		_reset_patrol_turn_timer()
	elif global_position.x >= right_limit:
		patrol_direction = -1
		_reset_patrol_turn_timer()
	elif is_on_floor() and not _has_floor_ahead(patrol_direction):
		patrol_direction *= -1
		_reset_patrol_turn_timer()

	var target_speed: float = float(patrol_direction) * patrol_speed
	velocity.x = move_toward(velocity.x, target_speed, GROUND_ACCELERATION * delta)
	facing_direction = patrol_direction


func _process_chase(delta: float) -> void:
	if player_ref == null:
		_set_enemy_state(EnemyState.PATROL)
		_reset_patrol_turn_timer()
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	var distance_to_player: float = to_player.length()
	var distance_from_spawn: float = absf(global_position.x - spawn_position.x)

	if distance_to_player > lose_interest_radius or distance_from_spawn > max_chase_distance:
		_set_enemy_state(EnemyState.PATROL)
		_reset_patrol_turn_timer()
		return

	var horizontal_delta: float = to_player.x
	if absf(horizontal_delta) > attack_range:
		var chase_direction: int = 1 if horizontal_delta > 0.0 else -1
		facing_direction = chase_direction
		if is_on_floor() and not _has_floor_ahead(chase_direction):
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
			return
		var target_speed: float = float(chase_direction) * chase_speed
		velocity.x = move_toward(velocity.x, target_speed, GROUND_ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
		if attack_cooldown_timer <= 0.0:
			_set_enemy_state(EnemyState.ATTACK_WINDUP)


func _process_attack_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)

	if player_ref != null:
		var horizontal_delta: float = player_ref.global_position.x - global_position.x
		if absf(horizontal_delta) > 0.2:
			facing_direction = 1 if horizontal_delta > 0.0 else -1

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
		if global_position.distance_to(player_ref.global_position) <= (attack_range + 8.0):
			player_ref.take_damage(attack_damage, global_position)


func _process_contact_damage() -> void:
	if hurt_idle_timer > 0.0:
		return
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
		if global_position.distance_to(player_ref.global_position) <= (attack_range + 6.0):
			player_ref.take_damage(contact_damage, global_position)
			contact_damage_timer = contact_damage_cooldown


func _process_head_block_player() -> void:
	if player_ref == null:
		return
	if head_block_timer > 0.0:
		return
	if player_ref.velocity.y < HEAD_BLOCK_IGNORE_ASCENT_SPEED:
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	var within_x: bool = absf(to_player.x) <= HEAD_BLOCK_X_RANGE
	var within_y: bool = to_player.y >= HEAD_BLOCK_MIN_Y_OFFSET and to_player.y <= HEAD_BLOCK_MAX_Y_OFFSET
	if not within_x or not within_y:
		return

	var repel_dir: float = 1.0
	if to_player.x < 0.0:
		repel_dir = -1.0
	elif is_zero_approx(to_player.x):
		repel_dir = float(facing_direction)
		if is_zero_approx(repel_dir):
			repel_dir = 1.0

	var next_velocity: Vector2 = player_ref.velocity
	next_velocity.x = repel_dir * HEAD_BLOCK_PUSH_X
	player_ref.velocity = next_velocity
	head_block_timer = HEAD_BLOCK_COOLDOWN


func _should_chase_player() -> bool:
	if player_ref == null:
		return false

	var distance_to_player: float = global_position.distance_to(player_ref.global_position)
	if distance_to_player > detection_radius:
		return false

	var distance_from_spawn: float = absf(global_position.x - spawn_position.x)
	return distance_from_spawn <= max_chase_distance


func _update_visuals() -> void:
	if animated_sprite == null:
		return

	animated_sprite.flip_h = facing_direction > 0 if sprite_faces_left else facing_direction < 0
	_update_attack_area_transform()

	if hurt_idle_timer > 0.0:
		_play_idle_animation()
		return

	if absf(velocity.x) > MOVE_EPSILON:
		_play_move_animation()
	else:
		_play_idle_animation()


func _play_idle_animation() -> void:
	_play_animation(&"idle")


func _play_move_animation() -> void:
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"move"):
		_play_animation(&"move")
	else:
		_play_animation(&"walk")


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
	# Slime permanece no chao; evita impulso vertical em knockback.
	velocity.y = maxf(velocity.y, 0.0)


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


func _reset_patrol_turn_timer() -> void:
	var min_turn_time: float = maxf(0.2, patrol_turn_time_min)
	var max_turn_time: float = maxf(min_turn_time, patrol_turn_time_max)
	patrol_turn_timer = randf_range(min_turn_time, max_turn_time)


func _stop_before_ledge() -> void:
	if hurt_idle_timer > 0.0:
		return
	if not is_on_floor():
		return
	if absf(velocity.x) <= MOVE_EPSILON:
		return

	var move_direction: int = 1 if velocity.x > 0.0 else -1
	if _has_floor_ahead(move_direction):
		return

	velocity.x = 0.0
	if enemy_state == EnemyState.PATROL:
		patrol_direction *= -1
		facing_direction = patrol_direction
		_reset_patrol_turn_timer()


func _resolve_non_player_collisions() -> void:
	var should_turn: bool = false
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision == null:
			continue

		var collider: Node = collision.get_collider() as Node
		if collider == null:
			continue
		if collider == player_ref or collider.is_in_group("player"):
			continue
		if collision.get_normal().y <= -0.65:
			continue

		velocity.x = 0.0
		velocity.y = maxf(velocity.y, 0.0)
		should_turn = true

	if should_turn and non_player_turn_timer <= 0.0:
		non_player_turn_timer = NON_PLAYER_COLLISION_TURN_COOLDOWN
		if enemy_state == EnemyState.PATROL:
			patrol_direction *= -1
			facing_direction = patrol_direction
			_reset_patrol_turn_timer()
		elif enemy_state == EnemyState.CHASE:
			facing_direction *= -1


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
