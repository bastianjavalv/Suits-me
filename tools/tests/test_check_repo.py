# -*- coding: utf-8 -*-
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_repo  # noqa: E402
import fixtures_apk as fx  # noqa: E402


def _revisar(tmp_path: Path):
    return check_repo.revisar(tmp_path, [p for p in tmp_path.rglob("*") if p.is_file()])


def test_repositorio_limpio(tmp_path):
    (tmp_path / "LEEME.md").write_text("Proyecto original sin recursos de terceros.", encoding="utf-8")
    (tmp_path / "datos.json").write_text('{"color": "#AABBCC"}', encoding="utf-8")
    assert _revisar(tmp_path) == []


def test_detecta_apk_aunque_cambie_la_extension(tmp_path):
    fx.apk_unity_il2cpp(tmp_path / "copia.zip")
    problemas = _revisar(tmp_path)
    assert any("paquete Android dentro de un ZIP" in p for p in problemas)


def test_detecta_extensiones_y_firmas(tmp_path):
    (tmp_path / "juego.apk").write_bytes(b"x")
    (tmp_path / "libunity.bin").write_bytes(fx.elf_stub())
    (tmp_path / "codigo.bin").write_bytes(fx.construir_dex(["La/B;"]))
    (tmp_path / "global-metadata.dat").write_bytes(b"\xaf\x1b\xb1\xfa")
    (tmp_path / "AtelierDeLasEras.nro").write_bytes(b"x")
    (tmp_path / "prod.keys").write_bytes(b"x")
    problemas = "\n".join(_revisar(tmp_path))
    assert "juego.apk" in problemas
    assert "libunity.bin" in problemas and "ELF" in problemas
    assert "codigo.bin" in problemas and "DEX" in problemas
    assert "global-metadata.dat" in problemas
    assert "AtelierDeLasEras.nro" in problemas
    assert "prod.keys" in problemas


def test_detecta_credenciales(tmp_path):
    # Valores ficticios construidos por partes para no disparar escáneres de secretos.
    (tmp_path / "config.json").write_text('{"k": "%s"}' % ("AKIA" + "ABCDEFGHIJKLMNOP"), encoding="utf-8")
    (tmp_path / "notas.md").write_text("-----BEGIN " + "PRIVATE KEY-----\nabc\n", encoding="utf-8")
    problemas = "\n".join(_revisar(tmp_path))
    assert "clave de AWS" in problemas
    assert "clave privada PEM" in problemas
