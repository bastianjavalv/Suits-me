# Módulo de mejoras basado en opiniones de jugadores

## 1. De dónde salen las críticas

| Fuente | Qué aporta | Fiabilidad |
|---|---|---|
| Lista de requisitos del propietario del proyecto (10 puntos) | Síntesis de críticas recurrentes de jugadores de SUITSME | Principal referencia de este módulo |
| [Grand Screen](https://grand-screen.com/games/suitsme-fashion-stylist-games/) (ficha y reseñas recopiladas) | «Los anuncios cansan con el tiempo» y «el sistema de mejoras es algo repetitivo» | Indicativa: agregador de terceros consultado con el buscador |
| [AppGamer](https://www.appgamer.com/suitsme-dress-up-fashion-game-cheats-tips/) | Valoración 2,9/5 y queja de que faltan formas de ganar gemas y dinero | Indicativa |
| Auditoría del APK ([informe](01-informe-viabilidad-apk.md)) | 12 redes publicitarias, Google Play Billing, configuración remota, cuentas | Verificada sobre el archivo real |

No se hizo un análisis sistemático de reseñas (las tiendas no eran accesibles desde el entorno de
desarrollo). Si se reúne un conjunto de reseñas, puede añadirse aquí con su metodología.

## 2. Qué existe en SUITSME y qué es mejora nueva

Del juego original solo se sabe lo que muestra su APK y sus descripciones públicas: vestir modelos,
maquillaje y peinados, desafíos de estilo y un armario amplio, con anuncios, compras integradas,
inicio de sesión y configuración remota. Por eso la tabla distingue entre **funciones del género**
(presentes en este tipo de juegos y descritas públicamente para SUITSME) y **mejoras nuevas** de
este proyecto. Nada se ha copiado del original.

## 3. Requisitos y estado verificado

| # | Requisito | Tipo | Implementación | Evidencia |
|---|---|---|---|---|
| 1 | Economía: monedas y gemas ilimitadas, sin micropagos, anuncios ni restricciones | Mejora nueva (el original monetiza con anuncios y compras) | `economy.gd`: modo ilimitado persistente; probar una prenda la añade gratis; colección completa desde Opciones | `test_economy_inventory.gd`, `test_game_state.gd`, `check_offline.py` |
| 2 | Inventario permanente, sin duplicados y reutilizable | Función del género, reforzada | `inventory.gd`: las prendas no se consumen ni caducan; claves únicas; las «huérfanas» se conservan si un dato se daña | `test_adquisiciones_permanentes_sin_duplicados`, `test_favoritas_y_huerfanas_se_conservan` |
| 3 | Búsqueda por categoría, color, estilo, colección, temporada, diseñador, precio y favoritos | Mejora nueva | `wardrobe_filter.gd` + pantalla Filtros (más texto, «solo mi armario» y orden) | `test_filtros_del_armario`, `test_filtro_rapido_con_muchas_prendas` (5000 prendas) |
| 4 | Guardar conjuntos, editar borradores, combinar prendas y presentar alternativas | Mejora nueva | `outfit_library.gd` (looks, borradores, historial, papelera) y entregas múltiples por desafío | `test_looks_borradores_historial_y_papelera`, `test_alternativas_y_originalidad` |
| 5 | Rotación de 360°, zoom, poses fotográficas y proporciones realistas | Función del género | Plataforma giratoria, zoom e inspección por zonas, 5 poses, maniquí de 1,77 m (unas 7,7 cabezas) | `test_meshes.gd`, recorrido de integración, capturas |
| 6 | Desafíos variados, libertad creativa y uso de prendas existentes | Función del género, ampliada | 30 desafíos (recreación histórica, creativos y libres), sin compras necesarias | `test_contenido_real.gd` |
| 7 | Evaluación transparente (tema, armonía, creatividad) e identificada como local | Mejora nueva | `evaluator.gd`: 4 criterios con explicación línea a línea y aviso de evaluación local | `test_evaluacion_transparente_y_estrellas`, recorrido de integración |
| 8 | Rendimiento de carga, filtros, transiciones y animaciones | Mejora técnica | Caché de mallas, reconstrucción solo de las categorías que cambian, resolución dinámica, perfiles | Medición en [07-pruebas-y-calidad.md](07-pruebas-y-calidad.md) |
| 9 | Autoguardado, recuperación de borradores, copias de seguridad e historial | Mejora nueva | `save_system.gd`: escritura atómica, SHA-256, 10 copias rotativas, recuperación automática; el conjunto en curso se recupera | `test_library_save.gd` (8 pruebas), `test_partida_danada_se_recupera_de_la_copia` |
| 10 | Galería de diseños, fotos y conjuntos | Función del género | `gallery.gd` + modo foto + «Recrear el look» | `test_todo_persiste_entre_sesiones`, recorrido de integración |

## 4. Reglas respetadas

- No se reproducen mecánicas de monetización, esperas artificiales ni pérdida de progreso.
- No se eliminó ninguna mecánica característica del género por las críticas.
- La evaluación nunca finge ser una votación en línea.
