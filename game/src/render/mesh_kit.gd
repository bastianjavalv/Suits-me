class_name MeshKit
extends RefCounted
## Construcción de mallas procedurales: superficies de revolución con bordes por columna
## (escotes, bajos asimétricos), pliegues por desplazamiento radial, aberturas frontales y
## normales/tangentes analíticas para materiales PBR anisótropos.
##
## Convenciones: Y hacia arriba; el frente del cuerpo mira a +Z; el ángulo θ se mide desde +Z
## hacia +X. UV = (arco en metros, altura en metros) para que los tejidos no se deformen;
## UV2 = (θ normalizado 0..1, t vertical 0..1) para costuras y bajos en el shader.


## Interpola (rx, rz) de un perfil [Vector3(y, rx, rz)] ordenado por y, con Catmull-Rom.
static func sample_profile(profile: Array, y: float) -> Vector2:
	var n := profile.size()
	if n == 0:
		return Vector2.ZERO
	if y <= profile[0].x:
		return Vector2(profile[0].y, profile[0].z)
	if y >= profile[n - 1].x:
		return Vector2(profile[n - 1].y, profile[n - 1].z)
	var i := 1
	while i < n - 1 and profile[i].x < y:
		i += 1
	var p1: Vector3 = profile[i - 1]
	var p2: Vector3 = profile[i]
	var p0: Vector3 = profile[maxi(i - 2, 0)]
	var p3: Vector3 = profile[mini(i + 1, n - 1)]
	var t := (y - p1.x) / maxf(p2.x - p1.x, 0.00001)
	return Vector2(_cr(p0.y, p1.y, p2.y, p3.y, t), _cr(p0.z, p1.z, p2.z, p3.z, t))


static func _cr(a: float, b: float, c: float, d: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3)


## Superficie de revolución.
## opts:
##   profile: Array[Vector3(y, rx, rz)]  perfil base (obligatorio salvo que se dé `radius`)
##   radius: Callable(theta, y, t) -> Vector2  radios propios (opcional, sustituye a profile)
##   y_bottom / y_top: float o Callable(theta) -> float   límites por columna
##   offset: Callable(theta, y, t) -> float  desplazamiento radial extra (pliegues, holgura)
##   center: Callable(y) -> Vector2(cx, cz)  desplazamiento del eje (opcional)
##   segments (int), rings (int)
##   gap: float  abertura frontal total en radianes (0 = cerrada)
##   inward: bool  normales hacia dentro (forros)
static func lathe(opts: Dictionary) -> ArrayMesh:
	var segments: int = maxi(int(opts.get("segments", 32)), 6)
	var rings: int = maxi(int(opts.get("rings", 24)), 2)
	var gap: float = float(opts.get("gap", 0.0))
	var closed := gap <= 0.0001
	var theta0 := gap * 0.5
	var theta_span := TAU - gap
	var cols := segments + 1
	var profile: Array = opts.get("profile", [])
	var radius_fn: Callable = opts.get("radius", Callable())
	var offset_fn: Callable = opts.get("offset", Callable())
	var center_fn: Callable = opts.get("center", Callable())
	var yb: Variant = opts.get("y_bottom", 0.0)
	var yt: Variant = opts.get("y_top", 1.0)
	var inward: bool = opts.get("inward", false)

	var pos := PackedVector3Array()
	pos.resize(cols * (rings + 1))
	var uv2 := PackedVector2Array()
	uv2.resize(pos.size())
	var thetas := PackedFloat32Array()
	thetas.resize(cols)
	for j in cols:
		thetas[j] = theta0 + theta_span * float(j) / float(segments)
	for j in cols:
		var th := thetas[j]
		var y0: float = yb.call(th) if yb is Callable else float(yb)
		var y1: float = yt.call(th) if yt is Callable else float(yt)
		for i in rings + 1:
			var t := float(i) / float(rings)
			var y := lerpf(y0, y1, t)
			var r: Vector2 = radius_fn.call(th, y, t) if radius_fn.is_valid() else sample_profile(profile, y)
			var extra: float = offset_fn.call(th, y, t) if offset_fn.is_valid() else 0.0
			var c: Vector2 = center_fn.call(y) if center_fn.is_valid() else Vector2.ZERO
			var s := sin(th)
			var co := cos(th)
			var p := Vector3(c.x + (r.x + extra) * s, y, c.y + (r.y + extra) * co)
			pos[i * cols + j] = p
			uv2[i * cols + j] = Vector2(fposmod(th, TAU) / TAU, t)
	return _grid_mesh(pos, uv2, cols, rings + 1, closed, inward)


## Malla de rejilla (cols × rows) con normales y tangentes por diferencias centrales.
static func _grid_mesh(pos: PackedVector3Array, uv2: PackedVector2Array, cols: int, rows: int, closed: bool,
		inward: bool) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(pos.size())
	var tangents := PackedFloat32Array()
	tangents.resize(pos.size() * 4)
	var uvs := PackedVector2Array()
	uvs.resize(pos.size())
	for i in rows:
		var arc := 0.0
		for j in cols:
			var idx := i * cols + j
			var jl := j - 1
			var jr := j + 1
			if closed:
				jl = (j - 1 + (cols - 1)) % (cols - 1) if j == 0 else j - 1
				jr = 1 if j == cols - 1 else j + 1
			jl = clampi(jl, 0, cols - 1)
			jr = clampi(jr, 0, cols - 1)
			var il := clampi(i - 1, 0, rows - 1)
			var ir := clampi(i + 1, 0, rows - 1)
			var du := pos[i * cols + jr] - pos[i * cols + jl]
			var dv := pos[ir * cols + j] - pos[il * cols + j]
			var n := dv.cross(du)
			if n.length_squared() < 1e-14:
				n = Vector3(pos[idx].x, 0.0, pos[idx].z)
				if n.length_squared() < 1e-14:
					n = Vector3.UP if i == rows - 1 else Vector3.DOWN
			n = n.normalized()
			if inward:
				n = -n
			normals[idx] = n
			var tg := du.normalized() if du.length_squared() > 1e-14 else Vector3.RIGHT
			tangents[idx * 4] = tg.x
			tangents[idx * 4 + 1] = tg.y
			tangents[idx * 4 + 2] = tg.z
			tangents[idx * 4 + 3] = -1.0 if inward else 1.0
			if j > 0:
				arc += pos[idx].distance_to(pos[idx - 1])
			uvs[idx] = Vector2(arc, pos[idx].y)
	var indices := PackedInt32Array()
	for i in rows - 1:
		for j in cols - 1:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if inward:
				indices.append_array([a, b, c, b, d, c])
			else:
				indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Elipsoide como superficie de revolución (útil para cabeza, manos, bolsos, perlas grandes).
static func ellipsoid(radii: Vector3, segments: int = 24, rings: int = 16, offset: Callable = Callable()) -> ArrayMesh:
	return lathe({
		"segments": segments, "rings": rings, "y_bottom": -radii.y, "y_top": radii.y,
		"radius": func(_th: float, y: float, _t: float) -> Vector2:
			var k := sqrt(maxf(0.0, 1.0 - (y * y) / (radii.y * radii.y)))
			return Vector2(radii.x * k, radii.z * k),
		"offset": offset,
	})


## Une varias mallas de una superficie en una sola (menos llamadas de dibujo).
static func merge(parts: Array, transforms: Array = []) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in parts.size():
		var xf: Transform3D = transforms[k] if k < transforms.size() else Transform3D.IDENTITY
		st.append_from(parts[k], 0, xf)
	return st.commit()


## Número total de triángulos de una malla (para presupuestos de rendimiento).
static func triangle_count(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		total += idx.size() / 3 if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total
