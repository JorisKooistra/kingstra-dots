# Changelog

Versions follow `YYYY.MM.N` (year, month, release within that month). The current version is in `VERSION`.

## 2026.10.0 — 2026-10-27

First versioned release. Highlights since the Lua migration:

### Shell
- Quick settings, status tile, system tray and a richer dashboard (Overview and System tabs).
- Sound & media: volume panel and music popup merged into one audio panel, with equalizer presets.
- Notifications: pop-ups next to the rail, a counter on the rail, grouping per app, do-not-disturb.
- Agenda: compact panel with local events and hourly weather.
- Settings: eight Dutch tabs with a search field.
- Focus and Monitors moved out of the rail to the dashboard and Quick settings.
- Workspace overview: one screen, fixed grid, fade in and out, close with the mouse.
- Removed: mail panel, the Today tab, the Stewart overlay, unused alternative network and battery popups.

### Windows
- Floating apps remember their size and position per app; `Super + T` remembers floating per app.
- Floating windows get a subtle border.

### Hardware
- Logitech M720 thumb button: drag windows, double-click for the overview; keeps working after restart, sleep and reconnect.

### Installer and updates
- Compact installer and updater view with a fixed header and progress bar.
- Package overview with weekly cache cleanup; loose files no longer block a dotfiles update.
- CI: smoke tests, ShellCheck and qmllint on every push.

### Lockscreen
- Typed password characters are hidden by default.

### Docs
- Old planning documents for the six previous themes moved to `docs/archief/`.
