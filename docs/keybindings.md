# Keybindings — kingstra-dots

> **Super** = Windows/Meta-toets  
> Binds zijn verdeeld over `config/hypr/conf.d/80-84-binds-*.conf`

---

## Vensters

| Toetsen | Actie |
|---|---|
| `Super + H/J/K/L` | Focus links / omlaag / omhoog / rechts |
| `Super + ←↓↑→` | Focus (pijltoetsen) |
| `Super + Shift + H/J/K/L` | Venster verplaatsen |
| `Super + Ctrl + ←↓↑→` | Venster aanpassen |
| `Super + Muis links` | Venster slepen |
| `Super + Muis rechts` | Venster aanpassen |
| `Super + Q` | Venster sluiten |
| `Super + F` | Volledig scherm |
| `Super + Shift + F` | Maximaliseren |
| `Super + T` | Zwevend aan/uit |
| `Super + Shift + T` | Vastpinnen (altijd zichtbaar) |
| `Super + P` | Pseudotile (dwindle) |
| `Super + \` | Split-richting wisselen (dwindle) |

---

## Werkruimtes

| Toetsen | Actie |
|---|---|
| `Super + 1–0` | Naar werkruimte 1–10 |
| `Super + Tab` | Vorige werkruimte |
| `Super + Scroll` | Werkruimte wisselen |
| `Super + Shift + 1–0` | Venster naar werkruimte 1–10 |
| `Super + Alt + 1–0` | Venster stil verplaatsen (focus blijft) |
| `Super + S` | Scratchpad aan/uit |
| `Super + Shift + S` | Venster naar scratchpad |

---

## Applicaties

| Toetsen | Actie |
|---|---|
| `Super + Return` | Kitty (terminal) |
| `Super + Ctrl + Return` | Walker (launcher) |
| `Super + B` | Browser (standaard) |
| `Super + E` | Nautilus (bestanden) |
| `Super + V` | Klembordgeschiedenis (cliphist) |
| `Super + Shift + Return` | btop in kitty |
| `Super + Shift + C` | cava in kitty |

---

## Widgets

| Toetsen | Actie |
|---|---|
| `Super + N` | SwayNC control center aan/uit |
| `Super + Shift + N` | Alle meldingen sluiten |
| `Super + Alt + N` | Niet-storen wisselen |
| `Super + W` | Wallpaper-selector *(fase 9)* |
| `Super + M` | Muziek-popup *(fase 5)* |
| `Super + C` | Kalender-popup *(fase 5)* |
| `Super + O` | Vensteroverzicht *(fase 5)* |
| `Super + X` | Power-menu *(fase 5)* |

---

## Screenshots

| Toetsen | Actie |
|---|---|
| `Print` | Gebied kiezen → opslaan + kopiëren |
| `Super + Print` | Gebied kiezen → alleen kopiëren |
| `Shift + Print` | Gebied kiezen → satty (annotatie) |
| `Super + Shift + P` | Volledig scherm opslaan |

Bestanden worden opgeslagen in `~/Pictures/Screenshots/`.

---

## Media

| Toetsen | Actie |
|---|---|
| `XF86AudioRaiseVolume` | Volume omhoog |
| `XF86AudioLowerVolume` | Volume omlaag |
| `XF86AudioMute` | Dempen aan/uit |
| `XF86AudioMicMute` | Microfoon dempen aan/uit |
| `XF86MonBrightnessUp` | Helderheid omhoog |
| `XF86MonBrightnessDown` | Helderheid omlaag |
| `XF86AudioPlay/Pause` | Afspelen/pauzeren |
| `XF86AudioNext/Prev` | Volgend/vorig nummer |
| `Super + Alt + P` | Afspelen/pauzeren |
| `Super + Alt + .` | Volgend nummer |
| `Super + Alt + ,` | Vorig nummer |

---

## Sessie

| Toetsen | Actie |
|---|---|
| `Super + Ctrl + L` | Vergrendelen (hyprlock) |
| `Super + Ctrl + R` | Hyprland herladen |
| `Super + Ctrl + Q` | Sessie beëindigen |

---

## Ontwerpregels

1. `Super` = vensterbeheer en navigatie  
2. `Super + Shift` = actie op het huidige venster  
3. `Super + Ctrl` = systeem/sessie of venstergrootte  
4. `Super + Alt` = stil verplaatsen of media  
5. Mediatoetsen = directe hardwarefuncties  
6. Widget-binds storen de workflow niet  
7. Geen dubbele combinaties — gecontroleerd door de installer

---

*Gegenereerd door fase 4. Bijgewerkt door fase 5 zodra Quickshell IPC-commando's beschikbaar zijn.*
