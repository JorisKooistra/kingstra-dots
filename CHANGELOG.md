# Changelog

Versions follow `YYYY.MM.N` (year, month, release within that month). The current version is in `VERSION`.

## Unreleased

### Ruimtelijk werkvlak
- Super+Z biedt Ruimtelijk: vensters kunnen boven, onder en naast elkaar staan. De bestaande indeling blijft standaard behouden.
- Super+pijlen kiest een venster; Super+Shift+pijlen verplaatst het; Super+Ctrl+Alt+pijlen verplaatst het zicht. Super+drievingerveeg verwerkt beide assen tegelijk waar live Lua-gebaren ondersteund worden.
- Eén venster vult het werkgebied. Scroll-/kolombreedteacties controleren de werkelijke layout en doen niets wanneer scrollen uitstaat of de werkruimte leeg is.
- Lay-outkeuzes worden pas opgeslagen nadat Hyprland de wijziging bevestigt. Basis: Hyprscroll2D (MIT), met eigen Kingstra-integratie en tests.

### Rustige muziekstatus
- De animatie in de now-playing-pill gebruikt een vaste tekenruimte. Alleen de streepjes schalen; titel en pill veranderen daardoor niet meer mee van hoogte.

### Tablet mode: smoother
- Rotating keeps the screen's current resolution and refresh rate instead of asking for "preferred", so the panel no longer needs a full modeset (no black flash or resolution jump).
- Repeated hinge events no longer rotate again when the screen already has the right orientation; a short message in the corner says when tablet mode switches on or off.

### Zen mode
- Super+Alt+Z (or `kingstra zen`, or Modus › Zen in the keyboard menu) hides the bar and rail until you touch the edge, turns on Niet storen, removes the desktop widgets and dims windows without focus. Switching it off restores exactly what was there before.

### Login screen (SDDM)
- The Kingstra SDDM theme now matches the lock screen: the same 140 px clock with separate hours and minutes and a dimmed colon, the same date line, the same shrink-and-fade when you start typing, and the same 48 px glass pills at the bottom (keyboard layout, session, restart, power off) with hover growth.
- `kingstra update` copies the theme to `/usr/share/sddm/themes/kingstra` as before.

### Session: resume apps
- Like macOS and Windows, apps come back after logging in, each on the workspace where it was. The session starter saves the open apps every two minutes to `~/.local/state/kingstra/session.json` (command line, workspace, class; Flatpak apps restart via `flatpak run`) and restores them a few seconds after login.
- Apps that are already running (autostart) are not started twice; a snapshot older than seven days is ignored; an empty snapshot (for example while shutting down) never overwrites a good one.
- `kingstra sessie` shows what is saved; `kingstra sessie aan|uit|bewaar|herstel` switches it or saves and restores right away.

### Lock screen: glance
- Under the clock the lock screen now shows the next appointment (today or tomorrow), the track that plays or is paused with album art and working buttons, and one pill per app with the number of waiting notifications. Never the content: the shell writes only app names and counts to `$XDG_RUNTIME_DIR/kingstra-notification-summary.json`.
- Everything fades away with the clock as soon as you start typing.

### Windows: snap layouts, scrolling and scratchpad
- Super+Z opens a snap picker, like Snap Layouts in Windows 11 and KDE's tiles: seven layouts for the current workspace (Tegels, 50 | 50, 70 | 30, Midden groot, Drie kolommen, Scrollen, Eén tegelijk). Click a zone to put the active window there; the big zone makes it the main window. Keys 1-7, arrows and Enter work too.
- Every layout is a real Hyprland layout (dwindle, master, scrolling, monocle), so windows stay tiled. The choice per workspace is saved in `~/.local/state/kingstra/workspace-layouts.json` and comes back after a restart.
- Scrolling columns like niri: Super+Alt+S switches the current workspace to a scrolling strip and back. Super+Shift+wheel moves one column, Super+Ctrl+, and . make the column narrower or wider.
- Any window can become a scratchpad: Super+Shift+` sends the active window to the "kladblok" (floating, centered, 70% × 65%) or brings it back; Super+` shows or hides it. Spotify and Discord keep their own.
- Window groups (Super+G) get a tab bar of rounded pills in the theme's colors instead of thin stripes.
- New commands: `kingstra indeling [naam|scroll|kies]` and `kingstra kladblok [stuur]`; the keyboard menu has a Vensters submenu.
- Three-finger swipe down opens the control center, up opens the overview (needs a Hyprland version with Lua gesture functions; older versions skip it).
- Fix: `hypr-dispatch.sh setfloating` now sets floating instead of toggling it.

### Shell: Kingstra island
- One place for short feedback, like Dynamic Island and Live Activities on macOS: a pill grows out of the middle of the bar (with hollow corners into the bar edge) and shrinks back.
- Volume, microphone and brightness keys now run `hypr/scripts/osd.sh`, which changes the value itself (wpctl, brightnessctl) and shows it in the island. With the island's OSD off, or the shell not running, swayosd takes over as before.
- New notifications appear in the island instead of the cards at the top right; more waiting shows as `+2`. Left-click opens, right-click dismisses, middle-click skips. Critical notifications stay until clicked.
- Live activities: the playing track with album art and moving equalizer bars (click to expand with controls), plus dots when the microphone (orange), camera (green) or a screen recording (red) is in use.
- `kingstra eiland [osd|meldingen|live] aan|uit` switches parts off; `kingstra eiland meldingen uit` brings back the old notification cards. Stored in `~/.local/state/kingstra/island.json`.

### Shell: desktop widgets
- A large clock with the date and, when something plays or is paused, a media card sit on the wallpaper (above the wallpaper, below windows), in the theme's fonts and colors. Click the clock for the agenda.
- `kingstra widgets aan|uit|klok <plek>|media aan|uit` and the keyboard menu (Uiterlijk › Bureaubladwidgets) switch them and move the clock (linksboven, rechtsboven, midden, linksonder, rechtsonder).

### Shell: control center edit mode
- The pencil in the control center header switches to edit mode, like DMS and Windows 11: move pills left or right, make them wide or narrow, hide or show them. Saved in `~/.local/state/kingstra/control-center.json`; hidden pills stay reachable in edit mode.

### Shell: pinned rail modules
- Right-click a pill in the control center (Wi-Fi, Bluetooth, Niet storen, Energie) or the media card to pin it to the rail as a mini tile, like modules in the macOS menu bar. One click toggles it there; middle-click unpins. Stored in `~/.local/state/kingstra/rail-pins`.

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
