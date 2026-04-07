# kingstra-dots

Eigen Hyprland rice voor Arch Linux. Modulair, reproduceerbaar, volledig automatisch te installeren.

---

## Kenmerken

- **Compositor** — Hyprland met modulaire `conf.d`-structuur
- **Bar** — Quickshell (QML): werkruimtes, klok, actief venster, CPU/RAM, media, meldingen
- **Thema** — Matugen genereert Material You-kleuren vanuit de wallpaper
- **Shell** — zsh + oh-my-posh, thema volgt de wallpaper-kleuren
- **Terminal** — kitty met Matugen-kleuren en JetBrains Mono
- **Launcher** — Walker (`Super+Ctrl+Return`)
- **Meldingen** — SwayNC (control center rechtsonder)
- **Wallpaper** — hyprpaper (statisch) + mpvpaper (video, optioneel)
- **Lockscreen** — hyprlock, stijl volgt Matugen-kleuren
- **OSD** — SwayOSD (volume, helderheid)
- **Bestandsbeheer** — Nautilus + Yazi (terminal)
- **Hardware** — automatische detectie: Nvidia/AMD/Intel, laptop, touchpad, vingerafdruk

---

## Installatie

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh)
```

De bootstrap kloont de repo naar `~/kingstra-dots` en start de installer automatisch.

**Met opties:**
```bash
# Dry-run — bekijk wat er zou gebeuren zonder iets te installeren
bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh) --dry-run

# Andere installatiemap
KINGSTRA_DIR=~/.config/kingstra-dots bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh)
```

**Handmatig (na klonen):**
```bash
# Één fase uitvoeren
bash install.sh --phase 09_wallpaper

# Vanaf een fase verdergaan
bash install.sh --from-phase 10_session

# Feature-flags overschrijven
echo "ENABLE_FINGERPRINT=false" > my-overrides.conf
bash install.sh --override my-overrides.conf
```

### Vereisten

- Arch Linux (pacman)
- AUR-helper (`yay` of `paru`) — vereist voor AUR-pakketten
- bash 4.4+
- git

---

## Installatiefasen

| # | Fase | Inhoud |
|---|---|---|
| 01 | Projectskelet | Mappenstructuur, installervalidatie |
| 02 | Shell/terminal | zsh, oh-my-posh, kitty, fastfetch, cava |
| 03 | Hyprland core | Modulaire config, screenshots, GTK, portalen |
| 04 | Bindingen | 5 bind-bestanden, duplicaatcontrole |
| 05 | Quickshell UI | Topbar, workspaces, klok, stats, media, power |
| 06 | Meldingen | SwayNC: control center, mpris, DND |
| 07 | Launcher | Walker: app launcher, ssh, calculatie |
| 08 | Thema | Matugen: kleuren uit wallpaper voor alle apps |
| 09 | Wallpaper | hyprpaper + mpvpaper, orchestrator, fzf-picker |
| 10 | Sessie | hyprlock, hypridle, SDDM |
| 11 | Apps | Nautilus, yazi, cliphist, playerctl, screenshots |
| 12 | Netwerk/resume | NetworkManager, Bluetooth, post-suspend fixes |
| 13 | Monitoring | StatsPopup, lm_sensors, btop |
| 14 | Hardware | Automatische GPU/laptop/touchpad/fingerprint-aanpassing |
| 15 | Validatie | Eindcontrole van alle componenten |

---

## Wallpaper en thema

```bash
# Statisch wallpaper instellen (triggert automatisch Matugen)
kingstra-wallpaper set ~/Pictures/Wallpapers/foto.png

# Videowallpaper
kingstra-wallpaper video ~/Videos/achtergrond.mp4

# Willekeurig
kingstra-wallpaper random

# Interactieve picker (fzf + preview)
kingstra-wallpaper pick

# Status
kingstra-wallpaper status
```

---

## Hardware-detectie

De installer detecteert automatisch:

| Hardware | Variabele | Actie |
|---|---|---|
| Nvidia GPU | `DETECT_GPU=nvidia` | env vars, cursor fix, nvidia-utils |
| AMD GPU | `DETECT_GPU=amd` | VA-API driver (radeonsi) |
| Laptop/batterij | `DETECT_IS_LAPTOP=true` | power-profiles, korte timeouts |
| Backlight | `DETECT_HAS_BACKLIGHT=true` | brightnessctl, hypridle dim |
| Touchpad | `DETECT_HAS_TOUCHPAD=true` | natural scroll, tap-to-click |
| Vingerafdruk | `DETECT_HAS_FINGERPRINT=true` | fprintd, PAM-configuratie |

Om gedetecteerde waarden te overschrijven:
```bash
# my-overrides.conf
ENABLE_FINGERPRINT=false
ENABLE_VIDEO_WALLPAPER=false
ENABLE_SPICETIFY=true
```

---

## Belangrijke paden

| Pad | Inhoud |
|---|---|
| `~/.config/hypr/` | Hyprland configuratie (symlink naar repo) |
| `~/.config/hypr/conf.d/72-hardware.conf` | Gegenereerde hardware-config |
| `~/.config/quickshell/` | Quickshell/QML topbar |
| `~/.config/matugen/` | Matugen templates |
| `~/.config/kingstra-dots/` | Deze repo |
| `~/.local/bin/kingstra-*` | Installer scripts |
| `~/.local/share/kingstra/` | Logs, backups, markers |
| `~/Pictures/Wallpapers/` | Wallpapers |

---

## Toetscombinaties

Zie [docs/keybindings.md](docs/keybindings.md) voor de volledige lijst.

Snel overzicht:

| Combinatie | Actie |
|---|---|
| `Super + Return` | Kitty |
| `Super + Ctrl + Return` | Walker launcher |
| `Super + E` | Nautilus |
| `Super + Shift + E` | Yazi (terminal bestandsbeheer) |
| `Super + N` | SwayNC control center |
| `Super + V` | Klembordgeschiedenis |
| `Super + X` | Power-menu |
| `Super + Alt + N` | nmtui (netwerk) |
| `Print` | Screenshot |

---

## Licentie

MIT
