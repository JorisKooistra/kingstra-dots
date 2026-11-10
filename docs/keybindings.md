# Keybindings — kingstra-dots

> **Super** = Windows/Meta key  
> Binds staan in `config/hypr/lua/binds.lua`.

Opgeschoond op 28-10-2026: toetsen die niet gebruikt werden zijn weg. De functies
zelf staan in het toetsenbordmenu (`Super + Ctrl + Space`): controlecentrum,
niet storen, schermindeling, kalender, FocusTime, games, yazi, nmtui, Blueman,
vastzetten op alle werkruimtes en de groepsacties. Het controlecentrum opent ook
met een klik op de bovenbalk.

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
| `Super + ←↓↑→` | Focus (pijltoetsen, met monitor-fallback) |

---

## Vensters — verplaatsen en aanpassen

| Toetsen | Actie |
|---|---|
| `Super + Shift + ←↓↑→` | Venster verplaatsen (pijltoetsen) |
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
| `Super + Shift + Space` | Zwevend venster centreren |
| `Super + P` | Pseudo-tiling (dwindle) |
| `Super + \` | Split-richting wisselen (dwindle) |

---

## Indelingen en kladblok

| Toetsen | Actie |
|---|---|
| `Super + Z` | Snap-indeling kiezen voor deze werkruimte (1-8, klik een vak) |
| `Super + Alt + S` | Scrollende kolommen aan/uit op deze werkruimte |
| `Super + Shift + Z` | Zen-modus aan/uit (balk verborgen, niet storen, rest gedimd) |
| `Super + wiel` | Binnen de werkruimte: strook volgende/vorige pagina; ruimtelijk omhoog/omlaag |
| `Super + Alt + wiel` | Binnen de werkruimte opzij (ruimtelijk links/rechts) |
| `Super + Ctrl + linkermuis slepen` | Werkvlak vrij verschuiven; klikt alleen vast als je dicht bij een plek loslaat |
| `Super + Ctrl + wiel` | Echte desktop uit-/inzoomen op de monitor onder de muis (ruimtelijk werkvlak) |
| `Super + Ctrl + middelklik` | Desktopzoom terug naar 100% |
| `Super + Ctrl + Alt + ←→` | Strook: kolom verder; ruimtelijk: zicht in alle richtingen |
| `Super + Ctrl + .` / `,` | Scrollen: kolom breder / smaller |
| ``Super + ` `` | Kladblok tonen/verbergen |
| ``Super + Shift + ` `` | Actief venster naar het kladblok, of terug |
| `Super + -` | Actief venster parkeren (minimaliseren) |
| `Super + Shift + -` | Laatst geparkeerde venster terug op zijn eigen werkruimte |
| `Super + W` | Vensterlijst: geparkeerde vensters staan onderaan, Enter haalt terug |
| 3 vingers | Ruimtelijk werkvlak: het beeld schuift mee, alle kanten op. Elders: opzij vegen wisselt van werkruimte, omhoog/omlaag doet niets |
| Knijpen (2 vingers) | Ruimtelijk werkvlak uit- of inzoomen |

---

## Venstergroepen (tabs)

| Toetsen | Actie |
|---|---|
| `Super + G` | Groepsmodus in-/uitschakelen |
| `Super + Alt + →` | Volgende tab in groep |
| `Super + Alt + ←` | Vorige tab in groep |

---

## Werkruimten

| Toetsen | Actie |
|---|---|
| `Super + 1–0` | Naar werkruimte 1–10 |
| `Super + Tab` | Werkruimte-overzicht; op een ruimtelijke werkruimte de vensterkaart |
| `Alt + Tab` | Vorige werkruimte |
| `Super + Shift + wiel` | Door werkruimten bladeren |
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
| `Super + V` | Klembordgeschiedenis: Enter plakt, Shift+Enter kopieert, Ctrl+P pint vast |
| `Super + .` | Emoji en symbolen (launcher in de emoji-stand) |
| `Super + H` (vasthouden) | Dicteren: praten, loslaten typt de tekst (lokaal, whisper.cpp) |
| `Super + H` (kort tikken) | Live dicteren: elke zin wordt getypt zodra je even pauzeert; nog een keer tikken stopt |
| `Super + Shift + Return` | btop in Kitty |
| `Super + Shift + C` | cava (audio visualizer) in Kitty |

---

## Widgets

| Toetsen | Actie |
|---|---|
| `Super + N` | Quickshell meldingscentrum in-/uitschakelen |
| `Super + Shift + N` | Alle meldingen sluiten |
| `Super + Shift + W` | Willekeurige wallpaper (uit skwd-map) |
| `Super + Ctrl + W` | Wallpaper picker |
| `Super + Shift + T` | Volgend thema (cyclisch) |
| `Super + A` | Sfeer: thema, wallpaper en wat ga je doen (Werken, Kijken en luisteren, Spelen, Zen). Vervangt de losse thema- en modekiezer |
| `Super + Ctrl + P` | Muziekpaneel |
| `Super + Ctrl + I` | Instellingen (eigen app, ook in de launcher) |
| `Super + Ctrl + Space` | Toetsenbordmenu voor alles (thema, modus, schermen, systeem, sessie) |
| Klik op CPU/RAM-pil | Systeemstats popup |

---

## Screenshots

| Toetsen | Actie |
|---|---|
| `Print` | Gebied vastleggen: opslaan en kopiëren, met voorbeeld |
| `Super + Ctrl + Print` | Vastleg-studio: gebied, venster of scherm; foto of opname; tekst kopiëren; kleur kiezen |
| `Super + Print` | Gebied selecteren → alleen kopiëren |
| `Shift + Print` | Gebied selecteren → bewerken in satty |
| `Ctrl + Print` | Volledig scherm opslaan |
| `Super + Shift + R` | Schermopname van een gebied starten of stoppen |

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
| `Super + Ctrl + R` | Hyprland herladen (+ melding) |
| `Super + Ctrl + Backspace` | Afsluitmenu (vergrendelen, slaap, herstarten, uit, uitloggen) |
| `Super + Ctrl + F12` | Tabletmodus handmatig wisselen (touchscreen/2-in-1) |
| Tabletmodus-schakelaar | Intern scherm roteren + schermtoetsenbord openen (automatisch) |

## Ruimtelijk werkvlak

Kies **Ruimtelijk** onder Instellingen › Bureaublad of met **Super+Z**. Bestaande werkruimtes
worden bij een update niet automatisch omgezet.

- **Super+pijlen:** nabijgelegen venster kiezen.
- **Super+Shift+pijlen:** venster naar de buurplek. Is die leeg, dan staat het er alleen;
  staan er al vensters, dan komt het erbij als Dwindle-tegel, zonder maximum per pagina.
- **Super+Ctrl+Alt+pijlen:** het zichtgebied verplaatsen, zonder vensters te verplaatsen.
  Op een scrollstrook schuift links/rechts één kolom; zo betekent deze toets overal "verder kijken".
- **Drie vingers slepen** (zonder Super) schuift het beeld vrij, ook diagonaal.
  Op een andere indeling wisselt drie vingers opzij van werkruimte. **Knijpen**
  zoomt uit (vingers naar elkaar) of terug in, tot 100%. Vier vingers doen niets.
- **Aanraakscherm:** twee vingers slepen schuift het beeld, knijpen zoomt. Eén
  vinger blijft de app bedienen. Een veeg vanaf de schermrand wisselt nog van
  werkruimte. In de kaart: één vinger sleept het zicht, lang indrukken verplaatst
  een app, twee vingers knijpen.
- **Super+wiel:** één pagina omhoog/omlaag; **Super+Alt+wiel** of een kantelwiel: links/rechts.
- **Super+twee vingers** op het touchpad: het werkvlak schuift mee met je vingers, zoals een kaart. Bij optillen klikt het op een plek vast als je er dichtbij bent. Uitgezoomd doet een gewone tweevingerscroll (zonder Super) hetzelfde, zodat het verkleinde venster niet van binnenuit wegschiet. Het muiswiel blijft in het document scrollen. Knijpen zoomt nog.
- **Ontdekken:** de eerste keer op een ruimtelijk werkvlak legt een melding de gebaren uit (`werkvlak-hint.sh --reset` toont hem opnieuw), en Super vasthouden toont een blok Werkvlak met dezelfde gebaren. Alle gebaren werken ook op een leeg werkvlak of met een zwevend venster in focus.
- **Super+Ctrl+linkermuis ingedrukt:** het werkvlak vrij slepen, ook diagonaal. Bij loslaten
  klikt het alleen op een plek vast als je er dichtbij bent.
- **Nieuwe vensters** komen waar je kijkt: op een lege plek vult het venster die plek,
  op een plek met vensters wordt het een extra tegel (zonder maximum). Eén plek met vensters
  vult het hele scherm, net als gewone tegels; scroll of sleep opzij voor meer ruimte.
- **Muisfocus** verschuift het beeld niet zolang er nog een rand van het venster zichtbaar is.
- **Super+Ctrl+wiel:** echte desktop uit-/inzoomen (100–25%), met direct klikken, typen en appscroll.
  Dit werkt per monitor; **Super+Ctrl+middelklik** zet de monitor terug op 100%.
  Super+wiel blijft een hele pagina verplaatsen; Super+Ctrl+linkermuis sleept vrij.
- **Vensterkaart:** de knop 󰊢 in de rail of Super+Tab.
- **Super+Ctrl+, / .:** breedte kleiner/groter.
- **Super+linkermuis slepen** van een venster: het komt precies waar je loslaat,
  op een lege plek of op de tegelplek onder de muis. Het beeld schuift niet mee.
- **Super+Tab:** kaart openen; gewoon slepen verplaatst alleen de camera,
  **Super+slepen** of lang indrukken verplaatst een app. Op het midden van een ander venster wisselen
  ze van tegel binnen dezelfde pagina; vanaf een andere pagina komt de app ernaast. Aan een rand splits je dat vlak. Wiel of knijpen zoomt, tik kiest een venster.
  Zwevende vensters staan er ook bij; vensters buiten beeld tonen hun laatste miniatuur.
- **Super+rechtermuis:** Dwindle-verhoudingen veranderen binnen de pagina.
- **Super+backslash:** richting van de geselecteerde Dwindle-splitsing wisselen.
- **Esc** in de kaart: sluiten.

Gewone appscroll blijft bij de app. De ruimtelijke acties zijn buiten die layout
niet actief; de bestaande focus- en vensteracties blijven daar werken.

Gebruik **Super+Ctrl+I** of `kingstra bediening` voor schermmode, rail en muziek.
