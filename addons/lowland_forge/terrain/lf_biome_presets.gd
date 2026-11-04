@tool
class_name LFBiomePresets
extends RefCounted
## Ready-made biomes beyond the four defaults (LFBiomeDef.defaults()): add them to LFMapParams.biomes, alone
## (a single-biome map) or next to the defaults (each takes the climate it scores best in). Each call builds
## a fresh LFBiomeDef, so tweaking one never changes another map's.
##
##   var p := LFMapParams.new()
##   p.biomes.append(LFBiomePresets.make("Desert"))

## Every preset's name, in a stable order.
const NAMES: Array[String] = ["Desert", "Palm Coast", "Frozen Highlands", "Ash Barrens", "Drowned Marsh"]


## A new preset biome by name (case and `_` / `-` for spaces don't matter), or null if there is none.
static func make(biome_name: String) -> LFBiomeDef:
	match biome_name.to_lower().replace("_", " ").replace("-", " "):
		"desert":
			return desert()
		"palm coast":
			return palm_coast()
		"frozen highlands":
			return frozen_highlands()
		"ash barrens":
			return ash_barrens()
		"drowned marsh":
			return drowned_marsh()
	return null


## Every preset, freshly built, in NAMES order.
static func all() -> Array[LFBiomeDef]:
	var out: Array[LFBiomeDef] = []
	for n in NAMES:
		out.append(make(n))
	return out


# --- hot ----------------------------------------------------------------------


## Hot and dry: sand, cacti, dry scrub, scattered rocks.
static func desert() -> LFBiomeDef:
	var K := LFPropMeshes.Kind
	var b := _make("Desert", 1.6, -1.6, -0.6, Color(0.80, 0.64, 0.38))
	b.surface = &"sand"
	b.clearings = false
	b.trees = [LFPropRule.make(K.CACTUS, 0.03), LFPropRule.make(K.PALM, 0.0008, {"from_top": true})]
	b.plants = [LFPropRule.make(K.DRY_BUSH, 0.07), LFPropRule.make(K.GRASS, 0.02, {"river_bonus": true})]
	b.rock_chance = 0.25
	b.dryness = 1.0
	return b


## Hot and wet: palms over pale grass and flowering bushes.
static func palm_coast() -> LFBiomeDef:
	var K := LFPropMeshes.Kind
	var b := _make("Palm Coast", 1.4, 0.8, -0.35, Color(0.42, 0.64, 0.24))
	b.trees = [LFPropRule.make(K.PALM, 0.13, {"scale_min": 0.85, "scale_max": 1.25}), LFPropRule.make(K.BROAD, 0.003, {"from_top": true})]
	b.plants = [LFPropRule.make(K.GRASS, 0.35, {"river_bonus": true}), LFPropRule.make(K.FERN, 0.08, {"river_bonus": true}),
			LFPropRule.make(K.BUSH, 0.06), LFPropRule.make(K.FLOWER, 0.08, {"patchy": true})]
	b.rock_chance = 0.12
	b.berry_habitat = 0.2
	b.dryness = 0.3
	return b


# --- cold and dead ------------------------------------------------------------


## Cold: snow ground, snow-laden pines, rocks.
static func frozen_highlands() -> LFBiomeDef:
	var K := LFPropMeshes.Kind
	var b := _make("Frozen Highlands", -3.0, 0.0, -0.9, Color(0.88, 0.90, 0.94))
	b.surface = &"snow"
	b.only_above = true   # snow on the heights, not in patches beside the pines
	b.trees = [LFPropRule.make(K.SNOW_PINE, 0.18)]
	b.plants = [LFPropRule.make(K.GRASS, 0.03), LFPropRule.make(K.DRY_BUSH, 0.02)]
	b.rock_chance = 0.35
	b.dryness = 0.8
	return b


## Burnt land: grey ash, dead trees, dry scrub, the odd crystal.
static func ash_barrens() -> LFBiomeDef:
	var K := LFPropMeshes.Kind
	var b := _make("Ash Barrens", 0.5, -2.2, -0.5, Color(0.27, 0.25, 0.24))
	b.surface = &"rock"
	b.clearings = false
	b.trees = [LFPropRule.make(K.DEAD, 0.09)]
	b.plants = [LFPropRule.make(K.DRY_BUSH, 0.03), LFPropRule.make(K.CRYSTAL, 0.0006)]
	b.rock_chance = 0.5
	b.rock_size_bias = 1.8
	b.log_chance = 0.05
	b.dryness = 1.0
	return b


# --- wet ----------------------------------------------------------------------


## Waterlogged lowland: willows, reeds, mud, rotting logs and mushrooms.
static func drowned_marsh() -> LFBiomeDef:
	var K := LFPropMeshes.Kind
	var b := _make("Drowned Marsh", -0.2, 1.8, -0.4, Color(0.22, 0.26, 0.12))
	b.surface = &"mud"
	b.trees = [LFPropRule.make(K.WILLOW, 0.1, {"scale_min": 1.0, "scale_max": 1.5}),
			LFPropRule.make(K.DEAD, 0.05, {"from_top": true})]
	b.plants = [LFPropRule.make(K.REEDS, 0.6, {"river_bonus": true, "patchy": true}),
			LFPropRule.make(K.GRASS, 0.12, {"river_bonus": true}),
			LFPropRule.make(K.MUSHROOM, 0.03, {"patchy": true}), LFPropRule.make(K.FERN, 0.04)]
	b.rock_chance = 0.05
	b.log_chance = 0.3
	b.log_mushroom_bonus = 0.5
	b.mushroom_habitat = 0.8
	return b


static func _make(n: String, heat: float, wet: float, common: float, col: Color) -> LFBiomeDef:
	var b := LFBiomeDef.new()
	b.name = n
	b.likes_heat = heat
	b.likes_wet = wet
	b.commonness = common
	b.ground_color = col
	return b
