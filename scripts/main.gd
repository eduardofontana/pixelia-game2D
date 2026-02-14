extends Node2D

const HUD_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"

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
const Z_HUD_LAYER: int = 120
const ENEMY_FIRST_SEEN_DISTANCE: float = 260.0
const ENEMY_FIRST_SEEN_SCREEN_MARGIN: float = 56.0
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

@onready var bgm_player: AudioStreamPlayer = get_node_or_null("BGM") as AudioStreamPlayer
@onready var hud_layer: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
@onready var player_ref: CharacterBody2D = get_node_or_null("Player") as CharacterBody2D
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
var victory_overlay: CanvasLayer = null
var victory_dim_rect: ColorRect = null
var victory_card: PanelContainer = null
var victory_restart_button: Button = null
var victory_intro_tween: Tween = null
var victory_card_base_top: float = -88.0
var victory_card_base_bottom: float = 88.0
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


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	if hud_layer == null:
		hud_layer = _resolve_hud_layer()
	_validate_main_root_nodes()
	_setup_victory_overlay()
	_setup_boss_hud()
	_bind_level_portal()
	_bind_map_gold_item()
	_bind_boss()
	_bind_player_lifecycle()
	_rebuild_terrain_spawn_map()
	_configure_player_void_fov()

	if is_instance_valid(bgm_player):
		bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		if not bgm_player.is_connected("finished", Callable(self, "_on_bgm_finished")):
			bgm_player.finished.connect(_on_bgm_finished)
		if not bgm_player.playing:
			bgm_player.play()

	_apply_platform_ordering()
	_bind_collectible_coins()
	_cache_coin_spawn_snapshots()
	_set_map_gold_active(false)
	_update_portal_access_state()
	_update_hud_coin_count()


func _validate_main_root_nodes() -> void:
	if player_ref == null:
		push_warning("Main: node 'Player' nao encontrado no no raiz.")
	if hud_layer == null:
		hud_layer = _resolve_hud_layer()
	if hud_layer == null:
		push_warning("Main: node 'HUD' nao encontrado no no raiz.")
	if bgm_player == null:
		push_warning("Main: node 'BGM' nao encontrado no no raiz.")


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


func _physics_process(_delta: float) -> void:
	_process_enemy_first_seen_dialogs()
	_process_boss_proximity_dialog()


func _exit_tree() -> void:
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0


func _bind_level_portal() -> void:
	if level_portal == null:
		return

	var callback: Callable = Callable(self, "_on_level_portal_body_entered")
	if not level_portal.is_connected("body_entered", callback):
		level_portal.body_entered.connect(_on_level_portal_body_entered)


func _on_level_portal_body_entered(body: Node2D) -> void:
	if portal_finished:
		return
	if not portal_unlocked:
		return
	if not _is_player_body(body):
		return

	portal_finished = true
	_show_victory_overlay()


func _setup_victory_overlay() -> void:
	if victory_overlay != null:
		return

	victory_overlay = CanvasLayer.new()
	victory_overlay.name = "VictoryOverlay"
	victory_overlay.layer = 180
	victory_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	victory_overlay.visible = false
	add_child(victory_overlay)

	victory_dim_rect = ColorRect.new()
	victory_dim_rect.name = "Dim"
	victory_dim_rect.anchor_left = 0.0
	victory_dim_rect.anchor_top = 0.0
	victory_dim_rect.anchor_right = 1.0
	victory_dim_rect.anchor_bottom = 1.0
	victory_dim_rect.offset_left = 0.0
	victory_dim_rect.offset_top = 0.0
	victory_dim_rect.offset_right = 0.0
	victory_dim_rect.offset_bottom = 0.0
	victory_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_dim_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	victory_overlay.add_child(victory_dim_rect)

	victory_card = PanelContainer.new()
	victory_card.name = "Card"
	victory_card.anchor_left = 0.5
	victory_card.anchor_top = 0.5
	victory_card.anchor_right = 0.5
	victory_card.anchor_bottom = 0.5
	victory_card.offset_left = -228.0
	victory_card.offset_top = victory_card_base_top
	victory_card.offset_right = 228.0
	victory_card.offset_bottom = victory_card_base_bottom
	victory_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	victory_overlay.add_child(victory_card)

	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.04, 0.08, 0.9)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.74, 0.56, 0.36, 0.74)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.56)
	card_style.shadow_size = 8
	card_style.shadow_offset = Vector2(0.0, 4.0)
	card_style.content_margin_left = 20.0
	card_style.content_margin_top = 18.0
	card_style.content_margin_right = 20.0
	card_style.content_margin_bottom = 18.0
	victory_card.add_theme_stylebox_override("panel", card_style)

	var center_box := VBoxContainer.new()
	center_box.name = "CenterBox"
	center_box.custom_minimum_size = Vector2(406.0, 126.0)
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 14)
	victory_card.add_child(center_box)

	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.custom_minimum_size = Vector2(406.0, 56.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text = "Vencedor!"
	title_label.add_theme_font_size_override("font_size", 62)
	title_label.add_theme_constant_override("outline_size", 7)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.84, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	center_box.add_child(title_label)

	victory_restart_button = Button.new()
	victory_restart_button.name = "RestartButton"
	victory_restart_button.custom_minimum_size = Vector2(270.0, 48.0)
	victory_restart_button.focus_mode = Control.FOCUS_ALL
	victory_restart_button.text = "Jogar Novamente"
	victory_restart_button.add_theme_font_size_override("font_size", 28)
	victory_restart_button.add_theme_constant_override("outline_size", 3)
	victory_restart_button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86, 1.0))
	victory_restart_button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	_apply_victory_button_style(victory_restart_button)
	victory_restart_button.pressed.connect(_on_victory_restart_pressed)
	center_box.add_child(victory_restart_button)

	if ResourceLoader.exists(HUD_FONT_PATH):
		var loaded_font: Resource = load(HUD_FONT_PATH)
		if loaded_font is Font:
			title_label.add_theme_font_override("font", loaded_font as Font)
			victory_restart_button.add_theme_font_override("font", loaded_font as Font)


func _apply_victory_button_style(button: Button) -> void:
	if button == null:
		return

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.17, 0.06, 0.09, 0.9)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.82, 0.27, 0.24, 0.86)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.corner_radius_bottom_left = 10
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.24, 0.08, 0.12, 0.95)
	hover_style.border_color = Color(0.94, 0.34, 0.28, 0.95)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.11, 0.03, 0.05, 0.96)
	pressed_style.border_color = Color(0.98, 0.41, 0.32, 0.95)
	button.add_theme_stylebox_override("pressed", pressed_style)


func _play_victory_intro_animation() -> void:
	if victory_overlay == null or victory_dim_rect == null or victory_card == null:
		return

	if victory_intro_tween != null:
		victory_intro_tween.kill()
		victory_intro_tween = null

	victory_dim_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	victory_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	victory_card.offset_top = victory_card_base_top + 24.0
	victory_card.offset_bottom = victory_card_base_bottom + 24.0

	victory_intro_tween = create_tween()
	victory_intro_tween.set_trans(Tween.TRANS_QUAD)
	victory_intro_tween.set_ease(Tween.EASE_OUT)
	victory_intro_tween.tween_property(victory_dim_rect, "color:a", 0.0, 0.22)
	victory_intro_tween.parallel().tween_property(victory_card, "modulate:a", 1.0, 0.24)
	victory_intro_tween.parallel().tween_property(victory_card, "offset_top", victory_card_base_top, 0.24)
	victory_intro_tween.parallel().tween_property(victory_card, "offset_bottom", victory_card_base_bottom, 0.24)
	victory_intro_tween.tween_callback(Callable(self, "_finish_victory_intro"))


func _finish_victory_intro() -> void:
	get_tree().paused = true
	if victory_restart_button != null:
		victory_restart_button.grab_focus()


func _show_victory_overlay() -> void:
	if victory_overlay == null:
		return
	if is_instance_valid(bgm_player):
		bgm_player.stop()
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0

	victory_overlay.visible = true
	_play_victory_intro_animation()


func _on_victory_restart_pressed() -> void:
	if victory_intro_tween != null:
		victory_intro_tween.kill()
		victory_intro_tween = null
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0
	get_tree().paused = false
	portal_finished = false
	get_tree().reload_current_scene()


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

func _apply_platform_ordering() -> void:
	# Padroniza camadas visuais para comportamento consistente de plataforma.
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


func _bind_collectible_coins() -> void:
	var coin_nodes: Array[Node] = get_tree().get_nodes_in_group("collectible_coin")
	for coin_node in coin_nodes:
		if not coin_node.has_signal("collected"):
			continue
		var callback: Callable = Callable(self, "_on_coin_collected")
		if not coin_node.is_connected("collected", callback):
			coin_node.connect("collected", callback)


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
	if hud_layer == null:
		return
	if hud_layer.has_method("set_coin_count"):
		hud_layer.call("set_coin_count", coins_collected)


func _bind_map_gold_item() -> void:
	if map_gold_item == null:
		return
	var callback: Callable = Callable(self, "_on_map_gold_body_entered")
	if not map_gold_item.is_connected("body_entered", callback):
		map_gold_item.body_entered.connect(_on_map_gold_body_entered)


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
	if boss_ref.has_signal("defeated"):
		var callback: Callable = Callable(self, "_on_boss_defeated")
		if not boss_ref.is_connected("defeated", callback):
			boss_ref.connect("defeated", callback)
	if boss_ref.has_signal("health_changed"):
		var hp_callback: Callable = Callable(self, "_on_boss_health_changed")
		if not boss_ref.is_connected("health_changed", hp_callback):
			boss_ref.connect("health_changed", hp_callback)
	if boss_ref.has_method("set_boss_active"):
		boss_ref.call("set_boss_active", false)
	else:
		boss_ref.visible = false
		boss_ref.set_physics_process(false)
	_set_boss_hud_visible(false)
	_refresh_boss_hud_from_boss()


func _bind_player_lifecycle() -> void:
	if player_ref == null:
		return

	if player_ref.has_signal("died"):
		var died_callback: Callable = Callable(self, "_on_player_died")
		if not player_ref.is_connected("died", died_callback):
			player_ref.connect("died", died_callback)

	if player_ref.has_signal("respawned"):
		var respawn_callback: Callable = Callable(self, "_on_player_respawned")
		if not player_ref.is_connected("respawned", respawn_callback):
			player_ref.connect("respawned", respawn_callback)


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


func _on_player_respawned() -> void:
	_reset_dialog_runtime_flags()
	if map_gold_unlocked and not map_gold_collected and map_gold_item != null and map_gold_item.visible:
		_queue_player_dialog_line(DIALOG_MAP_GOLD_APPEARED, PLAYER_DIALOG_DURATION)


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


func _reset_dialog_runtime_flags() -> void:
	saw_skeleton_once = false
	saw_bat_once = false
	saw_slime_once = false
	saw_boss_approach_once = false


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
