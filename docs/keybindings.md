# Keybindings — kingstra-dots

> **Super** = Windows/Meta key  
> Binds are split across `config/hypr/conf.d/80-84-binds-*.conf`

---

## Windows

| Keys | Action |
|---|---|
| `Super + H/J/K/L` | Focus left / down / up / right |
| `Super + ←↓↑→` | Focus (arrow keys) |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + Shift + ←↓↑→` | Move window (arrow keys) |
| `Super + Ctrl + ←↓↑→` | Resize window |
| `Super + LMB drag` | Move window (mouse) |
| `Super + RMB drag` | Resize window (mouse) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + M` | Maximize (keep bar/gaps) |
| `Super + T` | Toggle floating |
| `Super + Shift + T` | Pin (always visible) |
| `Super + Shift + Space` | Center floating window |
| `Super + P` | Pseudotile (dwindle) |
| `Super + \` | Toggle split direction (dwindle) |

---

## Window groups (tabs)

| Keys | Action |
|---|---|
| `Super + G` | Toggle group |
| `Super + Alt + →` | Next tab in group |
| `Super + Alt + ←` | Previous tab in group |
| `Super + Ctrl + G` | Lock/unlock group |
| `Super + Shift + G` | Move window out of group |

---

## Workspaces

| Keys | Action |
|---|---|
| `Super + 1–0` | Switch to workspace 1–10 |
| `Super + Tab` | Previous workspace |
| `Super + Scroll` | Cycle workspaces |
| `Super + Shift + 1–0` | Move window to workspace 1–10 |
| `Super + Alt + 1–0` | Move window silently (keep focus) |
| `Super + S` | Toggle scratchpad |
| `Super + Shift + S` | Move window to scratchpad |

---

## Apps

| Keys | Action |
|---|---|
| `Super + Return` | Kitty (terminal) |
| `Super + Ctrl + Return` | Walker (launcher) |
| `Super + B` | Browser (default) |
| `Super + E` | Nautilus (files) |
| `Super + Shift + E` | Yazi (terminal file manager) |
| `Super + V` | Clipboard history (cliphist) |
| `Super + Shift + Return` | btop in kitty |
| `Super + Shift + C` | cava in kitty |
| `Super + Alt + N` | nmtui (network manager in kitty) |
| `Super + Alt + B` | Blueman (Bluetooth) |
| `Super + Ctrl + B` | Reload Hyprland config |

---

## Widgets

| Keys | Action |
|---|---|
| `Super + N` | Toggle SwayNC control center |
| `Super + Shift + N` | Dismiss all notifications |
| `Super + Alt + N` | Toggle do-not-disturb |
| `Super + W` | Wallpaper picker |
| `Super + Ctrl + T` | Theme picker |
| `Super + Ctrl + M` | Mode picker (office / gaming / media) |
| `Super + Alt + G` | Game launcher (quickshell-games-launchers) |
| `Super + Shift + M` | Music popup |
| `Super + C` | Calendar popup |
| `Super + O` | Monitor overview |
| `Super + X` | FocusTime / power menu |
| `Super + Shift + I` | Settings panel |
| Click CPU/RAM pill | Stats popup |

---

## Screenshots

| Keys | Action |
|---|---|
| `Print` | Select area → save + copy |
| `Super + Print` | Select area → copy only |
| `Shift + Print` | Select area → annotate (satty) |
| `Super + Shift + P` | Full screen capture |

Screenshots are saved to `~/Pictures/Screenshots/`.

---

## Media

| Keys | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86MonBrightnessUp` | Brightness up |
| `XF86MonBrightnessDown` | Brightness down |
| `XF86AudioPlay/Pause` | Play/pause |
| `XF86AudioNext/Prev` | Next/previous track |
| `Super + Alt + P` | Play/pause |
| `Super + Alt + .` | Next track |
| `Super + Alt + ,` | Previous track |

---

## Session

| Keys | Action |
|---|---|
| `Super + Ctrl + L` | Lock (Quickshell lock, fallback hyprlock) |
| `Super + Ctrl + R` | Reload Hyprland |
| `Super + Ctrl + Q` | End session |

---

## Design rules

1. `Super` = window management and navigation  
2. `Super + Shift` = action on current window  
3. `Super + Ctrl` = system/session or window size  
4. `Super + Alt` = silent move, group nav, or media  
5. Media keys = direct hardware functions  
6. Widget binds don't interrupt workflow  
7. No duplicate combos — checked by installer
