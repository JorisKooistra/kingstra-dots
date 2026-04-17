# kingstra-dots

Personal Hyprland rice for Arch Linux. Modular, reproducible, fully automated installation.

---

## Features

### Compositor — Hyprland

Hyprland with a 16-file `conf.d` modular config. Every concern lives in its own file:
colors, theme, decoration, animations, window rules, autostart, keybindings, and hardware overrides.
The file `99-custom.conf` is never touched by the installer — user tweaks survive updates.

### Bar — Quickshell (QML)

~24k lines of QML across 64 files. The bar adapts to position (`top`, `bottom`, `left`, `right`):
horizontal layout for top/bottom, vertical sidebar for left/right.

Modules: workspaces, active window title, system stats (CPU/RAM/network/battery),
media controls, notifications button, clock, tray icons, and more.
Each activity mode (see **Modes** below) activates a different module set.

### Theming — Material You via Matugen

Every wallpaper change triggers a full color pipeline:

1. Matugen generates a Material You palette from the wallpaper image.
2. The active theme applies a hue/saturation/lightness transform on top.
3. Colors propagate to Hyprland, Quickshell, kitty, oh-my-posh, GTK 3/4, Qt6, SwayNC, Walker, and SDDM.

The pipeline is centralized in `apply-shell-state` and `kingstra-matugen-run` — no per-app tweaking needed.

### Themes

Six distinct visual personalities. Each theme defines its own Matugen scheme type, blur, opacity,
corner radius, fonts, color transforms, bar/widget shapes, ornaments, particle effects, and terminal style.

| Theme | Description | Scheme |
|---|---|---|
| `botanical` | Temperate rainforest — moss, wood, filtered light | scheme-content |
| `rocky` | Granite — angular, solid, no-nonsense | scheme-monochrome |
| `ocean` | Deep sea — cool, calm, fluid | scheme-fidelity |
| `space` | Cosmic — deep, dark, floating panels | scheme-expressive |
| `cyber` | Neon — high contrast, sharp, electric | scheme-rainbow |
| `animated` | Vibrant — colourful, dynamic, expressive | scheme-fruit-salad |

Switch from the terminal or with `Super + Ctrl + T` to open the visual theme carousel.

```bash
kingstra-theme-switch botanical
```

### Modes

Modes reconfigure the bar module set and autohide behaviour for the current activity.
Theme identity (shape, ornaments, particles) stays fixed — only content and behaviour change.

| Mode | Bar | Modules |
|---|---|---|
| `office` (default) | Always visible | Workspaces, window title, clock, network, battery, volume, bluetooth, notifications |
| `gaming` | Always visible | Workspaces, CPU/GPU/RAM temps, audio device, mic mute, game launcher, clock |
| `media` | Auto-hide (3 s) | Volume, brightness, media controls, clock |

Switch with `Super + Ctrl + M` or from the terminal:

```bash
kingstra-mode-switch gaming
```

### Shell — zsh + oh-my-posh

Modular zsh config with a `conf.d/` pattern. The prompt theme (`kingstra.omp.toml`) uses the
active Material You palette, so it automatically matches the wallpaper.

### Terminal — kitty

Configured with JetBrains Mono and Matugen-generated colors. Background, foreground, and accent
colors update automatically on every wallpaper or theme change.

### Wallpaper

Supports both static images (hyprpaper) and video backgrounds (mpvpaper). All picks flow through
the same `apply-shell-state` pipeline to keep colors in sync.

```bash
kingstra-wallpaper set ~/Pictures/photo.png    # static
kingstra-wallpaper video ~/Videos/bg.mp4       # video (mpvpaper)
kingstra-wallpaper random                      # random from collection
kingstra-wallpaper pick                        # interactive fzf picker with preview
kingstra-wallpaper status                      # show active wallpaper
```

Keybinds: `Super + Shift + W` (random) and `Super + Ctrl + W` (visual picker).

### Launcher — Walker

Walker app launcher with sub-modes for SSH hosts, calculator, and more.
Opens with `Super + Ctrl + Return`. Colors follow the active theme.

### Notifications — SwayNC

SwayNC as notification daemon and control center. Supports MPRIS media controls inline,
do-not-disturb, and is styled with Matugen colors. Toggle with `Super + N`.

### OSD — SwayOSD

On-screen display for volume and brightness changes. Appears on hardware key presses.

### Lockscreen — hyprlock

Styled with Material You colors. Supports fingerprint unlock via PAM (see **Hardware detection**).

### Game launcher

[quickshell-games-launchers](https://github.com/Eaquo/quickshell-games-launchers) integrated
into the bar: Steam, Epic, GOG, and Heroic with cover art. Accessible via `Super + Alt + G`
or automatically visible in gaming mode.

### File management

- **Nautilus** — GUI file manager (`Super + E`)
- **Yazi** — Terminal file manager with image previews (`Super + Shift + E`)

### Monitoring

StatsPopup widget and btop for system monitoring. Gaming mode shows per-core CPU and GPU temperature.
lm_sensors provides hardware sensor data.

### Clipboard — cliphist

Clipboard history with `Super + V`. Stores text and images.

### Touchscreen support

Auto-detects touchscreen hardware and applies a touch profile: larger UI scale, bigger bar hit
targets, touch-friendly scrolling. Tablet mode switch (rotate display + on-screen keyboard) is
also handled automatically.

Override: `KINGSTRA_FORCE_TOUCH=1` / `KINGSTRA_FORCE_TOUCH=0`.

### Hardware detection

The installer auto-detects and configures:

| Hardware | Variable | Action |
|---|---|---|
| Nvidia GPU | `DETECT_GPU=nvidia` | env vars, cursor fix, nvidia-utils |
| AMD GPU | `DETECT_GPU=amd` | VA-API driver (radeonsi) |
| Laptop/battery | `DETECT_IS_LAPTOP=true` | power-profiles, short idle timeouts |
| Backlight | `DETECT_HAS_BACKLIGHT=true` | brightnessctl, hypridle dim |
| Touchpad | `DETECT_HAS_TOUCHPAD=true` | natural scroll, tap-to-click |
| Touchscreen | `DETECT_HAS_TOUCHSCREEN=true` | touch profile, tablet mode on laptops |
| Tablet mode switch | `DETECT_HAS_TABLET_MODE_SWITCH=true` | rotate internal display + OSK on tablet switch |
| Fingerprint | `DETECT_HAS_FINGERPRINT=true` | fprintd, PAM for sudo + SDDM |

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
| `Super + Alt + G` | Game launcher |
| `Super + Alt + N` | nmtui (network) |
| `Super + Ctrl + T` | Theme picker |
| `Super + Ctrl + W` | Wallpaper picker |
| `Super + Ctrl + M` | Mode picker |
| `Super + Shift + W` | Random wallpaper |
| `Print` | Screenshot |

---

## Notes

### SDDM fingerprint flow

The Kingstra greeter starts an empty PAM login once and shows a fingerprint status card while
waiting for the scanner. If SDDM or PAM misses that first attempt, press `Enter` on an empty
password field to trigger fingerprint auth again; typing a password remains the fallback.

### Overriding detected hardware values

```bash
# my-overrides.conf
ENABLE_FINGERPRINT=false
ENABLE_VIDEO_WALLPAPER=false
ENABLE_SPICETIFY=true
```

Pass with `bash install.sh --override my-overrides.conf`.

---

## Credits

Inspired by [imperative-dots](https://github.com/ilyamiro/imperative-dots) by ilyamiro.

## License

MIT — see [LICENSE](LICENSE).
