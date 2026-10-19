# kingstra-dots

Personal Hyprland rice for Arch Linux. Modular, reproducible, fully automated installation.

---

## Overview

| Layer | Tool |
|---|---|
| Compositor | Hyprland 0.55+ with a Lua config (`config/hypr/hyprland.lua`) |
| Shell UI | Quickshell (QML): bar, shell frame, panels, launcher, notifications, lockscreen |
| Colors | Matugen (Material You palette from the wallpaper) |
| Themes | `organic`, `paper`, `neon`, `mono`, `mono-accent` |
| Wallpaper | skwd-wall (static), mpvpaper (optional video) |
| Terminal / shell | kitty, zsh + oh-my-posh |
| Login / lock | SDDM (Kingstra greeter), Quickshell lock with hyprlock fallback, hypridle |
| OSD | SwayOSD |

Config folders are deployed as symlinks: `~/.config/<name>` points to `config/<name>` in this repo.

---

## Hyprland — Lua config

Hyprland loads a single entrypoint, `config/hypr/hyprland.lua`, which requires the modules in
`config/hypr/lua/`. The old `hyprland.conf` is no longer used; the first Lua session removes it.

| Module | Contents |
|---|---|
| `config.lua` | General, decoration, blur, layouts, input, animations |
| `monitors.lua` | Universal fallback monitor rule (`preferred`, scale 1.0) |
| `rules.lua` | Window and layer rules |
| `binds.lua` | All keybindings, including the `passthrough` submap |
| `autostart.lua` | Runs `~/.local/bin/kingstra-session-start` on `hyprland.start` |

Machine-specific and generated modules are loaded optionally (each returns `{ apply = function() ... end }`)
and are kept out of git. A tracked `*.lua.default` exists for each one as a fallback:

| Generated module | Written by |
|---|---|
| `colors.lua` | Matugen (`templates/hypr-colors.lua`) |
| `theme.lua` | `kingstra-theme-switch` |
| `hardware.lua` | Installer phase 14 (GPU env vars, touchpad, tablet mode) |
| `monitors-local.lua` | Display settings (`monitor-apply-save.sh`, Settings panel) |
| `workspaces.lua` | Workspace/monitor assignments |
| `input-overrides.lua` | Settings panel input overrides |

Helper scripts live in `config/hypr/scripts/` (workspace actions, overview, screenshots,
monitor hotplug restore, resume fixes, lid lock, tablet mode, Citrix guard, and more).
`hypr-dispatch.sh` wraps dispatch calls so scripts keep working with the Lua config.

---

## Quickshell

Quickshell is the primary UI layer (about 40k lines of QML across ~90 files). Three Quickshell
processes are started by `kingstra-session-start`:

- **`TopBar.qml`** — the bar (`bar/BarShell.qml`) and the shell surface (`shellsurface/ShellSurface.qml`):
  rail, status strip, screen frame and the panels that grow out of it (launcher, clipboard,
  window switcher, performance drawer).
- **`Main.qml`** — popups such as calendar, music, battery, network, volume, monitors,
  settings, theme and mode pickers, FocusTime and help. Toggled through `config/hypr/scripts/qs_manager.sh`.
- **`overview/shell.qml`** — the workspace overview (`Super + Tab`).

The screen frame and edge panels are drawn as one shared SDF "blob" by a small Qt plugin in
`plugin/` (`Kingstra.Blobs`), built and installed by phase 05.

Bar layout comes from the active theme: `bar_position` (top/bottom), an optional side rail, a
status strip, the bar template, and the bar/widget shapes. Bar skins live in `bar/skins/` and
theme effects (particles, neon grid, botanical glow) in `bar/effects/`.

Notifications, the app launcher, the clipboard history and the lockscreen are all Quickshell
components. SwayNC is no longer used; phase 06 stops it if it is still running.

### Modes

Modes change the bar module set and autohide behaviour for the current activity. Theme identity
stays the same. Definitions live in `config/kingstra/modes/*.toml`.

| Mode | Bar | Modules |
|---|---|---|
| `office` (default) | Always visible | Workspaces, clock, updates, CPU temp, RAM, network, battery, volume, Bluetooth, notifications |
| `gaming` | Always visible | Workspaces, CPU/GPU temps, RAM, FPS, battery, volume, game launcher, clock |
| `media` | Auto-hide | Volume, brightness, media controls, battery, clock |

Switch with `Super + Ctrl + M` or `kingstra-mode-switch <mode>`.

---

## Theming — Matugen

Every wallpaper or theme change runs one pipeline, `apply-shell-state`:

1. `kingstra-matugen-run` resolves the current wallpaper and the active theme's `[matugen]`
   settings (scheme type, color index, contrast, light/dark) and runs Matugen.
2. The wallpaper stays the single source of truth for the palette; themes change styling, not
   the colors themselves.
3. Matugen writes the generated files and the affected apps are reloaded.

Templates live in `config/matugen/templates/`. Phase 08 creates `~/.config/matugen/config.toml`
with these targets:

Hyprland (`lua/colors.lua`), Quickshell (`colors.json`), kitty, btop, cava, Walker, Qt6 (qt6ct),
GTK 3/4, yazi, hyprlock, oh-my-posh, Firefox (website CSS), VS Code, SDDM, Spicetify, and a
palette inspector JSON (`~/.config/kingstra/state/matugen-palette.json`) shown in the
wallpaper picker overlay.

Firefox has two layers: the Matugen website CSS above, and browser chrome styling from
`config/firefox/chrome/userChrome.css`, installed into each profile by `kingstra-firefox-optimize`.

---

## Themes

Five themes, defined in `config/kingstra/themes/*.toml`. Each theme sets its Matugen scheme,
radius, gaps, blur, opacity, fonts, icon theme, bar layout and shape, widget style, motion,
particles and terminal look.

| Theme | Character | Scheme | Bar | Extras |
|---|---|---|---|---|
| `organic` (default) | Dark, warm, tactile; soft shapes | `scheme-content`, dark | Top + left rail | Fireflies, organic glow |
| `paper` | Warm e-reader; light matte paper, minimal motion | `scheme-fidelity`, light | Top | Sketch wallpaper effect |
| `neon` | Futuristic cockpit; black glass, cyan/magenta | `scheme-rainbow`, dark | Top + left rail | Neon grid, specks, glass-tint wallpaper |
| `mono` | Monochrome, flat, angular, compact | `scheme-monochrome`, dark | Bottom | Grayscale wallpaper |
| `mono-accent` | Mono with a single wallpaper accent hue | `scheme-fidelity`, dark | Bottom | Color-splash wallpaper |

For `paper`, `neon`, `mono` and `mono-accent`, `kingstra-wallpaper` generates the themed wallpaper
variant in the cache before skwd switches to it, so there is no flash of the unfiltered image.

```bash
kingstra-theme-switch organic
kingstra-theme-switch --list
kingstra-theme-switch --current
```

`Super + Ctrl + T` opens the theme picker; `Super + Shift + T` cycles to the next theme.

---

## Wallpaper

skwd-wall is the only wallpaper renderer (`skwd-daemon.service`). Video wallpapers use mpvpaper
when `ENABLE_VIDEO_WALLPAPER=true`. Everything goes through `kingstra-wallpaper`, which calls the
same `apply-shell-state` pipeline so colors stay in sync.

```bash
kingstra-wallpaper set ~/Pictures/photo.png    # static
kingstra-wallpaper video ~/Videos/bg.mp4       # video (mpvpaper)
kingstra-wallpaper random [--video]            # random from ~/Pictures/Wallpapers
kingstra-wallpaper pick                        # interactive fzf picker
kingstra-wallpaper reload                      # re-apply the last wallpaper
kingstra-wallpaper stop-video                  # stop video, restore static
kingstra-wallpaper status                      # show the active wallpaper
```

Keybinds: `Super + Shift + W` (random) and `Super + Ctrl + W` (visual picker).

---

## Other components

- **Launcher** — Quickshell launcher panel (`Super + Ctrl + Return`) with usage-based ordering
  and up to three pinned apps. Walker + Elephant are also installed and run as a service.
- **Notifications** — Quickshell popup and center (`Super + N`), clear (`Super + Shift + N`),
  do-not-disturb (`Super + Alt + N`).
- **Clipboard** — cliphist with a Quickshell panel (`Super + V`), text and images.
- **Lockscreen** — `lock.sh` starts the Quickshell lock (`Lock.qml`) and falls back to hyprlock,
  then `loginctl lock-session`. Fingerprint works through PAM when detected.
- **Game launcher** — [quickshell-games-launchers](https://github.com/Eaquo/quickshell-games-launchers)
  (`Super + Ctrl + G`).
- **Files** — Nautilus (`Super + E`) and yazi (`Super + Shift + E`).
- **Monitoring** — btop, lm_sensors, and the performance drawer and HUD telemetry in the shell.
- **Calendar** — read-only Thunderbird helper for the agenda.
- **Passthrough** — `Super + Escape` toggles a submap where Hyprland consumes no Super shortcuts.
  `citrix-guard.sh` does this automatically for Citrix (`wfica`) windows to avoid the Super-key crash.
- **WiFi/Bluetooth stability** — phase 12 turns off WiFi power saving and Bluetooth USB autosuspend,
  and installs resume and lid-lock user services.
- **Touch and tablet mode** — touchscreens get a touch profile (larger targets, touch scrolling);
  convertibles rotate the internal display and show an on-screen keyboard in tablet mode.
  Override detection with `KINGSTRA_FORCE_TOUCH=1` / `KINGSTRA_FORCE_TOUCH=0`.

---

## Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh)
```

The bootstrap:
- syncs the repo to the latest default branch state before every run;
- clones to `~/kingstra-dots` (or updates that clone if it already exists);
- auto-installs `yay-bin` when no AUR helper is present;
- starts the installer automatically.

Updates started from the Quickshell settings also finish by running the full,
idempotent installer. A repository pull by itself is not considered a completed
update: package manifests, generated hardware/display Lua, validation and live
session reloads are applied by `install.sh --yes` on every update run.

**With options:**
```bash
# Dry-run — see what would happen without installing anything
bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh) --dry-run

# Custom install directory
KINGSTRA_DIR=~/.config/kingstra-dots bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh)
```

**Manual (after cloning):**
```bash
./install.sh                              # all phases
./install.sh --dry-run                    # show what would happen
./install.sh --phase 09_wallpaper         # a single phase
./install.sh --from-phase 10_session      # continue from a phase
./install.sh --override my-overrides.conf # override detected feature flags
./install.sh --yes                        # skip confirmation prompts
```

### Requirements

- Arch Linux (pacman)
- bash 4.4+
- git

An AUR helper is not a manual prerequisite: `bootstrap.sh` installs `yay-bin` when none is found.

### Installation phases

| # | Phase | What it does |
|---|---|---|
| 01 | `01_project_base` | Validate repo structure, logging, backups, base requirements |
| 02 | `02_shell_terminal` | zsh, oh-my-posh, zsh plugins, kitty, fastfetch, cava, btop |
| 03 | `03_hypr_core` | Hyprland and core packages, Lua config, GTK, XDG portals |
| 04 | `04_bindings` | Validate `lua/binds.lua` and check for duplicate binds |
| 05 | `05_ui_quickshell` | Quickshell, Qt6 dependencies, build the `Kingstra.Blobs` plugin |
| 06 | `06_notifications` | Quickshell notifications (stops legacy SwayNC) |
| 07 | `07_launcher` | Walker + Elephant providers, weather API setup |
| 08 | `08_theming` | Matugen, templates, themes/modes/state, `kingstra-*` scripts, game launcher, first color run |
| 09 | `09_wallpaper` | skwd-wall + Kingstra overlay, optional mpvpaper, `kingstra-wallpaper` |
| 10 | `10_session` | Lockscreen, hypridle, SDDM and the Kingstra greeter |
| 11 | `11_apps_tools` | Nautilus, yazi, cliphist, playerctl, screenshot tools, polkit, optional apps |
| 12 | `12_network_resume_fixes` | NetworkManager, Bluetooth, resume and lid-lock services |
| 13 | `13_monitoring` | lm_sensors, btop validation, bar system data |
| 14 | `14_profiles` | Hardware detection → `lua/hardware.lua`, GPU, laptop, tablet, fingerprint setup |
| 15 | `15_finalize` | Final validation, services check, install-complete marker |

Smoke tests for the installer and Lua generators live in `tests/smoke/`.

### Hardware detection and profiles

There is no profile to pick. `installer/lib/detect.sh` detects each feature on its own, so a
laptop with an Nvidia GPU gets both sets of tweaks. Phase 14 turns the result into
`~/.config/hypr/lua/hardware.lua` and installs the matching packages.

| Hardware | Detected as | Action |
|---|---|---|
| Nvidia GPU | `DETECT_GPU=nvidia` | Wayland env vars, cursor fix, Nvidia packages |
| AMD GPU | `DETECT_GPU=amd` | VA-API driver (radeonsi) |
| Laptop/battery | `DETECT_IS_LAPTOP=true` | power-profiles-daemon |
| Backlight | `DETECT_HAS_BACKLIGHT=true` | brightnessctl |
| Touchpad | `DETECT_HAS_TOUCHPAD=true` | natural scroll, tap-to-click |
| Touchscreen | `DETECT_HAS_TOUCHSCREEN=true` | touch profile; tablet mode on laptops |
| Tablet mode switch | `DETECT_HAS_TABLET_MODE_SWITCH=true` | rotate internal display + OSK |
| Fingerprint | `DETECT_HAS_FINGERPRINT=true` | fprintd, PAM for sudo, lock and SDDM |

Feature flags derived from detection can be overridden with `--override`:

```bash
# my-overrides.conf
ENABLE_FINGERPRINT=false
ENABLE_VIDEO_WALLPAPER=false
ENABLE_SPICETIFY=true
ENABLE_VESKTOP=true
```

Spicetify, Vesktop and the optional Office, Heroic and VLC apps are never enabled automatically.
`installer/profiles/` (`default`, `laptop`, `nvidia`) holds older preset files; they can still
be passed with `--override`, but only their `ENABLE_*` flags have an effect.

### Uninstall

Kingstra-owned autostart runs through one entrypoint:

```bash
~/.local/bin/kingstra-session-start
```

To remove Kingstra-owned symlinks, stop its session processes, and optionally restore the newest
installer backup:

```bash
./uninstall.sh
./uninstall.sh --dry-run
./uninstall.sh --restore latest
./uninstall.sh --no-restore
```

By default, the uninstaller tries to restore the backup that belongs to the active installation
(read from `~/.local/share/kingstra/install-complete`, otherwise it falls back to the newest backup).
It restores backed-up user files, restores backed-up `/etc` files such as PAM/SDDM config when
available, disables Kingstra user services, and removes Kingstra-owned paths listed in
`manifest/owned-paths.txt`.

The uninstaller does not remove packages. Use `--no-restore` if you only want to remove
Kingstra-managed files without restoring the captured backup.

---

## Important paths

| Path | Contents |
|---|---|
| `~/.config/hypr/hyprland.lua` | Hyprland entrypoint (symlinked from repo) |
| `~/.config/hypr/lua/` | Lua modules, plus generated `colors`, `theme`, `hardware`, `monitors-local`, `workspaces` |
| `~/.config/quickshell/` | Quickshell UI |
| `~/.config/matugen/` | Matugen templates and generated `config.toml` |
| `~/.config/kingstra/` | Themes, modes, active theme and runtime state |
| `~/kingstra-dots/` | This repo (default bootstrap location) |
| `~/.local/bin/kingstra-*` | Kingstra scripts |
| `~/.local/bin/kingstra-session-start` | Session autostart entrypoint |
| `~/.local/share/kingstra/` | Install logs, backups, markers |
| `~/.local/state/kingstra/session.log` | Session start log |
| `~/Pictures/Wallpapers/` | Wallpapers |

---

## Keybindings

All binds live in `config/hypr/lua/binds.lua`. See [docs/keybindings.md](docs/keybindings.md)
for the full list.

| Keybinding | Action |
|---|---|
| `Super + Return` | kitty |
| `Super + Ctrl + Return` | App launcher |
| `Super + Tab` | Workspace overview |
| `Super + W` | Window switcher |
| `Super + E` / `Super + Shift + E` | Nautilus / yazi |
| `Super + V` | Clipboard history |
| `Super + N` | Notifications |
| `Super + X` | FocusTime |
| `Super + O` | Monitors |
| `Super + Ctrl + I` | Settings |
| `Super + Ctrl + T` / `Super + Shift + T` | Theme picker / next theme |
| `Super + Ctrl + M` | Mode picker |
| `Super + Ctrl + W` / `Super + Shift + W` | Wallpaper picker / random wallpaper |
| `Super + Ctrl + G` | Game launcher |
| `Super + Ctrl + L` | Lock |
| `Super + Escape` | Passthrough submap |
| `Super + F1` | Help |
| `Print` | Screenshot (`Super + Print` to clipboard, `Shift + Print` annotate) |

---

## Notes

### SDDM fingerprint flow

The Kingstra greeter starts an empty PAM login once and shows a fingerprint status card while
waiting for the scanner. If SDDM or PAM misses that first attempt, press `Enter` on an empty
password field to trigger fingerprint auth again; typing a password remains the fallback.

---

## Credits

Inspired by [imperative-dots](https://github.com/ilyamiro/imperative-dots) by ilyamiro.

## License

MIT — see [LICENSE](LICENSE).
