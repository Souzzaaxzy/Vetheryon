extends SceneTree

## Gera (bake) um mapa LowLand Forge e salva em res://maps/.
##   VETHERYON_LF_PRESET="Rolling Plains" godot --headless --script res://tools/bake_map.gd
##
## Presets: Classic Island, Highland Island, Mountain Valley, Rolling Plains,
## Deep Forest, Badlands, Frozen Isle.

func _initialize() -> void:
	_run()


func _run() -> void:
	var preset := OS.get_environment("VETHERYON_LF_PRESET")
	if preset == "":
		preset = "Rolling Plains"
	var seedv := int(OS.get_environment("VETHERYON_LF_SEED"))
	if seedv == 0:
		seedv = 20261104
	var out_dir := OS.get_environment("VETHERYON_LF_OUT")
	if out_dir == "":
		out_dir = "res://maps/world"
	var tiles := int(OS.get_environment("VETHERYON_LF_TILES"))
	if tiles <= 0:
		tiles = 2

	var baker := LFMapBaker.new()
	baker.auto_preview = false
	baker.map_seed = seedv
	baker.params = LFMapPresets.make(preset)
	# Menos props = muito mais leve (o vilarejo fica numa area plana do mapa).
	var dens := float(OS.get_environment("VETHERYON_LF_DENSITY"))
	if dens <= 0.0:
		dens = 0.35
	baker.params.prop_density = dens
	baker.params.tree_density = dens
	baker.params.rock_density = dens
	baker.params.ground_cover_density = dens * 0.5
	baker.tile_size = 512
	baker.tiles_x = tiles
	baker.tiles_z = tiles
	baker.props = LFTileBaker.Props.LARGE
	baker.output_dir = out_dir
	var info: Dictionary = baker.bake()
	print("BAKE preset=", preset, " seed=", seedv, " density=", dens, " info=", info)
	baker.free()
	quit()
