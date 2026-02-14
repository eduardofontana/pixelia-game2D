extends CanvasLayer

@export var player_path: NodePath

const MAX_HEARTS_DISPLAY: int = 5
const HP_ICON: String = "💓"
const MAX_LIFE_ICONS_DISPLAY: int = 5
const LIFE_ICON_FULL: String = "❤️"
const STAMINA_DOTS_TOTAL: int = 5
const STAMINA_ICON_FULL: String = "🐇"
const STAMINA_SMOOTH_SPEED: float = 9.0
const HUD_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 3.0
const VOLUME_STEP_DB: float = 2.0

@onready var life_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/LifeRow/LifeLabel")
@onready var hp_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/TopRow/HpLabel")
@onready var life_icons_label: RichTextLabel = get_node_or_null("MarginContainer/PanelContainer/VBox/LifeRow/LifeIconsLabel")
@onready var lives_label: RichTextLabel = get_node_or_null("MarginContainer/PanelContainer/VBox/TopRow/LivesLabel")
@onready var stamina_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/StaminaRow/StaminaLabel")
@onready var stamina_dots_label: RichTextLabel = get_node_or_null("MarginContainer/PanelContainer/VBox/StaminaRow/StaminaDotsLabel")
@onready var level_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/LevelLabel")
@onready var xp_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/XpLabel")
@onready var coins_label: Label = get_node_or_null("MarginContainer/PanelContainer/VBox/InfoRow/CoinsLabel")
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
var master_bus_index: int = -1
var coin_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not _has_required_nodes():
		return

	_apply_hud_font()
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


func _update_lives_display(current_hp: int, max_hp_value: int) -> void:
	var filled_icons := MAX_HEARTS_DISPLAY
	if max_hp_value > 0:
		var hp_ratio := clampf(float(current_hp) / float(max_hp_value), 0.0, 1.0)
		filled_icons = clampi(int(round(hp_ratio * float(MAX_HEARTS_DISPLAY))), 0, MAX_HEARTS_DISPLAY)
	var hidden_icons := MAX_HEARTS_DISPLAY - filled_icons
	lives_label.text = "[color=#ffffff]%s[/color][color=#ffffff00]%s[/color]" % [
		HP_ICON.repeat(filled_icons),
		HP_ICON.repeat(maxi(hidden_icons, 0))
	]


func _update_life_label(current_lives: int) -> void:
	if life_label == null:
		return
	life_label.text = "Life:"
	if life_icons_label == null:
		return

	var filled_icons := clampi(current_lives, 0, MAX_LIFE_ICONS_DISPLAY)
	var hidden_icons := MAX_LIFE_ICONS_DISPLAY - filled_icons
	life_icons_label.text = "[color=#ffffff]%s[/color][color=#ffffff00]%s[/color]" % [
		LIFE_ICON_FULL.repeat(filled_icons),
		LIFE_ICON_FULL.repeat(maxi(hidden_icons, 0))
	]


func _apply_stamina_visuals(force_target: bool, _delta: float) -> void:
	var ratio := target_stamina_ratio if force_target else displayed_stamina_ratio
	if stamina_dots_label == null:
		return

	var filled_dots := clampi(int(round(ratio * float(STAMINA_DOTS_TOTAL))), 0, STAMINA_DOTS_TOTAL)
	var hidden_dots := STAMINA_DOTS_TOTAL - filled_dots
	stamina_dots_label.text = "[color=#ffffff]%s[/color][color=#ffffff00]%s[/color]" % [
		STAMINA_ICON_FULL.repeat(filled_dots),
		STAMINA_ICON_FULL.repeat(maxi(hidden_dots, 0))
	]


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

	# Mantem o texto estavel: sem escala/rotacao ao tomar dano.
	lives_label.modulate = Color(1.0, 0.48, 0.48, 1.0)

	hearts_damage_tween = create_tween()
	hearts_damage_tween.set_trans(Tween.TRANS_QUAD)
	hearts_damage_tween.set_ease(Tween.EASE_OUT)
	hearts_damage_tween.tween_property(lives_label, "modulate", hearts_base_modulate, 0.16 + (0.04 * intensity))


func _has_required_nodes() -> bool:
	return life_label != null \
		and hp_label != null \
		and life_icons_label != null \
		and lives_label != null \
		and stamina_label != null \
		and stamina_dots_label != null \
		and level_label != null \
		and xp_label != null


func _apply_hud_font() -> void:
	if not ResourceLoader.exists(HUD_FONT_PATH):
		return
	var loaded_font: Resource = load(HUD_FONT_PATH)
	if not (loaded_font is Font):
		return
	var hud_font: Font = loaded_font as Font
	hp_label.add_theme_font_override("font", hud_font)
	life_label.add_theme_font_override("font", hud_font)
	life_icons_label.add_theme_font_override("font", hud_font)
	lives_label.add_theme_font_override("font", hud_font)
	stamina_label.add_theme_font_override("font", hud_font)
	stamina_dots_label.add_theme_font_override("font", hud_font)
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
