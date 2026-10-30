# Atelier de las Eras (título provisional)

Juego **original** de moda e historia del vestido, diseñado para Nintendo Switch (modos sobremesa y
portátil) y desarrollado con Godot 4.

> **Aviso importante.** Este repositorio no contiene código, arte, personajes, interfaz ni ningún otro
> recurso de *SUITSME* ni de Zirafit Limited, y no está afiliado a ellos. Un port de SUITSME solo puede
> hacerlo el titular de sus derechos (o alguien con su licencia) desde el proyecto fuente original; ver
> [`docs/01-informe-viabilidad-apk.md`](docs/01-informe-viabilidad-apk.md). El nombre del repositorio
> es histórico; se recomienda renombrarlo para evitar confusiones con la marca.

## Estado

Proyecto en construcción. El estado verificado de cada requisito se mantiene en
[`docs/00-estado.md`](docs/00-estado.md).

## Herramientas disponibles ahora

- [`tools/apk_audit/`](tools/apk_audit/LEEME.md): auditoría de solo lectura de un APK (SHA-256,
  manifiesto, motor, SDK, viabilidad). Se puede ejecutar en cualquier PC con Python 3.
- [`tools/check_repo.py`](tools/check_repo.py): bloquea APK, binarios propietarios y credenciales.

## Pruebas

```bash
python3 -m pip install pytest
python3 -m pytest tools/tests -q
```
