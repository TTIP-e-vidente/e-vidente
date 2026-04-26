# Sprite Production Pipeline (Godot 4.x)

Practical workflow to produce high-quality sprites efficiently and integrate them with Godot scenes.

## Goals

- Keep visual quality consistent across chapters and features.
- Reduce rework by defining a repeatable art-to-engine pipeline.
- Keep runtime fast on desktop and web.
- Prefer scene and resource authoring over script-side visual hardcoding.

## 1) Source Asset Strategy

Use a clear source-of-truth convention before importing:

- Keep editable source files outside runtime folders (for example, `source_art/`).
- Export final runtime textures into `assets/` with stable names.
- Use naming that encodes role and state:
  - `char_chef_idle_01.png`
  - `ui_btn_primary_default.png`
  - `food_bread_slice_gluten.png`

Recommended consistency rules:

- One pixel density target per project area.
- Shared pivot convention (feet for characters, center for items, top-left for UI slices).
- Explicit frame sizing for animation sheets.

## 2) Scene-First Visual Assembly

Build visuals in `.tscn` and resources first, not in GDScript.

Preferred node/resource stack:

- Static visuals: `Sprite2D` with configured texture and offsets.
- Frame animation: `AnimatedSprite2D` + `SpriteFrames` resource.
- Timeline animation: `AnimationPlayer` driving sprite frame, modulation, position, scale.
- Sprite sheet slicing: `AtlasTexture` resources for reusable regions.
- Tile workflows: `TileSet` and `TileMap` for repeatable environment pieces.

Good practice:

- Reuse visual prefabs (`PackedScene`) for repeated items/icons.
- Keep script logic focused on state transitions (play animation, toggle visible), not color/font/layout styling.

## 3) Import Presets That Save Time

Create import presets for predictable results:

- Pixel-art assets:
  - Filter: Off
  - Mipmaps: Off
  - Repeat: Disabled unless needed
- Hand-painted/high-res assets:
  - Filter: On
  - Mipmaps: On for camera zoom-outs
- UI icon sheets:
  - Lossless where text/icons must stay crisp
  - Avoid oversized textures for tiny UI elements

Web-focused guidance:

- Prefer PNG/WebP source exports with tight alpha bounds.
- Avoid huge transparent margins; trim before import.
- Keep atlas dimensions power-of-two when practical.

## 4) Atlas and Reuse Workflow

For many related sprites, prefer atlases:

1. Group by usage domain (UI, character set, chapter, map).
2. Build atlas textures with deterministic packing.
3. Reference slices with `AtlasTexture` resources.
4. Reuse slices across scenes to reduce duplicated files.

Benefits:

- Fewer texture binds.
- Easier consistency of icon families.
- Lower maintenance for style updates.

## 5) Animation Ownership Rules

Avoid mixed responsibility between scene and code.

- Scene/resource owns visual setup (frames, timing, transitions where possible).
- Script owns gameplay intent (state changed -> play animation key).

Minimal script example:

```gdscript
func set_state(new_state: State) -> void:
    current_state = new_state
    match new_state:
        State.IDLE:
            animated_sprite.play("idle")
        State.WALK:
            animated_sprite.play("walk")
        State.HIT:
            animated_sprite.play("hit")
```

## 6) Performance Checklist (Especially for Web)

- Prefer atlases over many small loose textures.
- Remove unused frames and duplicate near-identical assets.
- Avoid runtime `load()` loops for frequently used sprites.
- Preload critical scenes/resources used every run.
- Use object pooling for short-lived VFX sprites.
- Verify overdraw-heavy layers on mobile.

## 7) Done Criteria For Each New Sprite Set

A sprite task is complete only if all are true:

- Visuals are integrated through `.tscn` and resources.
- Import settings are verified for target platform.
- No style constants are buried in gameplay scripts.
- Reusable pieces are extracted into scenes/resources.
- At least one smoke run validates loading on headless/web target path.
