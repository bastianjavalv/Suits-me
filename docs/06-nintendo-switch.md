# Hito 6 — Adaptación a Nintendo Switch

## 1. Requisitos externos (no disponibles en este repositorio)

Compilar, probar y publicar en Nintendo Switch exige, como mínimo:

1. Registro y aprobación en el **Nintendo Developer Portal** (acuerdos de confidencialidad incluidos).
2. **SDK y kits de desarrollo** de Nintendo.
3. Para Godot, una **plataforma de consola de un socio autorizado** (por ejemplo, W4 Games); sus
   condiciones, precios y capacidades del renderizador deben confirmarse al solicitarla.
4. Superar la **certificación de Nintendo** y obtener las clasificaciones por edades de cada región.

Nada de esto se ha simulado: el repositorio no contiene herramientas privadas ni afirma tenerlas.

## 2. Qué está preparado en el código

| Pieza | Archivo | Estado |
|---|---|---|
| Detección sobremesa/portátil | `platform_bridge.gd` | En PC por tamaño de ventana o `--modo=`; en consola usa el singleton del port si existe (`CONSOLE_SINGLETON`, nombre a confirmar con el proveedor) |
| Confirmación de datos guardados | `platform_bridge.gd → commit_save_data()` | Llamada tras cada guardado; la implementación depende de la API del port |
| Mapa de botones por letra | `input_bindings.gd` | Probado (ver tabla) |
| Detección de mandos | `controls.gd`, `InputBindings.classify()` | Pro Controller, Joy-Con (L), (R) y pareja; Xbox, PlayStation y genéricos en PC |
| Joy-Con individual | `controls.gd → stick_rotates` | Pulsar el stick alterna entre navegar y girar el maniquí |
| Pantalla táctil | `gesture_recognizer.gd`, `app.gd` | Un dedo gira, pellizco hace zoom, doble toque restablece; los botones de la interfaz son táctiles |
| Cambio táctil ↔ mando | `controls.gd → input_mode_changed` | Las indicaciones de botones se ocultan al tocar y vuelven al usar el mando |
| Perfiles gráficos | `data/config/calidad.json`, `quality_profiles.gd` | Probados |
| Resolución dinámica | `dynamic_resolution.gd` | Probada con tiempos sintéticos |
| Teclado en pantalla | `LineEdit.virtual_keyboard_enabled` | El renombrado de looks es opcional: todos los nombres tienen valor por defecto |

## 3. Mapa de controles

Godot nombra los botones por posición (`JOY_BUTTON_A` = botón inferior). En los mandos de Nintendo
la **A** está a la derecha, por eso el juego asigna las acciones por la letra impresa:

| Control | Acción | Godot (Nintendo) | Teclado |
|---|---|---|---|
| Stick izquierdo / cruceta | Navegación (la cruceta, paso a paso y sin zona muerta) | Eje izquierdo / `DPAD_*` | Flechas, WASD |
| Stick derecho | Girar el maniquí (X) y encuadre vertical (Y) | `RIGHT_X/Y` | Q/E, R/F, arrastrar con el ratón |
| A | Confirmar / probar | `JOY_BUTTON_B` (derecha) | Intro, Espacio |
| B | Cancelar / atrás | `JOY_BUTTON_A` (abajo) | Esc, Retroceso |
| X | Opciones de vestuario | `JOY_BUTTON_Y` (arriba) | C |
| Y | Cambiar categoría | `JOY_BUTTON_X` (izquierda) | Tab |
| L / R | Cambiar sección o pestaña | `LEFT/RIGHT_SHOULDER` | 1/2, Re Pág/Av Pág |
| ZL / ZR | Alejar / acercar | Gatillos | Z/X, rueda del ratón |
| + | Pausa | `START` | P, F10 |
| − | Inventario («solo mi armario») | `BACK` | I |

Todo es reasignable en Opciones → Reasignar controles. Con un mando de Xbox en PC la disposición
automática usa la convención de Xbox (A abajo).

## 4. Perfiles sobremesa y portátil

| Parámetro | Sobremesa | Portátil |
|---|---|---|
| Resolución objetivo | 1920×1080 | 1280×720 |
| Objetivo de cuadros | 60 FPS (objetivo, no garantía) | 60 FPS (objetivo, no garantía) |
| Escala 3D dinámica | 0,8–1,0 | 0,7–1,0 |
| Antialiasing | MSAA 2× | FXAA |
| Mapa de sombras | 2048, filtro suave bajo | 1024, filtro suave muy bajo |
| Segmentos radiales de las prendas | 48 | 32 |
| Anillos por metro de prenda | 40 | 28 |
| Umbral de LOD | 1,0 | 2,0 |

La interfaz se diseña a 1920×1080 y se escala al lienzo; el texto más pequeño (22 px) equivale a
unos 15 px en 1280×720, y el jugador puede aumentarlo al 115 % o 130 %.

## 5. Rendimiento medido (honesto)

| Escena compleja (12 prendas, 40 piezas) | Sobremesa | Portátil |
|---|---|---|
| Triángulos del conjunto | 39 296 | 31 872 |
| Primitivas máximas por cuadro | 132 926 | 101 406 |
| Llamadas de dibujo máximas | 138 | 138 |
| FPS medio (llvmpipe, sin GPU) | 6,1 | 13,2 |

Las cifras de FPS se midieron en un contenedor **sin GPU** con renderizado por software: **no
indican** el rendimiento en Switch. Las cifras de geometría y llamadas de dibujo sí son
independientes del equipo. **No se puede afirmar que el juego alcance 60 FPS en Switch** hasta
medirlo en un kit de desarrollo con `tools/capturas_rendimiento.gd`, que produce el mismo informe.

## 6. Pendiente en hardware autorizado

1. Integrar el singleton del port (modo de funcionamiento, guardado, teclado del sistema).
2. Medir FPS, memoria y tiempos de carga en sobremesa y portátil; ajustar `calidad.json`.
3. Revisar el contraste y el tamaño mínimo del texto en la pantalla de la consola.
4. Probar Joy-Con individual, pareja de Joy-Con, Pro Controller y táctil en la consola real.
5. Requisitos de certificación (suspensión, cambio de usuario, mensajes de guardado).
