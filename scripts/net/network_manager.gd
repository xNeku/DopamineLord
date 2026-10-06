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
signal attack_received(peer_id: int, direction: Vector2)
## Un jugador ha dicho qué rama ha elegido (o la ha cambiado).
signal class_received(peer_id: int, class_id: StringName)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var is_online: bool = false
## Si es true, el jugador local lo controla un bot (para probar con varias instancias).
var bot_mode: bool = false
## Rama que ha elegido el jugador local (vacía hasta que elige) y la de cada jugador remoto.
var local_class: StringName = &""
var peer_classes: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void:
		# Quien llega nuevo no sabe qué rama tenemos: se la decimos.
		if local_class != &"":
			_receive_class.rpc_id(id, String(local_class))
		peer_joined.emit(id)
	)
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
	local_class = &""
	peer_classes.clear()


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


## El jugador local elige su rama. Se la dice a los que ya están conectados; los que lleguen
## después la reciben al conectarse.
func choose_class(class_id: StringName) -> void:
	local_class = class_id
	if is_online and not multiplayer.get_peers().is_empty():
		_receive_class.rpc(String(class_id))


func send_state(position: Vector2, facing: Vector2, walking: float) -> void:
	if is_online and not multiplayer.get_peers().is_empty():
		_receive_state.rpc(position, facing, walking)


func send_jump(from: Vector2, to: Vector2) -> void:
	if is_online and not multiplayer.get_peers().is_empty():
		_receive_jump.rpc(from, to)


## Avisa a los demás de que este jugador ha atacado, para que vean el golpe. El daño no
## va por aquí: lo resuelve el host.
func send_attack(direction: Vector2) -> void:
	if is_online and not multiplayer.get_peers().is_empty():
		_receive_attack.rpc(direction)


@rpc("any_peer", "unreliable_ordered")
func _receive_state(position: Vector2, facing: Vector2, walking: float) -> void:
	state_received.emit(multiplayer.get_remote_sender_id(), position, facing, walking)


@rpc("any_peer", "reliable")
func _receive_jump(from: Vector2, to: Vector2) -> void:
	jump_received.emit(multiplayer.get_remote_sender_id(), from, to)


@rpc("any_peer", "reliable")
func _receive_attack(direction: Vector2) -> void:
	attack_received.emit(multiplayer.get_remote_sender_id(), direction)


@rpc("any_peer", "reliable")
func _receive_class(class_id: String) -> void:
	# Viene de la red: solo se aceptan ids de ramas que existen.
	var id := StringName(class_id)
	if not GameData.CLASS_IDS.has(id):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	peer_classes[peer_id] = id
	class_received.emit(peer_id, id)
