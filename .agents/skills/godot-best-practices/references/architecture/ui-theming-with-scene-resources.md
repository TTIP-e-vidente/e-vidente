# UI Theming Without Hardcoded Styles

How to keep UI styling in Godot editor resources/scenes instead of GDScript constants.

## Principle

Use scripts for behavior and state, not for visual definition.

- Behavior: enabled/disabled, selected, loading, progress.
- Visual definition: colors, fonts, paddings, borders, corner radius, icon assignment.

Visual definition should live in:

- `Theme` resources (`.tres`)
- `StyleBox` resources (`StyleBoxFlat`, `StyleBoxTexture`)
- Reusable UI scenes (`.tscn`)

## Recommended UI Stack

- Root UI scene with a project theme assigned.
- Reusable UI component scenes:
  - `PrimaryButton.tscn`
  - `CardPanel.tscn`
  - `InfoBadge.tscn`
- Theme variations by control type and state.

Example structure:

```
ui/
├── themes/
│   ├── app_theme.tres
│   ├── buttons/
│   └── panels/
├── components/
│   ├── primary_button.tscn
│   ├── primary_button.gd
│   ├── info_card.tscn
│   └── info_card.gd
└── screens/
    ├── main_menu.tscn
    └── level_summary.tscn
```

## What Scripts Should Do

Allowed in GDScript:

- Connect signals.
- Switch theme type variation names.
- Set text/icon content from data.
- Toggle visibility or play transitions.

Avoid in GDScript:

- `label.add_theme_color_override(...)` as default style strategy.
- Repeating color/font constants in multiple scripts.
- Building layout metrics in code when containers can do it.

## Theme-First Example

1. In `app_theme.tres`, define styleboxes/colors/fonts for:
   - `Button` states (normal, hover, pressed, disabled)
   - `Panel` variants
   - `Label` typography scale
2. In `PrimaryButton.tscn`, set `theme_type_variation = "PrimaryButton"`.
3. In script, only bind text/callback and optional state changes.

```gdscript
class_name PrimaryButton
extends Button

func set_loading(is_loading: bool) -> void:
    disabled = is_loading
    text = "Cargando..." if is_loading else "Continuar"
```

## Scene Composition For UI

Prefer containers over manual positioning:

- `MarginContainer` for outer spacing.
- `VBoxContainer` and `HBoxContainer` for flow.
- `GridContainer` for repeated cards/buttons.
- `Control` anchors for responsive behavior.

This removes many layout constants from scripts and improves maintainability.

## State-Driven Styling (Without Hardcoded Colors)

For state visuals, use one of:

- Theme variations (`theme_type_variation`).
- AnimationPlayer tracks over modulate/scale/alpha.
- Pre-authored alternative scenes for major variants.

Avoid direct per-frame style mutation except for temporary effects.

## Review Checklist

- Is style defined in Theme/StyleBox, not scattered in scripts?
- Are reusable UI pieces extracted into component scenes?
- Are containers/anchors handling layout instead of manual offsets?
- Can a designer restyle a screen without touching gameplay code?
- Are state transitions represented by scene resources or animation tracks?
