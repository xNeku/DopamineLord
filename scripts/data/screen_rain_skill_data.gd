class_name ScreenRainSkillData
extends SkillData
## Pasiva de Magia (Lluvia): cada cierto tiempo llueven bolas durante unos segundos. Cada gota
## daña a todos los enemigos que se ven en pantalla y los ralentiza. Caen tantas gotas por
## segundo como ataques por segundo tenga el jugador en ese momento.

## Segundos entre el final de una lluvia y el principio de la siguiente.
@export var interval: float = 5.0
@export var duration: float = 5.0
## Daño de cada gota = ataque del jugador × este valor (0.5 = la mitad).
@export var damage_mult: float = 0.5
## Multiplicador de velocidad de los enemigos alcanzados, y cuánto dura el efecto.
@export_range(0.05, 1.0) var slow_mult: float = 0.5
@export var slow_time: float = 1.5
## Bolas que se dibujan por gota (solo visual).
@export var visual_balls: int = 5
@export var color: Color = Color(0.5, 0.65, 1.0)


func is_passive() -> bool:
	return true
