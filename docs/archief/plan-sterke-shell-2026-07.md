# Gedeeld motion- en chrome-tokensysteem voor de bar

## Context

Aanleiding: caelestia-shell (github.com/caelestia-dots/shell) is het voorbeeld. Wat dat project onderscheidt is niet de featureset (workspaces, tray, klok — heeft kingstra-dots al) maar een coherente motion-taal: alles morpht (positie/breedte/schaal) via dezelfde gedeelde easing-curves, en de bar-"chrome" (paneelkleuren, randen, actieve-status) is overal consistent.

Onderzoek in deze sessie (2 Explore-agents + directe code-inspectie) legde het volgende bloot in `config/quickshell/`:

- Er bestaat al een tokenlaag: `ThemeConfig.qml` (singleton) → `bar/BarSurface.qml` (`surface`-object, generieke `panelRadius`/`skinNumber()`/`skinBool()`) → `bar/skins/{Theme}Bar.qml` (6x pure-data `QtObject` met numerieke boosts). Dit ÍS het "Tokens.qml"-idee, alleen decentraal. De skins zijn dus niet het probleem.
- **Gat 1 — motion**: `ThemeConfig.motionDurationScale` kent maar 3 van de 6 daadwerkelijk gebruikte `style_profile.motion`-waarden (`gentle`, `firm`, en een nooit-gebruikte `minimal`). De 4 overige thema's (`smooth`=ocean, `float`=space, `playful`=animated, `snappy`=cyber) vallen stilzwijgend terug op modifier `1.0` — ondanks unieke labels in hun `.toml`. Erger: geen van de 7 bestanden in `bar/modules/*.qml` importeert `ThemeConfig` uberhaupt; ALLE Behavior-animaties daar (workspace-pil-breedte, scale, hover) hebben hardcoded ms-waarden en hardcoded `easing.type`. De morph die je bij caelestia ziet, bestaat dus wél in de code (`Behavior on targetWidth/scale` met `Easing.OutBack`) maar reageert nergens op het actieve thema.
- **Gat 2 — chrome**: `bar/BarContent.qml` heeft een generieke per-thema kleurmapping (`themeAccentBorderColor`, regel 64-70) — maar cyber ontbreekt daar juist in, want cyber heeft in plaats daarvan een compleet eigen, veel rijker kleurenblok (`cyberModuleColor`, `cyberModuleBorderColor`, `cyberWorkspaceActiveColor`, `cyberModuleTickColor`, tekstkleuren — regels 93-107) dat de andere 5 thema's niet hebben. Elke module gebruikt het patroon `ctx.cyberChrome ? ctx.cyberModuleColor : surface.panelColor`: cyber krijgt een volwaardige eigen identiteit, de rest valt terug op één generieke grijstint. Zelfs de "actieve workspace"-kleur staat hardcoded op `mocha.mauve` in `WorkspacesModule.qml:199`, ongeacht thema.

Doel van dit plan: beide gaten dichten via generieke, datagedreven tokens — zodat elk thema zijn eigen motion-gevoel (organisch/bouncy vs hoekig/snap) én eigen chrome-kleur krijgt, zonder dat gedeelde modules per-thema code-branches nodig hebben. Oorspronkelijke scope: alleen `config/quickshell/bar/**` — popups/widgets (`widgets/skins/*`) bleven bewust buiten dit plan. **Die afbakening is inmiddels vervallen, zie Deel D2**: de gebruiker wil de losse popups juist vervangen door widgets die verweven zijn in de bar.

Daarnaast (Deel C hieronder, al geïmplementeerd): tijdens het testen bleek de shell/terminal eentonig te ogen t.o.v. de wallpaper — dat is los van de bar-tokens en zit in de matugen-kleurpipeline zelf.

Update (Deel D hieronder): de gebruiker overweegt de huidige zes thema's (botanical/rocky/ocean/space/cyber/animated) te vervangen door vier nieuwe: **paper, organic, modern, mono** (D1). Dit vervangt de thema-namen waarop Deel A/B's tabellen nu nog zijn geschreven — Deel A/B wordt pas op de nieuwe 4 namen ingevuld, niet meer op de oude 6 (zie volgorde-besluit in Deel D). Daarnaast is de scope verbreed: losse quickshell-popups worden shell-surface-geïntegreerde uitschuif-widgets/panels (D2), en de tweede-kleur-aanpak uit Deel C wordt een kernvereiste die zich uitstrekt tot alle door matugen getinte apps, niet alleen de bar (D3).

## Deel A — Motion-tokens (duur + easing-curve per thema)

Uitbreiding van `config/quickshell/ThemeConfig.qml`:

| `motion` | thema | duration-scale | easing.type | overshoot |
|---|---|---|---|---|
| gentle | botanical | 1.08 (bestaand) | OutBack | 1.4 |
| firm | rocky | 0.78 (bestaand) | OutQuint | 0 |
| smooth | ocean | 1.00 | OutCubic | 0 |
| float | space | 1.30 | OutSine | 0 |
| playful | animated | 0.95 | OutBack | 2.2 |
| snappy | cyber | 0.65 | OutExpo | 0 |

- Vervang de huidige 3-branch switch in `motionDurationScale` (regel 84-92) door alle 6 branches hierboven.
- Voeg toe: `readonly property int motionEasingType` (switch op `styleMotion`, default `Easing.OutCubic`) en `readonly property real motionOvershoot` (1.4/2.2/0 per rij hierboven, default 0). `easing.overshoot` wordt door QML genegeerd bij niet-Back-curves, dus altijd meegeven is veilig.
- `duration(ms)` blijft in deze oorspronkelijke Deel A-opzet ongewijzigd qua signatuur. In de latere D2-herziening mag er categorie-support bijkomen, maar bestaande numerieke callers moeten backward-compatible blijven.

Refactor in `bar/modules/*.qml` (7 bestanden): voeg `import "../.."` toe (zelfde pad-conventie als `bar/effects/OceanWave.qml:2`). Vervang **alleen de vorm-bepalende** Behaviors (width/targetWidth/scale — de daadwerkelijke morph), niet elke opacity/color-fade:
- `WorkspacesModule.qml`: regel 193 (`targetWidth`), 211 (`scale`) → `ThemeConfig.duration(250)` + `easing.type: ThemeConfig.motionEasingType` + `easing.overshoot: ThemeConfig.motionOvershoot`.
- Analoog in `CenterBox.qml`, `MediaPlayerModule.qml`, `NotificationsButton.qml`, `SearchButton.qml`, `SystemElementsPill.qml`, `SystemTrayPill.qml` — alleen hun width/scale-Behaviors.
- `bar/BarContentSidebar.qml` gebruikt al `ThemeConfig.duration()` maar met hardcoded easing; de 2 resterende hardcoded `duration: 120/140` (icon-grid crossfade, rond regel 525/535) in dezelfde pas meenemen voor consistentie.

## Deel B — Generieke chrome-tokens (module-kleuren per thema)

Nieuwe properties in elk van de 6 `bar/skins/{Theme}Bar.qml`-bestanden (zelfde stijl als bestaande `panelOpacityBoost`/`cornerRadiusDelta`):
- `moduleFillColorName` / `moduleHoverFillColorName` (strings, mocha-kleursleutel): neutrale fill-rollen voor module-achtergronden. Voor cyber moet dit overeenkomen met de huidige `crust`/`surface0`-achtige fill, niet met `teal`.
- `accentColorName` (string, mocha-kleursleutel): primaire accentrol voor border/tick/occupied-workspace; oude zes-thema-voorstel was botanical=`"green"`, rocky=`"text"`, ocean=`"teal"`, space=`"mauve"`, animated=`"pink"`, cyber=`"teal"`, maar D1 vervangt dit straks door 4 nieuwe rijen.
- `accentHotColorName` (string, default = accentColorName): hot/active accentrol; cyber gebruikte hiervoor `"blue"` (matcht huidige `cyberModuleBorderHoverColor`/`cyberWorkspaceActiveColor`), maar D3 kan dit later vervangen door `accent2`.
- `textHotColorName` (string): kleur voor nadrukkelijke tekst/waarde, zodat cyber's huidige geelachtige hot-text niet per ongeluk dezelfde kleur wordt als de border.
- `chromeBorderAlphaMultiplier` (real, default 1.0): **botanical = 0.0** — behoudt bewust de huidige onzichtbare rand (regel 67 huidige code), nu als data i.p.v. losse ternary.
- `showModuleTick` (bool, default false): alleen cyber = `true` — de tick-mark blijft een bewust cyber-only vormelement (data, geen `ctx.cyberChrome`-check meer nodig).

Generieke berekening in `bar/BarContent.qml` (vervangt het cyber-only blok regel 93-107 én `themeAccentBorderColor`/`themeAccentBorderHoverColor` regel 64-78):
- `moduleColor`, `moduleHoverColor`, `moduleBorderColor`, `moduleBorderHoverColor`, `moduleTickColor`, `workspaceActiveColor`, `workspaceOccupiedColor`, `textColor`, `textMutedColor`, `textHotColor` worden generiek berekend, maar **niet allemaal uit dezelfde accentkleur**. Cyber gebruikt vandaag `mocha.crust`/`mocha.surface0` voor module-fill en `teal`/`blue` alleen voor border/tick/workspace-hot; een formule die alles via `accentColorName` laat lopen kan cyber dus niet exact reproduceren. Voeg daarom aparte skin-rollen toe waar nodig: bv. `moduleFillColorName`, `moduleHoverFillColorName`, `accentColorName`, `accentHotColorName`, `textHotColorName`, plus alpha/boost-waarden.
- Basis-alpha's blijven wel uit cyber's bestaande hardcoded waarden komen (0.12/0.26/0.34/0.62/0.58/0.88/0.10), maar worden per rol toegepast: fill-alpha op fill-kleuren, border/tick/workspace-alpha op accentkleuren.
- **Verificatie tijdens implementatie**: reken na dat de formule voor het thema dat cyber vervangt exact dezelfde kleuren teruggeeft als de huidige hardcoded cyber-waarden — geen visuele regressie voor het enige thema dat al chrome had. Dit lukt alleen als fill- en accentrollen gescheiden blijven.
- `mocha["naam"]`-bracket-toegang op een QML `Item`/`QtObject` met `property color`-velden werkt via het Qt-metaobjectsysteem; dit patroon komt nog nergens in de repo voor, dus na implementatie kort visueel controleren (zie Verificatie). Gebruik niet direct `surface.skin.accentColorName` zonder null/fallback-check: voeg in `BarSurface.qml` een `skinString(name, fallbackValue)`-helper toe naast `skinNumber()`/`skinBool()`.

Refactor in de 7 modules: vervang elke `ctx.cyberChrome ? ctx.cyberModuleXxx : surface.panelXxx`-ternary door het ongeconditioneerde `ctx.moduleXxx`. Tick-zichtbaarheid wordt `visible: surface.skinBool("showModuleTick", false)` of een `ctx.showModuleTick` wrapper in plaats van `visible: ctx.cyberChrome`; niet direct `surface.skin.showModuleTick` lezen zonder null-check.

## Uitvoeringsvolgorde Deel A/B (kleinste veilige stappen eerst)

1. **Deel B, alleen `WorkspacesModule.qml`** — kleur is risicoarmer en makkelijker visueel te verifiëren dan motion. Bewijst het patroon voordat je het overal toepast.
2. **Deel A, alleen `WorkspacesModule.qml`** — motion-tokens op hetzelfde bestand.
3. Zodra beide zichtbaar goed staan op alle 6 thema's: dezelfde twee refactors toepassen op de overige 6 modulebestanden + de 2 resterende hardcoded durations in `BarContentSidebar.qml`.
4. Opruimen: `themeAccentBorderColor`/`themeAccentBorderHoverColor` en het cyber-only kleurenblok in `BarContent.qml` verwijderen zodra niets er meer naar verwijst.

Dit is een bewuste, zichtbare gedragsverandering voor 4 van de 6 thema's (ocean/space/animated/cyber gaan van "stilzwijgend identiek aan default" naar hun eigen motion) en voor 5 van de 6 thema's qua chrome (workspace-actief-kleur verandert van hardcoded mauve naar het thema-accent). Dat is de bedoeling, geen bug — maar wel iets om na stap 1-2 expliciet te tonen/beoordelen voordat je doorschaalt naar de overige modules.

Status: **nog niet geïmplementeerd** — wacht bewust tot de thema-specifieke waarden (kolommen hierboven) herzien zijn.

### Kritieke bestanden Deel A/B

- `config/quickshell/ThemeConfig.qml` — motion-mapping uitbreiden
- `config/quickshell/bar/BarContent.qml` — generieke chrome-formule, cyber-only blok verwijderen
- `config/quickshell/bar/BarSurface.qml` — `skinString()` helper en content-keuze voor rail/status-strip/surface-hosts
- `config/quickshell/bar/modules/WorkspacesModule.qml` — eerste refactor (bewijs van patroon)
- `config/quickshell/bar/modules/{CenterBox,MediaPlayerModule,NotificationsButton,SearchButton,SystemElementsPill,SystemTrayPill}.qml` — zelfde refactor, stap 3
- `config/quickshell/bar/skins/{Botanical,Rocky,Ocean,Space,Animated,Cyber}Bar.qml` — nieuwe accent/chrome-properties
- `config/quickshell/bar/BarContentSidebar.qml` — resterende hardcoded durations

## Deel C — Matugen: tweede dominante tint naast de seed (geïmplementeerd)

Aanleiding: de gebruiker merkte op dat de shell/terminal eentonig oogt vergeleken met de wallpaper (bv. een fjordfoto met zowel blauw water als groen gebergte, terwijl de shell maar één tintfamilie laat zien). Root cause, bevestigd via `quickshell-colors.json`: elke "mocha"-kleurnaam (`blue`, `mauve`, `green`, `teal`, ...) is gekoppeld aan een Material You-rol (`primary`/`secondary`/`tertiary`/...container), en die rollen zijn ALLEMAAL wiskundige hue-rotaties van **één** seed-kleur die `kingstra-matugen-run` uit de wallpaper haalt (`_dominant_hex_color`, gekozen via `color_index`). Bij een terughoudend `scheme_type` (bv. botanical's `scheme-content`) is die rotatie klein, dus versmelt alles tot één tintfamilie — ongeacht welke mocha-naam een thema gebruikt.

Fix (matugen zelf blijft de bron — geen vervanging, wel verfijning): matugen ondersteunt een `[config.custom_colors]`-tabel met een `blend`-optie. Een custom color met `blend = true` wordt licht richting het schema geharmoniseerd maar behoudt zijn eigen hue — dus een ECHTE tweede, onafhankelijk bemonsterde tint uit de foto, in plaats van nog een rotatie van dezelfde seed.

### Hoe de data-flow werkt (van wallpaper tot bar)

```
wallpaper.jpg
   │  ImageMagick histogram (top-10 kleuren, gesorteerd op frequentie)
   ▼
_dominant_hex_color(image, COLOR_INDEX)        → primaire seed  (SOURCE_HEX)
_dominant_hex_color(image, COLOR_INDEX + 1)    → tweede tint    (SECONDARY_HEX)
   │
   ▼
_set_custom_colors_block() schrijft naar ~/.config/matugen/config.toml:
   [config.custom_colors]
   secondary_accent = { color = "<SECONDARY_HEX>", blend = true }
   │
   ▼
matugen (color hex $SOURCE_HEX | image $WALLPAPER) --config config.toml
   │  genereert naast primary/secondary/tertiary ook:
   │  secondary_accent, on_secondary_accent, secondary_accent_container,
   │  on_secondary_accent_container, secondary_accent_source (ongeharmoniseerde bron)
   ▼
templates renderen elk hun eigen output uit dezelfde matugen-run:
   ├─ quickshell-colors.json  → "accent2": "{{colors.secondary_accent.default.hex}}"
   │      ▼
   │  ~/.config/quickshell/colors.json  →  MatugenColors.qml (property color accent2)
   │      ▼
   │  beschikbaar in QML als `mocha.accent2` voor de bar (nog niet gebruikt, zie vervolgstap)
   │
   └─ palette-inspector.json  → 5 nieuwe rows (secondary_accent_source/secondary_accent/
          on_secondary_accent/secondary_accent_container/on_secondary_accent_container)
             ▼
          ~/.config/kingstra/state/matugen-palette.json
             ▼
          "MATUGEN TOKENS"-paneel in kingstra-skwd-wall-overlay-patch (wallpaper-picker) —
          generiek data-driven (leest gewoon de colors-array, geen hardcoded key-lijst),
          dus nieuwe rollen verschijnen daar vanzelf via de FileView-watcher zonder dat het
          overlay-bestand zelf hoeft te veranderen.
```

Geïmplementeerd in:
- `config/shared/scripts/kingstra-matugen-run` — nieuwe functie `_set_custom_colors_block()` (idempotent, sentinel-marker-based) schrijft `[config.custom_colors]\nsecondary_accent = { color = "...", blend = true }` naar `matugen/config.toml`. De hex komt uit een tweede `_dominant_hex_color`-aanroep op `COLOR_INDEX + 1` (dus een andere dominante kleur dan de primaire seed), met fallback op de primaire `SOURCE_HEX` of een neutrale grijstint als extractie mislukt — de template kan hierdoor nooit een onbekende kleur-referentie raken.
- `config/matugen/templates/quickshell-colors.json` — nieuw veld `"accent2": "{{colors.secondary_accent.default.hex}}"`.
- `config/quickshell/MatugenColors.qml` — nieuwe `property color accent2` (met FileView-uitlezing), naast de bestaande Catppuccin-achtige aliassen.
- `config/matugen/templates/palette-inspector.json` — 5 nieuwe rows zodat de tweede tint ook zichtbaar is in het bestaande "MATUGEN TOKENS"-debugpaneel (zie diagram hierboven) — zonder dit stond `accent2` alleen in `colors.json`, nergens zichtbaar tijdens het testen.

Geverifieerd: dry-run met een wallpaper met twee losse hues (blauw water + groen gebergte) gaf `source_color` (primary) als blauw-teal en `secondary_accent_source`/`secondary_accent` apart als groen/olijf — de gewenste "combi" i.p.v. één tintfamilie. Op een overwegend eenkleurige wallpaper (woestijn/rots) komt `accent2` terecht ook tan uit — correct gedrag, er is geen tweede hue om te vinden. Bevestigd door de gebruiker: de nieuwe tokens zijn zichtbaar in het "MATUGEN TOKENS"-paneel.

Belangrijk bij testen: de wallpaper-picker toont soms een hover/preview-tegel die NIET de daadwerkelijk actieve desktop-wallpaper is. Verifieer de echte actieve wallpaper met `awww query` voordat je een kleurresultaat als fout bestempelt.

Status: **geïmplementeerd en geverifieerd** (colors.json + debugpaneel). Nog niet gedaan / vervolgstap: `accent2` daadwerkelijk gebruiken in de bar-chrome-tokens uit Deel B (bv. als `accentHotColorName`-achtige tweede tint per thema) zodat de per-thema chrome ook echt de dubbele hue van de wallpaper reflecteert — dit wachtte bewust tot de gebruiker de thema-specifieke waarden zelf heeft herzien.

## Verificatie Deel A/B (nog uit te voeren)

- Geen toml/generator-wijzigingen nodig; puur QML in `config/quickshell/`, dus direct zichtbaar na een Quickshell-herstart (herinnering: Quickshell zelf herstarten is Claude's taak, betrouwbaar via `setsid nohup`, niet aan de gebruiker overlaten).
- Na stap 1-2: `kingstra-theme-switch cyber` en daarna elk overig thema doorlopen, telkens de workspace-pil bekijken (hover + klik tussen workspaces) — met een grim/slurp-screenshot vergelijken vóór/na per thema, zoals eerder in dit project gedaan voor UI-bugs.
- Expliciet controleren dat cyber's tick-mark en kleuren pixel-voor-pixel ongewijzigd blijven (enige thema met bestaande chrome — regressiegevoelig), en dat botanical geen rand krijgt (de `chromeBorderAlphaMultiplier: 0.0`-afspraak).
- Na stap 3: dezelfde visuele check herhalen voor de overige 6 modules op minstens 2 thema's (bv. rocky voor "hard/snappy" en space voor "float/zwevend") om te bevestigen dat het motion-verschil ook echt voelbaar is, niet alleen numeriek correct.

## Deel D — Thema-migratie + structurele verbreding

Aanleiding: naast de migratie van zes naar vier thema's (**paper, organic, modern, mono**) bracht de gebruiker twee extra wensen in die hier bewust samen worden uitgewerkt omdat ze elkaar raken:

- **D1** — de thema-migratie zelf (oorspronkelijke Deel D-inhoud).
- **D2.0** — de bar moet "sterk" zijn: een horizontale (top/bottom) én verticale (side) bar tegelijk kunnen tonen, elk met een zelf te kiezen kant, in plaats van vandaag's "kies er 1".
- **D2.1** — de losse quickshell-popups (volume, netwerk, batterij, kalender, muziek, focustime, monitors) vervangen door uitschuif-widgets/panels die zichtbaar uit de shell-surface/bar-rand groeien — op de settings-popup na, die blijft een eigen centraal venster.
- **D3** — `accent2`/multi-kleur-theming (Deel C) is geen "vervolgstap" meer maar een kernvereiste, en moet verder reiken dan alleen de bar: naar alle apps die matugen al themt.

**Nieuw volgorde-besluit na Caelestia-benchmark: architectuur eerst.** De beste route is niet om eerst twee losse bars te bouwen en daarna widgets eraan vast te plakken. Dat levert functioneel snel resultaat op, maar maakt het moeilijker om later het echte caelestia-gevoel te krijgen. De nieuwe prioriteit:

1. **Shell-surface + plugin haalbaarheid**: bewijs eerst dat kingstra-dots één per-screen shell-surface kan dragen waarin bar(s), panels/widgets, masks, interaction-zones en focus-grab samen leven. Bewijs daarnaast dat een native Qt Quick-plugin laadbaar is.
2. **Gedeelde tokens**: bouw daarna één semantisch motion/chrome/spacing-tokenfundament, backward-compatible met de huidige QML.
3. **Thema-migratie 6 → 4**: pas de vier nieuwe identiteiten toe op dat fundament, niet op de oude losse bar-architectuur.
4. **Geïntegreerde bar/panels**: bouw het eindbeeld als één primary rail + subtiele horizontale status-strip binnen dezelfde shell-surface, niet als twee permanente onafhankelijke `PanelWindow`s.
5. **Widgets + app-theming**: migreer popups naar bar-verweven panels en rol `accent2` daarna breed uit naar apps.

De oude D2.0-dual-bar blijft alleen waardevol als spike of tijdelijke fallback. Het einddoel wordt een geïntegreerde shell-surface.

### D1 — Thema-migratie 6 → 4 (ontwerp)

Vier scherpere, tijdlozere identiteiten vervangen de huidige zes (botanical, rocky, ocean, space, cyber, animated). Dit vervángt de bestaande set — geen toevoeging. Matugen blijft de kleurbron voor alle vier (geen wijziging nodig, `scheme_type` is toch al een simpele per-thema instelling).

#### Ontwerpvoorstel per thema

| thema | karakter | motion | easing / overshoot | scheme_type | vorm-taal |
|---|---|---|---|---|---|
| **paper** | mat, warm-neutraal, alsof er vellen op elkaar liggen | traag uitdovend, geen bounce (papier stuitert niet) | `OutQuad`, duration-scale ~1.15 | `scheme-fidelity` — blijft dicht bij de echte wallpaperkleur, "eerlijke inkt op papier" | gematigde ronding (index-kaart), brede zachte schaduw i.p.v. blur |
| **organic** | opvolger van botanical+ocean samen: vloeiend, natuurlijk | bouncy | `OutBack`, overshoot ~1.8, duration-scale ~1.05 | `scheme-content` of `scheme-tonal-spot` | asymmetrische, grote ronding, blob-vormen; bestaand glow/wave-effect generieker hergebruikt |
| **modern** | strak maar niet hard, hoge informatiedichtheid | snel, precies, geen bounce | `OutCubic`/`OutQuint`, duration-scale ~0.85 | `scheme-vibrant` of `scheme-expressive` voor heldere, doelbewuste accentkleur | gematigde ronding (8–12px), geen particles/ornamenten |
| **mono** | grijswaarden als basis, één bewuste kleurpop | minimaal, bijna instant, geen bounce | `Linear`/`OutQuad`, duration-scale ~0.6 | `scheme-monochrome` (wat rocky nu al gebruikt) | strak, functioneel, geen ornamenten |

**Bijzonderheid mono + Deel C**: zet voor dit thema de `secondary_accent` custom color (Deel C) op **`blend = false`** in plaats van `true`, zodat die ene kleur zijn volle, ongeharmoniseerde verzadiging behoudt tegen een verder grijswaarden-UI — één bewuste, herkenbare kleurpop uit de wallpaper zelf, i.p.v. een gemiddeld gerotate tint. Dit vereist dat `_set_custom_colors_block()`/de template-mapping een per-thema `blend`-waarde kunnen krijgen (nu hardcoded `true`).

#### Migratie-omvang D1 (6 → 4 is een vervanging, geen toevoeging)

- `config/kingstra/themes/{botanical,rocky,ocean,space,cyber,animated}.toml` → vervangen door `paper.toml`, `organic.toml`, `modern.toml`, `mono.toml`.
- `config/quickshell/bar/skins/{Botanical,Rocky,Ocean,Space,Animated,Cyber}Bar.qml` → 4 nieuwe skin-bestanden.
- `config/quickshell/bar/effects/*.qml` (7 bestanden) → herzien welke effecten per nieuw thema passen (bv. organic hergebruikt een gegeneraliseerde glow/wave; paper/modern/mono hebben waarschijnlijk geen of een zeer subtiel effect).
- `config/kingstra/themes/previews/*.jpg` → 4 nieuwe preview-afbeeldingen.
- Harde thema-naam-checks die herzien moeten worden (gevonden via eerdere Explore-agent): `bar/BarShell.qml`, `bar/BarSurface.qml`, `bar/BarContent.qml`, `bar/BarContentSidebar.qml`, `volume/VolumePopup.qml` (widget-skin-keuze), `clock/DigitalClock.qml`, `clock/AnalogClock.qml`, `themes/ThemePicker.qml`, `settings/SettingsPopup.qml`.
- `DEFAULT_THEME="botanical"`-achtige fallbacks in scripts (o.a. `kingstra-matugen-run`).
- Bestaande gebruikersstate (`config/kingstra/active-theme`, `state/theme.json`) verwijst mogelijk nog naar een oude naam — migratiepad nodig (bv. eenmalige remap oude→nieuwe naam, of gewoon terugvallen op het nieuwe default-thema).
- `widgets/skins/*` (6 bestanden) en de per-thema popup-varianten (`BatteryPopupAlt.qml`, `NetworkPopupAlt.qml`) → **niet migreren naar de nieuwe 4 thema's.** D2 hieronder vervangt het hele popup-systeem waar deze bij horen; ze eerst 6→4 overzetten en ze vervolgens weggooien voor D2 is dubbel werk.

### D2.0 — Bar-architectuur: geïntegreerde shell-surface met rail + status-strip

Aanleiding: de gebruiker wil niet langer kiezen tussen een top/bottom-bar Óf een side-bar — beide moeten **tegelijk** kunnen bestaan, met de kant (boven/onder, links/rechts) apart instelbaar per oriëntatie. Na vergelijking met caelestia is de beste eindroute aangescherpt: niet twee losse `PanelWindow`-bars, maar één per-screen shell-surface waarin een verticale primary rail en een horizontale status-strip samen met panels/widgets leven.

Huidige situatie (geverifieerd): er bestaat precies **één** bar-instantie per scherm. `TopBar.qml` instantieert één `BarShell {}`; `bar/BarShell.qml:13-30` gebruikt `Variants { model: Quickshell.screens }` om per scherm één `PanelWindow` te maken, en de oriëntatie van díe ene instantie komt volledig uit één enkele waarde: `ThemeConfig.barPosition` (`barPositionNormalized`, regel 48-58). `BarContent.qml` (horizontale layout) en `BarContentSidebar.qml` (verticale layout) zijn bovendien geen complementaire helften — beide renderen vandaag onafhankelijk van elkaar **dezelfde volledige moduleset** (workspaces, clock, tray, status-pills, media), alleen anders gerangschikt. Twee bars tegelijk tonen zonder verdere aanpassing zou dus alles dubbel laten zien.

Wat dit vereist:
- **Nieuwe shell-surface laag**: introduceer een per-screen surface, voorlopig `ShellSurface`/`Panels` genoemd, analoog aan caelestia's `Drawers.qml` + `ContentWindow.qml`. Deze surface bevat rail, status-strip, panel/widget-host, interaction zones, focus-grab en masks/regions.
- **`ThemeConfig.qml` + generator/state-flow**: `barPosition` (één string) vervangen door een config die twee onafhankelijke onderdelen beschrijft, bv. `barRailEnabled` + `barRailEdge` ("left"/"right") + `barStatusStripEnabled` + `barStatusStripEdge` ("top"/"bottom"). Legacy `barHorizontal*`/`barVertical*` mag als tijdelijke naam in een spike, maar het eindmodel moet semantisch rail/status-strip zijn. `theme.json`, `kingstra-theme-switch` en settings moeten hierop mee.
- **Bar-content wordt entry-based**: `BarContent.qml` en `BarContentSidebar.qml` blijven niet als twee volledige parallelle bars bestaan. Modules worden entries met een gewenste zone (`rail`, `strip`, later eventueel `both`) zodat moduleverdeling data-driven wordt.
- **Exclusive-zone en masks worden surface-verantwoordelijkheid**: niet twee onafhankelijke windows die elk hun eigen reserve-ruimte proberen te claimen, maar één surface die de gereserveerde randen en input/mask-regio's consistent beheert. Een tijdelijke dual-PanelWindow-spike mag dit onderzoeken, maar is niet het einddoel.
- **`settings/SettingsPopup.qml`**: UI-toggle nodig voor "welke bar(s) aan, welke kant" — vandaag is daar vermoedelijk maar één bar-positiekiezer.
- **Compatibele consumenten van `ThemeConfig.barPosition`**: `Main.qml`/`WindowRegistry.js` (popup-layout), `volume/VolumeBarPopup.qml` en settings/theme-editor code lezen nog het oude ene veld. `barPosition` moet daarom tijdelijk blijven bestaan als legacy/effective property, of deze consumenten moeten tegelijk naar de nieuwe rail/status-strip-config worden gemigreerd.

Status: eindrichting gewijzigd. D2.0 is niet meer "bouw twee bars"; het is "bouw één geïntegreerde shell-surface met rail + status-strip". De oude dual-bar-implementatie is alleen nog een fallback/spike als de surface-aanpak blokkeert.

### D2.1 — Uitschuif-widgets verweven in de bar (vervangt losse popups, op settings na)

Gekozen mechanisme: **een paneel dat vanuit de aanklikbare module in de bar naar buiten groeit** — geen los, gecentreerd venster meer, maar een surface die zichtbaar bij de pil hoort die je aanklikt. De gebruiker koos hier bewust voor caelestia-niveau i.p.v. een pure-QML-benadering: dat betekent inclusief een **gecompileerde native Qt-plugin** voor de vloeiende bar↔paneel-verbinding, niet alleen het generaliseren van de bestaande (zelf als "slap" ervaren) sidebar-drawer.

Bestaande kingstra-dots-infrastructuur die hierbij hoort te vervallen/gemigreerd wordt (niet als basis om op te bouwen — zie waarom hieronder):
- `bar/BarShell.qml:66` (`sidebarDrawerWidth`) en `bar/BarShell.qml:74` (`barThickness` groeit met `sidebarDrawerWidth` zodra `sidebarDrawerOpen`) — bestaat al, maar alleen voor `animatedVerticalBar`, en is precies het mechanisme dat nu "slap" aanvoelt.
- `bar/BarContentSidebar.qml:18-23` (`compactAnimatedSidebar`, `expandAllowed`, `hoverExpandedWidth`) — toont nu alleen workspace-previews, geen widget-content.
- Huidige popup-architectuur: één centrale `PanelWindow` in `Main.qml` (WlrLayer.Overlay), content geswitcht via `/tmp/qs_widget_state` + `hypr/scripts/qs_manager.sh toggle <target>`. Positie/afmetingen komen uit `WindowRegistry.js` (`getLayout(name, ..., ThemeConfig.theme, ThemeConfig.barPosition)`), dus die registry moet mee zodra widgets vanuit een bar-module groeien in plaats van uit een los popup-coordinaat. Kleurenpalet komt al overal uit `MatugenColors`; alleen Volume gebruikt daarnaast `widgets/skins/*`.
- `volume/VolumeBarPopup.qml` is geen gewone centrale popup maar een aparte `PanelWindow` per scherm die ook direct `ThemeConfig.barPosition` gebruikt; die moet in D2.0/D2.1 apart worden gemigreerd of expliciet uitgezonderd.

Te vervangen popups (op settings na): `battery/{BatteryPopup,BatteryPopupAlt}.qml`, `focustime/FocusTimePopup.qml`, `network/{NetworkPopup,NetworkPopupAlt}.qml`, `volume/{VolumePopup,VolumeBarPopup}.qml`, `calendar/CalendarPopup.qml`, `music/MusicPopup.qml`, `monitors/{GamingPopup,MonitorPopup}.qml`. `settings/SettingsPopup.qml` blijft een eigen centraal venster.

#### Wat caelestia daadwerkelijk doet (geverifieerd tegen de bron op GitHub, niet alleen het eindresultaat)

- `plugin/src` + `plugin/CMakeLists.txt` in `caelestia-dots/shell`: een gecompileerde Qt Quick-plugin (`import Caelestia.Blobs`), geen QML-truc. `modules/drawers/ContentWindow.qml` gebruikt een gedeelde `BlobGroup` plus per paneel een `PanelBg`/`BlobRect` met een `deformAmount`/`deformMatrix` — bar en open paneel zijn zo letterlijk **één vervormbare metaball-vorm**, geen twee losse rects die toevallig samen bewegen. Dát is de kern van het "verfijnde" gevoel, niet de content die erin staat.
- `components/Anim.qml`: één centraal, semantisch motion-vocabulaire (Material Design 3 Expressive Motion) — categorieën `Standard{Small,Normal,Large,ExtraLarge}`, `Emphasized*`, en een `Spatial`-vs-`Effects`-onderscheid. Thema-verschil zit bij caelestia in kleur/vorm, niet in een andere curve per thema.
- `modules/drawers/`, `modules/sidebar/`, `modules/dashboard/`: dashboard, launcher, session, sidebar, osd, notifications, utilities én popouts zijn gelijkwaardige onderdelen van één `Panels`/`ContentWindow`/`Interactions`/`ScreenState`-systeem — geen losse ad-hoc bestanden per feature zoals nu `volume/VolumePopup.qml`, `network/NetworkPopup.qml`, etc.

#### Consequentie: nieuwe infrastructuur-laag voor kingstra-dots

`kingstra-dots` is vandaag 100% declaratieve QML/config — geen enkel `.cpp`/`CMakeLists.txt`-bestand in de repo (gecontroleerd). Een blob-plugin zoals caelestia's voegt een **compileerstap** toe die er nu niet is:

- Nieuwe map op repo-root (net als caelestia: `plugin/src` + `plugin/CMakeLists.txt`), **niet** onder `config/quickshell/`. Belangrijk: `deploy_config "quickshell"` symlinkt alleen `config/quickshell` naar `~/.config/quickshell`; een repo-root `plugin/` wordt dus niet vanzelf mee gedeployed. Dat is gewenst. Build-output moet buiten zowel `config/quickshell/` als de plugin-bronboom blijven; alleen het eindresultaat (gecompileerde plugin + `qmldir`) wordt op een QML-importpad geïnstalleerd.
- `manifest/packages/ui.txt` uitbreiden met een build-toolchain (`cmake`, `ninja` of `make`, `base-devel` o.i.d.) — `qt6-base`/`qt6-declarative` staan er al (Arch splitst geen `-dev`-pakketten, headers zitten er al in), maar de buildtools staan nu nog niet in `manifest/packages/ui.txt`.
- `installer/phases/05_ui_quickshell.sh` krijgt een expliciete build/install-stap voor `plugin/` vóór of na `deploy_config "quickshell"`; de volgorde maakt minder uit dan het installpad. Als dit een aparte fase wordt, moet Fase 05 wel valideren dat Quickshell de plugin op runtime kan vinden.
- **Nog te verifiëren, niet aangenomen**: het exacte mechanisme waarmee Quickshell een native QML-plugin oppikt (QML_IMPORT_PATH-conventie of een Quickshell-specifieke pluginmap). Caelestia lost dit zelf op via zijn eigen CMake/Nix-build; kingstra-dots moet dit apart uitzoeken. **Dit is de eerste technische spike, vóór er QML/C++ geschreven wordt** — anders bouw je een plugin die Quickshell niet laadt.

#### Gevolg voor Deel A: motion-systeem wordt eerst herzien

Caelestia's `Anim.qml` (Material 3 Expressive) is een grondiger fundament dan Deel A's huidige voorstel (één losse `duration-scale` + `easing.type` + `overshoot` per thema). Vóór Deel A wordt geïmplementeerd: vervang die tabel door een vergelijkbaar semantisch systeem (small/normal/large/extraLarge × standard/emphasized, spatial vs. effects) dat overal hetzelfde is; per-thema identiteit (bouncy vs. snappy) wordt dan een secundaire "energie"-knop bovenop dat ene systeem, niet 6 losse curve-sets. `ThemeConfig.duration()` moet wel backward-compatible blijven met bestaande numerieke callers (`ThemeConfig.duration(300)` komt al op meerdere plekken voor); voeg categorie-support toe zonder die oude signatuur te breken, of introduceer een aparte `durationToken()`. Deel B's chrome-tokens (kleur) blijven ongewijzigd relevant — die kleuren de blob-vorm, ze concurreren niet met de vorm zelf.

Open vragen (blokkerend voor D2-implementatie, in volgorde):
1. Quickshell-plugin-laadmechanisme (zie hierboven) — spike vóór alles.
2. Pure-QML-fallback nodig voor machines waar de plugin niet compileert, of garandeert de installer altijd een succesvolle build (zoals caelestia's eigen installer/Nix-flake doet)?
3. Multi-monitor: moet een widget die via keybind opent altijd op de bar van het actieve scherm verschijnen?
4. Calendar en het monitor-overzicht hebben relatief veel content (maand-grid, multi-monitor-preview) — past dat in een "groeit uit een pil"-paneel, of hebben die twee een grotere minimum-afmeting nodig die het morph-gevoel verstoort?

Status D2: richting + niveau-ambitie nu vastgesteld: eerst shell-surface en pluginhaalbaarheid bewijzen, daarna pas panel/widget-QML bouwen. De eerste concrete stappen zijn dus de shell-surface architectuurspike én de Quickshell-pluginlaad-spike, niet meteen QML-widgetwerk.

**Plugin-spike resultaat (Fase 2.5, 2026-07-17): geslaagd.** `Kingstra.Test` bouwt met Qt's standaard `qt_add_qml_module()`, installeert als dynamische QML-plugin onder `~/.local/lib/qml/Kingstra/Test/`, en laadt in een los Quickshell-proces met `QML_IMPORT_PATH=/home/joris/.local/lib/qml`. Quickshell meldt `Configuration Loaded`; Hyprland registreerde de test-`PanelWindow` op de overlaylaag (`240x160`). De tijdelijke screenshot was niet betrouwbaar als pixelbewijs doordat een bestaande gelijktijdige overlay het actieve scherm bedekte, maar er was geen `module not found`, plugin-load- of QML-typefout. Route A houdt daarom een native plugin als standaard voor blob/morphing; de pure-QML-variant blijft alleen een productfallback voor hosts zonder buildtoolchain.

**Plugin-installcontract (Fase 2.6, 2026-07-17):** benodigd op Arch zijn `cmake`, een C++-toolchain (`base-devel`, of minimaal `gcc` + `make`), en `qt6-base` + `qt6-declarative`; `ninja` is optioneel maar gewenst als generator. De spike bouwde met CMake/Make en Qt 6.11.1. Installatiepad: `/home/joris/.local/lib/qml/Kingstra/<Module>/`; runtimevariabele: `QML_IMPORT_PATH=/home/joris/.local/lib/qml`. Bij productisering moet één gedeelde Quickshell-launch-wrapper deze variabele leveren aan `kingstra-session-start`, `kingstra-theme-switch`, `resume-fix.sh` en `qs_manager.sh`. Pas daarna wordt het UI-manifest/installscript aangepast, met een buildmap buiten de repo-configboom.

### Tokencontract (Fase 3.1)

| tokenfamilie | eigenaar | API / waarden | fallback | eerste gebruiker |
|---|---|---|---|---|
| motion duration | `ThemeConfig.qml` | bestaande `duration(ms)` blijft; nieuw `durationToken("fast"|"medium"|"slow"|"spatial")` | huidige numerieke duur | `WorkspacesModule.qml` |
| motion easing | `ThemeConfig.qml` | semantische `easingToken("standard"|"emphasized"|"effects")`; callers krijgen de Qt-easing enum | `Easing.OutCubic` | `WorkspacesModule.qml` |
| spacing | `ThemeConfig.qml` | `spacingToken("tight"|"normal"|"loose")` in ongeschaalde dp; consumer past `shell.s()` toe | 4 / 8 / 12 | `BarContent.qml` en rail/strip |
| component geometry | `BarSurface.qml` | panel- en pill-radius plus toekomstige module-padding | huidige `styleWidgetRadius`, skin-delta | `WorkspacesModule.qml` |
| chrome fill/border | `BarSurface.qml` | `skinString()` naast bestaande `skinNumber()`/`skinBool()`; rollen `moduleFillColorName`, `moduleHoverFillColorName`, `chromeBorderAlphaMultiplier` | huidige panel/inner-pill formule | `WorkspacesModule.qml` |
| accent/text hot | skinbestand | `accentColorName`, `accentHotColorName`, `textHotColorName`, `showModuleTick` | huidige Mocha-keuzes per module | cyber-equivalent in `WorkspacesModule.qml` |
| theme-effecten | skinbestand | bestaande effectflags, cycles en boosts | huidige skinproperties | `BarSurface.qml` |

De grens is bewust scherp: `ThemeConfig` bezit tijd, easing en globale spacing; `BarSurface` vertaalt dat naar gedeelde chrome-geometrie; skins kiezen alleen uiterlijk en effectflags. Modules mogen na Fase 3 geen eigen kleurrol of nieuwe magische motionduur introduceren.

### D3 — Multi-kleur-theming als kernvereiste (was Deel C's "vervolgstap")

De gebruiker: matugen voelt te generiek omdat alles op één seed-kleur is gebaseerd, en het thema moet overal doorschijnen — apps, widgets, de bar. Deel C loste dit al op voor de bar (`accent2` in `quickshell-colors.json`/`MatugenColors.qml`), maar dat dekt niet "overal": gecontroleerd via grep op `config/matugen/templates/*` — geen van de overige templates gebruikt `secondary_accent`/`accent2`.

| template | app-oppervlak | huidige kleurbron |
|---|---|---|
| `gtk-colors.css` | GTK-apps | 36 kleurverwijzingen, uitsluitend primary-rotatie |
| `kitty-colors.conf` | terminal | 32 kleurverwijzingen, uitsluitend primary-rotatie |
| `firefox-colors.css` | browser | 80 kleurverwijzingen, uitsluitend primary-rotatie |
| `qt6ct-colors.conf` | Qt-apps | 3 kleurverwijzingen, uitsluitend primary-rotatie |
| `vscode-colors.json`, `walker-colors.css`, `yazi-theme.toml`, `spicetify-*`, `swaync-colors.css`, `cava-colors.conf`, `btop-colors.toml`, `hyprlock.conf`, `sddm-colors.qml`, `zsh-omp-colors.toml` | editor/launcher/bestandsbeheer/notificaties/audio-viz/systeemmonitor/lockscreen/login/prompt | niet één voor één geteld, zelfde patroon (alleen primary-rotatie) |

Conclusie: de dekking is al breed — 17 apps/oppervlakken worden al getint, dus "meer apps themen" is niet het gat. Het gat is dat elke template nog maar één hue gebruikt. Aanpak: per template minstens één rol aanwijzen waar `accent2` de primary-rotatie vervangt of aanvult — bv. kitty/VSCode: één syntax-categorie op `accent2` i.p.v. op een primary-rotatiekleur; GTK: focus-ring/selectie-onderscheid; Firefox: één specifieke UI-rol i.p.v. de hele `--accent-color`-keten.

Rechtstreekse link met Deel B: `accentHotColorName` (Deel B, daar nu een handmatig gekozen mocha-key per thema) zou net zo goed simpelweg `accent2` kunnen zijn — dan reflecteert ook de bar-chrome de daadwerkelijke tweede wallpaperkleur i.p.v. een los ontworpen "hot"-variant. Dat besluit moet vallen vóór Deel B geïmplementeerd wordt, anders wordt de chrome-formule twee keer aangepast.

**Niet meegenomen**: fysieke RGB-verlichting op de PC zelf — door de gebruiker genoemd als "liefst ook", maar er is geen RGB-hardware aanwezig, dus dit blijft buiten scope zonder verder onderzoek.

### Gevolgen voor Deel A/B (bijgewerkt)

De motion- en accentkleur-tabellen in Deel A en Deel B zijn geschreven voor de oude zes namen. Bij implementatie van D1 worden die tabellen vervangen door 4 rijen (paper/organic/modern/mono) in plaats van 6. Deel B's generieke chrome-architectuur blijft relevant, maar de concrete formule moet fill-rollen en accent-rollen scheiden (zie Deel B hierboven) om de bestaande cyber-look exact te kunnen reproduceren. Deel A's motion-tabel wordt wél inhoudelijk herzien (zie D2-gevolg hierboven: Material-3-Expressive-achtig semantisch systeem i.p.v. 6 losse duration/easing/overshoot-sets). Extra open vraag: het D3-besluit over `accentHotColorName` (handmatige mocha-key vs. `accent2`) moet vallen vóór Deel B wordt geïmplementeerd.

### D4 — Benchmark tegen `caelestia-dots/caelestia` + `caelestia-dots/shell`

Onderzoek tegen de actuele upstream maakte één belangrijk onderscheid scherper: `caelestia-dots/caelestia` is de hoofd-dotfiles repo (Hyprland/Lua, app-configs, manifest/CLI-installatie), maar de bar/shell-finesse zit in `caelestia-dots/shell`. Voor kingstra-dots is de shell-repo de relevante benchmark voor de bar; de main repo is vooral interessant voor packaging, app-integratie en de scheiding tussen dotfiles en shell.

#### Huidige window-inventaris (Fase 1.1)

| window / entrypoint | huidig doel | layer / exclusie / input | state / IPC | toekomstige bestemming |
|---|---|---|---|---|
| `TopBar.qml` | `ShellRoot` die `BarShell {}` en `VolumeBarPopup {}` host | zelf geen window; host twee window-systemen | zet `Qt.application.organization = "kingstra-shell"` voor QML `Settings` | tijdelijk entrypoint houden; later vervangen of uitbreiden met `ShellSurface` als hoofdhost |
| `bar/BarShell.qml` | per scherm één bar-`PanelWindow` via `Variants { model: Quickshell.screens }` | anchored aan één rand op basis van `ThemeConfig.barPosition`; `exclusiveZone` reserveert bar-dikte; `mask: Region` beperkt input/paint tot barregio; geen expliciete keyboard focus | leest `settings/settings.json`, `mode.json`, Hyprland/UPower/MPRIS/Networking; barmodules togglen popups via `qs_manager.sh` | rail + status-strip moeten hieruit naar `ShellSurface`/entry-hosts migreren; `BarShell` blijft alleen fallback tijdens spike |
| `Main.qml` | centrale popup-overlay voor battery/network/calendar/music/settings/etc. | één fullscreen `PanelWindow` op actieve monitor; `WlrLayer.Overlay`; `exclusiveZone: -1`; keyboard focus `OnDemand` wanneer zichtbaar | leest `/tmp/qs_widget_state`, schrijft `/tmp/qs_active_widget`, positioneert via `WindowRegistry.getLayout(... ThemeConfig.barPosition)` | vervangen door panel-host binnen `ShellSurface`; `WindowRegistry.js` wordt legacy of anchor-resolver |
| `volume/VolumeBarPopup.qml` | aparte volume-popup naast bar, per scherm maar zichtbaar op actieve monitor | `Variants` met overlay-`PanelWindow`; focus via `HyprlandFocusGrab`; anchors/margins direct afhankelijk van `ThemeConfig.barPosition` | `IpcHandler target: "volume"` met `toggle/open/close` | apart migreren naar panel-host; niet vergeten omdat dit buiten `Main.qml` om loopt |
| `WindowRegistry.js` | popupafmetingen en absolute posities voor `Main.qml` | geen window; rekent met monitorrect + `barPosition` | layouttabel voor widgetnamen naar componentpaden | vervangen door entry-anchor/panel-layoutlogica; tijdelijk compatibel houden zolang legacy-popups bestaan |
| `overview/shell.qml` | aparte overview-shell gestart via `qs --no-duplicate` | eigen `ShellRoot`; windowdetails zitten in `overview/modules/overview` | los overview-systeem | voorlopig buiten bar-surface laten, later beoordelen of launcher/overview onder dezelfde interactionlaag moet vallen |

#### Routekeuze (Fase 1.2)

Gekozen route: **A — geïntegreerde surface eerst** (**go bevestigd in Fase 1.6 op 2026-07-17**).

Reden: de huidige inventaris laat al drie losse UI-windowfamilies zien (`BarShell`, `Main.qml` popups, `VolumeBarPopup`) plus een aparte overview-shell. Als er nu eerst twee permanente bars worden gebouwd, groeit die versnippering verder. Voor het gewenste caelestia-niveau moet eerst bewezen worden dat één per-screen `ShellSurface` rail, status-strip, panel-host, interaction-zones, masks en focus kan dragen. De oude dual-bar-route blijft alleen fallback als de Fase 1.3-spike technisch blokkeert.

Go-bewijs: `ShellSurface.qml` draait per `Quickshell.screens` op `WlrLayer.Top`, zonder keyboard focus en met een lege inputmask. Na sessieherstart stond op elk van `DP-1`, `DP-3` en `DP-4` precies één `quickshell:kingstra-shell-surface` van `1920x1080` op `y=0`; de bestaande bar bleef zichtbaar en bruikbaar. Daarmee is er geen layer-shell-, multi-monitor- of inputblokkade gevonden die route A in de weg staat. De dual-bar-route B blijft uitsluitend een hersteloptie bij een latere, concrete beperking.

#### Module-zones (Fase 1.4)

De eindsurface heeft drie semantische zones. Een entry mag hooguit in één primaire zone zitten; een compacte statusindicatie mag nooit daarnaast nog een tweede opener voor hetzelfde paneel worden. Hierdoor vervangen de huidige volledige, parallelle layouts uit `BarContent.qml` en `BarContentSidebar.qml` elkaar niet langer met duplicatie.

| entry / functie | primaire zone | huidige bron | opent / doet | besluit |
|---|---|---|---|---|
| launcher/search | primary rail | `SearchButton.qml` | Walker | rail; vaste navigatie-entry |
| workspaces | primary rail | `WorkspacesModule.qml` | workspace wisselen en scrollen | rail; centrale navigatie-entry |
| focus time | primary rail | nieuwe entry, huidige `focustime/FocusTimePopup.qml` | focus-timer-paneel | rail; bewust toevoegen, niet verstoppen tussen systeemstatus |
| media transport | primary rail | `MediaPlayerModule.qml` | play/pause/next en muziek-paneel | rail; contextuele entry, verborgen zonder speler |
| notifications | status-strip | `NotificationsButton.qml` | SwayNC overzicht / DND | strip; globale status, geen duplicate rail-knop |
| tijd, datum, weer | status-strip | `CenterBox.qml` | calendar/weer-paneel | strip; tijd is status, geen navigatie |
| system tray | status-strip | `SystemTrayPill.qml` | app-specifieke tray-menu's | strip; alleen hier |
| updates, keyboard, netwerk, bluetooth, volume, batterij, power | status-strip | `SystemElementsPill.qml` | respectievelijke paneelactie of systeemactie | strip; losse entries in de data-laag, geen monolithische pill als eindvorm |
| batterij, netwerk, volume, kalender, muziek, focus time, monitors/gaming | panel host | huidige popupbestanden + `Main.qml`/`VolumeBarPopup.qml` | groeit uit de entry uit de twee zones | geen eigen permanente barzone; elk paneel bewaart een `sourceEntryId` voor positionering en focus |

De entry-to-panel-koppeling wordt één-op-één: `focus-time -> focustime`, `media -> music`, `clock-weather -> calendar`, `network -> network`, `volume -> volume`, `battery -> battery`, `monitors -> monitors`, `gaming -> gaming`. `notifications`, `system tray`, `updates`, `keyboard`, `bluetooth` en `power` blijven directe acties totdat ze aantoonbaar een eigen paneel nodig hebben. Settings blijft buiten dit model als zelfstandig centraal venster.

#### Configschema rail + status-strip (Fase 1.5)

Nieuwe waarden leven op hetzelfde niveau als de huidige `bar_height`/`bar_position` in `theme.json`, en komen uit de `[quickshell]`-sectie van het actieve thema. De namen zijn bewust fysiek en zone-specifiek: er is geen tweede dubbelzinnige `bar_position`.

| JSON- en TOML-veld | type / geldige waarden | default voor nieuw thema | eigenaar / gebruik |
|---|---|---|---|
| `bar_rail_enabled` | boolean | `true` | maakt de primary rail aan |
| `bar_rail_edge` | `left` of `right` | `left` | ankering van de primary rail |
| `bar_rail_width` | integer, `48..128` dp | `64` | raildikte en gereserveerde rand |
| `bar_status_strip_enabled` | boolean | `true` | maakt de horizontale status-strip aan |
| `bar_status_strip_edge` | `top` of `bottom` | `top` | ankering van de status-strip |
| `bar_status_strip_height` | integer, `30..96` dp | huidige/nieuwe `bar_height` | stripdikte en gereserveerde rand |
| `bar_position` | `top`, `bottom`, `left`, `right` | `top` | uitsluitend legacy/effective fallback totdat alle oude popupconsumenten zijn gemigreerd |
| `bar_height` | integer, `30..96` dp | gelijk aan `bar_status_strip_height` | legacy fallback; nooit meer de raildikte |

Compatibiliteitsregel bij ontbrekende nieuwe velden: `bar_position=top|bottom` betekent alleen een status-strip aan die kant en geen rail; `bar_position=left|right` betekent alleen een rail aan die kant en geen status-strip. Zo blijft ieder bestaand thema visueel gelijk zolang `BarShell.qml`, `Main.qml`, `VolumeBarPopup.qml` en `WindowRegistry.js` de oude waarde nog lezen.

Als beide nieuwe zones actief zijn, blijft `ThemeConfig.barPosition` tijdelijk een afgeleide compatibiliteitswaarde: de striprand wanneer de strip bestaat, anders de railrand, anders `top`. Nieuwe code leest uitsluitend de zonevelden. Dit is nadrukkelijk tijdelijk: in Fase 5 migreren popup- en panel-ankers naar `sourceEntryId`/surface-geometrie, waarna `bar_position` niet meer voor nieuwe functionaliteit gebruikt mag worden.

Het write-pad wordt in Fase 5 in deze volgorde aangepast: thema-TOML -> `kingstra-theme-switch` -> `theme.json` -> `ThemeConfig.qml` -> `SettingsPopup.qml`. Settings toont twee onafhankelijke toggles en twee rand-kiezers; de oude enkele positiekiezer blijft alleen zichtbaar als compatibiliteitsfallback voor een oud thema zonder de nieuwe velden.

#### Ontwerpwaarden voor de vier identiteiten (Fase 4.2)

| Thema | Vorm/density | Materiaal en schaduw | Motion en accenten | Shell-zones |
|---|---|---|---|---|
| `paper` | Radius 12, comfortabel, rustige volle strip | Lichte paper-glass laag, blur 22, schaduw 0.08, duidelijke dunne rand | `calm`, geen ambient-effect; accent is subtiel en editorial | Alleen top status-strip (40 px), geen rail |
| `organic` | Radius 22-24, comfortabel/rich, zachte rail + strip | Warmere, donkerdere soft-glass laag, blur 24, schaduw 0.30, glass 0.14 | `gentle`, organische gloed/fireflies sterker zichtbaar; `accent2` als warme hot-state | Linker rail (56 px) plus top strip (40 px) |
| `modern` | Radius 3-4, compact, hard-tech | Bijna opaque, geen blur, hoge outline 0.36, minimale schaduw | `snappy`, hoog contrast, functionele teal/accent ticks | Linker rail (48 px) plus top strip (34 px) |
| `mono` | Blokvorm, compact, maximale leesbaarheid | Opaque monochroom, geen blur/glass, sterke randen, minimale gaps | `firm`, geen effecten; alleen neutrale focusrol | Alleen bottom status-strip (34 px), geen rail |

Deze waarden zijn bewust contractwaarden, geen generieke presets: de QML-skins vertalen ze straks naar concrete kleuren uit het actuele Matugen-palet. De nieuwe TOMLs bevatten daarom geen open visuele TODO's; ieder getal hierboven is nu de gecontroleerde uitgangswaarde voor de eerste runtime-iteratie.

#### Plugin-laadmechanisme (Fase 2.1)

Antwoord: **ja**. Quickshell draait een normale Qt QML-engine en kan daarom een los gecompileerde QML-extensionmodule via het standaard Qt-mechanisme laden; er is geen Quickshell-specifiek pluginpad nodig. De QML-URI bepaalt de directory onder een import-root. Voor de spike wordt dat:

```text
QML_IMPORT_PATH=$HOME/.local/lib/qml
import Kingstra.Test 1.0

$HOME/.local/lib/qml/Kingstra/Test/
  qmldir                         # module Kingstra.Test + plugin-declaratie
  libkingstratestplugin.so        # Linux plugin-binary
  kingstratestplugin.qmltypes     # toolingmetadata, gegenereerd door CMake
```

`qmldir` en de pluginbinary moeten naast elkaar in de URI-directory staan. De QML-engine zoekt de plugin daar standaard op; `qt_add_qml_module()` genereert normaal zowel `qmldir`, type-registratie als pluginbron. Dit volgt de standaard Qt-modulecontracten, niet een Caelestia-specifieke buildtruc. Bronnen: [Qt: Creating C++ Plugins for QML](https://doc.qt.io/qt-6.11/qtqml-modules-cppplugins.html), [Qt: qmldir module definition](https://doc.qt.io/qt-6/qtqml-modules-qmldir.html), [Qt: qt_add_qml_module](https://doc.qt.io/qt-6/qt-add-qml-module.html). Quickshell 0.3 ondersteunt reguliere QML-imports en gebruikt QtQuick/QML voor de configuratie: [Quickshell QML Language](https://quickshell.org/docs/v0.3.0/guide/qml-language/).

De import-root moet in de omgeving staan van **elke** Quickshell-start: `QML_IMPORT_PATH="$HOME/.local/lib/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"`. De huidige repo start TopBar niet alleen via `kingstra-session-start`, maar kan hem ook opnieuw starten vanuit `kingstra-theme-switch`, `hypr/scripts/resume-fix.sh` en `hypr/scripts/qs_manager.sh`. Fase 2.6 maakt daarom één kleine launch-wrapper of gedeelde env-helper voor al deze paden; een losse export in alleen de normale sessiestart zou herstarts stukmaken.

Wat caelestia beter doet dan het oude kingstra-plan:
- **Eén per-screen shell-surface**: `Drawers.qml` maakt per scherm één `ContentWindow`, en daarin zitten bar, dashboard, launcher, sidebar, notifications, OSD, utilities en popouts in hetzelfde coördinatensysteem. Het oude D2.0-plan maakte maximaal twee losse `PanelWindow`-bars per scherm; dat is bruikbaar als fallback, maar niet het niveau waarop panelen echt uit de bar kunnen groeien.
- **Blob-vorm als fundament, niet als decoratie**: `ContentWindow.qml` gebruikt één `BlobGroup` voor de bar-rand, panels en popouts (`PanelBg`/`BlobRect`), inclusief deform-matrix en fullscreen-maskering. Als kingstra dit effect wil benaderen, moet de native plugin vóór het echte panelontwerp bewezen worden; anders bouw je panel-layouts die later weer anders moeten.
- **Interactielaag vóór losse widgetlogica**: caelestia heeft een centrale `Interactions`-laag die hover, drag, edge-zones, focus-grab en panel-visibility stuurt. Kingstra heeft nu `qs_manager.sh` + `/tmp/qs_widget_state` + centrale popup-window; dat werkt, maar voelt eerder als losse popups dan als één shell.
- **Tokens zijn twee lagen**: upstream gebruikt base tokens (`TokenConfig`: spacing, padding, rounding, anim durations/curves, component sizes) plus appearance scale/config. Kingstra heeft al skins en `ThemeConfig`, maar mist nog één echte shared tokenlaag voor afmetingen, easing, font-schaal en component sizes.
- **Bar entries zijn data-driven**: caelestia's bar is een verticale `Bar.qml` met `Config.bar.entries` en popouts die hun anchor uit de actieve entry halen. Kingstra's oude module-verdeling was hardcoded per horizontale/verticale layout; de nieuwe route maakt daar expliciet rail/strip-entries van.

Gevolg voor de ambitie: als het doel alleen "mooier en bruikbaarder" is, kan het huidige gefaseerde plan volstaan. Als het doel "caelestia-niveau fluid/morphing shell" is, moet de prioriteit verschuiven:
1. Eerst een **shell-surface architectuurspike**: kan kingstra één per-screen fullscreen/top-layer surface met regionale masks/exclusions gebruiken, waar bar(s), panels en widgets samen in leven?
2. Dan de **native blob-plugin spike**.
3. Daarna pas rail/status-strip moduleverdeling en widgetmigratie definitief maken.

Concreet betekent dit dat de oude D2.0-dual-bar-route niet te ver moet worden uitgewerkt als twee permanente, onafhankelijke `PanelWindow`s. Behandel twee losse bars alleen als fallback/spike. Het eindbeeld voor maximale kwaliteit is één "primary rail" + één subtiele horizontale status-strip binnen dezelfde shell-surface, met gedeelde interaction/panel/blob-laag. Dat geeft meer kans op het vloeiende caelestia-gevoel dan twee losse bars die later visueel aan panelen worden gekoppeld.

#### Correctie na eerste live review (2026-07-17)

De eerste volledige surface-implementatie bewees de technische basis, maar was als UX-route te mager: `ShellChrome` had een mini-entryset gebouwd die bestaande sidebar-functionaliteit verving in plaats van te behouden. Dat is niet acceptabel als eindrichting. De beste route is daarom aangescherpt:

- De rail is een **functionele primaire navigatiezone**, niet alleen decor: workspaces, workspace-scroll, launcher, media/focus en systeemacties moeten permanent bruikbaar zijn.
- De statusstrip is een **status- en commandolaag** met gecentreerde tijd/datum en zonder randgaten. Als een thema geen rail heeft, moet de strip alsnog workspace-controls bieden.
- Panels moeten **uit hun bronzone komen**. Volume/network/battery horen naast de rail of vanuit de strip te bewegen, niet als oude rechtsboven-popups.
- De oude `qs-master` overlay mag bij actief zoneschema nooit zichtbaar blijven voor gemigreerde widgets; `Main.qml` is dan alleen compatibiliteit voor niet-gemigreerde targets.
- Walker/app picker gebruikt een eigen bottom-aligned theme-layout; de oude `[ui].anchor`-aanname is onvoldoende voor deze Walker-versie.

Deze correctie is uitgevoerd en afgevinkt als Fase 8 in `stappen.md`. De laatste live-checks tonen: alle sessiecomponenten running, `organic` actief, geen `qs-master` bij surface-panels, geen Wi-Fi-module zonder Wi-Fi-device, volume-panel naast de rail, en Walker onderin via `/tmp/kingstra-regression-fix-walker-final-20260717.png`.

#### Correctie na tweede live review: mode + theme distinctie (2026-07-17)

De tweede review legde een architectuurlek bloot: de mode picker opende wel, maar `ShellChrome` las `mode.json` niet meer. Daardoor veranderde Office/Gaming/Media de nieuwe shell niet, omdat alleen de verborgen legacy `BarShell` nog mode-aware was. De gekozen route blijft de geïntegreerde surface, maar de surface moet nu expliciet alle runtime-state consumeren die vroeger in de bar zat.

Uitgevoerd als Fase 9 in `stappen.md`:
- `ShellChrome` leest `~/.config/kingstra/state/mode.json` rechtstreeks, inclusief inode-poll fallback, modulelijst en `bar_autohide`.
- Mode modules sturen de rail/strip weer: workspaces/network/notifications voor Office, performance/game-launcher voor Gaming, compacte media/autohide voor Media.
- Media-mode schuift rail en strip naar de edge met hover-trigger in plaats van alleen modules te verbergen.
- `ModePicker.qml` is robuuster gemaakt voor `StackView` en expliciete key-event parameters.
- Paper/Organic/Modern/Mono zijn verder uit elkaar getrokken in TOML én in `ShellChrome`-kleurrollen, zodat Matugen de vier identiteiten niet visueel laat samenklonteren.
- `BarSurface` gebruikt default texture fallbacks alleen nog voor thema's waarvoor daadwerkelijk assets bestaan, zodat Organic niet met ontbrekende texture-waarschuwingen start.

Live-verificatie: `kingstra-mode-switch gaming/media/office` schrijft correcte mode-state; Media toont alleen edge triggers na autohide (`/tmp/kingstra-media-mode-20260717.png`); `qs_manager.sh open mode` opent de picker en markeert de actieve mode (`/tmp/kingstra-mode-picker-fixed-20260717.png`). Theme-switches door `paper`, `modern`, `mono` en terug naar `organic` leveren verschillende rail/strip-reserveringen en actieve `theme.json`-waarden op. De eindstate is `organic` + `office`, alle sessiecomponenten draaien, en `hyprctl layers -j` toont alleen de geïntegreerde shell-surface plus rail/strip-reserveringen zonder open `qs-master`.

Status: D1 is idee-fase → nu voldoende concreet voor een implementatieplan zodra de resterende open ontwerp-vragen (exacte ronding/schaduw-waarden, welk effect organic/paper/modern echt krijgt, migratiepad voor bestaande gebruikersstate) beantwoord zijn. D2.0 is nu aangescherpt tot geïntegreerde shell-surface met rail + status-strip; de oude dual-bar-variant blijft alleen fallback/spike als die surface-aanpak technisch blokkeert. D2.1 heeft een vastgestelde richting mét niveau-ambitie (paneel groeit uit de bar-rand, native Qt-plugin voor de blob-vervorming, zoals caelestia) — eerste stap is de shell-surface spike én de Quickshell-pluginlaad-spike, daarna pas QML-widgetwerk. D3 nog te doen: per template beslissen waar `accent2` wat vervangt, en het `accentHotColorName`-besluit voor Deel B. Deel A wacht op D2.1's motion-herziening voordat de definitieve per-thema tabel wordt vastgelegd.

**Concrete, kleine-stappen-uitvoering**: zie `stappen.md` voor het volledige, gefaseerde stappenplan (Fase 0 t/m 7) dat dit hele plan — Deel A, B, D1, D2.0, D2.1, D3 en D4 — omzet in losse, controleerbare acties per bestand.
