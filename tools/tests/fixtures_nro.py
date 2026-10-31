# -*- coding: utf-8 -*-
"""NRO sintéticos para las pruebas de verificar_nro.py (sin código ni datos de consola reales)."""
from __future__ import annotations

import struct
from typing import Dict

NACP_TAMANO = 0x4000


def jpeg(ancho: int, alto: int) -> bytes:
    """Cabecera JPEG mínima (SOI, APP0, SOF0, EOI): basta para leer sus dimensiones."""
    app0 = b"JFIF\0" + b"\x01\x01" + b"\x00" + b"\x00\x01" + b"\x00\x01" + b"\x00\x00"
    sof = struct.pack(">BHHB", 8, alto, ancho, 1) + bytes([1, 0x11, 0])
    return (b"\xff\xd8" + b"\xff\xe0" + struct.pack(">H", len(app0) + 2) + app0
            + b"\xff\xc0" + struct.pack(">H", len(sof) + 2) + sof + b"\xff\xd9")


def nacp(titulo: str, autor: str, version: str) -> bytes:
    datos = bytearray(NACP_TAMANO)
    for i in range(16):
        datos[i * 0x300:i * 0x300 + len(titulo)] = titulo.encode()
        datos[i * 0x300 + 0x200:i * 0x300 + 0x200 + len(autor)] = autor.encode()
    datos[0x3060:0x3060 + len(version)] = version.encode()
    return bytes(datos)


def romfs(archivos: Dict[str, bytes]) -> bytes:
    """RomFS en el formato de libnx con todos los archivos en la raíz."""
    sin_entrada = 0xFFFFFFFF
    dirs = struct.pack("<6I", 0, sin_entrada, sin_entrada, 0 if archivos else sin_entrada, sin_entrada, 0)
    tabla = b""
    datos = b""
    nombres = list(archivos)
    for i, nombre in enumerate(nombres):
        contenido = archivos[nombre]
        n = nombre.encode()
        tam_entrada = 32 + ((len(n) + 3) & ~3)
        hermano = len(tabla) + tam_entrada if i + 1 < len(nombres) else sin_entrada
        tabla += struct.pack("<IIQQII", 0, hermano, len(datos), len(contenido), sin_entrada, len(n))
        tabla += n + b"\0" * ((-len(n)) % 4)
        datos += contenido + b"\0" * ((-len(contenido)) % 16)
    hash_dir = struct.pack("<I", 0)
    hash_arch = struct.pack("<I", 0)
    off = 0x50
    off_hash_dir = off
    off += len(hash_dir)
    off_dirs = off
    off += len(dirs)
    off_hash_arch = off
    off += len(hash_arch)
    off_tabla = off
    off += len(tabla)
    off_datos = (off + 15) & ~15
    cabecera = struct.pack("<10Q", 0x50, off_hash_dir, len(hash_dir), off_dirs, len(dirs), off_hash_arch,
                           len(hash_arch), off_tabla, len(tabla), off_datos)
    cuerpo = cabecera + hash_dir + dirs + hash_arch + tabla
    return cuerpo + b"\0" * (off_datos - len(cuerpo)) + datos


def nro(icono: bytes, metadatos: bytes, archivos: Dict[str, bytes]) -> bytes:
    """NRO con tres segmentos de relleno y la sección de recursos ASET."""
    segmentos = [(0x80, 0x100), (0x180, 0x40), (0x1C0, 0x40)]
    tam_nro = 0x200
    cabecera = bytearray(tam_nro)
    cabecera[0x10:0x14] = b"NRO0"
    struct.pack_into("<III", cabecera, 0x14, 0, tam_nro, 0)
    for k, (off, tam) in enumerate(segmentos):
        struct.pack_into("<II", cabecera, 0x20 + 8 * k, off, tam)
    fs = romfs(archivos)
    off_icono = 0x38
    off_nacp = off_icono + len(icono)
    off_romfs = off_nacp + len(metadatos)
    aset = b"ASET" + struct.pack("<I", 0) + struct.pack("<QQQQQQ", off_icono, len(icono), off_nacp, len(metadatos),
                                                         off_romfs, len(fs))
    return bytes(cabecera) + aset + icono + metadatos + fs


def nro_del_juego(pck: bytes = b"GDPC" + b"\0" * 60, carpeta: str = "AtelierDeLasEras") -> bytes:
    return nro(jpeg(256, 256), nacp("Atelier de las Eras", "Proyecto Atelier de las Eras", "0.1.0"),
               {"game.pck": pck, "app.id": (carpeta + "\n").encode()})
