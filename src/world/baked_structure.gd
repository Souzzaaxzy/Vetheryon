class_name BakedStructure
extends Resource

## Uma construção já "cozida": todas as malhas do glTF fundidas numa só (por
## material), com UV/normal/tangente preservados, e a casca de colisão exata
## (ConcavePolygonShape3D, triângulo a triângulo) no mesmo espaço local.
##
## É o que o StructureManager guarda em memória e no cache de disco — assim o
## custo de fundir a malha é pago UMA vez por tipo de construção, não a cada
## vez que uma instância entra na tela.

@export var mesh: ArrayMesh
@export var shape: ConcavePolygonShape3D
## Escala sugerida quando a entrada não traz uma (dimensionada pela porta).
@export var default_scale: float = 1.0
@export var faces: int = 0
