# Soundlings — mundos con personalidad

Prototipo para iPhone y iPad, iOS 17+, con interfaz en inglés. Seguimos editando **el mismo Soundlings.xcodeproj**: no se creó otro proyecto ni se cambió la versión de la app. No necesita paquetes ni sonidos externos.

## Probar

1. Abrí **Soundlings.xcodeproj** en esta carpeta, seleccioná el esquema **Soundlings**, un iPhone o iPad y pulsá **⌘R**. Para un dispositivo físico, configurá tu equipo en Signing & Capabilities.
2. Elegí **The Hanging Gardens** desde **…** y tocá **Play**. Si tenías un mundo guardado anterior, cargar el preset permite escuchar la nueva composición inicial completa.
3. Comparalo con **The Moon Courtyard**: terrazas cálidas, ritmo más activo y campanas frente a islas violetas flotantes, tempo lento, coro y pedal sostenido.
4. Tocá **Random**, arriba junto al menú. Cambia arquitectura, tamaño y recorrido, paleta, tonalidad, escala, acordes, tempo, swing, eco, instrumentos, ritmos, densidades, registros, volúmenes, paneos y puntos de partida. Si estaba sonando, prepara y reproduce la nueva creación. **Build → Undo** recupera la anterior.
5. Abrí el mezclador para aislar cada personaje y explorar sus sonidos. Los ajustes detienen la música; tocá Play después de editar.
6. **Save World** conserva el mundo en el dispositivo. **Export World** guarda un JSON completo; **Import World** permite abrirlo en otra instalación. **Export Stereo WAV** guarda un loop musical para compartir desde Archivos.

El botón de encuadre vuelve a mostrar el mundo completo. Pellizcá para acercarte, arrastrá con un dedo para girar y con dos para desplazar. Los controles funcionan durante la preparación de audio. iPhone usa orientación vertical; iPad también admite horizontal.

## Lienzo vacío y cámaras

**… → New Empty World** inicia el constructor sin piezas ni personajes activos. Arrastrá un módulo desde el catálogo, o tocá su tarjeta: agrega el recorrido y activa su personaje musical. El lienzo vacío y los mundos de una sola plataforma se pueden guardar, exportar e importar. Undo recupera el mundo anterior.

El botón **Follow** abre controles con el nombre del personaje y flechas **‹ / ›** para pasar rápidamente entre las voces activas. **First person** coloca la cámara a la altura de sus ojos; arrastrar horizontalmente permite mirar alrededor. **Follow view** vuelve al seguimiento exterior y el visor vuelve al mundo completo. La cámara omite el cuerpo propio y se estabiliza respecto del pequeño vaivén de caminar. En primera persona el ángulo horizontal es de 92°, con suavizado de posición y giro. Los portales usan una única envolvente de fundido: 0,14 segundos para cubrir el traslado y 0,22 segundos para revelar el destino. La cámara y el video exportado comparten esa misma transición. Los portales muy próximos se encadenan bajo un mismo negro para evitar destellos entre traslados.

El icono de la app está integrado en Assets.xcassets/AppIcon.appiconset, con imágenes opacas para iPhone, iPad y la ficha de la tienda. Es el mismo proyecto y conserva su identificador y versión.

## Constructor y Random comparten las mismas piezas

**Build** abre una bandeja sobre el mundo. **… → New Empty World** abre ese mismo constructor desde cero. Ya no hay arquitectura exclusiva de Random: el generador guarda sus arcos, pabellones, islas, columnas, ruedas, cascadas, árboles, estanques y órbitas como piezas editables del mismo catálogo. Los mundos anteriores convierten su decoración en esas piezas al cargarse. Borrarlas no hace que vuelvan a aparecer.

1. Arrastrá un módulo al mundo o tocá su tarjeta. El primer módulo se ubica donde lo soltás; los siguientes se conectan al final del recorrido, orientados hacia donde los soltás.
2. Mantené pulsada cualquier pieza de un módulo y arrastrá para mover todo el conjunto. Soltar confirma una única acción de Deshacer.
3. **Undo** recupera el estado anterior. **… → Redo** repite la última acción deshecha.
4. **Play** permite escucharlo. **Share video** elige duración y montaje y abre la hoja de compartir al finalizar.
5. **… → Edit individual pieces** conserva el constructor detallado: piezas musicales, decoración, personajes, coordenadas, alturas, tamaños y mezcla. **Advanced** oculta o muestra las herramientas precisas; desactivarlo devuelve el catálogo de módulos.
6. **Save** conserva el resultado. **Export World** comparte los datos completos para reconstruir el mismo mundo en otra instalación.

Se verificó que 200 mundos generados se pueden reconstruir exactamente usando únicamente las operaciones de colocación del constructor y sus mismos ajustes musicales. En el uso manual, las coordenadas precisas permiten copiar posiciones fraccionarias, además de construir libremente. Esto es equivalencia de las piezas y datos; los gestos y la comodidad de uso todavía necesitan prueba en iPhone/iPad.

## Nuevos instrumentos, pantalla completa y video

**Build → … → Edit individual pieces → Path & sound → Harp / Wind / Wood** coloca cuerdas, tubos de viento o láminas de madera. Al llegar una voz melódica, la superficie cambia su sonido a cuerda pulsada, flauta o marimba. Los elementos vibran/se iluminan y los brazos del personaje responden al disparo musical. Los drones y golpes de batería conservan su función. El mezclador también ofrece **String, Flute y Clarinet** en las voces compatibles. String usa una cuerda sintetizada con línea de retardo y amortiguación; flauta y clarinete usan síntesis de aire y armónicos, sin muestras externas.

Random combina cinco arquitecturas: terrazas, islas, espiral, recorrido ondulado y anfiteatro. Elige una familia instrumental dominante. Los mundos guardados anteriores siguen abriendo; regenerar una semilla con este generador actualizado puede dar otro resultado, por lo que conviene compartir el JSON completo.

El botón de expansión inicia la reproducción y muestra únicamente el mundo. **Tocá una vez la pantalla para recuperar todos los controles.**

**… → Export Video with Audio** o **Share video** prepara un MP4 vertical de 1080 × 1920, 30 fps, con audio estéreo. Permite elegir un loop o aproximadamente 15, 30 o 60 segundos, ajustados a compases completos. El montaje automático alterna planos generales con movimiento, seguimiento, primera persona de personajes que caminan y pantalla partida opcional. También se puede conservar la cámara actual. Funciona con mundos construidos y randomizados; no incluye controles de la app. El avance tiene botón Cancel. Al terminar aparece la hoja de compartir de iOS para guardar en Archivos o enviar a una app instalada. La reproducción se pausa durante la preparación. **Export Stereo WAV** guarda el audio por separado a 48 kHz/16 bits.

El video usa una escena independiente y timestamps derivados del mismo reloj musical que el audio. La exportación y su cancelación necesitan validación final en iPhone/iPad: esta sesión no dispone de GPU ni de un simulador operativo.

## Flotación, arpegios y menos portales

**Violet** sostiene su pedal en un núcleo luminoso y permanece flotando sobre su estación. **Sage** vuela entre destinos musicales, abre su dosel y muestra tres luces para sus acordes. Ahora ambos buscan altura libre sobre la arquitectura: el vuelo contempla también arcos y anillos, no atraviesa sus bordes. Sage asciende, cruza y desciende con velocidad limitada; conserva el rumbo de un trayecto hasta completarlo. Los personajes voladores no saltan por choques de caminantes ni usan teletransportaciones.

En **Build → Musical Steps** hay dos nuevas piezas para Coral:

- **Filter Gate:** cambia un filtro pasa-bajos real de 150 a 12.000 Hz. La apertura se ajusta en Details; la lente del personaje y las láminas de la pieza muestran el cambio. El filtro permanece hasta la siguiente puerta.
- **Octave Bloom:** expande el arpegio a 1, 2 o 3 octavas, dentro del registro disponible. Los anillos del personaje indican su rango activo. El arpegio sigue tomando sus notas de la armonía común y mantiene la escala/modo.

Los modificadores se guardan en el mundo y actúan sobre el audio y el video exportados. Sus cambios y luces usan los eventos del reloj musical; una maniobra de colisión todavía puede demorar físicamente a Coral respecto de esa secuencia programada.

Random agrega puentes y escaleras continuas con pendientes suaves. Una casilla silenciosa que se salta musicalmente deja de considerarse un portal si el camino intermedio existe. En 200 semillas probadas quedó como máximo un enlace de portal por mundo, reservado principalmente para el regreso entre alturas. Los mundos guardados conservan su geometría; Random genera los nuevos recorridos.

## Activar y apagar personajes

Sobre los controles de reproducción hay seis miniaturas con los colores y accesorios de los personajes. Tocá una para activar o silenciar esa voz. El borde de color y el check indican que está activa; en gris y con el altavoz tachado está apagada. Los controles ofrecen nombres y estado para VoiceOver. Los personajes apagados también desaparecen del mundo y su estado se guarda y se exporta con él.

Si la música estaba sonando, el cambio vuelve a preparar y reproduce el loop desde el inicio. Durante esa preparación los botones se bloquean brevemente. Si apagás al personaje seguido, la cámara pasa a otro activo; si apagás todos, vuelve a la vista general. También se pueden activar y apagar desde Music & Voices.

## Personajes y música

| Personaje | Función | Acción visible |
|---|---|---|
| Azure, azul | Melodía: campana, marimba o reed | Camina y llega a las notas según su ritmo |
| Coral, coral | Arpegios de la armonía, filtros y expansión de octavas | Activa puertas de filtro y rango; lente y anillos muestran sus efectos |
| Gold, dorado | Bajo redondo o resonante | Pasos pesados y espaciados; sigue la armonía |
| Violet, violeta | Pedal sub o bowed | Flota sobre una estación con un aro; sostiene la tónica durante todo el loop |
| Sage, verde | Pad cálido o coro | Se desliza y despliega una cúpula mientras sostiene acordes |
| Ember, naranja | Percusión electrónica o madera | Permanece en su tambor y mueve brazos/pies con bombo, caja, hi-hat y rim |

Los timbres son síntesis procedural, no grabaciones de instrumentos acústicos. Hay 16 timbres en seis familias. El drone permanece independiente de la progresión armónica. Las llegadas, saltos, golpes y luces usan el mismo calendario de eventos fraccionarios que el audio.

El mezclador permite elegir tonalidad y escala, cuatro grados de la progresión, duración de acordes, loops de 4/8/12 compases, tempo, swing, eco y paleta. Por voz hay controles de timbre, ritmo, densidad, longitud, brillo, volumen, paneo, registro, patrón y estación inicial según su función. Densidad introduce silencios reproducibles mediante la semilla.

## Construir

Tocá un pad o **Build**. **Note** define el tono de la melodía, ajustado a la escala; **Chord** agrega su tríada; **Drum** acentúa llegadas; **Transpose** modifica las voces afinadas que recorren la ruta; **Rest** silencia la llegada. Pad y bajo siguen la progresión. El drone mantiene su pedal.

Las puertas establecen transposiciones relativas, sin acumulación indefinida. El mapa sigue el orden del recorrido; invertirlo puede cambiar las transposiciones. El loop musical tiene duración propia: los personajes no necesariamente visitan todos los pads en cada loop.

Agregá vecinos con West/North/Up/East/South/Down, eliminá pads o usá Undo/Redo, con historial de 24 cambios. Se permiten entre 0 y 96 pads. Podés borrar el último para volver al lienzo vacío. Las conexiones largas o verticales se convierten en portales. Las transiciones de portal desvanecen al personaje sólo al final del trayecto y lo hacen reaparecer gradualmente cuando el destino queda libre. Los giros se interpolan y los engranajes y el vaivén cierran ciclos completos al repetir el loop. El encuadre permanece estable durante la evitación de obstáculos. La validación al construir todavía es básica: el editor puede permitir superposición entre estructuras estáticas. La evitación de personajes actúa sobre el escenario resultante.

## Colisiones y acabado visual

Los personajes usan volúmenes de colisión y buscan espacio sobre plataformas y puentes. Las correcciones laterales mantienen una decisión durante un intervalo, evitando alternar de lado en cada cuadro. El paso de los pies y la orientación siguen el desplazamiento real, no el avance del calendario musical cuando el personaje está detenido. Durante la reproducción, avanzan desde su posición anterior con velocidad limitada; si se encuentran dos personajes, uno puede realizar un salto con trayectoria completa mientras el otro espera. Si un techo impide saltar, intenta retroceder y girar. La maniobra queda fijada hasta terminar, con un tiempo de espera antes de repetirla. Si no hay una trayectoria segura, esperan. El percusionista dispone de una plataforma ampliada. Pad y drone vuelan a alturas distintas. Las piezas sólidas de la arquitectura se consideran obstáculos; los arcos y anillos abiertos conservan sus huecos.

La evitación puede desplazar al personaje respecto del centro de su estación. El pad luminoso conserva el disparo musical exacto: la interacción física no retrasa el sonido. Se trata de colisiones cinemáticas simplificadas, no de simulación física de mallas ni choques con masas, rebotes o gravedad completa. Las maniobras en cruces muy densos todavía necesitan evaluación sobre dispositivos reales. La colocación inicial puede elevar un personaje cuando no encuentra suelo libre; durante la reproducción los saltos son maniobras continuas comprobadas contra cuerpos y obstáculos. Los bordes bajos de las plataformas permiten bajar un escalón sin tratar al propio suelo como una pared.

El acabado incorpora piedra y metal con materiales físicos, oclusión ambiental, iluminación más contenida, teclas pequeñas en los pads y personajes con collares, insignias, orejas, gorro, mochila y mazas según su papel. Los volúmenes más pequeños dejan espacio para cruzarse.

## Conservar y compartir

Hay una ranura local. Random y cambiar presets no sobrescriben esa ranura automáticamente: usá Save World para conservar el resultado. Las importaciones y Random pueden deshacerse.

El JSON incluye geometría, instrumentos, secuencias, semilla y todos los parámetros; la semilla sola identifica la generación inicial, pero no representa las ediciones posteriores. Se rechazan archivos mayores de 1 MB y configuraciones no válidas. Los guardados anteriores de esta misma app se migran a seis roles.

WAV exporta exactamente un loop estéreo, 48 kHz/16 bits, con las mismas colas y mezcla que la reproducción. El JSON permite intercambiar mundos y el MP4 abre la hoja de compartir de iOS. La galería pública y los enlaces web siguen pendientes.

## Coherencia de escala y modo

Random mantiene activado **Music & Voices → Stay in scale / mode**. Melodía, arpegios, acordes, pads, bajos y drone usan la misma tonalidad y modo; los mecanismos de arpa, viento y madera toman esas mismas notas. Las quintas del bajo y los acordes se construyen por grados del modo, y las puertas de transposición desplazan grados de esa escala en vez de modular a otra tonalidad. El límite de registro también elige una nota perteneciente al modo.

El constructor ofrece **Diatonic triad / Suspended** para los acordes mientras la protección está activada. Se puede desactivar **Stay in scale / mode** para trabajar deliberadamente con acordes mayores/menores cromáticos y transposiciones por semitonos. La preferencia se guarda y viaja en el JSON; los mundos anteriores quedan protegidos de forma predeterminada.

## Sincronización

El audio se sintetiza en segundo plano antes de reproducirlo. Cada evento se coloca en `round(beat × 48000 × 60 / BPM)`, con error máximo de media muestra. Los sonidos no se disparan desde animaciones ni temporizadores de interfaz. Las colas se pliegan al inicio, el eco es circular y el pedal usa ciclos completos para evitar discontinuidades en la unión.

AVAudioPlayerNode repite el buffer. La animación lee su posición, compensando aproximadamente la latencia de salida y usando la longitud real del buffer para evitar deriva entre vueltas. Esto verifica precisión digital; la latencia acústica y el rendimiento deben medirse en dispositivos. Bluetooth puede agregar demora variable. La app se pausa al salir y detiene la reproducción ante interrupciones o cambios de salida.

## Verificación

Ver **VALIDATION.md**. Desde esta carpeta:

```sh
bash Tests/run.sh
```

**Audio Preview.wav** se genera con el renderer actual. **Reference/Concept.png** conserva la referencia visual. **Geometry Preview.png** es una aproximación anterior por CPU de la geometría, no una captura de iOS: no representa los materiales, sombras ni iluminación finales de la GPU.

## Pendiente

Prueba visual, táctil y acústica en iPhone/iPad; medir rendimiento y latencia. No se pudo ejecutar CoreSimulator ni acceder a una GPU desde esta sesión. La comprobación del código y las pruebas automatizadas no sustituyen esa prueba.

Faltan enlaces sociales, biblioteca de mundos, edición mientras suena, MIDI, arte definitivo, más gestos de construcción y colisiones avanzadas. Las conexiones imposibles dependientes de la perspectiva, bifurcaciones, ascensores físicos y modo aventura siguen pendientes. Girar cambia la vista, no la conectividad del mundo.

### Live character controls

Tap a portrait to follow that character. If already in first person, another portrait switches directly to that character’s first-person view. The separate speaker button toggles its sound and visibility. Disabled characters cannot be followed.

The six pre-rendered voices share one sample clock. Speaker toggles ramp over 8 ms without restarting the transport; even with everyone muted, the world clock keeps running. Pause freezes that clock and Play resumes it. WAV/video export uses the same stems, enabled voices and post-mix limiter. On-device audio and touch-layout checks remain necessary.

### Building before adding characters

New Empty World starts with all characters disabled. Place musical steps and scenery first, then open **Build → Characters** and tap **+** for each creature. Placing any catalogue piece, including Orbit, never enables a voice. The palette shows the active placement item; changing category returns to selection mode. Long-press dragging is disabled during placement so it cannot replace a chosen item with an existing selection.

Raised walkways now use short deck sections and foot clearance on approaches to higher landings. Late walkers follow intermediate route corners. Drone halos remain horizontal above the head, arpeggio rings stay below the face, and Orbit reserves its decorative envelope against ground characters. If a placed solid structure completely blocks a path, move it to restore passage.

**Front / Isometric:** the camera controls include a Front button for an aligned orthographic view with a shallow 12.5° downward angle. Front resets world rotation, follows no character, and keeps horizontal platforms horizontal on screen. Tap Isometric to return to the diagonal overview. The chosen angle also carries through to video export.

### Backdrops

Open **Backdrop** beside the camera controls, or use **Music and voices → World personality → Backdrop**. Choose Sky, Space, Underwater, Mist or Sunset. Space has stars, a nebula and a distant crescent; Underwater has light shafts, bubbles, turquoise lighting and depth haze. Backdrops are procedural, deterministic from the world seed, and independent of architecture. Random varies the backdrop too.

Changing a backdrop keeps live audio running. The setting is saved in the world JSON and reproduced in video export. Older files default to Sky. Distant backdrop artwork is static; bubbles and stars are not animated particles.

### More coherent Random worlds

Random now lays out a continuous promenade before adding decoration: rounded terraces, lobed island circuits, ribbons, amphitheatres and a rising helix. Walking starts are separated; 1.55-unit-wide bridges allow passing; percussion uses a lateral stage. Scenery must clear the entire walking corridor and stage, including space above characters. Architectural supports stop below the deck.

Each walking voice completes one circuit per musical loop, with its own rhythm and an offset starting position. This prevents the long catch-up movement caused by restarting a short musical sequence halfway around a large route. New random worlds use eight bars and a moderate tempo range. **Complete route each loop** and **Walkway width** are editable in the music settings, persisted and exported. These rules apply to newly generated worlds; existing saved layouts retain their settings.

Backdrops now use 2048×2048 artwork: atmospheric landscape layers and cloud banks, softly shaded planets and irregular nebulae, or feathered underwater light shafts, distant terrain and aquatic plants. Highlights, haze and fine grain keep the centre readable for the musical world.

### Rotating mechanisms and character-panel folding

Gear rotation now uses a separate rotor beneath a fixed axle orientation. Orbit rings retain their fixed tilt beneath rotating pivots. Every mechanism reserves its complete swept envelope, including teeth and rims, for character avoidance and placement checks against other scenery. Build rejects overlapping placement, movement, rotation and resizing; Copy searches for a clear nearby position. Loading a world or selecting a preset repairs overlapping legacy mechanisms in the stored model so saved positions match the scene.

The initial Hanging Gardens world has a dedicated raised drum stage with a clear gap to its route. It is prepared before playback and revealed when the percussionist is enabled. Other worlds retain their prior stage-placement rule.

Tap **Characters** above the portraits to collapse or expand that panel. The preference persists across launches and does not touch audio playback or mute states.

### Learn how each world is built

Tap **Learn** beneath Random, or choose **How This World Is Built** from the world menu. The guide captures the current world and shows its construction in a separate 3D preview: world settings, each path step, each instrument, scenery and characters. Future pieces are faint, built pieces are solid, and a gold outline identifies the current piece.

Use **Back / Next**, **Auto**, the chapter menu and **Zoom to piece**. **Exact settings** exposes coordinates and the matching editor controls. Keep Reverse route off while placing the path in index order, then apply the original direction at the end. Precise music settings now includes walkway width so values such as 1.55 can be reproduced exactly. Closing the guide returns to the same world and resumes previously playing audio at its paused position; an audio interruption or inactive app prevents automatic resumption.

### Open gateways

Transpose rings are now violet open arches aligned with their route; portals use the same solid-arch construction. Their piers and segmented vault have collision geometry around a character-sized opening. Combined transpose/portal stations use one arch. Solid arches no longer change size during animation. Foot clearance follows sounding surfaces, and actor collision radii cover their costumes and rings. Moving mechanisms also reserve clearance from these gateways.

### Simpler building
The default builder shows Path & sound, Decorate, and Friends. Choose a piece and tap beside the selected step: new path pieces attach in that direction and inherit its elevation. Extend path starts an empty path or continues the last segment with one tap. Change sound replaces the selected step's instrument without rebuilding the path. Add friends explicitly, then press Play. Hold an existing piece to move it; Undo remains available.

Advanced reveals free placement, elevation, the full sound catalogue, music settings, and precise inspectors. Switch Advanced off to return to automatic attachment. Learn uses short visual instructions, with numeric reconstruction data folded into Advanced details. Palette dragging and isolated sound audition are not included in this simplification.

### Module-first building
New empty worlds now open a compact module shelf: Musical stairs, Rhythm terrace, String bridge, Wind tower, and Quiet garden. Drag a card into the scene, or tap it to add it. The first drop chooses the location; subsequent drops choose a cardinal direction from the path's final step. Every module adds six connected musical steps, a side ornament, and its associated voice. Connections and elevation are automatic, with one undo for the whole addition. Busy directions and world limits reject the whole addition without partial edits. The viewport reframes after placement.

Share video opens the existing vertical movie export/share flow. More → Edit individual pieces retains the detailed editor and full saved-world compatibility. Modules retain persistent grouping IDs and can be moved together by holding any member piece; their thumbnails show their actual path geometry. Drag placement and movie rendering need device validation. The module shelf uses native drag and drop (touch and hold briefly, then drag).


### Grouped modules and larger worlds
Hold any step or decoration in a module, drag, and release to move the complete assembly. A translucent preview preserves relative geometry; release commits one undo, cancellation restores everything, and occupied positions reject the move. Saved/exported worlds retain group membership. Earlier exact six-step modules recover their grouping when entering Build; arbitrary legacy structures remain individual pieces. Advanced editing still allows individual changes.

The module shelf now includes Echo courtyard (12 steps), Waterfall walk (14 rising steps), and Woodland maze (18 steps), with mixed musical stations and three ornaments each. Existing six-step modules remain available. Tile/structure count caps and fixed world-coordinate bounds have been removed; coordinates must remain finite and overlap checks still apply. Camera fitting/clipping follows the world's extent. Actual capacity depends on device memory and rendering performance.

### Photographic atmosphere with motion
The five existing environments now use generated photographic-style images bundled in the asset catalog. Clouds drift as transparent layers in Sky, Mist, and Sunset, even while the music is paused. Space occasionally shows a short meteor. Scenery uses fixed 2:1 longitude/latitude coordinates and never participates in world bounds or collisions. Live atmosphere uses a continuous view clock; export uses explicit music timestamps, so motion remains deterministic across shots and split-screen views. The current renderer wraps image-based panoramic environments around the camera; distant scenery changes with viewing direction, without false parallax during translation. The previous procedural paintings remain a fallback if artwork cannot load.

Artwork assets, generation method, and final prompt set: [BACKGROUND_ART.md](BACKGROUND_ART.md). Device/GPU validation of the final composite and MP4 encoding is still required.


### Camera orbit and surrounding panoramas
Dragging with one finger now moves the camera around the fixed construction. Turning in first person changes the direction seen in the panorama. Fit world and Front reset the camera orbit. Automatic movie orbit shots and both split-screen cameras use the same camera/environment mapping.

All five environments ship new 2:1 panoramic images, generated with the built-in image generation tool (saved paths and final prompts in BACKGROUND_ART.md). A camera-centered, unlit sphere renders behind the world without writing depth, casting shadows, changing editable bounds, or intercepting piece selection. Distant scenery follows camera translation to avoid artificial near-field parallax. Clouds and meteors animate in fixed panoramic coordinates; changing viewport shape does not reset them. Scene fog is disabled on this compositing path; atmosphere is supplied by the panorama and environment lighting. The old background plates remain as fallback resources.

Physical-device review is still required for panorama orientation, the wrap seam/poles, clarity at different zoom levels, touch orbit direction, and final MP4 frames. This is a distant panoramic environment, not a navigable terrain mesh.

### Shared visual finish across every world
All presets, saved/imported worlds, random worlds, manual modules, tutorial scenes and video renders use the same visual style. No regeneration or world-data conversion is required.

- Stone, brushed metal, wood, enamel, cloth, foliage and water have bounded 128-pixel procedural surface maps, normal detail and separate roughness. Stone blocks have restrained per-piece color variation and softer three-segment bevels. Vault meshes now supply real normals and UVs and receive the same lighting as the rest of the architecture.
- Panoramas supply environment reflections, complemented by soft directional shadows, cool rim light, calibrated ambient light and restrained bloom. Character contact shadows project onto actual walkways and disappear over empty space.
- Character clothing has a matte fabric finish; faces stay smooth, blink briefly, look toward the next part of the path, lean slightly through turns and show gentle breathing and anticipation. These expressions leave locomotion and the eye-level camera anchor independent.
- Piano keys depress, drum membranes compress, strings vibrate laterally, wooden bars move slightly and wind tubes pulse. Emission decays with musical activity instead of applying full-bright color continuously. Silent steps use quiet stone surfaces.
- Basins and waterfalls have transparent, reflective materials with time-driven ripple normals and subtle foam. Water also animates in scenery-only worlds. Export uses explicit timestamps; live animation continues while paused.

Reflections are from the environment panorama, not screen-space mirrors of nearby objects. Water uses animated surface normals rather than fluid simulation or physical refraction. The final rendered balance and device performance still need iPhone/iPad review because the development environment has no GPU rendering.

### Overview background sampling
The static panorama now goes directly into the surrounding sphere's texture; it is no longer drawn into SpriteKit's intermediate texture. A separate transparent sphere carries animated clouds and meteors. Both layers use linear/mipmap/anisotropic filtering, and sphere tessellation is higher. Overview background pitch is limited to a gentle horizon angle to avoid magnifying the panorama's compressed polar region; horizontal orbit remains continuous and first-person pitch is unchanged. This is an image-based background presentation choice, not new terrain geometry.

The source panoramas remain at their genuine 1774 × 887 resolution. This correction removes an extra rasterization and reduces polar distortion; it does not invent high-resolution source detail or claim 4K artwork. Actual clarity, orientation and alpha composition still require device review.


The overview background now uses the existing native 1254 × 1254 photographic plates with aspect-fill framing and 8% overscan. It samples almost the complete image height in portrait instead of magnifying a tiny sector of the 360° panorama. Horizontal texture position now follows camera azimuth continuously through complete rotations, with one image period per turn. Feathered matching boundaries allow seamless horizontal repeat while vertical framing stays bounded. This preserves the photographic plate detail; it does not reconstruct unseen physical scenery from a single photograph. First-person views retain the spherical panorama. The animated atmospheric layer keeps its own camera-relative panoramic coordinates. Tutorial focus, landscape and video framing use the same overview plate path.

First-person panoramas retain cached Lanczos reconstruction into a 4096 × 2048 sampling texture from the original 1774 × 887 artwork. Overview plates bypass that reconstruction and directly sample their native image. Front and Backdrop controls use circular icons with accessible labels. CPU composition previews for all five overview environments are in Previews/; they show the actual image crop, not a GPU screenshot of the game.


Living environments: the underwater surface has spatially masked ripple flow, edge vegetation sways with roots pinned at the seabed boundary, feathered sun shafts shift direction/intensity, and caustic lines move over the distant floor. Sunset water receives traveling wave distortion and fragmented glints whose intensity uses analytic wave normals, a sun/view half-vector and Schlick Fresnel; glints also respond to camera heading and elevation. Sky photographs have slow cloud flow in addition to the existing drifting cloud layers. Space retains occasional meteors. The native photographic textures stay directly bound to the materials, preserving the sharper overview treatment. First-person panoramas use a shared tessellated sphere with animated texture coordinates. Everything uses explicit atmosphere time, including pause and video export; split-screen cameras evaluate the same simulated instant.

These are bounded photographic motion effects and an analytic reflection overlay, rather than a fluid solver, a fully modeled ocean, or reconstruction of 3D vegetation from the background photograph. Full scene reflections/refraction and true plant geometry are not implemented. Final GPU appearance and export playback still need device review.

## Sea 360° video pilot

Open the existing project and run on iPhone/iPad. Tap the backdrop icon and choose **Sea · 360° video** (the existing `sunset` environment identifier is preserved for saved worlds). This pilot replaces that environment only. Its resource is `Soundlings/EnvironmentVideos/Ocean360.mp4`: a silent 11-second coastal 360° loop adapted from 2FILMZ Studios under CC BY 3.0. It is a 4K stereoscopic-source adaptation, not final-quality 8K open-ocean sunset footage. Other backgrounds keep their previous behavior.

The live scene uses a muted AVQueuePlayer + AVPlayerLooper as the spherical material. A matching first-frame poster covers startup. Both overview and first-person cameras sample the same world-anchored panorama, with a fixed initial yaw aimed toward the sea. The former photograph sliding, UV distortion and artificial ocean glints are disabled for this video. The panorama already records real water motion and reflections; it cannot re-light or reconstruct a 3D ocean when the observer translates.

Video export stops the pilot's separate playback instance and sequentially decodes native frames with AVAssetReader, indexed by the simulated clock, rather than recording wall-clock AVPlayer playback. Both split-screen cameras reuse the same decoded image. Each 330-frame wrap resets the reader to the beginning. Exports carry visible footage credits; Help also links the author/source and license. Full attribution and processing notes are in `Soundlings/EnvironmentVideos/ATTRIBUTION.md`.

Pilot device checks: select Sea, rotate through a complete turn, switch into first person and back, pause/resume the music while checking the waves continue, watch at least three video loops, then export an automatic edit longer than 22 seconds with split screen. Confirm the sea keeps moving, the loop has no flash, the panorama responds to the same camera bearings and the exported background does not freeze. This environment cannot validate native AVFoundation playback/decoding or a complete MP4 export; those checks remain required on device.
