# Hito 2 — Estrategia técnica

## 1. Por qué no se reutiliza el motor original

El análisis del APK ([01-informe-viabilidad-apk.md](01-informe-viabilidad-apk.md)) mostró que SUITSME
usa Unity 6 con IL2CPP: no hay proyecto ni código fuente que portar, y sus recursos pertenecen a
Zirafit Limited. Elegir Unity para un juego **nuevo** no aportaría compatibilidad con el original.
El motor se eligió, por tanto, con criterios propios del proyecto.

## 2. Motor elegido: Godot 4.7.2

| Criterio | Godot 4.7.2 | Unity 6 |
|---|---|---|
| Licencia | MIT: sin costes ni activación | Licencia por puestos; requiere activación en CI |
| Pruebas automáticas | Se ejecuta sin ventana en GitHub Actions y en este entorno | Requiere licencia y Unity Hub en CI |
| Consola | Plataformas de consola mediante socios con acuerdos con Nintendo (por ejemplo, W4 Games) para desarrolladores autorizados | Módulo de Switch para desarrolladores autorizados |
| Renderizador | «Mobile» (Vulkan) pensado para GPU modestas | URP |
| Peso del proyecto | Texto plano versionable (escenas, scripts, datos) | Binarios y metadatos de editor |

Decisión: **Godot 4.7.2**, renderizador *Mobile*, GDScript con tipado estático. Ambos motores
exigen la autorización de Nintendo para compilar en Switch; las condiciones de los socios de
consola deben consultarse en el momento de solicitarlas (no se han verificado en este proyecto).

Versión fijada en el proyecto y en CI: `4.7.2-stable`, con verificación SHA-512 de los binarios
oficiales.

## 3. Arquitectura por sistemas

```text
game/
├── data/                 Contenido editable (JSON): eras, prendas, enciclopedia, fuentes,
│                         desafíos, escenarios, poses, tejidos, economía, calidad
├── src/core/             Lógica pura y comprobable (sin nodos 3D)
│   ├── catalog.gd            Catálogo de prendas validado e indexado
│   ├── inventory.gd          Armario permanente, favoritas, huérfanas
│   ├── economy.gd            Monedas y gemas ilimitadas persistentes
│   ├── outfit.gd             Conjunto actual (reglas de ranuras)
│   ├── outfit_library.gd     Looks, borradores, historial y papelera
│   ├── save_system.gd        Guardado atómico, SHA-256, copias y migraciones
│   ├── challenge_book.gd     Desafíos y progreso
│   ├── evaluator.gd          Evaluación local transparente
│   ├── color_tools.gd        Familias de color y armonía cromática
│   ├── encyclopedia.gd       Fichas, fuentes y estados de verificación
│   ├── wardrobe_filter.gd    Búsqueda y filtros del armario
│   ├── gallery.gd            Fotografías locales
│   └── game_state.gd         Autoload «Game»: une todo y autoguarda
├── src/render/           Presentación 3D procedural
│   ├── mannequin.gd          Maniquí articulado (personaje)
│   ├── garment_builder.gd    Prendas: corpiños, faldas, mangas, pantalones, abrigos, capas
│   ├── accessory_builder.gd  Calzado, tocados, peinados, joyería, bolsos, gafas…
│   ├── fabric_library.gd     Materiales PBR por tejido
│   ├── outfit_view.gd        Monta el conjunto, oculta capas tapadas, vaivén de faldas
│   ├── stage_builder.gd      Escenarios por época e iluminación de estudio
│   ├── camera_rig.gd         Zoom e inspección
│   └── mesh_kit.gd           Mallas de revolución con normales y tangentes analíticas
├── src/platform/         Consola y entrada
│   ├── platform_bridge.gd    Autoload «Platform»: modo sobremesa/portátil, guardado de consola
│   ├── controls.gd           Autoload «Controls»: mandos, modo de entrada, reasignación
│   ├── input_bindings.gd     Mapa Joy-Con / Pro Controller por letra de botón
│   ├── gesture_recognizer.gd Gestos táctiles
│   ├── quality_profiles.gd   Perfiles gráficos
│   ├── dynamic_resolution.gd Escalado dinámico de la resolución 3D
│   └── perf_probe.gd         Medición de cuadros por segundo
├── src/ui/               Pantallas (menú, eras, vestidor, ficha, desafíos, looks, galería…)
├── shaders/              Tejidos (opacos y calados), maniquí con maquillaje, suelos
└── tests/                Pruebas unitarias e integración
```

Los sistemas pedidos en el encargo quedan separados así: **personajes** (`mannequin.gd`),
**vestuario** (`garment_builder.gd`, `accessory_builder.gd`, `fabric_library.gd`, `outfit_view.gd`),
**inventario** (`inventory.gd`), **economía** (`economy.gd`), **desafíos** (`challenge_book.gd`,
`evaluator.gd`), **enciclopedia** (`encyclopedia.gd`), **guardado** (`save_system.gd`),
**interfaz** (`src/ui`), **controles** (`input_bindings.gd`, `controls.gd`,
`gesture_recognizer.gd`) y **configuración gráfica** (`quality_profiles.gd`,
`dynamic_resolution.gd`).

## 4. Funcionamiento sin conexión

- El juego no contiene ninguna llamada de red: `tools/check_offline.py` lo comprueba en cada
  cambio (prohíbe `HTTPRequest`, sockets, WebSocket, multijugador, apertura de URLs y extensiones
  nativas).
- No hay cuentas, anuncios, analítica, notificaciones ni compras reales.
- Todo el contenido (prendas, fichas, fuentes, escenarios) viaja dentro del juego.

## 5. Arte procedural: qué es y qué no es

El maniquí, las prendas y los escenarios se generan por código a partir de parámetros. Esto permite
tener las 86 prendas jugables, con tejidos PBR diferenciados, costuras, pliegues y caída, sin
recursos de terceros. **No sustituye** a un equipo de arte: para un realismo de nivel comercial
(cuerpos escaneados, prendas simuladas con software de patronaje, texturas fotográficas) el
proyecto define un circuito de producción en [08-pipeline-de-arte.md](08-pipeline-de-arte.md).
