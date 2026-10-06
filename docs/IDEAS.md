# Ideas para más adelante

Lista de "más adelante". Las ideas nuevas van aquí, no al código, hasta que el tramo actual esté jugable.

- Rendimiento (siguientes pasos, tras medir en la tablet): IA de mobs a menor frecuencia cuando están lejos de todos los jugadores; objetivo (jugador más cercano) cacheado por mob; reutilizar los arrays de la rejilla; dibujar los drops y los textos flotantes en bloque; rejilla espacial también para las paredes.
- Mundo generado: cada chunk registra sus obstáculos en el `MobManager` (`add_obstacle_circle`/`add_obstacle_rect`) y su altura de ordenación en el `MobRenderer` (`sort_anchors`); con muchos árboles habrá que ordenar por chunk, no con una banda por obstáculo.
- Decidir si los mobs deben bloquear al jugador (ahora lo atraviesa y ellos se apartan).
