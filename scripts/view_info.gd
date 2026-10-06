class_name ViewInfo
extends RefCounted
## Lo que se ve de verdad en pantalla, en coordenadas del mundo. Sirve para dibujar solo lo que
## cabe en la vista, sea cual sea el tamaño o la proporción de la ventana. (Las reglas del juego
## usan el rectángulo fijo de `ViewRange`; esto es solo para el dibujo.)


## El rectángulo del mundo que cubre la pantalla de `viewport`, ampliado `margin` píxeles.
static func world_rect(viewport: Viewport, margin: float) -> Rect2:
	var rect: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	return rect.grow(margin)


## Diagnóstico (F6): dibujo simple con círculos en vez de MultiMesh, para saber si lo que
## desaparece es cosa de la GPU o de la lógica.
static var simple_draw: bool = false
