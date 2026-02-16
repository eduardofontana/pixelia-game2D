extends CharacterBody2D
class_name EnemyBase

const DEFAULT_HEALTH_BAR_WIDTH: float = 28.0
const DEFAULT_HEALTH_PERCENT_FONT_SIZE: int = 10
const DEFAULT_HEALTH_PERCENT_OUTLINE_SIZE: int = 2
const DEFAULT_VAMPIRE_FONT_PATH: String = "res://fonts/Pixelia2D.ttf"

@export var player_path: NodePath
@export var health_bar_visible_time: float = 3.2

@onready var health_bar: Node2D = get_node_or_null("HealthBar")
@onready var health_fill: Control = get_node_or_null("HealthBar/Bg/Fill")
@onready var health_percent_label: Label = get_node_or_null("HealthBar/PercentLabel")

var player_ref: CharacterBody2D = null
var current_hp: int = 1
var is_dying: bool = false
var health_bar_timer: float = 0.0
var health_fill_style: StyleBoxFlat = null
var hurt_sfx_player: AudioStreamPlayer = null


func _get_health_bar_width() -> float:
	return DEFAULT_HEALTH_BAR_WIDTH


func _get_health_percent_font_size() -> int:
	return DEFAULT_HEALTH_PERCENT_FONT_SIZE


func _get_health_percent_outline_size() -> int:
	return DEFAULT_HEALTH_PERCENT_OUTLINE_SIZE


func _get_vampire_font_path() -> String:
	return DEFAULT_VAMPIRE_FONT_PATH


func _get_hurt_sfx_path() -> String:
	return ""


func _get_hurt_sfx_volume_db() -> float:
	return -6.0


func _get_max_hp_value() -> int:
	return 1


func _bind_player() -> void:
	if not player_path.is_empty():
		player_ref = get_node_or_null(player_path) as CharacterBody2D
	else:
		var parent_node: Node = get_parent()
		if parent_node != null:
			player_ref = parent_node.get_node_or_null("Player") as CharacterBody2D

	if player_ref == null:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0] as CharacterBody2D

	if player_ref == null:
		call_deferred("_retry_bind_player")


func _retry_bind_player() -> void:
	if player_ref != null:
		return

	var parent_node: Node = get_parent()
	if parent_node != null:
		player_ref = parent_node.get_node_or_null("Player") as CharacterBody2D
	if player_ref == null:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0] as CharacterBody2D


func _is_player_target(node: Node) -> bool:
	if node == null:
		return false
	if player_ref != null and node == player_ref:
		return true
	return node.is_in_group("player")


func _setup_health_fill_style() -> void:
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

	var font_path: String = _get_vampire_font_path()
	if ResourceLoader.exists(font_path):
		var loaded_font: Resource = load(font_path)
		if loaded_font is Font:
			health_percent_label.add_theme_font_override("font", loaded_font as Font)

	health_percent_label.add_theme_font_size_override("font_size", _get_health_percent_font_size())
	health_percent_label.add_theme_constant_override("outline_size", _get_health_percent_outline_size())
	health_percent_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 0.98))
	health_percent_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))


func _update_health_bar() -> void:
	if health_fill == null:
		return

	var max_hp_value: int = _get_max_hp_value()
	var ratio: float = 0.0
	if max_hp_value > 0:
		ratio = clampf(float(current_hp) / float(max_hp_value), 0.0, 1.0)

	health_fill.size.x = _get_health_bar_width() * ratio
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


func _show_health_bar() -> void:
	health_bar_timer = health_bar_visible_time
	if health_bar != null:
		health_bar.visible = true


func _update_health_bar_timer(delta: float = -1.0) -> void:
	if health_bar == null or not health_bar.visible:
		return
	if delta >= 0.0:
		health_bar_timer = maxf(0.0, health_bar_timer - delta)
	if health_bar_timer <= 0.0:
		health_bar.visible = false


func _setup_hurt_sfx() -> void:
	if hurt_sfx_player != null:
		return

	hurt_sfx_player = AudioStreamPlayer.new()
	hurt_sfx_player.name = "HurtSfx"
	hurt_sfx_player.bus = "SFX"
	hurt_sfx_player.volume_db = _get_hurt_sfx_volume_db()
	add_child(hurt_sfx_player)

	var sfx_path: String = _get_hurt_sfx_path()
	if ResourceLoader.exists(sfx_path):
		var loaded_stream: Resource = load(sfx_path)
		if loaded_stream is AudioStream:
			hurt_sfx_player.stream = loaded_stream


func _play_hurt_sfx() -> void:
	if hurt_sfx_player == null or hurt_sfx_player.stream == null:
		return
	hurt_sfx_player.stop()
	hurt_sfx_player.play()
