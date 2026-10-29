# Native werkvlakzoom

Super+Ctrl+wiel zoomt de echte desktop tussen 100% en 25%; Super+Ctrl+middelklik
herstelt 100%. Werkt alleen bij `lua:hyprscroll2d`, per monitor. Appbuffers blijven
op hun eigen afmetingen; klikken en scrollen worden naar de geschaalde app geleid.
Super+wiel gaat een hele pagina verder; Super+Ctrl+linkermuis bedient de Lua-camera.
Elke wielstap zoomt ongeveer 25%. Uitgezoomd verschijnt een knop Reset 100%.

Focus volgt de muis, zowel in het uitgezoomde werkvlak als op andere monitors.
Tijdens zoomen blijft het uitstekende deel van een zwevend venster verborgen
op andere fysieke monitors en vangt het daar geen muisinput. Op 100% geldt weer
het normale gedrag over monitorranden. De opgeslagen zwevende/getegelde stand
en geometrie per app blijven behouden.

Fase 05 van de installer/updater draait `kingstra-build-native-zoom`. Die bouwt
[Phantomat](https://github.com/kaolti/phantomat) op vaste revisie
`a1e8a0806541640d01503ac861a8a39548de8724`, met `kingstra.patch`, tegen de lokale
Hyprland 0.56.2-headers. Bron en build staan in de gebruikerscache, gescheiden
per bronrevisie, patch en Hyprland-ABI. De `.so`-symlink en ABI-stamp zijn ignored.
Er worden geen binaries of monitor-specifieke bestanden uit deze pc verspreid.

Handmatig opnieuw bouwen vanuit de repo:

```sh
bash config/shared/scripts/kingstra-build-native-zoom
hyprctl reload
```

Bij herladen sluit de zoom en laadt Hyprland de nieuwe build vanuit zijn eigen
cachepad. Een build voor een andere Hyprland-versie wordt overgeslagen; het gewone
werkvlak en de Quickshell-kaart blijven dan werken.

De patch beperkt het renderen tot de betreffende werkruimte, behoudt de
Lua-Dwindle-geometrie en de bestaande Super-muisbindings, laat directe app-input
aan tijdens zoomen, en houdt de oorsprong van elke monitor apart. De upstream
installer wordt nooit uitgevoerd; die zou een andere desktopindeling activeren.
De upstream BSD-licentie staat in `LICENSE.upstream`.

Regressies: `bash tests/smoke/spatial-layout.sh`. De optionele integratietest in
`tests/integration/native-zoom.py` opent een aparte geneste Hyprland met testapps;
de echte gebruikersvensters worden niet aangestuurd.
