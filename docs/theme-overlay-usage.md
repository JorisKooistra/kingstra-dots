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
  - Ornament overlays via `OrnamentLayer.qml` (top-left, top-right, center optioneel).
  - Cyber divider/grid als code-generated 1-2px lijnen in `CyberBar.qml` (geen verplicht asset).
  - Particle layer via `ParticleLayer.qml` (fireflies / space-specks).
  - Animated: blur-first stijl; overlay is optioneel en niet verplicht.
- Widget/popup skins (`config/quickshell/widgets/skins/*WidgetSkin.qml`):
  - Lichte texture/ornament accenten op panel/rand/header.
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
- Ornament/effect lagen mogen interactie niet blokkeren.
- Ontbrekende assets geven warning, nooit crash.
- Animated hoeft geen extra texture-overlay te hebben; blur-only is toegestaan.
