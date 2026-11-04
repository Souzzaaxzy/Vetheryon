class_name LFTerrainRoads
extends RefCounted
## Roads that shape the land. Planned once from the seed (LFTerrainGenerator.setup), then applied inside
## LFTerrainGenerator.get_height, so terrain meshes, collision, props, grass and anything else that asks
## for a height all agree.
##  - route(): AStarGrid2D over a coarse height grid. Cost rises steeply with slope, so a road winds
##    along hillsides and around rises when it can; water is a costly ford; `avoid` circles are walls.
##  - add_road(): resamples the route, smooths it, and builds a height profile limited to MAX_GRADE
##    (cuts into rises and banks up over hollows). Near the road the ground is pulled to that profile:
##    flat across the carriageway, then blended back to the land over a shoulder whose width grows with
##    the cut, so a road through a cliff becomes a cutting with steep earth walls.
##  - apply(): the height modifier (fast reject by bounding box and a bucket grid of segments).
## Rivers are left alone: a road crossing one is a ford, not a dam. Read-only after setup (thread safe).

const CELL := 4.0            # A* grid spacing (m)
const STEP := 2.0            # profile sample spacing (m)
const BRIDGE_WET := 0.3        # land this close above the waterline (m) counts as water for a bridge
const MAX_BRIDGE := 40.0       # longest bridge (m); wider water stays a ford
const MAX_GRADE := 0.13      # rise per metre the road profile may have (~7.4 degrees)
const HALF_WIDTH := 2.2      # flat carriageway half width (m)
const BANK := 0.85           # shoulder width per metre of cut or fill (lower = steeper walls)
const MIN_SHOULDER := 2.5
const MAX_SHOULDER := 22.0
const BUCKET := 16.0

## Each road: {"pts": PackedVector2Array, "prof": PackedFloat32Array (road height at each point),
## "cut": PackedFloat32Array (land height minus road height), "ford": PackedByteArray}.
var roads: Array[Dictionary] = []
var _bounds := Rect2()
var _buckets := {}   # Vector2i -> Array of [road index, segment index]


func is_empty() -> bool:
	return roads.is_empty()


# --- planning ----------------------------------------------------------------------------------------------

## A route over the land from `from` to `to` (x, z) for `gen` (base heights, before any roads). `avoid`
## holds Vector3(x, z, radius) circles the road must not enter. With `follow`, cells on its roads cost
## `follow_cost` (against 1 for flat open land), so the route runs along them where that is shorter
## (LFRoadNetwork cuts those parts out again). Returns smoothed points (may be empty).
static func route(gen: LFTerrainGenerator, from: Vector2, to: Vector2, avoid: Array[Vector3] = [],
		follow: LFTerrainRoads = null, follow_cost := 0.3) -> PackedVector2Array:
	var lo := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2(70, 70)
	var hi := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2(70, 70)
	var w := int(ceil((hi.x - lo.x) / CELL)) + 1
	var h := int(ceil((hi.y - lo.y) / CELL)) + 1
	var heights := PackedFloat32Array()
	heights.resize(w * h)
	for j in h:
		for i in w:
			heights[j * w + i] = gen.base_height(lo.x + i * CELL, lo.y + j * CELL)
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	for j in h:
		for i in w:
			var x := lo.x + i * CELL
			var z := lo.y + j * CELL
			var hc := heights[j * w + i]
			var grad := 0.0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni := clampi(i + d.x, 0, w - 1)
				var nj := clampi(j + d.y, 0, h - 1)
				grad = maxf(grad, absf(heights[nj * w + ni] - hc) / CELL)
			var weight := 1.0 + 60.0 * grad * grad
			if hc < gen.water_level_at(x, z) + 0.6:
				weight += 30.0
			elif gen.river_factor(x, z) > 0.4:
				weight += 14.0
			var blocked := false
			for c in avoid:
				if Vector2(x - c.x, z - c.y).length() < c.z:
					blocked = true
					break
			if blocked:
				astar.set_point_solid(Vector2i(i, j), true)
			elif follow != null and follow.distance_to(x, z) < HALF_WIDTH + 1.0:
				astar.set_point_weight_scale(Vector2i(i, j), 1.0)
			elif follow != null:   # (scaled up rather than the road down: the A* heuristic must not overestimate)
				astar.set_point_weight_scale(Vector2i(i, j), weight / follow_cost)
			else:
				astar.set_point_weight_scale(Vector2i(i, j), weight)
	var a := Vector2i(clampi(roundi((from.x - lo.x) / CELL), 0, w - 1), clampi(roundi((from.y - lo.y) / CELL), 0, h - 1))
	var b := Vector2i(clampi(roundi((to.x - lo.x) / CELL), 0, w - 1), clampi(roundi((to.y - lo.y) / CELL), 0, h - 1))
	astar.set_point_solid(a, false)
	astar.set_point_solid(b, false)
	var ids := astar.get_id_path(a, b)
	if ids.is_empty():
		return PackedVector2Array([from, to])
	var pts := PackedVector2Array([from])
	for k in range(1, ids.size() - 1):
		pts.append(lo + Vector2(ids[k]) * CELL)
	pts.append(to)
	return smooth(pts, 3)


## Chaikin corner cutting (keeps the end points).
static func smooth(pts: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var p := pts
	for it in iterations:
		if p.size() < 3:
			return p
		var q := PackedVector2Array([p[0]])
		for k in p.size() - 1:
			q.append(p[k].lerp(p[k + 1], 0.25))
			q.append(p[k].lerp(p[k + 1], 0.75))
		q.append(p[p.size() - 1])
		p = q
	return p


## Adds a road along `route_pts` (x, z): resampled every STEP, with a grade-limited height profile.
## `meta` is kept on the road (e.g. {"from": plan id, "from_name", "to_name"} for its signposts). A road
## that branches off another at its end has "joins" (that road's index) and "end_h" (its surface height
## there); at its start, "joins_start" and "start_h".
func add_road(gen: LFTerrainGenerator, route_pts: PackedVector2Array, meta := {}) -> void:
	var pts := _resample(route_pts, STEP)
	if pts.size() < 2:
		return
	var n := pts.size()
	var land := PackedFloat32Array()
	var wet := PackedFloat32Array()   # the land as height over the water there, on WATER_LEVEL's scale
	var ford := PackedByteArray()
	land.resize(n)
	wet.resize(n)
	ford.resize(n)
	for k in n:
		land[k] = gen.base_height(pts[k].x, pts[k].y)
		wet[k] = land[k] - gen.water_level_at(pts[k].x, pts[k].y) + LFTerrainGenerator.WATER_LEVEL
		ford[k] = 1 if gen.river_factor(pts[k].x, pts[k].y) > 0.35 or wet[k] < LFTerrainGenerator.WATER_LEVEL + 0.3 else 0
	# Bridged water: the profile runs straight across from bank to bank (no dip into the channel), and
	# the banks around it are shaped and surfaced like any road; only the water under the deck keeps
	# its river bed.
	var bridges := _bridges(wet)
	var shaped := land.duplicate()
	for span: Vector2i in bridges:
		var lo := span.x
		while lo > 0 and ford[lo - 1] == 1:
			lo -= 1
		var hi := span.y
		while hi < n - 1 and ford[hi + 1] == 1:
			hi += 1
		for k in range(lo, hi + 1):
			ford[k] = 1 if k > span.x and k < span.y else 0
		for k in range(span.x + 1, span.y):
			shaped[k] = lerpf(land[span.x], land[span.y], float(k - span.x) / float(span.y - span.x))
	# Smooth the land a little first, then limit the grade both ways (cut the rises, fill the dips).
	var prof := shaped.duplicate()
	for pass_i in 3:
		var nxt := prof.duplicate()
		for k in range(1, n - 1):
			nxt[k] = (prof[k - 1] + prof[k] * 2.0 + prof[k + 1]) * 0.25
		prof = nxt
	var dh := MAX_GRADE * STEP
	for k in range(1, n):
		prof[k] = clampf(prof[k], prof[k - 1] - dh, prof[k - 1] + dh)
	for k in range(n - 2, -1, -1):
		prof[k] = clampf(prof[k], prof[k + 1] - dh, prof[k + 1] + dh)
	prof[0] = float(meta.get("start_h", land[0]))   # meet the ground at both ends (or the road a branch joins)
	prof[n - 1] = float(meta.get("end_h", land[n - 1]))
	for k in range(n - 2, -1, -1):
		prof[k] = clampf(prof[k], prof[k + 1] - dh, prof[k + 1] + dh)
	for k in range(1, n):
		prof[k] = clampf(prof[k], prof[k - 1] - dh * 1.5, prof[k - 1] + dh * 1.5)
	var cut := PackedFloat32Array()
	cut.resize(n)
	for k in n:
		cut[k] = land[k] - prof[k]
	var ri := roads.size()
	var rd := {"pts": pts, "prof": prof, "cut": cut, "ford": ford, "bridges": bridges}
	rd.merge(meta)
	roads.append(rd)
	for k in n - 1:
		var reach := HALF_WIDTH + _shoulder(maxf(absf(cut[k]), absf(cut[k + 1])))
		var r := Rect2(pts[k], Vector2.ZERO).expand(pts[k + 1]).grow(reach)
		_bounds = r if _bounds.size == Vector2.ZERO else _bounds.merge(r)
		for bx in range(floori(r.position.x / BUCKET), floori(r.end.x / BUCKET) + 1):
			for bz in range(floori(r.position.y / BUCKET), floori(r.end.y / BUCKET) + 1):
				var key := Vector2i(bx, bz)
				if not _buckets.has(key):
					_buckets[key] = []
				(_buckets[key] as Array).append([ri, k])


## Where the road goes under water (land below the waterline), short enough to span: a plank bridge
## from the last dry point to the next ([Vector2i(first, last)] point indices). Longer water stays a ford.
static func _bridges(land: PackedFloat32Array) -> Array:
	var out: Array = []
	var n := land.size()
	var k := 0
	while k < n:
		if land[k] >= LFTerrainGenerator.WATER_LEVEL + BRIDGE_WET:
			k += 1
			continue
		var a := k
		while k < n and land[k] < LFTerrainGenerator.WATER_LEVEL + BRIDGE_WET:
			k += 1
		var span := Vector2i(maxi(a - 1, 0), mini(k, n - 1))
		if float(span.y - span.x) * STEP <= MAX_BRIDGE:
			out.append(span)
	return out


static func _shoulder(cut: float) -> float:
	return clampf(MIN_SHOULDER + cut * BANK, MIN_SHOULDER, MAX_SHOULDER)


static func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	out.append(pts[0])
	var carry := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var len := a.distance_to(b)
		var t := step - carry
		while t <= len:
			out.append(a.lerp(b, t / len))
			t += step
		carry = len - (t - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > step * 0.3:
		out.append(pts[pts.size() - 1])
	return out


# --- applying ----------------------------------------------------------------------------------------------

## The land height `h` at (x, z), reshaped by any road nearby.
func apply(x: float, z: float, h: float) -> float:
	if roads.is_empty() or not _bounds.has_point(Vector2(x, z)):
		return h
	var segs: Variant = _buckets.get(Vector2i(floori(x / BUCKET), floori(z / BUCKET)))
	if segs == null:
		return h
	var p := Vector2(x, z)
	var best_d := INF
	var best_prof := 0.0
	var best_cut := 0.0
	var best_ford := 0.0
	for e: Array in segs:
		var rd: Dictionary = roads[e[0]]
		var k: int = e[1]
		var pts: PackedVector2Array = rd["pts"]
		var a := pts[k]
		var ab := pts[k + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			var prof: PackedFloat32Array = rd["prof"]
			var cut: PackedFloat32Array = rd["cut"]
			var ford: PackedByteArray = rd["ford"]
			best_prof = lerpf(prof[k], prof[k + 1], t)
			best_cut = lerpf(cut[k], cut[k + 1], t)
			best_ford = lerpf(float(ford[k]), float(ford[k + 1]), t)
	var reach := HALF_WIDTH + _shoulder(absf(best_cut))
	if best_d >= reach:
		return h
	var f := 1.0 - smoothstep(HALF_WIDTH, reach, best_d)
	f *= 1.0 - best_ford   # fords keep the river bed
	return lerpf(h, best_prof, f)


## Where a branch from `from` should join road `ri` (a Y junction): the point of the road nearest to
## `from`, skipping the first `skip_start` and last `skip_end` metres of it. Returns [point, surface height].
func junction(ri: int, from: Vector2, skip_start: float, skip_end: float) -> Array:
	var rd: Dictionary = roads[ri]
	var pts: PackedVector2Array = rd["pts"]
	var prof: PackedFloat32Array = rd["prof"]
	var n := pts.size()
	var k0 := mini(int(skip_start / STEP), n - 1)
	var k1 := maxi(n - 1 - int(skip_end / STEP), k0)
	var best := k0
	for k in range(k0, k1 + 1):
		if pts[k].distance_squared_to(from) < pts[best].distance_squared_to(from):
			best = k
	return [pts[best], prof[best]]


## The road point nearest to `p` over every road: Vector2i(road index, point index), or (-1, -1) when
## there are no roads.
func nearest_point(p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for ri in roads.size():
		var pts: PackedVector2Array = roads[ri]["pts"]
		for k in pts.size():
			var d := pts[k].distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = Vector2i(ri, k)
	return best


## Distance from (x, z) to the nearest road centreline (INF when none is near).
func distance_to(x: float, z: float) -> float:
	var segs: Variant = _buckets.get(Vector2i(floori(x / BUCKET), floori(z / BUCKET)))
	if segs == null:
		return INF
	var p := Vector2(x, z)
	var best := INF
	for e: Array in segs:
		var pts: PackedVector2Array = (roads[e[0]] as Dictionary)["pts"]
		var a := pts[int(e[1])]
		var ab := pts[int(e[1]) + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best
