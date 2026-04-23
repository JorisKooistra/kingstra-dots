# Settings App Tabs

Doel: eerst zorgen dat elke tab betrouwbaar iets kan lezen, wijzigen en opslaan. Daarna trekken we layout, typografie, knoppen en statusmeldingen gelijk.

## Voorgestelde tabvolgorde

1. Theme
2. Bar
3. Widgets
4. Keybinds
5. Input
6. Display
7. Network
8. Audio
9. Weather & Time
10. Session
11. Updates
12. Advanced
13. About

## Theme

Status: grotendeels uitgewerkt.

Uitwerking:
- Thema kiezen uit de bestaande carousel.
- Actief en geselecteerd thema duidelijk tonen.
- Theme-velden lezen uit `~/.config/kingstra/themes/*.toml`.
- Thema-instellingen opslaan via `theme-update-safe.sh`.
- Actief thema opnieuw toepassen via `theme-switch-safe.sh`.
- Alle theme-variabelen optioneel tonen voor debug.

Werkt als:
- Een thema selecteren geen configuratie wijzigt.
- Opslaan alleen het geselecteerde `.toml`-bestand wijzigt.
- Opslaan van het actieve thema ook live herlaadt.
- Fouten zichtbaar terugkomen in de tab.

## Bar

Uitwerking:
- Barpositie: top, bottom, left, right.
- Bar-layout: automatisch horizontal/sidebar op basis van positie.
- Hoogte, breedtegedrag, vorm, edge-style en klokstijl.
- Topbar live herladen na opslaan.

Config:
- `quickshell.bar_height`
- `quickshell.bar_position`
- `bar.template`
- `bar.width_mode`
- `bar.shape`
- `bar.top_edge_style`
- `bar.bottom_edge_style`
- `bar.clock_style`
- `bar.topbar_loose_blocks`

Werkt als:
- De gekozen positie na herstart behouden blijft.
- Verticale posities automatisch een sidebar-template krijgen.
- Herladen een foutmelding geeft als Quickshell niet start.

## Widgets

Uitwerking:
- Modules aan/uit zetten: workspaces, search, media, tray, notifications, system stats.
- Widget-volgorde kiezen per bar-layout.
- Compacte of uitgebreide weergave per module.
- Widget-specifieke instellingen, zoals monitor-refresh of media-info.

Config:
- Nieuwe `~/.config/quickshell/settings/widgets.json`.
- Later eventueel per theme overrides.

Werkt als:
- Een module direct uit de bar verdwijnt of terugkomt.
- Ongeldige widgetnamen genegeerd worden.
- Default config bruikbaar blijft zonder bestand.

## Keybinds

Status: basis werkt.

Uitwerking:
- Bestaande Hyprland-bindings lezen uit `~/.config/hypr/conf.d/8*-binds*.conf`.
- Zoeken/filteren op label, toets, dispatcher en argumenten.
- Binding bewerken, toevoegen vanuit catalogus, en verwijderen door commentaar te zetten.
- Conflictscan toevoegen: dezelfde mods+key detecteren.

Werkt als:
- Elke wijziging via `write_keybind.sh` loopt.
- `hyprctl reload` na opslaan uitgevoerd wordt.
- Niet-ingestelde catalogusacties zichtbaar blijven.
- Conflicten blokkeren of heel duidelijk waarschuwen.

## Input

Status: scroll-tuning werkt.

Uitwerking:
- Touchpad- en muisscroll apart instellen.
- Keyboard-layout en repeat-rate toevoegen.
- Natural scroll, tap-to-click en disable while typing toevoegen.
- Per-device overrides pas later, nadat basis veilig werkt.

Config:
- `~/.config/quickshell/settings/settings.json`
- `~/.config/hypr/conf.d/73-scroll-settings.conf`
- Later `20-input.conf` of een aparte settings override.

Werkt als:
- Waarden direct via `hyprctl keyword` toegepast worden.
- Settings na herstart identiek terugkomen.
- Grenzen voorkomen dat scroll onbruikbaar snel of traag wordt.

## Display

Uitwerking:
- Monitoren lezen via `hyprctl monitors -j`.
- Resolutie, refresh-rate, schaal, positie en rotatie tonen.
- Preset opslaan en toepassen via bestaande monitor-scripts.
- Laptop/externe-monitor profielen koppelen.

Config:
- Bestaande Hyprland monitorconfig.
- `monitor-apply-save.sh`
- `monitor-hotplug-restore.sh`

Werkt als:
- De huidige monitorstate altijd zichtbaar is.
- Toepassen terugvalt naar vorige bruikbare config bij fout.
- Hotplug-profielen niet kapotgeschreven worden.

## Network

Uitwerking:
- Wifi, ethernet en bluetooth status tonen.
- Wifi aan/uit, netwerk kiezen, wachtwoord invoeren.
- Bluetooth aan/uit, pair/connect/disconnect.
- Bestaande panel-logic hergebruiken.

Config/scripts:
- `network/wifi_panel_logic.sh`
- `network/eth_panel_logic.sh`
- `network/bluetooth_panel_logic.sh`

Werkt als:
- Zonder NetworkManager/Bluetooth een nette foutmelding verschijnt.
- Verbinden async blijft en de UI niet bevriest.
- Secrets niet in logs of notificaties verschijnen.

## Audio

Uitwerking:
- Output/input devices tonen.
- Volume en mute regelen.
- Default sink/source kiezen.
- Per-app volume later toevoegen.

Config/scripts:
- `volume/audio_control.sh`
- `network/audio_panel_logic.sh`

Werkt als:
- PipeWire/WirePlumber state correct gelezen wordt.
- Muted state en volume direct zichtbaar bijwerken.
- Geen audio stack resulteert in een duidelijke lege state.

## Weather & Time

Status: basis werkt.

Uitwerking:
- Tijd- en datumformaten bewerken met preview.
- OpenWeather key, latitude, longitude en units opslaan.
- Cache wissen en weather-refresh starten na opslaan.
- Stad zoeken later toevoegen, zodat coördinaten niet handmatig hoeven.

Config:
- `~/.config/quickshell/settings/settings.json`
- `~/.config/quickshell/calendar/.env`
- `calendar/weather.sh`

Werkt als:
- Preview niet crasht op ongeldige Qt-formatstrings.
- `.env` veilig gequote wordt.
- Weather-tab bruikbaar blijft zonder API-key.

## Session

Uitwerking:
- Lock, logout, reboot, shutdown.
- Idle/suspend gedrag tonen en aanpassen.
- Lid-lock en resume fixes zichtbaar maken.
- Gaming/media/office mode kiezen.

Config/scripts:
- `hypridle/hypridle.conf`
- `systemd/kingstra-lid-lock.service`
- `kingstra-mode-switch`
- `kingstra-session-update`

Werkt als:
- Gevaarlijke acties bevestiging vragen.
- Mode-switch zichtbaar meldt wat gewijzigd is.
- Systemd service-status alleen gelezen wordt als systemctl bestaat.

## Updates

Uitwerking:
- Dotfiles update uitvoeren.
- Package updates tonen.
- Bootstrap opnieuw draaien in terminal.
- Laatste update-status en loglocatie tonen.

Config/scripts:
- `bootstrap.sh`
- `package_updates.sh`
- `package_upgrade.sh`

Werkt als:
- Update altijd in een terminal draait.
- De settings popup sluit of een duidelijke busy-state toont.
- Fouten zichtbaar blijven na afsluiten van de terminal.

## Advanced

Uitwerking:
- Configpaden en debugstatus tonen.
- Quickshell herstarten.
- Generated colors/templates opnieuw renderen.
- Backup/restore van relevante configbestanden later toevoegen.

Werkt als:
- Geen destructieve actie zonder bevestiging uitgevoerd wordt.
- Debugacties command-output kunnen tonen.
- Advanced standaard rustig blijft en geen primaire workflows verdringt.

## About

Status: basis werkt, staat onderaan.

Uitwerking:
- Project, auteur en componenten tonen.
- Links naar project en gebruikte tools.
- Versie/commit tonen als git beschikbaar is.
- Licentie en support-info toevoegen.

Werkt als:
- Links openen zonder de app te blokkeren.
- Ontbrekende git-info geen fout geeft.
- About geen eerste scherm meer is.

## Uniformering

Na de functionele basis:
- Een gedeelde `SectionHeader`, `SettingsCard`, `IconButton`, `PrimaryButton`, `DangerButton`, `FieldLabel`, `StatusBanner` en `EmptyState` component maken.
- Alle tabs dezelfde marges, radius, fontfamilies en buttonhoogtes geven.
- Alle writes via kleine scripts of veilige helpers laten lopen.
- Elke tab dezelfde states geven: loading, empty, dirty, saving, saved, error.
- Scrollgedrag per tab gelijk maken, inclusief mouse wheel en touchscreen.
- Taalkeuze uniform maken: Nederlands voor UI-tekst, technische keys alleen waar nodig.
