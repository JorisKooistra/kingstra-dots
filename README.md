# kingstra-dots

Personal Hyprland rice for Arch Linux. Modular, reproducible, fully automated installation.

---

## Overview

| Layer | Tool |
|---|---|
| Compositor | Hyprland 0.55+ with a Lua config (`config/hypr/hyprland.lua`) |
| Shell UI | Quickshell (QML): bar, shell frame, panels, launcher, notifications, lockscreen |
| Colors | Matugen (Material You palette from the wallpaper) |
| Themes | `organic`, `paper`, `neon`, `mono`, `mono-accent`, `matte` |
| Wallpaper | skwd-wall (static), mpvpaper (optional video) |
| Terminal / shell | kitty, zsh + oh-my-posh |
| Login / lock | SDDM (Kingstra greeter), Quickshell lock with hyprlock fallback, hypridle |
| OSD | SwayOSD |

Config folders are deployed as symlinks: `~/.config/<name>` points to `config/<name>` in this repo.

---

## The `kingstra` command

One entry point for everyday tasks. The separate `kingstra-*` scripts keep working.

```bash
kingstra theme organic        # switch theme (no name: picker)
kingstra mode gaming          # switch mode
kingstra update               # update system, Flatpak and dotfiles
kingstra doctor               # check the installation, with fixes
kingstra rollback             # dotfiles back to the restore point before the last update
kingstra refresh kitty        # one config back to the repo default (backup first)
kingstra restart              # restart the shell
kingstra version
kingstra help
```

### Updates and restore points

Every update first makes a restore point: a local git tag of the dotfiles and, when `/` is on
btrfs with snapper set up, a system snapshot. `kingstra rollback` returns the dotfiles to that
point and holds them there; `kingstra rollback --release` follows updates again.
`kingstra snapshot list` shows the restore points.

Your own edits to tracked files (for example keybindings changed in Settings) are set aside
during an update and put back afterwards. If they clash with the update, the dotfiles stay on
the old version and nothing is lost.

One-time migrations between versions live in `installer/migrations/` and run once per machine.

### Personal additions

Copy `config/hypr/lua/user.lua.default` to `config/hypr/lua/user.lua` for your own binds, rules and
settings. It is ignored by git, loads last, and an error in it never breaks the rest of the config.

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
- **`Main.qml`** — the theme and mode pickers and the shortcut help. Every other panel (calendar,
  sound & media, battery, network, monitors, settings, FocusTime) grows out of the shell surface.
  All are toggled through `config/hypr/scripts/qs_manager.sh`.
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

The shell shares one palette reader across its widgets, with a 250 ms polling
fallback for missed file notifications. Seed/accent extraction is cached by image
identity and algorithm, preserving the same colours. Wallhaven metadata loads after
colour publication; concurrent renderer/orchestrator applies are coalesced.

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

Six themes, defined in `config/kingstra/themes/*.toml`. Each theme sets its Matugen scheme,
radius, gaps, blur, opacity, fonts, icon theme, bar layout and shape, widget style, motion,
particles and terminal look.

| Theme | Character | Scheme | Bar | Extras |
|---|---|---|---|---|
| `organic` (default) | Dark, warm, tactile; soft shapes | `scheme-content`, dark | Top + left rail | Fireflies, organic glow |
| `paper` | Warm e-reader; light matte paper, minimal motion | `scheme-fidelity`, light | Top | Sketch wallpaper effect |
| `neon` | Futuristic cockpit; black glass, cyan/magenta | `scheme-rainbow`, dark | Top + left rail | Neon grid, specks, glass-tint wallpaper |
| `matte` | Muted wallpaper colours, charcoal surfaces, quiet controls | `scheme-content`, dark | Three floating pills: clock, workspace dots, status | Soft blur/shadows; no window borders, album-art glow or permanent music island |
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

`Super + Ctrl + W` opens our native Quickshell picker on the focused monitor.
It has slices, hexagons, a grid, a mosaic, Coverflow and Orbit, local search, colour filters and
favorites, plus Wallhaven search using the existing API key in `skwd-wall/config.json`.
Wallhaven has three main categories (General, Anime, People); the subject selector adds
quick tag searches such as Nature, Space, Abstract and Cyberpunk, combined with free text.
The subject control is explicitly labelled **Zoekonderwerp**: these are prepared search
terms, not shared categories supplied by every source. Wallhaven's SFW, Sketchy and NSFW
are independent checkboxes; only SFW is checked on startup. Pixabay has a separate
safe-search checkbox, enabled by default, plus its own actual API categories, colour,
minimum dimensions and popular/latest filters. Pexels supports colour and minimum
megapixel size. Sources without an adjustable safety filter say so in the picker.
A second source uses the free [NASA Image Library API](https://images.nasa.gov/docs/images.nasa.gov_api_docs.pdf)
without an API key. It offers topic search, automatic pagination, HD previews, download,
apply and trash; downloaded sidecars retain the original title, keywords, credit and
source page. NASA does not expose Wallhaven's colour, purity or resolution filters.
The NASA tab starts on Nebulae; choose All subjects to search the entire library.
[Wikimedia Commons](https://www.mediawiki.org/wiki/API:Imageinfo) is available as a third online
source without a key, with minimum resolution, automatic pagination and original-image
preview/download. Categories become searchable tags; author, license and source URL are
kept in the image sidecar and shown in the preview.

Additional source tabs provide [Wallpapers.com](https://wallpapers.com/api/),
[Alpha Coders](https://alphacoders.com/), [backiee](https://backiee.com/),
[WallpapersCraft](https://wallpaperscraft.com/), [GoodFon](https://www.goodfon.com/),
[WallpapersWide](https://wallpaperswide.com/),
[Pexels](https://www.pexels.com/api/) and [Pixabay](https://pixabay.com/api/docs/).
Wallpapers.com uses its public API (up to 60 results per topic); Pexels and Pixabay
require a key. Pexels is hidden from the source selector until a key is configured;
its key field remains available. Removing its key while browsing Pexels returns to
the local collection. The other five use publicly available site data rather than a
supported developer API. GoodFon resolves its original image, creator and license from
the published ImageObject data. WallpapersWide searches its native tags and uses its
published main HD download link. Public site parsers may need maintenance when
their markup changes. Published original images, titles, tags and credit are retained
where the source supplies them; unsupported source-specific filters stay hidden.

[HDQwalls](https://hdqwalls.com/) is a clearly labelled external source: its Cloudflare
challenge currently prevents automated access. Its picker page opens the official
website and does not invent search results or attempt to bypass the challenge.
Zedge is no longer offered; existing downloaded files and their metadata remain usable.

The **API-sleutels** button contains masked local key fields for Wallhaven (optional),
Wallpapers.com (optional), Pexels and Pixabay, with request links and remove controls.
Keys are stored with mode `0600` in `~/.config/kingstra/wallpaper-sources.json`, which
is ignored by git. They are sent to the worker through stdin and never returned in
UI state or logs. Existing Wallhaven keys in the skwd config remain supported.
Pixabay responses are cached for 24 hours; original/Full HD access requires separate
full API approval (normal keys return images up to 1280 px, shown in the picker).
Pexels currently pauses new API key issuance; an existing key can be entered.
On smaller screens the source tabs become a dropdown to leave more room for images.

**Geen AI** is a remembered option: Wallhaven excludes its AI art tag (`133451`),
backiee's unqueried catalog requests `is_ai=no` and checks its `AIGenerated` flag.
Other adapters and the local collection filter explicit AI labels/tags, without treating
all anime, illustration or digital art as AI. On these sources the UI explains that
missing labels cannot be filtered. AI labels discovered on a detail page also prevent
the full preview/download while this option is enabled. This is label filtering,
not an image classifier. No unsupported API parameters are presented as working filters.

Inspired by [elifouts/Dotfiles](https://github.com/elifouts/Dotfiles/tree/5895c44f32a7d6d35a8e6c2321eb6ab81fe37c75/.config/hypr/Modern/utilities/wallpaper-picker),
the selected image supplies a softly blurred, crossfading background (toggle with Sfeer),
a bar of sampled image colours and clickable tag chips. The small backdrop and colour
samples are cached beside the thumbnail by the worker, without generating a theme while
browsing. Clicking a swatch copies its hex code. Local folders supplement existing tags;
there is no inferred image-content tagging. The reference's category chips are folder names.
The existing three-accent Matugen pipeline remains: independent sampled wallpaper hues
feed accents 2 and 3 alongside the main palette. The photo-colour bar is separate from
the three current theme accents. A real Matugen regression checks a blue/orange/green
fixture for three distinct accent hues and wallpaper-derived secondary/tertiary sources.
Wallhaven loads more results as you scroll. Click a remote image to inspect a
full-resolution preview, zoom with the wheel or +/−, and drag to pan. The preview
loads the full image directly, with previous/next, download, apply and clear back/close
controls. Clicking any empty margin around the image also closes its preview.
Hover exposes separate vector icons for apply, download and (when saved) trash; the active wallpaper is
protected from removal. Applying a remote image downloads it to the library first.
A loaded HD preview and its metadata are reused without another request. Applying while
HD is still loading waits for that transfer, including when the preview is closed;
first downloads fetch image bytes and tag details concurrently. Download percentages and
renderer/palette/app refresh milestones explain progress without blocking browsing.
Wallhaven tags are saved automatically in an adjacent `<image>.json` file and included
in local searches. A local image applies with one click. Loading further Wallhaven
pages appends model rows without resetting the current position in any of the views.
The picker uses its own thumbnail cache and exits when closed. No upstream QML
overlay or patcher is used. Settings live in `~/.config/kingstra/wallpaper-picker.json`.
Use arrow keys to choose and F to favorite local images. Enter applies locally,
opens a Wallhaven preview, or applies the image inside that preview. Escape returns
from a preview, then closes the picker.
Keyboard focus is on demand, so other screens remain usable while it is open.
The hexagons follow a shared curved surface, with gradually wider spacing toward
the sides and flying edge columns. One smoothed camera handles wheel and gesture
input without an idle snap. The default HSL hue/saturation colour order is based on
[skwd v1](https://github.com/liixini/skwd-wall/tree/49a2f5c0bdc711cde5b70f145ff659380954882a).
The implementation keeps its own source; the upstream MIT notice is included in
`config/quickshell/wallpaper/SKWD-LICENSE.txt`.
Wheel ticks compensate for Hyprland's scroll multiplier so each tick advances one
column, or one full row in the grid with a short animation; pixel gestures remain continuous.
Hover highlights a tile and its name
independently of keyboard selection. Coverflow uses the same virtualized camera and
thumbnail cache, with a large center card and perspective-rotated neighboring cards;
its visual inspiration comes from the [wallpaperCarousel unixporn example](https://www.reddit.com/r/unixporn/comments/1ro14ur/niri_wallpaper_carousel_from_uilyamiro1_in_a_dms/),
with an independent implementation. Orbit adds a curved depth arrangement to the same
virtualized camera and keeps the selection visible throughout scrolling.

Picker verification runs without changing the desktop wallpaper:

```bash
bash tests/smoke/wallpaper-picker.sh
python3 tests/smoke/wallpaper-colours.py
python3 tests/integration/palette-refresh.py
python3 tests/integration/wallpaper-picker-offscreen.py --output /tmp/picker-test
# With Xvfb installed, the integration test also verifies actual shader images.
# Add --live-wallhaven, --live-nasa or --live-commons for real API checks.
# Add --paging-only to verify scroll position through page loads in every view.
python3 tests/integration/wallpaper-providers-live.py --output /tmp/picker-live-sources
# Explicit network check of the six keyless sources; private files, no apply.
# Use --live-source goodfon or --live-source wallpaperswide with the graphical
# integration test for a real website search, HD preview and private download.
```

The integration test uses actual Qt click, wheel and keyboard events, private
state and library fixtures, and mocked wallpaper application. When requested,
`--live-wallhaven` reads the existing API settings but keeps downloads and cache
inside the test directory. Xvfb is a development dependency, not a runtime requirement.

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

- **Launcher** — Compact search field and app list (`Super + Ctrl + Return`) with usage-based
  ordering and up to three pinned apps. Extra search modes and shell actions are available
  through the help button or `F1`; arrow keys and Enter also select and run shell actions.
  Background refreshes preserve the selected app. Walker remains a standalone command.
- **Notifications** — Quickshell pop-ups next to the rail and a center grouped per app
  (`Super + N`), clear (`Super + Shift + N`), do-not-disturb (keyboard menu, or middle-click
  the rail bell). Do-not-disturb keeps notifications silently and survives a restart.
- **Clipboard** — cliphist with a Quickshell panel (`Super + V`), text and images.
- **Lockscreen** — `lock.sh` starts the Quickshell lock (`Lock.qml`) and falls back to hyprlock,
  then `loginctl lock-session`. Fingerprint works through PAM when detected.
- **Game launcher** — [quickshell-games-launchers](https://github.com/Eaquo/quickshell-games-launchers)
  (keyboard menu or the rail).
- **Files** — Nautilus (`Super + E`) and yazi (keyboard menu).
- **Monitoring** — btop, lm_sensors, and the performance drawer and HUD telemetry in the shell.
- **Calendar** — compact agenda panel (keyboard menu) with local events you can add, edit
  and delete (`calendar/agenda_events.py`), plus the weather per day and hour.
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
| 09 | `09_wallpaper` | skwd-wall renderer + native Kingstra picker, optional mpvpaper, `kingstra-wallpaper` |
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

For choices that should stick, copy `installer/overrides.example.conf` to
`~/.config/kingstra/overrides.conf`. The installer reads it on every run, including updates;
it is not tracked by git.

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
| `Super + E` | Nautilus (yazi via the keyboard menu) |
| `Super + V` | Clipboard history |
| `Super + N` | Notifications |
| `Super + Ctrl + I` | Settings (own app, `kingstra-settings`) |
| `Super + Ctrl + Space` | Keyboard menu for everything |
| `Super + Ctrl + T` / `Super + Shift + T` | Theme picker / next theme |
| `Super + Ctrl + M` | Mode picker |
| `Super + Ctrl + W` / `Super + Shift + W` | Wallpaper picker / random wallpaper |
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

## Changelog

See [CHANGELOG.md](CHANGELOG.md). The installed version is in `VERSION`.

## License

MIT — see [LICENSE](LICENSE).
