#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_docs_eras.py - Genera docs/eras/*.md a partir de game/data (eras, fichas, prendas, desafíos).

Uso:
    python tools/gen_docs_eras.py             # regenera los documentos
    python tools/gen_docs_eras.py --comprobar # falla si los documentos no están al día (CI)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Dict, List

RAIZ = Path(__file__).resolve().parents[1]
DATOS = RAIZ / "game" / "data"
SALIDA = RAIZ / "docs" / "eras"
ESTADOS = {"verificado": "✔ verificado", "discutido": "⚠ discutido", "interpretacion": "◇ interpretación"}
CAMPOS = [("hechos", "Hechos"), ("materiales", "Materiales"), ("tecnicas", "Técnicas"), ("silueta", "Silueta"),
          ("uso", "Uso"), ("influencia", "Influencia"), ("curiosidades", "Curiosidades")]
TIPOS = {"recreacion_historica": "Recreación histórica", "creativo": "Creativo", "libre": "Libre"}


def leer(rel: str) -> dict:
    return json.loads((DATOS / rel).read_text(encoding="utf-8"))


def generar() -> Dict[str, str]:
    indice = leer("indice.json")
    eras = leer(indice["eras"])["eras"]
    fuentes = {f["id"]: f for f in leer(indice["fuentes"])["fuentes"]}
    escenarios = {s["id"]: s for s in leer(indice["escenarios"])["escenarios"]}
    desafios = leer(indice["desafios"])["desafios"]
    docs: Dict[str, str] = {}
    resumen: List[str] = ["# Eras de la Moda", "",
                          "Documentación generada automáticamente desde `game/data` con `tools/gen_docs_eras.py`. "
                          "No se edita a mano: se modifican los datos y se regenera.", "",
                          "Leyenda de estados: ✔ verificado en las fuentes citadas · ⚠ dato discutido entre fuentes · "
                          "◇ interpretación (no es un hecho documentado).", "",
                          "| Capítulo | Periodo | Prendas | Fichas | Desafíos |", "|---|---|---|---|---|"]
    for era in eras:
        eid = era["id"]
        fichas = leer("enciclopedia/%s.json" % eid)["entradas"]
        prendas = leer("prendas/%s.json" % eid)["prendas"]
        retos = [d for d in desafios if d["era"] == eid and d["tipo"] != "libre"]
        nombre = "%02d-%s.md" % (era["orden"], eid)
        resumen.append("| [%s](%s) | %s | %d | %d | %d |" % (era["titulo"], nombre, era["periodo"], len(prendas),
                                                         len(fichas), len(retos)))
        l: List[str] = ["# Capítulo %d — %s (%s)" % (era["orden"], era["titulo"], era["periodo"]), "",
                        era["resumen"], "", "## Etapas", ""]
        for s in era.get("subperiodos", []):
            l.append("- **%s:** %s" % (s["nombre"], s["descripcion"]))
        esc = escenarios.get(era["escenario"], {})
        l += ["", "## Escenario", "", "**%s.** %s" % (esc.get("nombre", ""), esc.get("descripcion", "")), "",
              "## Fichas de la enciclopedia", ""]
        citadas: List[str] = []
        for f in fichas:
            l += ["### %s" % f["nombre"], "", "*%s · %s.* %s" % (f["periodo"], f["region"], f["resumen"]), ""]
            for campo, titulo in CAMPOS:
                for a in f.get(campo, []):
                    refs = []
                    for r in a.get("fuentes", []):
                        if r not in citadas:
                            citadas.append(r)
                        refs.append("[%d]" % (citadas.index(r) + 1))
                    l.append("- %s · **%s:** %s %s" % (ESTADOS[a["estado"]], titulo, a["texto"], " ".join(refs)))
            if f.get("nota_fuentes"):
                l += ["", "> Nota sobre las fuentes: %s" % f["nota_fuentes"]]
            for pz in f.get("piezas_referencia", []):
                l += ["", "Pieza de referencia: [%s](%s)" % (pz["titulo"], pz.get("url", ""))]
            l += ["", "Revisión humana: %s" % ("sí" if f.get("revision_humana") else "pendiente"), ""]
        l += ["## Prendas del vestidor", "",
              "Todas son diseños originales del juego inspirados en la época; ninguna reproduce una pieza documentada.", "",
              "| Prenda | Categoría | Tejido | Fichas | Influencias |", "|---|---|---|---|---|"]
        for p in prendas:
            l.append("| %s | %s | %s | %s | %s |" % (p["nombre"], p["categoria"].replace("_", " "), p["tejido"],
                                                   ", ".join(p["tipologias"]), ", ".join(p.get("influencias", [])) or "—"))
        l += ["", "## Desafíos", ""]
        for d in retos:
            l.append("- **%s** (%s): %s" % (d["titulo"], TIPOS[d["tipo"]], d["descripcion"]))
        l += ["", "## Fuentes", ""]
        for k, r in enumerate(citadas, 1):
            f = fuentes[r]
            l.append("%d. %s. *%s*. <%s> (consultado el %s mediante %s)." % (
                k, f["autor"], f["titulo"], f.get("url", ""), f["consultado"], f["metodo"].replace("_", " ")))
        docs[nombre] = "\n".join(l) + "\n"
    libres = [d for d in desafios if d["tipo"] == "libre"]
    resumen += ["", "## Desafíos libres", ""] + ["- **%s:** %s" % (d["titulo"], d["descripcion"]) for d in libres]
    docs["README.md"] = "\n".join(resumen) + "\n"
    return docs


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    docs = generar()
    if "--comprobar" in sys.argv:
        desfasados = [n for n, t in docs.items() if not (SALIDA / n).exists() or (SALIDA / n).read_text(encoding="utf-8") != t]
        if desfasados:
            print("Documentos desactualizados (ejecuta tools/gen_docs_eras.py): " + ", ".join(desfasados))
            return 1
        print("docs/eras está al día.")
        return 0
    SALIDA.mkdir(parents=True, exist_ok=True)
    for n, t in docs.items():
        (SALIDA / n).write_text(t, encoding="utf-8")
    print("Generados %d documentos en %s" % (len(docs), SALIDA))
    return 0


if __name__ == "__main__":
    sys.exit(main())
