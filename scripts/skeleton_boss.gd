extends CharacterBody2D

signal defeated
signal health_changed(current_hp: int, max_hp_value: int)

enum BossState {
	PATROL,
	CHASE,
	ATTACK,
	HURT,
	DEAD
}

const MOVE_EPSILON: float = 4.0
const GROUND_ACCELERATION: float = 760.0
const GROUND_DECELERATION: float = 1200.0
const HEALTH_BAR_WIDTH: float = 46.0
const HIT_KNOCKBACK_X: float = 84.0
const HIT_KNOCKBACK_Y: float = -54.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.35
const HEALTH_PERCENT_FONT_SIZE: int = 11
const HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const HEALTH_PERCENT_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const DEATH_FALLBACK_EXTRA_TIME: float = 0.35
const PLAYER_STRUCTURE_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const FLOOR_CHECK_FORWARD_DISTANCE: float = 14.0
const FLOOR_CHECK_DOWN_START_Y: float = 4.0
const FLOOR_CHECK_DOWN_DISTANCE: float = 56.0
const DEATH_PARTICLE_COLOR: Color = Color(0.9, 0.9, 0.94, 1.0)
const DEATH_FADE_DURATION: float = 0.2
const VICTORY_SFX_PATH: String = "res://sounds/Retro Success Melody Win.wav"
const VICTORY_SFX_VOLUME_DB: float = -1.2
const HURT_SFX_STREAM: AudioStream = preload("res://sounds/Injured.wav")
const HURT_SFX_VOLUME_DB: float = -6.0
const DEATH_VFX = preload("res://scripts/death_vfx.gd")

@export var player_path: NodePath
@export var max_hp: int = 240
@export var patrol_distance: float = 120.0
@export var patrol_speed: float = 34.0
@export var chase_speed: float = 54.0
@export var detection_radius: float = 240.0
@export var lose_interest_radius: float = 340.0
@export var vertical_engage_tolerance: float = 96.0
@export var attack_range: float = 46.0
@export var attack_damage: int = 16
@export var attack_hit_time: float = 0.48
@export var attack_max_time: float = 1.45
@export var attack_cooldown: float = 1.05
@export var contact_damage: int = 9
@export var contact_damage_cooldown: float = 0.55
@export var hurt_recover_time: float = 0.26
@export var health_bar_visible_time: float = 3.2
@export var allow_attack_damage: bool = true
@export var allow_contact_damage: bool = true
@export var attack_area_offset_x: float = 30.0
@export var attack_area_offset_y: float = -3.0
@export var sprite_faces_left: bool = true
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"skeletonboss_walk"
@export var attack_animation: StringName = &"skeletonboss_attack"
@export var hurt_animation: StringName = &"skeletonboss_hurt"
@export var death_animation: StringName = &"skeletonboss_die"

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact_area: Area2D = $ContactArea
@onready var contact_collision: CollisionShape2D = $ContactArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var health_bar: Node2D = get_node_or_null("HealthBar")
@onready var health_fill: Control = get_node_or_null("HealthBar/Bg/Fill")
@onready var health_percent_label: Label = get_node_or_null("HealthBar/PercentLabel")

var player_ref: CharacterBody2D = null
var boss_state: int = BossState.PATROL
var spawn_position: Vector2 = Vector2.ZERO
var patrol_direction: int = 1
var facing_direction: int = 1
var current_hp: int = 1
var is_active_boss: bool = true
var death_signal_emitted: bool = false
var attack_cooldown_timer: float = 0.0
var attack_state_timer: float = 0.0
var attack_hit_applied: bool = false
var contact_damage_timer: float = 0.0
var hurt_timer: float = 0.0
var health_bar_timer: float = 0.0
var health_fill_style: StyleBoxFlat = null
var death_fallback_timer: float = -1.0
var death_cleanup_started: bool = false
var hurt_sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	spawn_position = global_position
	current_hp = max_hp
	_configure_collision_filters()
	_configure_animations()
	_bind_player()
	_update_attack_area_transform()
	_setup_health_fill_style()
	_apply_health_percent_font()
	_setup_hurt_sfx()
	_update_health_bar()
	if health_bar != null:
		health_bar.visible = false
	_set_collision_enabled(is_active_boss, false)
	if not is_active_boss:
		_play_animation(idle_animation)
		set_physics_process(false)
	_emit_health_changed()


func _physics_process(delta: float) -> void:
	if not is_active_boss:
		velocity = Vector2.ZERO
		return

	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	contact_damage_timer = maxf(0.0, contact_damage_timer - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	_update_health_bar_timer(delta)

	if boss_state != BossState.DEAD and not is_on_floor():
		velocity += get_gravity() * delta

	match boss_state:
		BossState.PATROL:
			_process_patrol(delta)
		BossState.CHASE:
			_process_chase(delta)
		BossState.ATTACK:
			_process_attack(delta)
		BossState.HURT:
			_process_hurt(delta)
		BossState.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)

	move_and_slide()
	_process_contact_damage()
	_update_visuals()
	if boss_state == BossState.DEAD and death_fallback_timer >= 0.0:
		death_fallback_timer = maxf(0.0, death_fallback_timer - delta)
		if death_fallback_timer <= 0.0:
			_finish_death_and_queue_free()


func set_boss_active(enabled: bool) -> void:
	is_active_boss = enabled
	visible = enabled
	set_physics_process(enabled)
	_set_collision_enabled(enabled, true)
	if not enabled:
		velocity = Vector2.ZERO
		boss_state = BossState.PATROL
		attack_cooldown_timer = 0.0
		attack_state_timer = 0.0
		attack_hit_applied = false
		contact_damage_timer = 0.0
		hurt_timer = 0.0
		death_fallback_timer = -1.0
		death_cleanup_started = false
		if health_bar != null:
			health_bar.visible = false
		if animated_sprite != null:
			animated_sprite.modulate = Color(1, 1, 1, 1)
		_play_animation(idle_animation)
		return
	if boss_state != BossState.DEAD:
		boss_state = BossState.PATROL
		_play_animation(idle_animation)


func reset_for_battle() -> void:
	current_hp = max_hp
	death_signal_emitted = false
	boss_state = BossState.PATROL
	global_position = spawn_position
	velocity = Vector2.ZERO
	attack_cooldown_timer = 0.0
	attack_state_timer = 0.0
	attack_hit_applied = false
	contact_damage_timer = 0.0
	hurt_timer = 0.0
	health_bar_timer = 0.0
	death_fallback_timer = -1.0
	death_cleanup_started = false
	_update_health_bar()
	if health_bar != null:
		health_bar.visible = false
	if animated_sprite != null:
		animated_sprite.modulate = Color(1, 1, 1, 1)
	set_boss_active(true)
	_emit_health_changed()


func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	if not is_active_boss:
		return
	if amount <= 0 or boss_state == BossState.DEAD:
		return

	current_hp = maxi(0, current_hp - amount)
	_play_hurt_sfx()
	_apply_hit_knockback(from_position)
	_show_health_bar()
	_update_health_bar()
	_emit_health_changed()

	if current_hp <= 0:
		_start_death()
		return

	attack_cooldown_timer = maxf(attack_cooldown_timer, 0.24)
	boss_state = BossState.HURT
	hurt_timer = maxf(0.05, hurt_recover_time)
	_play_animation(hurt_animation)


func _process_patrol(delta: float) -> void:
	if _can_chase_player():
		boss_state = BossState.CHASE
		return

	var left_limit: float = spawn_position.x - patrol_distance
	var right_limit: float = spawn_position.x + patrol_distance
	if global_position.x <= left_limit:
		patrol_direction = 1
	elif global_position.x >= right_limit:
		patrol_direction = -1
	elif is_on_floor() and not _has_floor_ahead(patrol_direction):
		patrol_direction *= -1

	velocity.x = move_toward(velocity.x, float(patrol_direction) * patrol_speed, GROUND_ACCELERATION * delta)
	if patrol_direction != 0:
		facing_direction = patrol_direction


func _process_chase(delta: float) -> void:
	if not _should_keep_chasing_player():
		boss_state = BossState.PATROL
		return
	if player_ref == null:
		boss_state = BossState.PATROL
		return

	var to_player: Vector2 = player_ref.global_position - global_position
	if absf(to_player.x) > MOVE_EPSILON:
		facing_direction = 1 if to_player.x > 0.0 else -1

	if absf(to_player.x) <= attack_range and absf(to_player.y) <= vertical_engage_tolerance and attack_cooldown_timer <= 0.0:
		_start_attack()
		return

	if is_on_floor() and not _has_floor_ahead(facing_direction):
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
		return

	velocity.x = move_toward(velocity.x, float(facing_direction) * chase_speed, GROUND_ACCELERATION * delta)


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
	attack_state_timer += delta
	if not attack_hit_applied and attack_state_timer >= maxf(0.01, attack_hit_time):
		attack_hit_applied = _deal_attack_damage()
	if attack_state_timer >= maxf(attack_max_time, attack_hit_time + 0.05):
		_finish_attack()


func _process_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
	if hurt_timer > 0.0:
		return
	if _is_current_animation(hurt_animation):
		return
	_recover_from_hurt()


func _start_attack() -> void:
	boss_state = BossState.ATTACK
	attack_state_timer = 0.0
	attack_hit_applied = false
	_play_animation(attack_animation, _resolve_attack_animation_speed_scale())


func _finish_attack() -> void:
	if boss_state != BossState.ATTACK:
		return
	attack_cooldown_timer = maxf(0.05, attack_cooldown)
	boss_state = BossState.CHASE if _can_chase_player() else BossState.PATROL


func _recover_from_hurt() -> void:
	if boss_state != BossState.HURT:
		return
	boss_state = BossState.CHASE if _can_chase_player() else BossState.PATROL


func _start_death() -> void:
	boss_state = BossState.DEAD
	velocity = Vector2.ZERO
	attack_cooldown_timer = 0.0
	attack_state_timer = 0.0
	attack_hit_applied = false
	contact_damage_timer = 0.0
	hurt_timer = 0.0
	death_fallback_timer = _get_animation_duration(death_animation) + DEATH_FALLBACK_EXTRA_TIME
	death_cleanup_started = false
	_set_collision_enabled(false, true, false)
	if health_bar != null:
		health_bar.visible = false
	DEATH_VFX.spawn_burst(self, global_position, DEATH_PARTICLE_COLOR, 18)
	_play_victory_sfx()
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(death_animation):
		animated_sprite.sprite_frames.set_animation_loop(death_animation, false)
	if _has_animation(death_animation):
		_play_animation(death_animation)
	else:
		_finish_death_and_queue_free()
	if not death_signal_emitted:
		death_signal_emitted = true
		defeated.emit()


func _process_contact_damage() -> void:
	if not allow_contact_damage:
		return
	if contact_damage <= 0:
		return
	if contact_damage_timer > 0.0:
		return
	if boss_state == BossState.DEAD:
		return
	if player_ref == null or not player_ref.has_method("take_damage"):
		return

	if contact_area != null:
		for body in contact_area.get_overlapping_bodies():
			if _is_player_target(body):
				player_ref.take_damage(contact_damage, global_position)
				contact_damage_timer = maxf(0.05, contact_damage_cooldown)
				return

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision == null:
			continue
		if _is_player_target(collision.get_collider() as Node):
			player_ref.take_damage(contact_damage, global_position)
			contact_damage_timer = maxf(0.05, contact_damage_cooldown)
			return


func _deal_attack_damage() -> bool:
	if not allow_attack_damage:
		return false
	if attack_damage <= 0:
		return false
	if player_ref == null or not player_ref.has_method("take_damage"):
		return false

	if attack_area != null:
		for body in attack_area.get_overlapping_bodies():
			if _is_player_target(body):
				player_ref.take_damage(attack_damage, global_position)
				return true

	var to_player: Vector2 = player_ref.global_position - global_position
	if absf(to_player.x) <= (attack_range + 14.0) and absf(to_player.y) <= (vertical_engage_tolerance + 18.0):
		player_ref.take_damage(attack_damage, global_position)
		return true
	return false


func _update_visuals() -> void:
	if animated_sprite == null:
		return

	animated_sprite.flip_h = facing_direction > 0 if sprite_faces_left else facing_direction < 0
	_update_attack_area_transform()

	if boss_state == BossState.ATTACK or boss_state == BossState.HURT or boss_state == BossState.DEAD:
		return
	if absf(velocity.x) > MOVE_EPSILON:
		_play_animation(_get_walk_animation())
	else:
		_play_animation(idle_animation)


func _update_attack_area_transform() -> void:
	if attack_area == null:
		return
	attack_area.position = Vector2(absf(attack_area_offset_x) * float(facing_direction), attack_area_offset_y)


func _configure_collision_filters() -> void:
	collision_layer = ENEMY_LAYER_MASK
	collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	if contact_area != null:
		contact_area.collision_layer = 0
		contact_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
		contact_area.monitorable = false
	if attack_area != null:
		attack_area.collision_layer = 0
		attack_area.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
		attack_area.monitorable = false


func _configure_animations() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if frames.has_animation(attack_animation):
		frames.set_animation_loop(attack_animation, false)
	if frames.has_animation(hurt_animation):
		frames.set_animation_loop(hurt_animation, false)
	if frames.has_animation(death_animation):
		frames.set_animation_loop(death_animation, false)
	if frames.has_animation(idle_animation):
		frames.set_animation_loop(idle_animation, true)
	if frames.has_animation(_get_walk_animation()):
		frames.set_animation_loop(_get_walk_animation(), true)
	if not animated_sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	if animated_sprite == null:
		return
	if boss_state == BossState.ATTACK and animated_sprite.animation == attack_animation:
		_finish_attack()
		return
	if boss_state == BossState.HURT and animated_sprite.animation == hurt_animation and hurt_timer <= 0.0:
		_recover_from_hurt()
		return
	if boss_state == BossState.DEAD and animated_sprite.animation == death_animation:
		_finish_death_and_queue_free()


func _finish_death_and_queue_free() -> void:
	if death_cleanup_started:
		return
	death_cleanup_started = true
	death_fallback_timer = -1.0
	set_physics_process(false)

	var fade_target: CanvasItem = animated_sprite
	if fade_target == null:
		fade_target = self
	var fade_tween: Tween = DEATH_VFX.fade_out(self, fade_target, DEATH_FADE_DURATION)
	if fade_tween != null:
		fade_tween.finished.connect(Callable(self, "queue_free"))
	else:
		queue_free()


func _play_victory_sfx() -> void:
	if not ResourceLoader.exists(VICTORY_SFX_PATH):
		return

	var loaded_stream: Resource = load(VICTORY_SFX_PATH)
	if not (loaded_stream is AudioStream):
		return
	_play_one_shot_sfx(loaded_stream as AudioStream, VICTORY_SFX_VOLUME_DB)


func _setup_hurt_sfx() -> void:
	if hurt_sfx_player != null:
		return

	hurt_sfx_player = AudioStreamPlayer.new()
	hurt_sfx_player.name = "HurtSfx"
	hurt_sfx_player.bus = "SFX"
	hurt_sfx_player.volume_db = HURT_SFX_VOLUME_DB
	hurt_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	hurt_sfx_player.stream = HURT_SFX_STREAM
	add_child(hurt_sfx_player)


func _play_hurt_sfx() -> void:
	if hurt_sfx_player == null or hurt_sfx_player.stream == null:
		return
	hurt_sfx_player.stop()
	hurt_sfx_player.play()


func _play_one_shot_sfx(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		current_scene = get_tree().root
	if current_scene == null:
		return

	var one_shot_player: AudioStreamPlayer = AudioStreamPlayer.new()
	one_shot_player.bus = "SFX"
	one_shot_player.volume_db = volume_db
	one_shot_player.process_mode = Node.PROCESS_MODE_ALWAYS
	one_shot_player.stream = stream
	current_scene.add_child(one_shot_player)
	one_shot_player.finished.connect(Callable(one_shot_player, "queue_free"))
	one_shot_player.play()


func _play_animation(animation_name: StringName, speed_scale: float = 1.0) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	animated_sprite.speed_scale = maxf(speed_scale, 0.01)
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	elif not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func _is_current_animation(animation_name: StringName) -> bool:
	if animated_sprite == null:
		return false
	return animated_sprite.animation == animation_name and animated_sprite.is_playing()


func _has_animation(animation_name: StringName) -> bool:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return false
	return animated_sprite.sprite_frames.has_animation(animation_name)


func _get_walk_animation() -> StringName:
	if _has_animation(walk_animation):
		return walk_animation
	return idle_animation


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
		health_percent_label.text = "%d%%" % int(round(ratio * 100.0))


func _show_health_bar() -> void:
	health_bar_timer = maxf(0.2, health_bar_visible_time)
	if health_bar != null:
		health_bar.visible = true


func _update_health_bar_timer(delta: float) -> void:
	if health_bar == null or not health_bar.visible:
		return
	health_bar_timer = maxf(0.0, health_bar_timer - delta)
	if health_bar_timer <= 0.0:
		health_bar.visible = false


func _setup_health_fill_style() -> void:
	if health_fill == null:
		return
	var panel_style: StyleBox = health_fill.get_theme_stylebox("panel")
	if not (panel_style is StyleBoxFlat):
		return
	health_fill_style = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	health_fill.add_theme_stylebox_override("panel", health_fill_style)


func _apply_health_percent_font() -> void:
	if health_percent_label == null:
		return
	if ResourceLoader.exists(HEALTH_PERCENT_FONT_PATH):
		var loaded_font: Resource = load(HEALTH_PERCENT_FONT_PATH)
		if loaded_font is Font:
			health_percent_label.add_theme_font_override("font", loaded_font as Font)
	health_percent_label.add_theme_font_size_override("font_size", HEALTH_PERCENT_FONT_SIZE)
	health_percent_label.add_theme_constant_override("outline_size", HEALTH_PERCENT_OUTLINE_SIZE)
	health_percent_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 0.98))
	health_percent_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))


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


func _can_chase_player() -> bool:
	if player_ref == null:
		return false
	var to_player: Vector2 = player_ref.global_position - global_position
	if to_player.length() > detection_radius:
		return false
	return absf(to_player.y) <= maxf(36.0, vertical_engage_tolerance * 1.35)


func _should_keep_chasing_player() -> bool:
	if player_ref == null:
		return false
	var to_player: Vector2 = player_ref.global_position - global_position
	if to_player.length() > lose_interest_radius:
		return false
	return absf(to_player.y) <= maxf(48.0, vertical_engage_tolerance * 1.65)


func _is_player_target(node: Node) -> bool:
	if node == null:
		return false
	if player_ref != null and node == player_ref:
		return true
	return node.is_in_group("player")


func _set_collision_enabled(enabled: bool, deferred: bool, include_body_collision: bool = true) -> void:
	if include_body_collision and body_collision != null:
		if deferred:
			body_collision.set_deferred("disabled", not enabled)
		else:
			body_collision.disabled = not enabled
	if contact_collision != null:
		if deferred:
			contact_collision.set_deferred("disabled", not enabled)
		else:
			contact_collision.disabled = not enabled
	if attack_collision != null:
		if deferred:
			attack_collision.set_deferred("disabled", not enabled)
		else:
			attack_collision.disabled = not enabled
	if contact_area != null:
		if deferred:
			if contact_area.monitoring != enabled:
				contact_area.set_deferred("monitoring", enabled)
			if contact_area.monitorable:
				contact_area.set_deferred("monitorable", false)
		else:
			contact_area.monitoring = enabled
			contact_area.monitorable = false
	if attack_area != null:
		if deferred:
			if attack_area.monitoring != enabled:
				attack_area.set_deferred("monitoring", enabled)
			if attack_area.monitorable:
				attack_area.set_deferred("monitorable", false)
		else:
			attack_area.monitoring = enabled
			attack_area.monitorable = false


func _has_floor_ahead(direction: int) -> bool:
	if direction == 0:
		return true
	var ray_start: Vector2 = global_position + Vector2(float(direction) * FLOOR_CHECK_FORWARD_DISTANCE, FLOOR_CHECK_DOWN_START_Y)
	var ray_end: Vector2 = ray_start + Vector2(0.0, FLOOR_CHECK_DOWN_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = PLAYER_STRUCTURE_LAYER_MASK
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _apply_hit_knockback(from_position: Vector2) -> void:
	if from_position == Vector2.INF:
		return
	var push_dir: float = 0.0
	if global_position.x > from_position.x:
		push_dir = 1.0
	elif global_position.x < from_position.x:
		push_dir = -1.0
	if is_zero_approx(push_dir):
		push_dir = float(facing_direction if facing_direction != 0 else 1)
	velocity.x = push_dir * HIT_KNOCKBACK_X * DAMAGE_KNOCKBACK_MULTIPLIER
	# Keep boss grounded when hit on floor to avoid sinking/jitter against terrain.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y, HIT_KNOCKBACK_Y * DAMAGE_KNOCKBACK_MULTIPLIER)


func get_current_hp() -> int:
	return current_hp


func get_max_hp_value() -> int:
	return max_hp


func _emit_health_changed() -> void:
	health_changed.emit(current_hp, max_hp)


func _get_animation_duration(animation_name: StringName) -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 0.4
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if not frames.has_animation(animation_name):
		return 0.4
	var frame_count: int = maxi(frames.get_frame_count(animation_name), 1)
	var animation_speed: float = maxf(frames.get_animation_speed(animation_name), 0.01)
	return float(frame_count) / animation_speed


func _resolve_attack_animation_speed_scale() -> float:
	var base_duration: float = _get_animation_duration(attack_animation)
	if base_duration <= 0.01:
		return 1.0
	var target_duration: float = maxf(attack_max_time, attack_hit_time + 0.05)
	if target_duration <= 0.01:
		return 1.0
	return maxf(base_duration / target_duration, 0.01)
