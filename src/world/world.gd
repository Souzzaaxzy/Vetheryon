extends Node3D

## Mundo do Vetheryon: streaming de chunks (tiles) do mapa LowLand Forge.
##
## Cada tile (512 m) é carregado/descarregado conforme o jogador se move, então o
## celular nunca tem o mundo inteiro na memória. Espelha o sistema de "chunks".

@export var map_dir: String = "res://maps/world"
## Distância para carregar um tile vizinho (512 m) — precisa ser > tile_size para
## o mundo continuar aparecendo conforme o jogador anda.
@export var load_distance: float = 300.0
@export var unload_margin: float = 120.0
@export var player_path: NodePath

var _streamer: LFTileStreamer
var _player: Node3D


func _ready() -> void:
	_player = get_node_or_null(player_path)
	_streamer = LFTileStreamer.new()
	_streamer.name = "LFTileStreamer"
	_streamer.map_dir = map_dir
	_streamer.load_distance = load_distance
	_streamer.unload_margin = unload_margin
	_streamer.check_every = 0.3
	_streamer.load_edge = false
	add_child(_streamer)

	# Coloca o jogador no spawn marcado pelo bake.
	await _streamer.load_around(_streamer.spawn_position())
	if _player:
		_player.global_position = _streamer.spawn_position() + Vector3(0, 2, 0)
	print("WORLD ready spawn=", _streamer.spawn_position())
