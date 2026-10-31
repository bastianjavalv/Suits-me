#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Convierte los rendimiento_*.json de tools/capturas_rendimiento.gd en una tabla Markdown."""
import json
import sys
from pathlib import Path


def main() -> int:
    carpeta = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    filas = []
    for ruta in sorted(carpeta.glob("rendimiento_*.json")):
        d = json.loads(ruta.read_text(encoding="utf-8"))
        filas.append("| %s | %dx%d | %s | %.1f | %.1f | %.1f | %d | %d | %d |" % (
            d["modo"], d["resolucion"][0], d["resolucion"][1], d["adaptador"], d["fps_medio"], d["ms_p95"],
            d["fps_1pct_bajo"], d["llamadas_dibujo_max"], d["primitivas_max"], d["escena"]["triangulos"]))
    print("### Medición de rendimiento (referencia)")
    print()
    print("| Perfil | Resolución | Adaptador | FPS medio | ms p95 | FPS 1 %% bajo | Llamadas de dibujo | Primitivas | Triángulos del conjunto |")
    print("|---|---|---|---|---|---|---|---|---|")
    print("\n".join(filas) if filas else "| — | — | — | — | — | — | — | — | — |")
    print()
    print("> Sin GPU, el renderizado por software no representa el rendimiento en Nintendo Switch. "
          "Las métricas de geometría (llamadas de dibujo, primitivas, triángulos) sí son independientes del equipo.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
