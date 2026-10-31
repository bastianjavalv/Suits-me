# -*- coding: utf-8 -*-
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_offline  # noqa: E402


def test_detecta_red_y_respeta_comentarios(tmp_path):
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "ok.gd").write_text("# HTTPRequest solo en un comentario\nvar x := 1\n", encoding="utf-8")
    (tmp_path / "src" / "mal.gd").write_text("var r := HTTPRequest.new()\n", encoding="utf-8")
    (tmp_path / "plugin.gdextension").write_text("[configuration]\n", encoding="utf-8")
    problemas = "\n".join(check_offline.revisar(tmp_path))
    assert "mal.gd:1: HTTPRequest" in problemas
    assert "ok.gd" not in problemas
    assert "plugin.gdextension" in problemas


def test_el_juego_real_no_usa_red():
    juego = Path(__file__).resolve().parents[2] / "game"
    assert check_offline.revisar(juego) == []
