class_name BounceSkillData
extends SkillData
## Pasiva de Rango: al matar con el ataque básico, la flecha rebota al enemigo más cercano
## y gana daño cada vez.

@export var max_bounces: int = 6
## Hasta dónde busca el siguiente enemigo, en el suelo plano.
@export var bounce_range: float = 160.0
## Daño extra por rebote, sobre el daño original (0.25 = +25% cada vez).
@export var damage_gain: float = 0.25


func is_passive() -> bool:
	return true
