#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
validate_data.py - Valida los datos del juego (game/data) sin necesidad de Godot.

Comprueba: JSON bien formado, índice completo, identificadores únicos y ASCII, campos obligatorios,
enlaces prenda -> ficha -> fuente, estados de verificación, eras, escenarios, tejidos y desafíos.

Uso: python tools/validate_data.py [CARPETA_DATOS]
Devuelve 0 si no hay errores (los avisos no bloquean).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ID = re.compile(r"^[a-z0-9_]+$")
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
CATEGORIAS = {"vestido", "parte_superior", "parte_inferior", "abrigo", "calzado", "tocado", "peinado", "maquillaje",
              "joyeria", "guantes", "bolso", "cinturon", "gafas", "complemento"}
TEMPORADAS = {"primavera", "verano", "otono", "invierno"}
TIPOS_PIEZA = {"interpretacion_de_epoca", "reproduccion_historica", "original_del_juego"}
ATRIBUCION = {"sin_atribucion", "documentada", "desconocida"}
ESTADOS = {"verificado", "discutido", "interpretacion"}
CAMPOS_AFIRMACION = ["hechos", "materiales", "tecnicas", "silueta", "uso", "influencia", "curiosidades"]
FAMILIAS = {"blanco", "negro", "gris", "beige", "marron", "rojo", "naranja", "amarillo", "verde", "azul", "morado",
            "rosa", "dorado", "plateado"}
TIPOS_DESAFIO = {"recreacion_historica", "creativo", "libre"}


class Informe:
    def __init__(self) -> None:
        self.errores: List[str] = []
        self.avisos: List[str] = []

    def error(self, msg: str) -> None:
        self.errores.append(msg)

    def aviso(self, msg: str) -> None:
        self.avisos.append(msg)


def cargar(ruta: Path, inf: Informe) -> dict:
    try:
        return json.loads(ruta.read_text(encoding="utf-8"))
    except FileNotFoundError:
        inf.error("%s: no existe" % ruta)
    except json.JSONDecodeError as exc:
        inf.error("%s: JSON no válido (línea %d): %s" % (ruta, exc.lineno, exc.msg))
    return {}


def validar(datos: Path) -> Tuple[Informe, Dict[str, int]]:
    inf = Informe()
    indice = cargar(datos / "indice.json", inf)
    if not indice:
        return inf, {}
    for clave in ("prendas", "enciclopedia"):
        listados = set(indice.get(clave, []))
        en_disco = {p.relative_to(datos).as_posix() for p in (datos / clave).glob("*.json")}
        en_disco.discard(indice.get("fuentes", "enciclopedia/fuentes.json"))
        for falta in sorted(en_disco - listados):
            inf.error("indice.json no incluye %s" % falta)
        for sobra in sorted(listados - en_disco):
            inf.error("indice.json cita un archivo inexistente: %s" % sobra)

    eras = {e["id"]: e for e in cargar(datos / indice.get("eras", "eras.json"), inf).get("eras", [])}
    tejidos = cargar(datos / indice.get("tejidos", "tejidos.json"), inf).get("tejidos", {})
    escenarios = {s["id"]: s for s in cargar(datos / indice.get("escenarios", "escenarios.json"), inf).get("escenarios", [])}
    for e in eras.values():
        if e.get("escenario") not in escenarios:
            inf.error("era %s: escenario desconocido %s" % (e["id"], e.get("escenario")))

    fuentes = {}
    for f in cargar(datos / indice.get("fuentes", "enciclopedia/fuentes.json"), inf).get("fuentes", []):
        if not ID.match(str(f.get("id", ""))):
            inf.error("fuente con id no válido: %r" % f.get("id"))
        if f.get("id") in fuentes:
            inf.error("fuente duplicada: %s" % f.get("id"))
        if f.get("url") and not str(f["url"]).startswith("https://"):
            inf.error("fuente %s: la URL debe usar https" % f.get("id"))
        fuentes[f.get("id")] = f

    fichas: Dict[str, dict] = {}
    citadas = set()
    for rel in indice.get("enciclopedia", []):
        for e in cargar(datos / rel, inf).get("entradas", []):
            fid = str(e.get("id", ""))
            if not ID.match(fid):
                inf.error("%s: ficha con id no válido %r" % (rel, fid))
            if fid in fichas:
                inf.error("%s: ficha duplicada %s" % (rel, fid))
            fichas[fid] = e
            if e.get("era") not in eras:
                inf.error("ficha %s: era desconocida %s" % (fid, e.get("era")))
            if not isinstance(e.get("revision_humana"), bool):
                inf.error("ficha %s: falta revision_humana" % fid)
            if not e.get("hechos"):
                inf.error("ficha %s: sin hechos" % fid)
            for campo in CAMPOS_AFIRMACION:
                for a in e.get(campo, []):
                    estado = a.get("estado")
                    if estado not in ESTADOS:
                        inf.error("ficha %s/%s: estado no válido %r" % (fid, campo, estado))
                    refs = a.get("fuentes", [])
                    if estado != "interpretacion" and not refs:
                        inf.error("ficha %s/%s: afirmación sin fuente: %s" % (fid, campo, a.get("texto", "")[:60]))
                    for r in refs:
                        citadas.add(r)
                        if r not in fuentes:
                            inf.error("ficha %s: fuente inexistente %s" % (fid, r))
            for pieza in e.get("piezas_referencia", []):
                for r in pieza.get("fuentes", []):
                    citadas.add(r)
                    if r not in fuentes:
                        inf.error("ficha %s: pieza con fuente inexistente %s" % (fid, r))
    for sin_uso in sorted(set(fuentes) - citadas):
        inf.aviso("fuente sin citar: %s" % sin_uso)

    prendas: Dict[str, dict] = {}
    for rel in indice.get("prendas", []):
        for p in cargar(datos / rel, inf).get("prendas", []):
            pid = str(p.get("id", ""))
            if not ID.match(pid):
                inf.error("%s: prenda con id no válido %r" % (rel, pid))
            if pid in prendas:
                inf.error("prenda duplicada: %s" % pid)
            prendas[pid] = p
            if p.get("categoria") not in CATEGORIAS:
                inf.error("prenda %s: categoría desconocida %s" % (pid, p.get("categoria")))
            if p.get("era") not in eras:
                inf.error("prenda %s: era desconocida %s" % (pid, p.get("era")))
            if p.get("tejido") not in tejidos:
                inf.error("prenda %s: tejido desconocido %s" % (pid, p.get("tejido")))
            for c in ("color", "color_secundario"):
                if c in p and not HEX.match(str(p[c])):
                    inf.error("prenda %s: %s debe ser #RRGGBB" % (pid, c))
            if not p.get("estilos"):
                inf.error("prenda %s: sin estilos" % pid)
            if not set(p.get("temporadas", [])) or not set(p.get("temporadas", [])) <= TEMPORADAS:
                inf.error("prenda %s: temporadas no válidas" % pid)
            precio = p.get("precio", {})
            if precio.get("moneda") not in ("monedas", "gemas") or not isinstance(precio.get("valor"), (int, float)) \
                    or precio.get("valor", -1) < 0:
                inf.error("prenda %s: precio no válido" % pid)
            if not p.get("tipologias"):
                inf.error("prenda %s: no enlaza ninguna ficha" % pid)
            for t in p.get("tipologias", []):
                if t not in fichas:
                    inf.error("prenda %s: ficha inexistente %s" % (pid, t))
            ficha = p.get("ficha", {})
            for k in ("descripcion", "materiales_modelo", "silueta", "uso"):
                if not str(ficha.get(k, "")).strip():
                    inf.error("prenda %s: ficha sin %s" % (pid, k))
            if ficha.get("tipo_pieza") not in TIPOS_PIEZA:
                inf.error("prenda %s: tipo_pieza no válido" % pid)
            atr = ficha.get("atribucion", {})
            if atr.get("estado") not in ATRIBUCION:
                inf.error("prenda %s: atribución no válida" % pid)
            if atr.get("estado") == "documentada" and not atr.get("fuentes"):
                inf.error("prenda %s: atribución documentada sin fuentes" % pid)
            modelo = p.get("modelo", {})
            if not modelo.get("generador") or not isinstance(modelo.get("params"), dict):
                inf.error("prenda %s: modelo incompleto" % pid)

    desafios = cargar(datos / indice.get("desafios", "desafios.json"), inf).get("desafios", [])
    ids_d = set()
    for d in desafios:
        did = str(d.get("id", ""))
        if did in ids_d:
            inf.error("desafío duplicado: %s" % did)
        ids_d.add(did)
        if d.get("tipo") not in TIPOS_DESAFIO:
            inf.error("desafío %s: tipo no válido" % did)
        if d.get("era") not in eras:
            inf.error("desafío %s: era desconocida" % did)
        if d.get("escenario") not in escenarios:
            inf.error("desafío %s: escenario desconocido" % did)
        for e in d.get("eras_validas", []):
            if e not in eras:
                inf.error("desafío %s: era válida desconocida %s" % (did, e))
        req = d.get("requisitos", {})
        for k in ("obligatorias", "sugeridas"):
            for c in req.get(k, []):
                if c != "prenda_principal" and c not in CATEGORIAS:
                    inf.error("desafío %s: categoría desconocida %s" % (did, c))
        prohib = req.get("prohibidos", {})
        for t in prohib.get("tejidos", []):
            if t not in tejidos:
                inf.error("desafío %s: tejido prohibido desconocido %s" % (did, t))
        for c in prohib.get("colores", []):
            if c not in FAMILIAS:
                inf.error("desafío %s: familia de color desconocida %s" % (did, c))
        for h in d.get("paleta", []):
            if not HEX.match(str(h)):
                inf.error("desafío %s: color de paleta no válido %s" % (did, h))

    for e in eras:
        n = sum(1 for p in prendas.values() if p.get("era") == e)
        if n < 8:
            inf.aviso("era %s: solo %d prendas" % (e, n))
    stats = {"eras": len(eras), "prendas": len(prendas), "fichas": len(fichas), "fuentes": len(fuentes),
             "desafios": len(desafios), "escenarios": len(escenarios),
             "fichas_revisadas": sum(1 for f in fichas.values() if f.get("revision_humana"))}
    return inf, stats


def main(argv: Optional[List[str]] = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    argv = sys.argv[1:] if argv is None else argv
    datos = Path(argv[0]) if argv else Path(__file__).resolve().parents[1] / "game" / "data"
    inf, stats = validar(datos)
    for a in inf.avisos:
        print("aviso: " + a)
    for e in inf.errores:
        print("ERROR: " + e)
    print("Datos: " + ", ".join("%s=%d" % kv for kv in stats.items()))
    if inf.errores:
        print("%d error(es)." % len(inf.errores))
        return 1
    print("Datos válidos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
