# Métricas de partida

Cada vez que abres el juego se escribe `actual.log` (y la partida anterior pasa a `anterior.log`),
con una línea cada 2 segundos: FPS, tiempos de física y de cada parte, llamadas de dibujo, mobs,
proyectiles y contadores de cosas raras (mobs que aparecen a la vista, proyectiles que casi no se
ven, frames lentos). Los `.log` no se suben solos: para que Claude los lea, hacer

    git add metricas
    git commit -m "Métricas de mis partidas"
    git push

La primera línea del archivo dice el sistema y la tarjeta gráfica.
