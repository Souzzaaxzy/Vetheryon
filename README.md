# Vetheryon

Sandbox medieval de fantasia 3D — Android, Godot 4.7 (renderizador Mobile).

> **Status:** Fase 1 — fatia vertical jogável (mundo + personagem + câmera + controles).
> Documento de design completo em [`docs/design/Vetheryon.md`](docs/design/Vetheryon.md).

## O que já funciona

- Mundo procedural **infinito por chunks** (128 m): gerado em runtime com o
  gerador do LowLand Forge, numa thread por chunk. Mantém **5 chunks em cruz**
  (o do jogador + 4 vizinhos); o que sai é liberado e, ao voltar, é gerado de
  novo (mesma seed = mesmo terreno).
- Terreno com relevo, cores por bioma, rios/lagos e colisão por *heightmap*.
- Árvores e rochas via *MultiMesh* (milhares de instâncias sem travar), **com
  colisão** nos troncos, pedras e troncos caídos (o jogador não atravessa).
- Personagem jogável (CharacterBody3D): andar, correr, pular, gravidade.
- Câmera 1ª/3ª pessoa com alternância (`F`), movimento relativo à câmera.
- Controles touchscreen (joystick virtual + botões) para Android.
- Céu procedural, sol e neblina.
- Tela de entrada com a arte de abertura e o botão "TOQUE PARA ENTRAR".
- Export de APK Android assinado (debug).

## Estrutura

```
src/
├── player/     player.gd, camera_rig.gd, player.tscn
├── world/      vetheryon_world.gd, main.tscn
└── ui/         touch_controls.gd, hud.gd, start_screen.gd
addons/lowland_forge/   gerador procedural + shaders (MIT)
```

## Rodar localmente

```bash
source /workspace/env.sh
godot --path /workspace/vetheryon                 # desktop
godot --headless --path /workspace/vetheryon --export-debug Android build/vetheryon.apk
```

Screenshot automatizado (headless/Xvfb):

```bash
VETHERYON_SCREENSHOT=/tmp/shot.png xvfb-run -a godot --path /workspace/vetheryon --rendering-driver opengl3
```

## Controles

| Ação | Desktop | Android |
|---|---|---|
| Mover | WASD | joystick esquerdo |
| Correr | Shift | botão CORRER |
| Pular | Espaço | botão PULAR |
| Câmera 1ª/3ª | F | botão CÂM |

## CI

`.github/workflows/build-apk.yml` compila o APK de debug a cada push na `main`
e publica como artefato `vetheryon-debug-apk`.
