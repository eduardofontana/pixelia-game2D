extends Area2D

signal collected(amount: int)

const COLLECT_SFX_PATH: String = "res://sounds/coin_3.wav"
const COLLECT_SFX_VOLUME_DB: float = -8.0

@export_range(0.0, 720.0, 1.0) var rotate_speed_deg_per_sec: float = 180.0
@export var coin_value: int = 1

var is_collected: bool = false


func _ready() -> void:
	add_to_group("collectible_coin")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if is_collected:
		return
	rotation_degrees = wrapf(rotation_degrees + (rotate_speed_deg_per_sec * delta), 0.0, 360.0)


func _on_body_entered(body: Node) -> void:
	if is_collected:
		return
	if not _is_player_body(body):
		return

	is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	visible = false
	_play_collect_sfx()
	collected.emit(maxi(coin_value, 0))
	call_deferred("queue_free")


func reset_coin_state() -> void:
	is_collected = false
	visible = true
	monitoring = true
	monitorable = true

	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)


func _is_player_body(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("player"):
		return true
	return body.name == "Player"


func _play_collect_sfx() -> void:
	if not ResourceLoader.exists(COLLECT_SFX_PATH):
		return

	var loaded_stream: Resource = load(COLLECT_SFX_PATH)
	if not (loaded_stream is AudioStream):
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	sfx_player.volume_db = COLLECT_SFX_VOLUME_DB
	sfx_player.stream = loaded_stream as AudioStream
	current_scene.add_child(sfx_player)
	sfx_player.finished.connect(Callable(sfx_player, "queue_free"))
	sfx_player.play()
