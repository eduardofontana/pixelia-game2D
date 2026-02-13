extends Node2D

const GAME_SCENE_PATH: String = "res://scenes/main.tscn"
const HUD_FONT_PATH: String = "res://fonts/Buffied-GlqZ.ttf"
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 3.0
const VOLUME_STEP_DB: float = 2.0

@onready var background_parallax: ParallaxBackground = $Background/ParallaxBackground
@onready var menu_card: PanelContainer = $UILayer/MenuCard
@onready var options_card: PanelContainer = $UILayer/OptionsCard
@onready var play_button: Button = $UILayer/MenuCard/MenuVBox/PlayButton
@onready var options_button: Button = $UILayer/MenuCard/MenuVBox/OptionsButton
@onready var quit_button: Button = $UILayer/MenuCard/MenuVBox/QuitButton
@onready var skull_label: Label = $UILayer/MenuCard/MenuVBox/SkullLabel
@onready var volume_down_button: Button = $UILayer/OptionsCard/OptionsVBox/VolumeControls/VolumeDownButton
@onready var volume_up_button: Button = $UILayer/OptionsCard/OptionsVBox/VolumeControls/VolumeUpButton
@onready var volume_slider: HSlider = $UILayer/OptionsCard/OptionsVBox/VolumeControls/VolumeSlider
@onready var volume_value_label: Label = $UILayer/OptionsCard/OptionsVBox/VolumeValueLabel
@onready var back_button: Button = $UILayer/OptionsCard/OptionsVBox/BackButton
@onready var menu_bgm: AudioStreamPlayer = $BGM

var master_bus_index: int = -1


func _ready() -> void:
	_setup_skull_emoji()
	_bind_signals()
	_apply_vampire_font()
	_setup_volume_controls()
	_setup_parallax_tiles()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_show_main_menu()
	_setup_bgm_loop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and options_card.visible:
		_show_main_menu()
		get_viewport().set_input_as_handled()


func _bind_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	volume_down_button.pressed.connect(_on_volume_down_pressed)
	volume_up_button.pressed.connect(_on_volume_up_pressed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	back_button.pressed.connect(_on_back_pressed)


func _apply_vampire_font() -> void:
	if not ResourceLoader.exists(HUD_FONT_PATH):
		return

	var loaded_font: Resource = load(HUD_FONT_PATH)
	if not (loaded_font is Font):
		return

	var vampire_font: Font = loaded_font as Font
	var text_nodes: Array[Control] = [
		$UILayer/MenuCard/MenuVBox/TitleLabel,
		skull_label,
		$UILayer/MenuCard/MenuVBox/SubtitleLabel,
		play_button,
		options_button,
		quit_button,
		$UILayer/OptionsCard/OptionsVBox/OptionsTitleLabel,
		$UILayer/OptionsCard/OptionsVBox/VolumeRow/VolumeLabel,
		volume_down_button,
		volume_up_button,
		volume_value_label,
		back_button
	]

	for node in text_nodes:
		node.add_theme_font_override("font", vampire_font)


func _setup_skull_emoji() -> void:
	if skull_label == null:
		return
	skull_label.text = char(0x2620)


func _setup_volume_controls() -> void:
	master_bus_index = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		master_bus_index = 0

	volume_slider.min_value = MIN_VOLUME_DB
	volume_slider.max_value = MAX_VOLUME_DB
	volume_slider.step = 0.5

	var current_db: float = AudioServer.get_bus_volume_db(master_bus_index)
	_apply_volume_db(current_db, false)


func _setup_bgm_loop() -> void:
	if menu_bgm == null:
		return
	menu_bgm.finished.connect(_on_bgm_finished)
	if not menu_bgm.playing:
		menu_bgm.play()


func _setup_parallax_tiles() -> void:
	if background_parallax == null:
		return

	var viewport_width: float = float(get_viewport_rect().size.x)
	for child in background_parallax.get_children():
		if not (child is ParallaxLayer):
			continue

		var layer: ParallaxLayer = child as ParallaxLayer
		var mirror_x: float = layer.motion_mirroring.x
		if mirror_x <= 0.0:
			continue

		var base_sprite: Sprite2D = null
		for layer_child in layer.get_children():
			if not (layer_child is Sprite2D):
				continue
			var sprite_child: Sprite2D = layer_child as Sprite2D
			if sprite_child.name.begins_with("AutoTileCopy_"):
				sprite_child.queue_free()
			elif base_sprite == null:
				base_sprite = sprite_child

		if base_sprite == null:
			continue

		# Cria copias para cobrir lateral esquerda/direita em resolucoes largas.
		var copies_each_side: int = int(ceil(viewport_width / mirror_x)) + 1
		for i in range(-1, copies_each_side + 1):
			if i == 0:
				continue
			var sprite_copy: Sprite2D = base_sprite.duplicate() as Sprite2D
			sprite_copy.name = "AutoTileCopy_%d" % i
			sprite_copy.position = base_sprite.position + Vector2(float(i) * mirror_x, 0.0)
			layer.add_child(sprite_copy)


func _on_viewport_size_changed() -> void:
	_setup_parallax_tiles()


func _show_main_menu() -> void:
	menu_card.visible = true
	options_card.visible = false
	play_button.grab_focus()


func _show_options_menu() -> void:
	menu_card.visible = false
	options_card.visible = true
	back_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	_show_options_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	_show_main_menu()


func _on_volume_down_pressed() -> void:
	_apply_volume_db(volume_slider.value - VOLUME_STEP_DB)


func _on_volume_up_pressed() -> void:
	_apply_volume_db(volume_slider.value + VOLUME_STEP_DB)


func _on_volume_slider_changed(value: float) -> void:
	_apply_volume_db(value)


func _apply_volume_db(volume_db: float, write_bus: bool = true) -> void:
	var clamped_db: float = clampf(volume_db, MIN_VOLUME_DB, MAX_VOLUME_DB)
	if write_bus and master_bus_index >= 0:
		AudioServer.set_bus_volume_db(master_bus_index, clamped_db)

	volume_slider.set_value_no_signal(clamped_db)
	_update_volume_label(clamped_db)


func _update_volume_label(volume_db: float) -> void:
	# Converte dB para percentual para facilitar leitura do jogador.
	var percent: int = int(round(clampf(db_to_linear(volume_db), 0.0, 1.0) * 100.0))
	volume_value_label.text = "Volume: %d%%" % percent


func _on_bgm_finished() -> void:
	if menu_bgm != null:
		menu_bgm.play()
