#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verificar_nro.py - Comprueba la estructura de un NRO de homebrew para Nintendo Switch.

Lee el NRO sin ejecutarlo y verifica:
    * la cabecera NRO0 y los tres segmentos (text, ro, data)
    * la sección de recursos ASET: icono JPEG de 256x256, metadatos NACP y romfs
    * en la romfs, game.pck (paquete de Godot, firma GDPC) y app.id (carpeta de la SD)
    * opcionalmente, que game.pck sea idéntico al .pck exportado (--pck)

Uso: python tools/verificar_nro.py JUEGO.nro [--pck game.pck] [--titulo T] [--carpeta C] [--json]
Devuelve 0 si el NRO es correcto y 1 si encuentra algún problema.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

NRO_HEADER = 0x10
ICONO_LADO = 256
NACP_TAMANO = 0x4000
NACP_IDIOMAS = 16
NACP_VERSION = 0x3060


def _cadena(datos: bytes) -> str:
    return datos.split(b"\0", 1)[0].decode("utf-8", errors="replace")


def dimensiones_jpeg(datos: bytes) -> Optional[Tuple[int, int]]:
    """Ancho y alto de un JPEG, leídos del marcador SOF. None si no es un JPEG válido."""
    if not datos.startswith(b"\xff\xd8"):
        return None
    i = 2
    while i + 4 <= len(datos):
        if datos[i] != 0xFF:
            return None
        marcador = datos[i + 1]
        if marcador == 0xFF:
            i += 1
            continue
        if marcador in (0xD8, 0x01) or 0xD0 <= marcador <= 0xD7:
            i += 2
            continue
        (longitud,) = struct.unpack(">H", datos[i + 2:i + 4])
        if marcador in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            if i + 9 > len(datos):
                return None
            alto, ancho = struct.unpack(">HH", datos[i + 5:i + 9])
            return ancho, alto
        if marcador == 0xDA:
            return None
        i += 2 + longitud
    return None


def archivos_romfs(romfs: bytes) -> Dict[str, bytes]:
    """Archivos de la romfs (formato de libnx), con su ruta completa."""
    if len(romfs) < 0x50:
        raise ValueError("romfs demasiado pequeña")
    campos = struct.unpack("<10Q", romfs[:0x50])
    if campos[0] != 0x50:
        raise ValueError("cabecera de romfs desconocida (tamaño %d)" % campos[0])
    tabla_dir, tam_dir = campos[3], campos[4]
    tabla_arch, tam_arch, datos_off = campos[7], campos[8], campos[9]

    def nombre_dir(desp: int) -> str:
        partes: List[str] = []
        while desp != 0:
            padre, _, _, _, _, largo = struct.unpack("<6I", romfs[tabla_dir + desp:tabla_dir + desp + 24])
            partes.append(romfs[tabla_dir + desp + 24:tabla_dir + desp + 24 + largo].decode("utf-8"))
            desp = padre
        return "/".join(reversed(partes))

    if tabla_dir + tam_dir > len(romfs) or tabla_arch + tam_arch > len(romfs):
        raise ValueError("tablas de la romfs fuera de rango")
    archivos: Dict[str, bytes] = {}
    desp = 0
    while desp + 32 <= tam_arch:
        base = tabla_arch + desp
        padre, _, d_off, d_tam, _, largo = struct.unpack("<IIQQII", romfs[base:base + 32])
        nombre = romfs[base + 32:base + 32 + largo].decode("utf-8")
        carpeta = nombre_dir(padre)
        inicio = datos_off + d_off
        if inicio + d_tam > len(romfs):
            raise ValueError("datos de %s fuera de la romfs" % nombre)
        archivos[(carpeta + "/" if carpeta else "") + nombre] = romfs[inicio:inicio + d_tam]
        desp += 32 + ((largo + 3) & ~3)
    return archivos


def analizar(datos: bytes) -> dict:
    """Desglosa el NRO. Lanza ValueError si la estructura no es válida."""
    if len(datos) < 0x80 or datos[NRO_HEADER:NRO_HEADER + 4] != b"NRO0":
        raise ValueError("no es un NRO (falta la firma NRO0)")
    (tam_nro,) = struct.unpack("<I", datos[NRO_HEADER + 8:NRO_HEADER + 12])
    segmentos = [struct.unpack("<II", datos[0x20 + 8 * k:0x28 + 8 * k]) for k in range(3)]
    if tam_nro > len(datos):
        raise ValueError("el NRO declara %d bytes y el archivo tiene %d" % (tam_nro, len(datos)))
    for nombre, (off, tam) in zip(("text", "ro", "data"), segmentos):
        if tam == 0 or off + tam > tam_nro:
            raise ValueError("segmento %s fuera de rango" % nombre)
    aset = datos[tam_nro:]
    if len(aset) < 0x38 or aset[:4] != b"ASET":
        raise ValueError("falta la sección de recursos ASET")
    secciones = {}
    for k, nombre in enumerate(("icono", "nacp", "romfs")):
        off, tam = struct.unpack("<QQ", aset[8 + 16 * k:24 + 16 * k])
        if off + tam > len(aset):
            raise ValueError("sección %s fuera de rango" % nombre)
        secciones[nombre] = aset[off:off + tam]
    nacp = secciones["nacp"]
    if len(nacp) != NACP_TAMANO:
        raise ValueError("NACP de %d bytes (se esperaban %d)" % (len(nacp), NACP_TAMANO))
    return {
        "tamano_nro": tam_nro,
        "segmentos": {n: {"desplazamiento": o, "tamano": t} for n, (o, t) in zip(("text", "ro", "data"), segmentos)},
        "icono": secciones["icono"],
        "titulo": _cadena(nacp[0:0x200]),
        "autor": _cadena(nacp[0x200:0x300]),
        "titulos": [_cadena(nacp[i * 0x300:i * 0x300 + 0x200]) for i in range(NACP_IDIOMAS)],
        "version": _cadena(nacp[NACP_VERSION:NACP_VERSION + 0x10]),
        "romfs": archivos_romfs(secciones["romfs"]) if secciones["romfs"] else {},
    }


def verificar(ruta: Path, pck: Optional[Path] = None, titulo: Optional[str] = None,
              carpeta: Optional[str] = None) -> Tuple[List[str], dict]:
    """Devuelve (problemas, resumen)."""
    datos = ruta.read_bytes()
    try:
        nro = analizar(datos)
    except (ValueError, struct.error, UnicodeDecodeError) as e:
        return ["estructura: %s" % e], {"archivo": ruta.name, "tamano": len(datos)}
    problemas: List[str] = []
    dims = dimensiones_jpeg(nro["icono"])
    if dims is None:
        problemas.append("el icono no es un JPEG válido")
    elif dims != (ICONO_LADO, ICONO_LADO):
        problemas.append("el icono mide %dx%d (debe ser %dx%d)" % (dims + (ICONO_LADO, ICONO_LADO)))
    if not nro["titulo"]:
        problemas.append("el NACP no tiene título")
    if titulo is not None and nro["titulo"] != titulo:
        problemas.append("título '%s' (se esperaba '%s')" % (nro["titulo"], titulo))
    if not nro["version"]:
        problemas.append("el NACP no tiene versión")
    archivos = nro["romfs"]
    juego = archivos.get("game.pck")
    if juego is None:
        problemas.append("la romfs no contiene game.pck")
    elif not juego.startswith(b"GDPC"):
        problemas.append("game.pck no es un paquete de Godot (falta la firma GDPC)")
    elif pck is not None and hashlib.sha256(juego).digest() != hashlib.sha256(pck.read_bytes()).digest():
        problemas.append("game.pck no coincide con %s" % pck.name)
    app_id = archivos.get("app.id", b"").decode("utf-8", errors="replace").strip()
    if not app_id:
        problemas.append("la romfs no contiene app.id (carpeta de la SD)")
    elif carpeta is not None and app_id != carpeta:
        problemas.append("app.id es '%s' (se esperaba '%s')" % (app_id, carpeta))
    resumen = {
        "archivo": ruta.name,
        "tamano": len(datos),
        "sha256": hashlib.sha256(datos).hexdigest(),
        "titulo": nro["titulo"],
        "autor": nro["autor"],
        "version": nro["version"],
        "icono": "%dx%d JPEG" % dims if dims else "no válido",
        "carpeta_sd": "sdmc:/switch/%s/" % app_id if app_id else "",
        "romfs": {n: len(c) for n, c in sorted(archivos.items())},
        "game_pck_sha256": hashlib.sha256(juego).hexdigest() if juego else "",
    }
    return problemas, resumen


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Comprueba la estructura de un NRO de homebrew para Switch.")
    ap.add_argument("nro", type=Path)
    ap.add_argument("--pck", type=Path, help="paquete exportado que debe estar dentro del NRO")
    ap.add_argument("--titulo", help="título esperado en el NACP")
    ap.add_argument("--carpeta", help="carpeta de la SD esperada en app.id")
    ap.add_argument("--json", action="store_true", help="imprime el resumen en JSON")
    args = ap.parse_args(argv)
    problemas, resumen = verificar(args.nro, args.pck, args.titulo, args.carpeta)
    if args.json:
        print(json.dumps({"problemas": problemas, "resumen": resumen}, ensure_ascii=False, indent=2))
    else:
        for clave, valor in resumen.items():
            print("%-16s %s" % (clave + ":", valor))
        for p in problemas:
            print("PROBLEMA: " + p)
        print("NRO correcto" if not problemas else "%d problema(s)" % len(problemas))
    return 1 if problemas else 0


if __name__ == "__main__":
    sys.exit(main())
