class_name SpinShootSkillData
extends SkillData
## El personaje gira disparando flechas en todas las direcciones (Fuck all).

@export var duration: float = 5.0
@export var turns_per_second: float = 2.0
@export var shots_per_second: float = 15.0
## Cuántas flechas salen en cada disparo, repartidas en círculo.
@export var arrows_per_shot: int = 3
@export var projectile_id: StringName = &""
@export var damage_mult: float = 0.6
## Multiplicador de la velocidad de movimiento mientras gira.
@export var move_speed_mult: float = 0.6
