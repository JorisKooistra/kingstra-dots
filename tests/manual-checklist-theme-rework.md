# Manual checklist - Theme rework

## 1) Theme -> Mode (office/gaming/media)
- [ ] Zet theme op `botanical`, wissel mode naar `office`, controleer modules en autohide-gedrag.
- [ ] Zet theme op `botanical`, wissel mode naar `gaming`, controleer modules en autohide-gedrag.
- [ ] Zet theme op `botanical`, wissel mode naar `media`, controleer modules en autohide-gedrag.
- [ ] Herhaal bovenstaande voor `rocky`, `ocean`, `space`, `cyber`, `animated`.

## 2) Mode -> Theme
- [ ] Start in mode `office`, wissel themes door alle 6 varianten; controleer dat mode-gedrag (modules/autohide) intact blijft.
- [ ] Start in mode `gaming`, wissel themes door alle 6 varianten; controleer dat mode-gedrag intact blijft.
- [ ] Start in mode `media`, wissel themes door alle 6 varianten; controleer dat mode-gedrag intact blijft.
- [ ] Controleer expliciet: mode-wissel reset theme niet naar default.

## 3) Wallpaper -> Theme
- [ ] Kies een actief theme (bijv. `rocky`) en wissel wallpaper 3x.
- [ ] Controleer dat `bar_shape`, ornaments en `clock_style` gelijk blijven aan het actieve theme.
- [ ] Controleer dat alleen palette/kleuren veranderen via Matugen.

## 4) Missing assets fallback
- [ ] Verwijder tijdelijk een ornament-bestand van actief theme en run `kingstra-theme-switch <theme>`.
- [ ] Verwacht: warning in script, UI blijft werken, geen crash.
- [ ] Verwijder tijdelijk terminal overlay-bestand en herhaal.
- [ ] Verwacht: warning in script, theme-switch slaagt, geen crash.

## 5) Kern flows
- [ ] `kingstra-theme-switch botanical` werkt en update `~/.config/quickshell/theme.json`.
- [ ] `kingstra-theme-switch rocky` werkt en update `~/.config/quickshell/theme.json`.
- [ ] `kingstra-mode-switch office/gaming/media` werkt met correcte modulelijst.
- [ ] `TopBar.qml` blijft entrypoint en laadt `bar/BarShell.qml`.

## 6) Installatiepad (schone machine)
- [ ] Voer bootstrap uit vanaf GitHub op schone omgeving.
- [ ] Controleer dat nieuwe paden aanwezig zijn:
  - `config/quickshell/bar/`
  - `config/quickshell/clock/`
  - `config/quickshell/widgets/skins/`
  - `assets/themes/*`
- [ ] Controleer dat theme/mode/wallpaper switch daarna werken.
