extends CharacterBody2D

signal stats_changed(current_hp: int, max_hp_value: int, current_stamina: float, max_stamina_value: float, current_lives: int)
signal died
signal respawned


const WALK_SPEED: float = 92.0
const SPRINT_SPEED: float = 128.0
const JUMP_VELOCITY: float = -320.0
const GROUND_ACCELERATION: float = 1200.0
const GROUND_DECELERATION: float = 2600.0
const AIR_ACCELERATION: float = 700.0
const AIR_DECELERATION: float = 900.0
const ATTACK_SPEED_FACTOR: float = 0.35
const ATTACK_ACCELERATION_FACTOR: float = 0.55
const ATTACK_GROUND_DECELERATION: float = 2200.0
const ATTACK_AIR_DECELERATION: float = 450.0
const ATTACK_SPEED_SCALE: float = 3.0
const ATTACK_GROUND_STOP_TIME: float = 0.06
const ATTACK_HITBOX_OFFSET_X: float = 18.0
const ATTACK_HITBOX_OFFSET_Y: float = -9.0
const ATTACK_HITBOX_START_DELAY: float = 0.03
const ATTACK_HITBOX_ACTIVE_TIME: float = 0.12
const ATTACK_HITBOX_WIDTH: float = 30.0
const ATTACK_HITBOX_HEIGHT: float = 22.0
const ATTACK_DAMAGE: int = 10
const HIT_KNOCKBACK_X: float = 96.0
const HIT_KNOCKBACK_Y: float = -70.0
const DAMAGE_KNOCKBACK_MULTIPLIER: float = 1.45
const DEATH_HITSTOP_TIME: float = 0.08
const DEATH_SHAKE_TIME: float = 0.34
const DEATH_SHAKE_STRENGTH: float = 2.4
const DEATH_FLASH_COLOR: Color = Color(1.0, 0.45, 0.45, 1.0)
const DEATH_DIM_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const DEATH_OVERLAY_COLOR: Color = Color(0.08, 0.0, 0.0, 0.0)
const DEATH_OVERLAY_PEAK_ALPHA: float = 0.0
const DEATH_OVERLAY_HOLD_ALPHA: float = 0.0
const DEATH_OVERLAY_FADE_OUT_TIME: float = 0.26
const DEATH_HEARTBEAT_OVERLAY_COLOR: Color = Color(0.78, 0.0, 0.0, 0.0)
const DEATH_HEARTBEAT_BASE_ALPHA: float = 0.08
const DEATH_HEARTBEAT_PEAK_ALPHA: float = 0.26
const DEATH_HEARTBEAT_IN_TIME: float = 0.12
const DEATH_HEARTBEAT_OUT_TIME: float = 0.24
const DEATH_CAMERA_ZOOM_PUNCH: float = 1.08
const DEATH_CAMERA_ZOOM_HOLD: float = 1.03
const DEATH_TEXT: String = "Voc\u00ea Morreu !"
const DEATH_TEXT_IN_TIME: float = 0.22
const DEATH_TEXT_HOLD_ALPHA: float = 0.96
const DEATH_TEXT_FADE_OUT_TIME: float = 0.22
const DEATH_TEXT_START_SCALE: Vector2 = Vector2(1.32, 1.32)
const DEATH_TEXT_END_SCALE: Vector2 = Vector2.ONE
const DEATH_TEXT_COLOR: Color = Color(0.72, 0.05, 0.08, 0.0)
const DEATH_TEXT_OUTLINE_COLOR: Color = Color(0.02, 0, 0, 0.98)
const DEATH_TEXT_SHADOW_COLOR: Color = Color(0, 0, 0, 0.92)
const DEATH_TEXT_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const DEATH_TEXT_Y_OFFSET: float = -48.0
const DEATH_EMOJI_TEXT: String = "\u2620"
const GAME_OVER_TEXT: String = "Fim de Jogo"
const GAME_OVER_EMOJI_TEXT: String = "\u2620"
const DEATH_CONTINUE_TEXT: String = "Continuar"
const DEATH_NEW_GAME_TEXT: String = "Novo Jogo"
const DEATH_EMOJI_IN_TIME: float = 0.2
const DEATH_EMOJI_FADE_OUT_TIME: float = 0.2
const DEATH_EMOJI_HOLD_ALPHA: float = 0.92
const DEATH_EMOJI_START_SCALE: Vector2 = Vector2(1.45, 1.45)
const DEATH_EMOJI_END_SCALE: Vector2 = Vector2(1.0, 1.0)
const DEATH_EMOJI_COLOR: Color = Color(0.92, 0.88, 0.88, 0.0)
const DEATH_EMOJI_Y_OFFSET: float = -104.0
const DEATH_COUNTDOWN_START: int = 5
const DEATH_COUNTDOWN_STEP_TIME: float = 1.0
const DEATH_COUNTDOWN_IN_TIME: float = 0.14
const DEATH_COUNTDOWN_FADE_OUT_TIME: float = 0.16
const DEATH_COUNTDOWN_START_SCALE: Vector2 = Vector2(1.3, 1.3)
const DEATH_COUNTDOWN_END_SCALE: Vector2 = Vector2.ONE
const DEATH_COUNTDOWN_COLOR: Color = Color(0.96, 0.92, 0.9, 0.0)
const DEATH_COUNTDOWN_Y_OFFSET: float = 56.0
const DEATH_COUNTDOWN_TREMOR_STRENGTH: float = 2.2
const DEATH_COUNTDOWN_TREMOR_SPEED: float = 22.0
const DEATH_ACTIONS_Y_OFFSET: float = 126.0
const DEATH_ACTIONS_ROW_HEIGHT: float = 36.0
const DEATH_ACTIONS_BUTTON_WIDTH: float = 196.0
const DEATH_ACTIONS_BUTTON_HEIGHT: float = 30.0
const DEATH_ACTIONS_BUTTON_FONT_SIZE: int = 22
const DEATH_ACTIONS_BUTTON_OUTLINE_SIZE: int = 3
const DEATH_ACTIONS_BUTTON_SPACING: int = 22
const DEATH_ACTIONS_FADE_IN_TIME: float = 0.2
const DEATH_COUNTDOWN_SFX_PATH: String = "res://sounds/Monster_Roar_4.wav"
const DEATH_COUNTDOWN_SFX_VOLUME_DB: float = -14.0
const PLAYER_RESPAWN_FADE_OUT_TIME: float = 0.24
const PLAYER_RESPAWN_FADE_IN_TIME: float = 0.28
const DEATH_INTRO_SFX_PATH: String = "res://sounds/deathplayersound.wav"
const DEATH_INTRO_SFX_VOLUME_DB: float = -5.0
const DEATH_MESSAGE_DELAY: float = 0.22
const DEATH_SFX_PATH: String = "res://sounds/Retro Negative Melody.wav"
const DEATH_SFX_VOLUME_DB: float = -4.0
const HURT_SFX_PATH: String = "res://sounds/damageplayer.wav"
const HURT_SFX_VOLUME_DB: float = -4.5
const JUMP_SFX_PATH: String = "res://sounds/JumpSound.wav"
const JUMP_SFX_VOLUME_DB: float = -5.0
const HURT_FLASH_COLOR: Color = Color(1.0, 0.45, 0.45, 1.0)
const HURT_FLASH_OUT_TIME: float = 0.13
const HEALTH_PERCENT_FONT_SIZE: int = 10
const HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const PLAYER_HEALTH_BAR_WIDTH: float = 28.0
const PLAYER_HEALTH_BAR_VISIBLE_TIME: float = 3.2
const HP_REGEN_DELAY_AFTER_HIT: float = 2.4
const HP_REGEN_PER_SECOND: float = 2.0
const MOVE_THRESHOLD: float = 0.01
const GROUND_STOP_EPSILON: float = 6.0
const BASE_SPRITE_OFFSET: Vector2 = Vector2.ZERO
const ATTACK_SPRITE_OFFSET: Vector2 = Vector2.ZERO
const ATTACK_STAMINA_COST: float = 14.0
const STAMINA_REGEN_RATE: float = 18.0
const SPRINT_STAMINA_DRAIN_RATE: float = 22.0
const DEFEND_BLOCK_PUSHBACK_X: float = 78.0
const DEFEND_BLOCK_DAMAGE_MULTIPLIER: float = 0.0
const DEFEND_BLOCK_MIN_DAMAGE: int = 0
const DEFEND_BLOCK_COOLDOWN: float = 0.12
const DEFAULT_VOID_FALL_KILL_Y: float = 860.0
const DEFAULT_VOID_FOV_MARGIN_Y: float = 120.0
const PLAYER_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 2
const PLAYER_COLLISION_MASK: int = PLAYER_LAYER_MASK | ENEMY_LAYER_MASK
const SPAWN_DIALOG_TEXT: String = "Que lugar \u00e9 este ?"
const SPAWN_DIALOG_DURATION: float = 2.8
const SPAWN_DIALOG_FADE_IN_TIME: float = 0.2
const SPAWN_DIALOG_FADE_OUT_TIME: float = 0.24
const SPAWN_DIALOG_MIN_WIDTH: float = 138.0
const SPAWN_DIALOG_MAX_WIDTH: float = 252.0
const SPAWN_DIALOG_MIN_HEIGHT: float = 34.0
const SPAWN_DIALOG_CONTENT_PADDING_X: float = 16.0
const SPAWN_DIALOG_CONTENT_PADDING_Y: float = 10.0
const SPAWN_DIALOG_FONT_SIZE: int = 15
const SPAWN_DIALOG_SCREEN_CENTER_OFFSET_Y: float = 0.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_sfx: AudioStreamPlayer = $AttackSfx
@onready var player_camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var health_bar: Node2D = get_node_or_null("HealthBar")
@onready var health_fill: Control = get_node_or_null("HealthBar/Bg/Fill")
@onready var health_percent_label: Label = get_node_or_null("HealthBar/PercentLabel")

@export var max_hp: int = 100
@export var max_stamina: float = 100.0
@export var lives: int = 5
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next_level: int = 100
@export var void_fall_kill_y: float = DEFAULT_VOID_FALL_KILL_Y
@export var void_fov_margin_y: float = DEFAULT_VOID_FOV_MARGIN_Y

var is_attacking: bool = false
var facing_direction: int = 1
var hp: int = 100
var stamina: float = 100.0
var is_defending: bool = false
var attack_ground_stop_timer: float = 0.0
var attack_hitbox_area: Area2D = null
var attack_hitbox_shape: CollisionShape2D = null
var attack_hitbox_start_timer: float = 0.0
var attack_hitbox_active_timer: float = 0.0
var hit_enemy_ids: Dictionary = {}
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false
var death_hitstop_timer: float = 0.0
var death_shake_timer: float = 0.0
var death_anim_started: bool = false
var is_respawn_transition: bool = false
var death_countdown_active: bool = false
var death_countdown_value: int = 0
var death_countdown_timer: float = 0.0
var death_countdown_tremor_time: float = 0.0
var death_fx_tween: Tween = null
var base_sprite_scale: Vector2 = Vector2.ONE
var base_sprite_modulate: Color = Color(1, 1, 1, 1)
var death_overlay_layer: CanvasLayer = null
var death_overlay: ColorRect = null
var death_text_label: Label = null
var death_emoji_label: Label = null
var death_countdown_label: Label = null
var death_actions_row: HBoxContainer = null
var death_continue_button: Button = null
var death_quit_button: Button = null
var death_overlay_tween: Tween = null
var death_heartbeat_tween: Tween = null
var death_text_tween: Tween = null
var death_emoji_tween: Tween = null
var death_countdown_tween: Tween = null
var death_actions_tween: Tween = null
var death_message_delay_tween: Tween = null
var camera_zoom_tween: Tween = null
var player_respawn_fade_tween: Tween = null
var base_camera_zoom: Vector2 = Vector2.ONE
var death_intro_sfx_player: AudioStreamPlayer = null
var death_sfx_player: AudioStreamPlayer = null
var hurt_sfx_player: AudioStreamPlayer = null
var jump_sfx_player: AudioStreamPlayer = null
var death_countdown_sfx_player: AudioStreamPlayer = null
var health_bar_timer: float = 0.0
var health_fill_style: StyleBoxFlat = null
var hurt_flash_tween: Tween = null
var hp_regen_delay_timer: float = 0.0
var hp_regen_accumulator: float = 0.0
var defend_block_cooldown_timer: float = 0.0
var defend_triggered_this_frame: bool = false
var last_damage_source_tag: StringName = &""
var last_death_source_tag: StringName = &""
var spawn_dialog_layer: CanvasLayer = null
var spawn_dialog_root: Control = null
var spawn_dialog_panel: PanelContainer = null
var spawn_dialog_label: Label = null
var spawn_dialog_timer: float = 0.0
var spawn_dialog_tween: Tween = null
var spawn_dialog_queue: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("player")
	_configure_player_collision_filters()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_setup_attack_hitbox()
	_setup_cinematic_overlay()
	_setup_death_intro_sfx()
	_setup_death_sfx()
	_setup_hurt_sfx()
	_setup_jump_sfx()
	_setup_countdown_sfx()
	_setup_player_health_fill_style()
	_apply_vampire_percent_font()
	spawn_position = global_position
	base_sprite_scale = animated_sprite.scale
	base_sprite_modulate = animated_sprite.modulate
	if player_camera != null:
		base_camera_zoom = player_camera.zoom
	hp = max_hp
	stamina = max_stamina
	hp_regen_delay_timer = 0.0
	hp_regen_accumulator = 0.0
	_update_player_health_bar()
	if health_bar != null:
		health_bar.visible = false
	_apply_sprite_offset(&"idle")
	_play_animation(&"idle")
	_update_light_visuals(1.0, 0.0)
	_setup_spawn_dialog()
	_show_spawn_dialog_once()
	_emit_stats_changed()


func _physics_process(delta: float) -> void:
	_update_player_health_bar_timer(delta)
	_process_spawn_dialog(delta)
	defend_block_cooldown_timer = maxf(0.0, defend_block_cooldown_timer - delta)

	if is_dead:
		_process_death_state(delta)
		return

	if _check_void_fall_death():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_defend_state()

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_defending:
		velocity.y = JUMP_VELOCITY
		_play_jump_sfx()

	if Input.is_action_just_pressed("attack") and not is_attacking and not is_defending and stamina >= ATTACK_STAMINA_COST:
		_set_stamina(stamina - ATTACK_STAMINA_COST)
		_start_attack()

	var direction: float = Input.get_axis("left", "right")
	if is_defending:
		direction = 0.0

	var wants_sprint: bool = Input.is_action_pressed("sprint")
	var is_sprinting: bool = wants_sprint and not is_attacking and not is_defending and stamina > 0.0
	if is_sprinting:
		_set_stamina(stamina - SPRINT_STAMINA_DRAIN_RATE * delta)
		if stamina <= 0.0:
			is_sprinting = false
	else:
		_regenerate_stamina(delta)
	_process_health_regen(delta)
	var move_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED

	if direction != 0.0 and not is_defending:
		facing_direction = 1 if direction > 0.0 else -1
	animated_sprite.flip_h = facing_direction < 0
	_update_attack_hitbox_transform()

	if is_defending:
		var defend_deceleration: float = GROUND_DECELERATION if is_on_floor() else AIR_DECELERATION
		velocity.x = move_toward(velocity.x, 0.0, defend_deceleration * 1.2 * delta)
		if is_on_floor() and absf(velocity.x) < GROUND_STOP_EPSILON:
			velocity.x = 0.0
	elif is_attacking:
		if is_on_floor() and attack_ground_stop_timer > 0.0:
			attack_ground_stop_timer = maxf(0.0, attack_ground_stop_timer - delta)
			velocity.x = 0.0
		else:
			if attack_ground_stop_timer > 0.0:
				attack_ground_stop_timer = maxf(0.0, attack_ground_stop_timer - delta)

			if absf(direction) > MOVE_THRESHOLD:
				var attack_target_speed := direction * move_speed * ATTACK_SPEED_FACTOR
				var attack_acceleration := (GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION) * ATTACK_ACCELERATION_FACTOR
				velocity.x = move_toward(velocity.x, attack_target_speed, attack_acceleration * delta)
			else:
				if is_on_floor():
					# Prevent attack slide on ground when no movement input is pressed.
					velocity.x = 0.0
				else:
					var attack_deceleration := ATTACK_AIR_DECELERATION
					velocity.x = move_toward(velocity.x, 0.0, attack_deceleration * delta)
	else:
		if absf(direction) > MOVE_THRESHOLD:
			var target_speed := direction * move_speed
			var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
			velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		else:
			var deceleration := GROUND_DECELERATION if is_on_floor() else AIR_DECELERATION
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			if is_on_floor() and absf(velocity.x) < GROUND_STOP_EPSILON:
				velocity.x = 0.0

	move_and_slide()
	_update_attack_hitbox(delta)
	_update_animation(direction, is_sprinting)
	_update_light_visuals(delta, direction)


func _setup_spawn_dialog() -> void:
	if spawn_dialog_panel != null:
		return

	if spawn_dialog_layer == null:
		spawn_dialog_layer = CanvasLayer.new()
		spawn_dialog_layer.name = "SpawnDialogLayer"
		spawn_dialog_layer.layer = 130
		spawn_dialog_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(spawn_dialog_layer)

	if spawn_dialog_root == null:
		spawn_dialog_root = Control.new()
		spawn_dialog_root.name = "Root"
		spawn_dialog_root.anchor_left = 0.0
		spawn_dialog_root.anchor_top = 0.0
		spawn_dialog_root.anchor_right = 1.0
		spawn_dialog_root.anchor_bottom = 1.0
		spawn_dialog_root.offset_left = 0.0
		spawn_dialog_root.offset_top = 0.0
		spawn_dialog_root.offset_right = 0.0
		spawn_dialog_root.offset_bottom = 0.0
		spawn_dialog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spawn_dialog_layer.add_child(spawn_dialog_root)

	spawn_dialog_panel = PanelContainer.new()
	spawn_dialog_panel.name = "SpawnDialog"
	spawn_dialog_panel.top_level = false
	spawn_dialog_panel.visible = false
	spawn_dialog_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	spawn_dialog_panel.custom_minimum_size = Vector2(SPAWN_DIALOG_MIN_WIDTH, SPAWN_DIALOG_MIN_HEIGHT)
	spawn_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spawn_dialog_root.add_child(spawn_dialog_panel)

	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	bubble_style.border_width_left = 1
	bubble_style.border_width_top = 1
	bubble_style.border_width_right = 1
	bubble_style.border_width_bottom = 1
	bubble_style.border_color = Color(0.83, 0.7, 0.47, 0.9)
	bubble_style.corner_radius_top_left = 10
	bubble_style.corner_radius_top_right = 10
	bubble_style.corner_radius_bottom_right = 10
	bubble_style.corner_radius_bottom_left = 10
	bubble_style.content_margin_left = 8.0
	bubble_style.content_margin_top = 5.0
	bubble_style.content_margin_right = 8.0
	bubble_style.content_margin_bottom = 5.0
	spawn_dialog_panel.add_theme_stylebox_override("panel", bubble_style)

	spawn_dialog_label = Label.new()
	spawn_dialog_label.name = "DialogLabel"
	spawn_dialog_label.custom_minimum_size = Vector2(
		SPAWN_DIALOG_MIN_WIDTH - SPAWN_DIALOG_CONTENT_PADDING_X,
		SPAWN_DIALOG_MIN_HEIGHT - SPAWN_DIALOG_CONTENT_PADDING_Y
	)
	spawn_dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spawn_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spawn_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spawn_dialog_label.text = SPAWN_DIALOG_TEXT
	spawn_dialog_label.add_theme_font_size_override("font_size", SPAWN_DIALOG_FONT_SIZE)
	spawn_dialog_label.add_theme_constant_override("outline_size", 1)
	spawn_dialog_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.91, 1.0))
	spawn_dialog_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	spawn_dialog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spawn_dialog_label.add_theme_font_override("font", _create_dialog_font())
	spawn_dialog_panel.add_child(spawn_dialog_label)
	_apply_spawn_dialog_size_for_text(SPAWN_DIALOG_TEXT)
	_update_spawn_dialog_position()


func _show_spawn_dialog_once() -> void:
	queue_dialog_line(SPAWN_DIALOG_TEXT, SPAWN_DIALOG_DURATION)


func queue_dialog_line(text: String, duration: float = SPAWN_DIALOG_DURATION) -> void:
	if spawn_dialog_panel == null:
		_setup_spawn_dialog()
	if spawn_dialog_panel == null:
		return

	var normalized_text: String = text.strip_edges()
	if normalized_text.is_empty():
		return

	spawn_dialog_queue.append({
		"text": normalized_text,
		"duration": maxf(duration, 0.2)
	})
	_try_show_next_spawn_dialog()


func queue_dialog_lines(lines: Array[String], duration_per_line: float = SPAWN_DIALOG_DURATION) -> void:
	if lines.is_empty():
		return
	for line_text in lines:
		queue_dialog_line(line_text, duration_per_line)


func _try_show_next_spawn_dialog() -> void:
	if spawn_dialog_panel == null:
		return
	if spawn_dialog_panel.visible:
		return
	if spawn_dialog_queue.is_empty():
		return

	var dialog_data: Dictionary = spawn_dialog_queue.pop_front()
	var dialog_text: String = str(dialog_data.get("text", "")).strip_edges()
	if dialog_text.is_empty():
		_try_show_next_spawn_dialog()
		return

	spawn_dialog_timer = float(dialog_data.get("duration", SPAWN_DIALOG_DURATION))
	if spawn_dialog_label != null:
		spawn_dialog_label.text = dialog_text
	_apply_spawn_dialog_size_for_text(dialog_text)

	spawn_dialog_panel.visible = true
	spawn_dialog_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_update_spawn_dialog_position()
	if spawn_dialog_tween != null:
		spawn_dialog_tween.kill()
	spawn_dialog_tween = create_tween()
	spawn_dialog_tween.set_trans(Tween.TRANS_QUAD)
	spawn_dialog_tween.set_ease(Tween.EASE_OUT)
	spawn_dialog_tween.tween_property(spawn_dialog_panel, "modulate:a", 1.0, SPAWN_DIALOG_FADE_IN_TIME)


func _process_spawn_dialog(delta: float) -> void:
	if spawn_dialog_panel == null:
		return
	if spawn_dialog_panel.visible:
		_update_spawn_dialog_position()
	else:
		_try_show_next_spawn_dialog()
		return

	if spawn_dialog_timer < 0.0:
		return

	spawn_dialog_timer = maxf(0.0, spawn_dialog_timer - delta)
	if spawn_dialog_timer <= 0.0:
		spawn_dialog_timer = -1.0
		_hide_spawn_dialog()


func _hide_spawn_dialog() -> void:
	if spawn_dialog_panel == null or not spawn_dialog_panel.visible:
		return
	if spawn_dialog_tween != null:
		spawn_dialog_tween.kill()
	spawn_dialog_tween = create_tween()
	spawn_dialog_tween.set_trans(Tween.TRANS_QUAD)
	spawn_dialog_tween.set_ease(Tween.EASE_IN)
	spawn_dialog_tween.tween_property(spawn_dialog_panel, "modulate:a", 0.0, SPAWN_DIALOG_FADE_OUT_TIME)
	spawn_dialog_tween.tween_callback(Callable(self, "_finish_hide_spawn_dialog"))


func _finish_hide_spawn_dialog() -> void:
	if spawn_dialog_panel == null:
		return
	spawn_dialog_panel.visible = false
	_try_show_next_spawn_dialog()


func _update_spawn_dialog_position() -> void:
	if spawn_dialog_panel == null or spawn_dialog_root == null:
		return

	var viewport_size: Vector2 = spawn_dialog_root.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size

	var bubble_width: float = maxf(spawn_dialog_panel.custom_minimum_size.x, SPAWN_DIALOG_MIN_WIDTH)
	var bubble_height: float = maxf(spawn_dialog_panel.custom_minimum_size.y, SPAWN_DIALOG_MIN_HEIGHT)
	var target_x: float = (viewport_size.x - bubble_width) * 0.5
	var target_y: float = ((viewport_size.y - bubble_height) * 0.5) + SPAWN_DIALOG_SCREEN_CENTER_OFFSET_Y
	spawn_dialog_panel.position = Vector2(target_x, target_y)


func _create_dialog_font() -> Font:
	if ResourceLoader.exists(DEATH_TEXT_FONT_PATH):
		var loaded_font: Resource = load(DEATH_TEXT_FONT_PATH)
		if loaded_font is Font:
			return loaded_font as Font
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray([
		"Arial",
		"Liberation Sans",
		"DejaVu Sans",
		"Noto Sans",
		"sans-serif"
	])
	return system_font


func _apply_spawn_dialog_size_for_text(text: String) -> void:
	if spawn_dialog_panel == null or spawn_dialog_label == null:
		return

	var content_max_width: float = SPAWN_DIALOG_MAX_WIDTH - SPAWN_DIALOG_CONTENT_PADDING_X
	var lines: PackedStringArray = _wrap_spawn_dialog_text(text, content_max_width)
	if lines.is_empty():
		lines = PackedStringArray([""])

	var longest_width: float = 0.0
	for line_text in lines:
		longest_width = maxf(longest_width, _measure_spawn_dialog_text_width(line_text))

	var font_size: int = spawn_dialog_label.get_theme_font_size("font_size")
	var font: Font = spawn_dialog_label.get_theme_font("font")
	var line_height: float = float(font_size + 4)
	if font != null:
		line_height = maxf(line_height, font.get_height(font_size))

	var bubble_width: float = clampf(
		longest_width + SPAWN_DIALOG_CONTENT_PADDING_X,
		SPAWN_DIALOG_MIN_WIDTH,
		SPAWN_DIALOG_MAX_WIDTH
	)
	var bubble_height: float = maxf(
		SPAWN_DIALOG_MIN_HEIGHT,
		(line_height * float(lines.size())) + SPAWN_DIALOG_CONTENT_PADDING_Y
	)

	spawn_dialog_panel.custom_minimum_size = Vector2(bubble_width, bubble_height)
	spawn_dialog_label.custom_minimum_size = Vector2(
		bubble_width - SPAWN_DIALOG_CONTENT_PADDING_X,
		bubble_height - SPAWN_DIALOG_CONTENT_PADDING_Y
	)


func _wrap_spawn_dialog_text(text: String, max_width: float) -> PackedStringArray:
	var wrapped_lines := PackedStringArray()
	var base_lines: PackedStringArray = text.split("\n", false)
	if base_lines.is_empty():
		base_lines.append(text)

	for base_line in base_lines:
		var trimmed_line: String = base_line.strip_edges()
		if trimmed_line.is_empty():
			wrapped_lines.append("")
			continue

		var words: PackedStringArray = trimmed_line.split(" ", false)
		var current_line: String = ""
		for word in words:
			var candidate: String = word if current_line.is_empty() else ("%s %s" % [current_line, word])
			if current_line.is_empty() or _measure_spawn_dialog_text_width(candidate) <= max_width:
				current_line = candidate
			else:
				wrapped_lines.append(current_line)
				current_line = word
		if not current_line.is_empty():
			wrapped_lines.append(current_line)

	return wrapped_lines


func _measure_spawn_dialog_text_width(text: String) -> float:
	if spawn_dialog_label == null:
		return float(text.length()) * 7.0

	var font_size: int = spawn_dialog_label.get_theme_font_size("font_size")
	var font: Font = spawn_dialog_label.get_theme_font("font")
	if font == null:
		return float(text.length()) * 7.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func has_active_dialog() -> bool:
	if spawn_dialog_panel != null and spawn_dialog_panel.visible:
		return true
	return not spawn_dialog_queue.is_empty()


func _start_attack() -> void:
	if is_dead or is_defending:
		return

	is_attacking = true
	attack_ground_stop_timer = ATTACK_GROUND_STOP_TIME
	attack_hitbox_start_timer = ATTACK_HITBOX_START_DELAY
	attack_hitbox_active_timer = ATTACK_HITBOX_ACTIVE_TIME
	hit_enemy_ids.clear()
	_set_attack_hitbox_enabled(false)
	_apply_sprite_offset(&"attack")
	if is_on_floor():
		velocity.x = 0.0
	if is_instance_valid(attack_sfx):
		attack_sfx.stop()
		attack_sfx.play()
	if _has_animation(&"attack"):
		animated_sprite.play(&"attack")
		animated_sprite.speed_scale = ATTACK_SPEED_SCALE
	else:
		is_attacking = false


func _update_defend_state() -> void:
	defend_triggered_this_frame = false

	if is_dead or is_respawn_transition:
		is_defending = false
		return

	var defend_pressed: bool = Input.is_action_pressed("defend")
	var defend_just_pressed: bool = Input.is_action_just_pressed("defend")
	var can_defend: bool = is_on_floor() and not is_attacking and _has_animation(&"defend")
	defend_triggered_this_frame = defend_just_pressed and can_defend
	is_defending = defend_pressed and can_defend


func _update_animation(direction: float, is_sprinting: bool) -> void:
	if is_dead:
		_play_animation(&"death", 1.0)
		return

	if is_attacking:
		_apply_sprite_offset(&"attack")
		if animated_sprite.animation != &"attack":
			animated_sprite.play(&"attack")
		animated_sprite.speed_scale = ATTACK_SPEED_SCALE
		return

	if is_defending and _has_animation(&"defend"):
		_apply_sprite_offset(&"defend")
		if defend_triggered_this_frame:
			animated_sprite.play(&"defend")
			animated_sprite.frame = 0
			animated_sprite.frame_progress = 0.0
		elif animated_sprite.animation != &"defend":
			animated_sprite.play(&"defend")
		animated_sprite.speed_scale = 1.0
		return

	if not is_on_floor():
		_play_animation(&"jump", 1.0)
		return

	if absf(direction) > MOVE_THRESHOLD:
		if is_sprinting:
			var run_ratio := absf(velocity.x) / SPRINT_SPEED
			var run_anim_speed := clampf(run_ratio * 1.25, 0.9, 1.7)
			_play_animation(&"run", run_anim_speed)
		else:
			var walk_ratio := absf(velocity.x) / WALK_SPEED
			var walk_anim_speed := clampf(walk_ratio * 1.2, 0.9, 1.6)
			_play_animation(&"walk", walk_anim_speed)
	else:
		_play_animation(&"idle", 1.0)


func _play_animation(animation_name: StringName, speed_scale: float = 1.0) -> void:
	if not _has_animation(animation_name):
		return
	_apply_sprite_offset(animation_name)
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	animated_sprite.speed_scale = speed_scale


func _has_animation(animation_name: StringName) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)


func _apply_sprite_offset(animation_name: StringName) -> void:
	if animation_name == &"attack":
		animated_sprite.offset = ATTACK_SPRITE_OFFSET
	else:
		animated_sprite.offset = BASE_SPRITE_OFFSET


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"attack":
		is_attacking = false
		attack_ground_stop_timer = 0.0
		_set_attack_hitbox_enabled(false)
		animated_sprite.offset = BASE_SPRITE_OFFSET
	elif animated_sprite.animation == &"death" and is_dead:
		_start_death_countdown()


func _set_stamina(value: float) -> void:
	var clamped_stamina := clampf(value, 0.0, max_stamina)
	if is_equal_approx(stamina, clamped_stamina):
		return
	stamina = clamped_stamina
	_emit_stats_changed()


func _regenerate_stamina(delta: float) -> void:
	_set_stamina(stamina + STAMINA_REGEN_RATE * delta)


func _process_health_regen(delta: float) -> void:
	if hp <= 0 or hp >= max_hp:
		hp_regen_accumulator = 0.0
		return

	if hp_regen_delay_timer > 0.0:
		hp_regen_delay_timer = maxf(0.0, hp_regen_delay_timer - delta)
		return

	hp_regen_accumulator += HP_REGEN_PER_SECOND * delta
	var heal_steps: int = int(floor(hp_regen_accumulator))
	if heal_steps <= 0:
		return

	hp_regen_accumulator -= float(heal_steps)
	var next_hp: int = mini(max_hp, hp + heal_steps)
	if next_hp == hp:
		return

	hp = next_hp
	_update_player_health_bar()
	_emit_stats_changed()


func _check_void_fall_death() -> bool:
	if is_dead or is_respawn_transition:
		return false

	var kill_threshold_y: float = void_fall_kill_y
	if player_camera != null:
		var viewport_height: float = get_viewport_rect().size.y
		var camera_half_height: float = viewport_height * 0.5 * player_camera.zoom.y
		var fov_bottom_y: float = player_camera.get_screen_center_position().y + camera_half_height
		kill_threshold_y = minf(kill_threshold_y, fov_bottom_y + void_fov_margin_y)

	if global_position.y <= kill_threshold_y:
		return false

	_trigger_void_death()
	return true


func _trigger_void_death() -> void:
	if is_dead:
		return

	last_damage_source_tag = &"void"
	hp = 0
	hp_regen_delay_timer = 0.0
	hp_regen_accumulator = 0.0
	_update_player_health_bar()
	_emit_stats_changed()
	_start_death()


func take_damage(amount: int, from_position: Vector2 = Vector2.INF, damage_source_tag: StringName = &"") -> void:
	if amount <= 0 or hp <= 0 or is_dead:
		return

	if _try_block_damage(amount, from_position, damage_source_tag):
		return

	last_damage_source_tag = damage_source_tag
	hp = maxi(0, hp - amount)
	hp_regen_delay_timer = HP_REGEN_DELAY_AFTER_HIT
	hp_regen_accumulator = 0.0
	_play_hurt_sfx()
	_play_hurt_flash()
	_apply_hit_knockback(from_position)
	_show_player_health_bar()
	_update_player_health_bar()
	if hp == 0:
		_start_death()

	_emit_stats_changed()


func _try_block_damage(amount: int, from_position: Vector2, damage_source_tag: StringName = &"") -> bool:
	if not _is_defending_active():
		return false

	if defend_block_cooldown_timer > 0.0:
		return true

	defend_block_cooldown_timer = DEFEND_BLOCK_COOLDOWN
	_apply_defend_knockback(from_position)

	var blocked_damage: int = maxi(DEFEND_BLOCK_MIN_DAMAGE, int(round(float(amount) * DEFEND_BLOCK_DAMAGE_MULTIPLIER)))
	if blocked_damage <= 0:
		return true

	last_damage_source_tag = damage_source_tag
	hp = maxi(0, hp - blocked_damage)
	hp_regen_delay_timer = HP_REGEN_DELAY_AFTER_HIT
	hp_regen_accumulator = 0.0
	_play_hurt_sfx()
	_play_hurt_flash()
	_show_player_health_bar()
	_update_player_health_bar()
	if hp == 0:
		_start_death()
	_emit_stats_changed()
	return true


func _is_defending_active() -> bool:
	return is_defending and not is_dead and not is_respawn_transition and _has_animation(&"defend")


func _apply_defend_knockback(from_position: Vector2) -> void:
	var push_dir: float = -float(facing_direction)
	if from_position != Vector2.INF:
		if global_position.x > from_position.x:
			push_dir = 1.0
		elif global_position.x < from_position.x:
			push_dir = -1.0
	if is_zero_approx(push_dir):
		push_dir = -float(facing_direction)

	velocity.x = push_dir * DEFEND_BLOCK_PUSHBACK_X
	if is_on_floor():
		velocity.y = 0.0


func _emit_stats_changed() -> void:
	stats_changed.emit(hp, max_hp, stamina, max_stamina, lives)


func get_last_death_source_tag() -> StringName:
	return last_death_source_tag


func _update_light_visuals(_delta: float, _direction: float) -> void:
	# Iluminacao do player removida: usamos apenas iluminacao global da cena.
	return


func _setup_player_health_fill_style() -> void:
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

	if ResourceLoader.exists(DEATH_TEXT_FONT_PATH):
		var loaded_font: Resource = load(DEATH_TEXT_FONT_PATH)
		if loaded_font is Font:
			health_percent_label.add_theme_font_override("font", loaded_font as Font)

	health_percent_label.add_theme_font_size_override("font_size", HEALTH_PERCENT_FONT_SIZE)
	health_percent_label.add_theme_constant_override("outline_size", HEALTH_PERCENT_OUTLINE_SIZE)
	health_percent_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 0.98))
	health_percent_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))


func _update_player_health_bar() -> void:
	if health_fill == null:
		return

	var ratio: float = 0.0
	if max_hp > 0:
		ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)

	health_fill.size.x = PLAYER_HEALTH_BAR_WIDTH * ratio
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


func _show_player_health_bar() -> void:
	health_bar_timer = PLAYER_HEALTH_BAR_VISIBLE_TIME
	if health_bar != null:
		health_bar.visible = true


func _update_player_health_bar_timer(delta: float) -> void:
	if health_bar == null or not health_bar.visible:
		return
	health_bar_timer = maxf(0.0, health_bar_timer - delta)
	if health_bar_timer <= 0.0:
		health_bar.visible = false


func _setup_attack_hitbox() -> void:
	attack_hitbox_area = Area2D.new()
	attack_hitbox_area.name = "AttackHitbox"
	attack_hitbox_area.collision_layer = 0
	attack_hitbox_area.collision_mask = ENEMY_LAYER_MASK
	attack_hitbox_area.monitoring = true
	attack_hitbox_area.monitorable = false
	add_child(attack_hitbox_area)

	attack_hitbox_shape = CollisionShape2D.new()
	attack_hitbox_shape.name = "CollisionShape2D"
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = Vector2(ATTACK_HITBOX_WIDTH, ATTACK_HITBOX_HEIGHT)
	attack_hitbox_shape.shape = attack_shape
	attack_hitbox_area.add_child(attack_hitbox_shape)
	_set_attack_hitbox_enabled(false)
	_update_attack_hitbox_transform()


func _configure_player_collision_filters() -> void:
	collision_layer = PLAYER_LAYER_MASK
	collision_mask = PLAYER_COLLISION_MASK


func _update_attack_hitbox_transform() -> void:
	if attack_hitbox_area == null:
		return
	attack_hitbox_area.position = Vector2(ATTACK_HITBOX_OFFSET_X * float(facing_direction), ATTACK_HITBOX_OFFSET_Y)


func _update_attack_hitbox(delta: float) -> void:
	if attack_hitbox_area == null or attack_hitbox_shape == null:
		return

	if not is_attacking:
		_set_attack_hitbox_enabled(false)
		return

	if attack_hitbox_start_timer > 0.0:
		attack_hitbox_start_timer = maxf(0.0, attack_hitbox_start_timer - delta)
		if attack_hitbox_start_timer <= 0.0:
			_set_attack_hitbox_enabled(true)

	if attack_hitbox_active_timer > 0.0:
		attack_hitbox_active_timer = maxf(0.0, attack_hitbox_active_timer - delta)
		if not attack_hitbox_shape.disabled:
			_apply_attack_damage()
		if attack_hitbox_active_timer <= 0.0:
			_set_attack_hitbox_enabled(false)


func _apply_attack_damage() -> void:
	if attack_hitbox_area == null:
		return

	for body in attack_hitbox_area.get_overlapping_bodies():
		if body == self or not (body is Node):
			continue
		if not body.is_in_group("enemies"):
			continue
		var body_id := body.get_instance_id()
		if hit_enemy_ids.has(body_id):
			continue
		if body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE, global_position)
			hit_enemy_ids[body_id] = true


func _set_attack_hitbox_enabled(enabled: bool) -> void:
	if attack_hitbox_shape != null:
		attack_hitbox_shape.disabled = not enabled


func _apply_hit_knockback(from_position: Vector2) -> void:
	if from_position == Vector2.INF:
		return

	var push_dir: float = 0.0
	if global_position.x > from_position.x:
		push_dir = 1.0
	elif global_position.x < from_position.x:
		push_dir = -1.0
	if is_zero_approx(push_dir):
		push_dir = -float(facing_direction)

	velocity.x = push_dir * HIT_KNOCKBACK_X * DAMAGE_KNOCKBACK_MULTIPLIER
	velocity.y = minf(velocity.y, HIT_KNOCKBACK_Y * DAMAGE_KNOCKBACK_MULTIPLIER)


func _start_death() -> void:
	if is_dead:
		return

	if lives > 0:
		lives -= 1
	lives = maxi(lives, 0)

	is_dead = true
	is_attacking = false
	is_defending = false
	death_anim_started = false
	is_respawn_transition = false
	death_countdown_active = false
	death_countdown_value = 0
	death_countdown_timer = 0.0
	death_countdown_tremor_time = 0.0
	death_hitstop_timer = DEATH_HITSTOP_TIME
	death_shake_timer = DEATH_SHAKE_TIME
	attack_ground_stop_timer = 0.0
	attack_hitbox_start_timer = 0.0
	attack_hitbox_active_timer = 0.0
	hit_enemy_ids.clear()
	_set_attack_hitbox_enabled(false)
	if death_countdown_tween != null:
		death_countdown_tween.kill()
		death_countdown_tween = null
	if death_heartbeat_tween != null:
		death_heartbeat_tween.kill()
		death_heartbeat_tween = null
	if death_countdown_sfx_player != null:
		death_countdown_sfx_player.stop()
	if hurt_sfx_player != null:
		hurt_sfx_player.stop()
	if death_message_delay_tween != null:
		death_message_delay_tween.kill()
		death_message_delay_tween = null
	if player_respawn_fade_tween != null:
		player_respawn_fade_tween.kill()
		player_respawn_fade_tween = null
	if death_countdown_label != null:
		death_countdown_label.text = ""
		var clear_count_color: Color = DEATH_COUNTDOWN_COLOR
		clear_count_color.a = 0.0
		death_countdown_label.modulate = clear_count_color
		death_countdown_label.rotation_degrees = 0.0
		death_countdown_label.scale = DEATH_COUNTDOWN_END_SCALE
	if death_text_label != null:
		death_text_label.text = DEATH_TEXT
	if death_emoji_label != null:
		death_emoji_label.text = DEATH_EMOJI_TEXT
	_hide_death_action_buttons()
	if health_bar != null:
		health_bar.visible = false
	health_bar_timer = 0.0
	hp_regen_delay_timer = 0.0
	hp_regen_accumulator = 0.0
	defend_block_cooldown_timer = 0.0
	velocity = Vector2.ZERO
	last_death_source_tag = last_damage_source_tag
	_emit_stats_changed()
	died.emit()

	_start_death_visual_fx()


func _process_death_state(delta: float) -> void:
	_update_death_camera_shake(delta)

	if is_respawn_transition:
		_update_light_visuals(delta, 0.0)
		return

	if death_hitstop_timer > 0.0:
		death_hitstop_timer = maxf(0.0, death_hitstop_timer - delta)
		if death_hitstop_timer <= 0.0 and not death_anim_started:
			_play_death_animation_or_fallback()
		return

	if not death_anim_started:
		_play_death_animation_or_fallback()

	velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_update_light_visuals(delta, 0.0)

	_process_death_countdown(delta)


func _respawn_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	hp = max_hp
	stamina = max_stamina
	hp_regen_delay_timer = 0.0
	hp_regen_accumulator = 0.0
	_update_player_health_bar()
	if health_bar != null:
		health_bar.visible = false
	health_bar_timer = 0.0
	is_attacking = false
	is_defending = false
	attack_ground_stop_timer = 0.0
	attack_hitbox_start_timer = 0.0
	attack_hitbox_active_timer = 0.0
	death_hitstop_timer = 0.0
	death_shake_timer = 0.0
	death_anim_started = false
	death_countdown_active = false
	death_countdown_value = 0
	death_countdown_timer = 0.0
	death_countdown_tremor_time = 0.0
	hit_enemy_ids.clear()
	defend_block_cooldown_timer = 0.0
	_set_attack_hitbox_enabled(false)
	if death_fx_tween != null:
		death_fx_tween.kill()
		death_fx_tween = null
	if death_countdown_tween != null:
		death_countdown_tween.kill()
		death_countdown_tween = null
	if death_heartbeat_tween != null:
		death_heartbeat_tween.kill()
		death_heartbeat_tween = null
	if death_message_delay_tween != null:
		death_message_delay_tween.kill()
		death_message_delay_tween = null
	if camera_zoom_tween != null:
		camera_zoom_tween.kill()
		camera_zoom_tween = null
	if player_respawn_fade_tween != null:
		player_respawn_fade_tween.kill()
		player_respawn_fade_tween = null
	if death_text_tween != null:
		death_text_tween.kill()
		death_text_tween = null
	if death_emoji_tween != null:
		death_emoji_tween.kill()
		death_emoji_tween = null
	if death_countdown_sfx_player != null:
		death_countdown_sfx_player.stop()
	if death_intro_sfx_player != null:
		death_intro_sfx_player.stop()
	if death_sfx_player != null:
		death_sfx_player.stop()
	if hurt_sfx_player != null:
		hurt_sfx_player.stop()
	animated_sprite.scale = base_sprite_scale
	var respawn_color: Color = base_sprite_modulate
	respawn_color.a = 0.0
	animated_sprite.modulate = respawn_color
	_fade_out_cinematic_overlay()
	_fade_out_death_text()
	_fade_out_death_emoji()
	_fade_out_death_countdown()
	_hide_death_action_buttons()
	_reset_camera_zoom()
	_reset_camera_shake()
	_apply_sprite_offset(&"idle")
	_play_animation(&"idle", 1.0)
	_start_player_fade_in_after_respawn()


func _start_death_visual_fx() -> void:
	if death_fx_tween != null:
		death_fx_tween.kill()

	animated_sprite.scale = base_sprite_scale * 1.12
	animated_sprite.modulate = DEATH_FLASH_COLOR

	death_fx_tween = create_tween()
	death_fx_tween.set_trans(Tween.TRANS_QUAD)
	death_fx_tween.set_ease(Tween.EASE_OUT)
	death_fx_tween.tween_property(animated_sprite, "scale", base_sprite_scale * 0.92, 0.09)
	death_fx_tween.parallel().tween_property(animated_sprite, "modulate", DEATH_DIM_COLOR, 0.12)
	death_fx_tween.tween_property(animated_sprite, "scale", base_sprite_scale, 0.14)
	_start_cinematic_overlay_fx()
	_start_death_camera_zoom_fx()
	_play_death_intro_sfx()
	_schedule_death_message_fx()


func _schedule_death_message_fx() -> void:
	if death_message_delay_tween != null:
		death_message_delay_tween.kill()

	var delay: float = DEATH_MESSAGE_DELAY
	if death_intro_sfx_player != null and death_intro_sfx_player.stream != null:
		var intro_length: float = death_intro_sfx_player.stream.get_length()
		if intro_length > 0.0:
			delay = clampf(intro_length + 0.02, DEATH_MESSAGE_DELAY, 2.0)

	death_message_delay_tween = create_tween()
	death_message_delay_tween.tween_interval(delay)
	death_message_delay_tween.tween_callback(Callable(self, "_play_death_message_fx"))


func _play_death_message_fx() -> void:
	if not is_dead or is_respawn_transition:
		return

	_start_death_text_fx()
	_start_death_emoji_fx()
	_play_death_sfx()


func _play_death_animation_or_fallback() -> void:
	death_anim_started = true
	if _has_animation(&"death"):
		_apply_sprite_offset(&"death")
		animated_sprite.play(&"death")
		animated_sprite.speed_scale = 1.0
	else:
		_start_death_countdown()


func _update_death_camera_shake(delta: float) -> void:
	if player_camera == null:
		return

	death_shake_timer = maxf(0.0, death_shake_timer - delta)
	if death_shake_timer > 0.0:
		var shake_ratio := death_shake_timer / DEATH_SHAKE_TIME
		var amplitude := DEATH_SHAKE_STRENGTH * shake_ratio
		player_camera.offset = Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
	else:
		_reset_camera_shake()


func _reset_camera_shake() -> void:
	if player_camera != null:
		player_camera.offset = Vector2.ZERO


func _setup_cinematic_overlay() -> void:
	if death_overlay_layer != null and death_overlay != null and death_text_label != null and death_emoji_label != null and death_countdown_label != null and death_actions_row != null and death_continue_button != null and death_quit_button != null:
		return

	death_overlay_layer = CanvasLayer.new()
	death_overlay_layer.name = "DeathOverlayLayer"
	death_overlay_layer.layer = 120
	add_child(death_overlay_layer)

	death_overlay = ColorRect.new()
	death_overlay.name = "DeathOverlay"
	death_overlay.anchor_left = 0.0
	death_overlay.anchor_top = 0.0
	death_overlay.anchor_right = 1.0
	death_overlay.anchor_bottom = 1.0
	death_overlay.offset_left = 0.0
	death_overlay.offset_top = 0.0
	death_overlay.offset_right = 0.0
	death_overlay.offset_bottom = 0.0
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.color = DEATH_OVERLAY_COLOR
	death_overlay_layer.add_child(death_overlay)

	death_text_label = Label.new()
	death_text_label.name = "DeathText"
	death_text_label.anchor_left = 0.0
	death_text_label.anchor_top = 0.0
	death_text_label.anchor_right = 1.0
	death_text_label.anchor_bottom = 1.0
	death_text_label.offset_left = 0.0
	death_text_label.offset_top = DEATH_TEXT_Y_OFFSET
	death_text_label.offset_right = 0.0
	death_text_label.offset_bottom = DEATH_TEXT_Y_OFFSET
	death_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_text_label.text = DEATH_TEXT
	death_text_label.modulate = DEATH_TEXT_COLOR
	death_text_label.scale = DEATH_TEXT_START_SCALE
	var death_font := _create_gothic_death_font()
	if death_font != null:
		death_text_label.add_theme_font_override("font", death_font)
	death_text_label.add_theme_font_size_override("font_size", 66)
	death_text_label.add_theme_constant_override("outline_size", 10)
	death_text_label.add_theme_color_override("font_outline_color", DEATH_TEXT_OUTLINE_COLOR)
	death_text_label.add_theme_color_override("font_shadow_color", DEATH_TEXT_SHADOW_COLOR)
	death_text_label.add_theme_constant_override("shadow_offset_x", 5)
	death_text_label.add_theme_constant_override("shadow_offset_y", 5)
	death_overlay_layer.add_child(death_text_label)

	death_emoji_label = Label.new()
	death_emoji_label.name = "DeathEmoji"
	death_emoji_label.anchor_left = 0.0
	death_emoji_label.anchor_top = 0.0
	death_emoji_label.anchor_right = 1.0
	death_emoji_label.anchor_bottom = 1.0
	death_emoji_label.offset_left = 0.0
	death_emoji_label.offset_top = DEATH_EMOJI_Y_OFFSET
	death_emoji_label.offset_right = 0.0
	death_emoji_label.offset_bottom = DEATH_EMOJI_Y_OFFSET
	death_emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_emoji_label.text = DEATH_EMOJI_TEXT
	death_emoji_label.modulate = DEATH_EMOJI_COLOR
	death_emoji_label.scale = DEATH_EMOJI_START_SCALE
	if death_font != null:
		death_emoji_label.add_theme_font_override("font", death_font)
	death_emoji_label.add_theme_font_size_override("font_size", 52)
	death_emoji_label.add_theme_constant_override("outline_size", 7)
	death_emoji_label.add_theme_color_override("font_outline_color", DEATH_TEXT_OUTLINE_COLOR)
	death_emoji_label.add_theme_color_override("font_shadow_color", DEATH_TEXT_SHADOW_COLOR)
	death_overlay_layer.add_child(death_emoji_label)

	death_countdown_label = Label.new()
	death_countdown_label.name = "DeathCountdown"
	death_countdown_label.anchor_left = 0.0
	death_countdown_label.anchor_top = 0.0
	death_countdown_label.anchor_right = 1.0
	death_countdown_label.anchor_bottom = 1.0
	death_countdown_label.offset_left = 0.0
	death_countdown_label.offset_top = DEATH_COUNTDOWN_Y_OFFSET
	death_countdown_label.offset_right = 0.0
	death_countdown_label.offset_bottom = DEATH_COUNTDOWN_Y_OFFSET
	death_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_countdown_label.text = ""
	death_countdown_label.modulate = DEATH_COUNTDOWN_COLOR
	death_countdown_label.scale = DEATH_COUNTDOWN_START_SCALE
	if death_font != null:
		death_countdown_label.add_theme_font_override("font", death_font)
	death_countdown_label.add_theme_font_size_override("font_size", 58)
	death_countdown_label.add_theme_constant_override("outline_size", 6)
	death_countdown_label.add_theme_color_override("font_outline_color", DEATH_TEXT_OUTLINE_COLOR)
	death_countdown_label.add_theme_color_override("font_shadow_color", DEATH_TEXT_SHADOW_COLOR)
	death_countdown_label.add_theme_constant_override("shadow_offset_x", 3)
	death_countdown_label.add_theme_constant_override("shadow_offset_y", 3)
	death_overlay_layer.add_child(death_countdown_label)

	death_actions_row = HBoxContainer.new()
	death_actions_row.name = "DeathActions"
	death_actions_row.anchor_left = 0.0
	death_actions_row.anchor_top = 0.5
	death_actions_row.anchor_right = 1.0
	death_actions_row.anchor_bottom = 0.5
	death_actions_row.offset_left = 0.0
	death_actions_row.offset_top = DEATH_ACTIONS_Y_OFFSET
	death_actions_row.offset_right = 0.0
	death_actions_row.offset_bottom = DEATH_ACTIONS_Y_OFFSET + DEATH_ACTIONS_ROW_HEIGHT
	death_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	death_actions_row.mouse_filter = Control.MOUSE_FILTER_STOP
	death_actions_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	death_actions_row.visible = false
	death_actions_row.modulate = Color(1.0, 1.0, 1.0, 0.0)
	death_actions_row.add_theme_constant_override("separation", DEATH_ACTIONS_BUTTON_SPACING)
	death_overlay_layer.add_child(death_actions_row)

	death_continue_button = Button.new()
	death_continue_button.name = "ContinueButton"
	death_continue_button.text = "Continuar"
	_configure_death_action_button(death_continue_button, true, death_font)
	death_continue_button.pressed.connect(_on_death_continue_pressed)
	death_actions_row.add_child(death_continue_button)

	death_quit_button = Button.new()
	death_quit_button.name = "QuitButton"
	death_quit_button.text = "Sair"
	_configure_death_action_button(death_quit_button, false, death_font)
	death_quit_button.pressed.connect(_on_death_quit_pressed)
	death_actions_row.add_child(death_quit_button)


func _start_cinematic_overlay_fx() -> void:
	if death_overlay == null:
		return

	_stop_death_heartbeat_overlay()
	if death_overlay_tween != null:
		death_overlay_tween.kill()

	death_overlay.color = DEATH_OVERLAY_COLOR
	death_overlay_tween = create_tween()
	death_overlay_tween.set_trans(Tween.TRANS_QUAD)
	death_overlay_tween.set_ease(Tween.EASE_OUT)
	death_overlay_tween.tween_property(death_overlay, "color:a", DEATH_OVERLAY_PEAK_ALPHA, 0.13)
	death_overlay_tween.tween_property(death_overlay, "color:a", DEATH_OVERLAY_HOLD_ALPHA, 0.2)


func _fade_out_cinematic_overlay() -> void:
	if death_overlay == null:
		return

	_stop_death_heartbeat_overlay(false)
	if death_overlay_tween != null:
		death_overlay_tween.kill()

	death_overlay_tween = create_tween()
	death_overlay_tween.set_trans(Tween.TRANS_QUAD)
	death_overlay_tween.set_ease(Tween.EASE_OUT)
	death_overlay_tween.tween_property(death_overlay, "color:a", 0.0, DEATH_OVERLAY_FADE_OUT_TIME)


func _pulse_death_heartbeat_overlay() -> void:
	if death_overlay == null:
		return

	if death_heartbeat_tween != null:
		death_heartbeat_tween.kill()
		death_heartbeat_tween = null

	var pulse_color: Color = DEATH_HEARTBEAT_OVERLAY_COLOR
	pulse_color.a = DEATH_HEARTBEAT_BASE_ALPHA
	death_overlay.color = pulse_color

	death_heartbeat_tween = create_tween()
	death_heartbeat_tween.set_trans(Tween.TRANS_QUAD)
	death_heartbeat_tween.set_ease(Tween.EASE_OUT)
	death_heartbeat_tween.tween_property(death_overlay, "color:a", DEATH_HEARTBEAT_PEAK_ALPHA, DEATH_HEARTBEAT_IN_TIME)
	death_heartbeat_tween.tween_property(death_overlay, "color:a", DEATH_HEARTBEAT_BASE_ALPHA, DEATH_HEARTBEAT_OUT_TIME)


func _stop_death_heartbeat_overlay(reset_overlay: bool = true) -> void:
	if death_heartbeat_tween != null:
		death_heartbeat_tween.kill()
		death_heartbeat_tween = null

	if not reset_overlay:
		return
	if death_overlay == null:
		return

	var clear_color: Color = DEATH_OVERLAY_COLOR
	clear_color.a = 0.0
	death_overlay.color = clear_color


func _start_death_text_fx() -> void:
	if death_text_label == null:
		return

	if death_text_tween != null:
		death_text_tween.kill()

	var text_color: Color = DEATH_TEXT_COLOR
	text_color.a = 0.0
	death_text_label.modulate = text_color
	death_text_label.scale = DEATH_TEXT_START_SCALE

	death_text_tween = create_tween()
	death_text_tween.set_trans(Tween.TRANS_QUAD)
	death_text_tween.set_ease(Tween.EASE_OUT)
	death_text_tween.tween_property(death_text_label, "scale", DEATH_TEXT_END_SCALE, DEATH_TEXT_IN_TIME)
	death_text_tween.parallel().tween_property(death_text_label, "modulate:a", DEATH_TEXT_HOLD_ALPHA, DEATH_TEXT_IN_TIME)


func _fade_out_death_text() -> void:
	if death_text_label == null:
		return

	if death_text_tween != null:
		death_text_tween.kill()

	death_text_tween = create_tween()
	death_text_tween.set_trans(Tween.TRANS_QUAD)
	death_text_tween.set_ease(Tween.EASE_OUT)
	death_text_tween.tween_property(death_text_label, "modulate:a", 0.0, DEATH_TEXT_FADE_OUT_TIME)


func _start_death_emoji_fx() -> void:
	if death_emoji_label == null:
		return

	if death_emoji_tween != null:
		death_emoji_tween.kill()

	var emoji_color: Color = DEATH_EMOJI_COLOR
	emoji_color.a = 0.0
	death_emoji_label.modulate = emoji_color
	death_emoji_label.scale = DEATH_EMOJI_START_SCALE

	death_emoji_tween = create_tween()
	death_emoji_tween.set_trans(Tween.TRANS_QUAD)
	death_emoji_tween.set_ease(Tween.EASE_OUT)
	death_emoji_tween.tween_property(death_emoji_label, "scale", DEATH_EMOJI_END_SCALE, DEATH_EMOJI_IN_TIME)
	death_emoji_tween.parallel().tween_property(death_emoji_label, "modulate:a", DEATH_EMOJI_HOLD_ALPHA, DEATH_EMOJI_IN_TIME)


func _fade_out_death_emoji() -> void:
	if death_emoji_label == null:
		return

	if death_emoji_tween != null:
		death_emoji_tween.kill()

	death_emoji_tween = create_tween()
	death_emoji_tween.set_trans(Tween.TRANS_QUAD)
	death_emoji_tween.set_ease(Tween.EASE_OUT)
	death_emoji_tween.tween_property(death_emoji_label, "modulate:a", 0.0, DEATH_EMOJI_FADE_OUT_TIME)


func _start_death_countdown() -> void:
	if death_countdown_label == null or is_respawn_transition:
		return
	if death_countdown_active:
		return

	death_countdown_active = true
	death_countdown_value = DEATH_COUNTDOWN_START
	death_countdown_timer = DEATH_COUNTDOWN_STEP_TIME
	death_countdown_tremor_time = 0.0
	_stop_death_heartbeat_overlay()
	_show_countdown_value()
	_hide_death_action_buttons()


func _process_death_countdown(delta: float) -> void:
	if not death_countdown_active or is_respawn_transition:
		return

	death_countdown_tremor_time += delta
	_update_countdown_tremor()

	death_countdown_timer = maxf(0.0, death_countdown_timer - delta)
	if death_countdown_timer > 0.0:
		return

	death_countdown_value -= 1
	if death_countdown_value <= 0:
		death_countdown_active = false
		_stop_death_heartbeat_overlay()
		_reset_countdown_tremor()
		_fade_out_death_countdown()
		if lives > 0:
			_start_player_fade_out_for_respawn()
		else:
			_enter_death_timeout_mode()
	else:
		death_countdown_timer = DEATH_COUNTDOWN_STEP_TIME
		_show_countdown_value()


func _show_countdown_value() -> void:
	if death_countdown_label == null:
		return

	death_countdown_label.text = str(death_countdown_value)
	if death_countdown_tween != null:
		death_countdown_tween.kill()

	var count_color: Color = DEATH_COUNTDOWN_COLOR
	count_color.a = 0.0
	death_countdown_label.modulate = count_color
	death_countdown_label.scale = DEATH_COUNTDOWN_START_SCALE

	death_countdown_tween = create_tween()
	death_countdown_tween.set_trans(Tween.TRANS_QUAD)
	death_countdown_tween.set_ease(Tween.EASE_OUT)
	death_countdown_tween.tween_property(death_countdown_label, "scale", DEATH_COUNTDOWN_END_SCALE, DEATH_COUNTDOWN_IN_TIME)
	death_countdown_tween.parallel().tween_property(death_countdown_label, "modulate:a", 0.98, DEATH_COUNTDOWN_IN_TIME)
	_pulse_death_heartbeat_overlay()
	_play_countdown_sfx()


func _fade_out_death_countdown() -> void:
	if death_countdown_label == null:
		return

	if death_countdown_tween != null:
		death_countdown_tween.kill()

	death_countdown_tween = create_tween()
	death_countdown_tween.set_trans(Tween.TRANS_QUAD)
	death_countdown_tween.set_ease(Tween.EASE_OUT)
	death_countdown_tween.tween_property(death_countdown_label, "modulate:a", 0.0, DEATH_COUNTDOWN_FADE_OUT_TIME)
	death_countdown_tween.tween_callback(Callable(self, "_reset_countdown_tremor"))


func _show_death_action_buttons(show_continue_button: bool = true, show_quit_button: bool = true, continue_text_value: String = DEATH_CONTINUE_TEXT) -> void:
	if death_actions_row == null:
		return

	if death_actions_tween != null:
		death_actions_tween.kill()
		death_actions_tween = null

	death_actions_row.visible = true
	death_actions_row.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if death_continue_button != null:
		death_continue_button.text = continue_text_value
		death_continue_button.visible = show_continue_button
		death_continue_button.disabled = not show_continue_button
	if death_quit_button != null:
		death_quit_button.visible = show_quit_button
		death_quit_button.disabled = not show_quit_button

	death_actions_tween = create_tween()
	death_actions_tween.set_trans(Tween.TRANS_QUAD)
	death_actions_tween.set_ease(Tween.EASE_OUT)
	death_actions_tween.tween_property(death_actions_row, "modulate:a", 1.0, DEATH_ACTIONS_FADE_IN_TIME)


func _enter_death_timeout_mode() -> void:
	if not is_dead or is_respawn_transition:
		return
	if death_text_label != null:
		death_text_label.text = GAME_OVER_TEXT
	if death_emoji_label != null:
		death_emoji_label.text = GAME_OVER_EMOJI_TEXT
	_start_death_text_fx()
	_start_death_emoji_fx()
	_show_death_action_buttons(true, false, DEATH_NEW_GAME_TEXT)


func _hide_death_action_buttons() -> void:
	if death_actions_row == null:
		return

	if death_actions_tween != null:
		death_actions_tween.kill()
		death_actions_tween = null

	if death_continue_button != null:
		death_continue_button.visible = true
		death_continue_button.disabled = true
	if death_quit_button != null:
		death_quit_button.visible = true
		death_quit_button.disabled = true
	death_actions_row.visible = false
	death_actions_row.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _configure_death_action_button(button: Button, is_primary: bool, death_font: Font) -> void:
	if button == null:
		return

	button.custom_minimum_size = Vector2(DEATH_ACTIONS_BUTTON_WIDTH, DEATH_ACTIONS_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if death_font != null:
		button.add_theme_font_override("font", death_font)
	button.add_theme_font_size_override("font_size", DEATH_ACTIONS_BUTTON_FONT_SIZE)
	button.add_theme_constant_override("outline_size", DEATH_ACTIONS_BUTTON_OUTLINE_SIZE)
	button.add_theme_color_override("font_outline_color", DEATH_TEXT_OUTLINE_COLOR)
	button.add_theme_color_override("font_shadow_color", DEATH_TEXT_SHADOW_COLOR)
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.92, 0.98))

	var normal_bg: Color = Color(0.35, 0.06, 0.07, 0.82) if is_primary else Color(0.12, 0.06, 0.06, 0.78)
	var hover_bg: Color = Color(0.52, 0.09, 0.1, 0.9) if is_primary else Color(0.2, 0.1, 0.1, 0.85)
	var pressed_bg: Color = Color(0.22, 0.03, 0.04, 0.9) if is_primary else Color(0.08, 0.03, 0.03, 0.84)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = normal_bg
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.63, 0.09, 0.11, 0.92)
	normal_style.content_margin_left = 10.0
	normal_style.content_margin_top = 4.0
	normal_style.content_margin_right = 10.0
	normal_style.content_margin_bottom = 4.0
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = hover_bg
	hover_style.border_color = Color(0.84, 0.14, 0.16, 0.95)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = pressed_bg
	pressed_style.border_color = Color(0.96, 0.24, 0.21, 0.95)
	button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style := normal_style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(normal_bg.r, normal_bg.g, normal_bg.b, 0.4)
	disabled_style.border_color = Color(0.4, 0.08, 0.09, 0.5)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_disabled_color", Color(0.74, 0.68, 0.64, 0.75))


func _on_death_continue_pressed() -> void:
	if not is_dead or is_respawn_transition:
		return
	if lives <= 0:
		_restart_full_game()
		return

	death_countdown_active = false
	death_countdown_value = 0
	death_countdown_timer = 0.0
	death_countdown_tremor_time = 0.0
	_reset_countdown_tremor()
	_fade_out_death_countdown()
	_start_player_fade_out_for_respawn()


func _on_death_quit_pressed() -> void:
	if not is_dead:
		return
	get_tree().quit()


func _restart_full_game() -> void:
	var tree_ref: SceneTree = get_tree()
	if tree_ref == null:
		return
	if tree_ref.paused:
		tree_ref.paused = false
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0
	tree_ref.reload_current_scene()


func _update_countdown_tremor() -> void:
	if death_countdown_label == null:
		return

	var intensity := clampf(float(death_countdown_value) / float(maxi(DEATH_COUNTDOWN_START, 1)), 0.35, 1.0)
	var wave := sin(death_countdown_tremor_time * DEATH_COUNTDOWN_TREMOR_SPEED)
	var tremor := wave * DEATH_COUNTDOWN_TREMOR_STRENGTH * intensity
	death_countdown_label.rotation_degrees = tremor


func _reset_countdown_tremor() -> void:
	if death_countdown_label == null:
		return
	death_countdown_label.rotation_degrees = 0.0
	death_countdown_label.scale = DEATH_COUNTDOWN_END_SCALE


func _start_player_fade_out_for_respawn() -> void:
	if is_respawn_transition:
		return

	death_countdown_active = false
	_stop_death_heartbeat_overlay()
	_hide_death_action_buttons()
	is_respawn_transition = true
	if player_respawn_fade_tween != null:
		player_respawn_fade_tween.kill()

	player_respawn_fade_tween = create_tween()
	player_respawn_fade_tween.set_trans(Tween.TRANS_QUAD)
	player_respawn_fade_tween.set_ease(Tween.EASE_OUT)
	player_respawn_fade_tween.tween_property(animated_sprite, "modulate:a", 0.0, PLAYER_RESPAWN_FADE_OUT_TIME)
	player_respawn_fade_tween.tween_callback(Callable(self, "_respawn_to_spawn"))


func _start_player_fade_in_after_respawn() -> void:
	if player_respawn_fade_tween != null:
		player_respawn_fade_tween.kill()

	player_respawn_fade_tween = create_tween()
	player_respawn_fade_tween.set_trans(Tween.TRANS_QUAD)
	player_respawn_fade_tween.set_ease(Tween.EASE_OUT)
	player_respawn_fade_tween.tween_property(animated_sprite, "modulate:a", base_sprite_modulate.a, PLAYER_RESPAWN_FADE_IN_TIME)
	player_respawn_fade_tween.tween_callback(Callable(self, "_finish_respawn_after_fade_in"))


func _finish_respawn_after_fade_in() -> void:
	is_dead = false
	is_respawn_transition = false
	death_countdown_active = false
	death_countdown_value = 0
	death_countdown_timer = 0.0
	death_countdown_tremor_time = 0.0
	last_damage_source_tag = &""
	last_death_source_tag = &""
	_reset_countdown_tremor()
	_emit_stats_changed()
	respawned.emit()


func _start_death_camera_zoom_fx() -> void:
	if player_camera == null:
		return

	if camera_zoom_tween != null:
		camera_zoom_tween.kill()

	var punch_zoom := base_camera_zoom * DEATH_CAMERA_ZOOM_PUNCH
	var hold_zoom := base_camera_zoom * DEATH_CAMERA_ZOOM_HOLD

	camera_zoom_tween = create_tween()
	camera_zoom_tween.set_trans(Tween.TRANS_QUAD)
	camera_zoom_tween.set_ease(Tween.EASE_OUT)
	camera_zoom_tween.tween_property(player_camera, "zoom", punch_zoom, 0.08)
	camera_zoom_tween.tween_property(player_camera, "zoom", hold_zoom, 0.18)


func _reset_camera_zoom() -> void:
	if player_camera != null:
		player_camera.zoom = base_camera_zoom


func _setup_death_sfx() -> void:
	if death_sfx_player != null:
		return

	death_sfx_player = AudioStreamPlayer.new()
	death_sfx_player.name = "DeathSfx"
	death_sfx_player.bus = "SFX"
	death_sfx_player.volume_db = DEATH_SFX_VOLUME_DB
	add_child(death_sfx_player)

	if ResourceLoader.exists(DEATH_SFX_PATH):
		var loaded_stream: Resource = load(DEATH_SFX_PATH)
		if loaded_stream is AudioStream:
			death_sfx_player.stream = loaded_stream


func _setup_death_intro_sfx() -> void:
	if death_intro_sfx_player != null:
		return

	death_intro_sfx_player = AudioStreamPlayer.new()
	death_intro_sfx_player.name = "DeathIntroSfx"
	death_intro_sfx_player.bus = "SFX"
	death_intro_sfx_player.volume_db = DEATH_INTRO_SFX_VOLUME_DB
	add_child(death_intro_sfx_player)

	if ResourceLoader.exists(DEATH_INTRO_SFX_PATH):
		var loaded_stream: Resource = load(DEATH_INTRO_SFX_PATH)
		if loaded_stream is AudioStream:
			death_intro_sfx_player.stream = loaded_stream


func _play_death_intro_sfx() -> void:
	if death_intro_sfx_player == null or death_intro_sfx_player.stream == null:
		return
	death_intro_sfx_player.stop()
	death_intro_sfx_player.play()


func _play_death_sfx() -> void:
	if death_sfx_player == null or death_sfx_player.stream == null:
		return
	death_sfx_player.stop()
	death_sfx_player.play()


func _setup_countdown_sfx() -> void:
	if death_countdown_sfx_player != null:
		return

	death_countdown_sfx_player = AudioStreamPlayer.new()
	death_countdown_sfx_player.name = "DeathCountdownSfx"
	death_countdown_sfx_player.bus = "SFX"
	death_countdown_sfx_player.volume_db = DEATH_COUNTDOWN_SFX_VOLUME_DB
	add_child(death_countdown_sfx_player)

	if ResourceLoader.exists(DEATH_COUNTDOWN_SFX_PATH):
		var loaded_stream: Resource = load(DEATH_COUNTDOWN_SFX_PATH)
		if loaded_stream is AudioStream:
			death_countdown_sfx_player.stream = loaded_stream


func _play_countdown_sfx() -> void:
	if death_countdown_sfx_player == null or death_countdown_sfx_player.stream == null:
		return

	var pitch_step: float = float(DEATH_COUNTDOWN_START - death_countdown_value)
	death_countdown_sfx_player.pitch_scale = 0.9 + (pitch_step * 0.08)
	death_countdown_sfx_player.stop()
	death_countdown_sfx_player.play()


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


func _setup_jump_sfx() -> void:
	if jump_sfx_player != null:
		return

	jump_sfx_player = AudioStreamPlayer.new()
	jump_sfx_player.name = "JumpSfx"
	jump_sfx_player.bus = "SFX"
	jump_sfx_player.volume_db = JUMP_SFX_VOLUME_DB
	add_child(jump_sfx_player)

	if ResourceLoader.exists(JUMP_SFX_PATH):
		var loaded_stream: Resource = load(JUMP_SFX_PATH)
		if loaded_stream is AudioStream:
			jump_sfx_player.stream = loaded_stream


func _play_jump_sfx() -> void:
	if jump_sfx_player == null or jump_sfx_player.stream == null:
		return
	jump_sfx_player.stop()
	jump_sfx_player.play()


func _play_hurt_sfx() -> void:
	if hurt_sfx_player == null or hurt_sfx_player.stream == null:
		return
	hurt_sfx_player.stop()
	hurt_sfx_player.play()


func _play_hurt_flash() -> void:
	if animated_sprite == null or is_dead:
		return

	if hurt_flash_tween != null:
		hurt_flash_tween.kill()
		hurt_flash_tween = null

	animated_sprite.modulate = HURT_FLASH_COLOR
	hurt_flash_tween = create_tween()
	hurt_flash_tween.set_trans(Tween.TRANS_QUAD)
	hurt_flash_tween.set_ease(Tween.EASE_OUT)
	hurt_flash_tween.tween_property(animated_sprite, "modulate", base_sprite_modulate, HURT_FLASH_OUT_TIME)


func _create_gothic_death_font() -> Font:
	if ResourceLoader.exists(DEATH_TEXT_FONT_PATH):
		var file_font: Resource = load(DEATH_TEXT_FONT_PATH)
		if file_font is Font:
			return file_font

	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray([
		"Vladimir Script",
		"Edwardian Script ITC",
		"Viner Hand ITC",
		"Palace Script MT",
		"Old English Text MT",
		"Lucida Blackletter",
		"UnifrakturCook",
		"UnifrakturMaguntia",
		"Blackadder ITC",
		"Goudy Text MT",
		"Cloister Black",
		"Book Antiqua",
		"Times New Roman"
	])
	return system_font
