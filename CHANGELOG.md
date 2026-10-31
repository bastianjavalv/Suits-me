# Registro de cambios

## 0.3.0 — 2026-10-31

### Añadido
- NRO: 1920×1080 en la base y 1280×720 en modo portátil, con cambio en caliente al poner o quitar
  la consola de la base. Es un cambio propio sobre el port (`switch/motor`): la superficie EGL se
  recrea con el nuevo tamaño y se conserva el contexto GL. El táctil se escala al tamaño de la ventana.
- Pantalla «Preparando gráficos…» con barra de progreso. Con GLES3 recorre los 10 escenarios con un
  conjunto de cada época para compilar los sombreadores antes de jugar, sin tocar la partida.
- Recorrido de integración: comprobación de la pantalla de carga (29 comprobaciones) y captura
  `00_preparando_graficos`.

### Cambiado
- La pantalla de arranque usa el fondo oscuro de la interfaz.

## 0.2.0 — 2026-10-31

NRO homebrew para Nintendo Switch con firmware personalizado.

### Añadido
- `switch/`: port comunitario de Godot 4.7.2 para homebrew (DemoxDev/godot-switch-template, MIT),
  revisado y copiado sin cambios; scripts para compilar el motor y empaquetar el NRO.
- Job de CI «NRO para Switch (homebrew con CFW)»: compila el motor con devkitA64 (imagen fijada por
  digest), empaqueta `AtelierDeLasEras.nro` con icono y metadatos y lo publica como artefacto.
- `tools/verificar_nro.py`: comprueba cabecera, icono, NACP y romfs del NRO (6 pruebas).
- `game/tools/icono_nro.gd`: icono JPEG de 256×256 a partir de `icon.svg`.
- Recorrido de integración con GLES3 y el servidor de texto básico en la CI.

### Cambiado
- Controles: disposición `switch` para mandos que informan los botones por su letra (el port
  homebrew); prueba nueva.
- Plataforma: detección del port homebrew; «Salir» disponible en PC y en homebrew.
- Perfiles gráficos: el FXAA solo se aplica en los renderizadores que lo admiten.
- El verificador del repositorio bloquea NRO, NSO y archivos de claves de consola.

## 0.1.0 — 2026-10-30

Primera versión jugable de *Atelier de las Eras*.

### Añadido
- Auditoría de solo lectura del APK de SUITSME 0.13272 (`tools/apk_audit`, v1.1.0) e informe de
  viabilidad: Unity 6000.0.58f2 con IL2CPP; port directo no viable.
- Núcleo del juego: catálogo, armario permanente, economía local ilimitada, conjuntos, looks,
  borradores, historial, papelera, galería, desafíos con evaluación local transparente.
- Guardado atómico con SHA-256, copias rotativas, recuperación y migraciones.
- Eras de la Moda: 9 capítulos, 86 prendas, 40 fichas con 105 afirmaciones y 59 fuentes,
  30 desafíos, 10 escenarios y 5 poses.
- Presentación 3D procedural: maniquí articulado, prendas paramétricas, tejidos PBR, maquillaje.
- Interfaz completa navegable con mando, táctil, ratón y teclado; perfiles sobremesa y portátil.
- Herramientas: verificador de material propietario, verificador sin conexión, validador de datos,
  generador de documentación de épocas, capturas y medición de rendimiento.
- CI en GitHub Actions: datos, pruebas, integración con capturas, rendimiento y ejecutables.
- Documentación y tutorial en español.
