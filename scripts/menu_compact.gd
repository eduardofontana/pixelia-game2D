extends Node2D

const GAME_SCENE_PATH: String = "res://scenes/level01.tscn"
const LOADING_IMAGE_PATH: String = "res://background/loadingpixelia.png"
const LOADING_DURATION: float = 5.0
const MENU_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"
const CLICK_SFX_STREAM: AudioStream = preload("res://sounds/click_double_off.wav")
const CLICK_SFX_VOLUME_DB: float = -5.0
const LOADING_BAR_LEFT_RATIO: float = 0.287
const LOADING_BAR_TOP_RATIO: float = 0.864
const LOADING_BAR_WIDTH_RATIO: float = 0.427
const LOADING_BAR_HEIGHT_RATIO: float = 0.032

@onready var play_button: Button = $UILayer/Root/CenterContainer/MenuCardFrame/ButtonsRoot/ButtonsVBox/PlayButton
@onready var options_button: Button = $UILayer/Root/CenterContainer/MenuCardFrame/ButtonsRoot/ButtonsVBox/OptionsButton
@onready var quit_button: Button = $UILayer/Root/CenterContainer/MenuCardFrame/ButtonsRoot/ButtonsVBox/QuitButton

@onready var options_overlay: Control = $UILayer/Root/OptionsOverlay
@onready var options_title: Label = $UILayer/Root/OptionsOverlay/Panel/VBox/OptionsTitle
@onready var fullscreen_button: Button = $UILayer/Root/OptionsOverlay/Panel/VBox/FullscreenButton
@onready var vsync_button: Button = $UILayer/Root/OptionsOverlay/Panel/VBox/VsyncButton
@onready var back_button: Button = $UILayer/Root/OptionsOverlay/Panel/VBox/BackButton

var is_starting_game: bool = false
var loading_overlay: CanvasLayer = null
var loading_image: TextureRect = null
var loading_bar_bg: Panel = null
var loading_bar_fill: Panel = null


func _ready() -> void:
	_build_loading_overlay()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_menu_button_font()
	_bind_buttons()
	_update_options_texts()
	options_overlay.visible = false


func _bind_buttons() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	vsync_button.pressed.connect(_on_vsync_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _build_loading_overlay() -> void:
	loading_overlay = CanvasLayer.new()
	loading_overlay.layer = 100
	loading_overlay.visible = false
	add_child(loading_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 1.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_overlay.add_child(dim)

	loading_image = TextureRect.new()
	loading_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	loading_image.stretch_mode = TextureRect.STRETCH_SCALE
	loading_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_overlay.add_child(loading_image)

	loading_bar_bg = Panel.new()
	loading_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_overlay.add_child(loading_bar_bg)

	var bar_bg_style := StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0.15, 0.03, 0.01, 0.75)
	bar_bg_style.corner_radius_top_left = 8
	bar_bg_style.corner_radius_top_right = 8
	bar_bg_style.corner_radius_bottom_right = 8
	bar_bg_style.corner_radius_bottom_left = 8
	loading_bar_bg.add_theme_stylebox_override("panel", bar_bg_style)

	loading_bar_fill = Panel.new()
	loading_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_bar_bg.add_child(loading_bar_fill)

	var bar_fill_style := StyleBoxFlat.new()
	bar_fill_style.bg_color = Color(1.0, 0.37, 0.08, 0.9)
	bar_fill_style.corner_radius_top_left = 7
	bar_fill_style.corner_radius_top_right = 7
	bar_fill_style.corner_radius_bottom_right = 7
	bar_fill_style.corner_radius_bottom_left = 7
	loading_bar_fill.add_theme_stylebox_override("panel", bar_fill_style)

	if ResourceLoader.exists(LOADING_IMAGE_PATH):
		var loaded: Resource = load(LOADING_IMAGE_PATH)
		if loaded is Texture2D:
			loading_image.texture = loaded as Texture2D

	_layout_loading_bar()
	_update_loading_progress(0.0)


func _on_play_pressed() -> void:
	if is_starting_game:
		return

	_play_click_sfx()
	is_starting_game = true
	_set_buttons_enabled(false)
	options_overlay.visible = false
	loading_overlay.visible = true
	_update_loading_progress(0.0)

	var start_time_ms: int = Time.get_ticks_msec()
	while true:
		var elapsed_sec: float = maxf(0.0, float(Time.get_ticks_msec() - start_time_ms) / 1000.0)
		var progress: float = clampf(elapsed_sec / LOADING_DURATION, 0.0, 1.0)
		_update_loading_progress(progress)
		if progress >= 1.0:
			break
		await get_tree().process_frame

	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	if is_starting_game:
		return
	_play_click_sfx()
	options_overlay.visible = true


func _on_quit_pressed() -> void:
	if is_starting_game:
		return
	_play_click_sfx()
	get_tree().quit()


func _on_fullscreen_pressed() -> void:
	_play_click_sfx()
	if _is_fullscreen_enabled():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_options_texts()


func _on_vsync_pressed() -> void:
	_play_click_sfx()
	if _is_vsync_enabled():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_update_options_texts()


func _on_back_pressed() -> void:
	_play_click_sfx()
	options_overlay.visible = false


func _set_buttons_enabled(enabled: bool) -> void:
	play_button.disabled = not enabled
	options_button.disabled = not enabled
	quit_button.disabled = not enabled
	fullscreen_button.disabled = not enabled
	vsync_button.disabled = not enabled
	back_button.disabled = not enabled


func _is_fullscreen_enabled() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _is_vsync_enabled() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED


func _update_options_texts() -> void:
	fullscreen_button.text = "Tela cheia: Ligado" if _is_fullscreen_enabled() else "Tela cheia: Desligado"
	vsync_button.text = "VSync: Ligado" if _is_vsync_enabled() else "VSync: Desligado"


func _apply_menu_button_font() -> void:
	if not ResourceLoader.exists(MENU_FONT_PATH):
		return
	var loaded_font: Resource = load(MENU_FONT_PATH)
	if not (loaded_font is Font):
		return

	var menu_font: Font = loaded_font as Font
	var button_nodes: Array[Button] = [
		play_button,
		options_button,
		quit_button,
		fullscreen_button,
		vsync_button,
		back_button
	]

	for button_node in button_nodes:
		if button_node == null:
			continue
		button_node.add_theme_font_override("font", menu_font)

	if options_title != null:
		options_title.add_theme_font_override("font", menu_font)


func _on_viewport_size_changed() -> void:
	_layout_loading_bar()


func _layout_loading_bar() -> void:
	if loading_bar_bg == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var x: float = viewport_size.x * LOADING_BAR_LEFT_RATIO
	var y: float = viewport_size.y * LOADING_BAR_TOP_RATIO
	var width: float = viewport_size.x * LOADING_BAR_WIDTH_RATIO
	var height: float = viewport_size.y * LOADING_BAR_HEIGHT_RATIO
	loading_bar_bg.position = Vector2(x, y)
	loading_bar_bg.size = Vector2(width, height)

	if loading_bar_fill != null:
		loading_bar_fill.position = Vector2(2.0, 2.0)
		loading_bar_fill.size = Vector2(0.0, maxf(1.0, height - 4.0))


func _update_loading_progress(progress: float) -> void:
	if loading_bar_bg == null or loading_bar_fill == null:
		return
	var clamped: float = clampf(progress, 0.0, 1.0)
	var inner_width: float = maxf(0.0, loading_bar_bg.size.x - 4.0)
	loading_bar_fill.size.x = inner_width * clamped


func _play_click_sfx() -> void:
	if CLICK_SFX_STREAM == null:
		return
	var click_player := AudioStreamPlayer.new()
	click_player.stream = CLICK_SFX_STREAM
	click_player.volume_db = CLICK_SFX_VOLUME_DB
	add_child(click_player)
	click_player.finished.connect(Callable(click_player, "queue_free"))
	click_player.play()
