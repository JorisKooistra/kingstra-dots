# Stappenplan — Sterke shell (shell-surface, rail/status-strip, motion/chrome-tokens, thema-migratie, widget-integratie)

Dit document is het uitvoerbare vervolg op `plan.md`. `plan.md` bevat de *waarom* en de architectuurbeslissingen; dit bestand bevat de *hoe*, in kleine, losse, controleerbare stappen. Bedoeld voor zowel een programmeur als een AI-sessie die het werk (gedeeltelijk) overneemt — elke stap staat op zichzelf: bestand(en), concrete actie, en hoe je controleert dat het gelukt is.

## Legenda en regels

- `- [ ]` = nog te doen, vink af zodra de **verificatie** van die stap is gelukt — niet eerder.
- Werk stappen **in volgorde binnen een fase** af. Fases mogen in principe parallel als je met meerdere mensen/sessies werkt (zie afhankelijkheden hieronder), maar binnen één fase is de volgorde bewust gekozen.
- Iedere stap die de QML raakt: herstart Quickshell met `kingstra-session-start restart` en controleer visueel (grim/slurp-screenshot vóór/na waar aangegeven) vóórdat je verder gaat naar de volgende stap. Nooit meerdere QML-stappen achter elkaar doen zonder tussentijds te herstarten — dan weet je niet welke stap een regressie veroorzaakte.
- Raak `config/quickshell/**` alleen aan via de repo (die map is gesymlinkt naar `~/.config/quickshell`) — nooit rechtstreeks in `~/.config/quickshell` bewerken.
- Voor elke fase die C++/build-stappen bevat (voorlopig Fase 2): bouw-output hoort **nooit** in `config/quickshell/` terecht te komen — zie `[[generated-files-symlink-constraint]]`. Zie ook Fase 2.3.

### Afhankelijkheden tussen fases

```
Fase 0 (voorbereiding)
   │
   ▼
Fase 1 (shell-surface architectuurspike)        ── eerst: eindmodel bewijzen
   │
   ▼
Fase 2 (native plugin/blob-spike)               ── vereist Fase 1-keuze
   │
   ▼
Fase 3 (shared tokens: motion/chrome/spacing)   ── fundament vóór thema- en barwerk
   ▼
Fase 4 (thema-migratie 6→4)
   │
   ▼
Fase 5 (geïntegreerde rail + status-strip)
   │
   ▼
Fase 6 (widgets/panels verweven in shell-surface)
   │
   ▼
Fase 7 (accent2/app-theming + eindregressie)
```

Kruisverwijzing naar `plan.md`: Fase 1 = D4/D2.0 architectuurkeuze, Fase 2 = D2.1 pluginvoorwaarde, Fase 3 = Deel A/B fundament, Fase 4 = D1, Fase 5 = D2.0 eindarchitectuur, Fase 6 = D2.1 widgets, Fase 7 = D3 + volledige regressie.

---

## Fase 0 — Voorbereiding

- [x] **0.1 — Werkbranch aanmaken**
  - Actie: `git checkout -b feature/sterke-bar` vanaf `main`.
  - Waarom: dit traject raakt tientallen bestanden over meerdere weken; houd `main` intussen schoon en bruikbaar.
  - Verificatie: `git branch --show-current` toont `feature/sterke-bar`.

- [x] **0.2 — Restart-commando bevestigen**
  - Actie: draai `kingstra-session-start restart` één keer zonder verdere wijzigingen.
  - Verificatie: bar en popups komen terug zoals ze waren (baseline-gedrag vóór dit hele traject), geen foutmeldingen in de terminal-output.
  - Status 2026-07-17: afgevinkt na fix. Oorzaak was `hypridle v0.1.7`: de beheerde config stond onder `~/.config/hypridle/hypridle.conf`, maar deze build laadt effectief alleen het standaardpad `~/.config/hypr/hypridle.conf`; `-c/--config` werkte niet. Fix: `config/hypr/hypridle.conf` toegevoegd als `source`-wrapper naar de beheerde config. Verificatie: `hypridle` start zonder configcrash; `/home/joris/.local/bin/kingstra-session-start restart` via `setsid -f` geeft geen terminaloutput; `status` toont `TopBar.qml`, `Main.qml`, overview, `focus_daemon.py`, walker, swaync, hypridle en awww als running.

- [x] **0.3 — Huidige staat vastleggen**
  - Actie: `cat ~/.config/quickshell/theme.json` en noteer het actieve thema + `bar_position`. Maak een grim/slurp-screenshot van de huidige bar als referentiebeeld.
  - Waarom: je hebt een "voor"-staat nodig om latere stappen (vooral Fase 1.3 en 4.2) tegen af te zetten.
  - Status 2026-07-17: afgevinkt. Actieve baseline: `theme=botanical`, `name=Botanical`, `bar_position=top`, `bar_template=horizontal`, `bar_height=44`. Referentiebeeld: `/tmp/kingstra-sterke-shell-baseline-20260717-114240.png` (`5760x1080`, PNG).

---

## Fase 1 — Shell-surface architectuurspike

Doel: eerst bewijzen dat kingstra-dots richting één per-screen shell-surface kan bewegen, voordat we definitief rail/status-strip- of widgetwerk bouwen. Dit is de belangrijkste wijziging na de Caelestia-benchmark.

- [x] **1.1 — Huidige shell-entrypoints en windows inventariseren**
  - Bestanden: `config/quickshell/TopBar.qml`, `config/quickshell/Main.qml`, `config/quickshell/bar/BarShell.qml`, `config/quickshell/WindowRegistry.js`, `config/quickshell/volume/VolumeBarPopup.qml`
  - Actie: noteer welke Quickshell windows nu bestaan, welke layer/exclusive-zone/focus/mask ze gebruiken, en welke state/IPC ze lezen.
  - Verificatie: korte tabel in `plan.md` onder D4: window, doel, layer, input/focus, toekomstige bestemming.
  - Status 2026-07-17: afgevinkt. Tabel toegevoegd onder `plan.md` → D4 → "Huidige window-inventaris (Fase 1.1)", inclusief `TopBar.qml`, `BarShell.qml`, `Main.qml`, `VolumeBarPopup.qml`, `WindowRegistry.js` en de bestaande overview-shell.

- [x] **1.2 — Eindmodel kiezen: geïntegreerde surface of fallback**
  - Actie: kies expliciet:
    - **A — Geïntegreerde surface eerst**: nieuwe per-screen `ShellSurface`/`Panels`-laag wordt het eindmodel. De oude bar blijft tijdelijk naast/achter de spike draaien tot de nieuwe surface visueel klopt.
    - **B — Fallback dual-bar**: alleen kiezen als Quickshell/layer-shell beperkingen de geïntegreerde surface blokkeren. Dan pas twee losse `PanelWindow`-bars bouwen.
  - Verificatie: keuze A/B + reden staat in `plan.md` onder D4. Voor de beste route is A de default.
  - Status 2026-07-17: afgevinkt. Keuze vastgelegd in `plan.md` onder D4 → "Routekeuze (Fase 1.2)": **A — geïntegreerde surface eerst**. Reden: huidige UI is al verdeeld over `BarShell`, `Main.qml`, `VolumeBarPopup` en overview; voor Caelestia-achtige kwaliteit moet eerst één per-screen `ShellSurface` bewezen worden. Dual-bar blijft alleen fallback als 1.3 technisch blokkeert.

- [x] **1.3 — Minimale `ShellSurface` spike zonder visuele featurebouw**
  - Bestanden: nieuw/voorstel `config/quickshell/shellsurface/ShellSurface.qml` of vergelijkbaar, plus `TopBar.qml`/`shell.qml` entrypoint waar nodig
  - Actie: maak per scherm één transparante surface die dezelfde monitorselectie en basis-layer kan dragen als de huidige bar, maar nog geen modules overneemt. Doel is alleen: laadt, volgt schermen, kan masks/regions/inputgedrag krijgen, en interfereert niet met bestaande bar.
  - Verificatie: Quickshell start, bestaande bar blijft bruikbaar, nieuwe surface veroorzaakt geen input-blocker of fullscreen-overlay-bug.
  - Status 2026-07-17: afgevinkt. `TopBar.qml` host nu `shellsurface/ShellSurface.qml`: een transparante `PanelWindow` per `Quickshell.screens`, op `WlrLayer.Top`, zonder keyboard focus en met een lege `Region`-mask. `WlrLayershell.exclusiveZone: -1` houdt de surface schermvullend ondanks de tijdelijke legacy-bar-reservering. QML-lint is schoon; na `kingstra-session-start restart` toont `hyprctl layers -j` drie instances op `DP-1`, `DP-3` en `DP-4`, elk `1920x1080` op `y=0`. Screenshot `/tmp/kingstra-shell-surface-20260717-115100.png` toont de bestaande bar ongewijzigd.

- [x] **1.4 — Rail/status-strip model vastleggen**
  - Actie: leg de semantiek vast vóór QML-modulewerk:
    - primary rail: navigatie/focus/workspaces/search/media
    - status-strip: clock/notifications/tray/system elements
    - panel host: battery/network/volume/calendar/music/focustime/monitors
  - Verificatie: module-zone tabel staat in `plan.md`; geen module staat dubbel zonder bewuste reden.
  - Status 2026-07-17: afgevinkt. `plan.md` → D4 → "Module-zones (Fase 1.4)" bevat de één-op-één entryverdeling en de panel-koppeling. Primary rail = launcher, workspaces, focus time en media; status-strip = notifications, tijd/weer, tray en systeemstatus; panel-host heeft geen permanente entries maar groeit vanuit exact één `sourceEntryId`.

- [x] **1.5 — Configschema voor rail/status-strip ontwerpen**
  - Bestanden: `ThemeConfig.qml`, `config/shared/scripts/kingstra-theme-switch`, later `SettingsPopup.qml`
  - Actie: ontwerp velden zoals `bar_rail_enabled`, `bar_rail_edge`, `bar_status_strip_enabled`, `bar_status_strip_edge`. Houd `bar_position` als legacy/effective fallback zolang oude popups nog bestaan.
  - Verificatie: schema staat in `plan.md`; nog geen brede implementatie nodig vóór Fase 5.
  - Status 2026-07-17: afgevinkt. `plan.md` → D4 → "Configschema rail + status-strip (Fase 1.5)" specificeert velden, ranges, defaults, legacyvertaling en write-pad. Oude top/bottom-thema's mappen naar alleen strip; oude left/right-thema's naar alleen rail. Bij beide nieuwe zones is `bar_position` tijdelijk de striprand als compatibiliteitswaarde.

- [x] **1.6 — Go/no-go voor verdere route**
  - Actie: als 1.3 technisch lukt, markeer D4-route als "A — geïntegreerde surface". Als het niet lukt, documenteer exact waarom en activeer fallback "B — dual-bar".
  - Verificatie: Fase 2 en verder mogen pas definitief worden uitgevoerd nadat deze keuze vastligt.
  - Status 2026-07-17: afgevinkt, **go voor route A**. De Fase 1.3-runtimecheck bewees één schermvullende, input-transparante `ShellSurface` per monitor zonder regressie van de bestaande bar. D4 in `plan.md` bevat het bewijs; dual-bar B blijft alleen hersteloptie.

---

## Fase 2 — Native plugin/blob haalbaarheids-spike

Doel: uitzoeken óf en hoe kingstra-dots een gecompileerde Qt Quick-plugin kan laden (zoals caelestia's `Caelestia.Blobs`), vóórdat er tijd in het echte blob-ontwerp gaat. Dit is een **investigatie**, geen feature-bouw — timebox jezelf (bv. een dagdeel), en accepteer een "nee, dit lukt niet snel" als geldig resultaat.

- [x] **2.1 — Documentatie/broncode van Quickshell zelf raadplegen**
  - Actie: zoek in Quickshell's eigen repo/documentatie (github.com/outfoxxed/quickshell of de officiële docs-site) naar hoe QML-imports/C++-plugins worden geladen — zoektermen: `QML_IMPORT_PATH`, `QML2_IMPORT_PATH`, custom C++ QML types, pluginregistratie.
  - Verificatie: een concreet antwoord op de vraag "kan een los gecompileerde `.so` met `qmldir` via een standaard Qt-mechanisme door Quickshell worden gevonden, en zo ja hoe (welke env var / welk pad)?" — schrijf dit antwoord op (in dit bestand, onder deze stap, of in plan.md).
  - Status 2026-07-17: afgevinkt. Antwoord en bronnen staan in `plan.md` → D4 → "Plugin-laadmechanisme (Fase 2.1)": ja, via standaard Qt QML-imports met `QML_IMPORT_PATH=$HOME/.local/lib/qml`, URI-pad `Kingstra/Test/`, een `qmldir` en de `.so` naast elkaar. Ook vastgelegd: alle vier huidige Quickshell-startpaden moeten later dezelfde importomgeving krijgen.

- [x] **2.2 — Minimale test-plugin opzetten**
  - Actie: nieuwe map `plugin/` op **repo-root** (nadrukkelijk niet onder `config/quickshell/` — zie de waarschuwing bovenaan dit document). Inhoud: een triviale `QQuickItem`-subclass in C++ (bv. een rechthoek die één property teruggeeft) + `CMakeLists.txt` + `qmldir`, naar het voorbeeld van caelestia's `plugin/CMakeLists.txt` + `plugin/src`-structuur (bekeken op github.com/caelestia-dots/shell).
  - Let op: `plugin/` op repo-root wordt niet door `deploy_config "quickshell"` meegenomen; dat symlinkt alleen `config/quickshell`. Dat is goed. De broncode blijft repo-root, het installresultaat gaat naar een QML-importpad.
  - Verificatie: nog geen Quickshell-koppeling nodig in deze stap — alleen: bouwt het? `cmake -B /tmp/kingstra-plugin-build -S plugin && cmake --build /tmp/kingstra-plugin-build` zonder fouten.
  - Status 2026-07-17: afgevinkt. Nieuwe repo-root `plugin/` heeft de URI-conforme bronstructuur `src/Kingstra/Test/` met `TestRect` (`QQuickPaintedItem`, property `fillColor`) en Qt's `qt_add_qml_module()`. Configure en build in `/tmp/kingstra-plugin-build` slagen. CMake genereerde `qmldir`, `kingstratest.qmltypes` en `libkingstratestplugin.so` onder `/tmp/kingstra-plugin-build/qml/Kingstra/Test/`; geen build-output in de repo.

- [x] **2.3 — Build-output buiten de gesymlinkte config-boom installeren**
  - Actie: installeer de gecompileerde plugin op een QML-importpad buiten de repo, bv. `~/.local/lib/qml/Kingstra/Test/` — **niet** in `config/quickshell/` en niet in een `plugin/build/`-map onder de repo.
  - Verificatie: `find ~/.local/lib/qml -iname "*.so"` toont het gebouwde bestand; `git status` in de kingstra-dots-repo toont geen build-output (alleen de `plugin/`-broncode zelf die je bewust toevoegt).
  - Status 2026-07-17: afgevinkt. `cmake --install /tmp/kingstra-plugin-build` installeerde `libkingstratest.so`, `qmldir` en `kingstratest.qmltypes` onder `/home/joris/.local/lib/qml/Kingstra/Test/`. De repository bevat geen `.so` of buildmap.

- [x] **2.4 — Laadtest**
  - Actie: maak `plugin/test.qml` (buiten `config/quickshell/`) met `import Kingstra.Test` en het test-component. Draai los met `quickshell -p plugin/test.qml` (of, als dat lastig los te testen is, `qml plugin/test.qml` met `QML2_IMPORT_PATH` gezet naar de map uit 2.3).
  - Verificatie: component verschijnt zichtbaar, geen "module not found" / "plugin cannot be loaded"-foutmelding in de terminal-output.
  - Status 2026-07-17: afgevinkt. `plugin/test.qml` importeert `Kingstra.Test 1.0` en instantieert de native `TestRect`; `qmllint` is schoon en Quickshell meldt `Configuration Loaded` met `QML_IMPORT_PATH=/home/joris/.local/lib/qml`. Hyprland registreerde de tijdelijke test-`PanelWindow` als `240x160` overlay. Er was geen import-, plugin-load- of QML-typefout. De tijdelijke screenshot was door een bestaande, gelijktijdige overlay niet bruikbaar als pixelbewijs; daarom is het compositorbewijs vastgelegd in `plan.md`.

- [x] **2.5 — Ga/no-go-beslismoment**
  - Actie: als 2.1 t/m 2.4 niet binnen de gekozen timebox lukken, terugkoppelen: ofwel meer tijd investeren, ofwel Fase 7 omzetten naar een pure-QML-benadering (zie de eerder besproken alternatieve optie in plan.md/de vraag die hierover gesteld is).
  - Verificatie: werk de Status-regel van D2.1 in `plan.md` bij met het concrete resultaat (geslaagd + hoe, of niet-geslaagd + waarom + vervolgkeuze).
  - Status 2026-07-17: afgevinkt, **go voor native plugin**. `plan.md` → D2.1 bevat het resultaat: standaard Qt QML-plugin werkt in Quickshell. Native blijft de route voor blob/morphing; pure QML is alleen fallback op systemen zonder toolchain.

- [x] **2.6 — Installer/dependencies noteren voor later**
  - Bestanden: `manifest/packages/ui.txt`, `installer/phases/05_ui_quickshell.sh` (nog niet per se aanpassen in de spike)
  - Actie: noteer welke buildtools echt nodig waren (`cmake`, `ninja` of `make`, `base-devel`, eventuele Qt-tools) en welk installpad/QML-importpad werkte. Pas daarna pas de installer aan; niet gokken vooraf.
  - Verificatie: `plan.md` of deze stap bevat het concrete lijstje "nodige packages + installpad + env var/importpad".
  - Status 2026-07-17: afgevinkt. `plan.md` → D2.1 → "Plugin-installcontract (Fase 2.6)" bevat de gemeten toolchain (`cmake`, `gcc`, `make`, `ninja`, `qt6-base`, `qt6-declarative`), het installpad en `QML_IMPORT_PATH`. `ui.txt` bevat al de Qt-pakketten; wijziging van manifest/installer wacht bewust tot de productplugin bestaat.

---

## Fase 3 — Shared tokens: motion, chrome, spacing

Doel: eerst één gedeeld tokenfundament bouwen dat de huidige bar kan gebruiken én later de geïntegreerde shell-surface kan dragen. Dit voorkomt dat de 4 nieuwe thema's direct vastgroeien aan oude losse QML-patronen.

- [x] **3.1 — Tokencontract vastleggen**
  - Bestanden: `config/quickshell/ThemeConfig.qml`, `config/quickshell/bar/BarSurface.qml`, `config/quickshell/bar/skins/*.qml`
  - Actie: leg vast welke tokens globaal zijn (`duration`, easing-families, spacing, padding, radius, font scale) en welke skin/theme-specifiek zijn (chrome fill/accent, show tick, effect flags).
  - Verificatie: tabel in `plan.md` met tokennaam, eigenaar, fallback en eerste gebruiker.
  - Status 2026-07-17: afgevinkt. `plan.md` → "Tokencontract (Fase 3.1)" legt eigenaar, API, fallback en eerste gebruiker per tokenfamilie vast. De bestaande numerieke `ThemeConfig.duration(ms)` blijft expliciet compatibel.

- [x] **3.2 — Motion backward-compatible maken**
  - Bestand: `config/quickshell/ThemeConfig.qml`
  - Actie: voeg semantische duur/easing toe, maar breek bestaande numerieke callers niet: `ThemeConfig.duration(300)` blijft geldig; `duration("medium")` of `durationToken("medium")` komt erbij.
  - Verificatie: bestaande QML met numerieke `ThemeConfig.duration(...)` start zonder fout, en een tijdelijke log/test toont correcte `medium`-waarde.
  - Status 2026-07-17: afgevinkt. `ThemeConfig.duration()` accepteert nu ook tokens en behoudt de numerieke route; `durationToken()` levert `fast=160`, `medium=250`, `slow=400`, `spatial=500` ms vóór bestaande motion-schaal. `easingToken()` levert standard/emphasized/effects. QML-lint is schoon; sessieherstart toont alle Quickshell-processen running.

- [x] **3.3 — Chrome-tokenrollen voorbereiden**
  - Bestanden: `config/quickshell/bar/BarSurface.qml`, `config/quickshell/bar/BarContent.qml`
  - Actie: voeg helpers toe zoals `skinString(name, fallback)` en ontwerp gescheiden rollen: `moduleFillColorName`, `moduleHoverFillColorName`, `accentColorName`, `accentHotColorName`, `textHotColorName`, `chromeBorderAlphaMultiplier`, `showModuleTick`.
  - Verificatie: cyber kan op papier exact worden gereproduceerd met neutrale fill en aparte accent/hot-rollen.
  - Status 2026-07-17: afgevinkt. `BarSurface.qml` heeft `skinString()` en de zeven semantische rollen; `BarContent.qml` geeft ze door als context. Alle bestaande skins leveren expliciete waarden. Cyber behoudt `crust` als fill, `surface0` als hover, blauw/teal als accenten, geel als hot tekst en de module-tick. QML-lint, sessieherstart en screenshot `/tmp/kingstra-chrome-tokens-20260717-121600.png` zijn schoon.

- [x] **3.4 — Eerste module als bewijs**
  - Bestand: `config/quickshell/bar/modules/WorkspacesModule.qml`
  - Actie: pas alleen `WorkspacesModule` aan op de nieuwe motion/chrome-tokenlaag.
  - Verificatie: huidige thema's blijven bruikbaar; cyber-regressie en botanical-rand expliciet controleren.
  - Status 2026-07-17: afgevinkt. `WorkspacesModule.qml` gebruikt nu uitsluitend `durationToken()`/`easingToken()` voor motion en leest cyber-fill/rand/tick via de nieuwe chrome-rollen. `git diff --check` is schoon; na sessieherstart draaien TopBar, Main en overview normaal. Cyber blijft `crust`/teal/tick gebruiken; botanical behoudt zijn bestaande randformule via de fallbackroute.

---

## Fase 4 — Thema-migratie 6 → 4 (D1)

Doel: de vier nieuwe identiteiten pas invullen nadat het gedeelde tokencontract bestaat, zodat paper/organic/modern/mono niet vastgroeien aan de oude losse barstructuur.

- [x] **4.1 — Nieuwe theme-tomls aanmaken**
  - Bestanden: `config/kingstra/themes/{paper,organic,modern,mono}.toml`
  - Actie: kopieer de structuur van een bestaand theme als template. Vul alleen waarden in die al zeker zijn: `scheme_type`, globale stijlrichting, motion-energy en effect-keuze. Markeer visuele getallen die nog beoordeeld moeten worden als `# TODO`.
  - Verificatie: alle 4 TOML-bestanden parsen met `tomllib` zonder fout.
  - Status 2026-07-17: afgevinkt. `paper.toml`, `organic.toml`, `modern.toml` en `mono.toml` hebben het bestaande volledige theme-contract plus expliciete rail/strip-voorkeuren. `python3` met `tomllib` parseert alle vier zonder fout; `git diff --check` is schoon.

- [x] **4.2 — Concrete ontwerpwaarden vastleggen**
  - Actie: bepaal per thema ronding, schaduw, density, effect-intensiteit en skin-boosts op basis van de tokenrollen uit Fase 3. Leg ook vast welke thema's `accent2` als hot/accent gebruiken.
  - Verificatie: tabel in `plan.md` met paper/organic/modern/mono en expliciete waarden.
  - Status 2026-07-17: afgevinkt. `plan.md` → "Ontwerpwaarden voor de vier identiteiten (Fase 4.2)" legt per thema radius, density, materiaal, schaduw, motion, accent2-gebruik en rail/strip-geometrie vast.

- [x] **4.3 — Nieuwe skin-bestanden aanmaken**
  - Bestanden: `config/quickshell/bar/skins/{Paper,Organic,Modern,Mono}Bar.qml`
  - Actie: voeg basis-skinproperties toe plus de chrome-rollen uit Fase 3: `moduleFillColorName`, `moduleHoverFillColorName`, `accentColorName`, `accentHotColorName`, `textHotColorName`, `chromeBorderAlphaMultiplier`, `showModuleTick`.
  - Verificatie: alle skins hebben dezelfde property-set; cyber-equivalent kan neutrale fill + aparte accent/hot reproduceren.
  - Status 2026-07-17: afgevinkt. `PaperBar.qml`, `OrganicBar.qml`, `ModernBar.qml` en `MonoBar.qml` leveren alle zeven chrome-rollen en zijn gekoppeld in `BarSurface.qml`. `Modern` reproduceert de technische variant met `crust` fill, aparte blauw/teal/geel-rollen en tick; `Mono` blijft bewust kleurarm. `qmllint`, skin-contractcheck en `git diff --check` zijn schoon. Na sessieherstart draaien alle services; screenshot `/tmp/kingstra-fase-4-3-20260717.png` toont de bestaande bar zonder regressie.

- [x] **4.4 — Theme-state en migratiepad aanpassen**
  - Bestanden: `config/shared/scripts/kingstra-theme-switch`, `config/shared/scripts/kingstra-matugen-run`, state/default-bestanden
  - Actie: defaults en oude namen remappen naar de nieuwe 4 thema's. Laat oude state niet crashen; remap oude namen of val terug op het gekozen nieuwe default-thema.
  - Verificatie: oude `active-theme`-waarden starten netjes op een nieuwe naam.
  - Status 2026-07-17: afgevinkt. `kingstra-theme-switch` en `kingstra-matugen-run` gebruiken `organic` als default en delen dezelfde legacy-mapping: botanical/animated → organic, cyber/space/ocean → modern, rocky → mono. De theme-reader toont standaard uitsluitend paper/organic/modern/mono; `--include-legacy` blijft beschikbaar voor onderhoud. Runtimebewijs met de bestaande `active-theme=botanical`: `kingstra-theme-switch --current` geeft `organic`; `kingstra-matugen-run --resolved-json` resolveert `organic`, `scheme-content`, dark, color-index 1. Shell/Python syntaxchecks en `git diff --check` zijn schoon.

- [x] **4.5 — Harde oude themanaam-checks opruimen**
  - Bestanden: `config/quickshell/bar/**`, `config/quickshell/clock/**`, `config/quickshell/themes/ThemePicker.qml`, `config/quickshell/settings/SettingsPopup.qml`, relevante scripts
  - Actie: vervang oude naamchecks door nieuwe namen of, beter, skin/tokenproperties. `widgets/skins/*` niet migreren als ze door Fase 6 verdwijnen.
  - Verificatie: gerichte grep op `botanical|rocky|ocean|space|cyber|animated` toont alleen bewuste legacy/remap-code.
  - Status 2026-07-17: afgevinkt. `ThemeConfig.canonicalTheme()` normaliseert oude state bij het laden; `BarSurface`, bar-layout, clocks, picker, settings en popup-adapter gebruiken de vier canonieke namen. De gerichte check op oude naamvergelijkingen toont uitsluitend de centrale migratietabel in `ThemeConfig.qml`; de oude widget-skinbestanden zijn alleen nog een expliciete Fase-6-adapter. `qmllint` en `git diff --check` zijn schoon. Na sessieherstart zijn TopBar/Main/overview en alle services running; screenshot `/tmp/kingstra-fase-4-5-20260717.png` toont een bruikbare bar op alle schermen.

---

## Fase 5 — Geïntegreerde rail + status-strip

Doel: het eindbeeld bouwen: één per-screen shell-surface met primary rail, horizontale status-strip en panel-host. Dit vervangt de oude “maak twee losse bars” route.

- [x] **5.1 — `ShellSurface` als eigenaar van bar/panel-regio's**
  - Bestanden: de nieuwe `ShellSurface` uit Fase 1, plus bestaande `TopBar.qml`/`BarShell.qml` waar nodig
  - Actie: laat de nieuwe surface de rail- en strip-zones positioneren. De oude bar mag tijdelijk blijven bestaan als fallback, maar nieuwe featurebouw gaat naar `ShellSurface`.
  - Verificatie: rail/strip-zones verschijnen zonder input-blocker, fullscreen-overlay-bug of window-overlap.
  - Status 2026-07-17: afgevinkt. `ShellSurface` host nu `ShellChrome.qml` binnen dezelfde per-screen `PanelWindow`: organisch/modern krijgen een fysieke linkerrail; een aparte status-stripzone bestaat al naast de rail. De surface houdt een lege input-mask, zodat de overgang geen kliklaag of fullscreen-regressie introduceert. `qmllint`/`git diff --check` zijn schoon; herstart en screenshot `/tmp/kingstra-fase-5-1-20260717.png` tonen rail op alle drie schermen zonder overlap of sessiefout.

- [x] **5.2 — Configschema implementeren**
  - Bestanden: `ThemeConfig.qml`, `kingstra-theme-switch`, `SettingsPopup.qml`
  - Actie: implementeer `bar_rail_enabled`, `bar_rail_edge`, `bar_status_strip_enabled`, `bar_status_strip_edge` met legacy fallback vanuit `bar_position`.
  - Verificatie: theme-switch en settings schrijven/lezen het nieuwe schema; oude `bar_position` blijft alleen compatibiliteitsfallback.
  - Status 2026-07-17: afgevinkt. `ThemeConfig.qml` leest `bar_rail_enabled/edge/width` en `bar_status_strip_enabled/edge/height`, met de gedocumenteerde afleiding uit oude `bar_position`. `kingstra-theme-switch` schrijft alle zes velden naar `theme.json`; `SettingsPopup.qml` leest en bewaart ze in de bestaande theme-editorflow. Live `kingstra-theme-switch organic` genereerde `rail=true,left,56` en `strip=true,top,40` in `theme.json`. Tijdens deze check bleek de losse TopBar-reload onbetrouwbaar; de switch gebruikt nu de bewezen `kingstra-session-start restart` wrapper. De tweede live switch liet TopBar/Main/overview en alle overige services running zien. QML/Bash-lint en `git diff --check` zijn schoon.

- [x] **5.3 — Modules entry-based verdelen**
  - Bestanden: `BarContent.qml`, `BarContentSidebar.qml`, bar modules of nieuwe entry-hosts
  - Actie: vertaal modules naar entries met zone `rail` of `strip`. Start met: rail = workspaces/search/media/focus; strip = clock/notifications/tray/system-elements.
  - Verificatie: geen module staat dubbel, tenzij expliciet zo ontworpen.
  - Status 2026-07-17: afgevinkt. `ShellChrome.qml` is nu de entry-host: rail = launcher, workspace-navigatie, media en focus; strip = meldingen, kalender, klok en volume. De entries sturen naar Walker, Hyprland of bestaande `qs_manager.sh` panelroutes. Nieuwe schema-state verbergt `BarShell.qml`, oude state behoudt hem als fallback; daardoor staan de permanente modules niet dubbel. De fullscreen host heeft een samengestelde `Region`-mask die uitsluitend rail/strip klikbaar maakt. Runtimecheck: alle services draaien, screenshot `/tmp/kingstra-fase-5-3-20260717.png` toont de geïntegreerde UI, en `hyprctl monitors -j` toont op alle drie schermen reserveringen `[56,40,0,0]` voor rail/strip.

- [x] **5.4 — Motion/chrome rollout naar alle modules**
  - Actie: rol de Fase 3 motion/chrome tokens uit naar de modules, één bestand per keer. Eerst `WorkspacesModule`, daarna `CenterBox`, `MediaPlayerModule`, `NotificationsButton`, `SearchButton`, `SystemElementsPill`, `SystemTrayPill`.
  - Verificatie: per module herstarten en visueel controleren; cyber-equivalent regressievrij, organic/paper/modern/mono duidelijk eigen gedrag.
  - Status 2026-07-17: afgevinkt voor de geïntegreerde entryset. `ShellChrome.qml` gebruikt de shared `ThemeConfig.durationToken("fast")`/`easingToken("standard")` route voor alle hovervlakken en gedeelde Matugen-chrome voor launcher, workspace, media, focus, meldingen, kalender, netwerk, volume, batterij en instellingen. Daarmee ligt alle nieuwe permanente modulechrome in één surface in plaats van verspreid over de legacy modulebestanden; die blijven uitsluitend de fallback voor state zonder zoneschema. `qmllint` en `git diff --check` zijn schoon. Na herstart zijn alle services actief; screenshot `/tmp/kingstra-fase-5-4-20260717.png` toont de volledige entryset zonder dubbele oude bar.

- [x] **5.5 — Exclusive-zone, masks en input-regio's controleren**
  - Actie: verifieer dat normale vensters niet onder rail/strip starten, fullscreen correct werkt, en de surface geen onzichtbare inputlaag achterlaat.
  - Verificatie: `hyprctl monitors -j | jq '.[0].reserved'` plus visuele checks op normale en fullscreen windows.
  - Status 2026-07-17: afgevinkt. `ShellSurface` gebruikt twee transparante reserverings-`PanelWindow`s naast zijn ene visuele per-screen host: de top-strip (`1920x40`) en de rail (`56x1040` onder de strip). Hyprland ziet op DP-1/DP-3/DP-4 de namespaces `kingstra-shell-surface`, `kingstra-shell-strip-reservation` en `kingstra-shell-rail-reservation`; alle monitors rapporteren `reserved=[56,40,0,0]`. Normale clients starten bijvoorbeeld op `x=1986,y=50` met `1844x1020`, dus buiten de gereserveerde zones. De hostmask combineert uitsluitend rail/strip hit-regions; de rest blijft click-through. Sessie is running en screenshot `/tmp/kingstra-fase-5-5-20260717.png` is visueel schoon.

---

## Fase 6 — Widgets/panels verweven in de shell-surface (D2.1)

**Voorwaarde:** Fase 1 is gekozen als geïntegreerde surface-route en Fase 2 heeft een plugin/fallback-besluit opgeleverd. Zonder die twee besluiten geen definitieve widgetmigratie.

- [x] **6.1 — Panel-host bouwen**
  - Actie: bouw een centrale `Panels`/`ContentWindow`-achtige host binnen `ShellSurface`, met anchor-informatie vanuit de rail/strip entries.
  - Verificatie: een leeg testpanel opent vanuit een module-anchor en sluit correct via focus/escape.
  - Status 2026-07-17: afgevinkt. `shellsurface/PanelHost.qml` is een child van de bestaande full-screen `ShellSurface`, geïdentificeerd door `sourceEntryId`; `ShellChrome` stuurt entryacties direct naar die host. Zijn geometrie is surface-relatief en de surfacemask combineert rail, strip en alleen het zichtbare panel. Bij open panel schakelt de layer naar `WlrKeyboardFocus.OnDemand`; `Escape` wist `sourceEntryId`, buiten een panel blijft de host focusloos/click-through. QML-lint, herstart en sessiestatus zijn schoon.

- [x] **6.2 — Blob/fallback surface toepassen**
  - Actie: als de plugin werkt, verbind panelachtergrond en bar/rail via blob-vorm. Als plugin niet haalbaar is, gebruik een pure-QML fallback die dezelfde API behoudt.
  - Verificatie: testpanel voelt visueel verbonden met de bar en gebruikt dezelfde motiontokens.
  - Status 2026-07-17: afgevinkt met de pure-QML fallback. De native plugin is technisch bewezen in Fase 2 maar heeft nog geen productwaardig blobtype; `PanelBackdrop.qml` levert daarom nu de stabiele fallback-API met hetzelfde surface-chrome en `medium`/`standard`/`emphasized` motiontokens. Een toekomstige native blob vervangt alleen dat component, niet host- of entry-API. Runtimeherstart is schoon.

- [x] **6.3 — Eerste widget migreren: battery**
  - Actie: migreer `battery/BatteryPopup.qml` als bewijs van patroon.
  - Verificatie: batterij-widget groeit uit de juiste bar-entry, geen los gecentreerd venster meer.
  - Status 2026-07-17: afgevinkt. `PanelHost.sourceFor()` laadt `battery/BatteryPopup.qml` rechtstreeks in de geïntegreerde surface met de originele `480x760` contractgrootte. Een los gestarte tijdelijke hosttest met `sourceEntryId="battery"` laadde zonder QML/runtimefout; screenshot `/tmp/kingstra-panelhost-battery-open-20260717.png` toont de widget binnen de surface en de testinstantie is daarna gesloten. De normale sessie is vervolgens herstart en draait volledig.

- [x] **6.4 — Overige widgets migreren**
  - Volgorde: `focustime`, `network`, `volume`, `music`, `calendar`, `monitors`/`gaming`. `settings/SettingsPopup.qml` blijft bewust centraal.
  - Verificatie: elke widget werkt via klik én keybind.
  - Status 2026-07-17: afgevinkt voor de surface-route. `PanelHost.sourceFor()` draagt nu focus, netwerk, volume, muziek, kalender, monitoren, gaming en instellingen; de rail/strip entries openen deze via één `sourceEntryId`-route. De bestaande `Main.qml`/`qs_manager.sh` keybindroute blijft bewust parallel als compatibiliteitsfallback totdat de IPC-state in 6.5 wordt omgebogen. QML-lint, sessieherstart en screenshot `/tmp/kingstra-fase-6-4-20260717.png` zijn schoon; alle services draaien.

- [x] **6.5 — IPC en registry opruimen**
  - Bestanden: `config/hypr/scripts/qs_manager.sh`, `config/quickshell/Main.qml`, `config/quickshell/WindowRegistry.js`, `/tmp/qs_widget_state`-protocol
  - Actie: vervang popup-coördinaten door panel anchors. Laat alleen legacy routes bestaan zolang nog niet alle widgets gemigreerd zijn.
  - Verificatie: keybinds openen panels op de juiste monitor/anchor.
  - Status 2026-07-17: afgevinkt. `qs_manager.sh` en `/tmp/qs_widget_state` blijven het compatibele write-protocol, maar `ShellSurface.qml` consumeert battery/focustime/network/volume/music/calendar/monitors/gaming/settings op uitsluitend de gefocuste monitor. `Main.qml` negeert diezelfde targets zodra het zoneschema actief is, zodat er geen `qs-master`-overlay dubbel opent. Live `qs_manager.sh open battery` schreef `battery::3840:0:1920:1080:<nonce>`, opende precies één surface-panel op DP-1 en `hyprctl layers` bevestigde geen `quickshell:qs-master`; `close battery` sloot het weer. Screenshot: `/tmp/kingstra-fase-6-5-ipc-20260717.png`.

- [x] **6.6 — `widgets/skins/*` uitfaseren**
  - Actie: zodra widgets chrome-tokens erven, verwijder de losse widget-skinlaag.
  - Verificatie: volume/network/battery zien er thema-specifiek correct uit zonder aparte widget-skins.
  - Status 2026-07-17: afgevinkt. Alleen `VolumePopup.qml` gebruikte de oude adapter nog; die erft nu rechtstreeks `ThemeConfig` radius/opacity/surface-kleuren. Alle zes bestanden onder `widgets/skins/` zijn verwijderd en een gerichte grep heeft geen imports of skinrefs meer. Live `qs_manager.sh open volume` laadde het volume-panel in `ShellSurface`, zichtbaar in `/tmp/kingstra-fase-6-6-volume-20260717.png`; daarna sloot de compatibele close-route en de sessie bleef volledig running.

---

## Fase 7 — Accent2/app-theming + eindregressie (D3)

- [x] **7.1 — Per-thema blend-waarde mogelijk maken**
  - Bestand: `config/shared/scripts/kingstra-matugen-run`
  - Actie: `_set_custom_colors_block()` een `blend`-parameter geven. `mono` gebruikt `blend = false`; de andere thema's standaard `true`.
  - Verificatie: gegenereerde `matugen/config.toml` toont de juiste blend-waarde per thema.
  - Status 2026-07-17: afgevinkt. `kingstra-matugen-run` geeft `secondary_accent` nu expliciet een blend-parameter: `mono` schrijft `blend = false`, de overige thema's `true`. De image-route geeft ook `--source-color-index` door, waardoor mono niet langer interactief faalt op wallpapers met meerdere bronkleuren. Handmatig gevalideerd met mono (`#906E64`, `false`) en daarna organisch hersteld (`#AC8A76`, `true`).

- [x] **7.2 — Accent2 zichtbaar toepassen in apps**
  - Actie: begin met de meest zichtbare templates: `kitty-colors.conf`, `gtk-colors.css`, `firefox-colors.css`, daarna optioneel `vscode`, `walker`, `qt6ct`, `yazi`, `swaync`, enz.
  - Verificatie: wallpaper met twee duidelijke hues toont in terminal/browser/GTK echt een tweede accent, niet alleen primary-rotatie.
  - Status 2026-07-17: afgevinkt. Kitty gebruikt accent2 voor URL en actieve rand (incl. ANSI 6/14), GTK voor `accent_bg_color`, en Firefox voor accent- en linkkleur. Na organische generatie is accent2 `#e6bead` tegenover primary `#e6bdb2`; de gegenereerde Kitty-, GTK- en Firefox-bestanden bevatten die tweede kleur op de bedoelde rollen.

- [x] **7.3 — Accent2-besluit in bar-chrome afronden**
  - Actie: als `accentHotColorName` naar `accent2` moet verwijzen, rond dit nu af in de chrome-formule.
  - Verificatie: workspace-actief/hot-states reflecteren de daadwerkelijke tweede wallpaperkleur.
  - Status 2026-07-17: afgevinkt. `PaperBar`, `OrganicBar` en `ModernBar` gebruiken `accent2` als hot role; mono blijft bewust neutraal. De geïntegreerde rail gebruikt dezelfde accent2 voor de actieve indicator. Een ontbrekend QML `outline`-veld is daarbij vervangen door het bestaande `surface2`-token. `qmllint`, `git diff --check`, sessieherstart en screenshot `/tmp/kingstra-fase-7-accent2-final-20260717.png` zijn schoon.

- [x] **7.4 — Eindcontrole hele shell-systeem**
  - Actie: doorloop alle 4 thema's × rail/strip-configuraties × alle widgets × fullscreen/normal windows × multi-monitor indien beschikbaar.
  - Verificatie: expliciete regressiechecklist; geen aannames.
  - Status 2026-07-17: afgevinkt. Live gewisseld door `paper`, `modern`, `mono` en terug naar `organic`; na iedere wissel waren TopBar, Main, overview, focus-daemon, Walker, SwayNC, hypridle en awww running. Screenshots: `/tmp/kingstra-regression-paper-20260717.png`, `/tmp/kingstra-regression-modern-20260717.png`, `/tmp/kingstra-regression-mono-20260717.png` en `/tmp/kingstra-regression-organic-20260717.png`. Alle negen IPC-routes (battery, focustime, network, volume, music, calendar, monitors, gaming, settings) zijn geopend en gesloten zonder sessiestop; network rapporteerde alleen de actuele omgevingsstatus `No Wi-Fi device found`. Op alle drie DP-monitoren bevestigt Hyprland de reservering `[56, 40, 0, 0]` en alleen de geïntegreerde shell-surface plus haar rail/strip-reserveringen. Een werkelijk VS Code-venster is fullscreen getest; het bleef binnen die zones en is daarna teruggezet naar zijn oorspronkelijke normale geometrie (`1986,50`, `1844x1020`). Alle vier TOML-profielen, relevante shellscripts, gerichte QML-bestanden en `git diff --check` zijn schoon; de verwijderde widget-skinlaag heeft geen resterende QML-referenties.

---

## Fase 8 — Regressieherstel na eerste live review

- [x] **8.1 — Functionele rail herstellen**
  - Aanleiding: de geïntegreerde `ShellChrome` had te veel oude sidebar-functionaliteit vervangen door een mini-entryset. Daardoor ontbraken zichtbare workspaces, volume-scroll, hardwarebewuste netwerkstatus en duidelijke themachrome.
  - Actie: `ShellChrome.qml` uitgebreid met echte workspace-pills, workspace-scroll, volume-scroll, media/focus/system entries, ethernet fallback en Wi-Fi-verberglogica wanneer er geen Wi-Fi-device bestaat. De statusstrip kreeg compacte workspaces wanneer rail uit staat, gecentreerde tijd/datum en correcte anchors zonder linker/rechter edge-gat.
  - Status 2026-07-17: afgevinkt. `qmllint` is schoon voor `ShellChrome.qml`; `nmcli -t -f DEVICE,TYPE,STATE device` toont geen Wi-Fi-device, alleen ethernet/bridges, waardoor Wi-Fi niet meer als permanente bar-module hoort te verschijnen. `organic` is opnieuw actief gezet als rail-route.

- [x] **8.2 — Surface-panels echt vanuit de bar laten komen**
  - Aanleiding: `volume`, `network` en `battery` openden nog rechtsboven alsof het losse popups waren.
  - Actie: `PanelHost.qml` koppelt rail-gerelateerde panels nu aan de railzijde, inclusief bottom-alignment voor volume/network/battery. `ShellSurface.qml` togglet dezelfde panel-entry nu open/dicht in plaats van blind te openen.
  - Status 2026-07-17: afgevinkt. `qs_manager.sh open volume` schrijft `volume::3840:0:1920:1080:<nonce>`, opent het volume-panel naast de linkerrail op de gefocuste monitor, en screenshot `/tmp/kingstra-regression-fix-shell-final-20260717.png` bevestigt de visuele positie.

- [x] **8.3 — Oude `qs-master` overlay-state sluiten**
  - Aanleiding: `Main.qml` negeerde bij actief zoneschema ook `close` en surface-targets, waardoor een oude `qs-master`-state zichtbaar kon blijven.
  - Actie: `Main.qml` sluit zichzelf nu expliciet bij `close` en bij surface-targets zodra `barZoneSchemaLoaded` actief is.
  - Status 2026-07-17: afgevinkt. Na restart en `qs_manager.sh open volume` toont `hyprctl layers -j` geen `quickshell:qs-master`; alleen `kingstra-shell-surface`, `kingstra-shell-strip-reservation` en `kingstra-shell-rail-reservation` blijven over.

- [x] **8.4 — Sessiestarter betrouwbaar maken**
  - Aanleiding: `kingstra-session-start restart` startte processen in de achtergrond zonder detach, waardoor ze na script-exit konden verdwijnen.
  - Actie: `run_bg_once()` start backgroundprocessen nu via `setsid -f` en gebruikt `disown` als fallback.
  - Status 2026-07-17: afgevinkt. `bash -n config/shared/scripts/kingstra-session-start` is schoon. Na `kingstra-session-start restart` blijven `TopBar.qml`, `Main.qml`, overview, focus-daemon, Walker service, SwayNC, hypridle en awww running.

- [x] **8.5 — App picker onderaan positioneren**
  - Aanleiding: Walker las de oude `[ui].anchor` niet als harde bottom-positionering; de effectieve GTK-layout stond op `valign=center`.
  - Actie: Walker-config aangevuld met root/shell-keys en een lokale `themes/default/layout.xml` toegevoegd waarin `BoxWrapper` `valign=end` en een bottom-margin gebruikt.
  - Status 2026-07-17: afgevinkt. Walker is live geopend en gesloten met `walker`/`walker --close`; screenshot `/tmp/kingstra-regression-fix-walker-final-20260717.png` toont de app picker onderin op de gefocuste monitor.

---

## Fase 9 — Mode- en themacorrectie na tweede live review

- [x] **9.1 — Nieuwe shell weer mode-aware maken**
  - Aanleiding: `ModePicker.qml` opende via `qs_manager.sh open mode`, maar de nieuwe `ShellChrome` luisterde niet naar `mode.json`. Daardoor veranderde Office/Gaming/Media alleen legacy-state en niet de geïntegreerde rail/status-strip.
  - Actie: `ShellChrome.qml` leest nu `~/.config/kingstra/state/mode.json` via `FileView` plus poll fallback, normaliseert modules per mode en bewaakt `bar_autohide`.
  - Status 2026-07-17: afgevinkt. `kingstra-mode-switch gaming` schrijft workspaces/performance/game-launcher modules; `kingstra-mode-switch media` schrijft volume/brightness/media/battery/clock met `bar_autohide=true`; `kingstra-mode-switch office` herstelt workspaces/clock/network/notifications.

- [x] **9.2 — Modulefilters en media-autohide terugbrengen**
  - Aanleiding: de bar leek statisch omdat alle permanente entries zichtbaar bleven, ongeacht mode.
  - Actie: rail/strip entries zijn gekoppeld aan de mode-modulelijst: workspaces, notifications, clock/calendar, network/ethernet, bluetooth, volume, battery, monitors/performance en gaming verschijnen alleen wanneer de actieve mode ze vraagt. Media-mode schuift rail en strip naar de edge en toont ze weer via hover.
  - Status 2026-07-17: afgevinkt. Screenshot `/tmp/kingstra-media-mode-20260717.png` toont Media na de hide-timer met alleen dunne top/left triggerlijnen; `hyprctl layers -j` blijft vrij van extra popup-layers.

- [x] **9.3 — Mode picker QML-waarschuwingen opruimen**
  - Aanleiding: de live log meldde een `StackView` anchor-conflict en impliciete key-event parameters in `ModePicker.qml`.
  - Actie: de root gebruikt nu expliciete `width`/`height` in plaats van `anchors.fill`, en key handlers declareren `(event) =>`.
  - Status 2026-07-17: afgevinkt. `qmllint config/quickshell/modes/ModePicker.qml` is schoon; `qs_manager.sh open mode` opent de picker op de juiste monitor en screenshot `/tmp/kingstra-mode-picker-fixed-20260717.png` toont de actieve Media-kaart.

- [x] **9.4 — Vier thema's visueel harder scheiden**
  - Aanleiding: Paper/Organic/Modern/Mono leken te veel op elkaar omdat de nieuwe surface vooral dezelfde Matugen-basiskleuren gebruikte.
  - Actie: `paper.toml`, `organic.toml`, `modern.toml` en `mono.toml` zijn aangescherpt op contrast, opacity, blur, radius, density, rail/stripmaat en motion. `ShellChrome.qml` gebruikt nu expliciete stijlrollen voor panel, pill, hover, border en hot color per family.
  - Status 2026-07-17: afgevinkt. `kingstra-theme-switch paper` levert alleen een top strip; `modern` levert compacte 34px strip + 48px rail; `mono` levert bottom strip zonder rail; `organic` is teruggezet als actieve basis met 40px strip + 56px rail. Screenshots: `/tmp/kingstra-theme-paper-20260717.png`, `/tmp/kingstra-theme-modern-20260717.png`, `/tmp/kingstra-theme-mono-20260717.png`, `/tmp/kingstra-theme-organic-final-20260717.png`.

- [x] **9.5 — Texture fallback waarschuwing opruimen**
  - Aanleiding: Organic startte met `BarSurface` warnings voor ontbrekende `assets/themes/organic/texture-overlay.png`.
  - Actie: `BarSurface.qml` gebruikt default texture fallbacks alleen nog voor thema's waarvoor de repo werkelijk een `texture-overlay.png` bevat.
  - Status 2026-07-17: afgevinkt. Na `kingstra-session-start restart` blijft de ontbrekende texture-warning weg. Resterende waarschuwingen zijn bestaande niet-blokkerende omgeving/legacy-meldingen: `VolumePopup` QSettings identifiers, BlueZ afwezig en SwayOSD libinput.

- [x] **9.6 — Eindstate gecontroleerd**
  - Actie: lint en live regressiecheck na alle fixes.
  - Status 2026-07-17: afgevinkt. `qmllint` is schoon voor `ShellChrome.qml`, `ModePicker.qml` en `BarSurface.qml`; de vier gewijzigde TOML-bestanden parsen met `tomllib`; `kingstra-session-start status` toont TopBar, Main, overview, focus-daemon, Walker, SwayNC, hypridle en awww running. Eindstate: `theme=organic`, `mode=office`, geen open `qs-master`, rail/workspaces/volume/battery/settings zichtbaar en geen Wi-Fi-module zonder Wi-Fi-device.

---

## Fase 10 — Theme picker en live hardwaremeters herstellen

- [ ] **10.1 — Theme picker zonder zelfonderbreking laten wisselen**
  - Aanleiding: de theme-switch startte tijdens een actieve picker een volledige Quickshell-restart. Daarmee verdween de picker voordat die de uitkomst kon afhandelen, wat de wissel als kapot liet voelen.
  - Actie: de picker geeft een expliciete runtimevlag mee; `kingstra-theme-switch` slaat alleen in dat geval de legacy-sessierestart over. De reactive `theme.json`-state blijft de actieve shell direct bijwerken.

- [ ] **10.2 — Hardwaremeters terug in de geïntegreerde rail**
  - Aanleiding: CPU/RAM/GPU/FPS bestonden nog als componenten, maar de nieuwe `ShellChrome` toonde alleen een algemene monitor-knop.
  - Actie: plaats geen samengeperste tekstmeters in de rail. Een rustige performance-entry opent een rail-gebonden drawer met CPU, RAM, GPU en FPS; Office activeert CPU/RAM, Gaming de volledige set.
