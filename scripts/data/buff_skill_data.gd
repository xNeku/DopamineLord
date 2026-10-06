class_name BuffSkillData
extends SkillData
## Mejora temporal del ataque básico (por ejemplo, Melee Boost).

@export var duration: float = 5.0
## Multiplicador de la velocidad de ataque (1.6 = un 60 % más rápido).
@export var attack_speed_mult: float = 1.6
## Multiplicador del alcance del golpe.
@export var attack_range_mult: float = 1.5
## Multiplicador de la velocidad de movimiento (y de la distancia del salto).
@export var move_speed_mult: float = 1.0
## Color con el que se tiñe el personaje mientras dura.
@export var tint: Color = Color(1.35, 1.05, 0.7)
