# Keybindings — kingstra-dots

> **Super** = Windows/Meta key  
> Binds zijn verdeeld over `config/hypr/conf.d/80–84-binds-*.conf`

---

## Ontwerpregels

| Modifier | Gebruik |
|---|---|
| `Super` | Vensterbeheer en navigatie |
| `Super + Shift` | Directe snelacties |
| `Super + Ctrl` | Panelen, pickers en sessiebeheer |
| `Super + Alt` | Secundaire venster-, groep- en media-acties |
| Mediatoetsen | Directe hardwarefuncties |

Alle combinaties worden bij installatie automatisch gecontroleerd op duplicaten.

---

## Vensters — focus

| Toetsen | Actie |
|---|---|
| `Super + H` | Focus naar links |
| `Super + J` | Focus naar beneden |
| `Super + K` | Focus naar boven |
| `Super + L` | Focus naar rechts |
| `Super + ←↓↑→` | Focus (pijltoetsen, met monitor-fallback) |

---

## Vensters — verplaatsen en aanpassen

| Toetsen | Actie |
|---|---|
| `Super + Shift + H/J/K/L` | Venster verplaatsen |
| `Super + Shift + ←↓↑→` | Venster verplaatsen (pijltoetsen) |
| `Super + Ctrl + ←↓↑→` | Venster aanpassen (60px per druk) |
| `Super + LMB slepen` | Venster verslepen (muis) |
| `Super + RMB slepen` | Venster aanpassen (muis) |

---

## Vensters — toestand

| Toetsen | Actie |
|---|---|
| `Super + Q` | Venster sluiten |
| `Super + F` | Volledig scherm |
| `Super + M` | Maximaliseren (balk + gaps blijven zichtbaar) |
| `Super + T` | Zwevend/geplaatst wisselen |
| `Super + Alt + T` | Vastzetten op alle werkruimten (pin) |
| `Super + Shift + Space` | Zwevend venster centreren |
| `Super + P` | Pseudo-tiling (dwindle) |
| `Super + \` | Split-richting wisselen (dwindle) |

---

## Venstergroepen (tabs)

| Toetsen | Actie |
|---|---|
| `Super + G` | Groepsmodus in-/uitschakelen |
| `Super + Alt + →` | Volgende tab in groep |
| `Super + Alt + ←` | Vorige tab in groep |
| `Super + Ctrl + Shift + G` | Groep vergrendelen/ontgrendelen |
| `Super + Shift + G` | Venster uit groep halen |

---/

## Werkruimten

| Toetsen | Actie |
|---|---|
| `Super + 1–0` | Naar werkruimte 1–10 |
| `Super + Tab` | Vorige werkruimte |
| `Super + Scroll` | Door werkruimten bladeren |
| `Super + Shift + 1–0` | Venster naar werkruimte 1–10 verplaatsen |
| `Super + Alt + 1–0` | Venster stil verplaatsen (focus blijft hier) |
| `Super + S` | Scratchpad in-/uitschakelen |
| `Super + Shift + S` | Venster naar scratchpad sturen |

---/

## Applicaties

| Toetsen | Actie |
|---|---|
| `Super + Return` | Kitty (terminal) |
| `Super + Ctrl + Return` | Walker (launcher) |
| `Super + B` | Browser (standaard) |
| `Super + E` | Nautilus (bestandsbeheer) |
| `Super + Shift + E` | Yazi (terminal bestandsbeheer) |
| `Super + V` | Klembordgeschiedenis (cliphist) |
| `Super + Shift + Return` | btop in Kitty |
| `Super + Shift + C` | cava (audio visualizer) in Kitty |
| `Super + Alt + I` | nmtui (netwerk) in Kitty |
| `Super + Alt + B` | Blueman (Bluetooth) |
| `Super + Ctrl + B` | Hyprland config herladen (+ melding) |

---

## Widgets

| Toetsen | Actie |
|---|---|
| `Super + N` | SwayNC meldingscentrum in-/uitschakelen |
| `Super + Shift + N` | Alle meldingen sluiten |
| `Super + Alt + N` | Niet-storen in-/uitschakelen |
| `Super + Shift + W` | Willekeurige wallpaper (uit skwd-map) |
| `Super + Ctrl + W` | Wallpaper picker |
| `Super + Shift + T` | Volgend thema (cyclisch) |
| `Super + Ctrl + T` | Thema picker |
| `Super + Ctrl + M` | Modus picker (office / gaming / media) |
| `Super + Ctrl + G` | Game launcher |
| `Super + Shift + M` | Muziek popup |
| `Super + Ctrl + C` | Kalender popup |
| `Super + O` | Monitor overzicht |
| `Super + X` | FocusTime / power menu |
| `Super + Ctrl + I` | Instellingenpaneel |
| Klik op CPU/RAM-pil | Systeemstats popup |

---

## Screenshots

| Toetsen | Actie |
|---|---|
| `Print` | Gebied selecteren → opslaan + kopiëren |
| `Super + Print` | Gebied selecteren → alleen kopiëren |
| `Shift + Print` | Gebied selecteren → bewerken in satty |
| `Super + Shift + P` | Volledig scherm opslaan |

Opgeslagen in `~/Pictures/Screenshots/`.

---

## Media

| Toetsen | Actie |
|---|---|
| `XF86AudioRaiseVolume` | Volume omhoog (SwayOSD) |
| `XF86AudioLowerVolume` | Volume omlaag (SwayOSD) |
| `XF86AudioMute` | Geluid dempen |
| `XF86AudioMicMute` | Microfoon dempen |
| `XF86MonBrightnessUp` | Helderheid omhoog (SwayOSD) |
| `XF86MonBrightnessDown` | Helderheid omlaag (SwayOSD) |
| `XF86AudioPlay` / `XF86AudioPause` | Afspelen/pauzeren |
| `XF86AudioNext` | Volgend nummer |
| `XF86AudioPrev` | Vorig nummer |
| `XF86AudioStop` | Stoppen |
| `Super + Alt + P` | Afspelen/pauzeren (zonder mediatoets) |
| `Super + Alt + .` | Volgend nummer |
| `Super + Alt + ,` | Vorig nummer |

---

## Sessie

| Toetsen | Actie |
|---|---|
| `Super + Ctrl + L` | Scherm vergrendelen (hyprlock + vingerafdruk indien beschikbaar) |
| Laptop dichtklappen | Scherm vergrendelen |
| `Super + Ctrl + R` | Hyprland herladen |
| `Super + Ctrl + Backspace` | Sessie afsluiten |
| `Super + Ctrl + F12` | Tabletmodus handmatig wisselen (touchscreen/2-in-1) |
| Tabletmodus-schakelaar | Intern scherm roteren + schermtoetsenbord openen (automatisch) |