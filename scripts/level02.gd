extends Node2D

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const LEVEL_TRANSITION_LAYER: int = 260
const LEVEL_ENTRY_FADE_SECONDS: float = 0.4

@onready var bgm_player: AudioStreamPlayer = get_node_or_null("BGM") as AudioStreamPlayer

var entry_fade_overlay: CanvasLayer = null
var entry_fade_rect: ColorRect = null
var entry_fade_tween: Tween = null


func _ready() -> void:
	_ensure_audio_buses()
	_play_bgm()
	_play_entry_fade()


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


func _play_bgm() -> void:
	if bgm_player == null:
		return
	bgm_player.bus = BUS_MUSIC
	if not bgm_player.playing:
		bgm_player.play()


func _play_entry_fade() -> void:
	if entry_fade_overlay == null:
		entry_fade_overlay = CanvasLayer.new()
		entry_fade_overlay.name = "EntryFadeOverlay"
		entry_fade_overlay.layer = LEVEL_TRANSITION_LAYER
		entry_fade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(entry_fade_overlay)

	if entry_fade_rect == null:
		entry_fade_rect = ColorRect.new()
		entry_fade_rect.name = "Fade"
		entry_fade_rect.anchor_left = 0.0
		entry_fade_rect.anchor_top = 0.0
		entry_fade_rect.anchor_right = 1.0
		entry_fade_rect.anchor_bottom = 1.0
		entry_fade_rect.offset_left = 0.0
		entry_fade_rect.offset_top = 0.0
		entry_fade_rect.offset_right = 0.0
		entry_fade_rect.offset_bottom = 0.0
		entry_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry_fade_overlay.add_child(entry_fade_rect)

	if entry_fade_tween != null:
		entry_fade_tween.kill()
		entry_fade_tween = null

	entry_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	entry_fade_tween = create_tween()
	entry_fade_tween.set_trans(Tween.TRANS_SINE)
	entry_fade_tween.set_ease(Tween.EASE_OUT)
	entry_fade_tween.tween_property(entry_fade_rect, "color:a", 0.0, LEVEL_ENTRY_FADE_SECONDS)
	entry_fade_tween.tween_callback(Callable(self, "_finish_entry_fade"))


func _finish_entry_fade() -> void:
	if entry_fade_overlay != null:
		entry_fade_overlay.queue_free()
	entry_fade_overlay = null
	entry_fade_rect = null
	entry_fade_tween = null
