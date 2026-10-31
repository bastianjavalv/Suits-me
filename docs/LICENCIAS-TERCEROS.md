# Licencias de terceros

| Componente | Uso | Licencia | Dónde |
|---|---|---|---|
| Godot Engine 4.7.2 | Motor del juego y plantillas de exportación | MIT | <https://godotengine.org/license> |
| Playfair Display | Tipografía de títulos | SIL Open Font License 1.1 | `game/assets/fonts/OFL-PlayfairDisplay.txt` |
| Jost | Tipografía de texto | SIL Open Font License 1.1 | `game/assets/fonts/OFL-Jost.txt` |

## NRO homebrew para Switch

Componentes que se enlazan en `AtelierDeLasEras.nro` o que solo se usan para compilarlo. Ninguno es
de Nintendo.

| Componente | Uso | Licencia | Dónde |
|---|---|---|---|
| Port de Godot para Switch (DemoxDev/godot-switch-template, commit `cca2e20`) | Plataforma `switch` y parches, copiados en `switch/motor/` | MIT | `switch/motor/LICENSE`, `switch/motor/NOTICE` |
| libnx 4.12.0 (switchbrew) | Acceso al sistema de la consola, enlazado | ISC | <https://github.com/switchbrew/libnx> |
| Mesa 20.1 (switch-mesa) y libdrm_nouveau | OpenGL ES 3 y EGL, enlazados | MIT | <https://docs.mesa3d.org/license.html> |
| newlib y bibliotecas de GCC (devkitA64) | Biblioteca C y C++ en tiempo de ejecución, enlazadas | Licencias permisivas de newlib; GPL 3 con la excepción de biblioteca de GCC | <https://devkitpro.org> |
| devkitA64, switch-tools (`elf2nro`, `nacptool`) | Solo compilación y empaquetado | GPL y licencias de cada herramienta | Imagen `devkitpro/devkita64`, fijada por digest en la CI |

Todo lo demás (código, datos, sombreadores, modelos procedurales, textos de la enciclopedia y
capturas) es obra original de este proyecto. Las citas de la enciclopedia remiten a sus fuentes,
cuyos textos no se reproducen.

Este proyecto **no** incluye código, recursos, marcas ni personajes de SUITSME ni de Zirafit
Limited, y no está afiliado a ellos.

La licencia del propio proyecto está pendiente de decisión del titular del repositorio.
