# Keybindings — kingstra-dots

> **Super** = Windows/Meta key  
> Binds staan in `config/hypr/lua/binds.lua`.

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
| `Duimknop slepen` | Venster verslepen (Logitech M720, via logiops) |
| `Duimknop dubbelklik` | Overzicht openen (zelfde als Super + Tab) |

---

## Vensters — toestand

| Toetsen | Actie |
|---|---|
| `Super + Q` | Venster sluiten |
| `Super + F` | Volledig scherm |
| `Super + M` | Maximaliseren (balk + gaps blijven zichtbaar) |
| `Super + T` | Zwevend/geplaatst wisselen; onthouden per app, inclusief grootte en positie (`~/.local/state/kingstra/floating-apps`) |
| `Super + Alt + T` | Vastzetten op alle werkruimten (pin) |
| `Super + Shift + Space` | Zwevend venster centreren |
| `Super + P` | Pseudo-tiling (dwindle) |
| `Super + \` | Split-richting wisselen (dwindle) |

---

## Indelingen en kladblok

| Toetsen | Actie |
|---|---|
| `Super + Z` | Snap-indeling kiezen voor deze werkruimte (1-8, klik een vak) |
| `Super + Alt + S` | Scrollende kolommen aan/uit op deze werkruimte |
| `Super + Alt + Z` | Zen-modus aan/uit (balk verborgen, niet storen, rest gedimd) |
| `Super + Shift + wiel` | Strook: volgende/vorige kolom; ruimtelijk: omhoog/omlaag |
| `Super + Ctrl + .` / `,` | Scrollen: kolom breder / smaller |
| ``Super + ` `` | Kladblok tonen/verbergen |
| ``Super + Shift + ` `` | Actief venster naar het kladblok, of terug |
| `Super + -` | Actief venster parkeren (minimaliseren) |
| `Super + Shift + -` | Laatst geparkeerde venster terug op zijn eigen werkruimte |
| `Super + W` | Vensterlijst: geparkeerde vensters staan onderaan, Enter haalt terug |
| 3 vingers omlaag / omhoog | Controlecentrum / overzicht |

---

## Venstergroepen (tabs)

| Toetsen | Actie |
|---|---|
| `Super + G` | Groepsmodus in-/uitschakelen |
| `Super + Alt + →` | Volgende tab in groep |
| `Super + Alt + ←` | Vorige tab in groep |
| `Super + Ctrl + Shift + G` | Groep vergrendelen/ontgrendelen |
| `Super + Shift + G` | Venster uit groep halen |

---

## Werkruimten

| Toetsen | Actie |
|---|---|
| `Super + 1–0` | Naar werkruimte 1–10 |
| `Super + Tab` | Werkruimte-overzicht; op een ruimtelijke werkruimte de vensterkaart |
| `Alt + Tab` | Vorige werkruimte |
| `Super + Scroll` | Door werkruimten bladeren |
| `Super + Shift + 1–0` | Venster naar werkruimte 1–10 verplaatsen |
| `Super + Alt + 1–0` | Venster stil verplaatsen (focus blijft hier) |
| `Super + S` | Spotify-werkruimte tonen/verbergen |
| `Super + Shift + S` | Venster naar de Spotify-werkruimte sturen |

---

## Applicaties

| Toetsen | Actie |
|---|---|
| `Super + Return` | Kitty (terminal) |
| `Super + Ctrl + Return` | App launcher |
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
| `Super + N` | Quickshell meldingscentrum in-/uitschakelen |
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
| `Super + X` | FocusTime |
| `Super + A` | Controlecentrum (snelle instellingen, agenda, media, meldingen) |
| `Super + ,` / `Super + Ctrl + I` | Bediening en instellingen (eigen app, ook in de launcher) |
| `Super + Alt + Space` | Toetsenbordmenu voor alles (thema, modus, schermen, systeem, sessie) |
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
| `XF86AudioRaiseVolume` | Volume omhoog (eiland, anders SwayOSD) |
| `XF86AudioLowerVolume` | Volume omlaag (eiland, anders SwayOSD) |
| `XF86AudioMute` | Geluid dempen |
| `XF86AudioMicMute` | Microfoon dempen |
| `XF86MonBrightnessUp` | Helderheid omhoog (eiland, anders SwayOSD) |
| `XF86MonBrightnessDown` | Helderheid omlaag (eiland, anders SwayOSD) |
| `XF86AudioPlay` / `XF86AudioPause` | Afspelen/pauzeren |
| `XF86AudioNext` | Volgend nummer |
| `XF86AudioPrev` | Vorig nummer |
| `XF86AudioStop` | Stoppen |
| `Super + Alt + P` | Afspelen/pauzeren (zonder mediatoets) |
| `Super + Alt + .` | Volgend nummer |
| `Super + Alt + ,` | Vorig nummer |

---

## Passthrough (Citrix, VM's, remote desktops)

| Toetsen | Actie |
|---|---|
| `Super + Escape` | Passthrough aan/uit — alle Super-binds gaan naar het venster zelf |

Bij Citrix-vensters (wfica) gebeurt dit automatisch via `citrix-guard.sh`:
zodra het venster focus krijgt, worden alle Super-shortcuts doorgegeven aan
de remote sessie (voorkomt crashes op de Super-toets); bij focusverlies komen
de binds automatisch terug.

---

## Sessie

| Toetsen | Actie |
|---|---|
| `Super + Ctrl + L` | Quickshell-vergrendelscherm (hyprlock als terugval) |
| Laptop dichtklappen | Scherm vergrendelen |
| `Super + Ctrl + R` | Hyprland herladen |
| `Super + Ctrl + Backspace` | Sessie afsluiten |
| `Super + Ctrl + F12` | Tabletmodus handmatig wisselen (touchscreen/2-in-1) |
| Tabletmodus-schakelaar | Intern scherm roteren + schermtoetsenbord openen (automatisch) |

## Ruimtelijk werkvlak

Kies **Ruimtelijk werkvlak** in Bediening of **Super+Z**. Bestaande werkruimtes
worden bij een update niet automatisch omgezet.

- **Super+pijlen:** nabijgelegen venster kiezen.
- **Super+Shift+pijlen:** venster verplaatsen of met een bezette plek wisselen.
- **Super+Ctrl+Alt+pijlen:** het zichtgebied verplaatsen, zonder vensters te verplaatsen.
- **Super+drievingerveeg:** vrij in beide richtingen bewegen, ook diagonaal
  (vereist live Lua-gebaren).
- **Super+Shift+wiel:** omhoog/omlaag; met een horizontaal wiel ook links/rechts.
- **Super+Ctrl+, / .:** breedte kleiner/groter.
- **Super+Tab:** kaart openen; sleep om vrij te bewegen, wiel om de kaart te
  vergroten/verkleinen, kies een venster om erop terug te keren.
- **Esc** in de kaart: sluiten.

Gewone appscroll blijft bij de app. De ruimtelijke acties zijn buiten die layout
niet actief; de bestaande focus- en vensteracties blijven daar werken.

Gebruik **Super+,** of `kingstra bediening` voor schermmode, rail en muziek.
