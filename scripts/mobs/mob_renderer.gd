class_name MobRenderer
extends Node2D
## Dibuja todos los mobs a la vez con MultiMesh: la sombra, el cuerpo, las marcas y la barra de
## vida salen de una sola malla y un solo shader, así que cuestan unas pocas llamadas de dibujo
## aunque haya cientos de mobs (un nodo por mob serían miles).
##
## - Solo se escriben los mobs que están en pantalla (más un margen).
## - La ordenación por Y con los jugadores y los obstáculos se resuelve con "bandas": los mobs
##   se reparten en una MultiMesh por cada tramo de Y entre dos jugadores/obstáculos, y cada
##   MultiMesh se coloca en el orden de Y justo entre ellos.
## - Más adelante, con arte de Neku, la malla pasa a ser un quad con textura (y el shader elige
##   el fotograma). El esquema es el mismo.

const MAX_KINDS := 16
const FLOATS_PER_INSTANCE := 12  # transform 2D (8) + datos propios (4)
const SHADER := preload("res://scripts/mobs/mob_renderer.gdshader")
const BODY_SEGMENTS := 20
## Cuánto más allá de la pantalla se siguen dibujando mobs (su cuerpo y su barra de vida llegan lejos).
const CULL_MARGIN := 80.0
## Lo que dura el destello con que se deshace un mob al morir.
const GHOST_TIME := 0.2

## Los mobs (id -> Mob) y los jugadores. Los pone el MobManager.
var mobs: Dictionary = {}
var players: Array[Player] = []
## Alturas (en pantalla) de obstáculos fijos que también cuentan para la ordenación.
var sort_anchors: PackedFloat32Array = PackedFloat32Array()

var _kind_index: Dictionary = {}
var _kind_colors := PackedVector4Array()
var _kind_radii := PackedFloat32Array()
var _kind_styles := PackedFloat32Array()
var _material: ShaderMaterial
var _mesh: ArrayMesh
var _bands: Array[MultiMeshInstance2D] = []
var _buffers: Array[PackedFloat32Array] = []
var _counts: PackedInt32Array = PackedInt32Array()
var _thresholds := PackedFloat32Array()
## Mobs que acaban de morir y se están deshaciendo (posición, tipo, tiempo).
var _ghosts: Array[Dictionary] = []
## Solo para el dibujo simple de diagnóstico (F6).
var _simple: Array[Vector3] = []
var _simple_hp := PackedFloat32Array()


func _init() -> void:
	_kind_colors.resize(MAX_KINDS)
	_kind_radii.resize(MAX_KINDS)
	_kind_styles.resize(MAX_KINDS)
	_mesh = _build_mesh()
	_material = ShaderMaterial.new()
	_material.shader = SHADER


## Número de tipo para un mob (colores, tamaño y marcas viajan en uniformes del shader).
func kind_of(data: MobData) -> int:
	if _kind_index.has(data.id):
		return _kind_index[data.id]
	var index: int = _kind_index.size()
	if index >= MAX_KINDS:
		push_warning("MobRenderer: más de %d tipos de mob, se reutiliza el último" % MAX_KINDS)
		return MAX_KINDS - 1
	_kind_index[data.id] = index
	_kind_colors[index] = Vector4(data.color.r, data.color.g, data.color.b, 1.0)
	_kind_radii[index] = data.radius
	_kind_styles[index] = float(data.ai)  # 0 cuerpo a cuerpo, 1 a distancia, 2 saltador
	_material.set_shader_parameter("kind_color", _kind_colors)
	_material.set_shader_parameter("kind_radius", _kind_radii)
	_material.set_shader_parameter("kind_style", _kind_styles)
	return index


## Un mob ha muerto: se deshace en vez de desaparecer de golpe.
func add_ghost(mob: Mob) -> void:
	if _ghosts.size() < 64:
		_ghosts.append({"position": mob.position, "kind": mob.kind, "age": 0.0, "lift": mob.lift})


func _process(delta: float) -> void:
	if players.is_empty():
		return
	PerfProbe.begin(&"mob_draw")
	_simple.clear()
	_simple_hp.clear()
	_update_bands(delta)
	PerfProbe.end(&"mob_draw")
	if ViewInfo.simple_draw or not _simple.is_empty():
		queue_redraw()


func _draw() -> void:
	for i in _simple.size():
		var spot := _simple[i]
		var color := Color(_kind_colors[int(spot.z)].x, _kind_colors[int(spot.z)].y, _kind_colors[int(spot.z)].z)
		var radius := _kind_radii[int(spot.z)]
		draw_circle(Vector2(spot.x, spot.y), radius * 1.4, color)
		draw_rect(Rect2(spot.x - radius, spot.y - radius * 3.2, radius * 2.0 * _simple_hp[i], 3.0), Color(0.3, 1.0, 0.3))


func _update_bands(delta: float) -> void:
	# Tramos de Y: uno por cada jugador y obstáculo, más el último.
	_thresholds.clear()
	for player in players:
		_thresholds.append(player.position.y)
	_thresholds.append_array(sort_anchors)
	_thresholds.sort()
	var band_count := _thresholds.size() + 1
	_ensure_bands(band_count)
	for band in band_count:
		_counts[band] = 0

	var view := ViewInfo.world_rect(get_viewport(), CULL_MARGIN)
	var low := view.position
	var high := view.end
	var thresholds := _thresholds
	var threshold_count := thresholds.size()
	# El dibujo va a más fotogramas que la física: el mob se adelanta lo que le toca entre dos
	# ticks (con su velocidad), para que se mueva suave a cualquier frecuencia de pantalla.
	var ahead := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
	for mob: Mob in mobs.values():
		var position := mob.position
		if not mob.is_puppet:
			position += mob.velocity * ahead
		if position.x < low.x or position.x > high.x or position.y < low.y or position.y > high.y:
			continue
		if ViewInfo.simple_draw:
			_simple.append(Vector3(position.x, position.y - 2.0 * mob.radius, mob.kind))
			_simple_hp.append(clampf(float(mob.health) / mob.data.max_health, 0.0, 1.0))
			continue
		var band := 0
		while band < threshold_count and position.y > thresholds[band]:
			band += 1
		var buffer := _buffers[band]
		var offset := _counts[band] * FLOATS_PER_INSTANCE
		if offset + FLOATS_PER_INSTANCE > buffer.size():
			buffer.resize(maxi(buffer.size() * 2, 64 * FLOATS_PER_INSTANCE))
			_buffers[band] = buffer
		var origin_y := position.y - _band_y(band, band_count)
		if mob.flash_amount > 0.0:
			mob.flash_amount = maxf(0.0, mob.flash_amount - delta * 6.0)
		var flash_and_windup := mob.flash_amount + (2.0 if mob.windup else 0.0)
		var health_ratio := clampf(float(mob.health) / mob.data.max_health, 0.0, 1.0)
		buffer[offset] = 1.0
		buffer[offset + 1] = 0.0
		buffer[offset + 2] = 0.0
		buffer[offset + 3] = position.x
		buffer[offset + 4] = 0.0
		buffer[offset + 5] = 1.0
		buffer[offset + 6] = 0.0
		buffer[offset + 7] = origin_y
		buffer[offset + 8] = float(mob.kind)
		buffer[offset + 9] = health_ratio
		buffer[offset + 10] = flash_and_windup
		buffer[offset + 11] = mob.lift
		_counts[band] += 1

	# Los mobs que acaban de morir: se encogen y se desvanecen con un destello.
	var i := _ghosts.size() - 1
	while i >= 0:
		var ghost := _ghosts[i]
		ghost["age"] += delta
		if ghost["age"] >= GHOST_TIME:
			_ghosts.remove_at(i)
		else:
			var ghost_position: Vector2 = ghost["position"]
			if ghost_position.x >= low.x and ghost_position.x <= high.x and ghost_position.y >= low.y and ghost_position.y <= high.y:
				var band := 0
				while band < threshold_count and ghost_position.y > thresholds[band]:
					band += 1
				_write_instance(band, band_count, ghost_position, ghost["kind"], -(ghost["age"] / GHOST_TIME + 0.001), 0.0, ghost["lift"])
		i -= 1

	for band in band_count:
		var node := _bands[band]
		node.position = Vector2(0.0, _band_y(band, band_count))
		var multimesh := node.multimesh
		var capacity := _buffers[band].size() / FLOATS_PER_INSTANCE
		if multimesh.instance_count != capacity:
			multimesh.instance_count = capacity
		multimesh.buffer = _buffers[band]
		multimesh.visible_instance_count = _counts[band]
		node.visible = _counts[band] > 0
	for band in range(band_count, _bands.size()):
		_bands[band].visible = false


func _write_instance(band: int, band_count: int, position: Vector2, kind: int, health_ratio: float, flash_and_windup: float, lift: float) -> void:
	var buffer := _buffers[band]
	var offset := _counts[band] * FLOATS_PER_INSTANCE
	if offset + FLOATS_PER_INSTANCE > buffer.size():
		buffer.resize(maxi(buffer.size() * 2, 64 * FLOATS_PER_INSTANCE))
	buffer[offset] = 1.0
	buffer[offset + 1] = 0.0
	buffer[offset + 2] = 0.0
	buffer[offset + 3] = position.x
	buffer[offset + 4] = 0.0
	buffer[offset + 5] = 1.0
	buffer[offset + 6] = 0.0
	buffer[offset + 7] = position.y - _band_y(band, band_count)
	buffer[offset + 8] = float(kind)
	buffer[offset + 9] = health_ratio
	buffer[offset + 10] = flash_and_windup
	buffer[offset + 11] = lift
	_counts[band] += 1


## Altura a la que se coloca el nodo de cada banda para que se ordene entre sus vecinos: justo
## encima del anterior jugador/obstáculo.
func _band_y(band: int, band_count: int) -> float:
	if band == 0:
		return _thresholds[0] - 0.01 if band_count > 1 else 0.0
	return _thresholds[band - 1] + 0.01


func _ensure_bands(count: int) -> void:
	while _bands.size() < count:
		var node := MultiMeshInstance2D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = false
		multimesh.use_custom_data = true
		multimesh.mesh = _mesh
		multimesh.instance_count = 0
		node.multimesh = multimesh
		node.material = _material
		add_child(node)
		_bands.append(node)
		_buffers.append(PackedFloat32Array())
	_counts.resize(maxi(count, _counts.size()))


## Una malla para todo el mob. Cada parte lleva su número en el canal rojo del color
## (0 sombra, 1 cuerpo, 2 anillo de a distancia, 3 anillo de saltador, 4 fondo de la barra de
## vida, 5 vida) y el shader la coloca y tiñe. Las coordenadas están en unidades del radio del mob.
func _build_mesh() -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Sombra: elipse achatada, de radio 1,5 veces el del mob.
	_add_disc(vertices, colors, uvs, indices, 0, Vector2.ZERO, 1.5, Vector2(1.0, Iso.Y_SCALE))
	# Cuerpo: disco de radio 1,4 con el centro a esa misma altura sobre el suelo.
	_add_disc(vertices, colors, uvs, indices, 1, Vector2(0.0, -1.4), 1.4, Vector2.ONE)
	# Marcas: anillos.
	_add_ring(vertices, colors, uvs, indices, 2, Vector2(0.0, -1.4), 0.7, 0.95)
	_add_ring(vertices, colors, uvs, indices, 3, Vector2(0.0, -1.4), 1.0, 1.4)
	# Barra de vida: fondo y relleno (el shader da el tamaño con las UV).
	_add_quad(vertices, colors, uvs, indices, 4)
	_add_quad(vertices, colors, uvs, indices, 5)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _part_color(part: int) -> Color:
	return Color(part / 8.0, 0.0, 0.0, 1.0)


func _add_disc(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array, part: int, center: Vector2, disc_radius: float, squash: Vector2) -> void:
	var first := vertices.size()
	vertices.append(center)
	colors.append(_part_color(part))
	uvs.append(Vector2.ZERO)
	for i in BODY_SEGMENTS:
		var angle := TAU * i / BODY_SEGMENTS
		vertices.append(center + Vector2(cos(angle) * disc_radius * squash.x, sin(angle) * disc_radius * squash.y))
		colors.append(_part_color(part))
		uvs.append(Vector2.ZERO)
	for i in BODY_SEGMENTS:
		indices.append(first)
		indices.append(first + 1 + i)
		indices.append(first + 1 + (i + 1) % BODY_SEGMENTS)


func _add_ring(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array, part: int, center: Vector2, inner: float, outer: float) -> void:
	var first := vertices.size()
	for i in BODY_SEGMENTS:
		var direction := Vector2.from_angle(TAU * i / BODY_SEGMENTS)
		vertices.append(center + direction * inner)
		vertices.append(center + direction * outer)
		for k in 2:
			colors.append(_part_color(part))
			uvs.append(Vector2.ZERO)
	for i in BODY_SEGMENTS:
		var a := first + i * 2
		var b := first + ((i + 1) % BODY_SEGMENTS) * 2
		indices.append_array([a, a + 1, b, b, a + 1, b + 1])


func _add_quad(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array, part: int) -> void:
	var first := vertices.size()
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		vertices.append(Vector2.ZERO)
		colors.append(_part_color(part))
		uvs.append(corner)
	indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
