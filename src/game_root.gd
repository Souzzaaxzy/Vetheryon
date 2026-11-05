extends Node3D

## Raiz do jogo: liga a tela inicial, a tela de carregamento, o menu de pausa e o
## inventário (hotbar + mochila).
##
## Fluxo:
##   1. Tela inicial ("TOQUE PARA ENTRAR") — o jogo começa pausado.
##   2. Ao tocar, aparece a tela de carregamento enquanto o mundo é gerado.
##   3. Quando o mundo fica pronto, a engrenagem e a hotbar são habilitadas.
##   4. "Salvar e sair" grava o mundo e volta para a tela inicial.

@export var loading_min_time: float = 0.9

var _world: Node
var _player: Node3D
var _start: CanvasLayer
var _loading: CanvasLayer
var _pause: CanvasLayer
var _touch: CanvasLayer
var _inv: Node
var _hotbar: CanvasLayer
var _inv_screen: CanvasLayer


func _ready() -> void:
	_world = get_node_or_null("World")
	_player = get_node_or_null("Player")
	_start = get_node_or_null("StartScreen")
	_loading = get_node_or_null("LoadingScreen")
	_pause = get_node_or_null("PauseMenu")
	_touch = get_node_or_null("TouchControls")
	_inv = get_node_or_null("Inventory")
	_hotbar = get_node_or_null("Hotbar")
	_inv_screen = get_node_or_null("InventoryScreen")

	# Liga o inventário à mão do jogador, à hotbar e à mochila.
	if _player and _player.has_node("Hand"):
		var hand := _player.get_node("Hand")
		hand.set_inventory(_inv)
		hand.world = _world
	if _hotbar:
		_hotbar.set_inventory(_inv)
		_hotbar.set_enabled(false)
		_hotbar.backpack_pressed.connect(_open_backpack)
		_hotbar.place_pressed.connect(_place_torch)
	if _inv_screen:
		_inv_screen.set_inventory(_inv)

	if _loading:
		_loading.visible = false
	if _pause:
		_pause.set_enabled(false)
	if _start:
		_start.entered.connect(_on_entered)
	if _pause:
		_pause.exit_requested.connect(_on_exit)
		_pause.save_requested.connect(_on_save)


func _on_entered() -> void:
	# Devolve o jogador ao ponto salvo ANTES de carregar, para os chunks gerarem
	# em volta de onde ele parou.
	_restore_save()
	_run_loading()


func _run_loading() -> void:
	if _loading:
		_loading.visible = true
		_loading.set_progress(0.0, "Preparando o terreno...")
	if _touch:
		_touch.visible = false
	if _hotbar:
		_hotbar.set_enabled(false)
	var t0 := Time.get_ticks_msec()
	while _world != null and not _world.is_ready():
		var p: float = _world.loading_progress()
		if _loading:
			_loading.set_progress(p, _status_for(p))
		await get_tree().process_frame
	if _loading:
		_loading.set_progress(1.0, "Pronto!")
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	if elapsed < loading_min_time:
		await get_tree().create_timer(loading_min_time - elapsed).timeout
	if _loading:
		_loading.finish()
	if _touch:
		_touch.visible = true
	if _pause:
		_pause.set_enabled(true)
	if _hotbar:
		_hotbar.set_enabled(true)


func _status_for(p: float) -> String:
	if p < 0.35:
		return "Gerando o terreno..."
	elif p < 0.7:
		return "Plantando as árvores..."
	return "Construindo as vilas..."


## Se houver um save para esta seed, devolve o jogador para onde ele parou.
func _restore_save() -> void:
	if _world == null or _player == null:
		return
	var pos: Variant = SaveGame.saved_player(_world.world_seed)
	if pos != null:
		_player.global_position = pos


func _on_save() -> void:
	_save_world()


func _on_exit() -> void:
	_save_world()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _save_world() -> void:
	if _world == null or _player == null:
		return
	SaveGame.save(_world.world_seed, _player.global_position)


func _open_backpack() -> void:
	if _inv_screen:
		_inv_screen.open()


func _place_torch() -> void:
	if _player and _player.has_node("Hand"):
		_player.get_node("Hand").place_torch(_player)
