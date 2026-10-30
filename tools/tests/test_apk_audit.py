# -*- coding: utf-8 -*-
"""Pruebas de apk_audit con APK sinteticos (sin archivos propietarios)."""
from __future__ import annotations

import json
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "apk_audit"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import apk_audit  # noqa: E402
import fixtures_apk as fx  # noqa: E402

# Identificador ficticio construido por partes para que los escáneres de secretos no lo confundan.
ADMOB_FALSO = "ca-app-pub-" + "1234567890123456" + "~" + "1234567890"


def test_axml_ida_y_vuelta():
    datos = fx.manifiesto_ejemplo(paquete="com.prueba.app", version_name="9.8.7", version_code=1234,
                                  permisos=("android.permission.INTERNET", "android.permission.VIBRATE"))
    arbol = apk_audit.parse_axml(datos)
    m = apk_audit.resumir_manifiesto(arbol)
    assert m["paquete"] == "com.prueba.app"
    assert m["versionName"] == "9.8.7"
    assert m["versionCode"] == 1234
    assert m["minSdk"] == 23 and m["targetSdk"] == 34
    assert m["permisos"] == ["android.permission.INTERNET", "android.permission.VIBRATE"]
    assert m["actividad_principal"] == "com.unity3d.player.UnityPlayerActivity"
    assert m["aplicacion"]["allowBackup"] is False
    assert m["aplicacion"]["label"] == "@0x7f0e0001"
    assert m["servicios"] == ["com.ejemplo.Servicio"]


def test_axml_rechaza_datos_que_no_son_xml_binario():
    try:
        apk_audit.parse_axml(b"<manifest/>  texto plano")
    except apk_audit.AxmlError:
        return
    raise AssertionError("debio rechazar XML de texto")


def test_dex_lista_clases_y_detecta_sdks():
    dex = fx.construir_dex(["Lcom/applovin/sdk/AppLovinSdk;", "Lcom/google/firebase/analytics/A;",
                            "Lcom/android/billingclient/api/B;", "Lorg/propio/Juego;"],
                           cadenas_extra=["https://servidor.ejemplo.org/api"])
    d = apk_audit.parse_dex(dex)
    assert d["checksum_ok"] is True
    assert len(d["clases"]) == 4
    sdks = {s["sdk"]: s["categoria"] for s in apk_audit.detectar_sdks(d["clases"])}
    assert sdks["AppLovin / MAX"] == "publicidad"
    assert sdks["Firebase Analytics"] == "analitica"
    assert sdks["Google Play Billing"] == "compras"
    assert "servidor.ejemplo.org" in apk_audit.hosts_en_cadenas(d["cadenas"])


def test_dex_detecta_checksum_alterado():
    dex = bytearray(fx.construir_dex(["La/B;"]))
    dex[-2] ^= 0xFF
    assert apk_audit.parse_dex(bytes(dex))["checksum_ok"] is False


def test_certificado_der():
    info = apk_audit.analizar_certificado(fx.certificado_falso(cn="Atelier Prueba", o="Prueba S.A."))
    assert "CN=Atelier Prueba" in info["sujeto"]
    assert "O=Prueba S.A." in info["emisor"]
    assert info["valido_desde"] == "2020-01-01"
    assert info["valido_hasta"] == "2049-12-31"
    assert len(info["huella_sha256"]) == 64


def test_apk_unity_il2cpp_completo(tmp_path):
    apk = fx.apk_unity_il2cpp(tmp_path / "juego.apk", version_unity="2022.3.21f1",
                              meta={"com.google.android.gms.ads.APPLICATION_ID": ADMOB_FALSO})
    inf = apk_audit.analizar_apk(apk)
    assert inf["integridad"]["zip_valido"] is True
    assert len(inf["archivo"]["sha256"]) == 64
    assert inf["manifiesto"]["paquete"] == "com.ejemplo.juego"
    assert inf["abis"] == ["arm64-v8a", "armeabi-v7a"]
    mot = inf["motor"]
    assert mot["motor"] == "Unity"
    assert mot["detalles"]["backend_scripting"] == "IL2CPP"
    assert mot["detalles"]["version_unity"] == "2022.3.21f1"
    assert mot["detalles"]["il2cpp_metadata"]["version"] == 29
    assert mot["detalles"]["il2cpp_metadata"]["magia_valida"] is True
    assert mot["detalles"]["addressables"] is True
    arquitecturas = {b["nombre"] + "@" + b["abi"]: b["elf"]["maquina"] for b in inf["bibliotecas_nativas"]}
    assert arquitecturas["libunity.so@arm64-v8a"].startswith("AArch64")
    assert arquitecturas["libunity.so@armeabi-v7a"].startswith("ARM (32")
    categorias = {s["categoria"] for s in inf["dex"]["sdks"]}
    assert {"publicidad", "analitica", "compras", "atribucion", "motor"} <= categorias
    assert "api.ejemplo-backend.com" in inf["hosts_red"]
    assert "cdn.ejemplo-contenido.net" in inf["hosts_red"]
    assert inf["firma"]["presente"] is True
    assert "esquema v2" in inf["firma"]["bloques"]
    assert "CN=Estudio Ejemplo" in inf["firma"]["certificados"][0]["sujeto"]
    assert inf["viabilidad"]["veredicto"] == "port directo no viable desde el APK"
    assert any("IL2CPP" in c for c in inf["viabilidad"]["conclusiones"])


def test_redaccion_de_meta_datos(tmp_path):
    clave = ADMOB_FALSO
    apk = fx.apk_unity_il2cpp(tmp_path / "a.apk", meta={"com.google.android.gms.ads.APPLICATION_ID": clave})
    con = apk_audit.analizar_apk(apk, redaccion=True)
    sin = apk_audit.analizar_apk(apk, redaccion=False)
    v_con = con["manifiesto"]["meta_datos"][0]["valor"]
    v_sin = sin["manifiesto"]["meta_datos"][0]["valor"]
    assert v_sin == clave
    assert v_con != clave and v_con.startswith("ca-a") and v_con.endswith("7890") and "*" in v_con
    assert clave not in apk_audit.informe_markdown(con)


def test_advierte_apk_dividido(tmp_path):
    apk = fx.apk_unity_il2cpp(tmp_path / "split.apk", split_required=True)
    inf = apk_audit.analizar_apk(apk)
    assert any("splits" in a for a in inf["advertencias"])


def test_detecta_otros_motores(tmp_path):
    casos = {
        "Godot": {"lib/arm64-v8a/libgodot_android.so": fx.elf_stub(), "assets/juego.pck": b"GDPC"},
        "Flutter": {"lib/arm64-v8a/libflutter.so": fx.elf_stub(), "lib/arm64-v8a/libapp.so": fx.elf_stub()},
        "Unreal Engine": {"lib/arm64-v8a/libUE4.so": fx.elf_stub()},
    }
    for esperado, archivos in casos.items():
        archivos = dict(archivos)
        archivos["AndroidManifest.xml"] = fx.manifiesto_ejemplo()
        apk = fx.crear_apk(tmp_path / (esperado.split()[0] + ".apk"), archivos)
        assert apk_audit.analizar_apk(apk)["motor"]["motor"] == esperado


def test_zip_corrupto_se_informa(tmp_path):
    apk = fx.apk_unity_il2cpp(tmp_path / "roto.apk")
    datos = bytearray(apk.read_bytes())
    with zipfile.ZipFile(apk) as zf:
        info = zf.getinfo("assets/bin/Data/sharedassets0.assets")
    inicio = info.header_offset + 30 + len(info.filename) + len(info.extra)
    datos[inicio + 2] ^= 0xFF
    apk.write_bytes(bytes(datos))
    inf = apk_audit.analizar_apk(apk)
    assert inf["integridad"]["zip_valido"] is False
    assert inf["integridad"]["entradas_con_error_crc"]


def test_archivo_que_no_es_zip(tmp_path):
    falso = tmp_path / "falso.apk"
    falso.write_bytes(b"esto no es un zip")
    inf = apk_audit.analizar_apk(falso)
    assert inf["integridad"]["zip_valido"] is False
    assert "veredicto" in inf["viabilidad"]


def test_cli_genera_informes(tmp_path, capsys):
    apk = fx.apk_unity_il2cpp(tmp_path / "cli.apk")
    salida = tmp_path / "salida"
    assert apk_audit.main([str(apk), "--salida", str(salida)]) == 0
    datos = json.loads((salida / "informe_apk.json").read_text(encoding="utf-8"))
    md = (salida / "informe_apk.md").read_text(encoding="utf-8")
    assert datos["archivo"]["sha256"] in md
    assert "## 7. Evaluación de viabilidad del port" in md
    assert "SHA-256" in capsys.readouterr().out


def test_il2cpp_por_metadatos_sin_bibliotecas_nativas(tmp_path):
    archivos = {
        "AndroidManifest.xml": fx.manifiesto_ejemplo(meta={"com.android.vending.splits.required": "true"}),
        "classes.dex": fx.construir_dex(["Lcom/unity3d/player/UnityPlayerActivity;"]),
        "assets/bin/Data/data.unity3d": b"UnityFS\x00" + b"\x00\x00\x00\x08" + b"5.x.x\x006000.0.58f2\x00",
        "assets/bin/Data/Managed/Metadata/global-metadata.dat": (0xFAB11BAF).to_bytes(4, "little") + (31).to_bytes(4, "little"),
    }
    inf = apk_audit.analizar_apk(fx.crear_apk(tmp_path / "base.apk", archivos))
    assert inf["motor"]["detalles"]["backend_scripting"] == "IL2CPP"
    assert inf["motor"]["detalles"]["version_unity"] == "6000.0.58f2"
    assert inf["abis"] == []
    assert any("APK base de una instalacion dividida" in c for c in inf["viabilidad"]["conclusiones"])
    cats = inf["recursos"]["por_categoria"]
    assert "metadatos IL2CPP" in cats and "codigo Android (DEX)" in cats


def test_redaccion_de_hosts_de_proyecto():
    assert apk_audit.redactar_host("miapp-12345.firebaseio.com") == "[proyecto].firebaseio.com"
    assert apk_audit.redactar_host("bucket-x.s3.eu-central-1.amazonaws.com") == "[proyecto].s3.eu-central-1.amazonaws.com"
    assert apk_audit.redactar_host("a.applovin.com") == "a.applovin.com"
