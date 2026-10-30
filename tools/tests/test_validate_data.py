# -*- coding: utf-8 -*-
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import validate_data  # noqa: E402

DATOS = Path(__file__).resolve().parents[2] / "game" / "data"


def test_datos_reales_validos():
    inf, stats = validate_data.validar(DATOS)
    assert inf.errores == []
    assert stats["eras"] == 9
    assert stats["prendas"] >= 80


def test_detecta_enlaces_rotos(tmp_path):
    copia = tmp_path / "data"
    shutil.copytree(DATOS, copia)
    ruta = copia / "prendas" / "anos20.json"
    doc = json.loads(ruta.read_text(encoding="utf-8"))
    doc["prendas"][0]["tipologias"] = ["ficha_que_no_existe"]
    doc["prendas"][1]["color"] = "rojo"
    ruta.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    enc = copia / "enciclopedia" / "anos20.json"
    edoc = json.loads(enc.read_text(encoding="utf-8"))
    edoc["entradas"][0]["hechos"].append({"texto": "Sin fuente", "estado": "verificado", "fuentes": []})
    enc.write_text(json.dumps(edoc, ensure_ascii=False), encoding="utf-8")
    inf, _ = validate_data.validar(copia)
    texto = "\n".join(inf.errores)
    assert "ficha inexistente ficha_que_no_existe" in texto
    assert "#RRGGBB" in texto
    assert "afirmación sin fuente" in texto
