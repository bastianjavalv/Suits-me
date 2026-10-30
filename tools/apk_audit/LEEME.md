# apk_audit — auditoría del APK en tu computadora

Script de **solo lectura** que analiza un APK y genera un informe en español. Úsalo cuando el APK no
pueda llegar al entorno de desarrollo en la nube (por ejemplo, porque su política de red bloquea
Google Drive o MediaFire). El informe resultante **no contiene código ni recursos del juego**: solo
metadatos (hashes, nombres, tamaños, versiones), así que puedes compartirlo sin problema.

## Qué necesitas

- Python 3.8 o superior. En Windows: descárgalo de <https://www.python.org/downloads/> y, durante la
  instalación, marca **“Add python.exe to PATH”**.
- El archivo `apk_audit.py` (está en esta misma carpeta del repositorio).
- El APK, por ejemplo `SUITSME-0.13272.apk`.

No hace falta instalar ninguna biblioteca adicional.

## Pasos (Windows)

1. Crea una carpeta, por ejemplo `C:\auditoria`, y copia ahí `apk_audit.py` y el APK.
2. Abre la carpeta en el Explorador, escribe `powershell` en la barra de direcciones y pulsa Enter.
3. Ejecuta:

   ```powershell
   python apk_audit.py SUITSME-0.13272.apk --salida informe_apk
   ```

   Si `python` no existe, prueba con `py` (el lanzador que instala el instalador de python.org).

4. Al terminar verás en pantalla el SHA-256, el motor detectado y el veredicto. Se crea la carpeta
   `informe_apk` con:
   - `informe_apk.md`: informe legible (ábrelo con el Bloc de notas o con VS Code).
   - `informe_apk.json`: los mismos datos en formato estructurado.
5. Para copiar el informe completo desde PowerShell:

   ```powershell
   Get-Content informe_apk\informe_apk.md -Encoding UTF8
   ```

   Pega el resultado en el chat o súbelo al repositorio en `docs/apk/informe_apk.md`.

## Pasos (macOS o Linux)

```bash
python3 apk_audit.py SUITSME-0.13272.apk --salida informe_apk
```

## Qué analiza

| Sección | Contenido |
|---|---|
| Integridad | SHA-256, SHA-1, MD5 y verificación CRC de cada entrada del ZIP |
| Firma | Esquemas v1/v2/v3 y certificado del firmante (sujeto, emisor, validez, huella) |
| Manifiesto | Paquete, versión, SDK mínimo y objetivo, permisos, componentes y meta-datos |
| Motor | Unity, Unreal, Godot, Flutter, Cocos, etc.; versión y backend (IL2CPP o Mono) |
| Nativo | ABIs y bibliotecas `.so` con su arquitectura |
| SDK | Publicidad, analítica, compras, atribución, backend… detectados por nombres de clase |
| Red | Dominios citados en el código y en los archivos de configuración |
| Recursos | Tamaño por tipo: texturas, audio, fuentes, paquetes de Unity… |
| Viabilidad | Veredicto sobre el port y requisitos externos |

## Privacidad del informe

Por defecto, los valores largos de los meta-datos (identificadores de publicidad, claves de SDK) se
muestran **redactados** (`ca-a****7890`). Usa `--sin-redaccion` solo para un análisis privado y no
publiques ese resultado.

## Lo que el script nunca hace

- No modifica el APK.
- No extrae texturas, modelos, audio ni código.
- No se conecta a Internet.
