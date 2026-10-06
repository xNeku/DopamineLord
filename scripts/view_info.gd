class_name ViewInfo
extends RefCounted
## Lo que se ve de verdad en pantalla, en coordenadas del mundo. Sirve para dibujar solo lo que
## cabe en la vista, sea cual sea el tamaño o la proporción de la ventana. (Las reglas del juego
## usan el rectángulo fijo de `ViewRange`; esto es solo para el dibujo.)


## El rectángulo del mundo que cubre la pantalla de `viewport`, ampliado `margin` píxeles.
static func world_rect(viewport: Viewport, margin: float) -> Rect2:
	var rect: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	return rect.grow(margin)


## Cómo se dibujan mobs y proyectiles (F6 va cambiando):
## 0 = MultiMesh (rápido, lo normal en Windows y Mac).
## 1 = círculos con `_draw` (más lento, pero seguro: en la GPU de la tablet el MultiMesh hace
##     desaparecer cosas).
## 2 = MultiMesh sin `visible_instance_count`: el hueco sobrante se rellena con instancias vacías.
## Por defecto, 1 en Android y 0 en el resto.
static var draw_mode: int = 1 if OS.has_feature("android") else 0
const DRAW_MODES := 3


static func simple_draw() -> bool:
	return draw_mode == 1
