# Lowland Forge Map Baker: using it from code

Everything the Inspector does, a script can do too: bake a map, change any setting, add tiles, export
heightmaps and map images, and stream the baked tiles in your game. A complete example that does it all with
no Inspector set-up is `examples/bake_from_code.gd`: put it on a Node3D in an empty scene and run it.

Every snippet in this guide is run by the addon's own checks, so it works as written.

## Bake a map
`LFMapBaker` is a node, but it bakes without being in a scene. `bake()` runs to the end and returns
`{"error", "tiles", "props", "ms"}`. Set `auto_preview = false` outside the editor.
```gdscript
var baker := LFMapBaker.new()
baker.auto_preview = false   # no preview outside the editor
baker.map_seed = map_seed
baker.params = LFMapPresets.make("Classic Island")
baker.params.lake_count = 2
baker.params.river_count = 2
baker.tile_size = 512
baker.tiles_x = 2
baker.tiles_z = 2
baker.props = LFTileBaker.Props.ALL
baker.output_dir = map_dir
var info := baker.bake()   # {"error", "tiles", "props", "ms"}
baker.free()
```
- `output_dir`: `res://...` in the editor; in an exported game `res://` is read-only, so bake to `user://...`.
- The same seed and settings give the same map, bit for bit.
- `LFMapPresets.NAMES` lists the presets: Classic Island, Highland Island, Mountain Valley, Rolling Plains,
  Deep Forest, Badlands, Frozen Isle. `LFMapPresets.make(name)` returns new `LFMapParams` to change.
- The Inspector's names are the property names: `tile_size`, `tiles_x`, `tiles_z`, `props`
  (`LFTileBaker.Props.ALL / LARGE / NONE`), `prop_draw_distance`, `collision`, `edge_walls`,
  `terrain_layers`, `prop_layers`, `wall_layers`, `water_areas`, `water_layers`, `water_mask`,
  `flowing_rivers`. Everything else is on `params` (an `LFMapParams`).

## Params
`LFMapParams` holds the land. A few worth knowing (open the resource in the Inspector for all of them, each
with a tooltip):
```gdscript
var p := LFMapParams.new()
p.boundary = LFMapParams.Boundary.MOUNTAINS   # OPEN, ISLAND (the default) or MOUNTAINS
p.lake_count = 3
p.natural_lakes = false   # only the counted lakes
p.river_count = 2
baker.params = p
```
Save one with `ResourceSaver.save(p, "res://my_params.tres")` and load it back with `load()`.

A new `LFMapBaker` starts with one lake, one river and `natural_lakes` off (the Classic Island preset);
`LFMapParams.new()` on its own has natural lakes on and no counted lake. `river_count = 0` means no river.

## Rivers, lakes and snow
Each river springs high up (a mountain, the island's high ground or a lake) and runs through the lakes in
its path to the sea. Lakes and rivers up in the hills have their own water level, so ask for the level at
a spot rather than comparing with the sea's (0 m). A snow biome only covers high ground with `only_above`
(Frozen Highlands has it on): the ground above `snow_line` of the way from the lowlands to the highest peak:
```gdscript
var level := b.water_level_at(spawn_at)   # the water surface there (0 = the sea's level)
var wet := b.ground_at(spawn_at).w < level
var cold := LFMapPresets.make("Highland Island")
for biome in cold.biomes:
	if biome.name == "Frozen Highlands":
		biome.only_above = true   # snow only above the snow line
		biome.min_height = 20.0   # and never below 20 m
cold.snow_line = 0.3   # 0 = the lowlands, 1 = the highest peak
```
`LFTerrainGenerator.find_water(from, dir, reach)` (from `b.make_generator()`, in world space) finds the first open water along a direction (a fisher casting a line). `waterfalls()` lists the falls: `{position` (the lip, world space, y = the water's top), `bottom`, `direction`, `width}`; `LFWaterfall.build(fall, LFWaterfall.make_materials())` builds one's mesh.

## Cliffs
Mountains are built of rock layers: hard layers stand as cliff bands with scree below them, rock slabs stand in
the bands and boulders lie on the scree (all solid). The *Cliffs* settings in `LFMapParams` shape them; they
only show on mountains (`mountain_height` above 0):
```gdscript
var rocky := LFMapPresets.make("Badlands")   # mesas ringed by cliff bands
rocky.cliffs = 1.0   # 0 = smooth mountainsides, no cliffs
rocky.cliff_rocks = 0.5   # fewer rock slabs (0 = none)
rocky.rock_color = Color(0.6, 0.42, 0.32)   # the cliffs and their slabs
```
Then `baker.params = rocky`. The baked slabs are in the `rock` group, with the rocks' collision.

## Work on one tile, grow the map
`one_tile` + `work_tile` bake one tile and keep the rest. `add_west / add_east / add_north / add_south` with
`new_tiles_only` add tiles round a baked map without touching the old ones (keep the seed, params and
`tiles_x / tiles_z` as they were; the bake fails with `ERR_INVALID_DATA` if they changed).
```gdscript
b.one_tile = true
b.work_tile = Vector2i(1, 0)
var one := b.bake()
b.one_tile = false
b.add_east = 1
b.new_tiles_only = true
var grown := b.bake()
```

## Heightmap and map image
```gdscript
b.heightmap_step = 4.0
var hm := b.export_heightmap()   # writes heightmap_* to output_dir; {"error", "size_px", ...}
b.map_image_px = 128
var err := b.export_map_image()   # writes output_dir/map_image.png
```

## The ground before baking
`ground_at(p)` is the baked ground under a point (in the baker's space, the map's centre at the origin):
`Vector4(normal.x, normal.y, normal.z, height)`. `spawn_point()` is where the bake puts the `Spawn` marker.
```gdscript
var spawn_at := b.spawn_point()
var ground := b.ground_at(spawn_at)
var height := ground.w
```

## Stream the tiles in your game
Add an `LFTileStreamer` at the origin, set its `map_dir` and `target`, and await `load_around` behind a
loading screen:
```gdscript
var streamer := LFTileStreamer.new()
streamer.name = "LFTileStreamer"
streamer.map_dir = map_dir
streamer.target = player
streamer.load_distance = 600.0
add_child(streamer)
await $LFTileStreamer.load_around($LFTileStreamer.spawn_position())
player.global_position = $LFTileStreamer.spawn_position() + Vector3.UP
```
- `tile_loaded(x, z, tile)` / `tile_unloaded(x, z)`: hook up each tile's water areas, spawn things in it.
- `loaded_tiles()`, `tile_node(Vector2i)`, `tile_at(position)`, `is_ready_at(position)`, `is_loading()`,
  `reload_index()` (after a new bake), `unload_margin`, `check_every`, `load_edge`.
- A tile's nodes are freed with it: keep what must last (trees cut, pickups taken) in your save data.

Tiles that load later bring their own water areas:
```gdscript
streamer.tile_loaded.connect(func(_x: int, _z: int, tile: Node3D) -> void:
	for area in tile.find_children("WaterArea*", "Area3D", true, false):
		area.body_entered.connect(_on_enter_water)
		area.body_exited.connect(_on_leave_water))
```

## What's in a baked map
Groups (`LFTileBaker.GROUP_*`): `terrain`, `tree`, `rock`, `log`, `edge_wall`, `water` (each `WaterArea`,
its `water_level` meta the surface height) and `spawn` (the `Spawn` marker). `GUIDE.md` (*Using the map in your game*) has the snippets for each;
the file layout is in its *What a bake writes*.
