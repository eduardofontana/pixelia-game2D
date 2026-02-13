extends CharacterBody2D

signal defeated
signal health_changed(current_hp: int, max_hp_value: int)

enum BossState {
	IDLE,
	ATTACK,
	HIT,
	DEATH
}

const MOVE_ACCELERATION: float = 780.0
const MOVE_DECELERATION: float = 980.0
const MOVE_EPSILON: float = 2.0
const HOVER_WAVE_SPEED: float = 2.1
const HOVER_WAVE_AMPLITUDE: float = 10.0
const HIT_KNOCKBACK_X: float = 84.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.45
const ATTACK_DAMAGE_RANGE_BONUS: float = 24.0
const PATROL_RETARGET_MIN_TIME: float = 0.9
const PATROL_RETARGET_MAX_TIME: float = 2.2
const PLAYER_STRUCTURE_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const INJURED_SFX_VOLUME_DB: float = -1.5
const ALIVE_LOOP_SFX_VOLUME_DB: float = -6.5
const DEATH_SFX_VOLUME_DB: float = -2.0
const INJURED_SFX_STREAM: AudioStream = preload("res://sounds/Injured.wav")
const ALIVE_LOOP_SFX_STREAM: AudioStream = preload("res://sounds/boss_music.wav")
const DEATH_SFX_STREAM: AudioStream = preload("res://sounds/boss_death.wav")

@export var player_path: NodePath
@export var max_hp: int = 320
@export var patrol_distance_x: float = 110.0
@export var patrol_distance_y: float = 70.0
@export var patrol_speed: float = 34.0
@export var chase_speed: float = 44.0
@export var detection_radius: float = 220.0
@export var attack_range: float = 54.0
@export var attack_damage: int = 16
@export var attack_windup_time: float = 0.72
@export var attack_cooldown: float = 1.4
@export var attack_hit_frame: int = 3
@export var attack_commit_time: float = 0.34
@export var miss_cooldown_penalty: float = 0.35
@export var hit_recover_time: float = 0.28
@export var touch_damage: int = 8
@export var touch_damage_interval: float = 0.45
@export var rage_hp_ratio: float = 0.45
@export var rage_speed_multiplier: float = 1.28
@export var rage_attack_bonus: int = 5
@export var strafe_strength: float = 0.45
@export var strafe_jitter_time_min: float = 0.35
@export var strafe_jitter_time_max: float = 1.0
@export var attack_range_jitter: float = 14.0
@export var dash_speed_multiplier: float = 1.55
@export var dash_duration_min: float = 0.2
@export var dash_duration_max: float = 0.42
@export var dash_cooldown_min: float = 1.6
@export var dash_cooldown_max: float = 3.1

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = get_node_or_null("DamageArea") as Area2D
@onready var damage_area_collision: CollisionShape2D = get_node_or_null("DamageArea/CollisionShape2D") as CollisionShape2D

var player_ref: CharacterBody2D = null
var boss_state: int = BossState.IDLE
var spawn_position: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
var patrol_retarget_timer: float = 0.0
var facing_direction: int = 1
var current_hp: int = 1
var hover_time: float = 0.0
var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var attack_commit_timer: float = 0.0
var hit_timer: float = 0.0
var attack_did_hit: bool = false
var current_attack_trigger_range: float = 0.0
var strafe_direction: int = 1
var strafe_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_active_boss: bool = true
var death_signal_emitted: bool = false
var touch_damage_timer: float = 0.0
var injured_sfx_player: AudioStreamPlayer = null
var alive_loop_sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	_configure_collision_filters()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	spawn_position = global_position
	current_hp = max_hp
	_bind_player()
	_configure_damage_area()
	_setup_audio_players()
	_configure_animations()
	_reset_patrol_target(true)
	current_attack_trigger_range = attack_range
	_reroll_attack_profile()
	_reset_dash_cooldown()
	_play_animation(&"idle")
	_emit_health_changed()
	_update_alive_loop_for_state()


func _physics_process(delta: float) -> void:
	if not is_active_boss:
		velocity = Vector2.ZERO
		return

	hover_time += delta
	patrol_retarget_timer = maxf(0.0, patrol_retarget_timer - delta)
	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	attack_commit_timer = maxf(0.0, attack_commit_timer - delta)
	touch_damage_timer = maxf(0.0, touch_damage_timer - delta)
	strafe_timer = maxf(0.0, strafe_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)

	match boss_state:
		BossState.IDLE:
			_process_idle(delta)
		BossState.ATTACK:
			_process_attack(delta)
		BossState.HIT:
			_process_hit(delta)
		BossState.DEATH:
			velocity = velocity.move_toward(Vector2.ZERO, MOVE_DECELERATION * delta)

	move_and_slide()
	_try_touch_damage_player()
	_update_visuals()


func set_boss_active(enabled: bool) -> void:
	is_active_boss = enabled
	visible = enabled
	set_physics_process(enabled)
	if body_collision != null:
		body_collision.set_deferred("disabled", not enabled)
	_sync_damage_area_state(enabled)
	if not enabled:
		velocity = Vector2.ZERO
		boss_state = BossState.IDLE
		_play_animation(&"idle")
		touch_damage_timer = 0.0
		attack_cooldown_timer = 0.0
		attack_commit_timer = 0.0
		dash_timer = 0.0
		dash_cooldown_timer = 0.0
		strafe_timer = 0.0
	else:
		_reroll_attack_profile()
		_reset_dash_cooldown()
	_emit_health_changed()
	_update_alive_loop_for_state()


func reset_for_battle() -> void:
	current_hp = max_hp
	death_signal_emitted = false
	boss_state = BossState.IDLE
	global_position = spawn_position
	velocity = Vector2.ZERO
	attack_timer = 0.0
	attack_cooldown_timer = 0.0
	attack_commit_timer = 0.0
	hit_timer = 0.0
	attack_did_hit = false
	touch_damage_timer = 0.0
	_reset_patrol_target(true)
	_reroll_attack_profile()
	_reset_dash_cooldown()
	set_boss_active(false)


func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	if not is_active_boss:
		return
	if amount <= 0 or boss_state == BossState.DEATH:
		return

	current_hp = maxi(0, current_hp - amount)
	_play_injured_sfx()
	_apply_hit_knockback(from_position)
	attack_commit_timer = 0.0
	_reroll_attack_profile()
	_emit_health_changed()

	if current_hp <= 0:
		_start_death()
		return

	boss_state = BossState.HIT
	hit_timer = hit_recover_time
	_play_animation(&"boss_hit")


func _process_idle(delta: float) -> void:
	if player_ref != null:
		var to_player: Vector2 = player_ref.global_position - global_position
		var player_distance: float = to_player.length()
		if player_distance <= detection_radius:
			if player_distance <= _get_attack_trigger_range() and attack_cooldown_timer <= 0.0:
				attack_commit_timer += delta
			else:
				attack_commit_timer = maxf(0.0, attack_commit_timer - (delta * 1.8))
			if attack_commit_timer >= maxf(0.1, attack_commit_time):
				attack_commit_timer = 0.0
				_start_attack()
				return
			var target_velocity: Vector2 = _compute_combat_velocity(to_player, player_distance)
			velocity = velocity.move_toward(target_velocity, MOVE_ACCELERATION * delta)
			return

		if patrol_retarget_timer <= 0.0 or global_position.distance_to(patrol_target) <= 10.0:
			_reset_patrol_target(false)
		var to_patrol: Vector2 = patrol_target - global_position
		var patrol_velocity: Vector2 = Vector2.ZERO
		if to_patrol.length() > MOVE_EPSILON:
			patrol_velocity = to_patrol.normalized() * patrol_speed
		velocity = velocity.move_toward(patrol_velocity, MOVE_ACCELERATION * delta)
		return

	velocity = velocity.move_toward(Vector2.ZERO, MOVE_DECELERATION * delta)


func _process_attack(delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)

	var target_velocity: Vector2 = Vector2.ZERO
	if player_ref != null:
		var to_player: Vector2 = player_ref.global_position - global_position
		var player_distance: float = to_player.length()
		if to_player.length() > MOVE_EPSILON:
			target_velocity = _compute_combat_velocity(to_player, player_distance)
		if _is_attack_hit_frame_reached() and not attack_did_hit:
			attack_did_hit = _try_attack_damage()
	velocity = velocity.move_toward(target_velocity, MOVE_ACCELERATION * delta)

	var attack_animation_playing: bool = false
	if animated_sprite != null and animated_sprite.animation == &"boss_attack":
		attack_animation_playing = animated_sprite.is_playing()

	if attack_timer <= 0.0 and not attack_animation_playing:
		if not attack_did_hit and _can_force_attack_damage():
			player_ref.take_damage(_get_current_attack_damage(), global_position)
			attack_did_hit = true
		_end_attack_state()


func _process_hit(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, MOVE_DECELERATION * delta)
	hit_timer = maxf(0.0, hit_timer - delta)
	if hit_timer <= 0.0:
		boss_state = BossState.IDLE
		_play_animation(&"idle")


func _start_attack() -> void:
	boss_state = BossState.ATTACK
	attack_timer = _get_attack_animation_duration()
	attack_did_hit = false
	_play_animation(&"boss_attack")


func _end_attack_state() -> void:
	if boss_state != BossState.ATTACK:
		return
	attack_cooldown_timer = attack_cooldown
	if not attack_did_hit:
		attack_cooldown_timer += maxf(0.0, miss_cooldown_penalty)
	_reroll_attack_profile()
	boss_state = BossState.IDLE
	_play_animation(&"idle")


func _start_death() -> void:
	boss_state = BossState.DEATH
	attack_timer = 0.0
	attack_commit_timer = 0.0
	hit_timer = 0.0
	attack_did_hit = false
	velocity = Vector2.ZERO
	if body_collision != null:
		body_collision.set_deferred("disabled", true)
	_sync_damage_area_state(false)
	_play_death_sfx()
	_stop_alive_loop_sfx()
	_play_animation(&"boss_death")
	if not death_signal_emitted:
		death_signal_emitted = true
		defeated.emit()


func _try_attack_damage() -> bool:
	if player_ref == null:
		return false
	if not player_ref.has_method("take_damage"):
		return false

	if _is_player_overlapping_damage_area():
		player_ref.take_damage(_get_current_attack_damage(), global_position)
		return true

	var max_attack_distance: float = _get_attack_trigger_range() + ATTACK_DAMAGE_RANGE_BONUS
	if global_position.distance_to(player_ref.global_position) > max_attack_distance:
		return false

	player_ref.take_damage(_get_current_attack_damage(), global_position)
	return true


func _is_player_overlapping_damage_area() -> bool:
	if damage_area == null:
		return false
	if not damage_area.monitoring:
		return false

	for body in damage_area.get_overlapping_bodies():
		if body == player_ref:
			return true
	return false


func _is_attack_hit_frame_reached() -> bool:
	if animated_sprite != null and animated_sprite.animation == &"boss_attack":
		var required_frame: int = maxi(0, attack_hit_frame)
		if animated_sprite.frame >= required_frame:
			return true
	var hit_window: float = maxf(0.08, attack_windup_time * 0.45)
	return attack_timer <= hit_window


func _get_attack_animation_duration() -> float:
	var fallback_duration: float = maxf(0.2, attack_windup_time)
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return fallback_duration

	var frames: SpriteFrames = animated_sprite.sprite_frames
	if not frames.has_animation(&"boss_attack"):
		return fallback_duration

	var frame_count: int = frames.get_frame_count(&"boss_attack")
	var animation_speed: float = frames.get_animation_speed(&"boss_attack")
	if frame_count <= 0 or animation_speed <= 0.0:
		return fallback_duration
	return maxf(fallback_duration, float(frame_count) / animation_speed)


func _can_force_attack_damage() -> bool:
	if player_ref == null:
		return false
	if not player_ref.has_method("take_damage"):
		return false
	if global_position.distance_to(player_ref.global_position) > (detection_radius + 12.0):
		return false
	return true


func _bind_player() -> void:
	if not player_path.is_empty():
		player_ref = get_node_or_null(player_path) as CharacterBody2D
	else:
		var parent_node: Node = get_parent()
		if parent_node != null:
			player_ref = parent_node.get_node_or_null("Player") as CharacterBody2D

	if player_ref == null:
		call_deferred("_retry_bind_player")


func _retry_bind_player() -> void:
	if player_ref != null:
		return
	var parent_node: Node = get_parent()
	if parent_node != null:
		player_ref = parent_node.get_node_or_null("Player") as CharacterBody2D


func _configure_collision_filters() -> void:
	collision_layer = ENEMY_LAYER_MASK
	collision_mask = PLAYER_STRUCTURE_LAYER_MASK


func _configure_damage_area() -> void:
	if damage_area == null:
		return
	damage_area.collision_layer = 0
	damage_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	damage_area.monitorable = false
	_sync_damage_area_state(is_active_boss)


func _setup_audio_players() -> void:
	if injured_sfx_player == null:
		injured_sfx_player = AudioStreamPlayer.new()
		injured_sfx_player.name = "InjuredSfx"
		injured_sfx_player.bus = "Master"
		injured_sfx_player.volume_db = INJURED_SFX_VOLUME_DB
		injured_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(injured_sfx_player)
		injured_sfx_player.stream = INJURED_SFX_STREAM

	if alive_loop_sfx_player == null:
		alive_loop_sfx_player = AudioStreamPlayer.new()
		alive_loop_sfx_player.name = "AliveLoopSfx"
		alive_loop_sfx_player.bus = "Master"
		alive_loop_sfx_player.volume_db = ALIVE_LOOP_SFX_VOLUME_DB
		alive_loop_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(alive_loop_sfx_player)
		alive_loop_sfx_player.stream = ALIVE_LOOP_SFX_STREAM
		var loop_callback: Callable = Callable(self, "_on_alive_loop_sfx_finished")
		if not alive_loop_sfx_player.is_connected("finished", loop_callback):
			alive_loop_sfx_player.finished.connect(_on_alive_loop_sfx_finished)


func _play_injured_sfx() -> void:
	if injured_sfx_player == null or injured_sfx_player.stream == null:
		return
	injured_sfx_player.stop()
	injured_sfx_player.play()


func _play_death_sfx() -> void:
	if DEATH_SFX_STREAM == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		current_scene = get_tree().root
	if current_scene == null:
		return
	var death_player := AudioStreamPlayer.new()
	death_player.bus = "Master"
	death_player.volume_db = DEATH_SFX_VOLUME_DB
	death_player.process_mode = Node.PROCESS_MODE_ALWAYS
	death_player.stream = DEATH_SFX_STREAM
	current_scene.add_child(death_player)
	death_player.finished.connect(Callable(death_player, "queue_free"))
	death_player.play()


func _update_alive_loop_for_state() -> void:
	if not is_active_boss or boss_state == BossState.DEATH:
		_stop_alive_loop_sfx()
		return
	_play_alive_loop_sfx()


func _play_alive_loop_sfx() -> void:
	if alive_loop_sfx_player == null or alive_loop_sfx_player.stream == null:
		return
	if alive_loop_sfx_player.playing:
		return
	alive_loop_sfx_player.play()


func _stop_alive_loop_sfx() -> void:
	if alive_loop_sfx_player == null:
		return
	alive_loop_sfx_player.stop()


func _on_alive_loop_sfx_finished() -> void:
	if not is_active_boss:
		return
	if boss_state == BossState.DEATH:
		return
	_play_alive_loop_sfx()


func _sync_damage_area_state(enabled: bool) -> void:
	if damage_area != null:
		damage_area.monitoring = enabled
	if damage_area_collision != null:
		damage_area_collision.set_deferred("disabled", not enabled)


func _configure_animations() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if frames.has_animation(&"boss_attack"):
		frames.set_animation_loop(&"boss_attack", false)
	if frames.has_animation(&"boss_death"):
		frames.set_animation_loop(&"boss_death", false)
	if not animated_sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	if animated_sprite != null and boss_state == BossState.ATTACK and animated_sprite.animation == &"boss_attack":
		if not attack_did_hit and _can_force_attack_damage():
			player_ref.take_damage(_get_current_attack_damage(), global_position)
			attack_did_hit = true
		_end_attack_state()
		return

	if boss_state != BossState.DEATH:
		return
	if animated_sprite == null:
		queue_free()
		return
	if animated_sprite.animation == &"boss_death":
		queue_free()


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	elif not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func _update_visuals() -> void:
	if animated_sprite == null:
		return

	var hover_offset: float = sin(hover_time * HOVER_WAVE_SPEED) * HOVER_WAVE_AMPLITUDE
	animated_sprite.position.y = hover_offset

	if absf(velocity.x) > MOVE_EPSILON:
		facing_direction = 1 if velocity.x > 0.0 else -1
	animated_sprite.flip_h = facing_direction < 0


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


func _reset_patrol_target(force_immediate: bool) -> void:
	var offset_x: float = randf_range(-maxf(patrol_distance_x, 0.0), maxf(patrol_distance_x, 0.0))
	var offset_y: float = randf_range(-maxf(patrol_distance_y, 0.0), maxf(patrol_distance_y, 0.0))
	patrol_target = spawn_position + Vector2(offset_x, offset_y)

	# Avoid picking a patrol point too close to current position to prevent stalling.
	if global_position.distance_to(patrol_target) < 6.0:
		patrol_target.x += 10.0 * float(facing_direction if facing_direction != 0 else 1)

	if force_immediate:
		patrol_retarget_timer = 0.0
	else:
		patrol_retarget_timer = randf_range(PATROL_RETARGET_MIN_TIME, PATROL_RETARGET_MAX_TIME)


func get_current_hp() -> int:
	return current_hp


func get_max_hp_value() -> int:
	return max_hp


func _emit_health_changed() -> void:
	health_changed.emit(current_hp, max_hp)


func _is_rage_mode() -> bool:
	var clamped_ratio: float = clampf(rage_hp_ratio, 0.1, 0.95)
	return float(current_hp) <= (float(maxi(max_hp, 1)) * clamped_ratio)


func _get_current_chase_speed() -> float:
	var speed: float = chase_speed
	if _is_rage_mode():
		speed *= maxf(rage_speed_multiplier, 1.0)
	if dash_timer > 0.0:
		speed *= maxf(dash_speed_multiplier, 1.0)
	return speed


func _get_attack_trigger_range() -> float:
	return maxf(18.0, current_attack_trigger_range)


func _get_current_attack_damage() -> int:
	var damage_value: int = attack_damage
	if _is_rage_mode():
		damage_value += maxi(rage_attack_bonus, 0)
	return maxi(1, damage_value)


func _get_current_touch_damage() -> int:
	var damage_value: int = touch_damage
	if _is_rage_mode():
		damage_value += int(ceil(float(maxi(rage_attack_bonus, 0)) * 0.5))
	return maxi(1, damage_value)


func _reroll_attack_profile() -> void:
	var jitter_limit: float = maxf(attack_range_jitter, 0.0)
	current_attack_trigger_range = attack_range + randf_range(-jitter_limit, jitter_limit)
	strafe_direction = -1 if randf() < 0.5 else 1
	var min_strafe_time: float = maxf(0.08, minf(strafe_jitter_time_min, strafe_jitter_time_max))
	var max_strafe_time: float = maxf(min_strafe_time, maxf(strafe_jitter_time_min, strafe_jitter_time_max))
	strafe_timer = randf_range(min_strafe_time, max_strafe_time)


func _compute_combat_velocity(to_player: Vector2, distance_to_player: float) -> Vector2:
	if to_player.length() <= MOVE_EPSILON:
		return Vector2.ZERO

	if strafe_timer <= 0.0:
		_reroll_attack_profile()

	var base_direction: Vector2 = to_player.normalized()
	var perpendicular: Vector2 = Vector2(-base_direction.y, base_direction.x) * float(strafe_direction)
	var movement_direction: Vector2
	var safe_strafe: float = clampf(strafe_strength, 0.0, 1.2)
	var preferred_distance: float = attack_range + 16.0
	if _is_rage_mode():
		preferred_distance -= 6.0

	if distance_to_player > (preferred_distance + 20.0):
		movement_direction = base_direction + (perpendicular * safe_strafe)
	elif distance_to_player < (preferred_distance - 12.0):
		movement_direction = (-base_direction * 0.85) + (perpendicular * (safe_strafe + 0.2))
	else:
		movement_direction = (perpendicular * (safe_strafe + 0.28)) + (base_direction * 0.25)

	if movement_direction.length() <= 0.001:
		movement_direction = base_direction
	movement_direction = movement_direction.normalized()
	_update_dash_state(distance_to_player)
	return movement_direction * _get_current_chase_speed()


func _update_dash_state(distance_to_player: float) -> void:
	if dash_timer > 0.0:
		return
	if dash_cooldown_timer > 0.0:
		return
	if distance_to_player < (_get_attack_trigger_range() + 22.0):
		return

	var dash_chance: float = 0.28 if _is_rage_mode() else 0.18
	if randf() > dash_chance:
		return

	var min_dash: float = maxf(0.08, minf(dash_duration_min, dash_duration_max))
	var max_dash: float = maxf(min_dash, maxf(dash_duration_min, dash_duration_max))
	dash_timer = randf_range(min_dash, max_dash)
	_reset_dash_cooldown()


func _reset_dash_cooldown() -> void:
	var min_cd: float = maxf(0.2, minf(dash_cooldown_min, dash_cooldown_max))
	var max_cd: float = maxf(min_cd, maxf(dash_cooldown_min, dash_cooldown_max))
	dash_cooldown_timer = randf_range(min_cd, max_cd)
	if _is_rage_mode():
		dash_cooldown_timer *= 0.82


func _try_touch_damage_player() -> void:
	if touch_damage <= 0:
		return
	if touch_damage_timer > 0.0:
		return
	if boss_state == BossState.DEATH:
		return
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	if damage_area != null:
		for body in damage_area.get_overlapping_bodies():
			if body == player_ref:
				player_ref.take_damage(_get_current_touch_damage(), global_position)
				touch_damage_timer = touch_damage_interval
				return

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision == null:
			continue
		var collider: Object = collision.get_collider()
		if collider != player_ref:
			continue
		player_ref.take_damage(_get_current_touch_damage(), global_position)
		touch_damage_timer = touch_damage_interval
		return
