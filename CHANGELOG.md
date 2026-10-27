# Changelog

Versions follow `YYYY.MM.N` (year, month, release within that month). The current version is in `VERSION`.

## Unreleased

### Safety net
- Every update first makes a restore point: a local git tag of the dotfiles and, on btrfs with snapper, a system snapshot (`kingstra-snapshot`).
- `kingstra-rollback` puts the dotfiles back to the last restore point and holds them there until `kingstra-rollback --release`.
- One-time migrations in `installer/migrations/` replace cleanup that ran on every update.
- `kingstra-doctor` checks the installation (programs, links, Lua, colors, Quickshell, services, disk, .pacnew) and says how to fix problems.
- The install marker records the installed version.
- Your own edits to tracked files are set aside during an update and put back; on a clash the dotfiles stay on the old version.

### Ease of use
- `kingstra` command: theme, mode, wallpaper, update, doctor, snapshot, rollback, refresh, restart, settings, keys, version.
- `kingstra refresh <part>` puts one config back to the repo default, with a backup first.
- `config/hypr/lua/user.lua` for personal binds, rules and settings: not tracked, loads last, errors are caught.

### Simpler
- SwayNC leftovers removed (config, color template, theme CSS, stop calls); migrations stop it and clean the Matugen config once.
- One launcher: the search buttons open the Quickshell launcher; Walker and Elephant no longer run as background services.
- `installer/profiles/` replaced by `installer/overrides.example.conf`; `~/.config/kingstra/overrides.conf` is read on every install and update.

### Styling
- Panels and popups use the theme's mono font (`ThemeConfig.textFont`, ~430 places) instead of a fixed font name, with JetBrains Mono as fallback when the theme font is not installed. Nerd icons use `ThemeConfig.iconFont`.
- About 450 hover and state animations in panels follow the theme's motion speed (`ThemeConfig.duration`), like the rail already did.
- `ttf-ibm-plex` is installed for the paper theme.

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
