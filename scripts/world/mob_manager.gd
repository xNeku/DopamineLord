class_name MobManager
extends Node
## Mobs y combate de la partida.
##
## Manda el host: él hace aparecer a los mobs, los mueve, resuelve los golpes y el daño. Los
## clientes reciben eventos (aparece, golpeado, muerto) y una foto de las posiciones unas
## 10 veces por segundo, que suavizan. Offline, el jugador es su propio host y todo funciona
## igual.

const MOB_SCENE := preload("res://scenes/mob.tscn")

## Solo en el host: un mob ha muerto, con su tipo, su posición y quién lo mató.
signal mob_killed(kind: StringName, position: Vector2, killer_peer: int)
## Solo en el host: un jugador ha muerto.
signal player_died(peer_id: int)

@export var mob_to_spawn: StringName = &"blob"
@export var max_mobs: int = 8
@export var spawn_interval: float = 2.0
## Distancia (en el suelo plano) a la que aparecen respecto a un jugador.
@export var spawn_distance_min: float = 160.0
@export var spawn_distance_max: float = 240.0
@export var snapshot_interval: float = 0.1
@export var respawn_seconds: float = 3.0

## Todos los jugadores de la partida. Lo rellena el mundo.
var players: Array[Player] = []
var spawn_point: Vector2 = Vector2.ZERO
## Contadores para las pruebas con bots.
var stats: Dictionary = {"hits": 0, "kills": 0, "damage_taken": 0}

var _mobs: Dictionary = {}
var _next_id: int = 1
var _spawn_timer: float = 0.0
var _snapshot_timer: float = 0.0
var _probe := CircleShape2D.new()


func _ready() -> void:
	_probe.radius = 9.0
	if not multiplayer.is_server():
		_request_sync.rpc_id(1)


func mob_count() -> int:
	return _mobs.size()


## El jugador local ha atacado. Si somos el host se resuelve aquí; si no, se lo pedimos.
func request_attack(position: Vector2, direction: Vector2) -> void:
	if multiplayer.is_server():
		_resolve_attack(multiplayer.get_unique_id(), position, direction)
	else:
		_attack_request.rpc_id(1, position, direction)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		if _mobs.size() < max_mobs:
			_try_spawn()
	for mob: Mob in _mobs.values():
		_think(mob, delta)
	_snapshot_timer += delta
	if _snapshot_timer >= snapshot_interval:
		_snapshot_timer = 0.0
		_send_snapshot()


# --- Lógica del host -------------------------------------------------------------------

func _try_spawn() -> void:
	var alive: Array[Player] = []
	for player in players:
		if not player.is_dead:
			alive.append(player)
	if alive.is_empty():
		return
	var anchor: Player = alive.pick_random()
	var ground := Vector2.from_angle(randf() * TAU) * randf_range(spawn_distance_min, spawn_distance_max)
	var spot := anchor.position + Iso.to_screen(ground)
	if _blocked(spot):
		return
	var id := _next_id
	_next_id += 1
	_spawn_mob.rpc(id, mob_to_spawn, spot)


func _blocked(spot: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _probe
	query.transform = Transform2D(0.0, spot)
	query.collision_mask = 3
	return not get_viewport().world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _think(mob: Mob, delta: float) -> void:
	var target := _nearest_player(mob.position)
	if target == null:
		mob.velocity = Vector2.ZERO
		mob.windup = false
		return
	var to_target := Iso.to_ground(target.position - mob.position)
	var distance := to_target.length()
	if mob.windup:
		mob.velocity = Vector2.ZERO
		mob.windup_left -= delta
		if mob.windup_left <= 0.0:
			mob.windup = false
			mob.attack_cooldown_left = mob.data.attack_cooldown
			# El golpe solo da si el jugador sigue cerca: se puede esquivar o saltar fuera.
			if distance <= mob.data.attack_range * 1.5:
				_damage_player(target, mob.data.damage)
	elif distance > mob.data.attack_range:
		mob.velocity = Iso.to_screen(to_target / distance * mob.data.move_speed)
		mob.move_and_slide()
	else:
		mob.velocity = Vector2.ZERO
		mob.attack_cooldown_left -= delta
		if mob.attack_cooldown_left <= 0.0:
			mob.windup = true
			mob.windup_left = mob.data.attack_windup


func _nearest_player(from: Vector2) -> Player:
	var best: Player = null
	var best_distance := INF
	for player in players:
		if player.is_dead:
			continue
		var distance := from.distance_squared_to(player.position)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


func _send_snapshot() -> void:
	if multiplayer.get_peers().is_empty():
		return
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var healths := PackedInt32Array()
	var flags := PackedInt32Array()
	for mob: Mob in _mobs.values():
		ids.append(mob.mob_id)
		positions.append(mob.position)
		healths.append(mob.health)
		flags.append(1 if mob.windup else 0)
	_snapshot.rpc(ids, positions, healths, flags)


func _resolve_attack(peer_id: int, position: Vector2, direction: Vector2) -> void:
	var attacker := _player_by_peer(peer_id)
	if attacker == null or attacker.is_dead:
		return
	var aim := Iso.to_ground(direction) if direction.length_squared() > 0.0 else Vector2.RIGHT
	aim = aim.normalized()
	var half_arc := deg_to_rad(attacker.attack_arc_degrees) * 0.5
	for mob: Mob in _mobs.values().duplicate():
		var offset := Iso.to_ground(mob.position - position)
		var reach := attacker.attack_range + mob.data.radius
		if offset.length() > reach:
			continue
		if offset.length() > mob.data.radius and absf(aim.angle_to(offset)) > half_arc:
			continue
		_hit_mob(mob, attacker.attack_damage, peer_id)


func _hit_mob(mob: Mob, damage: int, attacker_peer: int) -> void:
	var remaining := mob.health - damage
	_mob_hit.rpc(mob.mob_id, damage, maxi(remaining, 0))
	if remaining <= 0:
		var kind := mob.data.id
		var spot := mob.position
		_mob_died.rpc(mob.mob_id)
		mob_killed.emit(kind, spot, attacker_peer)


func _damage_player(target: Player, amount: int) -> void:
	var remaining := maxi(target.health - amount, 0)
	stats["damage_taken"] += amount
	_player_health.rpc(target.peer_id, remaining, amount)
	if remaining <= 0:
		_player_died.rpc(target.peer_id)
		player_died.emit(target.peer_id)
		var peer_id := target.peer_id
		get_tree().create_timer(respawn_seconds).timeout.connect(
			func() -> void: _player_respawn.rpc(peer_id, spawn_point)
		)


func _player_by_peer(peer_id: int) -> Player:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null


# --- Mensajes: del host a todos --------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _spawn_mob(id: int, mob_id: StringName, spot: Vector2) -> void:
	_create_mob(id, mob_id, spot, -1)


@rpc("authority", "unreliable_ordered")
func _snapshot(ids: PackedInt32Array, positions: PackedVector2Array, healths: PackedInt32Array, flags: PackedInt32Array) -> void:
	for i in ids.size():
		var mob: Mob = _mobs.get(ids[i])
		if mob != null:
			mob.apply_snapshot(positions[i], healths[i], flags[i])


@rpc("authority", "call_local", "reliable")
func _mob_hit(id: int, damage: int, remaining: int) -> void:
	var mob: Mob = _mobs.get(id)
	if mob == null:
		return
	mob.set_health(remaining)
	mob.flash()
	FloatingText.spawn(self, mob.position + Vector2(0, -26), str(damage), Color(1.0, 0.9, 0.4))
	if multiplayer.is_server():
		stats["hits"] += 1


@rpc("authority", "call_local", "reliable")
func _mob_died(id: int) -> void:
	var mob: Mob = _mobs.get(id)
	if mob == null:
		return
	_mobs.erase(id)
	mob.queue_free()
	if multiplayer.is_server():
		stats["kills"] += 1


@rpc("authority", "call_local", "reliable")
func _player_health(peer_id: int, health: int, damage: int) -> void:
	var player := _player_by_peer(peer_id)
	if player == null:
		return
	player.set_health(health)
	if damage > 0:
		FloatingText.spawn(self, player.position + Vector2(0, -60), str(damage), Color(1.0, 0.35, 0.35))


@rpc("authority", "call_local", "reliable")
func _player_died(peer_id: int) -> void:
	var player := _player_by_peer(peer_id)
	if player != null:
		player.die()


@rpc("authority", "call_local", "reliable")
func _player_respawn(peer_id: int, spot: Vector2) -> void:
	var player := _player_by_peer(peer_id)
	if player != null:
		player.respawn(spot)


# --- Mensajes: de un cliente al host ---------------------------------------------------

@rpc("any_peer", "reliable")
func _attack_request(position: Vector2, direction: Vector2) -> void:
	if multiplayer.is_server():
		_resolve_attack(multiplayer.get_remote_sender_id(), position, direction)


## Un cliente acaba de entrar al mundo y pide lo que ya existe.
@rpc("any_peer", "reliable")
func _request_sync() -> void:
	if not multiplayer.is_server():
		return
	var ids := PackedInt32Array()
	var kinds := PackedStringArray()
	var positions := PackedVector2Array()
	var healths := PackedInt32Array()
	for mob: Mob in _mobs.values():
		ids.append(mob.mob_id)
		kinds.append(String(mob.data.id))
		positions.append(mob.position)
		healths.append(mob.health)
	var peer_ids := PackedInt32Array()
	var player_healths := PackedInt32Array()
	for player in players:
		peer_ids.append(player.peer_id)
		player_healths.append(player.health)
	_sync.rpc_id(multiplayer.get_remote_sender_id(), ids, kinds, positions, healths, peer_ids, player_healths)


@rpc("authority", "reliable")
func _sync(ids: PackedInt32Array, kinds: PackedStringArray, positions: PackedVector2Array, healths: PackedInt32Array, peer_ids: PackedInt32Array, player_healths: PackedInt32Array) -> void:
	for i in ids.size():
		if not _mobs.has(ids[i]):
			_create_mob(ids[i], StringName(kinds[i]), positions[i], healths[i])
	for i in peer_ids.size():
		var player := _player_by_peer(peer_ids[i])
		if player != null:
			player.set_health(player_healths[i])


func _create_mob(id: int, kind: StringName, spot: Vector2, health: int) -> void:
	if _mobs.has(id):
		return
	var mob := MOB_SCENE.instantiate() as Mob
	mob.position = spot
	mob.setup(id, GameData.mob(kind), not multiplayer.is_server())
	if health >= 0:
		mob.health = health
	add_child(mob)
	_mobs[id] = mob
