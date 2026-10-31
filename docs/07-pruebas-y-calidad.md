# Hito 7 — Pruebas y control de calidad

## 1. Inventario de pruebas

| Conjunto | Cantidad | Qué cubre | Cómo ejecutarlo |
|---|---|---|---|
| Herramientas (Python) | 22 pruebas | Auditoría de APK con APK sintéticos, verificador del repositorio, verificador sin conexión, validador de datos | `python -m pytest tools/tests -q` |
| Juego (Godot, unitarias) | 58 pruebas | Catálogo, conjuntos, filtros, economía, armario, looks, guardado y recuperación, evaluación, enciclopedia, controles, gestos, resolución dinámica, perfiles, mallas de las 86 prendas, contenido real | `godot --headless --path game -s res://tests/run_tests.gd` |
| Recorrido de integración | 29 comprobaciones | Pantalla de carga (solo GLES3) → menú → épocas → vestidor → Historia de la prenda → desafío → resultado → foto → enciclopedia → looks → galería → opciones → pausa, en sobremesa, en portátil y con GLES3 | `xvfb-run godot --path game -s res://tests/integration/recorrido.gd` |
| Compilación | 2 ejecutables | Exportación Linux y Windows; prueba de humo del ejecutable de Linux | Ver tutorial, sección 7 |
| Repositorio | 4 verificadores | Sin material propietario ni credenciales, sin red, datos válidos, documentación al día | `.github/workflows/ci.yml` |

El ejecutor de pruebas de Godot **falla si el motor registra cualquier error de script** durante una
prueba (no solo si falla una aserción). Se comprobó con una prueba negativa deliberada.

## 2. Requisitos del encargo y su prueba

| Requisito | Prueba |
|---|---|
| Inicio | Recorrido: «arranca en el menú principal»; prueba de humo del ejecutable |
| Navegación | Recorrido: A, B, Y y + simulados; cambios de pantalla verificados |
| Armario y vestuario | `test_catalog_outfit.gd`, recorrido («seis prendas puestas») |
| Accesorios | `test_meshes.gd` (todas las categorías generan geometría válida) |
| Economía ilimitada | `test_economia_ilimitada_nunca_rechaza_ni_descuenta` (1000 compras), recorrido («gemas ilimitadas») |
| Guardado y carga | `test_library_save.gd`, `test_todo_persiste_entre_sesiones` |
| Modo sin conexión | `tools/check_offline.py` y su prueba sobre el juego real |
| Enciclopedia | `test_enciclopedia_valida_fuentes_y_compone_la_historia`, `test_cada_prenda_tiene_historia_con_fuentes`, recorrido |
| Controles | `test_platform.gd` (mapa completo, simulación de pulsaciones, reasignación) |
| Sobremesa y portátil | `test_modo_por_tamano_y_perfiles`, recorrido en ambos perfiles, LOD portátil < 70 % |
| Rendimiento y estabilidad | `tools/capturas_rendimiento.gd`, recuperación de partidas dañadas |

## 3. Errores encontrados y corregidos durante el desarrollo

| Error | Cómo se detectó | Corrección |
|---|---|---|
| El ejecutor de pruebas daba por buena una prueba que abortaba por error de script | Revisión del registro | Captura de errores del motor con `Logger`; prueba negativa añadida |
| El verificador del repositorio no veía archivos nuevos sin versionar | El primer commit pasó sin revisarlos | `git ls-files --cached --others --exclude-standard` |
| Credenciales ficticias de las pruebas disparaban el verificador | El propio verificador | Se construyen por partes en tiempo de ejecución |
| La auditoría no deducía IL2CPP en un APK base sin bibliotecas | Informe del APK real | IL2CPP se deduce también de `global-metadata.dat` |
| Normales de las mallas hacia dentro (maniquí blanco y plano) | Captura | Producto vectorial corregido |
| Costura del torno en la cara del maniquí (grieta y rasgos asimétricos) | Primer plano | Costura en la espalda y ángulos normalizados |
| Collar largo de perlas con 12 768 triángulos | Prueba de presupuesto | Perlas de baja poligonización |
| El busto atravesaba los vestidos rectos | Captura de las épocas | Relieve completo y prueba de regresión |
| Todas las pantallas se maquetaban contra un rectángulo de 0×0 | Captura y volcado de rectángulos | `set_anchors_and_offsets_preset()` |
| Identificador con «ñ» en una ficha | Validador de datos | Identificadores ASCII obligatorios |
| Cuelgue intermitente del servidor gráfico virtual | Captura que superó el tiempo | Límite de cuadros (`--quit-after`) en todas las ejecuciones |

## 4. Validación gráfica

Las capturas de `docs/capturas/` se generan con el juego real (renderizador *Mobile*, Vulkan por
software): una por época con un conjunto representativo y las pantallas principales en sobremesa
(1920×1080) y portátil (1280×720). No se compararon con SUITSME porque este proyecto no reproduce
su aspecto (ver [01-informe-viabilidad-apk.md](01-informe-viabilidad-apk.md)).

## 5. Rendimiento medido

Escena compleja: 12 prendas (vestido, chaqueta, sombrero, peinado, collar, guantes, bolso,
cinturón, gafas, sombrilla, zapatos y maquillaje) en el escenario de neón, girando sin parar.

| Perfil | Resolución | FPS medio | ms p95 | Llamadas de dibujo | Primitivas | Triángulos del conjunto |
|---|---|---|---|---|---|---|
| Sobremesa | 1920×1080 | 6,1 | 187,8 | 138 | 132 926 | 39 296 |
| Portátil | 1280×720 | 13,2 | 88,9 | 138 | 101 406 | 31 872 |

Equipo: contenedor Linux de 4 núcleos **sin GPU**, `llvmpipe` (LLVM 20.1.2). Estos FPS no
representan Nintendo Switch; las cifras de geometría sí. La CI repite la medición en cada cambio y
la publica en el resumen de la ejecución.

## 6. Pendiente

- Mediciones en un kit de desarrollo de Nintendo Switch (requisito externo).
- Prueba del ejecutable de Windows en Windows (se genera en CI, pero aquí no pudo ejecutarse).
- Revisión humana de las 40 fichas y sus fuentes.
