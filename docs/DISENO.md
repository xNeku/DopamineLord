# Diseño: ARPG isométrico "Diablo 2 + Terraria" (Godot)

Documento de referencia con todo lo hablado con Neku el 30/09/2026. Úsalo como fuente de verdad del diseño.

Marcas:
- **[DECIDIDO]**: lo dijo o lo aceptó Neku.
- **[PROPUESTA]**: lo sugirió Claude y Neku no lo ha confirmado. Confirmar o descartar antes de darlo por hecho.
- **[ABIERTO]**: pendiente de decidir.

## Cómo trabajar con Neku

- Comunicación directa, sin relleno ni tono corporativo. Paso a paso, aprendiendo construyendo.
- Va a vibecodear mucho: el código lo escribe la IA; el arte y los diseños importantes los hace él.
- Proyecto a muy largo plazo, para ir picando cuando se aburre o se estanca en otros. Sin prisa.
- Claude debe buscar problemas y avisar de riesgos, no solo decir que sí.

## Concepto

- 2D isométrico en Godot. **[DECIDIDO]**
- De Diablo 2: vista, builds, skill tree, loot épico y grindeo, mapa más o menos.
- De Terraria: farmeo y grindeo, sistema de bosses y eventos, mundo generado, coop, progresión por hitos.
- Quiere una experiencia ARPG distinta y fresca, con personalidad propia. Meta: rejugar, probar builds, farmear y presumir de equipo. No es competitivo.
- Relación con TRALO (en pausa): de ahí vienen el salto estilo Conquer Online y las pocas skins con gemas/shaders. Diferencia: aquí hay un mundo generado por anillos, no una mazmorra de 100 plantas.

## Mundo y coop

- Como en Terraria: creas un mundo que es tuyo e invitas a tus colegas. Los personajes son independientes del mundo y el gear es libre entre mundos (da igual entrar chetado a la partida de otro). **[DECIDIDO]**
- Mundo amplio generado por semilla. Empiezas en el centro, una planicie tipo bosque segura. Alrededor, biomas en anillos, y la dificultad sube al alejarte del centro. **[DECIDIDO]**
- Sin bloqueo duro: se puede ir lejos, pero los mobs te destrozan si no vas preparado. Hay bosses que solo se invocan con ítems concretos, así que el crafting importa. **[DECIDIDO]**
- El suelo no se modifica. Menas, árboles y cultivos son nodos de recurso sobre el mapa. **[DECIDIDO]**
- Coop: el que crea el mundo es el host y los demás se conectan, sin servidor dedicado. **[PROPUESTA]** La forma de conectarse (NAT, relay, Steam) se decide más adelante.
- Coop de hasta 4 jugadores desde el principio: la alpha tiene que poder jugarse con 4 amigos sin problema, y el coop se tiene en cuenta desde la primera línea de código. **[DECIDIDO]**

## Ramas (no clases)

- Tres ramas: Magia, Rango y Melee. Empezar con pocas cosas y ampliar con updates y DLCs. **[DECIDIDO]**
- Las ramas no se mezclan: la variedad está dentro de cada rama y su especialización. Cada rama es un árbol con prerrequisitos (para llegar a X hay que subir antes Y y Z). **[DECIDIDO]** Los builds híbridos, si los hay, vienen de los materiales de armadura y las gemas.
- En el prototipo la rama (Neku dice "clase") se elige nada más entrar en la partida. **[DECIDIDO]** (06/10/2026). Si en el juego final se fija al crear el personaje sigue **[ABIERTO]**.

## Kits base de las tres ramas (prototipo)

Definidos por Neku el 06/10/2026. Son los kits de prueba del ecosistema inicial: cada rama tiene un ataque básico y 4 skills (slots 1 a 4). No son las especializaciones del 25/50/75, y los números se afinan jugando. **[DECIDIDO]** (el texto de cada skill es de Neku; las notas **[PROPUESTA]** son interpretaciones o avisos de Claude).

### Melee (hecho, ver `data/skills/`)
Básico: golpe en arco. **[DECIDIDO]**
1. **Melee Boost:** sube la velocidad de ataque y el alcance.
2. **Spin to Win:** gira golpeando todo lo del área (como la E de Garen).
3. **Lanzada:** lanza la espada como un boomerang; crece y llega más lejos cuanto más enemigos golpea.
4. **Guerra:** grito; caen espadas del cielo en un área circular y los enemigos son atraídos al centro.

### Rango
Básico: flecha hacia delante.
1. **Big Arrow:** flecha gigante que empuja (knockback) a los enemigos. Hace daño crítico cuando los saca de la pantalla, porque la flecha sigue avanzando hasta salir de tu rango de visión.
2. **Speed out:** sube la velocidad de movimiento y de ataque.
3. **Bounce (pasiva):** al matar a un enemigo con el básico, la flecha rebota al enemigo más cercano. Cada vez que ejecuta a un enemigo, la flecha gana un 25% de daño.
4. **Fuck all:** empieza a girar y dispara flechas en todas direcciones durante 5 segundos (muchas flechas).

### Magia
Básico: lanza una bola de magia que hace daño.
1. **Boost It:** sube mucho la velocidad de ataque. Los proyectiles atraviesan a los enemigos y hacen daño; cuantos más atraviesan, más daño hacen y más grande se hace el proyectil. Si atraviesa a 5 o más, explota en área.
2. **Speed It:** sube mucho la velocidad de movimiento y deja un rastro que daña a los enemigos (del mismo color que el proyectil). Mientras dura, el mago se tiñe de ese color.
3. **Big ball:** bola de magia que parece una gran bola de nieve rodando. Explota al impactar con un enemigo, hace daño en área y lanza 15 mini bolas alrededor.
4. **Lluvia (pasiva):** cada 5 segundos cae una lluvia de bolas del cielo que hace el 50% del daño de sus proyectiles a todos los enemigos en pantalla y los ralentiza. Dura 5 segundos y caen tantos proyectiles como velocidad de ataque tenga en ese momento.

### Avisos y huecos detectados al contrastarlo con el diseño y la técnica **[PROPUESTA]**
- "Pantalla" y "rango de visión" (Big Arrow, Lluvia) dependen de la cámara de cada cliente, y el host no la conoce. Hay que traducirlo a una distancia fija en el suelo (por ejemplo, el medio ancho de la vista). Ver pregunta abierta.
- Rendimiento: Fuck all, Boost It y Lluvia generan muchos proyectiles. Los de los mobs son un nodo por proyectil; con las skills hay que usar un gestor de proyectiles que simule y dibuje todos en bloque, con tope por jugador. Los proyectiles viajan como evento (origen y velocidad), no como estado.
- La velocidad de ataque pasa a ser una estadística real (la usa Lluvia). Sin tope, Boost It + Lluvia se dispara: poner un tope de proyectiles por lluvia.
- Cadenas de explosión: Boost It (explota a 5 o más) y Big ball (15 mini bolas) pueden encadenarse. Las mini bolas no explotan, y se limita la profundidad.
- Las pasivas (Bounce, Lluvia) no necesitan botón. Los slots se mantienen como los dio Neku (Rango: 1, 2 y 4 activas; Magia: 1, 2 y 3 activas) y la pasiva se dispara sola.
- El Melee se hace difícil de jugar porque no se cura. Ni el robo de vida ni la regeneración están en el diseño. Propuesta: pequeño robo de vida solo en Melee, revisar con la hoja de balance. **[ABIERTO]**
- Elemento, munición y estilo como etiquetas en los datos desde ya (regla del nivel 75): bola de magia, flecha, melee.
- Las skills de un kit se vuelven a repartir entre las ramas por las elecciones 25/50/75 más adelante. Los kits actuales son la base común.

## Niveles y especialización

- Nivel 1 a 100, subiendo con la XP de los mobs. **[DECIDIDO]**
- Dos capas de personalización dentro de la rama: **[DECIDIDO]**
  1. **Elecciones en niveles clave** que te especializan. Ejemplo de Neku con Rango: al nivel 25 eliges Arquero o Pistolero; al nivel 50, si eligió Arquero, elige entre arco largo, ballesta o arco rápido.
  2. **Personalización dentro de la rama** con un árbol de habilidades con prerrequisitos (para llegar a X hay que subir antes Y y Z), a gusto del jugador, para diferenciarse aún más.
- Se empieza con pocas ramas/especializaciones y se amplía con updates y DLCs. **[DECIDIDO]**
- Cortes de nivel: **[DECIDIDO]**
  - **Nivel 25:** primera especialización (ejemplo en Rango: Arquero o Pistolero).
  - **Nivel 50:** segunda especialización (ejemplo en Arquero: arco largo, ballesta o arco rápido).
  - **Nivel 75:** cambios menores que modifican aún más el camino del jugador (tipos de balas, elementos, estilos...). No son una especialización nueva, son modificadores.
  - **Nivel 100:** sin decidir. Idea de Neku: un "renacer" que acumula el camino anterior, por ejemplo Melee, Guerrero, Berserk, y al renacer en mago pasa a ser Melee, Guerrero, Berserk, Mago. Neku sabe que es complicado, así que se verá más adelante si hace falta para el endgame. Qué se conserva al renacer queda por definir. **[ABIERTO]**
- Habrá respec: las elecciones se pueden cambiar. **[DECIDIDO]** Coste por definir (lo razonable es barato, con oro o un NPC). **[ABIERTO]**
- El 75 como modificadores sobre skills existentes (etiquetas de munición, elemento o estilo definidas en datos) multiplica los builds sin multiplicar skills ni arte. **[PROPUESTA]**
- **Sinergias elementales (identidad del juego):** los modificadores del 75 se combinan con las gemas. Ejemplo de Neku: gemas de fuego + balas de fuego = x4 de fuego, o las balas explotan. Son "mega combos" y de eso va un poco el juego. **[DECIDIDO]**
- Mezclar elementos da reacciones nuevas. **[DECIDIDO]** De momento se aparca: no se diseña a fondo hasta tener construido el tramo hasta el nivel 25. Mientras tanto, el elemento va como etiqueta en los datos.
- Riesgos de las sinergias, a resolver al diseñarlas: **[PROPUESTA]**
  - Si el mismo elemento da x4, todo el mundo va mono-elemento. Hace falta que mezclar elementos dé reacciones o combos propios que merezcan la pena, y resistencias o debilidades elementales en mobs y biomas para obligar a variar.
  - Multiplicadores sin tope rompen el balance. Poner topes o rendimientos decrecientes, y preferir efectos (explosión, contagio) a multiplicar números sin fin.
  - Las explosiones en cadena con cientos de mobs en pantalla pesan. Limitar la profundidad de la cadena y no crear un nodo por explosión.
- Guardar las elecciones del personaje (25/50/75) como datos por personaje, para que el respec y el renacer futuro sean baratos de añadir. **[PROPUESTA]**
- **[ABIERTO]** Si la elección del 50 fija el tipo de arma (arco largo, ballesta...), los drops de armas de otros tipos no le sirven al jugador. Opciones: sesgar los drops hacia tu especialización, o aceptarlo como en Diablo 2 y dejar que sirvan para el coop.
- Volumen de contenido: con 3 ramas, 2 especializaciones por rama y 3 estilos por especialización salen 18 caminos al nivel 50, y más combinaciones con los modificadores del 75. Empezar por una sola rama (Melee, según el roadmap) y llevar el resto a updates. **[PROPUESTA]**
- Relación con el mundo: los anillos de dificultad deberían corresponderse más o menos con rangos de nivel, y la XP de mobs muy por debajo de tu nivel debería caer, para que no se farmee el primer anillo al nivel 80. **[PROPUESTA]**

## Dificultad

- Dificultad muy vertical: a ratos el jugador se siente chetadísimo, como si hubiera roto el juego, y al entrar en una zona nueva le revientan. Es parte de la gracia. **[DECIDIDO]**
- Para que se sienta como desafío y no como injusticia: ataques legibles y telegrafiados, aviso al entrar en una zona muy por encima de tu nivel, y que morir no cueste demasiado. **[PROPUESTA]**
- Muerte en el modo normal: solo se pierde dinero, a la manera de Terraria. Las gemas no se pierden. **[DECIDIDO]** Cuánto dinero (un porcentaje, por ejemplo) está por definir.
- Modo hardcore: pierdes todo. Solo se activa cuando el netcode sea fiable (una desconexión o un desfase no debe matar a un personaje) y con algún premio, como un título o un cosmético. **[DECIDIDO]**
- **[ABIERTO]** Qué es "todo" en hardcore (borrar el personaje o solo el inventario) y si el modo se elige al crear el personaje.
- Coop con niveles distintos: no habrá escalado. Se puede entrar con mucho menos nivel, pero te destrozan. La idea es jugar el coop junto casi desde el principio, no entrar tarde. Un colega que se queda atrás se pone al día subiendo en otro mundo. **[DECIDIDO]** Aviso al entrar en una zona muy por encima de tu nivel. **[PROPUESTA]**
- Fases del mundo: al llegar a cierto punto (después de algún boss) el mundo cambia y pasa a modo difícil, como el modo difícil de Terraria. El disparador es un hito del mundo (un boss invocado a propósito), nunca el nivel de un personaje, y normalmente coincide con subir al nivel 50. **[DECIDIDO]**
- El nivel se bloquea en el 49 hasta entrar en el modo difícil del mundo. **[DECIDIDO]** El nivel es del personaje y el modo difícil es del mundo, así que un personaje de nivel 49 solo pasa del 49 jugando en un mundo que ya esté en modo difícil.
- La XP se congela en el tope del 49: no se acumula. **[DECIDIDO]**
- Cómo será el modo difícil según Neku: cambia algún bioma o zona, los mobs en general son más duros, hay más élites, aparecen otras amenazas y los minerales se regeneran como unos nuevos. No es una segunda capa enorme de contenido como en Terraria. **[DECIDIDO]**
- Consecuencias de ese diseño, a tener en cuenta: **[PROPUESTA]**
  - El boss que abre el modo difícil se afina para personajes de nivel máximo 49 con su mejor equipo, lo que hace el balance más predecible. La bifurcación del 50 llega con el modo difícil.
  - Del 50 al 100 se juega en modo difícil. Claude avisó de que 50 niveles son mucho contenido; Neku lo ve asumible porque el modo difícil es más ligero que el de Terraria y se va tramo a tramo. Neku prefiere no tratar el 1-49 como un juego completo aparte: cree que, una vez pulido todo, será más fácil crear el 50-100. Se hace por tramos.
  - Riesgo a vigilar: que el 50-100 se sienta como las mismas zonas con números más grandes. Cada tramo de 25 niveles debería traer algo visible y nuevo (una zona que cambia, un tipo de élite, un boss, una amenaza).
  - Pulir antes ayuda sobre todo a los sistemas (combate, loot, gemas, red, herramientas de contenido); los mobs, zonas y bosses de cada tramo se siguen haciendo tramo a tramo.
  - En coop, quien tiene el mundo decide cuándo se invoca el boss: el ritmo del grupo lo marca el mundo, no el personaje más fuerte.

## Salto (mecánica estrella, viene del Conquer Online)

- Salta en la dirección indicada (ratón o stick), con arco y sombra en el suelo. Sirve para moverse, farmear y esquivar skill shots de bosses. **[DECIDIDO]**
- Distancia variable según la velocidad de movimiento. Cooldown, sin estamina. **[DECIDIDO]**
- Se puede atacar en el aire. **[DECIDIDO]**
- No es invulnerable: te pueden golpear en el aire. Pero evade colisiones (efecto fantasmal): atraviesa mobs, árboles y menas dentro de su alcance; las paredes lo bloquean. **[DECIDIDO]**
- Si el punto de aterrizaje no vale, se acorta y recalcula hasta el último sitio libre. **[DECIDIDO]**
- Salto comprometido (sin cambiar de rumbo en el aire) y un tope máximo de distancia para que el gear muy alto no cruce el mapa de un salto. **[PROPUESTA]**
- Técnica: la posición lógica se mueve por el suelo y solo el sprite sube y baja con una parábola; la sombra se queda en el suelo; squash & stretch al despegar y aterrizar. **[PROPUESTA]**

## Combate y loot

- Primera versión: personaje básico atacando mobs que van apareciendo y moviéndose, y recogiendo drops (dinero y míticos, que pueden caer incluso de mobs básicos). **[DECIDIDO]**
- El farmeo se centra en **gemas, armas y míticos**. **[DECIDIDO]**
- Las armaduras se craftean; el farmeo de armaduras fuera de las míticas es casi nulo. **[DECIDIDO]**
- Míticos: sprites únicos hechos a mano y se les pueden poner gemas. **[DECIDIDO]** **[ABIERTO]** ¿Ranuras normales o gemas fijas propias?
- Armas: las trabajará más que el resto; habrá armaduras más épicas (las míticas). **[DECIDIDO]**
- Pocas skins base de armas y armaduras. El aspecto va ligado a las gemas, runas y joyas que lleves: cada gema aplica un shader. **[DECIDIDO]**
- Las ranuras dependen de la rareza. El pecho lleva como máximo 3; el resto, 1 o 2. **[DECIDIDO]**
- Cada ranura corresponde a una zona marcada del sprite (por ejemplo, pecho: centro, hombros, borde); si hay varias gemas, una manda en el color principal y las otras añaden detalles. **[PROPUESTA]**
- Armaduras crafteadas: el material da afinidad de rama (ejemplo: pechera de cactus, atributo para mago), el bioma marca el tier y materiales distintos dan stats distintos. **[DECIDIDO]**
- Compensaciones por material, 2 o 3 familias de material por bioma, mezcla de materiales entre piezas permitida y tinte del material con el mismo shader de gemas. **[PROPUESTA]**
- Riesgo: las gemas son el motor del endgame y necesitan profundidad (tiers, mejoras, combinarlas). Además, entre míticos hacen falta recompensas pequeñas frecuentes (materiales, dinero, gemas bajas). **[ABIERTO]**
- Gear "roto" de un colega en un mundo nuevo: se acepta que el early game sea trivial para quien va chetado. Opcional: cosmético separado de stats. **[PROPUESTA]**

## Oficios

- Agricultura (árboles, cultivos), Cocina/Alquimia (pociones y bufos; no hay hambre), Minería (piedra, minerales), Pesca y Artesanía (herrería, joyería...). **[DECIDIDO]**
- Suben usándolos, estilo RuneScape. El nivel mejora la eficiencia (velocidad, varias piezas por golpe; por ejemplo, pesca nivel 5 más rápida y nivel 10 saca 3 peces de golpe) pero nunca bloquea: todo se puede conseguir, solo más lento. **[DECIDIDO]**
- Sirven para repartirse el trabajo en coop. Es secundario, con calma, y entra después de tener el mundo con nodos de recurso. **[DECIDIDO]**
- Cadena: materias primas (pesca, agricultura, minería) → transformación (cocina, alquimia, artesanía) → consumo en combate. **[PROPUESTA]**
- Unos 20 niveles por oficio, con perks por hitos. Empezar por Minería y Artesanía. **[PROPUESTA]**

## Arte

- Lo hace Neku (menos el código) y va explorando estilos hasta dar con la estética que le guste. Herramienta: ReSprite. Dispositivo: tablet Lenovo Legion Y700 Gen3 con teclado y ratón. **[DECIDIDO]**
- Solo dos vistas 3/4 (frontal y de espaldas) para players y mobs. Se voltean en horizontal para obtener las 4 diagonales isométricas. Excepciones posibles: bichos largos y bosses grandes. **[DECIDIDO]**
- Personaje humano: cabeza, torso, manos y pies flotantes, sin piernas ni brazos. Animación por código (balanceo de pies y manos, arcos al atacar, rebote), no frames dibujados. **[DECIDIDO]**
- Cada ítem visible son 2 sprites (frontal y espalda). Guantes y botas se dibujan una vez y se voltean. **[DECIDIDO]**
- Los mobs los dibuja él a mano. **[DECIDIDO]**
- Piezas visibles en el personaje: casco, torso, manos, pies y arma. Anillos, amuletos y demás solo dan stats. **[PROPUESTA]**
- Medidas iniciales, a validar con un sprite de prueba en Godot antes de dibujar mucho: tile 64×32; player 64×64; equipo 64×64 en la misma cuadrícula; mobs 32×32 o 48–64; mini-boss 96×96; boss 128+; iconos 32×32; árboles ~64×96; proyectiles 16–32. Pies siempre en el mismo punto del lienzo. Paleta limitada (16–32 colores). **[PROPUESTA]**
- Programmer art primero (formas y colores simples): no se pinta nada final hasta que la mecánica sea divertida con formas. Cada mob, ítem y personaje apunta a su arte desde datos, para cambiarlo luego sin tocar código. **[PROPUESTA]**
- Herramientas exploradas, sin decidir: Krita (dibujo), Nomad Sculpt (escultura en tablet), Blender (en Android hay una alpha reportada, sin verificar). Otros flujos comentados: recortes 2D con huesos, voxels, 3D prerenderizado a sprites. **[ABIERTO]**

## Controles

- Mando desde el minuto 1. **[DECIDIDO]**
- Input por acciones (nunca por tecla o clic concreto). Menús navegables con foco, sin depender de arrastrar ni de hover. Movimiento del stick girado al eje isométrico. Salto hacia donde apunta el stick. Loot pequeño por proximidad y el raro con botón. Iconos de botones según el dispositivo usado. **[PROPUESTA]**
- **[ABIERTO]** ¿Base ratón y teclado con el mando adaptado, o base twin-stick con el ratón adaptado? El apuntado de magia y rango con mando probablemente necesite asistencia.

## Reglas técnicas para la IA (para no rehacer al llegar el online)

- Pensar en varios jugadores desde el día 1: lista de jugadores, no un jugador global.
- El input son órdenes ("saltar hacia aquí", "atacar") y la lógica las ejecuta. En online, las órdenes viajan al host.
- Lógica (posición, vida, cooldowns) separada de lo visual.
- Ítems, mobs, skills, gemas y recetas definidos por datos con ID, nada de código por ítem.
- Mundo: semilla más estado aparte (recursos talados, bosses muertos) que se guarda y se sincroniza.
- El host manda sobre el mundo (mobs, loot, recursos, bosses, daño) y cada cliente controla el movimiento y el salto de su propio personaje, sin predicción ni rollback (coop entre amigos, sin anti-trampas), para que el salto se sienta inmediato aunque haya latencia. En red se mandan eventos ("se disparó esto aquí"), no estado por frame, y cada cliente solo recibe lo que tiene cerca.
- Rendimiento: apuntar a cientos de mobs, no miles. Colisiones simples, rejilla espacial, reutilizar objetos; MultiMesh si hace falta. Shaders de gemas en jugadores, no uno por mob.

Todas estas reglas son **[PROPUESTA]**.

## Roadmap

**[PROPUESTA]**, cada fase termina con algo jugable:

1. **Movimiento y salto** en programmer art. Hecha cuando saltar dé gusto.
2. **Combate:** ataque básico (también en el aire), mobs que aparecen, se mueven y golpean, vida y muerte.
3. **Loot:** drops de dinero y míticos (incluso de mobs básicos), recogida, inventario mínimo y equipar con stats. Es el corazón del juego: pulir el momento del drop mítico.
4. **Mundo:** semilla, centro seguro, anillos de biomas, nodos de recurso y guardado.
5. **Oficios** (después de la 4, con calma).
6. **Progresión:** crafting, bosses invocables con materiales y primera rama (Melee).
7. **Coop:** host y clientes, sincronizar mundo y mobs.
8. **Contenido y arte:** más biomas, resto de ramas, arte definitivo, updates y DLCs.

El mando y los menús con foco se tienen en cuenta en todas las fases.

### Método de trabajo

- Se construye por tramos de nivel: primero hasta el nivel 25, se ve cómo va y se sigue. **[DECIDIDO]**
- Para que ese tramo sirva de prueba real y no solo de tutorial, debería incluir lo mínimo del núcleo del juego: la bifurcación del 25, 2 o 3 gemas con efecto, un mítico y la pared de dificultad entre el anillo 1 y el 2. Lo que hace distinto al juego (builds, gemas, combos, dificultad vertical) vive sobre todo entre el 25 y el 75. **[PROPUESTA]**
- Fijar desde ya, en una hoja, la curva del 1 al 100 (XP, daño, vida, nivel de ítem), aunque no haya contenido. Cambiar la escala después obliga a rehacer todo el balance. **[PROPUESTA]**
- Congelar este diseño y llevar toda idea nueva a una lista de "más adelante" hasta que el tramo hasta el 25 esté jugable. El alcance (mundo generado, oficios, coop, gemas, tres ramas con tres cortes, mando y todo el arte a mano) es mayor que el de TRALO, que se pausó por viabilidad. **[PROPUESTA]**
- Hoja de ruta por tramos de nivel: 25, 50, 75, 100 y endgame, todo con calma. **[DECIDIDO]**
- Posible alpha con contenido hasta el nivel 30. **[DECIDIDO]**
- Como el coop es un pilar del juego, la alpha del 30 debería incluir coop (si no, se prueba otro juego) y conviene meter una prueba mínima de 2 jugadores (un host y un cliente moviéndose y saltando, aunque sea con formas simples) justo después del movimiento y el combate básico, no al final. Meter la red tarde es lo más caro de arreglar. **[PROPUESTA]**

## Tramo 1: hasta el nivel 25 y alpha hasta el 30

Objetivo: algo jugable por hasta 4 amigos, con el núcleo del juego a la vista (no solo un tutorial).

**Entra:** **[PROPUESTA]**
- Cambio decidido el 06/10/2026: las tres ramas (Melee, Rango, Magia) entran ya en el prototipo, con ataque básico y 4 skills cada una, para pasárselo bien matando bichos en un "pequeño ecosistema". **[DECIDIDO]** Riesgo: triplica el balance y el contenido del tramo. Se compensa con kits pequeños, todo por datos y una hoja de balance.
- Movimiento y salto con programmer art, con mando y teclado/ratón desde el principio y menús navegables con foco.
- Combate de una sola rama (Melee, la más fácil de probar): ataque básico, también en el aire; mobs que aparecen, se mueven y golpean.
- Bifurcación del nivel 25 de esa rama, con 2 opciones.
- Loot: dinero, armas, 2 o 3 gemas con efecto y un mítico que pueda caer incluso de mobs básicos. Inventario mínimo, equipar con stats y ranuras según rareza.
- Mundo mínimo por semilla: centro seguro tipo bosque, anillo 1 y anillo 2 con una pared de dificultad clara entre ambos, un par de nodos de recurso y guardado del mundo.
- Un boss invocable con materiales.
- Muerte: se pierde un porcentaje de dinero.
- Coop de hasta 4 jugadores, probado desde la primera prueba de red.

**No entra todavía:** oficios, modo difícil, hardcore, renacer, reacciones entre elementos, cosméticos y arte definitivo, y la conexión por Steam.

**Coop de 4, decisiones técnicas:** **[PROPUESTA]**
- Conexión en la alpha: una red virtual privada entre amigos (Tailscale o ZeroTier) con ENet directo, sin abrir puertos ni montar servidor. Steam (con relay) más adelante.
- Personajes en archivos locales de cada jugador y mundo guardado por el host.
- Presupuesto: unos 100 a 200 mobs activos cerca de los jugadores con 4 conectados. Medir pronto con 4 instancias a la vez (pueden ser bots en la misma máquina).
- Cuatro jugadores multiplican mobs, proyectiles y explosiones: limitar cadenas y no crear un nodo por efecto.

**Decisiones abiertas de coop:**
- Loot en coop: los bosses dan loot individual (cada jugador recibe el suyo). Los drops del suelo (oleadas, mobs normales) son compartidos: quedan en el suelo y se los queda quien los recoja. A Neku le gustan los piques, como en Terraria. **[DECIDIDO]**
- Los míticos que caen de mobs normales también son compartidos: se los lleva quien llega primero. **[DECIDIDO]** Riesgo asumido: favorece a quien tiene más velocidad o salto y a quien tiene menos ping (el host decide quién lo recoge primero). Si en las pruebas con amigos genera mal rollo, se revisa (por ejemplo, con míticos individuales, que ya sería fácil porque el loot individual de los bosses ya existe). Al resolver las recogidas en el host, compensar algo la latencia para que el ping no decida solo. **[PROPUESTA]**
- XP en coop: todos los jugadores cercanos (en un radio de unas dos pantallas) reciben la XP completa de cada muerte, sin repartirla, la mate quien la mate. **[DECIDIDO]** Es el modelo de Path of Exile y Diablo 4; Diablo 2 la repartía y penalizaba las diferencias de nivel. La XP de mobs muy por debajo de tu nivel sigue cayendo. Opcional: un bonus pequeño por jugar en grupo, como el +10% de Diablo 4. **[PROPUESTA]**
- Por defecto no hay escalado de mobs según el número de jugadores. **[PROPUESTA]**

## Pendientes por decidir

- Si, en el juego final, la rama se fija al crear el personaje (en el prototipo se elige al entrar en la partida).
- Reglas de las sinergias elementales: qué pasa al mezclar elementos, topes y resistencias de mobs.
- Coste del respec y, mucho más adelante, cómo funciona el renacer (qué se conserva).
- Si la elección del nivel 50 fija el tipo de arma, cómo se tratan los drops de otros tipos.
- Base de control: ratón/teclado o twin-stick.
- Profundidad del sistema de gemas (tiers, mejoras, combinaciones).
- Míticos: ranuras normales o gemas fijas.
- Tope de distancia del salto y si es comprometido.
- Cosmético separado de stats.
- Herramienta y flujo de arte (probar con un sprite de prueba).
- Cómo conectan los jugadores en el coop.
- Número máximo de jugadores más allá de la alpha (4).
- Qué es "todo" en hardcore (borrar el personaje o solo el inventario) y cuánto dinero se pierde al morir en el modo normal.
- Modo difícil del mundo: qué cambia exactamente (zonas, élites, amenazas, minerales nuevos) y cuánto contenido nuevo trae.

## Notas sobre Steam (si se publica ahí)

- El código escrito con asistentes de IA no requiere declaración (política actualizada en enero 2026; revisar el formulario al publicar).
- El arte generado con IA que se distribuya en el juego o en la tienda sí hay que declararlo. Neku planea hacer el arte él mismo.
