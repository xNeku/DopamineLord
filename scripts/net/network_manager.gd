extends Node
## Red: crear partida, unirse y mensajes de los jugadores. Es un autoload llamado "Net".
##
## Modelo (coop entre amigos, sin anti-trampas): cada cliente controla el movimiento y el
## salto de su propio personaje y manda su estado unas 20 veces por segundo. El salto va
## como evento, para que los demás vean el arco completo. Todo lo que sea del mundo (mobs,
## loot, recursos) lo decidirá el host cuando exista.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
## Solo en clientes: se ha conectado al host / ha fallado / se ha perdido el host.
signal connected
signal connection_failed
signal disconnected
signal state_received(peer_id: int, position: Vector2, facing: Vector2, walking: float)
signal jump_received(peer_id: int, from: Vector2, to: Vector2)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var is_online: bool = false
## Si es true, el jugador local lo controla un bot (para probar con varias instancias).
var bot_mode: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: connected.emit())
	multiplayer.connection_failed.connect(func() -> void: connection_failed.emit())
	multiplayer.server_disconnected.connect(func() -> void: disconnected.emit())


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	is_online = true
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	is_online = true
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_online = false


## Cuántos jugadores hay en la partida, contando al local.
func player_count() -> int:
	return multiplayer.get_peers().size() + 1


## Direcciones IPv4 de esta máquina, para decirle a los amigos a dónde unirse.
func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127."):
			continue
		result.append(address)
	return result


func send_state(position: Vector2, facing: Vector2, walking: float) -> void:
	if is_online and not multiplayer.get_peers().is_empty():
		_receive_state.rpc(position, facing, walking)


func send_jump(from: Vector2, to: Vector2) -> void:
	if is_online and not multiplayer.get_peers().is_empty():
		_receive_jump.rpc(from, to)


@rpc("any_peer", "unreliable_ordered")
func _receive_state(position: Vector2, facing: Vector2, walking: float) -> void:
	state_received.emit(multiplayer.get_remote_sender_id(), position, facing, walking)


@rpc("any_peer", "reliable")
func _receive_jump(from: Vector2, to: Vector2) -> void:
	jump_received.emit(multiplayer.get_remote_sender_id(), from, to)
