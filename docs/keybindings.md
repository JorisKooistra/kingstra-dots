# Keybindings — kingstra-dots

> **Super** = Windows/Meta key  
> Binds are split across `config/hypr/conf.d/80-84-binds-*.conf`

---

## Windows

| Keys | Action |
|---|---|
| `Super + H/J/K/L` | Focus left / down / up / right |
| `Super + ←↓↑→` | Focus (arrow keys, with monitor fallback) |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + Shift + ←↓↑→` | Move window (arrow keys) |
| `Super + Ctrl + ←↓↑→` | Resize window |
| `Super + LMB drag` | Move window (mouse) |
| `Super + RMB drag` | Resize window (mouse) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + M` | Maximize (keep bar/gaps) |
| `Super + T` | Toggle floating |
| `Super + Alt + T` | Pin (always visible across workspaces) |
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
| `Super + Ctrl + Shift + G` | Lock/unlock group |
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
| `Super + V` | Clipboard history (cliphist, paste selection) |
| `Super + Shift + Return` | btop in kitty |
| `Super + Shift + C` | cava in kitty |
| `Super + Alt + I` | nmtui (network manager in kitty) |
| `Super + Alt + B` | Blueman (Bluetooth) |
| `Super + Ctrl + B` | Reload Hyprland config |

---

## Widgets

| Keys | Action |
|---|---|
| `Super + N` | Toggle SwayNC control center |
| `Super + Shift + N` | Dismiss all notifications |
| `Super + Alt + N` | Toggle do-not-disturb |
| `Super + Shift + W` | Random wallpaper (from skwd-wall folder) |
| `Super + Ctrl + W` | Wallpaper picker |
| `Super + Shift + T` | Apply next theme (cyclic) |
| `Super + Ctrl + T` | Theme picker |
| `Super + Ctrl + M` | Mode picker (office / gaming / media) |
| `Super + Ctrl + G` | Game launcher |
| `Super + Shift + M` | Music popup |
| `Super + Ctrl + C` | Calendar popup |
| `Super + O` | Monitor overview |
| `Super + X` | FocusTime / power menu |
| `Super + Ctrl + I` | Settings panel |
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
| `Super + Ctrl + L` | Lock (hyprlock+fingerprint if available, otherwise Quickshell) |
| Lid close | Lock screen |
| Tablet mode switch | Rotate internal display and open on-screen keyboard (touchscreen/2-in-1 only) |
| `Super + Ctrl + F12` | Toggle tablet mode fallback (touchscreen/2-in-1 only) |
| `Super + Ctrl + R` | Reload Hyprland |
| `Super + Ctrl + Q` | End session |

---

## Design rules

1. `Super` = window management and navigation  
2. `Super + Shift` = direct quick actions  
3. `Super + Ctrl` = panels/pickers/session controls  
4. `Super + Alt` = secondary window/group/media actions  
5. Media keys = direct hardware functions  
6. Widget binds don't interrupt workflow  
7. No duplicate combos — checked by installer
