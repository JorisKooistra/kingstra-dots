# Changelog

Versions follow `YYYY.MM.N` (year, month, release within that month). The current version is in `VERSION`.

## Unreleased

### Draaitafel: gedetailleerder en schermvullend
- De overgang tussen klein en groot loopt in fases: eerst groeit de platte speler naar zijn plek, dan kantelt hij en vouwt de voorkant uit, en pas aan het eind komen 33/45, merk en volumetekst erbij (bij sluiten andersom). De hoekradius loopt mee, zodat de bovenkant niet ineens verandert. De animatie start pas als het venster een paar frames heeft getekend.
- Alle uitstekende delen gebruiken nu dezelfde 3D-regels als de knoppen (nieuw `shellsurface/Extruded.qml`): armvoet, pivotkapje, armsteun, volumeschuif, armlift, lampje en 45-adapter hebben echte dikte, een zijkant naar gelang hun plek en een zachte slagschaduw. Display en spoelbalk liggen verzonken in het voorpaneel.
- Knoppen zijn echte uitgetrokken blokjes met een voetuitsparing, zijwanden en een zachte slagschaduw. Op het staande voorpaneel steken ze naar je toe (je ziet de bovenkant en schaduw eronder), bovenop de tafel zie je de voorkant; links of rechts van het midden zie je ook een zijkant. Indrukken duwt de kap terug in de voet.
- Fix: de linkerbovenhoek van de headshell werd afgeknipt, omdat hij buiten het tekenvlak van de arm viel. Het tekenvlak is nu ruimer.
- De naaldhouder stak als een licht puntje schuin onder het element uit; nu zie je alleen een donker naaldpuntje. De vingerlift is een kort lipje in de kleur van de headshell, geen schuin uitstekende lijn meer.
- Knoplabels blijven leesbaar als een knop aan staat: dat zie je nu aan het ledje, de rand en een lichtstreepje onder het icoon.
- De armsteun is een paaltje met schaduw en een gootje, de streepjes bij de volumeschuif zijn dikker en vallen in perspectief niet meer uiteen, en lange titels lopen langzaam door op het display.
- Fix: spoelen haperde. De schaduw van de arm wordt nu één keer getekend en alleen verschoven, in plaats van bij elke stap van het optillen opnieuw met vervaging.
- Fix: de plaat draaide schokkerig. Hij draait nu op het ritme van het scherm, en de stroboscoopring maakt geen sprong meer bij elke omwenteling.
- Headshell en element zijn groter en hebben dikte: een zijkant, een belicht element met glanslijn en een naaldhouder. Armvoet, pivotkapje, volumeschuif, armlift, lampje en 45-adapter hebben licht, schaduw en een zijkant.
- Het lampje staat verder van de draaischijf.
- De mat heeft een eigen tint, zodat een single niet meer wegvalt tegen een zwarte ondergrond.
- De houtnerf wordt op één vaste grootte getekend en geschaald, zodat de kleine speler dezelfde nerf heeft als de grote.
- Organic oogt weer als hout in plaats van futuristisch. De kleuren blijven uit het thema, maar zonder gloed: crèmekleurige knoppen, geborsteld metalen arm en draaischijfrand, een donkere houten rand en duidelijkere nerf.
- Arm en knoppen hebben meer diepte: de buis is belicht als een cilinder, het contragewicht en de armvoet hebben licht en schaduw, en de knoppen hebben een zijkant en een slagschaduw.
- START en 33/45 staan nu in de hoek langs de onderrand, niet meer op de draaischijf. Op 45 toeren gaat de lp eraf en komt er een single van 7 inch op, met een groot gat en de adapter op de as.
- De schuif rechts regelt nu het systeemvolume (slepen of scrollen).
- Het display op de schermvullende speler toont ook de artiest.
- Fix: de grote speler knipperde en schokte bij het openen. De animatie start pas als het venster op het scherm staat, en de kleine speler verdwijnt pas als de grote erover ligt.
- Fix: de spoelbalk sprong bij loslaten eerst terug naar de oude plek.
- Fix: de rand tussen bovenkant en voorkant sluit nu recht aan, zonder verspringing.
- Fix: de glans op de plaat draaide mee; het licht staat nu stil en de plaat draait eronder door.
- Fix: na een plaatwissel of spoelen sprong de naald soms meteen terug op de plaat. De arm zwenkt nu altijd zichtbaar terug.
- Fix: bij een volgend album verscheen soms eerst de nieuwe hoes op de oude plaat. De hoes wacht nu even, zodat de oude plaat eraf gaat en de nieuwe erop komt.
- Fix: de kleuren volgen nu het Matugen-thema. Hout (organic) en neon houden hun vormen, nerf en lichtlijnen, maar messing, walnoot en zwart zijn vervangen door accent- en oppervlaktekleuren uit het palet.
- Fix: bij openen vloog de schermvullende speler eerst van boven binnen. Hyprland animeert die laag niet meer (`no_anim` voor `quickshell:kingstra-vinyl-stage`), zodat alleen de groei vanuit de mediakaart overblijft.
- Fix: met de schermvullende speler open waren de andere schermen niet klikbaar. Hij vraagt toetsenbordfocus nu op aanvraag in plaats van exclusief.
- Fix: klok, mediakaart en draaitafel bleven weg ("VinylStage is not a type"). VinylStage staat nu in shellsurface/; `tests/smoke/qml-unscanned-dirs.sh` vangt typen uit een map die Quickshell geen qmldir geeft.
- De toonarm is gebogen (S-bocht met schuin headshell, vingerlift en contragewicht) en heeft een schaduw die verder wegvalt als de arm omhoog gaat.
- Spoelen gaat als op een echte speler: de arm gaat omhoog, zwenkt naar de nieuwe plek en zakt weer. Je kunt de naald zelf slepen (mediakaart op het bureaublad, Geluid & media en de schermvullende weergave).
- Bij een nieuw album gaat de arm naar zijn steun, schuift de oude plaat eraf en de nieuwe erop.
- Vorm als een klassieke direct-drive draaitafel (zoals een Technics): grote draaischijf links met stroboscoopstippen, gebogen arm met grote voet rechtsboven, armlift, pitch-schuif rechtsonder (±8 %, dubbelklik zet hem op 0), start/stop en 33/45 linksonder, naaldlampje en 45-adapter. De mediakaart op het bureaublad gebruikt dezelfde speler in het klein.
- Afwerking per thema: Organic walnoot met nerf en messing arm, Neon zwart glas met raster, lichtrand en gloeiende arm, Paper inkt op papier met harde schaduw, Mono geborsteld en neutraal.
- De schermvullende speler groeit uit de kleine op de mediakaart: hij komt plat van die plek, kantelt naar achteren en vouwt de voorkant uit; bij sluiten gaat hij weer terug.
- Screensaver: na 120 s zonder invoer terwijl er muziek speelt opent de draaitafel vanzelf en bij de eerste beweging sluit hij weer. `kingstra vinyl auto <seconden>|uit` of het toetsenbordmenu stelt dit in. Video die het scherm wakker houdt, houdt ook dit tegen.
- Nieuw: schermvullende draaitafel als screensaver, in voor/bovenaanzicht met langzaam meedraaiende camera. Open hem met de knop rechtsboven op de mediakaart, `kingstra vinyl` of het toetsenbordmenu. De voorkant heeft een display, een spoelbalk met naaldje (slepen tilt de arm op) en werkende knoppen; bovenop zitten 33/45 en start/stop. Spatie speelt/pauzeert, ← → spoelt 10 s, N/P volgend/vorig, Esc of klik ernaast sluit.

### Rail: indeling per thema
- De rail wordt nu opgebouwd uit een opgeslagen indeling per thema (`RailLayout.qml`, `~/.local/state/kingstra/rail-layout.json`, geschreven via `settings/rail-layout.py`). Zonder eigen keuze blijft de vertrouwde volgorde staan.
- Elk railonderdeel (launcher, werkruimtes, kladblokken, uitzoomen, meldingen, systeem, updates, games, extra knoppen, Meer, systeemvak, geluid, status, klok, afsluiten, instellingen) is een los blok dat je kunt verplaatsen; "Kleine ruimte" en "Duw naar onder" mogen vaker voorkomen.
- Eigen apps en launchers (naam, icoon uit het icoonthema of een Nerd Font-teken, commando) kunnen als knop in de rail.
- Het aantal werkruimtes in rail en strook is per thema in te stellen (1–10); scrollen over de werkruimtes telt hetzelfde aantal.
- Per scherm en mode blijft alles werken zoals het was: zichtbare onderdelen, Meer, extra knoppen en automatisch verbergen liggen daar bovenop. Inschuiven achter Meer animeert nu voor elk onderdeel op dezelfde manier.
- Tweede rail aan de overkant: zet je onderdelen op de tweede rail, dan verschijnt die rechts (of links als de hoofdrail rechts staat) met hetzelfde vlak, dezelfde knoppen en animaties. Hij reserveert eigen ruimte, schuift bij automatisch verbergen mee weg, en de omlijsting, de bovenstrook, het eiland, meldingen en tooltips houden er rekening mee. Panelen uit de tweede rail groeien aan die kant uit de omlijsting.
- De rail kan per thema aan of uit, los van wat het thema zelf kiest; zo krijgen ook Paper en Mono een rail (en een tweede rail).
- Nieuwe pagina Instellingen › Bediening › Rail-indeling (`settings/RailLayoutPage.qml`): kies het thema, sleep blokjes tussen Hoofdrail, Tweede rail en Niet getoond (of gebruik de pijltjes), zet de rail per thema aan/uit, stel het aantal werkruimtes in, en voeg eigen apps toe door een geïnstalleerde app te zoeken of zelf een commando in te vullen. Alles wordt direct bewaard en de rail volgt live.
- Rechtsklik op een railknop opent Rail-indeling; ook bereikbaar via Bediening en de railkaart in Super+A. Achter Meer kunnen nu ook eigen apps, Uitzoomen, het systeemvak en de klok.
- Nieuwe smoketest `tests/smoke/rail-layout.sh`: controleert het opslagscript en sleept offline (qmltestrunner met kleine Quickshell-stubs) in de echte editor.

### Rail: automatisch verbergen verbergt nu echt
- Met "automatisch verbergen" (per scherm of via de mode) schuift de rail nu helemaal weg tot alleen de dunne omlijsting over is, even breed als rechts en onder. Eerder bleef er een lege railstrook met gereserveerde ruimte tussen de vensters staan.
- De gereserveerde ruimte krimpt mee: vensters krijgen de volle breedte. Bij hover op de linkerrand klapt de rail er vloeiend over de vensters heen uit en na 2,4 s zonder hover schuift hij weer weg; zolang een paneel open is blijft hij staan.
- Omlijsting, bovenstrook, onderrand, meldingen en het eiland schuiven mee met de rail, dus de ronde hoeken blijven heel. Knoppen behouden hun breedte en vervagen tijdens het wegschuiven.

### Bediening: alles in één overlay (Super+A)
- Nieuwe overlay `control/ControlOverlay.qml`, geopend met Super+A of via het toetsenbordmenu, in dezelfde qs-master als de thema- en modekiezer. Drie kolommen tegelijk zichtbaar: thema (met voorbeelden) en wallpaper (miniaturen, willekeurig, grote kiezer); mode voor de hele desktop, mode per scherm via een schermkaartje, wallpaper-effect en energieprofiel; indeling van de werkruimte, kolombreedte, snap-sterkte als schuif en de rail per scherm (onderdelen, automatisch verbergen, herstellen).
- Gebruikt dezelfde helpers als Instellingen › Overzicht en › Bediening (`kingstra mode/theme/wallpaper`, `workspace-layout.py`, `werkvlak-settings.py`, `screen-profile.py`, `powerprofilesctl`); die tabbladen en de losse kiezers (Super+Ctrl+T, Super+Ctrl+M) blijven zoals ze waren.
- Het toetsenbordmenu opent nu met Super+Ctrl+Space (was Super+Alt+Space).
- Ronde vormen, glijdende markering bij keuzes en kolommen die gespreid binnenkomen; Esc of nogmaals Super+A sluit.

### Super+Tab: beide overzichten in één stijl
- Het werkruimte-overzicht en de werkvlak-kaart delen nu dezelfde onderdelen in `quickshell/overview/common/kingstra/`: `KingstraLook` (kleuren uit colors.json, letter, hoeken en tempo uit theme.json), `OverviewHeader` en `OverviewWindowCard`. Het gedrag per indeling is ongewijzigd.
- Het werkruimte-overzicht volgt nu het Kingstra-thema in plaats van vaste paarse standaardkleuren (`colorSource: "kingstra"`). Glas-glans staat uit, zodat het net zo vlak oogt als de kaart. Zet `glassMode` in `overview/config.json` aan als je de glans terug wilt.
- Vensters zien er overal hetzelfde uit: ronde hoek, live beeld (of het bewaarde plaatje), en een titel-label met app-icoon onderin. Zonder beeld krijg je het app-icoon in plaats van tekst. Hover, keuze en sleepdoel gebruiken dezelfde accentkleur, rand en overgangen. De kaart toont nu ook hover.
- Beide overzichten hebben dezelfde kop: een titel in kleine hoofdletters met een uitlegregel in een afgeronde pil. De actieve werkruimte en het zicht-kader gebruiken dezelfde accentrand.

### Werkvlak: Hyprland 0.57 en updates tijdens een sessie
- Native desktopzoom ondersteunt nu ook Hyprland 0.57.0, met de nieuwe scene-renderer en directe muisinput op aangrenzende pagina's.
- De updater bewaart een aparte pluginbuild per Hyprland-ABI. Een lopende 0.56.2-sessie behoudt zijn eigen build na de pakketupdate; de volgende sessie laadt de nieuwe 0.57-build.
- Camera-slepen en tegelresizing stoppen op 0.57 ook wanneer de releasebinding niet wordt aangeroepen, zodat een volgende app-sleepbeweging de camera niet meeneemt.
- Integratietests controleren volledige vensterbuffers buiten de huidige pagina, reset, focus, onafhankelijke verversing van monitors en slepen van getegelde en zwevende apps tussen gewone en uitgezoomde schermen.

### Werkvlak: muisfocus en zwevende vensters
- Focus volgt de muis tijdens zoomen en op andere monitors; terugkeren naar dezelfde app vereist geen klik meer.
- Alleen tijdens zoomen worden beeld én muisdetectie van zwevende vensters tot de eigen monitor beperkt. Buiten beeld doorlopende delen lekken niet naar een andere fysieke monitor. Op 100% blijft het normale zweefgedrag gelden.
- De opgeslagen zwevende/getegelde stand en geometrie per app blijven behouden; Super+Return krijgt geen geforceerde tegelstand.
- Integratietests controleren focus zonder klik, verborgen zwevende overlap op een tweede monitor, behoud van de zweefstand en herstel van normaal zweven op 100%.

### Werkvlak: afzonderlijke schermen en bediening
- Zoomen, camera slepen en zoom resetten gebruiken nu Super+Ctrl; Super+Alt+wiel scrolt horizontaal. De resetknop heeft een contrasterende accentvulling.
- Frame-updates van apps op andere fysieke schermen blijven doorlopen terwijl één werkvlak is uitgezoomd; normale overlays zoals de resetknop verversen weer.
- Nieuwe vensters (zoals Super+Return) laten zowel de werkvlakcamera als de native zoomcamera staan.
- Een app op een bezette andere pagina laten vallen voegt die naast het doelvenster toe. Alleen binnen dezelfde pagina kan een middendrop tegels verwisselen; de kaart toont het juiste splitdoel.
- Integratietests controleren een echte resetklik, doorlopende framecallbacks op een tweede output, een nieuwe app tijdens zoom en toevoegen aan een bezette pagina.

### Werkvlak: Dwindle en vaste camerabediening
- Lua-runtimefout “expected a dispatcher” bij de native zoom verholpen; de pluginactie werd binnen een sneltoets dubbel uitgevoerd/doorgegeven. Uitgezoomd slepen gebruikt nu de terugvertaalde wereldpositie voor Dwindle-splits en verwisselen.
- Super+Alt+wiel zoomt de echte desktop uit/in op de monitor onder de muis; apps blijven bedienbaar. Het wiel zoomt circa 25% per stap; de zichtbare Reset 100%-knop of Super+Alt+middelklik herstelt 100%. De updater bouwt de native renderer lokaal voor Hyprland 0.56.2; de Lua-layout blijft de indeling beheren.
- Camera slepen op het bureaublad: Super+Alt+linkermuis; de middelste muisknop is vrij. Super+wiel verschuift één hele pagina. In de kaart blijft gewoon slepen de camera bedienen.
- Pagina's gebruiken een blijvende Dwindle-splitsboom (zonder maximum per pagina), met verwisselen op het midden en splitsen aan de rand van een doelvenster. Super+rechtermuis wijzigt de verhoudingen.
- In de kaart sleept een gewone muisbeweging alleen de camera; Super+slepen verplaatst een app. Miniaturen blijven bestaan tijdens cameraupdates en bewegen direct mee. Zwevende vensters zijn zichtbaar en verplaatsbaar.
- De muis aan een zichtbare vensterrand laten komen scrolt niet meer automatisch. Scrollen kan ook lege pagina's bereiken. De bestaande Super+pijlen blijven vensters kiezen.
- Pagina's, camera en Dwindle-verhoudingen worden tijdens de sessie bewaard en bij een Hyprland-reload hersteld, ook terwijl targets één voor één terugkomen.

### Werkvlak: slepen landt waar je loslaat, kaart met miniaturen
- Super+slepen van een venster op het ruimtelijk werkvlak zette het venster altijd als laatste tegel neer en liet het beeld verschuiven. Hyprland haalt een gesleept venster even uit de layout; dat werd bij terugkomst als nieuw venster gezien. Nu komt het op de plek en tegelplek onder de muis (buiten beeld: terug naar de oude plek) en blijft de camera staan.
- In de werkvlakkaart (Super+Tab of 󰊢) sleep je een venster naar een andere plek of tussen tegels; een oplichtend vak toont waar het komt. Op een volle plek ruilt de tegel daar met de oude plek.
- De kaart toont voor vensters buiten beeld een miniatuur in plaats van alleen de titel. Hyprland levert alleen live beeld van vensters op het scherm, dus het nieuwe `werkvlak-thumb.sh` bewaart met grim een klein plaatje zodra een venster helemaal in beeld staat.
- Nieuwe tests voor neerzetten, tegelplekken en miniaturen.

### Instellingen: nieuw tabblad Overzicht
- Het eerste tabblad van Instellingen (Super+Ctrl+I) toont mode, thema, de indeling van de huidige werkruimte, scrollgedrag en wallpaper naast elkaar, allemaal direct te wijzigen. Thema's met voorbeeldafbeelding, wallpapers als miniaturen uit je wallpapermap.
- Scrollen en werkvlak zijn nu instelbaar: breedte van een nieuwe kolom op een scrollstrook, hoeveel vensters als tegels op één plek staan en hoe sterk slepen vastklikt. Bewaard in `~/.config/kingstra/werkvlak.json` en meteen toegepast via het nieuwe `werkvlak-settings.py`.
- Nieuwe smoketest `werkvlak-settings.sh`.

### Werkvlak: tegels, vrij slepen en scrollen binnen de werkruimte
- Super+wiel scrolt nu binnen de werkruimte (scrollstrook: volgende/vorige pagina; ruimtelijk: omhoog/omlaag), Super+Ctrl+wiel opzij. Super+Shift+wiel wisselt van werkruimte (was andersom).
- Super+middelmuis ingedrukt houden sleept het werkvlak vrij, ook diagonaal. Bij loslaten klikt het alleen op een plek vast als je er dichtbij bent; op een scrollstrook stapt slepen per kolom.
- Ruimtelijk werkvlak: een plek kan tot vier vensters als tegels hebben. Eén plek met vensters vult het hele scherm, net als gewone tegels. Een nieuw venster komt waar je kijkt: op een lege plek die je met scrollen of slepen hebt opgezocht, of als extra tegel. Vroeger verdween het altijd rechts in de rij.
- Ook met één venster kun je het zicht verplaatsen (dat kon pas vanaf twee).
- De camera springt niet meer weg als de muis over een venster gaat dat al grotendeels zichtbaar is.
- Super+Shift+pijl naar een plek met vensters voegt het venster als tegel toe; bij een volle plek wisselen ze.
- Scrollstrook: nieuwe kolommen zijn een volle pagina, zodat een venster op een lege pagina niet meer op half scherm opent. Super+Ctrl+, maakt een kolom smaller.
- Nieuwe railknop Uitzoomen: de werkvlakkaart op het ruimtelijk werkvlak, elders het werkruimte-overzicht.
- Nieuwe smoketest `spatial-drag.lua` voor slepen en Super+wiel.

### Systeem-widget toont de GPU
- De GPU stond alleen in de Systeem-widget in de Gaming-mode. Zodra er een meting is (nvidia-smi of sysfs) staat hij er nu altijd bij, met belasting en temperatuur.

### Sneltoetsen opgeschoond
- Op basis van Joris' aanvinklijst zijn 16 ongebruikte sneltoetsen weg: Super+H/J/K/L en Super+Shift+H/J/K/L (de pijltoetsen blijven), Super+Ctrl+pijlen (venster groter/kleiner; slepen met Super+RMB blijft), Super+Alt+T, Super+Shift+G, Super+Ctrl+Shift+G, Super+Shift+E, Super+Alt+I, Super+Alt+B, Super+Alt+N, Super+Ctrl+C, Super+A, Super+O, Super+X, Super+, en Super+Ctrl+G.
- Geen functie verdwenen: alles staat in het toetsenbordmenu (Super+Alt+Space). Nieuw daarin: vastzetten op alle werkruimtes, uit groep halen, groep vergrendelen, nmtui, Blueman, kalender, FocusTime, games en yazi. Instellingen blijft op Super+Ctrl+I.
- Toetsen die niet zijn beoordeeld (zoals parkeren en nieuwe toetsen) blijven staan.

### Apps echt sluiten in plaats van naar de tray
- Nieuwe lijst "Apps echt sluiten" in Instellingen › Sessie. Apps op de lijst stoppen helemaal zodra hun laatste venster dicht is (Super+Q of de X), in plaats van op de achtergrond in de systeemtray te blijven. ChatGPT staat er standaard op. Toevoegen gaat met een naam of met één klik op een app die nu open is; een chip aanklikken haalt hem eraf.
- Super+Shift+Q sluit het actieve venster direct echt af (het proces stopt), voor elke app.
- Shift+klik op een tray-icoon sluit die app af, in de rail, de zijbalk en de topbar.
- De watcher `app-quit.sh watch` start met de sessie; de lijst staat in `~/.config/kingstra/close-fully.list`. Nieuwe smoketest `app-quit.sh`.

### Scrollen: één toets om verder te kijken
- Super+Ctrl+Alt+links/rechts schuift nu ook op een scrollstrook één kolom, net zoals hij op het ruimtelijk werkvlak het zicht verplaatst. Op tegelende werkruimtes doet hij niets.

### Rail: Meer-knop voor minder gebruikte knoppen
- In Bediening kies je per scherm en mode welke railknoppen achter Meer staan (meldingen, systeem, updates, games, extra knoppen, afsluiten, instellingen), zoals verborgen menubalk-items op macOS. Ze schuiven weg met een korte animatie; een klik op Meer in de rail laat ze weer zien en na acht seconden schuiven ze terug.

### Wallpaper-effect bij scrollen
- Bewegen over het ruimtelijk werkvlak geeft een klein effect op de wallpaper: een zachte lichtvlek in de accentkleur glijdt tegen de beweging in en dooft weer uit, zodat het voelt alsof je over de wallpaper beweegt. Per scherm aan of uit via Bediening.
- Echte parallax kan niet met skwd-paper; de Lua-layout meldt camerabewegingen nu als Hyprland-event (`custom>>kingstra-pan`).

### Werkvlakkaart met live beelden
- De kaart van het ruimtelijk werkvlak (Super+Tab) toont nu het live beeld van elk venster, met de titel als label eronder, net als het gewone overzicht. Zonder beeld blijft de titel zichtbaar.
- Zoomen met het wiel gaat vloeiend, tegels glijden mee als het zicht verschuift, en de kaart opent met een korte uitzoombeweging. Het zichtgebied staat als kader met label boven de vensters.

### Instellingen als eigen app
- Instellingen draait nu als eigen app in een eigen proces (`SettingsApp.qml`, app-id `kingstra-settings`) in plaats van als venster binnen de bar. Hij staat als "Kingstra Instellingen" in Walker en de shell-launcher, verschijnt in het overzicht en het venstermenu als gewoon venster en werkt ook als de bar hangt of gecrasht is.
- Opent standaard zwevend en gecentreerd; Super+T tegelt hem naast een andere app en onthoudt die keuze, zoals bij elke app. Venster sluiten stopt het proces.
- Super+, , `kingstra settings [pagina]`, `kingstra-settings` en alle diepe links (thema, geluid, bediening, ...) openen dezelfde app; een tweede aanroep springt naar de pagina in het open venster. Alle pagina's, zoeken en Bediening zijn ongewijzigd.
- Nieuwe smoketest `settings-app.sh` controleert app-id, Hyprland-regel en startgedrag.

### Vensters parkeren (minimaliseren)
- Super+- parkeert het actieve venster, zoals minimaliseren naar de taakbalk. Super+Shift+- haalt het laatst geparkeerde terug, op de werkruimte waar het stond.
- De vensterlijst (Super+W) toont geparkeerde vensters onderaan; Enter of klik haalt ze terug. Elke rij heeft een parkeerknop. Ook via het toetsenbordmenu (Vensters) en `kingstra parkeer [terug|lijst]`.
- Fix: de vensterlijst kon door een jq-fout leeg blijven.

### Bediening: uitleg bij mode per scherm
- Onder de modeknoppen staat nu wat een schermmode wel en niet regelt, en welke mode de desktop als geheel heeft. De volgorde van extra railknoppen toont nette namen in plaats van interne codes.

### Fix: vastpinnen werkt op elk scherm
- Vastpinnen vanuit het controlecentrum schreef altijd naar de gedeelde lijst. Op een scherm met eigen railkeuzes (Bediening) verscheen de knop daardoor niet. Het controlecentrum weet nu op welk scherm het openstaat en pint daar vast; middelklik in de rail maakt los zonder ongevraagd eigen keuzes voor dat scherm aan te maken.

### Fix: Bediening knipperde elke paar seconden
- Het uitlezen van de werkruimte-indeling (elke twee seconden) schakelde de indelingsknoppen steeds even uit, waardoor ze knipperden. Uitlezen en toepassen zijn nu gescheiden.
- De knoppen op Bediening krijgen dezelfde zachte kleur-, druk- en vervaagovergangen als de rest van Instellingen.

### Fix: Ruimtelijk werkvlak gaf altijd een foutmelding
- De controle of de ruimtelijke layout geladen is vroeg het antwoord op via `hyprctl eval`. Dat antwoordt in Hyprland 0.56 altijd alleen `ok`, nooit de waarde, dus de keuze werd steeds geweigerd. De controle gebruikt nu `hyprctl repl`, en een onleesbaar antwoord laat Hyprland zelf de indeling bevestigen.
- De foutmelding zegt nu wat er nodig is: Hyprland 0.56 of nieuwer en een herladen config.

### Opruimen: SwayNC-resten
- Per ongeluk meegecommitte SwayNC-kleurbestanden en de back-up van de Matugen-migratie zijn weg uit de repo en worden voortaan genegeerd. SwayNC wordt al sinds het eiland niet meer gebruikt.

### Herstel leesbaarheid Bediening
- De nieuwe Bediening-pagina verwijst expliciet naar Kingstra-kleuren. De naam palette botste met Qt's eigen palette-eigenschap, met zwarte tekst en witte of zwarte knoppen als gevolg.
- Een Qt-rendertest reproduceert die fout en controleert daarna de echte pagina met donkere en lichte kleuren, inclusief geselecteerde en niet-geselecteerde bediening.

### Shell start weer na update
- Het eiland gebruikte een eigen property `right`, een vaste (FINAL) eigenschap van elk Qt-item. Qt weigerde daardoor het eiland en via de shell-surface de hele bar; na `kingstra update` bleef het scherm leeg. Hersteld door de naam te wijzigen (96ec636).
- Nieuwe smoketest `qml-final-properties.sh` vangt deze fout voortaan voordat hij op main komt.

### Muziekspeler met materiaal en traagheid
- De desktopspeler krijgt een vaste plint, fijnere groeven en een plaat die op gang komt en rustig uitloopt bij pauze. De toonarm en plint draaien niet mee.
- Organic gebruikt een warme houtachtige plint, Paper een getekende omlijsting, Neon een compacte disc zonder toonarm en Mono een rustige hifi-uitvoering. De bestaande afspeelknoppen blijven gelijk.
- Bediening biedt per scherm en mode: volg thema, altijd vinyl of alleen hoes.

### GPU in Systeem
- Het systeemtabblad toont beschikbare GPU-belasting, temperatuur en VRAM per apparaat. Niet meetbare waarden heten Niet beschikbaar, geen fictieve 0%.
- Eén gedeelde meetbron voor alle schermen; pollen gebeurt alleen wanneer een systeemtabblad zichtbaar is. Een gesuspendeerde GPU wordt niet voor een meting wakker gemaakt.

### Bediening als startpagina
- Instellingen opent op Bediening: kies een fysieke monitor en wijzig mode, indeling van de werkruimte, zichtbare railonderdelen, extra knoppen en muziekzichtbaarheid.
- Railkeuzes worden voor de gekozen mode op het gekozen scherm bewaard. Extra knoppen kunnen omhoog/omlaag worden gezet; de mode-indeling is terug te zetten.
- Thema, wallpaper-picker en sneltoetsen zijn van hieruit bereikbaar. Een tandwiel in het controlecentrum en `kingstra bediening` openen dezelfde pagina.

### Mode en muziek per scherm
- Schermprofielen bewaren mode en railkeuzes per fysieke monitor, met aparte aanpassingen per mode. Een modewissel raakt geen globale energie-, thema- of meldingsinstellingen.
- De now-playing-pill kiest standaard één stabiel mediascherm in plaats van alle schermen of het steeds wisselende focusscherm. Zichtbaarheid en desktopmedia zijn per scherm instelbaar via Bediening.
- Schermen met een betrouwbare serienummeridentiteit herkennen hun profiel ook na opnieuw aansluiten. Zonder serienummer wordt de connector gebruikt om identieke displays uit elkaar te houden.

### Kaart van het ruimtelijke werkvlak
- Super+Tab toont op ruimtelijke werkruimtes een kaart van alle vensters en het zichtgebied. Sleep in beide richtingen, vergroot/verklein de kaart met het wiel en kies een venster om terug te keren.
- De kaart gebruikt venstertitels en geometrie; zij claimt geen live videopreviews of compositorzoom. Gewone werkruimtes houden het bestaande overzicht.

### Ruimtelijk werkvlak
- Super+Z biedt Ruimtelijk: vensters kunnen boven, onder en naast elkaar staan. De bestaande indeling blijft standaard behouden.
- Super+pijlen kiest een venster; Super+Shift+pijlen verplaatst het; Super+Ctrl+Alt+pijlen verplaatst het zicht. Super+drievingerveeg verwerkt beide assen tegelijk waar live Lua-gebaren ondersteund worden.
- Eén venster vult het werkgebied. Scroll-/kolombreedteacties controleren de werkelijke layout en doen niets wanneer scrollen uitstaat of de werkruimte leeg is.
- Lay-outkeuzes worden pas opgeslagen nadat Hyprland de wijziging bevestigt. Basis: Hyprscroll2D (MIT), met eigen Kingstra-integratie en tests.

### Rustige muziekstatus
- De animatie in de now-playing-pill gebruikt een vaste tekenruimte. Alleen de streepjes schalen; titel en pill veranderen daardoor niet meer mee van hoogte.

### Tablet mode: smoother
- Rotating keeps the screen's current resolution and refresh rate instead of asking for "preferred", so the panel no longer needs a full modeset (no black flash or resolution jump).
- Repeated hinge events no longer rotate again when the screen already has the right orientation; a short message in the corner says when tablet mode switches on or off.

### Zen mode
- Super+Alt+Z (or `kingstra zen`, or Modus › Zen in the keyboard menu) hides the bar and rail until you touch the edge, turns on Niet storen, removes the desktop widgets and dims windows without focus. Switching it off restores exactly what was there before.

### Login screen (SDDM)
- The Kingstra SDDM theme now matches the lock screen: the same 140 px clock with separate hours and minutes and a dimmed colon, the same date line, the same shrink-and-fade when you start typing, and the same 48 px glass pills at the bottom (keyboard layout, session, restart, power off) with hover growth.
- `kingstra update` copies the theme to `/usr/share/sddm/themes/kingstra` as before.

### Session: resume apps
- Like macOS and Windows, apps come back after logging in, each on the workspace where it was. The session starter saves the open apps every two minutes to `~/.local/state/kingstra/session.json` (command line, workspace, class; Flatpak apps restart via `flatpak run`) and restores them a few seconds after login.
- Apps that are already running (autostart) are not started twice; a snapshot older than seven days is ignored; an empty snapshot (for example while shutting down) never overwrites a good one.
- `kingstra sessie` shows what is saved; `kingstra sessie aan|uit|bewaar|herstel` switches it or saves and restores right away.

### Lock screen: glance
- Under the clock the lock screen now shows the next appointment (today or tomorrow), the track that plays or is paused with album art and working buttons, and one pill per app with the number of waiting notifications. Never the content: the shell writes only app names and counts to `$XDG_RUNTIME_DIR/kingstra-notification-summary.json`.
- Everything fades away with the clock as soon as you start typing.

### Windows: snap layouts, scrolling and scratchpad
- Super+Z opens a snap picker, like Snap Layouts in Windows 11 and KDE's tiles: seven layouts for the current workspace (Tegels, 50 | 50, 70 | 30, Midden groot, Drie kolommen, Scrollen, Eén tegelijk). Click a zone to put the active window there; the big zone makes it the main window. Keys 1-7, arrows and Enter work too.
- Every layout is a real Hyprland layout (dwindle, master, scrolling, monocle), so windows stay tiled. The choice per workspace is saved in `~/.local/state/kingstra/workspace-layouts.json` and comes back after a restart.
- Scrolling columns like niri: Super+Alt+S switches the current workspace to a scrolling strip and back. Super+Shift+wheel moves one column, Super+Ctrl+, and . make the column narrower or wider.
- Any window can become a scratchpad: Super+Shift+` sends the active window to the "kladblok" (floating, centered, 70% × 65%) or brings it back; Super+` shows or hides it. Spotify and Discord keep their own.
- Window groups (Super+G) get a tab bar of rounded pills in the theme's colors instead of thin stripes.
- New commands: `kingstra indeling [naam|scroll|kies]` and `kingstra kladblok [stuur]`; the keyboard menu has a Vensters submenu.
- Three-finger swipe down opens the control center, up opens the overview (needs a Hyprland version with Lua gesture functions; older versions skip it).
- Fix: `hypr-dispatch.sh setfloating` now sets floating instead of toggling it.

### Shell: Kingstra island
- One place for short feedback, like Dynamic Island and Live Activities on macOS: a pill grows out of the middle of the bar (with hollow corners into the bar edge) and shrinks back.
- Volume, microphone and brightness keys now run `hypr/scripts/osd.sh`, which changes the value itself (wpctl, brightnessctl) and shows it in the island. With the island's OSD off, or the shell not running, swayosd takes over as before.
- New notifications appear in the island instead of the cards at the top right; more waiting shows as `+2`. Left-click opens, right-click dismisses, middle-click skips. Critical notifications stay until clicked.
- Live activities: the playing track with album art and moving equalizer bars (click to expand with controls), plus dots when the microphone (orange), camera (green) or a screen recording (red) is in use.
- `kingstra eiland [osd|meldingen|live] aan|uit` switches parts off; `kingstra eiland meldingen uit` brings back the old notification cards. Stored in `~/.local/state/kingstra/island.json`.

### Shell: desktop widgets
- A large clock with the date and, when something plays or is paused, a media card sit on the wallpaper (above the wallpaper, below windows), in the theme's fonts and colors. Click the clock for the agenda.
- `kingstra widgets aan|uit|klok <plek>|media aan|uit` and the keyboard menu (Uiterlijk › Bureaubladwidgets) switch them and move the clock (linksboven, rechtsboven, midden, linksonder, rechtsonder).

### Shell: control center edit mode
- The pencil in the control center header switches to edit mode, like DMS and Windows 11: move pills left or right, make them wide or narrow, hide or show them. Saved in `~/.local/state/kingstra/control-center.json`; hidden pills stay reachable in edit mode.

### Shell: pinned rail modules
- Right-click a pill in the control center (Wi-Fi, Bluetooth, Niet storen, Energie) or the media card to pin it to the rail as a mini tile, like modules in the macOS menu bar. One click toggles it there; middle-click unpins. Stored in `~/.local/state/kingstra/rail-pins`.

### Shell: keyboard menu
- Super+Alt+Space (or `kingstra menu`) opens one keyboard menu for everything, like Omarchy's: apps, appearance (theme, wallpaper), mode, quick toggles, screens, capture, system (update, doctor, restore point, restart) and session. Arrows or 1-9 choose, Enter or → opens, ← goes back, typing filters.

### Shell: notifications
- The control center groups notifications per app, newest app first; the cross on an app's row clears that app.
- Notifications that support it (chat apps) get an answer field in the notifications panel; Enter sends the reply.

### Shell: launcher prefixes
- The launcher understands a first character, like Caelestia and DMS: `=` calculator (Enter copies), `>` shell command (terminal or background), `:` emoji search (Enter copies, Dutch words like `:hart` work), `/` jump to a setting, `?` search DuckDuckGo, Arch Wiki or Wikipedia, `@` switch to an open window.
- An empty launcher shows the prefixes as chips; click one to start.
- The setting index now lives in `settings/SettingIndex.js`, shared by the settings app and the launcher; `open settings thema/fonts` also picks the theme-editor tab.

### Shell: control center
- The panel that grows from the top edge is now a control center (Super+A, or click the status tile in the rail): quick toggles, volume and brightness, time, month and next appointment, system load, media, notifications and screen time in one place.
- Toggles work like GNOME's quick settings: click to switch, the arrow expands the pill in place (Wi-Fi networks, Bluetooth devices, power profiles) with a link to the full panel.
- Notifications live in the control center: click runs the app's action, the cross dismisses, "Wis alles" clears; the arrow still opens the full notifications panel.
- Opened by hover on the top edge it closes when you move away; opened by click or Super+A, or once you click inside, it stays open until Esc or a click outside.
- The old Snelle instellingen panel stays available through `qs_manager.sh toggle quicksettings`; `kingstra quick` now opens the control center.

### Shell: settings as a real app
- Settings opens as its own floating window instead of a drawer beside the rail: move it, tile it next to an app, open it on any screen, and it stays open when you click elsewhere. Super+, (new) and Super+Ctrl+I toggle it.
- Search finds individual settings (blur, scroll speed, idle lock, ...) and jumps to the right page and theme-editor tab.
- Deep links: `kingstra settings <page>` or `qs_manager.sh open settings <page>` (thema, bar, sneltoetsen, invoer, beeldschermen, netwerk, geluid, tijd, sessie, updates, geavanceerd, over). The launcher's Thema action opens the Thema page.

### Safety net
- Every update first makes a restore point: a local git tag of the dotfiles and, on btrfs with snapper, a system snapshot (`kingstra-snapshot`).
- `kingstra-rollback` puts the dotfiles back to the last restore point and holds them there until `kingstra-rollback --release`.
- One-time migrations in `installer/migrations/` replace cleanup that ran on every update.
- `kingstra-doctor` checks the installation (programs, links, Lua, colors, Quickshell, services, disk, .pacnew) and says how to fix problems.
- The install marker records the installed version.
- Your own edits to tracked files are set aside during an update and put back; on a clash the dotfiles stay on the old version.

### Ease of use
- `kingstra` command: theme, mode, wallpaper, update, doctor, snapshot, rollback, refresh, restart, settings, keys, version.
- `kingstra refresh <part>` puts one config back to the repo default, with a backup first.
- `config/hypr/lua/user.lua` for personal binds, rules and settings: not tracked, loads last, errors are caught.

- `kingstra-shell-watch` restarts the bar, popups or overview after a crash (at most 3 times per 10 minutes, then a notification instead of a restart loop).
- The update badge stays off while the dotfiles are held after a rollback.
- A one-time welcome after a fresh install: the five key shortcuts and the shortcut overview (`kingstra welcome` shows it again).

### Simpler
- SwayNC leftovers removed (config, color template, theme CSS, stop calls); migrations stop it and clean the Matugen config once.
- One launcher: the search buttons open the Quickshell launcher; Walker and Elephant no longer run as background services.
- The old music and volume popups (about 2,900 lines) are gone; every route already opened Sound & media.
- `installer/profiles/` replaced by `installer/overrides.example.conf`; `~/.config/kingstra/overrides.conf` is read on every install and update.

### Styling
- Opening animations of Battery, Focus time, Monitors and Settings shortened from 1–1.8 s to about half a second, without the springy overshoot; they now follow the animation speed setting.
- Motion profiles "snappy" (neon) and "calm" (paper) now actually change the tempo.
- Rail in three groups: navigation on top (launcher, workspaces), notifications and status in the middle, system at the bottom with the clock.
- Status strip: the clock in the middle opens the calendar; the separate Agenda button is gone.
- The updates button only shows when there are updates.
- A panel that fails to load shows a clear message with `kingstra doctor` instead of a placeholder.
- Panels and popups use the theme's mono font (`ThemeConfig.textFont`, ~430 places) instead of a fixed font name, with JetBrains Mono as fallback when the theme font is not installed. Nerd icons use `ThemeConfig.iconFont`.
- About 450 hover and state animations in panels follow the theme's motion speed (`ThemeConfig.duration`), like the rail already did.
- `ttf-ibm-plex` is installed for the paper theme.
- Battery and network popups use the theme text color for their glass overlays instead of fixed white, so they show up on the light paper theme too.

## 2026.10.0 — 2026-10-27

First versioned release. Highlights since the Lua migration:

### Shell
- Quick settings, status tile, system tray and a richer dashboard (Overview and System tabs).
- Sound & media: volume panel and music popup merged into one audio panel, with equalizer presets.
- Notifications: pop-ups next to the rail, a counter on the rail, grouping per app, do-not-disturb.
- Agenda: compact panel with local events and hourly weather.
- Settings: eight Dutch tabs with a search field.
- Focus and Monitors moved out of the rail to the dashboard and Quick settings.
- Workspace overview: one screen, fixed grid, fade in and out, close with the mouse.
- Removed: mail panel, the Today tab, the Stewart overlay, unused alternative network and battery popups.

### Windows
- Floating apps remember their size and position per app; `Super + T` remembers floating per app.
- Floating windows get a subtle border.

### Hardware
- Logitech M720 thumb button: drag windows, double-click for the overview; keeps working after restart, sleep and reconnect.

### Installer and updates
- Compact installer and updater view with a fixed header and progress bar.
- Package overview with weekly cache cleanup; loose files no longer block a dotfiles update.
- CI: smoke tests, ShellCheck and qmllint on every push.

### Lockscreen
- Typed password characters are hidden by default.

### Docs
- Old planning documents for the six previous themes moved to `docs/archief/`.
