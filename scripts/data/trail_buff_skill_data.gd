class_name TrailBuffSkillData
extends BuffSkillData
## Buff que además deja un rastro en el suelo que daña a los enemigos (Speed It).

## Cuánto dura el rastro en el suelo, desde que se deja.
@export var trail_lifetime: float = 3.0
## Cada cuántos píxeles de recorrido (suelo plano) se deja un trozo de rastro.
@export var trail_spacing: float = 16.0
@export var trail_radius: float = 14.0
## Daño por golpe = ataque del jugador × este valor.
@export var trail_damage_mult: float = 0.6
## Cada cuántos segundos golpea a quien lo pisa.
@export var trail_tick: float = 0.3
