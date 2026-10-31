# -*- coding: utf-8 -*-
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import fixtures_nro as fx  # noqa: E402
import verificar_nro  # noqa: E402


def test_nro_correcto(tmp_path):
    pck = b"GDPC" + bytes(range(200))
    ruta = tmp_path / "AtelierDeLasEras.nro"
    ruta.write_bytes(fx.nro_del_juego(pck))
    (tmp_path / "game.pck").write_bytes(pck)
    problemas, resumen = verificar_nro.verificar(ruta, tmp_path / "game.pck", "Atelier de las Eras", "AtelierDeLasEras")
    assert problemas == []
    assert resumen["titulo"] == "Atelier de las Eras"
    assert resumen["version"] == "0.1.0"
    assert resumen["icono"] == "256x256 JPEG"
    assert resumen["carpeta_sd"] == "sdmc:/switch/AtelierDeLasEras/"
    assert resumen["romfs"] == {"app.id": 17, "game.pck": len(pck)}


def test_detecta_paquete_distinto_y_carpeta_inesperada(tmp_path):
    ruta = tmp_path / "juego.nro"
    ruta.write_bytes(fx.nro_del_juego(b"GDPC" + b"a" * 20, carpeta="OtraCarpeta"))
    (tmp_path / "game.pck").write_bytes(b"GDPC" + b"b" * 20)
    problemas, _ = verificar_nro.verificar(ruta, tmp_path / "game.pck", carpeta="AtelierDeLasEras")
    texto = "\n".join(problemas)
    assert "no coincide" in texto
    assert "OtraCarpeta" in texto


def test_detecta_icono_y_romfs_incorrectos(tmp_path):
    ruta = tmp_path / "juego.nro"
    ruta.write_bytes(fx.nro(fx.jpeg(128, 128), fx.nacp("Juego", "Autor", "1.0"), {"game.pck": b"PK\x03\x04"}))
    problemas, _ = verificar_nro.verificar(ruta)
    texto = "\n".join(problemas)
    assert "128x128" in texto
    assert "GDPC" in texto
    assert "app.id" in texto


def test_rechaza_lo_que_no_es_un_nro(tmp_path):
    ruta = tmp_path / "otro.nro"
    ruta.write_bytes(b"\0" * 512)
    problemas, _ = verificar_nro.verificar(ruta)
    assert len(problemas) == 1 and "NRO0" in problemas[0]
    truncado = tmp_path / "truncado.nro"
    truncado.write_bytes(fx.nro_del_juego()[:0x220])
    problemas, _ = verificar_nro.verificar(truncado)
    assert problemas and problemas[0].startswith("estructura")


def test_dimensiones_jpeg():
    assert verificar_nro.dimensiones_jpeg(fx.jpeg(256, 256)) == (256, 256)
    assert verificar_nro.dimensiones_jpeg(fx.jpeg(320, 180)) == (320, 180)
    assert verificar_nro.dimensiones_jpeg(b"\x89PNG") is None


def test_linea_de_ordenes_json(tmp_path, capsys):
    ruta = tmp_path / "AtelierDeLasEras.nro"
    ruta.write_bytes(fx.nro_del_juego())
    assert verificar_nro.main([str(ruta), "--json"]) == 0
    salida = json.loads(capsys.readouterr().out)
    assert salida["problemas"] == []
    assert salida["resumen"]["autor"] == "Proyecto Atelier de las Eras"
