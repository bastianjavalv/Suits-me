# Estado verificado del proyecto

Regla: un requisito figura como **Hecho** solo si está implementado **y** tiene una prueba o una
verificación reproducible. Lo demás figura como *Parcial*, *Pendiente* o *Requisito externo*.

| Hito | Requisito | Estado | Evidencia |
|---|---|---|---|
| 1 | APK recibido, íntegro y con SHA-256 | Hecho (auditado en la PC del propietario) | [Informe](01-informe-viabilidad-apk.md), [anexo](apk/informe_apk.md) |
| 1 | Motor, arquitectura, SDK, recursos y viabilidad | Hecho | Unity 6000.0.58f2, IL2CPP, APK base dividido; port directo no viable |
| 2 | Estrategia técnica y motor justificado | Hecho | [02](02-estrategia-tecnica.md) |
| 2 | Reutilizar código o recursos del original | No aplicable | Sin proyecto fuente ni licencia de Zirafit |
| 3 | Maniquí, armario, prendas, accesorios, mecánicas | Hecho | 58 pruebas del juego, recorrido de integración |
| 3 | Realismo de personajes y prendas de nivel comercial | Parcial | Arte procedural PBR; producción en [08](08-pipeline-de-arte.md) |
| 4 | Guardado, inventario, progresión, sin conexión | Hecho | `test_library_save.gd`, `test_game_state.gd`, `check_offline.py` |
| 4 | Monedas y gemas ilimitadas persistentes | Hecho | `test_economy_inventory.gd`, recorrido |
| 5 | Ficha individual por prenda, enlazada por identificador | Hecho | `test_cada_prenda_tiene_historia_con_fuentes` |
| 5 | Fuentes verificables y estados de verificación | Hecho | 105 afirmaciones, 59 fuentes, `validate_data.py` |
| 5 | Revisión humana de las fichas | Pendiente | `revision_humana: false` en las 40 fichas |
| 5 | Eras de la Moda: 9 capítulos con prendas, escenarios, desafíos y documentación | Hecho | `test_contenido_real.gd`, [docs/eras](eras/README.md) |
| 6 | Mapa Joy-Con / Pro Controller, táctil, detección de mandos | Hecho (en PC) | `test_platform.gd` |
| 6 | Perfiles sobremesa 1920×1080 y portátil 1280×720 | Hecho (en PC) | Recorrido en ambos perfiles, capturas |
| 6 | 60 FPS en Switch | Sin medir | Requiere kit de desarrollo; medición de referencia en [07](07-pruebas-y-calidad.md) |
| 7 | Pruebas, correcciones, mediciones, validación gráfica | Hecho | [07](07-pruebas-y-calidad.md), `docs/capturas/` |
| 8 | Compilación verificable de escritorio (Linux y Windows) | Hecho (Linux probado; Windows generado) | CI «Compilación de escritorio» |
| 8 | Compilación oficial para Nintendo Switch (eShop o cartucho) | Requisito externo | Nintendo Developer Portal y port de consola ([06](06-nintendo-switch.md)) |
| 8 | NRO homebrew para Switch con CFW | Hecho (compilado y verificado en CI) | Job «NRO para Switch», `tools/verificar_nro.py`, [switch/LEEME.md](../switch/LEEME.md) |
| 8 | El juego con el renderizador y el texto del NRO (GLES3, Fallback) | Hecho (en PC) | Recorrido de integración con GLES3 en la CI |
| 8 | NRO: 1920×1080 en la base, 1280×720 portátil, cambio en caliente | Hecho en código (compila; sin probar en consola) | Cambios propios en [switch/LEEME.md](../switch/LEEME.md) |
| 8 | Pantalla «Preparando gráficos…» con precompilación de sombreadores | Hecho (GLES3 en PC y CI) | Recorrido de integración con GLES3, captura `00_preparando_graficos` |
| 8 | NRO probado en una consola real | Pendiente | Requiere tu consola: [TUTORIAL, 10.1](TUTORIAL.md#101-switch-con-cfw-nro-homebrew) |
| 8 | Documentación y tutorial en español | Hecho | [TUTORIAL](TUTORIAL.md) |
