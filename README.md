# kingstra-dots

Personal Hyprland rice for Arch Linux. Modular, reproducible, fully automated installation.

---

## Features

- **Compositor** — Hyprland with modular `conf.d` structure
- **Bar** — Quickshell (QML): workspaces, clock, active window, CPU/RAM, media, notifications
- **Theme** — Matugen generates Material You colors from the wallpaper
- **Shell** — zsh + oh-my-posh, theme follows wallpaper colors
- **Terminal** — kitty with Matugen colors and JetBrains Mono
- **Launcher** — Walker (`Super+Ctrl+Return`)
- **Notifications** — SwayNC (control center, top-left)
- **Wallpaper** — hyprpaper (static) + mpvpaper (video, optional)
- **Lockscreen** — hyprlock, styled with Matugen colors
- **OSD** — SwayOSD (volume, brightness)
- **File manager** — Nautilus + Yazi (terminal)
- **Hardware** — automatic detection: Nvidia/AMD/Intel, laptop, touchpad, fingerprint

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

**With options:**
```bash
# Dry-run — see what would happen without installing anything
bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh) --dry-run

# Custom install directory
KINGSTRA_DIR=~/.config/kingstra-dots bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh)
```

**Manual (after cloning):**
```bash
# Run a single phase
bash install.sh --phase 09_wallpaper

# Continue from a specific phase
bash install.sh --from-phase 10_session

# Override feature flags
echo "ENABLE_FINGERPRINT=false" > my-overrides.conf
bash install.sh --override my-overrides.conf
```

### Requirements

- Arch Linux (pacman)
- bash 4.4+
- git

An AUR helper is no longer a manual prerequisite for the bootstrap flow: when missing,
`bootstrap.sh` installs `yay-bin` automatically.

---

## Installation phases

| # | Phase | Description |
|---|---|---|
| 01 | Project base | Directory structure, installer validation |
| 02 | Shell/terminal | zsh, oh-my-posh, kitty, fastfetch, cava |
| 03 | Hyprland core | Modular config, screenshots, GTK, portals |
| 04 | Bindings | 5 bind files, duplicate checking |
| 05 | Quickshell UI | Top bar, workspaces, clock, stats, media, power |
| 06 | Notifications | SwayNC: control center, mpris, DND |
| 07 | Launcher | Walker: app launcher, ssh, calculator |
| 08 | Theming | Matugen: colors from wallpaper for all apps |
| 09 | Wallpaper | hyprpaper + mpvpaper, orchestrator, fzf picker |
| 10 | Session | hyprlock, hypridle, SDDM |
| 11 | Apps | Nautilus, yazi, cliphist, playerctl, screenshots |
| 12 | Network/resume | NetworkManager, Bluetooth, post-suspend fixes |
| 13 | Monitoring | StatsPopup, lm_sensors, btop |
| 14 | Hardware | Automatic GPU/laptop/touchpad/fingerprint detection |
| 15 | Validation | Final check of all components |

---

## Wallpaper and theming

Every time the wallpaper, theme, or mode changes, `apply-shell-state` runs automatically:
it calls Matugen to generate a Material You palette from the current wallpaper, applies
an optional per-theme color transform, then reloads Quickshell, Hyprland, kitty, and SwayNC.

### Wallpaper

```bash
# Set static wallpaper
kingstra-wallpaper set ~/Pictures/Wallpapers/photo.png

# Video wallpaper (mpvpaper)
kingstra-wallpaper video ~/Videos/background.mp4

# Random wallpaper
kingstra-wallpaper random

# Interactive picker (fzf + preview)
kingstra-wallpaper pick

# Status
kingstra-wallpaper status
```

Keybind: `Super + W` opens the visual wallpaper picker.

### Themes

Themes control the visual personality of the desktop: Matugen scheme type, blur, transparency,
corner radius, fonts, and subtle color transforms on top of the generated palette.

| Theme | Description | Scheme |
|---|---|---|
| `botanical` | Temperate rainforest — moss, wood, filtered light | scheme-vibrant |
| `rocky` | Granite — angular, solid, no-nonsense | scheme-monochrome |
| `ocean` | Deep sea — cool, calm, fluid | scheme-fidelity |
| `space` | Cosmic — deep, dark, floating panels | scheme-expressive |
| `cyber` | Neon — high contrast, sharp, electric | scheme-rainbow |
| `animated` | Vibrant — colourful, dynamic, expressive | scheme-fruit-salad |

Switch theme from the terminal or keybind:

```bash
kingstra-theme-switch botanical
```

Keybind: `Super + Ctrl + T` opens the visual theme picker.

### Modes

Modes reconfigure the TopBar module set and bar behaviour for the current activity.

| Mode | Bar | Modules |
|---|---|---|
| `office` (default) | Always visible | Workspaces, window title, clock, network, battery, volume, bluetooth, notifications |
| `gaming` | Always visible | Workspaces, CPU/GPU/RAM temp, audio device, mic mute, game launcher, clock |
| `media` | Auto-hide (3 s) | Volume, brightness, media controls, clock |

Switch mode from the terminal or keybind:

```bash
kingstra-mode-switch gaming
```

Keybind: `Super + Ctrl + M` opens the visual mode picker.

---

## Hardware detection

The installer automatically detects:

| Hardware | Variable | Action |
|---|---|---|
| Nvidia GPU | `DETECT_GPU=nvidia` | env vars, cursor fix, nvidia-utils |
| AMD GPU | `DETECT_GPU=amd` | VA-API driver (radeonsi) |
| Laptop/battery | `DETECT_IS_LAPTOP=true` | power-profiles, short timeouts |
| Backlight | `DETECT_HAS_BACKLIGHT=true` | brightnessctl, hypridle dim |
| Touchpad | `DETECT_HAS_TOUCHPAD=true` | natural scroll, tap-to-click |
| Fingerprint | `DETECT_HAS_FINGERPRINT=true` | fprintd, PAM configuration |

To override detected values:
```bash
# my-overrides.conf
ENABLE_FINGERPRINT=false
ENABLE_VIDEO_WALLPAPER=false
ENABLE_SPICETIFY=true
```

---

## Important paths

| Path | Contents |
|---|---|
| `~/.config/hypr/` | Hyprland configuration (symlinked from repo) |
| `~/.config/hypr/conf.d/72-hardware.conf` | Generated hardware config |
| `~/.config/quickshell/` | Quickshell/QML top bar |
| `~/.config/matugen/` | Matugen templates |
| `~/.config/kingstra-dots/` | This repo |
| `~/.local/bin/kingstra-*` | Installer scripts |
| `~/.local/share/kingstra/` | Logs, backups, markers |
| `~/Pictures/Wallpapers/` | Wallpapers |

---

## Keybindings

See [docs/keybindings.md](docs/keybindings.md) for the full list.

Quick overview:

| Keybinding | Action |
|---|---|
| `Super + Return` | Kitty |
| `Super + Ctrl + Return` | Walker launcher |
| `Super + E` | Nautilus |
| `Super + Shift + E` | Yazi (terminal file manager) |
| `Super + N` | SwayNC control center |
| `Super + V` | Clipboard history |
| `Super + X` | Power menu |
| `Super + Alt + N` | nmtui (network) |
| `Print` | Screenshot |

---

## Credits

Inspired by [imperative-dots](https://github.com/ilyamiro/imperative-dots) by ilyamiro.

## License

MIT — see [LICENSE](LICENSE).
