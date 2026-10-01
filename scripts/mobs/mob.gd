class_name Mob
extends CharacterBody2D
## Un mob. Solo guarda su estado y se dibuja. Quien decide qué hace (moverse, atacar,
## morir) es el MobManager del host. En los clientes es un "títere" que sigue lo que llega.

const SMOOTHING := 12.0

var mob_id: int = 0
var data: MobData
var health: int = 0
var is_puppet: bool = false
## Está avisando de un golpe (telegrafiado).
var windup: bool = false
var windup_left: float = 0.0
var attack_cooldown_left: float = 0.0
## Arrastre de una skill (en pantalla, px/s). Solo el host lo usa.
var pull_velocity: Vector2 = Vector2.ZERO

var _target_position: Vector2
var _flash: float = 0.0


## Llamar tras fijar la posición y antes de añadirlo al árbol.
func setup(id: int, mob_data: MobData, puppet: bool) -> void:
	mob_id = id
	data = mob_data
	is_puppet = puppet
	health = data.max_health
	name = "Mob%d" % id
	_target_position = position
	collision_layer = 2
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.radius
	shape.shape = circle
	add_child(shape)


func apply_snapshot(new_position: Vector2, new_health: int, flags: int) -> void:
	_target_position = new_position
	health = new_health
	windup = (flags & 1) != 0


func set_health(value: int) -> void:
	health = value
	queue_redraw()


func flash() -> void:
	_flash = 1.0


func _physics_process(delta: float) -> void:
	if is_puppet:
		position = position.lerp(_target_position, 1.0 - exp(-SMOOTHING * delta))


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
	if _flash > 0.0 or windup:
		queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var radius := data.radius * 1.4
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	draw_circle(Vector2.ZERO, data.radius * 1.5, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var color := data.color.lerp(Color.WHITE, _flash)
	if windup:
		color = color.lerp(Color(1.0, 0.9, 0.2), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03))
	draw_circle(Vector2(0, -radius), radius, color)
	var ratio := clampf(float(health) / data.max_health, 0.0, 1.0)
	var bar := Vector2(18, 3)
	var top := Vector2(-bar.x * 0.5, -radius * 2.0 - 8.0)
	draw_rect(Rect2(top, bar), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(bar.x * ratio, bar.y)), Color(0.8, 0.2, 0.2))
