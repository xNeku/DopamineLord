# DopamineLord: reglas para Claude

ARPG isométrico 2D en **Godot 4.7.2** (Diablo 2 + Terraria). Coop de hasta 4 jugadores y mando desde el primer día.

El diseño completo, con todas las decisiones, está en [docs/DISENO.md](docs/DISENO.md). Es la fuente de verdad. Cada punto lleva una marca: **[DECIDIDO]** lo decidió Neku, **[PROPUESTA]** lo sugirió Claude y no está confirmado, **[ABIERTO]** sin decidir. Si algo está [ABIERTO], pregunta; no decidas por él.

## Cómo trabajar con Neku

- Español, directo, sin relleno ni tono corporativo. Paso a paso, aprendiendo construyendo.
- Hace casi todo desde una tablet Android: editor de Godot para Android 4.7.2, con Termux y git. No asumas escritorio. Solo GDScript (sin C#), sin addons que requieran compilar, escenas en texto.
- Tareas pequeñas. Cada una termina en algo que corre. Un commit por tarea y una rama por fase (por ejemplo `fase-1-movimiento`). No mezcles tareas.
- Neku puede estar editando escenas (`.tscn`) en la tablet. Trabaja en una rama, y avisa de qué escenas has cambiado.
- Las ideas nuevas van a `docs/IDEAS.md`, no al código. Hasta que el tramo actual esté jugable, el diseño está congelado.
- Sé crítico: avisa de riesgos y de contradicciones con el diseño, no te limites a decir que sí.

## Reglas técnicas (obligatorias)

1. **Multijugador desde el día 1.** Una lista de jugadores, nunca un "jugador" global.
2. **Input solo por acciones del Input Map**, nunca por tecla o clic concreto. Teclado/ratón y mando desde el principio. Los menús se navegan con foco: sin hover ni arrastrar como única vía.
3. **El input son órdenes** ("saltar hacia aquí", "atacar") que ejecuta la lógica. En red, las órdenes viajan al host.
4. **Lógica separada de lo visual.** Posición, vida y cooldowns viven en un lado; sprites y efectos, en otro.
5. **Todo contenido por datos con ID** (ítems, mobs, skills, gemas, recetas) en `data/`. Nada de código por ítem.
6. **Mundo = semilla + estado aparte** (recursos talados, bosses muertos), que se guarda y se sincroniza.
7. **Red:** el host manda sobre el mundo (mobs, loot, recursos, bosses, daño). Cada cliente controla el movimiento y el salto de su propio personaje, sin predicción (coop entre amigos, sin anti-trampas). Se mandan eventos, no estado por frame, y cada cliente solo recibe lo cercano. Hasta 4 jugadores. Conexión en la alpha: red privada virtual (Tailscale o ZeroTier) con ENet.
8. **Rendimiento (siempre, en cada tarea):** el juego va a tener muchísimos bichos y proyectiles, con coop. Antes de implementar algo, piensa cuántas veces ocurrirá por segundo y cuántas entidades afectará. Proyectiles y efectos se simulan en bloque y se dibujan con un solo nodo, los mensajes de red se agrupan, y nunca se recorta una skill por rendimiento: se optimiza la implementación. Además: cientos de mobs, no miles. Colisiones simples, rejilla espacial, reutilizar objetos, limitar cadenas de explosiones y no crear un nodo por efecto.
9. **Elemento, munición y estilo como etiquetas en los datos**, para las sinergias del nivel 75.
10. **Programmer art primero:** formas generadas por código. El arte final entra cambiando rutas en los datos, sin tocar código. El arte lo hace Neku a mano; no generes arte con IA.
11. **Los valores de feel van como variables exportadas o en un Resource** (duración y altura del salto, cooldown, distancia máxima...) para que Neku los ajuste en el inspector.
12. **Pixel art:** filtro nearest, tile iso 64×32, personaje en piezas (cabeza, pecho, manos, pies) de 64×64 cada una, idle y andar por código.

## Estructura

```
art/        PNG de Neku (por piezas, 64×64)
data/       definiciones por datos (ítems, mobs, skills, gemas)
docs/       DISENO.md (diseño) e IDEAS.md (lista de "más adelante")
scenes/     escenas
scripts/    GDScript
```

## Validar antes de hacer commit

Godot 4.7.2 se puede descargar y ejecutar en modo headless desde un entorno Linux:

```
godot --headless --path . --import
godot --headless --path . --quit-after 60
```

Debe terminar sin errores de parseo ni de carga. Si hay pruebas, ejecútalas también.

Para medir rendimiento: F3 enseña el panel de métricas (ms por sección, llamadas de dibujo, nodos); F4/F5 suben los mobs y proyectiles a 100/200/400. En headless: `godot --headless --path . -- --host --bot --class=rango --perf --stress-mobs=400 --stress-proj=200` escribe una línea cada 2 s. Para comparar versiones: `godot --headless --path . --fixed-fps 60 --quit-after 1500 -- ...` y medir el tiempo total. Los tiempos de dibujo reales solo se miden con GPU real (el juego apunta a Windows y Mac; la tablet es entorno de pruebas).

## Fase actual

Prototipo de combate (dentro del tramo 1): ramas `fase-6-clases` (hecha) y `fase-7-rendimiento` (estudio de rendimiento de mobs y proyectiles, ver DISENO.md). Tres ramas jugables (Melee, Rango, Magia), cada una con ataque básico y 4 skills (ver "Kits base de las tres ramas" en `docs/DISENO.md`), elección de rama al entrar en la partida, stats base por rama y una hoja de balance. Las tres ramas (Melee, Rango y Magia) ya están hechas. La hoja de balance (CSV) queda para más adelante.
