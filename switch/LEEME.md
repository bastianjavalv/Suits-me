# NRO homebrew para Nintendo Switch

Esta carpeta convierte *Atelier de las Eras* en `AtelierDeLasEras.nro`, un ejecutable homebrew que se
abre desde el Homebrew Menu (hbmenu) en consolas con firmware personalizado (Atmosphère).

> **Homebrew no oficial.** No usa ni contiene el SDK, código, claves ni recursos de Nintendo. Para
> publicar en la eShop o en cartucho sigue siendo necesario el programa oficial de Nintendo
> ([docs/06-nintendo-switch.md](../docs/06-nintendo-switch.md)).

## Contenido

| Ruta | Qué es |
|---|---|
| `motor/platform/switch/` | Plataforma `switch` para Godot 4.7.2: sistema operativo, pantalla EGL/GLES3, audio, mandos, táctil y teclado del sistema |
| `motor/patches/` | Tres parches pequeños a Godot: compilación de glad/EGL, `xattr` y un choque de nombres con newlib |
| `motor/GODOT_VERSION`, `motor/GODOT_COMMIT` | Etiqueta y commit oficial de Godot que se compilan (se comprueba el commit) |
| `motor/LICENSE`, `motor/NOTICE` | Licencia MIT del port y aviso de Godot |
| `compilar_motor.sh` | Descarga Godot, aplica los parches y compila el motor (ELF) |
| `empaquetar_nro.sh` | Une motor, `game.pck`, icono y metadatos NACP en el NRO |
| `LEEME-SWITCH.txt` | Instrucciones de instalación que acompañan al NRO |

El verificador `tools/verificar_nro.py` comprueba el NRO resultante: cabecera NRO0, sección ASET,
icono JPEG de 256×256, NACP y que la romfs lleve el mismo `game.pck` que se exportó.

## Origen del port

`motor/` parte del port comunitario
[DemoxDev/godot-switch-template](https://github.com/DemoxDev/godot-switch-template), commit
`cca2e20f9332716656797c4056fce3127daff0cf` (28 de octubre de 2026), con licencia MIT. Se copió en
lugar de descargarlo en cada compilación para revisarlo una vez y no depender de un repositorio
externo. Los cambios propios se describen en la sección siguiente.

## Cambios propios sobre el port

| Cambio | Archivos | Por qué |
|---|---|---|
| Resolución según el modo: 1920×1080 en la base y 1280×720 en portátil (el original fija 1280×720) | `nx_wrap.h/.cpp` (`docked()`, `default_window(ancho, alto)`), `display_server_switch.h/.cpp` | Cumplir los perfiles sobremesa y portátil del juego |
| Cambio en caliente al poner o quitar la consola de la base | `display_server_switch.cpp` (`process_events`, `_resize_surface`) | Al cambiar de modo se destruye la superficie EGL, se cambia el tamaño de la ventana nativa y se crea otra. El contexto GL se conserva, con sus texturas y sombreadores. Luego se avisa a la ventana raíz de Godot, como tras redimensionar una ventana de escritorio. Si la superficie nueva falla, se vuelve al tamaño anterior. |
| Coordenadas táctiles escaladas al tamaño de la ventana | `display_server_switch.cpp` | El panel táctil siempre informa en 1280×720 |

Mesa de Switch (`src/egl/drivers/switch/egl_switch.c` en devkitPro/mesa, rama
`switch-20.1.0-rc3`) libera los búferes de la ventana al destruir la superficie y lee su tamaño al
crearla; libnx solo permite cambiar el tamaño cuando la ventana no tiene búferes. En eso se apoya el
cambio en caliente. Compila sin errores; **falta probarlo en una consola**.

**Revisión realizada (31 de octubre de 2026).** Se leyó todo el código: unas 1600 líneas de C++ y
Python. El port solo llama a libnx y Mesa. Usa la romfs, la entrada (HID), el audio (`audout`), el
teclado del sistema (`swkbd`) y la versión del firmware (`setsys`). Abre el servicio de sockets
únicamente para `nxlink` (el registro hacia el PC), que solo conecta si el juego se lanza con
`nxlink -s`. Escribe solo en `sdmc:/switch/<carpeta>/`. No descarga nada ni lanza procesos.

**Comprobaciones del juego.** El recorrido de integración pasa con el renderizador GLES3
(Compatibility) y el servidor de texto básico (Fallback), que son los que usa este motor, incluida
la pantalla «Preparando gráficos…». La CI lo repite en cada cambio. El port informa los botones por su letra (A de Nintendo = `JOY_BUTTON_A`),
y el juego lo detecta por el GUID `switch-pad` (`game/src/platform/input_bindings.gd`).

## Cómo se compila

La CI («NRO para Switch (homebrew con CFW)») trabaja dentro de la imagen
`devkitpro/devkita64@sha256:1fc388c3…` (devkitA64 r29.2, GCC 15.2, libnx 4.12.0, switch-mesa 20.1.0).
El motor se guarda en caché mientras no cambie `motor/`. Los pasos para hacerlo en tu PC están en la
sección 9.1 del [tutorial](../docs/TUTORIAL.md).

## Limitaciones conocidas del port

- Compatibility (GLES3) en lugar del renderizador Mobile del PC.
- Mesa no guarda caché de sombreadores en Switch, así que cada arranque los recompila. El juego lo
  hace detrás de la pantalla «Preparando gráficos…»: recorre los 10 escenarios con un conjunto de
  cada época (`App._prepare_graphics`) para que no haya tirones al jugar.
- Sin hilos de trabajo, GDExtension, vibración ni sensores de movimiento. La pantalla táctil está
  implementada, pero el autor del port no la ha verificado.
- La partida se guarda en la tarjeta SD, no en el almacenamiento de partidas del sistema.

## Actualizar el port

1. Copia la nueva versión de `platform/switch`, `patches`, `LICENSE`, `NOTICE` y `GODOT_VERSION` del
   repositorio de origen en `motor/` y revisa las diferencias.
2. Actualiza `motor/GODOT_COMMIT` con el commit oficial de la etiqueta de Godot.
3. La clave de caché de la CI cambia sola y el motor se recompila.
