extends Node2D

const GAME_SCENE_PATH: String = "res://scenes/level01.tscn"
const HUD_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 3.0
const VOLUME_STEP_DB: float = 2.0
const MENU_CLICK_SFX_VOLUME_DB: float = -5.0
const MENU_PARALLAX_OFFSET: Vector2 = Vector2.ZERO
const MENU_CARD_BACKGROUND_PATH: String = "res://background/menupixelia.png"
const MENU_LOADING_IMAGE_PATH: String = "res://background/loadingpixelia.png"
const MENU_LOADING_DURATION: float = 5.0
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const MENU_CLICK_SFX_STREAM: AudioStream = preload("res://sounds/click_double_off.wav")

@onready var background_parallax: ParallaxBackground = $Background/ParallaxBackground
@onready var menu_card: PanelContainer = $UILayer/MenuCard
@onready var options_card: PanelContainer = $UILayer/OptionsCard
@onready var play_button: Button = $UILayer/MenuCard/MenuVBox/PlayButton
@onready var options_button: Button = $UILayer/MenuCard/MenuVBox/OptionsButton
@onready var quit_button: Button = $UILayer/MenuCard/MenuVBox/QuitButton
@onready var skull_label: Label = $UILayer/MenuCard/MenuVBox/SkullLabel
@onready var music_down_button: Button = $UILayer/OptionsCard/OptionsVBox/MusicControls/MusicDownButton
@onready var music_up_button: Button = $UILayer/OptionsCard/OptionsVBox/MusicControls/MusicUpButton
@onready var music_slider: HSlider = $UILayer/OptionsCard/OptionsVBox/MusicControls/MusicSlider
@onready var music_value_label: Label = $UILayer/OptionsCard/OptionsVBox/MusicValueLabel
@onready var sfx_down_button: Button = $UILayer/OptionsCard/OptionsVBox/SfxControls/SfxDownButton
@onready var sfx_up_button: Button = $UILayer/OptionsCard/OptionsVBox/SfxControls/SfxUpButton
@onready var sfx_slider: HSlider = $UILayer/OptionsCard/OptionsVBox/SfxControls/SfxSlider
@onready var sfx_value_label: Label = $UILayer/OptionsCard/OptionsVBox/SfxValueLabel
@onready var fullscreen_button: Button = $UILayer/OptionsCard/OptionsVBox/FullscreenRow/FullscreenButton
@onready var vsync_button: Button = $UILayer/OptionsCard/OptionsVBox/VSyncRow/VSyncButton
@onready var back_button: Button = $UILayer/OptionsCard/OptionsVBox/BackButton
@onready var menu_bgm: AudioStreamPlayer = $BGM

var master_bus_index: int = -1
var music_bus_index: int = -1
var sfx_bus_index: int = -1
var is_starting_game: bool = false
var loading_overlay: CanvasLayer = null
var loading_image_rect: TextureRect = null


func _ready() -> void:
	_ensure_audio_buses()
	_setup_menu_card_background()
	_setup_loading_overlay()
	_remove_menu_emblem()
	_bind_signals()
	_apply_vampire_font()
	_setup_audio_controls()
	_setup_parallax_tiles()
	_apply_menu_parallax_offset()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_show_main_menu()
	_setup_bgm_loop()


func _unhandled_input(event: InputEvent) -> void:
	if is_starting_game:
		return
	if event.is_action_pressed("ui_cancel") and options_card.visible:
		_show_main_menu()
		get_viewport().set_input_as_handled()


func _bind_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	music_down_button.pressed.connect(_on_music_down_pressed)
	music_up_button.pressed.connect(_on_music_up_pressed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_down_button.pressed.connect(_on_sfx_down_pressed)
	sfx_up_button.pressed.connect(_on_sfx_up_pressed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	vsync_button.pressed.connect(_on_vsync_pressed)
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
		$UILayer/OptionsCard/OptionsVBox/MusicRow/MusicLabel,
		music_down_button,
		music_up_button,
		music_value_label,
		$UILayer/OptionsCard/OptionsVBox/SfxRow/SfxLabel,
		sfx_down_button,
		sfx_up_button,
		sfx_value_label,
		$UILayer/OptionsCard/OptionsVBox/FullscreenRow/FullscreenLabel,
		fullscreen_button,
		$UILayer/OptionsCard/OptionsVBox/VSyncRow/VSyncLabel,
		vsync_button,
		back_button
	]

	for node in text_nodes:
		node.add_theme_font_override("font", vampire_font)


func _remove_menu_emblem() -> void:
	if skull_label == null:
		return
	var emblem := skull_label.get_node_or_null("DefendIcon")
	if emblem != null:
		emblem.queue_free()
	skull_label.visible = false
	skull_label.text = ""


func _setup_menu_card_background() -> void:
	if menu_card == null:
		return

	var card_background := menu_card.get_node_or_null("CardBackground") as TextureRect
	if card_background == null:
		card_background = TextureRect.new()
		card_background.name = "CardBackground"
		card_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_background.z_index = -1
		menu_card.add_child(card_background)
		menu_card.move_child(card_background, 0)

	card_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_background.offset_left = 6.0
	card_background.offset_top = 6.0
	card_background.offset_right = -6.0
	card_background.offset_bottom = -6.0
	card_background.modulate = Color(1.0, 1.0, 1.0, 0.98)

	if ResourceLoader.exists(MENU_CARD_BACKGROUND_PATH):
		var loaded_texture: Resource = load(MENU_CARD_BACKGROUND_PATH)
		if loaded_texture is Texture2D:
			card_background.texture = loaded_texture as Texture2D


func _setup_loading_overlay() -> void:
	if loading_overlay != null:
		return

	loading_overlay = CanvasLayer.new()
	loading_overlay.name = "LoadingOverlay"
	loading_overlay.layer = 100
	loading_overlay.visible = false
	add_child(loading_overlay)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 1.0)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_overlay.add_child(shade)

	loading_image_rect = TextureRect.new()
	loading_image_rect.name = "LoadingImage"
	loading_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	loading_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	loading_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_overlay.add_child(loading_image_rect)

	if ResourceLoader.exists(MENU_LOADING_IMAGE_PATH):
		var loaded_texture: Resource = load(MENU_LOADING_IMAGE_PATH)
		if loaded_texture is Texture2D:
			loading_image_rect.texture = loaded_texture as Texture2D


func _set_menu_interactable(enabled: bool) -> void:
	if play_button != null:
		play_button.disabled = not enabled
	if options_button != null:
		options_button.disabled = not enabled
	if quit_button != null:
		quit_button.disabled = not enabled
	if music_down_button != null:
		music_down_button.disabled = not enabled
	if music_up_button != null:
		music_up_button.disabled = not enabled
	if music_slider != null:
		music_slider.editable = enabled
	if sfx_down_button != null:
		sfx_down_button.disabled = not enabled
	if sfx_up_button != null:
		sfx_up_button.disabled = not enabled
	if sfx_slider != null:
		sfx_slider.editable = enabled
	if fullscreen_button != null:
		fullscreen_button.disabled = not enabled
	if vsync_button != null:
		vsync_button.disabled = not enabled
	if back_button != null:
		back_button.disabled = not enabled


func _show_loading_overlay() -> void:
	if loading_overlay != null:
		loading_overlay.visible = true
	menu_card.visible = false
	options_card.visible = false
	if menu_bgm != null:
		menu_bgm.stop()


func _ensure_audio_buses() -> void:
	var master_index: int = AudioServer.get_bus_index(BUS_MASTER)
	if master_index < 0:
		return

	_ensure_bus_exists(BUS_MUSIC, master_index)
	_ensure_bus_exists(BUS_SFX, master_index)


func _ensure_bus_exists(bus_name: StringName, send_bus_index: int) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	var new_bus_index: int = AudioServer.get_bus_count()
	AudioServer.add_bus(new_bus_index)
	AudioServer.set_bus_name(new_bus_index, bus_name)
	var send_bus_name: StringName = AudioServer.get_bus_name(send_bus_index)
	AudioServer.set_bus_send(new_bus_index, send_bus_name)


func _setup_audio_controls() -> void:
	master_bus_index = AudioServer.get_bus_index(BUS_MASTER)
	if master_bus_index < 0:
		master_bus_index = 0

	music_bus_index = AudioServer.get_bus_index(BUS_MUSIC)
	if music_bus_index < 0:
		music_bus_index = master_bus_index

	sfx_bus_index = AudioServer.get_bus_index(BUS_SFX)
	if sfx_bus_index < 0:
		sfx_bus_index = master_bus_index

	music_slider.min_value = MIN_VOLUME_DB
	music_slider.max_value = MAX_VOLUME_DB
	music_slider.step = 0.5
	sfx_slider.min_value = MIN_VOLUME_DB
	sfx_slider.max_value = MAX_VOLUME_DB
	sfx_slider.step = 0.5

	var music_db: float = AudioServer.get_bus_volume_db(music_bus_index)
	var sfx_db: float = AudioServer.get_bus_volume_db(sfx_bus_index)
	_apply_music_volume_db(music_db, false)
	_apply_sfx_volume_db(sfx_db, false)
	_update_fullscreen_button_text()
	_update_vsync_button_text()


func _setup_bgm_loop() -> void:
	if menu_bgm == null:
		return
	menu_bgm.bus = BUS_MUSIC
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
	_apply_menu_parallax_offset()


func _apply_menu_parallax_offset() -> void:
	if background_parallax == null:
		return
	background_parallax.offset = MENU_PARALLAX_OFFSET


func _show_main_menu() -> void:
	menu_card.visible = true
	options_card.visible = false
	play_button.grab_focus()


func _show_options_menu() -> void:
	menu_card.visible = false
	options_card.visible = true
	_update_fullscreen_button_text()
	_update_vsync_button_text()
	back_button.grab_focus()


func _on_play_pressed() -> void:
	if is_starting_game:
		return
	is_starting_game = true
	_play_menu_click_sfx()
	_set_menu_interactable(false)
	_show_loading_overlay()
	await get_tree().create_timer(MENU_LOADING_DURATION).timeout
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	if is_starting_game:
		return
	_play_menu_click_sfx()
	_show_options_menu()


func _on_quit_pressed() -> void:
	if is_starting_game:
		return
	_play_menu_click_sfx()
	get_tree().quit()


func _on_back_pressed() -> void:
	if is_starting_game:
		return
	_play_menu_click_sfx()
	_show_main_menu()


func _on_music_down_pressed() -> void:
	_play_menu_click_sfx()
	_apply_music_volume_db(music_slider.value - VOLUME_STEP_DB)


func _on_music_up_pressed() -> void:
	_play_menu_click_sfx()
	_apply_music_volume_db(music_slider.value + VOLUME_STEP_DB)


func _on_music_slider_changed(value: float) -> void:
	_apply_music_volume_db(value)


func _on_sfx_down_pressed() -> void:
	_play_menu_click_sfx()
	_apply_sfx_volume_db(sfx_slider.value - VOLUME_STEP_DB)


func _on_sfx_up_pressed() -> void:
	_play_menu_click_sfx()
	_apply_sfx_volume_db(sfx_slider.value + VOLUME_STEP_DB)


func _on_sfx_slider_changed(value: float) -> void:
	_apply_sfx_volume_db(value)


func _apply_music_volume_db(volume_db: float, write_bus: bool = true) -> void:
	var clamped_db: float = clampf(volume_db, MIN_VOLUME_DB, MAX_VOLUME_DB)
	if write_bus and music_bus_index >= 0:
		AudioServer.set_bus_volume_db(music_bus_index, clamped_db)

	music_slider.set_value_no_signal(clamped_db)
	_update_bus_volume_label(music_value_label, "Musica", clamped_db)


func _apply_sfx_volume_db(volume_db: float, write_bus: bool = true) -> void:
	var clamped_db: float = clampf(volume_db, MIN_VOLUME_DB, MAX_VOLUME_DB)
	if write_bus and sfx_bus_index >= 0:
		AudioServer.set_bus_volume_db(sfx_bus_index, clamped_db)

	sfx_slider.set_value_no_signal(clamped_db)
	_update_bus_volume_label(sfx_value_label, "Efeitos", clamped_db)


func _update_bus_volume_label(target_label: Label, prefix: String, volume_db: float) -> void:
	if target_label == null:
		return
	var percent: int = int(round(clampf(db_to_linear(volume_db), 0.0, 1.0) * 100.0))
	target_label.text = "%s: %d%%" % [prefix, percent]


func _on_fullscreen_pressed() -> void:
	_play_menu_click_sfx()
	if _is_fullscreen_enabled():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_button_text()


func _on_vsync_pressed() -> void:
	_play_menu_click_sfx()
	if _is_vsync_enabled():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_update_vsync_button_text()


func _is_fullscreen_enabled() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _is_vsync_enabled() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED


func _update_fullscreen_button_text() -> void:
	if fullscreen_button == null:
		return
	fullscreen_button.text = "Ligado" if _is_fullscreen_enabled() else "Desligado"


func _update_vsync_button_text() -> void:
	if vsync_button == null:
		return
	vsync_button.text = "Ligado" if _is_vsync_enabled() else "Desligado"


func _on_bgm_finished() -> void:
	if menu_bgm != null:
		menu_bgm.play()


func _play_menu_click_sfx() -> void:
	if MENU_CLICK_SFX_STREAM == null:
		return
	var root_node: Node = get_tree().root
	if root_node == null:
		return
	var click_player: AudioStreamPlayer = AudioStreamPlayer.new()
	click_player.bus = BUS_SFX
	click_player.volume_db = MENU_CLICK_SFX_VOLUME_DB
	click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	click_player.stream = MENU_CLICK_SFX_STREAM
	root_node.add_child(click_player)
	click_player.finished.connect(Callable(click_player, "queue_free"))
	click_player.play()
