# Estado verificado del proyecto

Regla: un requisito solo figura como **Hecho** si está implementado **y** tiene una prueba o una
verificación reproducible enlazada. Todo lo demás figura como *En curso*, *Pendiente* o *Bloqueado*.

| Hito | Requisito | Estado | Evidencia |
|---|---|---|---|
| 1 | Recepción del APK y SHA-256 | Bloqueado (red del entorno) | [Informe](01-informe-viabilidad-apk.md) |
| 1 | Herramienta de auditoría del APK | Hecho | `tools/tests/test_apk_audit.py` (12 pruebas) |
| 1 | Bloqueo de material propietario y credenciales | Hecho | `tools/tests/test_check_repo.py` (4 pruebas) |
| 1 | Informe de viabilidad | Preliminar | [Informe](01-informe-viabilidad-apk.md) |
| 2–8 | Juego original | En curso | — |
