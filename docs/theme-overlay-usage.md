# Theme Overlay Usage

Dit document legt vast waar overlays worden gebruikt in de theme-skin rework.

## Scope
- Primair: Quickshell topbar surface.
- Secundair: Quickshell widget/popup skins.
- Optioneel: terminal visual overlay.
- Buiten scope: Hyprland, Walker, SwayNC, andere apps.

## Overlay Mapping Per Component
- Topbar surface (`config/quickshell/bar/BarSurface.qml`):
  - Texture overlay per theme (`texture-overlay.png`).
  - Runtime via `theme.json` veld `texture_overlay_asset` (en `material.texture_asset`).
  - Fallback bij leeg pad: `~/kingstra-dots/assets/themes/<theme>/texture-overlay.png`.
  - Cyber divider/grid als code-generated 1-2px lijnen in `CyberBar.qml` (geen verplicht asset).
  - Particle layer via `ParticleLayer.qml` (fireflies / space-specks).
  - Animated: blur-first stijl; overlay is optioneel en niet verplicht.
- Widget/popup skins (`config/quickshell/widgets/skins/*WidgetSkin.qml`):
  - Lichte texture-accenten op panel/rand/header.
  - Nooit als volle content-overlay over tekst.
- Terminal (pipeline via `terminal_visual`):
  - `terminal_overlay_asset` + `terminal_overlay_opacity`.
  - Safe no-op als asset ontbreekt of leeg is.

## Runtime Asset Locaties
- Definitieve runtime assets horen onder:
  - `assets/themes/botanical/`
  - `assets/themes/ocean/`
  - `assets/themes/rocky/`
  - `assets/themes/space/`
  - `assets/themes/cyber/`
  - `assets/themes/animated/`
- Input-bestanden in `aanleveringen/` zijn bronmateriaal en niet het eindpad.

## Sfeerimpressie In Plaats Van Moodboard
- Er is geen apart moodboard nodig.
- Gebruik per theme de bestaande preview-afbeelding als sfeerimpressie:
  - `config/kingstra/themes/previews/botanical.jpg`
  - `config/kingstra/themes/previews/ocean.jpg`
  - `config/kingstra/themes/previews/rocky.jpg`
  - `config/kingstra/themes/previews/space.jpg`
  - `config/kingstra/themes/previews/cyber.jpg`
  - `config/kingstra/themes/previews/animated.jpg`

## Guardrails
- Overlays blijven subtiel en mogen leesbaarheid niet breken.
- Effectlagen mogen interactie niet blokkeren.
- Ontbrekende assets geven warning, nooit crash.
- Animated hoeft geen extra texture-overlay te hebben; blur-only is toegestaan.

## Matugen Bron Van Waarheid
- Doelgedrag: kleuren = `actieve wallpaper` + `actief theme matugen-profiel`.
- Theme-selectie bepaalt altijd het profiel:
  - `scheme_type`
  - `mode`
  - `color_index`
- Wallpaper-selectie (ook via `skwd-wall`) bepaalt alleen de bronafbeelding.
- Centrale apply-pad:
  - `apply-shell-state` synchroniseert eerst `~/.config/matugen/config.toml` vanuit `~/.config/quickshell/theme.json`.
  - Daarna draait `kingstra-matugen-run` op de gekozen wallpaper.
- `skwd-wall` wordt op Kingstra-paden gehard met:
  - `features.matugen=false` (geen los tweede matugen-pad)
  - scheme/mode sync met actief theme.
