# Estado verificado del proyecto

Regla: un requisito solo figura como **Hecho** si está implementado **y** tiene una prueba o una
verificación reproducible enlazada. Todo lo demás figura como *En curso*, *Pendiente* o *Bloqueado*.

| Hito | Requisito | Estado | Evidencia |
|---|---|---|---|
| 1 | Recepción del APK y SHA-256 | Hecho (en la PC del propietario) | [Informe](01-informe-viabilidad-apk.md), [anexo](apk/informe_apk.md) |
| 1 | Motor, arquitectura, SDK y recursos | Hecho | Unity 6000.0.58f2, IL2CPP, APK base dividido |
| 1 | Herramienta de auditoría del APK | Hecho | `tools/tests/test_apk_audit.py` |
| 1 | Bloqueo de material propietario y credenciales | Hecho | `tools/tests/test_check_repo.py` |
| 1 | Informe de viabilidad | Hecho | Veredicto: port directo no viable desde el APK |
| 2 | Estrategia técnica del juego original | En curso | — |
| 3 | Sistemas de juego (armario, conjuntos, desafíos) | Hecho (núcleo) | `game/tests/unit/*` (46 pruebas) |
| 4 | Sin conexión, guardado, monedas y gemas ilimitadas | Hecho (núcleo) | `test_game_state.gd`, `test_library_save.gd`, `tools/check_offline.py` |
| 5 | Enciclopedia: motor y validación | Hecho | `test_evaluation.gd` (fuentes por afirmación) |
| 5 | Enciclopedia: contenido de los 9 capítulos | Pendiente | — |
| 6 | Controles Switch, táctil, perfiles sobremesa/portátil | Hecho (lógica) | `test_platform.gd` |
| 6 | Presentación 3D e interfaz | En curso | — |
| 7 | Mediciones de rendimiento | Pendiente | — |
| 8 | Compilación, documentación y tutorial | Pendiente | — |
