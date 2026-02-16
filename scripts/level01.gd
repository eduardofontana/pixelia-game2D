extends Node2D

const FALLBACK_SPAWN_MIN_X: float = 144.0
const FALLBACK_SPAWN_MAX_X: float = 1320.0
const FALLBACK_GROUND_Y: float = 624.0
const GROUND_COLLISION_MASK: int = 1
const GROUND_SCAN_TOP_Y: float = -220.0
const GROUND_SCAN_BOTTOM_Y: float = 1800.0
const TERRAIN_SAMPLE_STEP_X: float = 42.0
const MIN_GROUND_SAMPLE_GAP_X: float = 24.0
const PLAYER_VOID_WORLD_MARGIN_Y: float = 160.0
const PLAYER_VOID_FOV_MARGIN_Y: float = 120.0
const REQUIRED_COIN_COUNT: int = 15
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const KNIGHT_HIGHT_SCENE: PackedScene = preload("res://scenes/knight_hight.tscn")
const PORTAL_LOCKED_ALPHA: float = 0.35
const PORTAL_UNLOCKED_ALPHA: float = 1.0
const BOSS_HUD_TEXTURE_PATH: String = "res://sprites/Dead/HUD_Boss.png"
const BOSS_HUD_LAYER: int = 110
const BOSS_HUD_WIDTH: float = 176.0
const BOSS_HUD_HEIGHT: float = 64.0
const BOSS_HUD_TOP_Y: float = 100.0
const BOSS_HP_BAR_WIDTH: float = 104.0
const BOSS_HP_BAR_HEIGHT: float = 8.0

const Z_BACKGROUND_ROOT: int = -300
const Z_PARALLAX_BACKGROUND_LAYER: int = -120
const Z_TERRAIN_ROOT: int = 0
const Z_TERRAIN_FLOOR: int = 0
const Z_TERRAIN_STRUCTURE: int = 1
const Z_TERRAIN_DECORATION: int = 2
const Z_PORTAL: int = 8
const Z_PICKUP: int = 9
const Z_ACTOR: int = 10
const Z_ACTOR_HEALTHBAR: int = 12
const Z_PLAYER_BEHIND_WATER: int = Z_TERRAIN_STRUCTURE
const Z_HUD_LAYER: int = 120
const ENEMY_FIRST_SEEN_DISTANCE: float = 260.0
const ENEMY_FIRST_SEEN_SCREEN_MARGIN: float = 56.0
const WATER_SURFACE_ENTER_MARGIN_Y: float = 6.0
const WATER_FALL_SPEED_THRESHOLD: float = 8.0
const WATER_DEPTH_EXTENSION_Y: float = 420.0
const WATER_SPLASH_PARTICLE_COUNT: int = 12
const WATER_SPLASH_LIFETIME: float = 0.34
const WATER_SPLASH_Z_INDEX: int = Z_TERRAIN_DECORATION + 1
const WATER_SPLASH_COOLDOWN: float = 0.18
const PLAYER_DIALOG_DURATION: float = 2.9
const PLAYER_DIALOG_LONG_DURATION: float = 3.3
const DIALOG_SKELETON_FIRST_SEEN: String = "Preciso tomar cuidado com este monte de ossos."
const DIALOG_BAT_FIRST_SEEN: String = "Um baiacu voador ? rsrsrs"
const DIALOG_SLIME_FIRST_SEEN: String = "Que coisa nojenta !"
const DIALOG_MAP_GOLD_APPEARED: String = "O que \u00e9 aquilo ?"
const DIALOG_MAP_GOLD_PICKUP_LINE_1: String = "Sangue de Jesus tem poder !"
const DIALOG_MAP_GOLD_PICKUP_LINE_2: String = "Preciso derrotar essa coisa seja l\u00e1 o que for isso !"
const DIALOG_BOSS_FIRST_APPROACH: String = "Mais que coisa assustadora ! Deve ser Puro-Osso ! rsrsrs"
const DIALOG_BOSS_PLAYER_WON: String = "F\u00e1cil Demais ! N\u00e3o compensa !"
const DIALOG_BOSS_PLAYER_DIED_TAUNT: String = "Voc\u00ea n\u00e3o foi forte o suficiente !"
const BOSS_DIALOG_TRIGGER_DISTANCE: float = 210.0
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const CHARACTER_PLAYER_ID: StringName = &"player"
const CHARACTER_KNIGHT_HIGHT_ID: StringName = &"knight_hight"
const SELECTED_CHARACTER_ID_META_KEY: StringName = &"selected_character_id"
const SELECTED_CHARACTER_SCENE_META_KEY: StringName = &"selected_character_scene_path"
const LEVEL02_SCENE_PATH: String = "res://scenes/level_02.tscn"
const LEVEL_TRANSITION_FADE_SECONDS: float = 0.55
const LEVEL_TRANSITION_LAYER: int = 260
const LEVEL_TRANSITION_LOADING_IMAGE_PATH: String = "res://background/loadingpixelia.png"
const LEVEL_TRANSITION_LOADING_SECONDS: float = 5.0
const LEVEL_LOADING_BAR_LEFT_RATIO: float = 0.287
const LEVEL_LOADING_BAR_TOP_RATIO: float = 0.864
const LEVEL_LOADING_BAR_WIDTH_RATIO: float = 0.427
const LEVEL_LOADING_BAR_HEIGHT_RATIO: float = 0.032
const LEVEL_LOADING_BAR_INSET: float = 2.0

@onready var bgm_player: AudioStreamPlayer = get_node_or_null("BGM") as AudioStreamPlayer
@onready var hud_layer: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
@onready var player_ref: CharacterBody2D = _resolve_player_reference()
@onready var level_portal: Area2D = get_node_or_null("Level01Portal") as Area2D
@onready var map_gold_item: Area2D = get_node_or_null("MapGold") as Area2D
@onready var boss_ref: CharacterBody2D = get_node_or_null("Boss") as CharacterBody2D

var coins_collected: int = 0
var portal_finished: bool = false
var portal_unlocked: bool = false
var map_gold_unlocked: bool = false
var map_gold_collected: bool = false
var boss_spawned: bool = false
var boss_defeated: bool = false
var level_transition_overlay: CanvasLayer = null
var level_transition_dim_rect: ColorRect = null
var level_transition_loading_image: TextureRect = null
var level_transition_loading_bar_bg: Panel = null
var level_transition_loading_bar_fill: Panel = null
var level_transition_tween: Tween = null
var level_transition_in_progress: bool = false
var boss_hud_overlay: CanvasLayer = null
var boss_hud_root: Control = null
var boss_hud_fill: ColorRect = null
var terrain_spawn_min_x: float = FALLBACK_SPAWN_MIN_X
var terrain_spawn_max_x: float = FALLBACK_SPAWN_MAX_X
var ground_spawn_samples: PackedVector2Array = PackedVector2Array()
var coin_spawn_snapshots: Array[Dictionary] = []
var saw_skeleton_once: bool = false
var saw_bat_once: bool = false
var saw_slime_once: bool = false
var saw_boss_approach_once: bool = false
var player_spawn_position: Vector2 = Vector2.ZERO
var selected_character_id: StringName = CHARACTER_PLAYER_ID
var character_select_overlay: CanvasLayer = null
var character_option_buttons: Dictionary = {}
var character_selection_locked: bool = false
var water_cover_zones: Array[Rect2] = []
var player_is_behind_water: bool = false
var water_splash_cooldown_timer: float = 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	player_ref = _resolve_player_reference()
	player_spawn_position = _resolve_player_spawn_position()
	selected_character_id = CHARACTER_PLAYER_ID
	_ensure_audio_buses()
	_ensure_hud_layer()
	_validate_level01_root_nodes()
	_setup_level_transition_overlay()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_level_transition_viewport_size_changed):
		get_viewport().size_changed.connect(_on_level_transition_viewport_size_changed)
	_setup_boss_hud()
	_bind_level_portal()
	_bind_map_gold_item()
	_bind_boss()
	_bind_player_lifecycle()
	_rebuild_terrain_spawn_map()
	_configure_player_void_fov()

	if is_instance_valid(bgm_player):
		bgm_player.bus = BUS_MUSIC
		bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_connect_signal_once(bgm_player, &"finished", Callable(self, "_on_bgm_finished"))
		if not bgm_player.playing:
			bgm_player.play()

	_apply_scene_ordering()
	_rebuild_water_cover_zones()
	_bind_collectible_coins()
	_cache_coin_spawn_snapshots()
	_set_map_gold_active(false)
	_update_portal_access_state()
	_update_hud_coin_count()
	_setup_character_select_overlay()


func _validate_level01_root_nodes() -> void:
	if player_ref == null:
		push_warning("Level01: player nao encontrado no no raiz (Player/grupo 'player').")
	_ensure_hud_layer()
	if hud_layer == null:
		push_warning("Level01: node 'HUD' nao encontrado no no raiz.")
	if bgm_player == null:
		push_warning("Level01: node 'BGM' nao encontrado no no raiz.")


func _resolve_hud_layer() -> CanvasLayer:
	var direct_hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if direct_hud != null:
		return direct_hud

	for child in get_children():
		var canvas_child: CanvasLayer = child as CanvasLayer
		if canvas_child == null:
			continue
		if canvas_child.has_method("set_coin_count"):
			return canvas_child
		if String(canvas_child.name).to_lower().findn("hud") >= 0:
			return canvas_child

	var hud_nodes: Array[Node] = get_tree().get_nodes_in_group("hud")
	for hud_node in hud_nodes:
		var hud_canvas: CanvasLayer = hud_node as CanvasLayer
		if hud_canvas != null:
			return hud_canvas

	return null


func _ensure_hud_layer() -> void:
	if hud_layer == null:
		hud_layer = _resolve_hud_layer()


func _connect_signal_once(emitter: Object, signal_name: StringName, callback: Callable) -> void:
	if emitter == null:
		return
	if not emitter.has_signal(signal_name):
		return
	if emitter.is_connected(signal_name, callback):
		return
	emitter.connect(signal_name, callback)


func _ensure_audio_buses() -> void:
	var master_index: int = AudioServer.get_bus_index(BUS_MASTER)
	if master_index < 0:
		return
	_ensure_audio_bus_exists(BUS_MUSIC, master_index)
	_ensure_audio_bus_exists(BUS_SFX, master_index)


func _ensure_audio_bus_exists(bus_name: StringName, send_bus_index: int) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var new_bus_index: int = AudioServer.get_bus_count()
	AudioServer.add_bus(new_bus_index)
	AudioServer.set_bus_name(new_bus_index, bus_name)
	var send_bus_name: StringName = AudioServer.get_bus_name(send_bus_index)
	AudioServer.set_bus_send(new_bus_index, send_bus_name)


func _physics_process(delta: float) -> void:
	water_splash_cooldown_timer = maxf(0.0, water_splash_cooldown_timer - delta)
	_update_player_water_ordering()
	_process_enemy_first_seen_dialogs()
	_process_boss_proximity_dialog()


func _exit_tree() -> void:
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0


func _bind_level_portal() -> void:
	if level_portal == null:
		return

	_connect_signal_once(level_portal, &"body_entered", Callable(self, "_on_level_portal_body_entered"))


func _on_level_portal_body_entered(body: Node2D) -> void:
	if portal_finished:
		return
	if not portal_unlocked:
		return
	if not _is_player_body(body):
		return

	portal_finished = true
	_start_level_transition_to_level02()


func _setup_level_transition_overlay() -> void:
	if level_transition_overlay != null:
		return

	level_transition_overlay = CanvasLayer.new()
	level_transition_overlay.name = "LevelTransitionOverlay"
	level_transition_overlay.layer = LEVEL_TRANSITION_LAYER
	level_transition_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	level_transition_overlay.visible = false
	add_child(level_transition_overlay)

	level_transition_dim_rect = ColorRect.new()
	level_transition_dim_rect.name = "Fade"
	level_transition_dim_rect.anchor_left = 0.0
	level_transition_dim_rect.anchor_top = 0.0
	level_transition_dim_rect.anchor_right = 1.0
	level_transition_dim_rect.anchor_bottom = 1.0
	level_transition_dim_rect.offset_left = 0.0
	level_transition_dim_rect.offset_top = 0.0
	level_transition_dim_rect.offset_right = 0.0
	level_transition_dim_rect.offset_bottom = 0.0
	level_transition_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_transition_dim_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	level_transition_overlay.add_child(level_transition_dim_rect)

	level_transition_loading_image = TextureRect.new()
	level_transition_loading_image.name = "LoadingImage"
	level_transition_loading_image.anchor_left = 0.0
	level_transition_loading_image.anchor_top = 0.0
	level_transition_loading_image.anchor_right = 1.0
	level_transition_loading_image.anchor_bottom = 1.0
	level_transition_loading_image.offset_left = 0.0
	level_transition_loading_image.offset_top = 0.0
	level_transition_loading_image.offset_right = 0.0
	level_transition_loading_image.offset_bottom = 0.0
	level_transition_loading_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	level_transition_loading_image.stretch_mode = TextureRect.STRETCH_SCALE
	level_transition_loading_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_transition_loading_image.visible = false
	level_transition_overlay.add_child(level_transition_loading_image)
	if ResourceLoader.exists(LEVEL_TRANSITION_LOADING_IMAGE_PATH):
		var loading_texture_res: Resource = load(LEVEL_TRANSITION_LOADING_IMAGE_PATH)
		if loading_texture_res is Texture2D:
			level_transition_loading_image.texture = loading_texture_res as Texture2D

	level_transition_loading_bar_bg = Panel.new()
	level_transition_loading_bar_bg.name = "LoadingBarBg"
	level_transition_loading_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_transition_loading_bar_bg.visible = false
	level_transition_overlay.add_child(level_transition_loading_bar_bg)

	var bar_bg_style := StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0.15, 0.03, 0.01, 0.75)
	bar_bg_style.corner_radius_top_left = 8
	bar_bg_style.corner_radius_top_right = 8
	bar_bg_style.corner_radius_bottom_right = 8
	bar_bg_style.corner_radius_bottom_left = 8
	level_transition_loading_bar_bg.add_theme_stylebox_override("panel", bar_bg_style)

	level_transition_loading_bar_fill = Panel.new()
	level_transition_loading_bar_fill.name = "LoadingBarFill"
	level_transition_loading_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_transition_loading_bar_bg.add_child(level_transition_loading_bar_fill)

	var bar_fill_style := StyleBoxFlat.new()
	bar_fill_style.bg_color = Color(1.0, 0.37, 0.08, 0.9)
	bar_fill_style.corner_radius_top_left = 7
	bar_fill_style.corner_radius_top_right = 7
	bar_fill_style.corner_radius_bottom_right = 7
	bar_fill_style.corner_radius_bottom_left = 7
	level_transition_loading_bar_fill.add_theme_stylebox_override("panel", bar_fill_style)

	_layout_level_transition_loading_bar()
	_set_level_transition_loading_progress(0.0)


func _start_level_transition_to_level02() -> void:
	if level_transition_in_progress:
		return
	level_transition_in_progress = true

	_setup_level_transition_overlay()
	if level_transition_overlay == null or level_transition_dim_rect == null:
		_change_to_level02_scene()
		return

	if player_ref != null:
		player_ref.velocity = Vector2.ZERO
		player_ref.set_process_input(false)
		player_ref.set_process_unhandled_input(false)
		player_ref.set_physics_process(false)

	if is_instance_valid(bgm_player):
		bgm_player.stop()

	if level_transition_tween != null:
		level_transition_tween.kill()
		level_transition_tween = null

	level_transition_overlay.visible = true
	level_transition_dim_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_set_level_transition_loading_visible(false)
	_set_level_transition_loading_progress(0.0)
	level_transition_tween = create_tween()
	level_transition_tween.set_trans(Tween.TRANS_SINE)
	level_transition_tween.set_ease(Tween.EASE_IN_OUT)
	level_transition_tween.tween_property(level_transition_dim_rect, "color:a", 1.0, LEVEL_TRANSITION_FADE_SECONDS)
	level_transition_tween.tween_callback(Callable(self, "_start_level_loading_to_level02"))


func _start_level_loading_to_level02() -> void:
	_set_level_transition_loading_visible(true)
	_layout_level_transition_loading_bar()
	_set_level_transition_loading_progress(0.0)

	var start_time_ms: int = Time.get_ticks_msec()
	while true:
		var elapsed_sec: float = maxf(0.0, float(Time.get_ticks_msec() - start_time_ms) / 1000.0)
		var progress: float = clampf(elapsed_sec / LEVEL_TRANSITION_LOADING_SECONDS, 0.0, 1.0)
		_set_level_transition_loading_progress(progress)
		if progress >= 1.0:
			break
		await get_tree().process_frame

	_change_to_level02_scene()


func _change_to_level02_scene() -> void:
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0
	get_tree().paused = false
	_persist_selected_character_for_next_level()

	var change_error: int = get_tree().change_scene_to_file(LEVEL02_SCENE_PATH)
	if change_error == OK:
		return

	push_warning("Level01: falha ao carregar '%s' (erro %d)." % [LEVEL02_SCENE_PATH, change_error])
	level_transition_in_progress = false
	portal_finished = false

	if player_ref != null:
		player_ref.set_process_input(true)
		player_ref.set_process_unhandled_input(true)
		player_ref.set_physics_process(true)

	if level_transition_tween != null:
		level_transition_tween.kill()
		level_transition_tween = null

	if level_transition_dim_rect != null:
		level_transition_dim_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	if level_transition_overlay != null:
		level_transition_overlay.visible = false
	_set_level_transition_loading_visible(false)
	_set_level_transition_loading_progress(0.0)


func _set_level_transition_loading_visible(visible_value: bool) -> void:
	if level_transition_loading_image != null:
		level_transition_loading_image.visible = visible_value
	if level_transition_loading_bar_bg != null:
		level_transition_loading_bar_bg.visible = visible_value


func _on_level_transition_viewport_size_changed() -> void:
	_layout_level_transition_loading_bar()


func _layout_level_transition_loading_bar() -> void:
	if level_transition_loading_bar_bg == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var x: float = viewport_size.x * LEVEL_LOADING_BAR_LEFT_RATIO
	var y: float = viewport_size.y * LEVEL_LOADING_BAR_TOP_RATIO
	var width: float = viewport_size.x * LEVEL_LOADING_BAR_WIDTH_RATIO
	var height: float = viewport_size.y * LEVEL_LOADING_BAR_HEIGHT_RATIO
	level_transition_loading_bar_bg.position = Vector2(x, y)
	level_transition_loading_bar_bg.size = Vector2(width, height)

	if level_transition_loading_bar_fill != null:
		level_transition_loading_bar_fill.position = Vector2(LEVEL_LOADING_BAR_INSET, LEVEL_LOADING_BAR_INSET)
		level_transition_loading_bar_fill.size = Vector2(0.0, maxf(1.0, height - (LEVEL_LOADING_BAR_INSET * 2.0)))


func _set_level_transition_loading_progress(progress: float) -> void:
	if level_transition_loading_bar_bg == null or level_transition_loading_bar_fill == null:
		return
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var inner_width: float = maxf(0.0, level_transition_loading_bar_bg.size.x - (LEVEL_LOADING_BAR_INSET * 2.0))
	level_transition_loading_bar_fill.size.x = inner_width * clamped_progress


func _resolve_player_spawn_position() -> Vector2:
	var root_player: CharacterBody2D = get_node_or_null("Player") as CharacterBody2D
	if root_player != null:
		return root_player.global_position
	if player_ref != null:
		return player_ref.global_position
	return Vector2.ZERO


func _setup_character_select_overlay() -> void:
	if character_select_overlay != null:
		return

	var option_group := ButtonGroup.new()
	character_option_buttons.clear()
	character_selection_locked = false

	character_select_overlay = CanvasLayer.new()
	character_select_overlay.name = "CharacterSelectOverlay"
	character_select_overlay.layer = 240
	character_select_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(character_select_overlay)

	var root := Control.new()
	root.name = "Root"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	character_select_overlay.add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.anchor_left = 0.0
	dim.anchor_top = 0.0
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.offset_left = 0.0
	dim.offset_top = 0.0
	dim.offset_right = 0.0
	dim.offset_bottom = 0.0
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250.0
	panel.offset_top = -180.0
	panel.offset_right = 250.0
	panel.offset_bottom = 180.0
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	root.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.86, 0.74, 0.5, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	layout.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.add_child(layout)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Escolha o Personagem"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87, 0.98))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 2)
	title.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layout.add_child(title)

	var options_row := HBoxContainer.new()
	options_row.name = "Options"
	options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	options_row.add_theme_constant_override("separation", 14)
	options_row.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layout.add_child(options_row)

	var player_button: Button = _build_character_option_button(CHARACTER_PLAYER_ID, PLAYER_SCENE, option_group)
	options_row.add_child(player_button)
	character_option_buttons[CHARACTER_PLAYER_ID] = player_button

	var knight_button: Button = _build_character_option_button(CHARACTER_KNIGHT_HIGHT_ID, KNIGHT_HIGHT_SCENE, option_group)
	options_row.add_child(knight_button)
	character_option_buttons[CHARACTER_KNIGHT_HIGHT_ID] = knight_button

	_set_selected_character(selected_character_id)
	get_tree().paused = true


func _build_character_option_button(character_id: StringName, character_scene: PackedScene, option_group: ButtonGroup) -> Button:
	var option_button := Button.new()
	option_button.toggle_mode = true
	option_button.button_group = option_group
	option_button.custom_minimum_size = Vector2(180.0, 188.0)
	option_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	option_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	option_button.focus_mode = Control.FOCUS_ALL
	option_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	option_button.pressed.connect(Callable(self, "_on_character_option_pressed").bind(character_id))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.13, 0.13, 0.17, 0.96)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.42, 0.45, 0.5, 0.8)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8
	option_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(0.72, 0.76, 0.82, 0.9)
	hover_style.bg_color = Color(0.17, 0.17, 0.22, 0.98)
	option_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.22, 0.2, 0.12, 0.98)
	pressed_style.border_color = Color(0.94, 0.78, 0.38, 1.0)
	option_button.add_theme_stylebox_override("pressed", pressed_style)

	var content := Control.new()
	content.anchor_left = 0.0
	content.anchor_top = 0.0
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 10.0
	content.offset_top = 10.0
	content.offset_right = -10.0
	content.offset_bottom = -10.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	option_button.add_child(content)

	var name_label := Label.new()
	name_label.anchor_left = 0.0
	name_label.anchor_top = 1.0
	name_label.anchor_right = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_left = 0.0
	name_label.offset_top = -28.0
	name_label.offset_right = 0.0
	name_label.offset_bottom = -6.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = _get_character_display_name(character_id)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var preview := TextureRect.new()
	preview.anchor_left = 0.5
	preview.anchor_top = 0.5
	preview.anchor_right = 0.5
	preview.anchor_bottom = 0.5
	preview.offset_left = -70.0
	preview.offset_top = -64.0
	preview.offset_right = 70.0
	preview.offset_bottom = 64.0
	preview.custom_minimum_size = Vector2(140.0, 128.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = _resolve_character_preview_texture(character_scene)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)

	return option_button


func _resolve_character_preview_texture(character_scene: PackedScene) -> Texture2D:
	if character_scene == null:
		return null

	var preview_node: Node = character_scene.instantiate()
	if preview_node == null:
		return null

	var preview_texture: Texture2D = null
	var sprite: AnimatedSprite2D = preview_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null:
		var idle_animation: StringName = &"idle"
		if not sprite.sprite_frames.has_animation(idle_animation):
			var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
			if not animation_names.is_empty():
				idle_animation = StringName(animation_names[0])
		if sprite.sprite_frames.has_animation(idle_animation) and sprite.sprite_frames.get_frame_count(idle_animation) > 0:
			preview_texture = sprite.sprite_frames.get_frame_texture(idle_animation, 0)

	preview_node.free()
	return preview_texture


func _on_character_option_pressed(character_id: StringName) -> void:
	if character_selection_locked:
		return
	character_selection_locked = true

	_set_selected_character(character_id)
	var selected_button: Button = character_option_buttons.get(character_id) as Button
	await _play_character_select_fx(selected_button)
	_finalize_character_selection()


func _set_selected_character(character_id: StringName) -> void:
	selected_character_id = character_id
	for option_id_variant in character_option_buttons.keys():
		var option_id: StringName = StringName(option_id_variant)
		var option_button: Button = character_option_buttons[option_id_variant] as Button
		if option_button == null:
			continue
		var is_selected: bool = option_id == selected_character_id
		option_button.button_pressed = is_selected
		option_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_selected else Color(0.86, 0.86, 0.86, 1.0)

func _finalize_character_selection() -> void:
	_apply_selected_character()

	if character_select_overlay != null:
		character_select_overlay.queue_free()
		character_select_overlay = null
	character_option_buttons.clear()
	get_tree().paused = false


func _play_character_select_fx(button: Button) -> void:
	if button == null:
		return

	var base_scale: Vector2 = button.scale
	var base_modulate: Color = button.modulate
	var flash_color := Color(1.0, 0.96, 0.82, 1.0)

	var pick_tween: Tween = button.create_tween()
	pick_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pick_tween.set_trans(Tween.TRANS_SINE)
	pick_tween.set_ease(Tween.EASE_OUT)
	pick_tween.tween_property(button, "scale", base_scale * Vector2(1.04, 1.04), 0.06)
	pick_tween.parallel().tween_property(button, "modulate", flash_color, 0.06)
	pick_tween.tween_property(button, "scale", base_scale, 0.08)
	pick_tween.parallel().tween_property(button, "modulate", base_modulate, 0.08)
	await pick_tween.finished


func _apply_selected_character() -> void:
	if player_spawn_position == Vector2.ZERO and player_ref != null:
		player_spawn_position = player_ref.global_position

	var selected_scene: PackedScene = _get_character_scene(selected_character_id)
	if selected_scene == null:
		selected_scene = PLAYER_SCENE

	var active_player: CharacterBody2D = _resolve_player_reference()
	var selected_scene_path: String = selected_scene.resource_path
	var should_replace_player: bool = true
	if active_player != null and not selected_scene_path.is_empty():
		should_replace_player = active_player.scene_file_path != selected_scene_path

	if should_replace_player:
		if active_player != null:
			var parent_node: Node = active_player.get_parent()
			if parent_node != null:
				parent_node.remove_child(active_player)
			active_player.free()
		active_player = selected_scene.instantiate() as CharacterBody2D
		if active_player != null:
			active_player.name = "Player"
			add_child(active_player)

	if active_player != null:
		_apply_player_spawn_anchor(active_player)

	player_ref = active_player
	if player_ref == null:
		player_ref = _resolve_player_reference()
	_bind_player_lifecycle()
	_rebind_player_dependents()
	_apply_scene_ordering()
	_rebuild_water_cover_zones()
	_rebuild_terrain_spawn_map()
	_configure_player_void_fov()
	_update_hud_coin_count()
	_persist_selected_character_for_next_level()


func _get_character_scene(character_id: StringName) -> PackedScene:
	match character_id:
		CHARACTER_KNIGHT_HIGHT_ID:
			return KNIGHT_HIGHT_SCENE
		_:
			return PLAYER_SCENE


func _get_character_display_name(character_id: StringName) -> String:
	match character_id:
		CHARACTER_KNIGHT_HIGHT_ID:
			return "Knight Hight"
		_:
			return "Knight"


func _persist_selected_character_for_next_level() -> void:
	var tree_ref: SceneTree = get_tree()
	if tree_ref == null or tree_ref.root == null:
		return

	var selected_scene: PackedScene = _get_character_scene(selected_character_id)
	var selected_scene_path: String = ""
	if selected_scene != null:
		selected_scene_path = String(selected_scene.resource_path)

	tree_ref.root.set_meta(SELECTED_CHARACTER_ID_META_KEY, selected_character_id)
	if selected_scene_path.is_empty():
		if tree_ref.root.has_meta(SELECTED_CHARACTER_SCENE_META_KEY):
			tree_ref.root.remove_meta(SELECTED_CHARACTER_SCENE_META_KEY)
	else:
		tree_ref.root.set_meta(SELECTED_CHARACTER_SCENE_META_KEY, selected_scene_path)


func _apply_player_spawn_anchor(player_node: CharacterBody2D) -> void:
	if player_node == null:
		return
	player_node.global_position = player_spawn_position
	if _node_has_property(player_node, &"spawn_position"):
		player_node.set("spawn_position", player_spawn_position)
	var player_camera: Camera2D = player_node.get_node_or_null("Camera2D") as Camera2D
	if player_camera != null:
		player_camera.make_current()


func _rebind_player_dependents() -> void:
	var nodes_to_rebind: Array[Node] = []
	nodes_to_rebind.append_array(get_tree().get_nodes_in_group("enemies"))
	if boss_ref != null:
		nodes_to_rebind.append(boss_ref)
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


func _on_bgm_finished() -> void:
	if is_instance_valid(bgm_player):
		bgm_player.play()


func _setup_boss_hud() -> void:
	if boss_hud_overlay != null:
		return

	boss_hud_overlay = CanvasLayer.new()
	boss_hud_overlay.name = "BossHUD"
	boss_hud_overlay.layer = BOSS_HUD_LAYER
	boss_hud_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(boss_hud_overlay)

	boss_hud_root = Control.new()
	boss_hud_root.name = "Root"
	boss_hud_root.anchor_left = 0.0
	boss_hud_root.anchor_top = 0.0
	boss_hud_root.anchor_right = 1.0
	boss_hud_root.anchor_bottom = 1.0
	boss_hud_root.offset_left = 0.0
	boss_hud_root.offset_top = 0.0
	boss_hud_root.offset_right = 0.0
	boss_hud_root.offset_bottom = 0.0
	boss_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_hud_root.visible = false
	boss_hud_overlay.add_child(boss_hud_root)

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.anchor_left = 0.5
	frame.anchor_top = 0.0
	frame.anchor_right = 0.5
	frame.anchor_bottom = 0.0
	frame.offset_left = -BOSS_HUD_WIDTH * 0.5
	frame.offset_top = BOSS_HUD_TOP_Y
	frame.offset_right = BOSS_HUD_WIDTH * 0.5
	frame.offset_bottom = BOSS_HUD_TOP_Y + BOSS_HUD_HEIGHT
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BOSS_HUD_TEXTURE_PATH):
		var hud_texture_res: Resource = load(BOSS_HUD_TEXTURE_PATH)
		if hud_texture_res is Texture2D:
			frame.texture = hud_texture_res as Texture2D
	boss_hud_root.add_child(frame)

	var hp_bg := ColorRect.new()
	hp_bg.name = "HpBg"
	hp_bg.position = Vector2((BOSS_HUD_WIDTH - BOSS_HP_BAR_WIDTH) * 0.5, 46.0)
	hp_bg.size = Vector2(BOSS_HP_BAR_WIDTH, BOSS_HP_BAR_HEIGHT)
	hp_bg.color = Color(0.06, 0.02, 0.02, 0.82)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(hp_bg)

	boss_hud_fill = ColorRect.new()
	boss_hud_fill.name = "HpFill"
	boss_hud_fill.position = Vector2(1.0, 1.0)
	boss_hud_fill.size = Vector2(BOSS_HP_BAR_WIDTH - 2.0, BOSS_HP_BAR_HEIGHT - 2.0)
	boss_hud_fill.color = Color(0.22, 0.86, 0.36, 0.95)
	boss_hud_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(boss_hud_fill)

	_set_boss_hud_visible(false)


func _set_boss_hud_visible(visible_value: bool) -> void:
	if boss_hud_root == null:
		return
	boss_hud_root.visible = visible_value


func _refresh_boss_hud_from_boss() -> void:
	if boss_ref == null:
		_on_boss_health_changed(0, 1)
		return

	var current_hp_value: int = 0
	var max_hp_value: int = 1
	if boss_ref.has_method("get_current_hp"):
		current_hp_value = int(boss_ref.call("get_current_hp"))
	if boss_ref.has_method("get_max_hp_value"):
		max_hp_value = int(boss_ref.call("get_max_hp_value"))

	_on_boss_health_changed(current_hp_value, max_hp_value)


func _on_boss_health_changed(current_hp_value: int, max_hp_value: int) -> void:
	var safe_max_hp: int = maxi(max_hp_value, 1)
	var clamped_hp: int = clampi(current_hp_value, 0, safe_max_hp)
	var ratio: float = clampf(float(clamped_hp) / float(safe_max_hp), 0.0, 1.0)

	if boss_hud_fill != null:
		var inner_width: float = maxf(0.0, BOSS_HP_BAR_WIDTH - 2.0)
		boss_hud_fill.size.x = inner_width * ratio
		boss_hud_fill.color = Color(
			lerpf(0.92, 0.24, ratio),
			lerpf(0.18, 0.84, ratio),
			0.18,
			0.96
		)

func _apply_scene_ordering() -> void:
	# Padroniza camadas visuais para manter o ordenamento consistente.
	_apply_background_ordering()

	var terrain_node: CanvasItem = get_node_or_null("Terrain") as CanvasItem
	if terrain_node != null:
		terrain_node.z_index = Z_TERRAIN_ROOT
		terrain_node.z_as_relative = false
	_apply_terrain_ordering()

	var portal_item: CanvasItem = level_portal as CanvasItem
	if portal_item != null:
		portal_item.z_index = Z_PORTAL
		portal_item.z_as_relative = false

	if hud_layer != null:
		hud_layer.layer = Z_HUD_LAYER

	if player_ref != null:
		_apply_actor_ordering(player_ref)

	var enemy_nodes: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemy_nodes:
		var enemy_body: CharacterBody2D = enemy_node as CharacterBody2D
		if enemy_body == null:
			continue
		_apply_actor_ordering(enemy_body)

	var coin_nodes: Array[Node] = get_tree().get_nodes_in_group("collectible_coin")
	for coin_node in coin_nodes:
		var coin_area: Area2D = coin_node as Area2D
		if coin_area == null:
			continue
		_apply_pickup_ordering(coin_area)

	if map_gold_item != null:
		_apply_pickup_ordering(map_gold_item)

	if player_ref != null and player_is_behind_water:
		_apply_player_behind_water_ordering(player_ref)


func _apply_background_ordering() -> void:
	var background_root: CanvasItem = get_node_or_null("Background") as CanvasItem
	if background_root != null:
		background_root.z_index = Z_BACKGROUND_ROOT
		background_root.z_as_relative = false

	var parallax_bg: ParallaxBackground = get_node_or_null("Background/ParallaxBackground") as ParallaxBackground
	if parallax_bg != null:
		parallax_bg.layer = Z_PARALLAX_BACKGROUND_LAYER


func _apply_terrain_ordering() -> void:
	var floor_layer: CanvasItem = get_node_or_null("Terrain/Floor") as CanvasItem
	if floor_layer != null:
		floor_layer.z_index = Z_TERRAIN_FLOOR
		floor_layer.z_as_relative = false

	var structure_layer: CanvasItem = get_node_or_null("Terrain/Structure") as CanvasItem
	if structure_layer != null:
		structure_layer.z_index = Z_TERRAIN_STRUCTURE
		structure_layer.z_as_relative = false

	var decoration_layer: CanvasItem = get_node_or_null("Terrain/Decoration") as CanvasItem
	if decoration_layer != null:
		decoration_layer.z_index = Z_TERRAIN_DECORATION
		decoration_layer.z_as_relative = false


func _apply_actor_ordering(actor: CharacterBody2D) -> void:
	if actor == null:
		return
	actor.z_index = Z_ACTOR
	actor.z_as_relative = false

	var health_bar_node: CanvasItem = actor.get_node_or_null("HealthBar") as CanvasItem
	if health_bar_node != null:
		health_bar_node.z_index = Z_ACTOR_HEALTHBAR
		health_bar_node.z_as_relative = false


func _apply_pickup_ordering(pickup: Area2D) -> void:
	if pickup == null:
		return
	pickup.z_index = Z_PICKUP
	pickup.z_as_relative = false


func _rebuild_water_cover_zones() -> void:
	water_cover_zones.clear()

	var decoration_root: Node = get_node_or_null("Terrain/Decoration")
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


func _bind_collectible_coins() -> void:
	var coin_nodes: Array[Node] = get_tree().get_nodes_in_group("collectible_coin")
	var callback: Callable = Callable(self, "_on_coin_collected")
	for coin_node in coin_nodes:
		_connect_signal_once(coin_node, &"collected", callback)


func _cache_coin_spawn_snapshots() -> void:
	coin_spawn_snapshots.clear()
	for coin_node in get_tree().get_nodes_in_group("collectible_coin"):
		var coin_area: Area2D = coin_node as Area2D
		if coin_area == null:
			continue
		var parent_node: Node = coin_area.get_parent()
		if parent_node == null:
			continue
		coin_spawn_snapshots.append({
			"node_name": String(coin_area.name),
			"parent_path": String(parent_node.get_path()),
			"position": coin_area.position,
			"rotation": coin_area.rotation,
			"scale": coin_area.scale
		})


func _restore_all_coins() -> void:
	if COIN_SCENE == null:
		return
	if coin_spawn_snapshots.is_empty():
		_cache_coin_spawn_snapshots()
		if coin_spawn_snapshots.is_empty():
			return

	for coin_snapshot in coin_spawn_snapshots:
		var node_name: String = String(coin_snapshot.get("node_name", ""))
		var parent_path_value: String = String(coin_snapshot.get("parent_path", ""))
		if node_name.is_empty() or parent_path_value.is_empty():
			continue

		var parent_node: Node = get_node_or_null(NodePath(parent_path_value))
		if parent_node == null:
			continue

		var coin_area: Area2D = parent_node.get_node_or_null(NodePath(node_name)) as Area2D
		if coin_area == null:
			var coin_instance: Node = COIN_SCENE.instantiate()
			coin_area = coin_instance as Area2D
			if coin_area == null:
				continue
			coin_area.name = node_name
			parent_node.add_child(coin_area)

		coin_area.position = coin_snapshot.get("position", Vector2.ZERO)
		coin_area.rotation = float(coin_snapshot.get("rotation", 0.0))
		var scale_value: Variant = coin_snapshot.get("scale", Vector2.ONE)
		if scale_value is Vector2:
			coin_area.scale = scale_value

		if coin_area.has_method("reset_coin_state"):
			coin_area.call("reset_coin_state")
		else:
			coin_area.visible = true
			coin_area.set_deferred("monitoring", true)
			coin_area.set_deferred("monitorable", true)
			var collision_shape: CollisionShape2D = coin_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if collision_shape != null:
				collision_shape.set_deferred("disabled", false)

		_apply_pickup_ordering(coin_area)

	_bind_collectible_coins()


func _on_coin_collected(amount: int) -> void:
	coins_collected += maxi(amount, 0)
	if not map_gold_unlocked and coins_collected >= REQUIRED_COIN_COUNT:
		map_gold_unlocked = true
		_set_map_gold_active(true)
		_queue_player_dialog_line(DIALOG_MAP_GOLD_APPEARED, PLAYER_DIALOG_DURATION)
	_update_hud_coin_count()


func _update_hud_coin_count() -> void:
	_ensure_hud_layer()
	if hud_layer == null:
		return
	if hud_layer.has_method("set_coin_count"):
		hud_layer.call("set_coin_count", coins_collected)


func _bind_map_gold_item() -> void:
	if map_gold_item == null:
		return
	_connect_signal_once(map_gold_item, &"body_entered", Callable(self, "_on_map_gold_body_entered"))


func _on_map_gold_body_entered(body: Node2D) -> void:
	if map_gold_collected:
		return
	if not map_gold_unlocked:
		return
	if not _is_player_body(body):
		return

	map_gold_collected = true
	_set_map_gold_active(false)
	_spawn_boss_for_battle()
	_queue_player_dialog_lines([
		DIALOG_MAP_GOLD_PICKUP_LINE_1,
		DIALOG_MAP_GOLD_PICKUP_LINE_2
	], PLAYER_DIALOG_LONG_DURATION)


func _bind_boss() -> void:
	if boss_ref == null:
		_set_boss_hud_visible(false)
		return
	_connect_signal_once(boss_ref, &"defeated", Callable(self, "_on_boss_defeated"))
	_connect_signal_once(boss_ref, &"health_changed", Callable(self, "_on_boss_health_changed"))
	if boss_ref.has_method("set_boss_active"):
		boss_ref.call("set_boss_active", false)
	else:
		boss_ref.visible = false
		boss_ref.set_physics_process(false)
	_set_boss_hud_visible(false)
	_refresh_boss_hud_from_boss()


func _bind_player_lifecycle() -> void:
	player_ref = _resolve_player_reference()
	if player_ref == null:
		return

	_connect_signal_once(player_ref, &"died", Callable(self, "_on_player_died"))


func _resolve_player_reference() -> CharacterBody2D:
	var direct_player: CharacterBody2D = get_node_or_null("Player") as CharacterBody2D
	if direct_player != null:
		return direct_player

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for player_node in players:
		var body: CharacterBody2D = player_node as CharacterBody2D
		if body != null:
			return body

	return null


func _spawn_boss_for_battle() -> void:
	if boss_ref == null:
		return
	if boss_spawned:
		return

	boss_spawned = true
	saw_boss_approach_once = false
	if boss_ref.has_method("set_boss_active"):
		boss_ref.call("set_boss_active", true)
	else:
		boss_ref.visible = true
		boss_ref.set_physics_process(true)
	_apply_actor_ordering(boss_ref)
	_set_boss_hud_visible(true)
	_refresh_boss_hud_from_boss()


func _on_boss_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	_set_boss_hud_visible(false)
	_queue_player_dialog_line(DIALOG_BOSS_PLAYER_WON, PLAYER_DIALOG_LONG_DURATION)
	portal_unlocked = true
	_update_portal_access_state()


func _on_player_died() -> void:
	if not _is_player_in_active_boss_battle():
		return
	if boss_ref != null:
		if boss_ref.has_method("set_boss_active"):
			boss_ref.call("set_boss_active", true)
		else:
			boss_ref.visible = true
			boss_ref.set_physics_process(true)
	_set_boss_hud_visible(true)
	_refresh_boss_hud_from_boss()
	if _was_player_defeated_by_main_boss():
		_queue_player_dialog_line(DIALOG_BOSS_PLAYER_DIED_TAUNT, PLAYER_DIALOG_DURATION)


func _is_player_in_active_boss_battle() -> bool:
	if boss_ref == null:
		return false
	if boss_defeated:
		return false
	if not boss_spawned:
		return false
	if not boss_ref.visible:
		return false
	return true


func _was_player_defeated_by_main_boss() -> bool:
	if player_ref == null:
		return false
	if not player_ref.has_method("get_last_death_source_tag"):
		return false

	var source_tag_value: Variant = player_ref.call("get_last_death_source_tag")
	if source_tag_value is StringName:
		return source_tag_value == &"boss"
	if source_tag_value is String:
		return String(source_tag_value).to_lower() == "boss"
	return false


func _set_map_gold_active(active: bool) -> void:
	if map_gold_item == null:
		return

	map_gold_item.visible = active
	map_gold_item.set_deferred("monitoring", active)
	map_gold_item.set_deferred("monitorable", active)

	var collision_shape: CollisionShape2D = map_gold_item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not active)


func _update_portal_access_state() -> void:
	if level_portal == null:
		return

	level_portal.set_deferred("monitoring", portal_unlocked)
	level_portal.set_deferred("monitorable", portal_unlocked)

	var portal_item: CanvasItem = level_portal as CanvasItem
	if portal_item != null:
		var alpha: float = PORTAL_UNLOCKED_ALPHA if portal_unlocked else PORTAL_LOCKED_ALPHA
		portal_item.modulate = Color(1.0, 1.0, 1.0, alpha)


func _is_player_body(body: Node2D) -> bool:
	if body == null:
		return false
	return body == player_ref or body.is_in_group("player")


func _process_enemy_first_seen_dialogs() -> void:
	if player_ref == null:
		return

	if not saw_skeleton_once and _is_enemy_type_first_seen("skeleton"):
		saw_skeleton_once = true
		_queue_player_dialog_line(DIALOG_SKELETON_FIRST_SEEN, PLAYER_DIALOG_DURATION)

	if not saw_bat_once and _is_enemy_type_first_seen("bat"):
		saw_bat_once = true
		_queue_player_dialog_line(DIALOG_BAT_FIRST_SEEN, PLAYER_DIALOG_DURATION)

	if not saw_slime_once and _is_enemy_type_first_seen("slime"):
		saw_slime_once = true
		_queue_player_dialog_line(DIALOG_SLIME_FIRST_SEEN, PLAYER_DIALOG_DURATION)


func _process_boss_proximity_dialog() -> void:
	if saw_boss_approach_once:
		return
	if not _is_boss_in_dialog_range():
		return
	saw_boss_approach_once = true
	_queue_player_dialog_line(DIALOG_BOSS_FIRST_APPROACH, PLAYER_DIALOG_LONG_DURATION)


func _is_boss_in_dialog_range() -> bool:
	if player_ref == null:
		return false
	if boss_ref == null:
		return false
	if boss_defeated:
		return false
	if not boss_spawned:
		return false
	if not boss_ref.visible:
		return false
	if player_ref.global_position.distance_to(boss_ref.global_position) > BOSS_DIALOG_TRIGGER_DISTANCE:
		return false
	return _is_world_position_inside_view(boss_ref.global_position)


func _is_enemy_type_first_seen(enemy_type_id: String) -> bool:
	if player_ref == null:
		return false

	var enemy_nodes: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemy_nodes:
		var enemy_body: CharacterBody2D = enemy_node as CharacterBody2D
		if enemy_body == null:
			continue
		if enemy_body.is_in_group("boss"):
			continue
		if not _matches_enemy_type(enemy_body, enemy_type_id):
			continue
		if player_ref.global_position.distance_to(enemy_body.global_position) > ENEMY_FIRST_SEEN_DISTANCE:
			continue
		if not _is_world_position_inside_view(enemy_body.global_position):
			continue
		return true

	return false


func _matches_enemy_type(enemy_body: CharacterBody2D, enemy_type_id: String) -> bool:
	if enemy_body == null:
		return false
	if enemy_type_id.is_empty():
		return false

	var lowered_type: String = enemy_type_id.to_lower()
	if String(enemy_body.name).to_lower().findn(lowered_type) >= 0:
		return true

	var script_resource: Script = enemy_body.get_script() as Script
	if script_resource != null:
		var script_path: String = String(script_resource.resource_path).to_lower()
		if script_path.ends_with("%s.gd" % lowered_type):
			return true

	return false


func _is_world_position_inside_view(world_position: Vector2) -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return true

	var viewport_rect: Rect2 = get_viewport_rect().grow(ENEMY_FIRST_SEEN_SCREEN_MARGIN)
	var screen_position: Vector2 = viewport.get_canvas_transform() * world_position
	return viewport_rect.has_point(screen_position)


func _queue_player_dialog_line(text: String, duration: float = PLAYER_DIALOG_DURATION) -> void:
	if player_ref == null:
		return
	if not player_ref.has_method("queue_dialog_line"):
		return
	player_ref.call("queue_dialog_line", text, duration)


func _queue_player_dialog_lines(lines: Array[String], duration_per_line: float = PLAYER_DIALOG_DURATION) -> void:
	if player_ref == null:
		return
	if lines.is_empty():
		return
	if player_ref.has_method("queue_dialog_lines"):
		player_ref.call("queue_dialog_lines", lines, duration_per_line)
		return
	if not player_ref.has_method("queue_dialog_line"):
		return
	for line_text in lines:
		player_ref.call("queue_dialog_line", line_text, duration_per_line)


func _rebuild_terrain_spawn_map() -> void:
	ground_spawn_samples = PackedVector2Array()
	var bounds: Vector2 = _resolve_terrain_scan_bounds()
	terrain_spawn_min_x = bounds.x
	terrain_spawn_max_x = bounds.y

	var excludes: Array[RID] = _build_ground_query_excludes()
	var sample_x: float = terrain_spawn_min_x
	var last_kept_x: float = -INF

	while sample_x <= terrain_spawn_max_x:
		var hit_point: Vector2 = _raycast_ground(sample_x, excludes)
		if hit_point != Vector2.INF:
			if ground_spawn_samples.size() <= 0 or absf(hit_point.x - last_kept_x) >= MIN_GROUND_SAMPLE_GAP_X:
				ground_spawn_samples.append(hit_point)
				last_kept_x = hit_point.x
		sample_x += TERRAIN_SAMPLE_STEP_X

	if ground_spawn_samples.size() <= 0:
		ground_spawn_samples = PackedVector2Array([
			Vector2(FALLBACK_SPAWN_MIN_X, FALLBACK_GROUND_Y),
			Vector2((FALLBACK_SPAWN_MIN_X + FALLBACK_SPAWN_MAX_X) * 0.5, FALLBACK_GROUND_Y),
			Vector2(FALLBACK_SPAWN_MAX_X, FALLBACK_GROUND_Y)
		])


func _resolve_terrain_scan_bounds() -> Vector2:
	var floor_layer: Node2D = get_node_or_null("Terrain/Floor") as Node2D
	if floor_layer != null and floor_layer.has_method("get_used_rect") and floor_layer.has_method("map_to_local"):
		var used_rect_variant: Variant = floor_layer.call("get_used_rect")
		if used_rect_variant is Rect2i:
			var used_rect: Rect2i = used_rect_variant
			if used_rect.size.x > 0:
				var left_cell: Vector2i = used_rect.position
				var right_cell: Vector2i = used_rect.position + Vector2i(used_rect.size.x - 1, 0)
				var left_local_variant: Variant = floor_layer.call("map_to_local", left_cell)
				var right_local_variant: Variant = floor_layer.call("map_to_local", right_cell)
				if left_local_variant is Vector2 and right_local_variant is Vector2:
					var left_local: Vector2 = left_local_variant
					var right_local: Vector2 = right_local_variant
					var left_world: Vector2 = floor_layer.to_global(left_local)
					var right_world: Vector2 = floor_layer.to_global(right_local)
					var min_x: float = minf(left_world.x, right_world.x) - 20.0
					var max_x: float = maxf(left_world.x, right_world.x) + 20.0
					if max_x > min_x:
						return Vector2(min_x, max_x)

	var dynamic_min_x: float = INF
	var dynamic_max_x: float = -INF
	var scene_nodes: Array[Node] = []
	scene_nodes.append_array(get_tree().get_nodes_in_group("player"))
	scene_nodes.append_array(get_tree().get_nodes_in_group("enemies"))
	scene_nodes.append_array(get_tree().get_nodes_in_group("collectible_coin"))
	if level_portal != null:
		scene_nodes.append(level_portal)
	for scene_node in scene_nodes:
		var node_2d: Node2D = scene_node as Node2D
		if node_2d == null:
			continue
		dynamic_min_x = minf(dynamic_min_x, node_2d.global_position.x)
		dynamic_max_x = maxf(dynamic_max_x, node_2d.global_position.x)
	if dynamic_max_x > dynamic_min_x:
		return Vector2(dynamic_min_x - 240.0, dynamic_max_x + 240.0)

	return Vector2(FALLBACK_SPAWN_MIN_X, FALLBACK_SPAWN_MAX_X)


func _build_ground_query_excludes() -> Array[RID]:
	var exclude_rids: Array[RID] = []

	if player_ref != null:
		exclude_rids.append(player_ref.get_rid())

	for node in get_tree().get_nodes_in_group("enemies"):
		var collider: CollisionObject2D = node as CollisionObject2D
		if collider != null:
			exclude_rids.append(collider.get_rid())

	for node in get_tree().get_nodes_in_group("collectible_coin"):
		var collider: CollisionObject2D = node as CollisionObject2D
		if collider != null:
			exclude_rids.append(collider.get_rid())

	if level_portal != null:
		exclude_rids.append(level_portal.get_rid())

	return exclude_rids


func _raycast_ground(world_x: float, excludes: Array[RID]) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(world_x, GROUND_SCAN_TOP_Y),
		Vector2(world_x, GROUND_SCAN_BOTTOM_Y)
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = GROUND_COLLISION_MASK
	query.exclude = excludes

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2.INF
	if not hit.has("position"):
		return Vector2.INF
	var hit_position: Vector2 = hit["position"]
	return hit_position


func _configure_player_void_fov() -> void:
	if player_ref == null:
		return

	var kill_y: float = _get_deepest_ground_y() + PLAYER_VOID_WORLD_MARGIN_Y
	player_ref.set("void_fall_kill_y", kill_y)
	player_ref.set("void_fov_margin_y", PLAYER_VOID_FOV_MARGIN_Y)


func _get_deepest_ground_y() -> float:
	var deepest_y: float = FALLBACK_GROUND_Y
	for anchor in ground_spawn_samples:
		deepest_y = maxf(deepest_y, anchor.y)
	return deepest_y
