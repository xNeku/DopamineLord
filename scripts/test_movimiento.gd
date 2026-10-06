extends Node2D
## Escena de prueba de movimiento y salto: una cuadrícula isométrica (tile 64×32), un jugador
## y unos obstáculos. La pared (gris) bloquea el salto; los árboles (verdes) y el "mob" (rojo)
## se saltan por encima, pero no se puede aterrizar encima. La cámara sigue al jugador local.
## Si hay una partida en red, aparecen también los jugadores de los demás.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MENU_SCENE := "res://scenes/menu_red.tscn"
const TILE_HALF := Vector2(32, 16)
const GRID_SIZE := 12
## Cada cuánto manda el jugador local su estado a los demás (20 veces por segundo).
const STATE_INTERVAL := 0.05

@onready var _camera: Camera2D = $Camera2D
@onready var _hud: Label = $Hud/Estado

## Todos los jugadores de la partida; el local es el primero (nunca uno global).
var players: Array[Player] = []

var _local: Player
var _mobs: MobManager
var _loot: LootManager
var _skills: SkillManager
var _projectiles: ProjectileManager
var _remote_by_peer: Dictionary = {}
var _state_timer: float = 0.0
var _debug_timer: float = 0.0


func _ready() -> void:
	_local = $Player
	if Net.local_class == &"":
		Net.choose_class(&"melee")  # al abrir esta escena sin pasar por el selector
	_local.setup(multiplayer.get_unique_id(), true, Net.local_class)
	_local.position = _spawn_point()
	_local.jumped.connect(Net.send_jump)
	_local.attacked.connect(_on_local_attacked)
	players.append(_local)
	_mobs = MobManager.new()
	_mobs.name = "MobManager"
	_mobs.players = players
	_mobs.spawn_point = _local.position
	add_child(_mobs)
	_loot = LootManager.new()
	_loot.name = "LootManager"
	_loot.players = players
	add_child(_loot)
	_projectiles = ProjectileManager.new()
	_projectiles.name = "ProjectileManager"
	_projectiles.players = players
	_projectiles.mobs = _mobs
	add_child(_projectiles)
	_mobs.projectiles = _projectiles
	_skills = SkillManager.new()
	_skills.name = "SkillManager"
	_skills.players = players
	_skills.mobs = _mobs
	_skills.projectiles = _projectiles
	add_child(_skills)
	_local.skill_requested.connect(_on_local_skill_requested)
	_mobs.mob_killed.connect(_loot.on_mob_killed)
	_mobs.player_died.connect(_loot.on_player_died)
	if Net.bot_mode:
		_local.get_node("PlayerInput").free()
		var bot := BotInput.new()
		_local.add_child(bot)

	for peer_id in multiplayer.get_peers():
		_add_remote(peer_id)
	Net.peer_joined.connect(_add_remote)
	Net.peer_left.connect(_remove_remote)
	Net.state_received.connect(_on_state_received)
	Net.jump_received.connect(_on_jump_received)
	Net.attack_received.connect(_on_attack_received)
	Net.class_received.connect(_on_class_received)
	Net.disconnected.connect(_back_to_menu)

	# Pared: capa 1 (mundo). Cuerpos: capa 2.
	_add_obstacle(Vector2(150, 0), Vector2(12, 70), 1, Color(0.55, 0.55, 0.6), false)
	_add_obstacle(Vector2(-80, 0), Vector2(16, 16), 2, Color(0.2, 0.55, 0.25), true)
	_add_obstacle(Vector2(-110, 12), Vector2(16, 16), 2, Color(0.2, 0.55, 0.25), true)
	_add_obstacle(Vector2(60, -50), Vector2(16, 16), 2, Color(0.2, 0.55, 0.25), true)
	_add_obstacle(Vector2(0, 60), Vector2(18, 18), 2, Color(0.75, 0.2, 0.2), true)


func _process(_delta: float) -> void:
	_camera.position = _local.position
	_hud.text = "%s  Vida: %d/%d  Oro: %d  %s\n%s\n%s" % [_local.class_data.display_name, _local.health, _local.max_health, _local.money, _jump_text(), _skills_text(), _network_text()]


func _physics_process(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= STATE_INTERVAL:
		_state_timer = 0.0
		var walking := 0.0 if _local.is_jumping else _local.move_order.length()
		Net.send_state(_local.position, _local.facing, walking)

	if Net.bot_mode:
		_debug_timer += delta
		if _debug_timer >= 2.0:
			_debug_timer = 0.0
			_print_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()


func _spawn_point() -> Vector2:
	var ids: Array = [multiplayer.get_unique_id()]
	ids.append_array(multiplayer.get_peers())
	ids.sort()
	return Vector2(ids.find(multiplayer.get_unique_id()) * 28.0, 0.0)


func _add_remote(peer_id: int) -> void:
	if _remote_by_peer.has(peer_id):
		return
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.setup(peer_id, false, Net.peer_classes.get(peer_id, &"melee"))
	_remote_by_peer[peer_id] = player
	players.append(player)


func _remove_remote(peer_id: int) -> void:
	var player: Player = _remote_by_peer.get(peer_id)
	if player == null:
		return
	_remote_by_peer.erase(peer_id)
	players.erase(player)
	player.queue_free()


func _on_state_received(peer_id: int, position: Vector2, facing: Vector2, walking: float) -> void:
	if _remote_by_peer.has(peer_id):
		_remote_by_peer[peer_id].apply_remote_state(position, facing, walking)


func _on_jump_received(peer_id: int, from: Vector2, to: Vector2) -> void:
	if _remote_by_peer.has(peer_id):
		_remote_by_peer[peer_id].start_remote_jump(from, to)


func _on_local_attacked(direction: Vector2) -> void:
	Net.send_attack(direction)
	_mobs.request_attack(_local.position, direction)


func _on_local_skill_requested(slot: int, direction: Vector2, target: Vector2) -> void:
	_skills.request_skill(slot, _local.position, direction, target)


func _on_class_received(peer_id: int, class_id: StringName) -> void:
	if _remote_by_peer.has(peer_id):
		_remote_by_peer[peer_id].apply_class(class_id)


func _on_attack_received(peer_id: int, direction: Vector2) -> void:
	if _remote_by_peer.has(peer_id):
		_remote_by_peer[peer_id].start_remote_attack(direction)


func _back_to_menu() -> void:
	Net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _jump_text() -> String:
	if _local.is_jumping:
		return "Salto: en el aire"
	if _local.jump_cooldown_left > 0.0:
		return "Salto: recarga %.1f s" % _local.jump_cooldown_left
	return "Salto: listo"


func _skills_text() -> String:
	var parts := PackedStringArray()
	for slot in _local.skills.size():
		if _local.skills[slot] == null:
			continue
		var left := _local.skill_cooldown_left[slot]
		var state := "listo" if left <= 0.0 else "%.1f" % left
		if _local.skills[slot].is_passive():
			state = "pasiva"
		parts.append("[%d] %s: %s" % [slot + 1, _local.skills[slot].display_name, state])
	return "  ".join(parts)


func _network_text() -> String:
	if not Net.is_online:
		return "Solo (Esc: menú)"
	if multiplayer.is_server():
		return "Host, %d jugadores. IP: %s (Esc: salir)" % [Net.player_count(), ", ".join(Net.local_addresses())]
	return "Conectado, %d jugadores (Esc: salir)" % Net.player_count()


func _print_debug() -> void:
	var line := "[red] yo=%d jugadores=%d vida=%d mobs=%d golpes=%d muertes=%d daño_recibido=%d oro=%d drops=%d local=%s" % [multiplayer.get_unique_id(), Net.player_count(), _local.health, _mobs.mob_count(), _mobs.stats["hits"], _mobs.stats["kills"], _mobs.stats["damage_taken"], _local.money, _loot.drop_count(), _local.position.round()]
	for peer_id in _remote_by_peer:
		var remote: Player = _remote_by_peer[peer_id]
		line += " | %d=%s%s %s" % [peer_id, remote.position.round(), " (salta)" if remote.is_jumping else "", remote.class_data.id]
	print(line)


func _draw() -> void:
	var color := Color(1, 1, 1, 0.12)
	for k in range(-GRID_SIZE, GRID_SIZE + 1):
		var along_u := k * Vector2(-TILE_HALF.x, TILE_HALF.y)
		draw_line(along_u + GRID_SIZE * -TILE_HALF, along_u + GRID_SIZE * TILE_HALF, color)
		var along_v := k * TILE_HALF
		draw_line(along_v + GRID_SIZE * Vector2(TILE_HALF.x, -TILE_HALF.y), along_v + GRID_SIZE * Vector2(-TILE_HALF.x, TILE_HALF.y), color)


## Obstáculo de prueba. `layer` es el número de capa (1 = mundo, 2 = cuerpos).
func _add_obstacle(pos: Vector2, size: Vector2, layer: int, color: Color, round_shape: bool) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1 << (layer - 1)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var polygon := Polygon2D.new()
	polygon.color = color
	if round_shape:
		var circle := CircleShape2D.new()
		circle.radius = size.x * 0.5
		shape.shape = circle
		var points := PackedVector2Array()
		for i in 16:
			points.append(Vector2.from_angle(TAU * i / 16.0) * circle.radius)
		polygon.polygon = points
	else:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
		var half := size * 0.5
		polygon.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	body.add_child(shape)
	body.add_child(polygon)
	add_child(body)
