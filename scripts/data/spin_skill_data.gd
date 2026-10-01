class_name SpinSkillData
extends SkillData
## El personaje gira golpeando todo lo que hay a su alrededor (Spin to Win).

@export var duration: float = 2.5
## Radio del área, en el suelo plano.
@export var radius: float = 48.0
## Cada cuántos segundos golpea a todo lo que hay dentro.
@export var tick_interval: float = 0.25
@export var damage: int = 6
## Vueltas por segundo (solo visual).
@export var turns_per_second: float = 3.0
## Multiplicador de la velocidad de movimiento mientras gira.
@export var move_speed_mult: float = 1.0
