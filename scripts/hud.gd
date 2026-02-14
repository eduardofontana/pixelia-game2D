extends CanvasLayer

@export var player_path: NodePath

const STAMINA_BAR_WIDTH: float = 88.0
const STAMINA_BAR_INSET: float = 1.0
const STAMINA_SMOOTH_SPEED: float = 9.0
const HUD_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const CONTROLS_HINT_VISIBLE_SECONDS: float = 10.0
const CONTROLS_HINT_FADE_SECONDS: float = 0.35
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 3.0
const VOLUME_STEP_DB: float = 2.0
const MENU_CLICK_SFX_VOLUME_DB: float = -5.0
const MENU_CLICK_SFX_STREAM: AudioStream = preload("res://sounds/click_double_off.wav")

@onready var life_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/LifeRow/LifeLabel")
@onready var hp_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/TopRow/HpLabel")
@onready var hp_hearts_container: HBoxContainer = get_node_or_null("MarginContainer/PanelContainer/VBox/TopRow/HpHearts")
@onready var life_hearts_container: HBoxContainer = get_node_or_null("MarginContainer/PanelContainer/VBox/LifeRow/LifeHearts")
@onready var stamina_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/StaminaRow/StaminaLabel")
@onready var stamina_bar_bg: Control = get_node_or_null("MarginContainer/PanelContainer/VBox/StaminaRow/StaminaBar/Bg")
@onready var stamina_bar_fill: Control = get_node_or_null("MarginContainer/PanelContainer/VBox/StaminaRow/StaminaBar/Bg/Fill")
@onready var level_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/LevelLabel")
@onready var xp_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/XpLabel")
@onready var coins_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/CoinsLabel")
@onready var controls_hint_card: Control = get_node_or_null("ControlsHintCard")
@onready var options_overlay: Control = get_node_or_null("OptionsOverlay")
@onready var pause_volume_down_button: Button = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/VolumeControls/VolumeDownButton")
@onready var pause_volume_up_button: Button = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/VolumeControls/VolumeUpButton")
@onready var pause_volume_slider: HSlider = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/VolumeControls/VolumeSlider")
@onready var pause_volume_value_label: Label = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/VolumeValueLabel")
@onready var pause_resume_button: Button = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/ActionsRow/ResumeButton")
@onready var pause_exit_button: Button = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/ActionsRow/ExitButton")

var player_ref: Node = null
var target_stamina_ratio: float = 1.0
var displayed_stamina_ratio: float = 1.0
var previous_hp_ratio: float = 1.0
var has_initial_hp_sample: bool = false
var hearts_base_modulate: Color = Color(1, 1, 1, 1)
var hearts_damage_tween: Tween = null
var stamina_fill_style: StyleBoxFlat = null
var stamina_low_pulse_time: float = 0.0
var master_bus_index: int = -1
var coin_count: int = 0
var hp_hearts: Array[CanvasItem] = []
var life_hearts: Array[CanvasItem] = []
var hud_nodes_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_cache_heart_nodes()

	if not _has_required_nodes():
		return
	hud_nodes_ready = true

	_apply_hud_font()
	_setup_controls_hint_card()
	_setup_sprint_fill_style()
	_setup_pause_options_menu()

	hearts_base_modulate = hp_hearts_container.modulate

	if not player_path.is_empty():
		player_ref = get_node_or_null(player_path)
	else:
		var parent_node := get_parent()
		if parent_node != null:
			player_ref = parent_node.get_node_or_null("Player")

	if player_ref == null:
		call_deferred("_retry_bind_player")
	elif player_ref.has_signal("stats_changed"):
		player_ref.connect("stats_changed", Callable(self, "_on_player_stats_changed"))

	_refresh_from_player()
	_apply_stamina_visuals(true, 1.0)
	_update_coin_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") or event.is_action_pressed("ui_cancel"):
		_toggle_options_overlay()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not hud_nodes_ready:
		return

	# Suaviza a leitura visual da stamina para evitar "saltos" bruscos no HUD.
	displayed_stamina_ratio = lerpf(displayed_stamina_ratio, target_stamina_ratio, clampf(delta * STAMINA_SMOOTH_SPEED, 0.0, 1.0))
	_apply_stamina_visuals(false, delta)

	_refresh_level_xp()


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false


func _on_player_stats_changed(current_hp: int, max_hp_value: int, current_stamina: float, max_stamina_value: float, current_lives: int) -> void:
	var ratio := 0.0
	if max_stamina_value > 0.0:
		ratio = clampf(current_stamina / max_stamina_value, 0.0, 1.0)
	target_stamina_ratio = ratio

	var hp_ratio := 1.0
	if max_hp_value > 0:
		hp_ratio = clampf(float(current_hp) / float(max_hp_value), 0.0, 1.0)

	if has_initial_hp_sample and hp_ratio < previous_hp_ratio:
		_animate_hearts_damage(previous_hp_ratio - hp_ratio)
	previous_hp_ratio = hp_ratio
	has_initial_hp_sample = true

	_update_life_label(current_lives)
	_update_lives_display(current_hp, max_hp_value)


func _refresh_from_player() -> void:
	if player_ref == null:
		return

	var current_hp := int(player_ref.get("hp"))
	var current_stamina := float(player_ref.get("stamina"))
	var max_stamina_value := float(player_ref.get("max_stamina"))
	var max_hp_value := int(player_ref.get("max_hp"))
	var current_lives := int(player_ref.get("lives"))
	_on_player_stats_changed(current_hp, max_hp_value, current_stamina, max_stamina_value, current_lives)
	_refresh_level_xp()


func _refresh_level_xp() -> void:
	if player_ref == null:
		return

	var level_value := int(player_ref.get("level"))
	var xp_value := int(player_ref.get("xp"))
	var xp_to_next := int(player_ref.get("xp_to_next_level"))

	level_label.text = "Level: %d" % level_value
	xp_label.text = "XP: %d / %d" % [xp_value, maxi(xp_to_next, 1)]


func _cache_heart_nodes() -> void:
	hp_hearts = _collect_heart_nodes(hp_hearts_container)
	life_hearts = _collect_heart_nodes(life_hearts_container)


func _collect_heart_nodes(container: Node) -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	if container == null:
		return result

	for child in container.get_children():
		if child is CanvasItem:
			result.append(child as CanvasItem)
	return result


func _update_lives_display(current_hp: int, max_hp_value: int) -> void:
	var filled_icons := hp_hearts.size()
	if max_hp_value > 0:
		var hp_ratio: float = clampf(float(current_hp) / float(max_hp_value), 0.0, 1.0)
		filled_icons = clampi(int(round(hp_ratio * float(hp_hearts.size()))), 0, hp_hearts.size())
	_set_hearts_fill(hp_hearts, filled_icons)


func _update_life_label(current_lives: int) -> void:
	if life_label == null:
		return
	life_label.text = "Life:"
	var filled_icons: int = clampi(current_lives, 0, life_hearts.size())
	_set_hearts_fill(life_hearts, filled_icons)


func _set_hearts_fill(heart_nodes: Array[CanvasItem], filled_count: int) -> void:
	for index in range(heart_nodes.size()):
		var heart: CanvasItem = heart_nodes[index]
		if heart == null:
			continue
		heart.visible = true
		if index < filled_count:
			heart.modulate = Color(1, 1, 1, 1)
		else:
			heart.modulate = Color(1, 1, 1, 0.2)


func _apply_stamina_visuals(force_target: bool, delta: float) -> void:
	var ratio: float = target_stamina_ratio if force_target else displayed_stamina_ratio
	ratio = clampf(ratio, 0.0, 1.0)
	if stamina_bar_fill == null or stamina_bar_bg == null:
		return

	var bg_width: float = maxf(stamina_bar_bg.size.x, STAMINA_BAR_WIDTH)
	var bar_width: float = maxf(1.0, bg_width - (STAMINA_BAR_INSET * 2.0))
	var bar_height: float = maxf(1.0, stamina_bar_bg.size.y - (STAMINA_BAR_INSET * 2.0))
	stamina_bar_fill.position = Vector2(STAMINA_BAR_INSET, STAMINA_BAR_INSET)
	stamina_bar_fill.size.y = bar_height
	stamina_bar_fill.size.x = bar_width * ratio

	if stamina_fill_style != null:
		if ratio > 0.55:
			stamina_fill_style.bg_color = Color(0.24, 0.86, 0.44, 0.95)
		elif ratio > 0.3:
			stamina_fill_style.bg_color = Color(0.94, 0.74, 0.23, 0.95)
		else:
			stamina_fill_style.bg_color = Color(0.9, 0.2, 0.22, 0.95)

	if ratio <= 0.3:
		stamina_low_pulse_time += delta
		var pulse_wave: float = 0.5 + (0.5 * sin(stamina_low_pulse_time * 16.0))
		stamina_bar_fill.modulate = Color(1.0, 1.0, 1.0, lerpf(0.62, 1.0, pulse_wave))
	else:
		stamina_low_pulse_time = 0.0
		stamina_bar_fill.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _retry_bind_player() -> void:
	if player_ref != null:
		return

	var parent_node := get_parent()
	if parent_node != null:
		player_ref = parent_node.get_node_or_null("Player")

	if player_ref != null and player_ref.has_signal("stats_changed"):
		player_ref.connect("stats_changed", Callable(self, "_on_player_stats_changed"))
		_refresh_from_player()


func _animate_hearts_damage(damage_ratio: float) -> void:
	if hp_hearts_container == null:
		return

	var intensity := clampf(damage_ratio * 3.0, 0.35, 1.0)
	if hearts_damage_tween != null:
		hearts_damage_tween.kill()

	hp_hearts_container.modulate = Color(1.0, 0.48, 0.48, 1.0)

	hearts_damage_tween = create_tween()
	hearts_damage_tween.set_trans(Tween.TRANS_QUAD)
	hearts_damage_tween.set_ease(Tween.EASE_OUT)
	hearts_damage_tween.tween_property(hp_hearts_container, "modulate", hearts_base_modulate, 0.16 + (0.04 * intensity))


func _has_required_nodes() -> bool:
	return life_label != null \
		and hp_label != null \
		and hp_hearts_container != null \
		and life_hearts_container != null \
		and stamina_label != null \
		and stamina_bar_bg != null \
		and stamina_bar_fill != null \
		and level_label != null \
		and xp_label != null \
		and hp_hearts.size() > 0 \
		and life_hearts.size() > 0


func _apply_hud_font() -> void:
	if not ResourceLoader.exists(HUD_FONT_PATH):
		return
	var loaded_font: Resource = load(HUD_FONT_PATH)
	if not (loaded_font is Font):
		return
	var hud_font: Font = loaded_font as Font
	hp_label.add_theme_font_override("font", hud_font)
	life_label.add_theme_font_override("font", hud_font)
	stamina_label.add_theme_font_override("font", hud_font)
	level_label.add_theme_font_override("font", hud_font)
	xp_label.add_theme_font_override("font", hud_font)
	if coins_label != null:
		coins_label.add_theme_font_override("font", hud_font)
	if pause_volume_value_label != null:
		pause_volume_value_label.add_theme_font_override("font", hud_font)
	if pause_resume_button != null:
		pause_resume_button.add_theme_font_override("font", hud_font)
	if pause_exit_button != null:
		pause_exit_button.add_theme_font_override("font", hud_font)
	if pause_volume_down_button != null:
		pause_volume_down_button.add_theme_font_override("font", hud_font)
	if pause_volume_up_button != null:
		pause_volume_up_button.add_theme_font_override("font", hud_font)
	var pause_title: Label = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/OptionsTitleLabel")
	if pause_title != null:
		pause_title.add_theme_font_override("font", hud_font)
	var pause_volume_label: Label = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/VolumeLabel")
	if pause_volume_label != null:
		pause_volume_label.add_theme_font_override("font", hud_font)
	var controls_hint_root: Node = get_node_or_null("ControlsHintCard")
	if controls_hint_root != null:
		for label_node in controls_hint_root.find_children("*", "Label", true, false):
			var hint_label: Label = label_node as Label
			if hint_label != null:
				hint_label.add_theme_font_override("font", hud_font)


func _setup_sprint_fill_style() -> void:
	if stamina_bar_fill == null:
		return

	var panel_style: StyleBox = stamina_bar_fill.get_theme_stylebox("panel")
	if not (panel_style is StyleBoxFlat):
		return

	stamina_fill_style = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	stamina_bar_fill.add_theme_stylebox_override("panel", stamina_fill_style)


func _setup_controls_hint_card() -> void:
	if controls_hint_card == null:
		return
	controls_hint_card.visible = true
	controls_hint_card.modulate = Color(1, 1, 1, 1)

	var hint_tween: Tween = create_tween()
	hint_tween.tween_interval(maxf(0.1, CONTROLS_HINT_VISIBLE_SECONDS))
	hint_tween.tween_property(controls_hint_card, "modulate", Color(1, 1, 1, 0), maxf(0.05, CONTROLS_HINT_FADE_SECONDS))
	hint_tween.tween_callback(func() -> void:
		if controls_hint_card != null:
			controls_hint_card.visible = false
	)


func _setup_pause_options_menu() -> void:
	if options_overlay == null or pause_volume_slider == null:
		return

	options_overlay.visible = false

	if pause_resume_button != null:
		pause_resume_button.pressed.connect(_on_pause_resume_pressed)
	if pause_exit_button != null:
		pause_exit_button.pressed.connect(_on_pause_exit_pressed)
	if pause_volume_down_button != null:
		pause_volume_down_button.pressed.connect(_on_pause_volume_down_pressed)
	if pause_volume_up_button != null:
		pause_volume_up_button.pressed.connect(_on_pause_volume_up_pressed)
	pause_volume_slider.value_changed.connect(_on_pause_volume_slider_changed)

	master_bus_index = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		master_bus_index = 0

	pause_volume_slider.min_value = MIN_VOLUME_DB
	pause_volume_slider.max_value = MAX_VOLUME_DB
	pause_volume_slider.step = 0.5

	var current_db: float = AudioServer.get_bus_volume_db(master_bus_index)
	_apply_pause_volume_db(current_db, false)


func _toggle_options_overlay() -> void:
	if options_overlay == null:
		return

	if options_overlay.visible:
		_close_options_overlay()
	else:
		_open_options_overlay()


func _open_options_overlay() -> void:
	if options_overlay == null:
		return

	options_overlay.visible = true
	get_tree().paused = true
	if pause_resume_button != null:
		pause_resume_button.grab_focus()


func _close_options_overlay() -> void:
	if options_overlay == null:
		return

	options_overlay.visible = false
	get_tree().paused = false


func _on_pause_resume_pressed() -> void:
	_play_menu_click_sfx()
	_close_options_overlay()


func _on_pause_exit_pressed() -> void:
	_play_menu_click_sfx()
	get_tree().quit()


func _on_pause_volume_down_pressed() -> void:
	_play_menu_click_sfx()
	if pause_volume_slider == null:
		return
	_apply_pause_volume_db(pause_volume_slider.value - VOLUME_STEP_DB)


func _on_pause_volume_up_pressed() -> void:
	_play_menu_click_sfx()
	if pause_volume_slider == null:
		return
	_apply_pause_volume_db(pause_volume_slider.value + VOLUME_STEP_DB)


func _on_pause_volume_slider_changed(value: float) -> void:
	_apply_pause_volume_db(value)


func _apply_pause_volume_db(volume_db: float, write_bus: bool = true) -> void:
	if pause_volume_slider == null:
		return

	var clamped_db: float = clampf(volume_db, MIN_VOLUME_DB, MAX_VOLUME_DB)
	if write_bus and master_bus_index >= 0:
		AudioServer.set_bus_volume_db(master_bus_index, clamped_db)

	pause_volume_slider.set_value_no_signal(clamped_db)
	_update_pause_volume_label(clamped_db)


func _update_pause_volume_label(volume_db: float) -> void:
	if pause_volume_value_label == null:
		return

	var percent: int = int(round(clampf(db_to_linear(volume_db), 0.0, 1.0) * 100.0))
	pause_volume_value_label.text = "Volume: %d%%" % percent


func set_coin_count(value: int) -> void:
	coin_count = maxi(value, 0)
	_update_coin_label()


func _update_coin_label() -> void:
	if coins_label == null:
		return
	coins_label.text = "Coins: %d" % coin_count


func _play_menu_click_sfx() -> void:
	if MENU_CLICK_SFX_STREAM == null:
		return
	var root_node: Node = get_tree().root
	if root_node == null:
		return
	var click_player: AudioStreamPlayer = AudioStreamPlayer.new()
	click_player.bus = "SFX"
	click_player.volume_db = MENU_CLICK_SFX_VOLUME_DB
	click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	click_player.stream = MENU_CLICK_SFX_STREAM
	root_node.add_child(click_player)
	click_player.finished.connect(Callable(click_player, "queue_free"))
	click_player.play()
