class_name LootManager
extends Node
## Lo que cae al suelo y el dinero de cada jugador.
##
## Manda el host: decide qué cae, y quién se lo queda (el primero que llega). Los drops del
## suelo son compartidos, como pidió el diseño. Los clientes reciben eventos.

const DROP_SCENE_SCRIPT := preload("res://scripts/world/drop.gd")

@export var pickup_radius: float = 16.0
@export var drop_lifetime: float = 60.0
@export var max_drops: int = 100
## Porcentaje del dinero que se pierde al morir. PROVISIONAL: el diseño solo dice "un
## porcentaje", sin decidir cuánto.
@export_range(0, 100) var death_money_loss_percent: int = 10

## Todos los jugadores de la partida. Lo rellena el mundo.
var players: Array[Player] = []

var _drops: Dictionary = {}
var _next_id: int = 1


func _ready() -> void:
	if not multiplayer.is_server():
		_request_sync.rpc_id(1)


func drop_count() -> int:
	return _drops.size()


## Un mob ha muerto (solo lo llama el host, escuchando al MobManager).
func on_mob_killed(kind: StringName, position: Vector2, _killer_peer: int) -> void:
	var data := GameData.mob(kind)
	if data.drop_money_max <= 0 or _drops.size() >= max_drops:
		return
	var amount := randi_range(data.drop_money_min, data.drop_money_max)
	var spot := position + Vector2(randf_range(-8, 8), randf_range(-4, 4))
	var id := _next_id
	_next_id += 1
	_spawn_drop.rpc(id, &"money", amount, spot)


## Un jugador ha muerto (solo lo llama el host). Pierde un porcentaje del dinero.
func on_player_died(peer_id: int) -> void:
	var player := _player_by_peer(peer_id)
	if player == null:
		return
	var lost := int(player.money * death_money_loss_percent / 100.0)
	if lost > 0:
		_set_money.rpc(peer_id, player.money - lost, -lost)


func _physics_process(delta: float) -> void:
	PerfProbe.begin(&"loot")
	_physics_tick(delta)
	PerfProbe.end(&"loot")


func _physics_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for drop: Drop in _drops.values().duplicate():
		drop.age += delta
		if drop.age >= drop_lifetime:
			_remove_drop.rpc(drop.drop_id)
			continue
		for player in players:
			if player.is_dead:
				continue
			if Iso.to_ground(player.position - drop.position).length() <= pickup_radius:
				_collect_drop.rpc(drop.drop_id, player.peer_id, player.money + drop.amount)
				break


func _player_by_peer(peer_id: int) -> Player:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null


func _create_drop(id: int, kind: StringName, amount: int, spot: Vector2) -> void:
	if _drops.has(id):
		return
	var drop := DROP_SCENE_SCRIPT.new() as Drop
	drop.drop_id = id
	drop.kind = kind
	drop.amount = amount
	drop.position = spot
	add_child(drop)
	_drops[id] = drop


# --- Mensajes: del host a todos --------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _spawn_drop(id: int, kind: StringName, amount: int, spot: Vector2) -> void:
	_create_drop(id, kind, amount, spot)


@rpc("authority", "call_local", "reliable")
func _remove_drop(id: int) -> void:
	var drop: Drop = _drops.get(id)
	if drop != null:
		_drops.erase(id)
		drop.queue_free()


## El drop `id` se lo queda `peer_id`, y su dinero pasa a valer `total`.
@rpc("authority", "call_local", "reliable")
func _collect_drop(id: int, peer_id: int, total: int) -> void:
	var drop: Drop = _drops.get(id)
	if drop == null:
		return
	var player := _player_by_peer(peer_id)
	if player != null:
		FloatingText.spawn(self, player.position + Vector2(0, -60), "+%d" % drop.amount, Color(1.0, 0.82, 0.2))
		player.set_money(total)
	_drops.erase(id)
	drop.queue_free()


@rpc("authority", "call_local", "reliable")
func _set_money(peer_id: int, total: int, change: int) -> void:
	var player := _player_by_peer(peer_id)
	if player == null:
		return
	player.set_money(total)
	if change != 0:
		FloatingText.spawn(self, player.position + Vector2(0, -60), "%d" % change, Color(1.0, 0.82, 0.2))


# --- Mensajes: de un cliente al host ---------------------------------------------------

@rpc("any_peer", "reliable")
func _request_sync() -> void:
	if not multiplayer.is_server():
		return
	var ids := PackedInt32Array()
	var kinds := PackedStringArray()
	var amounts := PackedInt32Array()
	var positions := PackedVector2Array()
	for drop: Drop in _drops.values():
		ids.append(drop.drop_id)
		kinds.append(String(drop.kind))
		amounts.append(drop.amount)
		positions.append(drop.position)
	var peer_ids := PackedInt32Array()
	var moneys := PackedInt32Array()
	for player in players:
		peer_ids.append(player.peer_id)
		moneys.append(player.money)
	_sync.rpc_id(multiplayer.get_remote_sender_id(), ids, kinds, amounts, positions, peer_ids, moneys)


@rpc("authority", "reliable")
func _sync(ids: PackedInt32Array, kinds: PackedStringArray, amounts: PackedInt32Array, positions: PackedVector2Array, peer_ids: PackedInt32Array, moneys: PackedInt32Array) -> void:
	for i in ids.size():
		_create_drop(ids[i], StringName(kinds[i]), amounts[i], positions[i])
	for i in peer_ids.size():
		var player := _player_by_peer(peer_ids[i])
		if player != null:
			player.set_money(moneys[i])
