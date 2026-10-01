class_name Iso
extends RefCounted
## Conversión entre el suelo "plano" y la pantalla isométrica.
##
## La lógica de combate y de IA mide distancias y ángulos en el suelo plano, como si no
## hubiera perspectiva. En pantalla, el eje vertical se ve aplastado a la mitad (tile 64×32).

const Y_SCALE := 0.5


## Un desplazamiento en pantalla, expresado en el suelo plano.
static func to_ground(screen_offset: Vector2) -> Vector2:
	return Vector2(screen_offset.x, screen_offset.y / Y_SCALE)


## Un desplazamiento en el suelo plano, expresado en pantalla.
static func to_screen(ground_offset: Vector2) -> Vector2:
	return Vector2(ground_offset.x, ground_offset.y * Y_SCALE)
