# Vetheryon

Sandbox medieval de fantasia 3D — Android, Godot 4.7 (renderizador Mobile).

> **Status:** Fase 1 — fatia vertical jogável (mundo + personagem + câmera + controles).
> Documento de design completo em [`docs/design/Vetheryon.md`](docs/design/Vetheryon.md).

## O que já funciona

- Terreno procedural (FastNoiseLite) com relevo, cores por altitude e colisão por *heightmap*.
- Personagem jogável (CharacterBody3D): andar, correr, pular, gravidade.
- Câmera 1ª/3ª pessoa com alternância (`F`), movimento relativo à câmera.
- Controles touchscreen (joystick virtual + botões) para Android.
- Céu procedural, sol com sombras e neblina.
- Export de APK Android assinado (debug).

## Estrutura

```
src/
├── player/     player.gd, camera_rig.gd, player.tscn
├── world/      terrain.gd, main.tscn
└── ui/         touch_controls.gd, hud.gd
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
