class_name ViewRange
extends RefCounted
## "Lo que se ve en pantalla" para las reglas del juego: un rectángulo fijo alrededor del
## jugador, igual para todos, así el host no depende de la cámara de cada cliente.
## Mitad de la vista (640×360), en píxeles de pantalla.

const HALF := Vector2(320, 180)


## ¿Está `point` (en pantalla) dentro de lo que ve el jugador que está en `center`?
static func contains(center: Vector2, point: Vector2) -> bool:
	var d := point - center
	return absf(d.x) <= HALF.x and absf(d.y) <= HALF.y
