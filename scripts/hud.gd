extends CanvasLayer

@export var player_path: NodePath

const MAX_HEARTS_DISPLAY: int = 5
const HEART_FULL: String = "\u2665"
const HEART_EMPTY: String = "\u2661"
const STAMINA_BAR_WIDTH: float = 84.0
const STAMINA_SMOOTH_SPEED: float = 9.0
const HUD_FONT_PATH: String = "res://fonts/Buffied-GlqZ.ttf"
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 3.0
const VOLUME_STEP_DB: float = 2.0

@onready var lives_label: RichTextLabel = get_node_or_null("MarginContainer/PanelContainer/VBox/TopRow/LivesLabel")
@onready var stamina_fill: Panel = get_node_or_null("MarginContainer/PanelContainer/VBox/StaminaRow/StaminaBar/StaminaFill")
@onready var level_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/LevelLabel")
@onready var xp_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/XpLabel")
@onready var coins_label: Label = get_node_or_null("CoinsLabel")
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
var hearts_base_scale: Vector2 = Vector2.ONE
var hearts_base_modulate: Color = Color(1, 1, 1, 1)
var hearts_damage_tween: Tween = null
var stamina_fill_style: StyleBoxFlat = null
var master_bus_index: int = -1
var coin_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not _has_required_nodes():
		return

	_apply_vampire_font()
	_setup_stamina_fill_style()
	_setup_pause_options_menu()

	hearts_base_scale = lives_label.scale
	hearts_base_modulate = lives_label.modulate

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
	if not _has_required_nodes():
		return

	# Suaviza a leitura visual da stamina para evitar "saltos" bruscos no HUD.
	displayed_stamina_ratio = lerpf(displayed_stamina_ratio, target_stamina_ratio, clampf(delta * STAMINA_SMOOTH_SPEED, 0.0, 1.0))
	_apply_stamina_visuals(false, delta)

	_refresh_level_xp()


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false


func _on_player_stats_changed(current_hp: int, max_hp_value: int, current_stamina: float, max_stamina_value: float, _current_lives: int) -> void:
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

	_update_lives_display(current_hp, max_hp_value)


func _refresh_from_player() -> void:
	if player_ref == null:
		return

	var current_hp := int(player_ref.get("hp"))
	var current_stamina := float(player_ref.get("stamina"))
	var max_stamina_value := float(player_ref.get("max_stamina"))
	var max_hp_value := int(player_ref.get("max_hp"))
	_on_player_stats_changed(current_hp, max_hp_value, current_stamina, max_stamina_value, 0)
	_refresh_level_xp()


func _refresh_level_xp() -> void:
	if player_ref == null:
		return

	var level_value := int(player_ref.get("level"))
	var xp_value := int(player_ref.get("xp"))
	var xp_to_next := int(player_ref.get("xp_to_next_level"))

	level_label.text = "Lv.: %d" % level_value
	xp_label.text = "XP: %d / %d" % [xp_value, maxi(xp_to_next, 1)]


func _update_lives_display(current_hp: int, max_hp_value: int) -> void:
	var max_half_steps := MAX_HEARTS_DISPLAY * 2
	var filled_half_steps := max_half_steps

	if max_hp_value > 0:
		var hp_ratio := clampf(float(current_hp) / float(max_hp_value), 0.0, 1.0)
		filled_half_steps = clampi(int(floor(hp_ratio * float(max_half_steps) + 0.0001)), 0, max_half_steps)

	var full: int = int(filled_half_steps * 0.5)
	var has_half: bool = (filled_half_steps % 2) == 1
	var empty: int = MAX_HEARTS_DISPLAY - full - (1 if has_half else 0)

	var hearts_bbcode := "[color=#ff4a5f]" + HEART_FULL.repeat(full) + "[/color]"
	if has_half:
		# Show a visually half-like heart using a lighter red, without the "1/2" glyph.
		hearts_bbcode += "[color=#ff9aa8]" + HEART_FULL + "[/color]"
	hearts_bbcode += "[color=#f0e7eb]" + HEART_EMPTY.repeat(maxi(empty, 0)) + "[/color]"
	lives_label.text = hearts_bbcode


func _apply_stamina_visuals(force_target: bool, _delta: float) -> void:
	var ratio := target_stamina_ratio if force_target else displayed_stamina_ratio
	var fill_width := STAMINA_BAR_WIDTH * ratio
	stamina_fill.offset_right = fill_width

	if stamina_fill_style == null:
		return

	if ratio > 0.6:
		stamina_fill_style.bg_color = Color(0.25, 0.86, 0.55, 1)
	elif ratio > 0.3:
		stamina_fill_style.bg_color = Color(0.97, 0.78, 0.27, 1)
	else:
		stamina_fill_style.bg_color = Color(0.93, 0.28, 0.33, 1)


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
	if lives_label == null:
		return

	var intensity := clampf(damage_ratio * 3.0, 0.35, 1.0)
	if hearts_damage_tween != null:
		hearts_damage_tween.kill()

	lives_label.scale = hearts_base_scale
	lives_label.rotation_degrees = 0.0
	lives_label.modulate = Color(1.0, 0.48, 0.48, 1.0)

	var bump_scale := hearts_base_scale * (1.0 + (0.18 * intensity))
	var squeeze_scale := hearts_base_scale * (1.0 - (0.12 * intensity))

	hearts_damage_tween = create_tween()
	hearts_damage_tween.set_trans(Tween.TRANS_QUAD)
	hearts_damage_tween.set_ease(Tween.EASE_OUT)

	hearts_damage_tween.tween_property(lives_label, "rotation_degrees", -6.0 * intensity, 0.035)
	hearts_damage_tween.parallel().tween_property(lives_label, "scale", bump_scale, 0.07)

	hearts_damage_tween.tween_property(lives_label, "rotation_degrees", 4.0 * intensity, 0.05)
	hearts_damage_tween.parallel().tween_property(lives_label, "scale", squeeze_scale, 0.07)

	hearts_damage_tween.tween_property(lives_label, "rotation_degrees", 0.0, 0.06)
	hearts_damage_tween.parallel().tween_property(lives_label, "scale", hearts_base_scale, 0.1)
	hearts_damage_tween.parallel().tween_property(lives_label, "modulate", hearts_base_modulate, 0.18)


func _has_required_nodes() -> bool:
	return lives_label != null \
		and stamina_fill != null \
		and level_label != null \
		and xp_label != null


func _apply_vampire_font() -> void:
	if not ResourceLoader.exists(HUD_FONT_PATH):
		return

	var loaded_font: Resource = load(HUD_FONT_PATH)
	if not (loaded_font is Font):
		return

	var vampire_font: Font = loaded_font as Font
	lives_label.add_theme_font_override("font", vampire_font)
	level_label.add_theme_font_override("font", vampire_font)
	xp_label.add_theme_font_override("font", vampire_font)
	if coins_label != null:
		coins_label.add_theme_font_override("font", vampire_font)
	if pause_volume_value_label != null:
		pause_volume_value_label.add_theme_font_override("font", vampire_font)
	if pause_resume_button != null:
		pause_resume_button.add_theme_font_override("font", vampire_font)
	if pause_exit_button != null:
		pause_exit_button.add_theme_font_override("font", vampire_font)
	var pause_title: Label = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/OptionsTitleLabel")
	if pause_title != null:
		pause_title.add_theme_font_override("font", vampire_font)
	var pause_volume_label: Label = get_node_or_null("OptionsOverlay/OptionsCard/OptionsVBox/VolumeLabel")
	if pause_volume_label != null:
		pause_volume_label.add_theme_font_override("font", vampire_font)


func _setup_stamina_fill_style() -> void:
	if stamina_fill == null:
		return

	var panel_style: StyleBox = stamina_fill.get_theme_stylebox("panel")
	if not (panel_style is StyleBoxFlat):
		return

	stamina_fill_style = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	stamina_fill.add_theme_stylebox_override("panel", stamina_fill_style)


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
	_close_options_overlay()


func _on_pause_exit_pressed() -> void:
	get_tree().quit()


func _on_pause_volume_down_pressed() -> void:
	if pause_volume_slider == null:
		return
	_apply_pause_volume_db(pause_volume_slider.value - VOLUME_STEP_DB)


func _on_pause_volume_up_pressed() -> void:
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
