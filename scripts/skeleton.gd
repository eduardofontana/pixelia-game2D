extends CharacterBody2D

enum EnemyState {
	PATROL,
	CHASE,
	ATTACK_WINDUP
}

const GROUND_ACCELERATION: float = 700.0
const GROUND_DECELERATION: float = 1200.0
const MOVE_EPSILON: float = 4.0
const HEALTH_BAR_WIDTH: float = 28.0
const ATTACK_AREA_OFFSET_X: float = 14.0
const ATTACK_AREA_OFFSET_Y: float = 1.0
const HIT_KNOCKBACK_X: float = 82.0
const HIT_KNOCKBACK_Y: float = -56.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.45
const HURT_SFX_PATH: String = "res://sounds/Zombie.wav"
const HURT_SFX_VOLUME_DB: float = -6.0
const DEATH_SFX_PATH: String = "res://sounds/Zombie_8.wav"
const DEATH_SFX_VOLUME_DB: float = -5.0
const JUMP_FORWARD_BOOST: float = 18.0
const HEAD_BLOCK_X_RANGE: float = 11.5
const HEAD_BLOCK_MIN_Y_OFFSET: float = -28.0
const HEAD_BLOCK_MAX_Y_OFFSET: float = -15.0
const HEAD_BLOCK_PUSH_X: float = 82.0
const HEAD_BLOCK_COOLDOWN: float = 0.16
const HEAD_BLOCK_IGNORE_ASCENT_SPEED: float = -24.0
const FACING_FLIP_DEADZONE_X: float = 6.0
const FACING_FLIP_COOLDOWN: float = 0.12
const VAMPIRE_FONT_PATH: String = "res://fonts/Buffied-GlqZ.ttf"
const HEALTH_PERCENT_FONT_SIZE: int = 11
const HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const PLAYER_STRUCTURE_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const GROUND_CHECK_COLLISION_MASK: int = 1
const LEDGE_CHECK_FORWARD_DISTANCE: float = 16.0
const LEDGE_CHECK_DOWN_START_Y: float = 4.0
const LEDGE_CHECK_DOWN_DISTANCE: float = 58.0
const WALL_CHECK_FORWARD_DISTANCE: float = 16.0
const NON_PLAYER_COLLISION_TURN_COOLDOWN: float = 0.2
const HOLE_FALL_KILL_MARGIN_Y: float = 210.0

@export var player_path: NodePath
@export var max_hp: int = 120
@export var patrol_distance: float = 44.0
@export var patrol_speed: float = 32.0
@export var chase_speed: float = 48.0
@export var detection_radius: float = 118.0
@export var lose_interest_radius: float = 164.0
@export var max_chase_distance: float = 210.0
@export var attack_range: float = 24.0
@export var attack_damage: int = 10
@export var attack_windup_time: float = 0.22
@export var attack_cooldown: float = 0.9
@export var jump_velocity: float = -225.0
@export var jump_cooldown_min: float = 1.0
@export var jump_cooldown_max: float = 2.2
@export var jump_chance_patrol: float = 0.14
@export var jump_chance_chase: float = 0.38
@export var contact_damage: int = 10
@export var contact_damage_cooldown: float = 0.55
@export var health_bar_visible_time: float = 3.2

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact_area: Area2D = $ContactArea
@onready var contact_collision: CollisionShape2D = $ContactArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var health_bar: Node2D = $HealthBar
@onready var health_fill: Control = $HealthBar/Bg/Fill
@onready var health_percent_label: Label = $HealthBar/PercentLabel

var player_ref: CharacterBody2D = null
var enemy_state: int = EnemyState.PATROL
var spawn_position: Vector2
var patrol_direction: int = 1
var facing_direction: int = 1
var current_hp: int = 1
var attack_cooldown_timer: float = 0.0
var attack_windup_timer: float = 0.0
var health_bar_timer: float = 0.0
var attack_did_hit: bool = false
var contact_damage_timer: float = 0.0
var base_modulate_color: Color = Color(1, 1, 1, 1)
var hurt_sfx_player: AudioStreamPlayer = null
var death_sfx_player: AudioStreamPlayer = null
var jump_decision_timer: float = 0.0
var head_block_timer: float = 0.0
var health_fill_style: StyleBoxFlat = null
var facing_flip_timer: float = 0.0
var non_player_turn_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_configure_collision_filters()
	spawn_position = global_position
	current_hp = max_hp
	base_modulate_color = modulate
	_setup_hurt_sfx()
	_setup_death_sfx()
	_bind_player()
	_update_attack_area_transform()
	_setup_health_fill_style()
	_apply_vampire_percent_font()
	_update_health_bar()
	_reset_jump_timer()
	_set_visual_alpha(1.0)
	_set_collision_enabled(true)
	if health_bar != null:
		health_bar.visible = false
	_play_animation(&"idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	contact_damage_timer = maxf(0.0, contact_damage_timer - delta)
	head_block_timer = maxf(0.0, head_block_timer - delta)
	facing_flip_timer = maxf(0.0, facing_flip_timer - delta)
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

	_process_jump_behavior(delta)
	_stop_before_ledge()
	move_and_slide()
	_resolve_non_player_collisions()
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
	_play_death_sfx()
	queue_free()


func _process_patrol(delta: float) -> void:
	if _should_chase_player():
		_set_enemy_state(EnemyState.CHASE)
		return

	var left_limit: float = spawn_position.x - patrol_distance
	var right_limit: float = spawn_position.x + patrol_distance

	if global_position.x <= left_limit:
		patrol_direction = 1
	elif global_position.x >= right_limit:
		patrol_direction = -1
	elif is_on_floor() and not _has_floor_ahead(patrol_direction):
		patrol_direction *= -1

	var target_speed: float = float(patrol_direction) * patrol_speed
	velocity.x = move_toward(velocity.x, target_speed, GROUND_ACCELERATION * delta)
	facing_direction = patrol_direction


func _process_chase(delta: float) -> void:
	if player_ref == null:
		_set_enemy_state(EnemyState.PATROL)
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	var distance_to_player: float = to_player.length()
	var distance_from_spawn: float = absf(global_position.x - spawn_position.x)

	if distance_to_player > lose_interest_radius or distance_from_spawn > max_chase_distance:
		_set_enemy_state(EnemyState.PATROL)
		return

	var horizontal_delta: float = to_player.x
	if absf(horizontal_delta) > attack_range:
		_update_facing_from_delta(horizontal_delta)
		if is_on_floor() and not _has_floor_ahead(facing_direction):
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
			return
		var target_speed: float = float(facing_direction) * chase_speed
		velocity.x = move_toward(velocity.x, target_speed, GROUND_ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
		if attack_cooldown_timer <= 0.0:
			_set_enemy_state(EnemyState.ATTACK_WINDUP)


func _process_attack_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)

	if player_ref != null:
		var horizontal_delta: float = player_ref.global_position.x - global_position.x
		_update_facing_from_delta(horizontal_delta)

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


func _process_jump_behavior(delta: float) -> void:
	jump_decision_timer = maxf(0.0, jump_decision_timer - delta)
	if jump_decision_timer > 0.0:
		return

	_reset_jump_timer()
	if not is_on_floor():
		return
	if _is_non_player_blocking_ahead(facing_direction):
		return

	var jump_chance: float = 0.0
	match enemy_state:
		EnemyState.PATROL:
			jump_chance = jump_chance_patrol
		EnemyState.CHASE:
			jump_chance = jump_chance_chase
		_:
			return

	if randf() > clampf(jump_chance, 0.0, 1.0):
		return
	if not _has_floor_ahead(facing_direction):
		return

	velocity.y = jump_velocity
	velocity.x += float(facing_direction) * JUMP_FORWARD_BOOST


func _reset_jump_timer() -> void:
	var min_cooldown: float = maxf(0.2, jump_cooldown_min)
	var max_cooldown: float = maxf(min_cooldown, jump_cooldown_max)
	jump_decision_timer = randf_range(min_cooldown, max_cooldown)


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

	animated_sprite.flip_h = facing_direction < 0
	_update_attack_area_transform()

	if absf(velocity.x) > MOVE_EPSILON:
		_play_animation(&"walk")
	else:
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


func _update_health_bar() -> void:
	if health_fill == null:
		return

	var ratio: float = 0.0
	if max_hp > 0:
		ratio = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)

	health_fill.size.x = HEALTH_BAR_WIDTH * ratio
	if ratio > 0.55:
		if health_fill_style != null:
			health_fill_style.bg_color = Color(0.24, 0.86, 0.44, 0.95)
	elif ratio > 0.3:
		if health_fill_style != null:
			health_fill_style.bg_color = Color(0.94, 0.74, 0.23, 0.95)
	else:
		if health_fill_style != null:
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


func _bind_player() -> void:
	if not player_path.is_empty():
		player_ref = get_node_or_null(player_path) as CharacterBody2D
	else:
		var parent_node: Node = get_parent()
		if parent_node != null:
			player_ref = parent_node.get_node_or_null("Player") as CharacterBody2D
	if player_ref == null:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
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
		if players.size() > 0:
			player_ref = players[0] as CharacterBody2D


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


func _setup_hurt_sfx() -> void:
	if hurt_sfx_player != null:
		return

	hurt_sfx_player = AudioStreamPlayer.new()
	hurt_sfx_player.name = "HurtSfx"
	hurt_sfx_player.bus = "Master"
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


func _setup_death_sfx() -> void:
	if death_sfx_player != null:
		return

	death_sfx_player = AudioStreamPlayer.new()
	death_sfx_player.name = "DeathSfx"
	death_sfx_player.bus = "Master"
	death_sfx_player.volume_db = DEATH_SFX_VOLUME_DB
	add_child(death_sfx_player)

	if ResourceLoader.exists(DEATH_SFX_PATH):
		var loaded_stream: Resource = load(DEATH_SFX_PATH)
		if loaded_stream is AudioStream:
			death_sfx_player.stream = loaded_stream


func _play_death_sfx() -> void:
	if death_sfx_player == null or death_sfx_player.stream == null:
		return
	death_sfx_player.stop()
	death_sfx_player.play()


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


func _is_player_target(node: Node) -> bool:
	if node == null:
		return false
	if player_ref != null and node == player_ref:
		return true
	return node.is_in_group("player")


func _update_facing_from_delta(horizontal_delta: float) -> void:
	if absf(horizontal_delta) < FACING_FLIP_DEADZONE_X:
		return

	var target_direction: int = 1 if horizontal_delta > 0.0 else -1
	if target_direction == facing_direction:
		return
	if facing_flip_timer > 0.0:
		return

	facing_direction = target_direction
	facing_flip_timer = FACING_FLIP_COOLDOWN


func _stop_before_ledge() -> void:
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


func _is_non_player_blocking_ahead(direction: int) -> bool:
	if direction == 0:
		return false

	var ray_start: Vector2 = global_position + Vector2(0.0, -6.0)
	var ray_end: Vector2 = ray_start + Vector2(float(direction) * WALL_CHECK_FORWARD_DISTANCE, 0.0)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = GROUND_CHECK_COLLISION_MASK
	query.exclude = [get_rid()]

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.has("collider"):
		return false
	var collider: Node = hit["collider"] as Node
	if collider == null:
		return false
	return not (collider == player_ref or collider.is_in_group("player"))
