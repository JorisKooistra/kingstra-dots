# Changelog

Versions follow `YYYY.MM.N` (year, month, release within that month). The current version is in `VERSION`.

## Unreleased

### Shell: keyboard menu
- Super+Alt+Space (or `kingstra menu`) opens one keyboard menu for everything, like Omarchy's: apps, appearance (theme, wallpaper), mode, quick toggles, screens, capture, system (update, doctor, restore point, restart) and session. Arrows or 1-9 choose, Enter or → opens, ← goes back, typing filters.

### Shell: notifications
- The control center groups notifications per app, newest app first; the cross on an app's row clears that app.
- Notifications that support it (chat apps) get an answer field in the notifications panel; Enter sends the reply.

### Shell: launcher prefixes
- The launcher understands a first character, like Caelestia and DMS: `=` calculator (Enter copies), `>` shell command (terminal or background), `:` emoji search (Enter copies, Dutch words like `:hart` work), `/` jump to a setting, `?` search DuckDuckGo, Arch Wiki or Wikipedia, `@` switch to an open window.
- An empty launcher shows the prefixes as chips; click one to start.
- The setting index now lives in `settings/SettingIndex.js`, shared by the settings app and the launcher; `open settings thema/fonts` also picks the theme-editor tab.

### Shell: control center
- The panel that grows from the top edge is now a control center (Super+A, or click the status tile in the rail): quick toggles, volume and brightness, time, month and next appointment, system load, media, notifications and screen time in one place.
- Toggles work like GNOME's quick settings: click to switch, the arrow expands the pill in place (Wi-Fi networks, Bluetooth devices, power profiles) with a link to the full panel.
- Notifications live in the control center: click runs the app's action, the cross dismisses, "Wis alles" clears; the arrow still opens the full notifications panel.
- Opened by hover on the top edge it closes when you move away; opened by click or Super+A, or once you click inside, it stays open until Esc or a click outside.
- The old Snelle instellingen panel stays available through `qs_manager.sh toggle quicksettings`; `kingstra quick` now opens the control center.

### Shell: settings as a real app
- Settings opens as its own floating window instead of a drawer beside the rail: move it, tile it next to an app, open it on any screen, and it stays open when you click elsewhere. Super+, (new) and Super+Ctrl+I toggle it.
- Search finds individual settings (blur, scroll speed, idle lock, ...) and jumps to the right page and theme-editor tab.
- Deep links: `kingstra settings <page>` or `qs_manager.sh open settings <page>` (thema, bar, sneltoetsen, invoer, beeldschermen, netwerk, geluid, tijd, sessie, updates, geavanceerd, over). The launcher's Thema action opens the Thema page.

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

- `kingstra-shell-watch` restarts the bar, popups or overview after a crash (at most 3 times per 10 minutes, then a notification instead of a restart loop).
- The update badge stays off while the dotfiles are held after a rollback.
- A one-time welcome after a fresh install: the five key shortcuts and the shortcut overview (`kingstra welcome` shows it again).

### Simpler
- SwayNC leftovers removed (config, color template, theme CSS, stop calls); migrations stop it and clean the Matugen config once.
- One launcher: the search buttons open the Quickshell launcher; Walker and Elephant no longer run as background services.
- The old music and volume popups (about 2,900 lines) are gone; every route already opened Sound & media.
- `installer/profiles/` replaced by `installer/overrides.example.conf`; `~/.config/kingstra/overrides.conf` is read on every install and update.

### Styling
- Opening animations of Battery, Focus time, Monitors and Settings shortened from 1–1.8 s to about half a second, without the springy overshoot; they now follow the animation speed setting.
- Motion profiles "snappy" (neon) and "calm" (paper) now actually change the tempo.
- Rail in three groups: navigation on top (launcher, workspaces), notifications and status in the middle, system at the bottom with the clock.
- Status strip: the clock in the middle opens the calendar; the separate Agenda button is gone.
- The updates button only shows when there are updates.
- A panel that fails to load shows a clear message with `kingstra doctor` instead of a placeholder.
- Panels and popups use the theme's mono font (`ThemeConfig.textFont`, ~430 places) instead of a fixed font name, with JetBrains Mono as fallback when the theme font is not installed. Nerd icons use `ThemeConfig.iconFont`.
- About 450 hover and state animations in panels follow the theme's motion speed (`ThemeConfig.duration`), like the rail already did.
- `ttf-ibm-plex` is installed for the paper theme.
- Battery and network popups use the theme text color for their glass overlays instead of fixed white, so they show up on the light paper theme too.

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
