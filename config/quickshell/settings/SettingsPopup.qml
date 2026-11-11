import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "SettingIndex.js" as SettingIndex

Item {
    id: root
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // -------------------------------------------------------------------------
    Keys.onEscapePressed: {
        if (editingIndex >= 0) { editingIndex = -1; }
        else { closeSequence.start(); }
        event.accepted = true;
    }
    // In een eigen venster (SettingsWindow.qml) sluit de app zichzelf;
    // als paneel in de shell-surface loopt sluiten via qs_manager.
    property bool windowed: false
    signal closeRequested()

    function finishClose() {
        if (windowed) closeRequested();
        else Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function animateClose() {
        closeSequence.start();
    }

    Keys.onTabPressed: { openTab((currentTab + 1) % tabs.length); event.accepted = true; }
    Keys.onBacktabPressed: { openTab((currentTab - 1 + tabs.length) % tabs.length); event.accepted = true; }

    MatugenColors { id: _theme }

    // -------------------------------------------------------------------------
    // COLORS
    // -------------------------------------------------------------------------
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color overlay0: _theme.overlay0
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color green: _theme.green
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color red: _theme.red
    readonly property int themedRadius: root.s(Math.max(12, ThemeConfig.styleWidgetRadius))
    readonly property int themedInnerRadius: root.s(Math.max(8, ThemeConfig.styleWidgetRadius - 4))
    readonly property string uiFontFamily: ThemeConfig.uiFont
    readonly property string monoFontFamily: ThemeConfig.monoFont
    readonly property string displayFontFamily: ThemeConfig.displayFont
    readonly property real themedLetterSpacing: ThemeConfig.letterSpacing
    readonly property int themedFontWeight: ThemeConfig.fontWeight
    readonly property real settingsOpacity: Math.max(0.92, ThemeConfig.popupOpacity)
    readonly property color popupFill: _theme.shellContentFill
    readonly property color popupPanelFill: _theme.shellRaisedFill
    readonly property color popupPanelHoverFill: _theme.shellHoverFill

    property real colorBlend: 0.0
    SequentialAnimation on colorBlend {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }
    property color ambientPurple: Qt.tint(root.mauve, Qt.rgba(root.pink.r, root.pink.g, root.pink.b, colorBlend))
    property color ambientBlue: Qt.tint(root.blue, Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, colorBlend))

    // -------------------------------------------------------------------------
    // STATE
    // -------------------------------------------------------------------------
    // Instellingen volgen de vraag "wat wil je regelen", zoals GNOME en DMS:
    // Start plus acht onderwerpen. Een onderwerp heeft één hoofdpagina;
    // alleen Invoer en Systeem hebben echt losse pagina's (ronde knoppen
    // bovenin). Dieper liggende pagina's staan in `extra`: die open je via
    // een knop op de hoofdpagina en krijgen bovenin een knop terug.
    // Paginanummers: 0 Per scherm, 1 Kleurstijl (matugen), 2 Alle onderdelen
    // (thema-editor), 4 Sneltoetsen, 5 Invoer, 6 Schermen, 7 Netwerk,
    // 8 Geluid, 9 Tijd & weer, 10 Energie en sessie, 11 Updates,
    // 12 Onderhoud, 13 Over, 15 Zijbalk-indeling, 16 Start, 17 Uiterlijk,
    // 18 Bureaublad, 19 Meldingen en rust, 20 Back-up, 21 Ruimte.
    property var tabs: [
        { label: "Start", icon: "󰋜", pages: [16], pageLabels: ["Start"], extra: [], extraLabels: [], keywords: "start begin home overzicht alles" },
        { label: "Uiterlijk", icon: "󰏘", pages: [17], pageLabels: ["Uiterlijk"], extra: [1, 2], extraLabels: ["Kleurstijl en contrast", "Alle onderdelen"],
          keywords: "uiterlijk thema kleur accent licht donker rond rondheid hoeken ruimte gaps lettertype font matugen icoon strook vorm blur effecten aanpassen origineel" },
        { label: "Bureaublad", icon: "󰕮", pages: [18], pageLabels: ["Bureaublad"], extra: [15], extraLabels: ["Zijbalk-indeling"],
          keywords: "bureaublad zijbalk rail verbergen indeling tegels scrollen scrollstrook ruimtelijk werkvlak vanzelf spel gaming batterij delen speler plaat cassette discman volgorde tweede rail apps werkruimtes vastklikken snap" },
        { label: "Schermen", icon: "󰍹", pages: [6], pageLabels: ["Schermen"], extra: [0], extraLabels: ["Per scherm"],
          keywords: "scherm schermen monitor monitoren display resolutie indeling layout hoofdscherm helderheid tablet touch werkruimte workspace per scherm stand mode muziek" },
        { label: "Geluid", icon: "󰕾", pages: [8], pageLabels: ["Geluid"], extra: [], extraLabels: [],
          keywords: "geluid audio volume uitvoer invoer microfoon speaker koptelefoon mixer dempen" },
        { label: "Netwerk en Bluetooth", icon: "󰤨", pages: [7], pageLabels: ["Netwerk en Bluetooth"], extra: [], extraLabels: [],
          keywords: "netwerk wifi bluetooth draadloos bedraad ethernet" },
        { label: "Invoer en sneltoetsen", icon: "󰌌", pages: [5, 4], pageLabels: ["Invoer", "Sneltoetsen"], extra: [], extraLabels: [],
          keywords: "invoer toetsenbord touchpad muis scroll scrollen rechtsklik dead keys sneltoets sneltoetsen keybind keybinds toets binding" },
        { label: "Meldingen en rust", icon: "󰂛", pages: [19], pageLabels: ["Meldingen en rust"], extra: [], extraLabels: [],
          keywords: "meldingen notificaties niet storen dnd rust nachtlicht warm avond schema per app stil nooit altijd" },
        { label: "Systeem", icon: "󰒓", pages: [10, 9, 11, 20, 21, 12, 13], pageLabels: ["Energie en sessie", "Tijd en weer", "Updates", "Back-up", "Ruimte", "Onderhoud", "Over"], extra: [], extraLabels: [],
          keywords: "ruimte schijfruimte vol opruimen cache prullenbak docker spotify back-up backup versies terughalen terugdraaien herstel gezondheid schijf schijven smart opstart kernel systeem sessie idle vergrendelen lock slaap suspend energie power profiel uitloggen weer tijd datum klok notatie formaat api openweather locatie updates update pakketten onderhoud geavanceerd herstart herladen matugen verwijderen over versie" }
    ]
    property int currentTab: 0
    property int currentPage: tabs[0].pages[0]
    property string settingsQuery: ""
    readonly property var visibleTabIndexes: {
        let q = settingsQuery.trim().toLowerCase();
        let out = [];
        for (let i = 0; i < tabs.length; i++) {
            let hay = (tabs[i].label + " " + tabs[i].pageLabels.join(" ") + " " + tabs[i].keywords).toLowerCase();
            if (q === "" || hay.indexOf(q) !== -1) out.push(i);
        }
        return out;
    }

    function openTab(index) {
        if (index < 0 || index >= tabs.length) return;
        currentTab = index;
        currentPage = tabs[index].pages[0];
    }

    function openPage(page) {
        for (let i = 0; i < tabs.length; i++) {
            if (tabs[i].pages.indexOf(page) !== -1 || tabs[i].extra.indexOf(page) !== -1) {
                currentTab = i;
                currentPage = page;
                return;
            }
        }
    }

    // Enter in het zoekveld: eerste losse instelling, dan het eerste passende
    // tabblad, en anders zoeken in de sneltoetsen.
    function acceptSettingsQuery() {
        let q = settingsQuery.trim();
        if (q === "") return;
        if (settingResults.length > 0) openSetting(settingResults[0]);
        else if (visibleTabIndexes.length > 0) openTab(visibleTabIndexes[0]);
        else searchKeybinds(q);
    }

    function searchKeybinds(q) {
        openPage(4);
        filterInput.text = q;
    }

    // Zoeken op losse instelling, zoals in GNOME en KDE: een treffer springt
    // naar de pagina (en het tabblad van de thema-editor) waar hij staat.
    // Labels zijn de koppen zoals ze op de pagina staan.
    // De index zelf staat in SettingIndex.js, gedeeld met de launcher.
    readonly property var settingIndex: SettingIndex.entries
    readonly property var settingResults: SettingIndex.search(settingsQuery, 8)

    function openSetting(entry) {
        if (!entry) return;
        if (entry.editor) openThemeEditor(entry.editor);
        if (entry.section) expandSection(entry.section);
        openPage(entry.page);
    }

    // Uitklapblokken per pagina. Een zoektreffer of diepe link naar een
    // instelling die erin zit klapt het blok open.
    function expandSection(key) {
        let sections = {
            "thema": themeAdvancedSection,
            "beeldschermen": displayAdvancedSection, "invoer": inputAdvancedSection,
            "geluid": audioAdvancedSection, "tijd": timeAdvancedSection,
            "sessie": sessionAdvancedSection, "verwijderen": uninstallAdvancedSection
        };
        let section = sections[String(key || "")];
        if (section) section.expanded = true;
    }

    // Opent Thema aanpassen op de gevraagde groep. Namen van vóór de
    // opruiming (appearance, bar, character, effects) blijven werken.
    readonly property var themeEditorAliases: ({
        "appearance": "windows", "vensters": "windows",
        "bar": "shell", "character": "shell", "effects": "shell", "strook": "shell",
        "kleuren": "colors", "letters": "fonts"
    })

    function themeEditorId(name) {
        let key = String(name || "").toLowerCase();
        if (themeEditorAliases[key] !== undefined) key = themeEditorAliases[key];
        for (let i = 0; i < themeEditorTabs.length; i++) {
            if (themeEditorTabs[i].id === key) return key;
        }
        return "";
    }

    function openThemeEditor(editor) {
        let id = themeEditorId(editor);
        if (id !== "") themeEditorTab = id;
        openPage(2);
    }

    // Diepe links (qs_manager.sh open settings <naam>): elke pagina heeft een
    // vaste naam, zodat panelen Instellingen op de juiste plek kunnen openen.
    readonly property var pageNames: ({
        "start": 16, "home": 16, "overzicht": 16, "overview": 16,
        "uiterlijk": 17, "appearance": 17, "bureaublad": 18, "desktop": 18,
        "rust": 19, "meldingen": 19, "nachtlicht": 19,
        "perscherm": 0, "per-scherm": 0, "bediening": 18, "control": 18, "apparaten": 6, "systeem": 10,
        "rail": 15, "rail-indeling": 15, "railindeling": 15, "zijbalk": 15,
        "thema": 1, "theme": 1, "kleurstijl": 1, "bar": 2, "aanpassen": 2, "kleuren": 2, "sneltoetsen": 4, "keybinds": 4,
        "invoer": 5, "input": 5, "beeldschermen": 6, "schermen": 6, "monitors": 6,
        "netwerk": 7, "network": 7, "geluid": 8, "audio": 8,
        "tijd": 9, "weer": 9, "sessie": 10, "session": 10, "energie": 10, "updates": 11, "update": 11,
        "backup": 20, "back-up": 20, "terughalen": 20,
        "ruimte": 21, "schijfruimte": 21, "opruimen": 21, "disk": 21, "space": 21,
        "geavanceerd": 12, "advanced": 12, "onderhoud": 12, "over": 13, "about": 13
    })

    function openNamedPage(name) {
        let key = String(name || "").trim().toLowerCase();
        if (key === "") return;
        // "thema/fonts": pagina plus tabblad van de thema-editor.
        let slash = key.indexOf("/");
        // "invoer/invoer": pagina plus het uitklapblok met die naam.
        if (slash > 0) {
            let editor = key.substring(slash + 1);
            key = key.substring(0, slash);
            if (themeEditorId(editor) !== "") {
                openThemeEditor(editor);
                return;
            }
            expandSection(editor);
        }
        let page = pageNames[key];
        if (page === undefined && /^[0-9]+$/.test(key)) page = parseInt(key);
        if (page !== undefined) openPage(page);
    }

    onCurrentPageChanged: {
        if (currentPage === 6) refreshDisplayStatus();
        if (currentPage === 8) refreshAudioState();
        if (currentPage === 10) refreshCloseFully();
        if (currentPage === 11) refreshUpdatePage(false);
        if (currentPage === 20) refreshBackupPage();
        if (currentPage === 21) refreshSpacePage(false);
    }

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0

    // Keybinds state
    ListModel { id: keybindsModel }
    ListModel { id: workspaceMonitorModel }
    property int editingIndex: -1
    property string keybindFilter: ""
    property string keybindWriteError: ""
    property string keybindWriteSuccessMessage: ""

    // Operational tab state
    property string displayStatusText: "Monitorstatus nog niet geladen"
    property string displayLayoutText: "Display-layout nog niet geladen"
    property string displayTouchText: "Touch-profiel nog niet geladen"
    property string displayBrightnessText: "Helderheid nog niet geladen"
    property string workspaceMonitorText: "Workspace-toewijzingen nog niet geladen"
    property var workspaceMonitorOptions: ["Vrij"]
    property bool workspaceMonitorDirty: false
    property bool workspaceMonitorSaveBusy: false
    property var primaryDisplayOptions: ["Automatisch (gefocusd)"]
    property string primaryDisplayName: ""
    property string primaryDisplayEffective: ""
    property bool primaryDisplaySaveBusy: false
    property string networkStatusText: "Netwerkstatus nog niet geladen"
    property string audioStatusText: "Audiostatus nog niet geladen"
    property bool audioStateBusy: false
    property var audioOutputs: []
    property var audioInputs: []
    property var audioApps: []
    property string sessionModeText: "office"
    property string currentPowerProfileText: "balanced"
    property string updateStatusText: "Nog niet gecontroleerd"
    // Updates-pagina: plan (wat er klaarstaat), laatste uitkomst en de
    // gezondheidscheck. Back-up-pagina: status van kingstra-backup.
    property var upPlan: ({})
    property bool upPlanBusy: false
    property var upResult: ({})
    property var vnHealth: []
    property var bkStatus: ({})
    // Ruimte-pagina: kingstra-ruimte (schijven, grootste mappen, opruimen).
    property var spaceData: ({})
    property bool spaceBusy: false
    property string spaceCleaning: ""
    readonly property string kingstraBin: Quickshell.env("HOME") + "/.local/bin/"
    property string advancedStatusText: "Klaar"
    property bool showUninstallConfirm: false
    readonly property string monitorRestoreScript: Quickshell.env("HOME") + "/.config/hypr/scripts/monitor-hotplug-restore.sh"
    readonly property string workspaceMonitorScript: Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-monitor-assignments.sh"
    readonly property string primaryDisplayScript: Quickshell.env("HOME") + "/.config/quickshell/settings/primary-display.sh"
    readonly property string tabletModeScript: Quickshell.env("HOME") + "/.config/hypr/scripts/tablet-mode.sh"
    readonly property string displayStatusScript: Quickshell.env("HOME") + "/.config/quickshell/settings/display_status.sh"
    readonly property string idleApplyScript: Quickshell.env("HOME") + "/.config/shared/scripts/kingstra-idle-apply"

    // Catalog van bekende acties zonder vaste keybinding — worden als "Niet ingesteld" getoond
    readonly property var keybindCatalog: [
        { label: "Kleurenkiezer",    cat: "apps",  file: "binds.lua",  d: "exec", args: "hyprpicker -r -n -f hex",              t: "bind", ln: 0, mods: "", key: "" },
        { label: "Schermopname",     cat: "apps",  file: "binds.lua",  d: "exec", args: "wf-recorder",                          t: "bind", ln: 0, mods: "", key: "" },
        { label: "Uitlogmenu",       cat: "core",  file: "binds.lua",  d: "exec", args: "wlogout",                               t: "bind", ln: 0, mods: "", key: "" },
        { label: "Emoji-kiezer",     cat: "apps",  file: "binds.lua",  d: "exec", args: "walker --modules emojis",               t: "bind", ln: 0, mods: "", key: "" }
    ]

    // Settings file
    property var settingsData: ({
        timeFormat: "HH:mm:ss",
        dateFormat: "dddd, MMMM dd",
        touchpadScrollFactor: 0.45,
        mouseScrollFactor: 1.35,
        touchpadRightClickButtonArea: true,
        keyboardLayout: "us",
        keyboardDeadKeys: false,
        idleLockSeconds: 300,
        idleScreenOffSeconds: 480,
        idleSuspendSeconds: 1800,
        idleProfiles: ({
            "performance": { idleLockSeconds: 900, idleScreenOffSeconds: 1800, idleSuspendSeconds: 0 },
            "balanced": { idleLockSeconds: 300, idleScreenOffSeconds: 480, idleSuspendSeconds: 1800 },
            "power-saver": { idleLockSeconds: 180, idleScreenOffSeconds: 300, idleSuspendSeconds: 900 }
        })
    })
    property var keyboardLayoutCodes: ["us", "nl", "be", "gb", "de", "fr"]
    property var keyboardLayoutLabels: [
        "English (US)",
        "Nederlands",
        "Belgisch",
        "English (UK)",
        "Deutsch",
        "Français"
    ]
    // Dode toetsen zitten in xkb in de variant, niet in de layout. Twee families:
    // us/gb hebben van zichzelf geen dode toetsen (aanzetten = "intl"), be/de/fr
    // hebben ze wel (uitzetten = "nodeadkeys"). nl kent geen variant zonder dode
    // toetsen, dus daar valt niets te kiezen.
    property var keyboardDeadKeysOnVariants: ({ "us": "intl", "gb": "intl" })
    property var keyboardDeadKeysOffVariants: ({ "be": "nodeadkeys", "de": "nodeadkeys", "fr": "nodeadkeys" })
    property var keyboardDeadKeysDefaultLayouts: ["nl", "be", "de", "fr"]
    property var idleTimeoutOptions: [
        "Off",
        "30 sec",
        "1 min",
        "2 min",
        "3 min",
        "5 min",
        "8 min",
        "10 min",
        "15 min",
        "20 min",
        "30 min",
        "45 min",
        "60 min"
    ]

    FileView {
        id: settingsFileView
        path: Quickshell.env("HOME") + "/.config/quickshell/settings/settings.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: {
            if (!__text) return;
            try {
                var parsed = JSON.parse(__text);
                root.settingsData = {
                    timeFormat: String(parsed.timeFormat || "HH:mm:ss"),
                    dateFormat: String(parsed.dateFormat || "dddd, MMMM dd"),
                    touchpadScrollFactor: root.scrollFactorFromPercent(root.scrollPercentFromSetting(parsed.touchpadScrollFactor, 0.45), 0.45),
                    mouseScrollFactor: root.scrollFactorFromPercent(root.scrollPercentFromSetting(parsed.mouseScrollFactor, 1.35), 1.35),
                    touchpadRightClickButtonArea: parsed.touchpadRightClickButtonArea !== false,
                    keyboardLayout: root.normalizeKeyboardLayout(parsed.keyboardLayout),
                    keyboardDeadKeys: root.normalizeKeyboardDeadKeys(
                        String(parsed.keyboardLayout || "") === "us,intl" ? true : parsed.keyboardDeadKeys,
                        parsed.keyboardLayout),
                    idleLockSeconds: root.normalizeIdleSeconds(parsed.idleLockSeconds, 300),
                    idleScreenOffSeconds: root.normalizeIdleSeconds(parsed.idleScreenOffSeconds, 480),
                    idleSuspendSeconds: root.normalizeIdleSeconds(parsed.idleSuspendSeconds, 1800),
                    idleProfiles: root.normalizeIdleProfiles(parsed)
                };
            } catch(e) {}
        }
    }

    // QS 0.3.0: watchChanges mist inode-vervanging; poll als vangnet
    Timer { interval: 1000; running: true; repeat: true; onTriggered: settingsFileView.reload() }

    // Keybinds laden via Process → StdioCollector (geen temp-bestand race-conditie)
    Process {
        id: loadKeybindsProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/settings/read_keybinds.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    root.mergeKeybinds(data);
                } catch(e) {
                    root.mergeKeybinds([]);
                }
            }
        }
    }

    Process {
        id: keybindWriteProc
        command: ["bash", "-lc", "true"]
        stderr: StdioCollector {
            onStreamFinished: {
                root.keybindWriteError = this.text.trim();
            }
        }
        onExited: {
            if (root.keybindWriteError !== "") {
                root.notify("Keybinds", "Opslaan mislukt: " + root.keybindWriteError);
            } else if (root.keybindWriteSuccessMessage !== "") {
                root.notify("Keybinds", root.keybindWriteSuccessMessage);
            }
            root.keybindWriteError = "";
            root.keybindWriteSuccessMessage = "";
            root.editingIndex = -1;
            loadKeybindsProc.running = true;
        }
    }

    // Weather state
    property string selectedUnit: "metric"

    // Theme state
    property string activeThemeName: ""
    property string activeThemeIcon: "󰏘"
    property string activeThemeId: ""
    property var themeAppearance: ({})
    property var activeThemeData: ({})
    property bool themeSaveBusy: false
    property string themeSaveError: ""
    property string themeEditThemeId: ""
    property string themeLoadedSignature: ""
    property string themeStatusText: ""
    property string themeStatusKind: "info"
    property string themeEditorTab: "colors"
    readonly property bool themeDirty: themeEditThemeId !== ""
                                        && themeLoadedSignature !== ""
                                        && currentThemeSignature() !== themeLoadedSignature
    readonly property string themeSwitchSafeCmd: Quickshell.env("HOME") + "/.config/hypr/scripts/theme-switch-safe.sh"
    readonly property string themeReadSafeCmd: Quickshell.env("HOME") + "/.config/hypr/scripts/theme-read-safe.sh"
    readonly property string themeUpdateSafeCmd: Quickshell.env("HOME") + "/.config/hypr/scripts/theme-update-safe.sh"
    property bool topbarReloadBusy: false
    property string topbarReloadError: ""

    // In-app editable theme fields
    property int editBorderRadius: 12
    property int editBorderWidth: 2
    property int editGapsIn: 5
    property int editGapsOut: 10
    property int editBlurSize: 8
    property int editBlurPasses: 3

    property string editUiFont: "Inter"
    property int editUiFontSize: 13
    property string editMonoFont: "JetBrainsMono Nerd Font"
    property int editMonoFontSize: 12
    property string editDisplayFont: "Inter"
    property string editFontWeight: "regular"
    property string editLetterSpacing: "0.0"

    property string editIconTheme: "Papirus-Dark"
    property string editSchemeType: "scheme-tonal-spot"
    property int editColorIndex: 0
    property string editContrast: "0.0"
    property string editMode: "dark"
    property var modeOptions: ["dark", "light"]
    property int editBarHeight: 40
    property string editBarPosition: "top"
    property bool editBarRailEnabled: false
    property string editBarRailEdge: "left"
    property int editBarRailWidth: 52
    property bool editBarStatusStripEnabled: true
    property string editBarStatusStripEdge: "top"
    property int editBarStatusStripHeight: 40
    property string editBarTemplate: "auto"
    property string editBarWidthMode: "full"
    property string editBarShape: "rounded"
    property string editBarTopEdgeStyle: "soft"
    property string editBarBottomEdgeStyle: "soft"
    property string editClockStyle: "digital"
    property bool editTopbarLooseBlocks: true

    // Transparantie & animatie
    property string editBarOpacity: "0.72"
    property string editPopupOpacity: "0.80"
    property string editAnimationSpeed: "0.75"

    // Materiaal
    property string editOverlayOpacity: "0.06"
    property string editGlowIntensity: "0.04"

    // Effecten
    property string editParticleType: "none"
    property int editParticleCount: 0
    property string editParticleSpeed: "0.18"
    property string editAmbientEffect: "theme-default"
    property string editEffectIntensity: "1.0"
    property int editEffectCycleMs: 0
    property string editHoverReactivity: "0.4"

    // Karakter
    property string editStyleFamily: "organic"
    property string editStyleDensity: "comfortable"
    property string editSurfaceMode: "soft-glass"
    property string editStyleMotion: "gentle"
    property string editPanelShadow: "0.22"
    property string editOutlineStrength: "0.18"
    property string editGlassStrength: "0.10"
    property int editWidgetRadius: 16
    property int editPanelPadding: 14
    property string editDrawerStyle: "context-card"
    property string editModuleDensity: "balanced"
    property string editWorkspacePreview: "hybrid"
    property string editRailAccent: "none"

    property var schemeOptions: [
        "scheme-tonal-spot",
        "scheme-monochrome",
        "scheme-neutral",
        "scheme-fidelity",
        "scheme-content",
        "scheme-expressive",
        "scheme-rainbow",
        "scheme-fruit-salad"
    ]
    property var fontOptions: [
        "Inter",
        "JetBrains Mono",
        "JetBrainsMono Nerd Font",
        "Fira Sans",
        "Fira Code",
        "Noto Sans",
        "Space Grotesk",
        "Share Tech Mono",
        "Nunito",
        "Iosevka Nerd Font"
    ]
    property var iconThemeOptions: [
        "Papirus-Dark",
        "Papirus",
        "Breeze",
        "Tela-circle-dark",
        "Adwaita"
    ]
    property var barPositionOptions: ["top", "bottom", "left", "right"]
    property var barTemplateOptions: ["auto", "horizontal", "sidebar", "compact-sidebar"]
    property var barWidthModeOptions: ["full", "floating"]
    property var barShapeOptions: ["rounded", "organic-grown", "capsule", "block", "segmented-capsule", "beveled", "kinetic-dock"]
    property var barEdgeStyleOptions: ["flush", "soft", "hard", "beveled", "ornate-rounded"]
    property var clockStyleOptions: ["digital", "analog", "hybrid"]
    property var fontWeightOptions: ["light", "regular", "medium", "bold"]
    property var particleTypeOptions: ["none", "fireflies", "space-specks", "space-specks-layered", "sparkles", "rain", "snow", "dust"]
    property var styleFamilyOptions: ["paper", "organic", "neon", "mono", "matte"]
    property var styleDensityOptions: ["compact", "comfortable", "airy"]
    property var surfaceModeOptions: ["paper-glass", "soft-glass", "hard-surface", "solid"]
    property var styleMotionOptions: ["calm", "gentle", "snappy", "firm"]
    property var ambientEffectOptions: ["theme-default", "none", "organic-glow", "neon-grid"]
    property var drawerStyleOptions: ["none", "context-card", "rail-panel"]
    property var moduleDensityOptions: ["minimal", "balanced", "rich"]
    property var workspacePreviewOptions: ["numbers", "app-icons", "hybrid"]
    property var railAccentOptions: ["none", "edge-line", "pulse-line", "segmented"]
    // De vier groepen van Thema aanpassen (pagina 2). Oude namen uit
    // diepe links worden in openThemeEditor omgezet.
    property var themeEditorTabs: [
        { id: "colors", label: "Kleuren", icon: "󰏘" },
        { id: "fonts", label: "Letters", icon: "󰛖" },
        { id: "windows", label: "Vensters", icon: "󰖯" },
        { id: "shell", label: "Strook en panelen", icon: "󰕮" }
    ]

    function refreshActiveTheme() {
        loadThemeProc.running = true;
    }

    function toIntValue(value, fallback) {
        let parsed = parseInt(value);
        return isNaN(parsed) ? fallback : parsed;
    }

    function toFloatString(value, fallback) {
        let parsed = parseFloat(value);
        if (isNaN(parsed)) return String(fallback);
        return String(parsed);
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    // Terugschrijven vanuit een spinbox (schaal 100) naar een edit-property.
    // Alleen schrijven bij echte wijziging: een onvoorwaardelijke write vanuit
    // onValueChanged invalideert de value-binding tijdens diens eigen evaluatie
    // en geeft "Binding loop detected"-warnings.
    function setEditFloat(prop, value100) {
        const s = (value100 / 100.0).toFixed(2);
        if (root[prop] !== s) root[prop] = s;
    }

    function shellSingleQuote(value) {
        return String(value || "").replace(/'/g, "'\\''");
    }

    function scrollPercentFromSetting(value, fallback) {
        let parsed = parseFloat(value);
        if (isNaN(parsed)) parsed = fallback;
        return Math.round(clamp(parsed, 0.20, 3.00) * 100);
    }

    function scrollFactorFromPercent(value, fallback) {
        let parsed = parseInt(value);
        if (isNaN(parsed)) parsed = Math.round(fallback * 100);
        return Math.round(clamp(parsed / 100.0, 0.20, 3.00) * 100) / 100;
    }

    function normalizeKeyboardLayout(value) {
        // "us,intl" was de oude manier om US International te kiezen; dat is nu
        // layout "us" met de dode-toetsen-schakelaar aan.
        if (String(value || "") === "us,intl") return "us";
        return normalizeOption(value, keyboardLayoutCodes, "us");
    }

    function keyboardLayoutIndex(value) {
        let normalized = normalizeKeyboardLayout(value);
        let index = keyboardLayoutCodes.indexOf(normalized);
        return index >= 0 ? index : 0;
    }

    function keyboardDeadKeysAdjustable(layout) {
        let safe = normalizeKeyboardLayout(layout);
        return keyboardDeadKeysOnVariants[safe] !== undefined
            || keyboardDeadKeysOffVariants[safe] !== undefined;
    }

    function keyboardDeadKeysDefault(layout) {
        return keyboardDeadKeysDefaultLayouts.indexOf(normalizeKeyboardLayout(layout)) >= 0;
    }

    function normalizeKeyboardDeadKeys(value, layout) {
        let safe = normalizeKeyboardLayout(layout);
        if (!keyboardDeadKeysAdjustable(safe)) return keyboardDeadKeysDefault(safe);
        if (value === undefined || value === null) return keyboardDeadKeysDefault(safe);
        return value === true;
    }

    function keyboardVariant(layout, deadKeys) {
        let safe = normalizeKeyboardLayout(layout);
        if (normalizeKeyboardDeadKeys(deadKeys, safe)) return keyboardDeadKeysOnVariants[safe] || "";
        return keyboardDeadKeysOffVariants[safe] || "";
    }

    function normalizeIdleSeconds(value, fallback) {
        let parsed = parseInt(value);
        if (isNaN(parsed)) parsed = fallback;
        parsed = Math.max(0, parsed);
        let index = idleTimeoutOptionIndex(parsed);
        return idleTimeoutSeconds(index);
    }

    function idleTimeoutSeconds(index) {
        let values = [0, 30, 60, 120, 180, 300, 480, 600, 900, 1200, 1800, 2700, 3600];
        let safeIndex = Math.max(0, Math.min(values.length - 1, parseInt(index)));
        return values[safeIndex];
    }

    function idleTimeoutOptionIndex(seconds) {
        let safeSeconds = Math.max(0, parseInt(seconds) || 0);
        let values = [0, 30, 60, 120, 180, 300, 480, 600, 900, 1200, 1800, 2700, 3600];
        let index = values.indexOf(safeSeconds);
        return index >= 0 ? index : 0;
    }

    function powerProfileLabel(profileName) {
        let safe = String(profileName || "balanced");
        if (safe === "performance") return "Performance";
        if (safe === "power-saver") return "Saver";
        return "Balanced";
    }

    function normalizeIdleProfiles(parsed) {
        let source = (parsed && parsed.idleProfiles) ? parsed.idleProfiles : {};

        function readProfile(profileName, fallbackLock, fallbackScreenOff, fallbackSuspend) {
            let profile = source[profileName] || {};
            return {
                idleLockSeconds: normalizeIdleSeconds(profile.idleLockSeconds, fallbackLock),
                idleScreenOffSeconds: normalizeIdleSeconds(profile.idleScreenOffSeconds, fallbackScreenOff),
                idleSuspendSeconds: normalizeIdleSeconds(profile.idleSuspendSeconds, fallbackSuspend)
            };
        }

        return {
            "performance": readProfile("performance", 900, 1800, 0),
            "balanced": readProfile("balanced", normalizeIdleSeconds(parsed.idleLockSeconds, 300), normalizeIdleSeconds(parsed.idleScreenOffSeconds, 480), normalizeIdleSeconds(parsed.idleSuspendSeconds, 1800)),
            "power-saver": readProfile("power-saver", 180, 300, 900)
        };
    }

    function idleProfileSettings(profileName) {
        let safe = String(profileName || "balanced");
        let profiles = settingsData.idleProfiles || {};
        let selected = profiles[safe];
        if (selected) return selected;
        return {
            idleLockSeconds: normalizeIdleSeconds(settingsData.idleLockSeconds, 300),
            idleScreenOffSeconds: normalizeIdleSeconds(settingsData.idleScreenOffSeconds, 480),
            idleSuspendSeconds: normalizeIdleSeconds(settingsData.idleSuspendSeconds, 1800)
        };
    }

    function idleProfileSummary(profileName) {
        let selected = idleProfileSettings(profileName);
        return powerProfileLabel(profileName) + ": " +
            formatIdleDuration(selected.idleLockSeconds, "lock uit") + " lock, " +
            formatIdleDuration(selected.idleScreenOffSeconds, "scherm aan") + " scherm, " +
            formatIdleDuration(selected.idleSuspendSeconds, "geen suspend");
    }

    function formatIdleDuration(seconds, offLabel) {
        let safeSeconds = Math.max(0, parseInt(seconds) || 0);
        if (safeSeconds <= 0) return offLabel || "Uit";
        if (safeSeconds < 60) return safeSeconds + " sec";
        if (safeSeconds % 3600 === 0) return (safeSeconds / 3600) + " uur";
        if (safeSeconds % 60 === 0) return (safeSeconds / 60) + " min";
        return safeSeconds + " sec";
    }

    function deriveDimTimeout(lockSeconds, screenOffSeconds, suspendSeconds) {
        let targets = [parseInt(lockSeconds) || 0, parseInt(screenOffSeconds) || 0, parseInt(suspendSeconds) || 0]
            .filter(function(value) { return value > 0; });
        if (targets.length === 0) return 0;
        let earliest = Math.min.apply(Math, targets);
        if (earliest <= 45) return 0;
        return Math.max(30, earliest - 60);
    }

    function buildHypridleConfig(lockSeconds, screenOffSeconds, suspendSeconds) {
        let safeLock = normalizeIdleSeconds(lockSeconds, 300);
        let safeScreenOff = normalizeIdleSeconds(screenOffSeconds, 480);
        let safeSuspend = normalizeIdleSeconds(suspendSeconds, 1800);
        let dimSeconds = deriveDimTimeout(safeLock, safeScreenOff, safeSuspend);
        let blocks = [
            "# =============================================================================",
            "# hypridle.conf — Idle daemon configuratie",
            "# =============================================================================",
            "# Beheerd vanuit de Settings-popup.",
            "# Tijden zijn in seconden.",
            "# =============================================================================",
            "",
            "general {",
            "    lock_cmd         = bash ~/.config/hypr/scripts/lock.sh",
            "    before_sleep_cmd = loginctl lock-session",
            "    after_sleep_cmd  = bash ~/.config/hypr/scripts/resume-display.sh",
            "}",
            ""
        ];

        if (dimSeconds > 0) {
            blocks.push(
                "# Automatisch dimmen voor de eerstvolgende idle-actie",
                "listener {",
                "    timeout   = " + dimSeconds,
                "    on-timeout = brightnessctl -s s 10%",
                "    on-resume  = brightnessctl -r",
                "}",
                ""
            );
        }

        if (safeLock > 0) {
            blocks.push(
                "# Automatisch vergrendelen",
                "listener {",
                "    timeout   = " + safeLock,
                "    on-timeout = loginctl lock-session",
                "    on-resume  = bash ~/.config/hypr/scripts/resume-display.sh --display-only",
                "}",
                ""
            );
        }

        if (safeScreenOff > 0) {
            blocks.push(
                "# Scherm uitschakelen via DPMS",
                "listener {",
                "    timeout   = " + safeScreenOff,
                "    on-timeout = bash ~/.config/hypr/scripts/hypr-dispatch.sh dpms off",
                "    on-resume  = bash ~/.config/hypr/scripts/resume-display.sh --display-only",
                "}",
                ""
            );
        }

        if (safeSuspend > 0) {
            blocks.push(
                "# Suspend / slaapstand",
                "listener {",
                "    timeout   = " + safeSuspend,
                "    on-timeout = bash ~/.config/hypr/scripts/suspend.sh",
                "}",
                ""
            );
        }

        return blocks.join("\n");
    }

    function sessionIdleSummary() {
        let selected = idleProfileSettings(currentPowerProfileText);
        return "Actief profiel: " + powerProfileLabel(currentPowerProfileText) +
            "\nLock: " + formatIdleDuration(selected.idleLockSeconds, "uit") +
            "\nScherm uit: " + formatIdleDuration(selected.idleScreenOffSeconds, "uit") +
            "\nSuspend: " + formatIdleDuration(selected.idleSuspendSeconds, "uit");
    }

    function normalizeOption(value, options, fallback) {
        let normalized = String(value || "");
        return options.indexOf(normalized) >= 0 ? normalized : fallback;
    }

    function isVerticalBarPosition(position) {
        let normalized = normalizeOption(position, barPositionOptions, "top");
        return normalized === "left" || normalized === "right";
    }

    function derivedBarTemplate(position, template) {
        let normalizedTemplate = normalizeOption(template, barTemplateOptions, "auto");
        if (isVerticalBarPosition(position)) {
            return normalizedTemplate === "compact-sidebar" ? "compact-sidebar" : "sidebar";
        }
        return "horizontal";
    }

    function setEditBarPosition(position) {
        editBarPosition = normalizeOption(position, barPositionOptions, "top");
        editBarTemplate = derivedBarTemplate(editBarPosition, editBarTemplate);
    }

    function defaultTopbarLooseBlocks(themeData, themeId) {
        let raw = themeValue(themeData, "bar", "topbar_loose_blocks", "__unset__");
        if (raw !== "__unset__") {
            if (typeof raw === "boolean") return raw;
            let normalized = String(raw || "").toLowerCase();
            if (normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on") return true;
            if (normalized === "false" || normalized === "0" || normalized === "no" || normalized === "off") return false;
        }

        // Fallback op de historische style-defaults zolang de key niet in het theme staat.
        let safeThemeId = normalizeThemeId(themeId || "");
        if (safeThemeId === "mono" || safeThemeId === "mono-accent" || safeThemeId === "neon") return false;
        return true;
    }

    function themeSection(themeData, name) {
        if (themeData && themeData[name]) return themeData[name];
        return ({});
    }

    function themeValue(themeData, sectionName, key, fallback) {
        let section = themeSection(themeData, sectionName);
        let value = section[key];
        return value !== undefined && value !== "" ? value : fallback;
    }

    function formatSchemeLabel(value) {
        let cleaned = String(value || "scheme-tonal-spot").replace(/^scheme-/, "");
        let parts = cleaned.split("-");
        for (let i = 0; i < parts.length; i++) {
            if (parts[i].length > 0) parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        }
        return parts.join(" ");
    }

    function normalizeThemeId(themeId) {
        return String(themeId || "").replace(/[^a-zA-Z0-9_-]/g, "");
    }

    function configHome() {
        let xdg = String(Quickshell.env("XDG_CONFIG_HOME") || "");
        return xdg !== "" ? xdg : Quickshell.env("HOME") + "/.config";
    }

    function themeFilePath(themeId) {
        let safeId = normalizeThemeId(themeId);
        if (safeId === "") return "";
        return configHome() + "/kingstra/themes/" + safeId + ".toml";
    }

    function setThemeStatus(text, kind) {
        themeStatusText = String(text || "");
        themeStatusKind = String(kind || "info");
    }

    function currentThemeSignature() {
        return JSON.stringify([
            editBorderRadius, editBorderWidth, editGapsIn, editGapsOut, editBlurSize, editBlurPasses,
            editUiFont, editUiFontSize, editMonoFont, editMonoFontSize, editDisplayFont, editFontWeight, editLetterSpacing,
            editIconTheme, editSchemeType, editColorIndex, editContrast, editMode,
            editBarHeight, editBarPosition, derivedBarTemplate(editBarPosition, editBarTemplate), editBarWidthMode, editBarShape,
            editBarTopEdgeStyle, editBarBottomEdgeStyle, editClockStyle, editTopbarLooseBlocks,
            editBarOpacity, editPopupOpacity, editAnimationSpeed, editOverlayOpacity, editGlowIntensity,
            editParticleType, editParticleCount, editParticleSpeed, editAmbientEffect, editEffectIntensity,
            editEffectCycleMs, editHoverReactivity,
            editStyleFamily, editStyleDensity, editSurfaceMode, editStyleMotion, editPanelShadow,
            editOutlineStrength, editGlassStrength, editWidgetRadius, editPanelPadding,
            editDrawerStyle, editModuleDensity, editWorkspacePreview, editRailAccent
        ]);
    }

    function loadThemeEditForm(themeData, themeId) {
        let safeThemeId = normalizeThemeId(themeId || themeCarousel.selectedThemeId || activeThemeId);
        if (safeThemeId === "") return;
        if (themeDirty && safeThemeId !== themeEditThemeId && !themeSaveBusy) {
            setThemeStatus("Onopgeslagen wijzigingen in " + themeEditThemeId + ". Sla eerst op of herstel de waarden.", "warn");
            return;
        }
        themeEditThemeId = safeThemeId;

        editBorderRadius = toIntValue(themeValue(themeData, "appearance", "border_radius", 12), 12);
        editBorderWidth = toIntValue(themeValue(themeData, "appearance", "border_width", 2), 2);
        editGapsIn = toIntValue(themeValue(themeData, "appearance", "gaps_in", 5), 5);
        editGapsOut = toIntValue(themeValue(themeData, "appearance", "gaps_out", 10), 10);
        editBlurSize = toIntValue(themeValue(themeData, "appearance", "blur_size", 8), 8);
        editBlurPasses = toIntValue(themeValue(themeData, "appearance", "blur_passes", 3), 3);

        editUiFont = String(themeValue(themeData, "fonts", "ui_font", "Inter"));
        editUiFontSize = toIntValue(themeValue(themeData, "fonts", "ui_font_size", 13), 13);
        editMonoFont = String(themeValue(themeData, "fonts", "mono_font", "JetBrainsMono Nerd Font"));
        editMonoFontSize = toIntValue(themeValue(themeData, "fonts", "mono_font_size", 12), 12);
        editDisplayFont = String(themeValue(themeData, "fonts", "display_font", editUiFont));
        editFontWeight = String(themeValue(themeData, "fonts", "font_weight", "regular"));
        editLetterSpacing = toFloatString(themeValue(themeData, "fonts", "letter_spacing", 0.0), 0.0);

        editIconTheme = String(themeValue(themeData, "icons", "icon_theme", "Papirus-Dark"));
        editSchemeType = normalizeOption(
            themeValue(themeData, "matugen", "scheme_type", "scheme-tonal-spot"),
            schemeOptions,
            "scheme-tonal-spot"
        );
        editColorIndex = Math.max(0, toIntValue(themeValue(themeData, "matugen", "color_index", 0), 0));
        editContrast = toFloatString(themeValue(themeData, "matugen", "contrast", 0.0), 0.0);
        editMode = normalizeOption(
            themeValue(themeData, "matugen", "mode", "dark"),
            modeOptions,
            "dark"
        );
        editBarHeight = Math.max(30, toIntValue(themeValue(themeData, "quickshell", "bar_height", 40), 40));
        editBarPosition = normalizeOption(
            themeValue(themeData, "quickshell", "bar_position", "top"),
            barPositionOptions,
            "top"
        );
        editBarTemplate = derivedBarTemplate(editBarPosition, themeValue(themeData, "bar", "template", "auto"));
        editBarWidthMode = normalizeOption(
            themeValue(themeData, "bar", "width_mode", "full"),
            barWidthModeOptions,
            "full"
        );
        editBarShape = normalizeOption(
            themeValue(themeData, "bar", "shape", "rounded"),
            barShapeOptions,
            "rounded"
        );
        editBarTopEdgeStyle = normalizeOption(
            themeValue(themeData, "bar", "top_edge_style", "soft"),
            barEdgeStyleOptions,
            "soft"
        );
        editBarBottomEdgeStyle = normalizeOption(
            themeValue(themeData, "bar", "bottom_edge_style", "soft"),
            barEdgeStyleOptions,
            "soft"
        );
        editClockStyle = normalizeOption(
            themeValue(themeData, "bar", "clock_style", "digital"),
            clockStyleOptions,
            "digital"
        );
        editTopbarLooseBlocks = defaultTopbarLooseBlocks(themeData, safeThemeId);
        editBarRailEnabled = themeValue(themeData, "quickshell", "bar_rail_enabled", false) === true;
        editBarRailEdge = normalizeOption(themeValue(themeData, "quickshell", "bar_rail_edge", "left"), barPositionOptions, "left");
        editBarRailWidth = Math.max(44, toIntValue(themeValue(themeData, "quickshell", "bar_rail_width", 52), 52));
        editBarStatusStripEnabled = themeValue(themeData, "quickshell", "bar_status_strip_enabled", true) !== false;
        editBarStatusStripEdge = normalizeOption(themeValue(themeData, "quickshell", "bar_status_strip_edge", editBarPosition), barPositionOptions, editBarPosition);
        editBarStatusStripHeight = Math.max(30, toIntValue(themeValue(themeData, "quickshell", "bar_status_strip_height", editBarHeight), editBarHeight));

        editBarOpacity = toFloatString(themeValue(themeData, "appearance", "bar_opacity", 0.72), 0.72);
        editPopupOpacity = toFloatString(themeValue(themeData, "appearance", "popup_opacity", 0.80), 0.80);
        editAnimationSpeed = toFloatString(themeValue(themeData, "appearance", "animation_speed", 0.75), 0.75);
        editOverlayOpacity = toFloatString(themeValue(themeData, "material", "overlay_opacity", 0.06), 0.06);
        editGlowIntensity = toFloatString(themeValue(themeData, "material", "glow_intensity", 0.04), 0.04);
        editParticleType = normalizeOption(
            String(themeValue(themeData, "effects", "particles", "none")),
            particleTypeOptions,
            "none"
        );
        editParticleCount = Math.max(0, toIntValue(themeValue(themeData, "effects", "particle_count", 0), 0));
        editParticleSpeed = toFloatString(themeValue(themeData, "effects", "particle_speed", 0.18), 0.18);
        editAmbientEffect = normalizeOption(
            themeValue(themeData, "effects", "ambient_effect", "theme-default"),
            ambientEffectOptions,
            "theme-default"
        );
        editEffectIntensity = toFloatString(themeValue(themeData, "effects", "effect_intensity", 1.0), 1.0);
        editEffectCycleMs = Math.max(0, toIntValue(themeValue(themeData, "effects", "effect_cycle_ms", 0), 0));
        editHoverReactivity = toFloatString(themeValue(themeData, "effects", "hover_reactivity", 0.4), 0.4);

        editStyleFamily = normalizeOption(themeValue(themeData, "style_profile", "family", safeThemeId), styleFamilyOptions, "organic");
        editStyleDensity = normalizeOption(themeValue(themeData, "style_profile", "density", "comfortable"), styleDensityOptions, "comfortable");
        editSurfaceMode = normalizeOption(themeValue(themeData, "style_profile", "surface_mode", "soft-glass"), surfaceModeOptions, "soft-glass");
        editStyleMotion = normalizeOption(themeValue(themeData, "style_profile", "motion", "gentle"), styleMotionOptions, "gentle");
        editPanelShadow = toFloatString(themeValue(themeData, "style_profile", "panel_shadow", 0.22), 0.22);
        editOutlineStrength = toFloatString(themeValue(themeData, "style_profile", "outline_strength", 0.18), 0.18);
        editGlassStrength = toFloatString(themeValue(themeData, "style_profile", "glass_strength", 0.10), 0.10);
        editWidgetRadius = Math.max(4, toIntValue(themeValue(themeData, "style_profile", "widget_radius", 16), 16));
        editPanelPadding = Math.max(6, toIntValue(themeValue(themeData, "style_profile", "panel_padding", 14), 14));

        editDrawerStyle = normalizeOption(themeValue(themeData, "bar_dynamics", "drawer_style", "context-card"), drawerStyleOptions, "context-card");
        editModuleDensity = normalizeOption(themeValue(themeData, "bar_dynamics", "module_density", "balanced"), moduleDensityOptions, "balanced");
        editWorkspacePreview = normalizeOption(themeValue(themeData, "bar_dynamics", "workspace_preview", "hybrid"), workspacePreviewOptions, "hybrid");
        editRailAccent = normalizeOption(themeValue(themeData, "bar_dynamics", "rail_accent", "none"), railAccentOptions, "none");
        themeLoadedSignature = currentThemeSignature();
        setThemeStatus("Geladen uit " + safeThemeId + ".toml", "info");
    }

    function saveThemeEdits() {
        if (themeEditThemeId === "") {
            notify("Theme", "Geen geldig theme geselecteerd");
            return;
        }
        if (themeSaveBusy) return;

        themeSaveBusy = true;
        themeSaveError = "";
        setThemeStatus("Opslaan naar " + themeEditThemeId + ".toml...", "info");

        let cmd = [
            root.themeUpdateSafeCmd,
            themeEditThemeId,
            "appearance.border_radius", String(Math.max(0, editBorderRadius)),
            "appearance.border_width", String(Math.max(0, editBorderWidth)),
            "appearance.gaps_in", String(Math.max(0, editGapsIn)),
            "appearance.gaps_out", String(Math.max(0, editGapsOut)),
            "appearance.blur_size", String(Math.max(0, editBlurSize)),
            "appearance.blur_passes", String(Math.max(0, editBlurPasses)),
            "fonts.ui_font", String(editUiFont || "Inter"),
            "fonts.ui_font_size", String(Math.max(8, editUiFontSize)),
            "fonts.mono_font", String(editMonoFont || "JetBrainsMono Nerd Font"),
            "fonts.mono_font_size", String(Math.max(8, editMonoFontSize)),
            "fonts.display_font", String(editDisplayFont || editUiFont || "Inter"),
            "fonts.font_weight", String(editFontWeight || "regular"),
            "fonts.letter_spacing", toFloatString(editLetterSpacing, 0.0),
            "icons.icon_theme", String(editIconTheme || "Papirus-Dark"),
            "matugen.scheme_type", normalizeOption(editSchemeType, schemeOptions, "scheme-tonal-spot"),
            "matugen.color_index", String(Math.max(0, editColorIndex)),
            "matugen.contrast", toFloatString(editContrast, 0.0),
            "matugen.mode", normalizeOption(editMode, modeOptions, "dark"),
            "quickshell.bar_height", String(Math.max(30, editBarHeight)),
            "quickshell.bar_position", normalizeOption(editBarPosition, barPositionOptions, "top"),
            "quickshell.bar_rail_enabled", String(!!editBarRailEnabled),
            "quickshell.bar_rail_edge", normalizeOption(editBarRailEdge, barPositionOptions, "left"),
            "quickshell.bar_rail_width", String(Math.max(44, editBarRailWidth)),
            "quickshell.bar_status_strip_enabled", String(!!editBarStatusStripEnabled),
            "quickshell.bar_status_strip_edge", normalizeOption(editBarStatusStripEdge, barPositionOptions, "top"),
            "quickshell.bar_status_strip_height", String(Math.max(30, editBarStatusStripHeight)),
            "bar.template", derivedBarTemplate(editBarPosition, editBarTemplate),
            "bar.width_mode", normalizeOption(editBarWidthMode, barWidthModeOptions, "full"),
            "bar.floating", String(editBarWidthMode === "floating"),
            "bar.attach_to_screen_edge", String(editBarWidthMode !== "floating"),
            "bar.shape", normalizeOption(editBarShape, barShapeOptions, "rounded"),
            "bar.top_edge_style", normalizeOption(editBarTopEdgeStyle, barEdgeStyleOptions, "soft"),
            "bar.bottom_edge_style", normalizeOption(editBarBottomEdgeStyle, barEdgeStyleOptions, "soft"),
            "bar.clock_style", normalizeOption(editClockStyle, clockStyleOptions, "digital"),
            "bar.topbar_loose_blocks", String(!!editTopbarLooseBlocks),
            "appearance.bar_opacity", toFloatString(editBarOpacity, 0.72),
            "appearance.popup_opacity", toFloatString(editPopupOpacity, 0.80),
            "appearance.animation_speed", toFloatString(editAnimationSpeed, 0.75),
            "material.overlay_opacity", toFloatString(editOverlayOpacity, 0.06),
            "material.glow_intensity", toFloatString(editGlowIntensity, 0.04),
            "effects.particles", String(editParticleType || "none"),
            "effects.particle_count", String(Math.max(0, editParticleCount)),
            "effects.particle_speed", toFloatString(editParticleSpeed, 0.18),
            "effects.ambient_effect", normalizeOption(editAmbientEffect, ambientEffectOptions, "theme-default"),
            "effects.effect_intensity", toFloatString(editEffectIntensity, 1.0),
            "effects.effect_cycle_ms", String(Math.max(0, editEffectCycleMs)),
            "effects.hover_reactivity", toFloatString(editHoverReactivity, 0.4),
            "style_profile.family", normalizeOption(editStyleFamily, styleFamilyOptions, "organic"),
            "style_profile.density", normalizeOption(editStyleDensity, styleDensityOptions, "comfortable"),
            "style_profile.surface_mode", normalizeOption(editSurfaceMode, surfaceModeOptions, "soft-glass"),
            "style_profile.motion", normalizeOption(editStyleMotion, styleMotionOptions, "gentle"),
            "style_profile.panel_shadow", toFloatString(editPanelShadow, 0.22),
            "style_profile.outline_strength", toFloatString(editOutlineStrength, 0.18),
            "style_profile.glass_strength", toFloatString(editGlassStrength, 0.10),
            "style_profile.widget_radius", String(Math.max(4, editWidgetRadius)),
            "style_profile.panel_padding", String(Math.max(6, editPanelPadding)),
            "bar_dynamics.drawer_style", normalizeOption(editDrawerStyle, drawerStyleOptions, "context-card"),
            "bar_dynamics.module_density", normalizeOption(editModuleDensity, moduleDensityOptions, "balanced"),
            "bar_dynamics.workspace_preview", normalizeOption(editWorkspacePreview, workspacePreviewOptions, "hybrid"),
            "bar_dynamics.rail_accent", normalizeOption(editRailAccent, railAccentOptions, "none")
        ];

        themeWriteProc.themeId = themeEditThemeId;
        themeWriteProc.applyAfterSave = (themeEditThemeId === activeThemeId);
        themeWriteProc.command = cmd;
        themeWriteProc.running = true;
    }

    function reloadTopbar() {
        if (topbarReloadBusy) return;
        topbarReloadBusy = true;
        topbarReloadError = "";

        topbarReloadProc.command = [
            "bash", "-lc",
            "if ! command -v quickshell >/dev/null 2>&1; then echo 'quickshell niet gevonden' >&2; exit 1; fi; " +
            "if [ ! -f \"$HOME/.config/quickshell/TopBar.qml\" ]; then echo 'TopBar.qml niet gevonden' >&2; exit 1; fi; " +
            "pkill -f 'quickshell.*[T]opBar.qml' >/dev/null 2>&1 || true; " +
            "sleep 0.2; " +
            "export QML_IMPORT_PATH=\"$HOME/.local/lib/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}\"; " +
            "nohup quickshell -p \"$HOME/.config/quickshell/TopBar.qml\" >/dev/null 2>&1 &"
        ];
        topbarReloadProc.running = true;
    }

    function applyTopbarEdits() {
        if (themeEditThemeId !== "" && themeDirty) {
            saveThemeEdits();
            return;
        }
        reloadTopbar();
    }

    function refreshOperationalStatus() {
        refreshDisplayStatus();
        networkStatusProc.running = true;
        refreshAudioState();
        sessionModeProc.running = true;
        powerProfileProc.running = true;
        updatesStatusProc.running = true;
    }

    function refreshDisplayStatus() {
        displayStatusProc.running = true;
        displayLayoutProc.running = true;
        displayTouchProc.running = true;
        displayBrightnessProc.running = true;
        workspaceMonitorLoadProc.running = true;
        primaryDisplayLoadProc.running = true;
    }

    function openShellWidget(name, subtarget) {
        let args = ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", name];
        if (subtarget && String(subtarget) !== "") args.push(String(subtarget));
        Quickshell.execDetached(args);
    }

    function lockSession() {
        Quickshell.execDetached(["bash", "-lc", "if [ -x \"$HOME/.config/hypr/scripts/lock.sh\" ]; then \"$HOME/.config/hypr/scripts/lock.sh\"; else loginctl lock-session; fi"]);
    }

    function refreshAudioState() {
        audioStateProc.running = true;
        audioStatusProc.running = true;
    }

    function audioPrimaryNode(list) {
        let nodes = list || [];
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i] && nodes[i].is_default) return nodes[i];
        }
        return nodes.length > 0 ? nodes[0] : null;
    }

    function audioIconFor(kind, node) {
        let text = String(((node && node.description) || "") + " " + ((node && node.name) || "")).toLowerCase();
        if (kind === "inputs") return "󰍬";
        if (kind === "apps") return "󰎆";
        if (text.indexOf("headset") >= 0 || text.indexOf("headphone") >= 0 || text.indexOf("earbud") >= 0) return "󰋋";
        if (text.indexOf("speaker") >= 0 || text.indexOf("monitor") >= 0) return "󰓃";
        return "󰕾";
    }

    function audioSummaryText(kind, node) {
        if (!node) return kind === "inputs" ? "Geen input gevonden" : "Geen output gevonden";
        let line = String(node.description || node.name || "Onbekend apparaat");
        let meta = [];
        meta.push(String(Math.max(0, Number(node.volume) || 0)) + "%");
        if (node.mute) meta.push("muted");
        if (!node.is_default) meta.push("niet standaard");
        if (node.name && node.name !== node.description) meta.push(String(node.name));
        return line + "\n" + meta.join("  ");
    }

    function setAudioVolume(type, id, value) {
        let safePct = Math.max(0, Math.min(150, Math.round(Number(value) || 0)));
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/volume/audio_control.sh", "set-volume", type, String(id), String(safePct)]);
        audioRefreshDelay.restart();
    }

    function toggleAudioMute(type, id) {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/volume/audio_control.sh", "toggle-mute", type, String(id)]);
        audioRefreshDelay.restart();
    }

    function setDefaultAudioDevice(type, id, name) {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/volume/audio_control.sh", "set-default", type, String(id), String(name)]);
        audioRefreshDelay.restart();
    }

    function switchSessionMode(modeName) {
        let safeMode = String(modeName || "office");
        Quickshell.execDetached(["bash", "-lc", "if command -v kingstra-mode-switch >/dev/null 2>&1; then kingstra-mode-switch '" + shellSingleQuote(safeMode) + "'; else '$HOME/.config/shared/scripts/kingstra-mode-switch' '" + shellSingleQuote(safeMode) + "'; fi"]);
        sessionModeText = safeMode;
        notify("Session", "Mode ingesteld: " + safeMode);
        sessionModeRefreshTimer.start();
    }

    function restoreDisplayLayout() {
        Quickshell.execDetached(["bash", "-lc", "'" + monitorRestoreScript + "' --once"]);
        notify("Display", "Opgeslagen layout wordt opnieuw toegepast");
        displayRefreshTimer.start();
    }

    function updateWorkspaceMonitorSummary() {
        let assigned = [];
        for (let i = 0; i < workspaceMonitorModel.count; i++) {
            let row = workspaceMonitorModel.get(i);
            if (row.monitor && String(row.monitor) !== "") {
                assigned.push(String(row.ws) + " -> " + String(row.monitor));
            }
        }
        workspaceMonitorText = assigned.length > 0
            ? assigned.join("  •  ")
            : "Geen vaste toewijzingen. Alle workspaces zijn vrij.";
    }

    function setWorkspaceMonitorRows(data, keepDirty) {
        let monitors = (data && Array.isArray(data.monitors)) ? data.monitors : [];
        let options = ["Vrij"];
        for (let i = 0; i < monitors.length; i++) {
            let name = String(monitors[i] || "");
            if (name !== "" && options.indexOf(name) < 0) options.push(name);
        }

        let rows = (data && Array.isArray(data.workspaces)) ? data.workspaces : [];
        for (let r = 0; r < rows.length; r++) {
            let monitor = String(rows[r].monitor || "");
            if (monitor !== "" && options.indexOf(monitor) < 0) options.push(monitor);
        }

        workspaceMonitorOptions = options;
        workspaceMonitorModel.clear();
        for (let ws = 1; ws <= 10; ws++) {
            let assigned = "";
            for (let j = 0; j < rows.length; j++) {
                if (Number(rows[j].id) === ws) {
                    assigned = String(rows[j].monitor || "");
                    break;
                }
            }
            workspaceMonitorModel.append({ ws: ws, monitor: assigned });
        }
        workspaceMonitorDirty = keepDirty === true ? workspaceMonitorDirty : false;
        updateWorkspaceMonitorSummary();
    }

    function setWorkspaceMonitorAssignment(index, monitorName) {
        if (index < 0 || index >= workspaceMonitorModel.count) return;
        let next = String(monitorName || "");
        let current = String(workspaceMonitorModel.get(index).monitor || "");
        if (current === next) return;
        workspaceMonitorModel.setProperty(index, "monitor", next);
        workspaceMonitorDirty = true;
        updateWorkspaceMonitorSummary();
    }

    function saveWorkspaceMonitorAssignments() {
        let args = ["bash", workspaceMonitorScript, "save"];
        for (let i = 0; i < workspaceMonitorModel.count; i++) {
            let row = workspaceMonitorModel.get(i);
            args.push(String(row.ws) + "=" + String(row.monitor || ""));
        }
        workspaceMonitorSaveProc.command = args;
        workspaceMonitorSaveProc.running = true;
    }

    function applyPrimaryDisplayState(data) {
        let monitors = (data && Array.isArray(data.monitors)) ? data.monitors : [];
        let options = ["Automatisch (gefocusd)"];
        for (let i = 0; i < monitors.length; i++) {
            let name = String((monitors[i] && monitors[i].name) || "");
            if (name !== "" && options.indexOf(name) < 0) options.push(name);
        }
        primaryDisplayOptions = options;
        primaryDisplayName = String((data && data.primary) || "");
        primaryDisplayEffective = String((data && data.effective) || "");
    }

    function setPrimaryDisplay(displayName) {
        let selected = displayName === "Automatisch (gefocusd)" ? "" : String(displayName || "");
        primaryDisplaySaveProc.command = ["bash", primaryDisplayScript, "set", selected];
        primaryDisplaySaveProc.running = true;
    }

    function toggleTabletMode() {
        Quickshell.execDetached(["bash", "-lc", "'" + tabletModeScript + "' toggle"]);
        notify("Display", "Tabletmodus wordt gewisseld");
        displayRefreshTimer.start();
    }

    function adjustBrightness(delta) {
        let step = Math.max(1, Math.abs(delta || 5));
        let direction = (delta || 0) >= 0 ? "+" : "";
        Quickshell.execDetached(["bash", "-lc", "if command -v brightnessctl >/dev/null 2>&1; then brightnessctl set '" + direction + step + "%' >/dev/null 2>&1; fi"]);
        displayRefreshTimer.start();
    }

    function runPackageUpgrade() {
        Quickshell.execDetached(["kitty", "--class", "kingstra-update", "--title", "Kingstra update", "bash", Quickshell.env("HOME") + "/.config/quickshell/package_upgrade.sh"]);
        updateResultWatch.start();
    }

    function refreshUpdatePage(search) {
        updatePlanCacheProc.running = true;
        updateResultProc.running = true;
        healthProc.running = true;
        if (search || !upPlan.checked || (Date.now() / 1000 - upPlan.checked) > 900) {
            upPlanBusy = true;
            updatePlanProc.running = true;
        }
    }

    function runSystemRollback() {
        Quickshell.execDetached(["kitty", "--class", "kingstra-update", "--title", "Update terugdraaien", "--hold", "bash", "-lc", "'" + kingstraBin + "kingstra-rollback' --system"]);
    }

    function openRescueMenu() {
        Quickshell.execDetached(["kitty", "--class", "kingstra-update", "--title", "Kingstra herstel", "bash", "-lc", "'" + kingstraBin + "kingstra-herstel'"]);
    }

    function refreshSpacePage(full) {
        if (!full && !spaceData.checked) spaceCachedProc.running = true;
        if (full || !spaceData.checked || (Date.now() / 1000 - spaceData.checked) > 600) {
            spaceBusy = true;
            spaceMeasureProc.running = true;
        }
    }

    function spaceClean(item) {
        if (!item) return;
        if (item.sudo) {
            // Wachtwoord nodig: in een terminal, daarna opnieuw meten.
            Quickshell.execDetached(["kitty", "--class", "kingstra-update", "--title", "Ruimte maken: " + item.label, "bash", "-lc",
                "cmd=$('" + kingstraBin + "kingstra-ruimte' --sudo-cmd " + item.id + ") && echo \"$cmd\" && eval \"$cmd\"; '" + kingstraBin + "kingstra-ruimte' --json >/dev/null; echo; read -rp 'Klaar. Enter sluit dit venster.' _"]);
            spaceAfterTimer.restart();
            return;
        }
        spaceCleaning = item.id;
        spaceCleanProc.command = [kingstraBin + "kingstra-ruimte", "--clean", item.id];
        spaceCleanProc.running = true;
    }

    function refreshBackupPage() {
        backupStatusProc.running = true;
        healthProc.running = true;
    }

    function backupAction(action) {
        if (action === "run") {
            Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "kingstra-backup.service"]);
            bkStatus = Object.assign({}, bkStatus, { running: true });
        } else if (action === "copy") {
            Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "kingstra-backup-copy.service"]);
            notify("Back-up", "Tweede kopie wordt bijgewerkt");
        } else {
            Quickshell.execDetached([kingstraBin + "kingstra-backup", action]);
        }
        backupRefreshTimer.restart();
    }

    function fmtWhen(ts) {
        if (!ts) return "nog nooit";
        let d = new Date(ts * 1000);
        let mins = Math.round((Date.now() - d.getTime()) / 60000);
        if (mins < 2) return "zojuist";
        if (mins < 60) return mins + " minuten geleden";
        if (mins < 1440) return Math.round(mins / 60) + " uur geleden";
        return Qt.formatDateTime(d, "d MMM HH:mm");
    }

    function fmtBytes(n) {
        let v = Number(n || 0);
        let units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
        return (i === 0 ? v : v.toFixed(1)) + " " + units[i];
    }

    function upGroupLine(item) {
        if (item.from && item.to) return item.name + "  " + item.from + " → " + item.to;
        if (item.to) return item.name + "  " + item.to;
        return item.name;
    }

    function restartQuickshell() {
        advancedStatusText = "Quickshell herstart aangevraagd";
        Quickshell.execDetached(["bash", "-lc", "pkill -f 'quickshell.*TopBar.qml' >/dev/null 2>&1 || true; pkill -f 'quickshell.*Main.qml' >/dev/null 2>&1 || true; sleep 0.3; export QML_IMPORT_PATH=\"$HOME/.local/lib/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}\"; quickshell -p '$HOME/.config/quickshell/TopBar.qml' >/dev/null 2>&1 & quickshell -p '$HOME/.config/quickshell/Main.qml' >/dev/null 2>&1 &"]);
        notify("Advanced", "Quickshell wordt herstart");
    }

    function rerenderTheme() {
        advancedStatusText = "Theme render aangevraagd";
        Quickshell.execDetached(["bash", "-lc", "if command -v kingstra-matugen-run >/dev/null 2>&1; then kingstra-matugen-run; elif [ -x '$HOME/.local/bin/kingstra-matugen-run' ]; then '$HOME/.local/bin/kingstra-matugen-run'; else '$HOME/.config/shared/scripts/kingstra-matugen-run'; fi"]);
        notify("Advanced", "Matugen render gestart");
    }

    function resetThemeEdits() {
        if (themeCarousel.selectedThemeId !== "" && themeCarousel.selectedThemeData) {
            themeLoadedSignature = "";
            loadThemeEditForm(themeCarousel.selectedThemeData, themeCarousel.selectedThemeId);
            setThemeStatus("Wijzigingen hersteld naar laatst geladen waarden", "info");
        }
    }

    function stringifyThemeValue(value) {
        if (value === undefined || value === null) return "—";
        if (typeof value === "string") return value;
        if (typeof value === "number" || typeof value === "boolean") return String(value);
        try { return JSON.stringify(value); } catch (e) {}
        return String(value);
    }

    function flattenThemeData(themeData) {
        let out = [];

        function walk(node, prefix) {
            if (node === undefined || node === null) return;

            if (Array.isArray(node)) {
                out.push({ key: prefix, value: root.stringifyThemeValue(node) });
                return;
            }

            if (typeof node === "object") {
                let keys = Object.keys(node);
                keys.sort();
                for (let i = 0; i < keys.length; i++) {
                    let key = keys[i];
                    let child = node[key];
                    let nextPrefix = prefix ? (prefix + "." + key) : key;
                    if (child !== null && typeof child === "object" && !Array.isArray(child)) {
                        walk(child, nextPrefix);
                    } else {
                        out.push({ key: nextPrefix, value: root.stringifyThemeValue(child) });
                    }
                }
                return;
            }

            out.push({ key: prefix, value: root.stringifyThemeValue(node) });
        }

        walk(themeData || {}, "");
        out.sort(function(a, b) { return String(a.key).localeCompare(String(b.key)); });
        return out;
    }

    function scrollFlickableByWheel(flickable, wheel) {
        if (!flickable || flickable.contentHeight === undefined || flickable.height === undefined) return false;

        let deltaY = 0;
        let hasPixelDelta = false;
        if (wheel && wheel.pixelDelta !== undefined && Number(wheel.pixelDelta.y) !== 0) {
            deltaY = Number(wheel.pixelDelta.y);
            hasPixelDelta = true;
        } else if (wheel && wheel.angleDelta !== undefined) {
            deltaY = Number(wheel.angleDelta.y);
        } else {
            deltaY = Number(wheel);
        }

        if (!deltaY || deltaY === 0) return false;

        let maxY = Math.max(0, Number(flickable.contentHeight) - Number(flickable.height));
        if (maxY <= 0) return false;

        // 120 angle units ~= one mouse-wheel notch. Pixel deltas come from touchpads.
        let travel = hasPixelDelta
            ? -deltaY * 1.15
            : -(deltaY / 120.0) * root.s(156);
        let nextY = Number(flickable.contentY) + travel;
        if (isNaN(nextY)) return false;

        flickable.contentY = Math.max(0, Math.min(maxY, nextY));
        return true;
    }

    component ThemedComboBox : ComboBox {
        id: combo
        implicitHeight: root.s(34)
        Layout.fillWidth: true
        Layout.preferredWidth: root.s(220)
        Layout.maximumWidth: root.s(300)
        font.family: root.uiFontFamily
        font.pixelSize: root.s(11)
        leftPadding: root.s(10)
        rightPadding: root.s(28)

        contentItem: Text {
            text: combo.displayText
            font: combo.font
            color: root.text
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            leftPadding: combo.leftPadding
            rightPadding: combo.rightPadding
        }

        indicator: Text {
            x: combo.width - width - root.s(10)
            y: (combo.height - height) / 2
            text: "󰅀"
            font.family: ThemeConfig.iconFont
            font.pixelSize: root.s(13)
            color: combo.hovered || combo.visualFocus ? root.blue : root.subtext0
        }

        background: Rectangle {
            radius: root.s(8)
            color: Qt.alpha(root.surface0, 0.78)
            border.width: 1
            border.color: combo.visualFocus ? root.blue : (combo.hovered ? Qt.alpha(root.surface2, 0.95) : Qt.alpha(root.surface2, 0.78))
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(120) } }
        }

        delegate: ItemDelegate {
            width: combo.width
            implicitHeight: root.s(32)
            font: combo.font
            highlighted: combo.highlightedIndex === index
            text: modelData !== undefined ? String(modelData) : ""
            padding: root.s(8)

            contentItem: Text {
                text: parent.text
                font: combo.font
                color: parent.highlighted ? root.base : root.text
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: root.s(6)
                color: parent.highlighted ? root.blue : Qt.alpha(root.surface0, 0.52)
            }
        }

        popup: Popup {
            y: combo.height + root.s(4)
            width: combo.width
            padding: root.s(4)
            implicitHeight: Math.min(root.s(220), contentItem.implicitHeight + root.s(8))

            background: Rectangle {
                radius: root.s(8)
                color: Qt.alpha(root.mantle, 0.96)
                border.color: root.surface2
                border.width: 1
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }
        }
    }

    component ThemedSpinBox : SpinBox {
        id: spin
        implicitHeight: root.s(34)
        Layout.fillWidth: true
        Layout.preferredWidth: root.s(220)
        Layout.maximumWidth: root.s(300)
        font.family: root.uiFontFamily
        font.pixelSize: root.s(11)
        leftPadding: root.s(8)
        rightPadding: root.s(28)
        editable: true
        // Eigen knoppen en tekstinvoer zetten value zelf; dan stuurt SpinBox
        // geen valueModified. Dat doen we hier, anders slaan velden met
        // onValueModified (kommagetallen, procenten) nooit iets op.
        function stepUp() {
            spin.value = Math.min(spin.to, spin.value + spin.stepSize)
            spin.valueModified()
        }
        function stepDown() {
            spin.value = Math.max(spin.from, spin.value - spin.stepSize)
            spin.valueModified()
        }

        contentItem: TextInput {
            z: 1
            text: spin.textFromValue(spin.value, spin.locale)
            font: spin.font
            color: root.text
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            readOnly: !spin.editable
            validator: spin.validator
            selectByMouse: true
            selectionColor: Qt.alpha(root.blue, 0.35)
            selectedTextColor: root.text
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            onTextEdited: {
                spin.value = spin.valueFromText(text, spin.locale)
                spin.valueModified()
            }
        }

        up.indicator: Rectangle {
            z: 3
            x: spin.width - width - root.s(5)
            y: root.s(4)
            implicitWidth: root.s(18)
            implicitHeight: (spin.height / 2) - root.s(5)
            radius: root.s(4)
            color: upMa.containsMouse ? Qt.alpha(root.blue, 0.24) : Qt.alpha(root.surface1, 0.74)
            border.width: 1
            border.color: upMa.containsMouse ? root.blue : Qt.alpha(root.surface2, 0.82)
            Text {
                anchors.centerIn: parent
                text: "+"
                font.family: ThemeConfig.textFont
                font.weight: Font.Bold
                font.pixelSize: root.s(11)
                color: upMa.containsMouse ? root.blue : root.subtext0
            }
            MouseArea {
                id: upMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: spin.stepUp()
            }
        }

        down.indicator: Rectangle {
            z: 3
            x: spin.width - width - root.s(5)
            y: spin.height - height - root.s(4)
            implicitWidth: root.s(18)
            implicitHeight: (spin.height / 2) - root.s(5)
            radius: root.s(4)
            color: downMa.containsMouse ? Qt.alpha(root.blue, 0.24) : Qt.alpha(root.surface1, 0.74)
            border.width: 1
            border.color: downMa.containsMouse ? root.blue : Qt.alpha(root.surface2, 0.82)
            Text {
                anchors.centerIn: parent
                text: "−"
                font.family: ThemeConfig.textFont
                font.weight: Font.Bold
                font.pixelSize: root.s(11)
                color: downMa.containsMouse ? root.blue : root.subtext0
            }
            MouseArea {
                id: downMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: spin.stepDown()
            }
        }

        background: Rectangle {
            radius: root.s(8)
            color: Qt.alpha(root.surface0, 0.78)
            border.width: 1
            border.color: spin.visualFocus ? root.blue : (spin.hovered ? Qt.alpha(root.surface2, 0.95) : Qt.alpha(root.surface2, 0.78))
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(120) } }
        }
    }

    component SettingsActionButton : Rectangle {
        id: actionButton
        property string label: "Actie"
        property string icon: "󰐊"
        property color accent: root.blue
        property bool primary: false
        signal triggered()

        implicitWidth: root.s(190)
        implicitHeight: root.s(38)
        Layout.preferredHeight: implicitHeight
        Layout.preferredWidth: implicitWidth
        radius: root.s(8)
        color: primary
               ? (buttonMa.containsMouse ? Qt.alpha(accent, 0.88) : accent)
               : (buttonMa.containsMouse ? Qt.alpha(accent, 0.18) : Qt.alpha(root.surface0, 0.62))
        border.width: primary ? 0 : 1
        border.color: buttonMa.containsMouse ? accent : root.surface2
        scale: buttonMa.pressed ? 0.97 : (buttonMa.containsMouse ? 1.01 : 1.0)

        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }

        RowLayout {
            anchors.centerIn: parent
            spacing: root.s(7)
            Text {
                text: actionButton.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: root.s(15)
                color: actionButton.primary ? root.base : actionButton.accent
            }
            Text {
                text: actionButton.label
                font.family: root.uiFontFamily
                font.weight: Font.Bold
                font.letterSpacing: root.themedLetterSpacing
                font.pixelSize: root.s(11)
                color: actionButton.primary ? root.base : root.text
            }
        }

        MouseArea {
            id: buttonMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.triggered()
        }
    }

    component SettingsInfoCard : Rectangle {
        id: infoCard
        property string title: ""
        property string value: ""
        property string icon: "󰋼"
        property color accent: root.blue

        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + root.s(24)
        radius: root.s(10)
        color: Qt.alpha(root.surface0, 0.46)
        border.color: Qt.alpha(root.surface2, 0.82)
        border.width: 1

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)
                Text { text: infoCard.icon; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17); color: infoCard.accent }
                Text { text: infoCard.title; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(14); color: root.text; Layout.fillWidth: true }
            }

            Text {
                text: infoCard.value
                font.family: root.uiFontFamily
                font.letterSpacing: root.themedLetterSpacing
                font.pixelSize: root.s(11)
                color: root.subtext0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Bouwstenen van de thema-editor ─────────────────────────────────
    // Eén blok per onderwerp, één regel per instelling met een korte uitleg.
    // Keuzes zijn ronde knoppen met Nederlandse namen in plaats van
    // uitklaplijsten met technische waarden.
    component EditorCard : Rectangle {
        id: editorCard
        property string heading: ""
        property string hint: ""
        property string glyph: "󰏘"
        default property alias rows: editorCardBody.data

        Layout.fillWidth: true
        implicitHeight: editorCardColumn.implicitHeight + root.s(30)
        radius: root.themedRadius
        color: Qt.alpha(root.surface0, 0.46)
        border.color: Qt.alpha(root.surface2, 0.82)
        border.width: 1

        ColumnLayout {
            id: editorCardColumn
            anchors.fill: parent
            anchors.margins: root.s(15)
            spacing: root.s(12)

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)
                Text { text: editorCard.glyph; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17); color: root.ambientPurple }
                Text { text: editorCard.heading; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(15); color: root.text; Layout.fillWidth: true }
            }
            Text {
                visible: editorCard.hint !== ""
                text: editorCard.hint
                font.family: root.uiFontFamily
                font.pixelSize: root.s(11)
                color: root.subtext0
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            ColumnLayout {
                id: editorCardBody
                Layout.fillWidth: true
                spacing: root.s(14)
            }
        }
    }

    component ChoiceRow : ColumnLayout {
        id: choiceRow
        property string label: ""
        property string hint: ""
        property var options: []
        property string current: ""
        signal picked(string choice)

        Layout.fillWidth: true
        spacing: root.s(6)

        Text { text: choiceRow.label; font.family: root.uiFontFamily; font.weight: Font.Medium; font.pixelSize: root.s(12); color: root.text; Layout.fillWidth: true }
        Flow {
            Layout.fillWidth: true
            spacing: root.s(6)
            Repeater {
                model: choiceRow.options
                Rectangle {
                    id: choiceChip
                    required property var modelData
                    readonly property bool chosen: choiceRow.current === String(modelData.v)
                    height: root.s(32)
                    width: choiceChipText.implicitWidth + root.s(28)
                    radius: height / 2
                    color: chosen ? Qt.alpha(root.ambientPurple, 0.22) : (choiceChipMa.containsMouse ? root.popupPanelFill : Qt.alpha(root.surface0, 0.55))
                    border.width: 1
                    border.color: chosen ? Qt.alpha(root.ambientPurple, 0.7) : root.surface1
                    scale: choiceChipMa.pressed ? 0.96 : 1.0
                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                    Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(150); easing.type: Easing.OutQuart } }
                    Text {
                        id: choiceChipText
                        anchors.centerIn: parent
                        text: choiceChip.modelData.t
                        font.family: root.uiFontFamily
                        font.pixelSize: root.s(11)
                        font.weight: choiceChip.chosen ? root.themedFontWeight : Font.Normal
                        color: choiceChip.chosen ? root.text : root.subtext0
                    }
                    MouseArea {
                        id: choiceChipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choiceRow.picked(String(choiceChip.modelData.v))
                    }
                }
            }
        }
        Text { visible: choiceRow.hint !== ""; text: choiceRow.hint; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }

    component NumberRow : ColumnLayout {
        id: numberRow
        property string label: ""
        property string hint: ""
        property int minimum: 0
        property int maximum: 100
        property int step: 1
        property int amount: 0
        signal edited(int newAmount)

        Layout.fillWidth: true
        spacing: root.s(4)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(10)
            Text { text: numberRow.label; font.family: root.uiFontFamily; font.weight: Font.Medium; font.pixelSize: root.s(12); color: root.text; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            ThemedSpinBox {
                from: numberRow.minimum
                to: numberRow.maximum
                stepSize: numberRow.step
                value: numberRow.amount
                onValueModified: numberRow.edited(value)
                Layout.fillWidth: false
                Layout.preferredWidth: root.s(150)
            }
        }
        Text { visible: numberRow.hint !== ""; text: numberRow.hint; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }

    component ListRow : ColumnLayout {
        id: listRow
        property string label: ""
        property string hint: ""
        property var choices: []
        property string current: ""
        // Een waarde uit het thema die niet in de lijst staat blijft zichtbaar.
        readonly property var shownChoices: current !== "" && choices.indexOf(current) < 0 ? [current].concat(choices) : choices
        signal picked(string choice)

        Layout.fillWidth: true
        spacing: root.s(4)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(10)
            Text { text: listRow.label; font.family: root.uiFontFamily; font.weight: Font.Medium; font.pixelSize: root.s(12); color: root.text; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            ThemedComboBox {
                model: listRow.shownChoices
                currentIndex: Math.max(0, listRow.shownChoices.indexOf(listRow.current))
                onActivated: listRow.picked(currentText)
                Layout.fillWidth: false
                Layout.preferredWidth: root.s(220)
            }
        }
        Text { visible: listRow.hint !== ""; text: listRow.hint; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }

    component AudioVolumeCard : Rectangle {
        id: volumeCard
        property string title: ""
        property string subtitle: ""
        property string icon: "󰕾"
        property color accent: root.blue
        property int volume: 0
        property bool muted: false
        property string audioType: "sink"
        property string audioId: ""
        property bool allowSetDefault: false
        property bool isDefault: false
        signal setDefaultRequested()

        Layout.fillWidth: true
        implicitHeight: audioCardLayout.implicitHeight + root.s(24)
        radius: root.s(10)
        color: Qt.alpha(root.surface0, 0.46)
        border.color: isDefault ? accent : Qt.alpha(root.surface2, 0.82)
        border.width: isDefault ? 2 : 1

        ColumnLayout {
            id: audioCardLayout
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(10)

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text { text: volumeCard.icon; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(18); color: volumeCard.accent }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(2)

                    Text {
                        text: volumeCard.title
                        font.family: root.displayFontFamily
                        font.weight: root.themedFontWeight
                        font.letterSpacing: root.themedLetterSpacing
                        font.pixelSize: root.s(14)
                        color: root.text
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: volumeCard.subtitle
                        font.family: root.uiFontFamily
                        font.pixelSize: root.s(11)
                        font.letterSpacing: root.themedLetterSpacing
                        color: root.subtext0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    text: volumeCard.muted ? "Muted" : (Math.max(0, Number(volumeCard.volume) || 0) + "%")
                    font.family: root.monoFontFamily
                    font.pixelSize: root.s(11)
                    color: volumeCard.muted ? root.peach : volumeCard.accent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(10)

                Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 150
                    value: Math.max(0, Math.min(150, Number(volumeCard.volume) || 0))
                    enabled: volumeCard.audioId !== ""

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                        width: volumeSlider.availableWidth
                        height: root.s(8)
                        radius: root.s(4)
                        color: Qt.alpha(root.surface1, 0.85)
                        border.width: 1
                        border.color: Qt.alpha(root.surface2, 0.82)

                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: volumeCard.muted ? Qt.alpha(root.surface2, 0.75) : volumeCard.accent
                        }
                    }

                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                        width: root.s(16)
                        height: root.s(16)
                        radius: root.s(8)
                        color: volumeCard.muted ? root.surface2 : Qt.lighter(volumeCard.accent, 1.15)
                        border.width: 1
                        border.color: volumeCard.accent
                    }

                    onMoved: root.setAudioVolume(volumeCard.audioType, volumeCard.audioId, value)
                }

                SettingsActionButton {
                    label: volumeCard.muted ? "Unmute" : "Mute"
                    icon: volumeCard.muted ? "󰖁" : "󰕾"
                    accent: root.peach
                    onTriggered: root.toggleAudioMute(volumeCard.audioType, volumeCard.audioId)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(10)
                visible: volumeCard.allowSetDefault

                Text {
                    text: volumeCard.isDefault ? "Actieve standaard" : "Klik om standaard te maken"
                    font.family: root.uiFontFamily
                    font.pixelSize: root.s(11)
                    color: volumeCard.isDefault ? root.green : root.subtext0
                    Layout.fillWidth: true
                }

                SettingsActionButton {
                    visible: !volumeCard.isDefault
                    label: "Maak standaard"
                    icon: "󰄬"
                    accent: volumeCard.accent
                    onTriggered: volumeCard.setDefaultRequested()
                }
            }
        }
    }

    Component.onCompleted: {
        // Laad keybinds via Process
        loadKeybindsProc.running = true;
        // Load weather .env values
        loadEnvProc.running = true;
        // Load active theme info
        refreshActiveTheme();
        refreshOperationalStatus();
        refreshCloseFully();
        startupSequence.start();
    }

    Process {
        id: displayStatusProc
        command: ["bash", "-lc", "'" + displayStatusScript + "' summary"]
        stdout: StdioCollector {
            onStreamFinished: root.displayStatusText = this.text.trim() || "Monitorstatus niet beschikbaar"
        }
    }

    Process {
        id: displayLayoutProc
        command: ["bash", "-lc", "'" + displayStatusScript + "' layout"]
        stdout: StdioCollector {
            onStreamFinished: root.displayLayoutText = this.text.trim() || "Display-layout niet beschikbaar"
        }
    }

    Process {
        id: displayTouchProc
        command: ["bash", "-lc", "'" + displayStatusScript + "' touch"]
        stdout: StdioCollector {
            onStreamFinished: root.displayTouchText = this.text.trim() || "Touch-profiel niet beschikbaar"
        }
    }

    Process {
        id: displayBrightnessProc
        command: ["bash", "-lc", "'" + displayStatusScript + "' brightness"]
        stdout: StdioCollector {
            onStreamFinished: root.displayBrightnessText = this.text.trim() || "Helderheid niet beschikbaar"
        }
    }

    Process {
        id: workspaceMonitorLoadProc
        command: ["bash", workspaceMonitorScript, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.setWorkspaceMonitorRows(JSON.parse(this.text || "{}"), false);
                } catch (e) {
                    root.workspaceMonitorText = "Workspace-toewijzingen niet beschikbaar";
                    workspaceMonitorModel.clear();
                    root.workspaceMonitorOptions = ["Vrij"];
                }
            }
        }
    }

    Process {
        id: workspaceMonitorSaveProc
        stdout: StdioCollector {
            onStreamFinished: {}
        }
        onRunningChanged: {
            root.workspaceMonitorSaveBusy = running;
            if (!running) {
                root.workspaceMonitorDirty = false;
                root.notify("Display", "Workspace-toewijzingen opgeslagen");
                root.refreshDisplayStatus();
            }
        }
    }

    Process {
        id: primaryDisplayLoadProc
        command: ["bash", primaryDisplayScript, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyPrimaryDisplayState(JSON.parse(this.text || "{}"));
                } catch (e) {
                    root.primaryDisplayOptions = ["Automatisch (gefocusd)"];
                    root.primaryDisplayName = "";
                    root.primaryDisplayEffective = "";
                }
            }
        }
    }

    Process {
        id: primaryDisplaySaveProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.applyPrimaryDisplayState(JSON.parse(this.text || "{}")); } catch (e) {}
            }
        }
        onRunningChanged: {
            root.primaryDisplaySaveBusy = running;
            if (!running) {
                root.notify("Display", root.primaryDisplayName === ""
                    ? "Hoofdscherm volgt de gefocuste monitor"
                    : "Hoofdscherm ingesteld op " + root.primaryDisplayName);
                primaryDisplayLoadProc.running = true;
            }
        }
    }

    Process {
        id: networkStatusProc
        command: ["bash", "-lc", "script=\"$HOME/.config/quickshell/network/wifi_panel_logic.sh\"; if [ -x \"$script\" ] && command -v jq >/dev/null 2>&1; then \"$script\" 2>/dev/null | jq -r 'if .power == \"off\" then \"Wifi uit\" elif .connected then \"Verbonden: \\(.connected.ssid)  \\(.connected.signal)%\" else \"Wifi aan, niet verbonden\" end' 2>/dev/null || echo 'Netwerkstatus niet leesbaar'; else echo 'NetworkManager helper niet beschikbaar'; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.networkStatusText = this.text.trim() || "Netwerkstatus niet beschikbaar"
        }
    }

    Process {
        id: audioStatusProc
        command: ["bash", "-lc", "script=\"$HOME/.config/quickshell/network/audio_panel_logic.sh\"; if [ -x \"$script\" ] && command -v jq >/dev/null 2>&1; then \"$script\" 2>/dev/null | jq -r 'if .connected then (.connected.name + \"  \" + .connected.volume + (if .connected.muted then \"  muted\" else \"\" end)) else \"Geen default audio device\" end' 2>/dev/null || echo 'Audiostatus niet leesbaar'; else echo 'Audio helper niet beschikbaar'; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.audioStatusText = this.text.trim() || "Audiostatus niet beschikbaar"
        }
    }

    Process {
        id: audioStateProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/volume/get_audio_state.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    root.audioOutputs = Array.isArray(data.outputs) ? data.outputs : [];
                    root.audioInputs = Array.isArray(data.inputs) ? data.inputs : [];
                    root.audioApps = Array.isArray(data.apps) ? data.apps : [];
                } catch (e) {
                    root.audioOutputs = [];
                    root.audioInputs = [];
                    root.audioApps = [];
                }
            }
        }
        onRunningChanged: root.audioStateBusy = running
    }

    Timer {
        id: displayRefreshTimer
        interval: 900
        repeat: false
        onTriggered: root.refreshDisplayStatus()
    }

    Timer {
        id: audioRefreshDelay
        interval: 180
        repeat: false
        onTriggered: root.refreshAudioState()
    }

    Timer {
        id: audioAutoRefreshTimer
        interval: 3000
        repeat: true
        running: root.currentPage === 8
        onTriggered: root.refreshAudioState()
    }

    // Apps die bij sluiten echt stoppen in plaats van naar de tray
    // (hypr/scripts/app-quit.sh beheert de lijst en beëindigt de processen).
    readonly property string appQuitScript: Quickshell.env("HOME") + "/.config/hypr/scripts/app-quit.sh"
    property var closeFullyList: []
    property var closeFullyOpenClasses: []

    function splitLines(text) {
        return String(text || "").split("\n").map(line => line.trim()).filter(line => line !== "");
    }
    function refreshCloseFully() {
        if (!closeFullyListProc.running) closeFullyListProc.running = true;
        if (!closeFullyClassesProc.running) closeFullyClassesProc.running = true;
    }
    function changeCloseFully(action, appClass) {
        let value = String(appClass || "").trim();
        if (value === "" || closeFullyEditProc.running) return;
        closeFullyEditProc.command = ["bash", appQuitScript, action, value];
        closeFullyEditProc.running = true;
    }
    function closeFullyCovers(appClass) {
        let lower = String(appClass || "").toLowerCase();
        for (let i = 0; i < closeFullyList.length; i++) {
            if (lower.indexOf(String(closeFullyList[i]).toLowerCase()) !== -1) return true;
        }
        return false;
    }

    Process {
        id: closeFullyListProc
        command: ["bash", root.appQuitScript, "list"]
        stdout: StdioCollector { onStreamFinished: root.closeFullyList = root.splitLines(this.text) }
    }

    Process {
        id: closeFullyClassesProc
        command: ["bash", root.appQuitScript, "classes"]
        stdout: StdioCollector { onStreamFinished: root.closeFullyOpenClasses = root.splitLines(this.text) }
    }

    Process {
        id: closeFullyEditProc
        onExited: root.refreshCloseFully()
    }

    Process {
        id: sessionModeProc
        command: ["bash", "-lc", "if command -v kingstra-mode-switch >/dev/null 2>&1; then kingstra-mode-switch --current; elif [ -x \"$HOME/.local/bin/kingstra-mode-switch\" ]; then \"$HOME/.local/bin/kingstra-mode-switch\" --current; else \"$HOME/.config/shared/scripts/kingstra-mode-switch\" --current; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.sessionModeText = this.text.trim() || "office"
        }
    }

    Process {
        id: powerProfileProc
        command: ["bash", "-lc", "if command -v powerprofilesctl >/dev/null 2>&1; then powerprofilesctl get 2>/dev/null; else echo balanced; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let profile = this.text.trim();
                if (profile !== "performance" && profile !== "power-saver") profile = "balanced";
                root.currentPowerProfileText = profile;
            }
        }
    }

    Process {
        id: updatesStatusProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/package_updates.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let count = this.text.trim();
                root.updateStatusText = count === "" ? "Updatecheck niet beschikbaar" : (count + " updates beschikbaar");
            }
        }
    }

    Process {
        id: updatePlanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/update_plan.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.upPlan = JSON.parse(this.text); } catch (e) {}
                root.upPlanBusy = false;
                if (root.upPlan.total !== undefined)
                    root.updateStatusText = root.upPlan.total === 0 ? "Alles is bij" : (root.upPlan.total + " updates klaar");
            }
        }
        onExited: root.upPlanBusy = false
    }

    Process {
        id: updatePlanCacheProc
        command: ["bash", "-c", "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/update-plan.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.upPlanBusy || this.text.trim() === "") return;
                try { root.upPlan = JSON.parse(this.text); } catch (e) {}
            }
        }
    }

    Process {
        id: updateResultProc
        command: ["bash", "-c", "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/update-result.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "") return;
                try {
                    let res = JSON.parse(this.text);
                    let changed = !root.upResult.time || res.time !== root.upResult.time;
                    root.upResult = res;
                    if (changed && updateResultWatch.running) {
                        updateResultWatch.stop();
                        root.refreshUpdatePage(true);
                    }
                } catch (e) {}
            }
        }
    }

    // Na "Bijwerken": kijk elke paar seconden of de terminal klaar is, en
    // ververs dan de pagina met de uitkomst.
    Timer {
        id: updateResultWatch
        interval: 4000
        repeat: true
        property int ticks: 0
        onRunningChanged: if (running) ticks = 0
        onTriggered: {
            ticks++;
            if (ticks > 450) { stop(); return; }
            updateResultProc.running = true;
        }
    }

    Process {
        id: healthProc
        command: ["bash", "-c", "\"$HOME/.local/bin/kingstra-health\" --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.vnHealth = JSON.parse(this.text); } catch (e) { root.vnHealth = []; }
            }
        }
    }

    Process {
        id: backupStatusProc
        command: ["bash", "-c", "\"$HOME/.local/bin/kingstra-backup\" status --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.bkStatus = JSON.parse(this.text); } catch (e) { root.bkStatus = ({}); }
            }
        }
    }

    Process {
        id: spaceCachedProc
        command: ["bash", "-c", "\"$HOME/.local/bin/kingstra-ruimte\" --cached 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { let d = JSON.parse(this.text); if (d && d.checked) root.spaceData = d; } catch (e) {}
            }
        }
    }
    Process {
        id: spaceMeasureProc
        command: ["bash", "-c", "\"$HOME/.local/bin/kingstra-ruimte\" --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { let d = JSON.parse(this.text); if (d && d.checked) root.spaceData = d; } catch (e) {}
                root.spaceBusy = false;
            }
        }
        onExited: root.spaceBusy = false
    }
    Process {
        id: spaceCleanProc
        onExited: {
            let label = root.spaceCleaning;
            root.spaceCleaning = "";
            spaceCachedProc.running = true;
            root.notify("Ruimte", "Opgeruimd");
        }
    }
    // Na een sudo-stap in de terminal: het nieuwe overzicht ophalen.
    Timer {
        id: spaceAfterTimer
        interval: 4000
        repeat: true
        property int rounds: 0
        onTriggered: {
            spaceCachedProc.running = true;
            rounds += 1;
            if (rounds >= 15) { rounds = 0; stop(); }
        }
    }

    Timer {
        id: backupRefreshTimer
        interval: 3000
        repeat: true
        property int ticks: 0
        onRunningChanged: if (running) ticks = 0
        onTriggered: {
            ticks++;
            backupStatusProc.running = true;
            if (ticks > 200 || (!root.bkStatus.running && ticks > 2)) stop();
        }
    }

    Timer {
        id: sessionModeRefreshTimer
        interval: 900
        repeat: false
        onTriggered: sessionModeProc.running = true
    }

    // Load weather .env on open
    Process {
        id: loadEnvProc
        command: ["bash", "-c", "if [ -f ~/.config/quickshell/calendar/.env ]; then cat ~/.config/quickshell/calendar/.env; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line.startsWith("#") || line === "") continue;
                    let eq = line.indexOf("=");
                    if (eq < 0) continue;
                    let k = line.substring(0, eq).trim();
                    let v = line.substring(eq + 1).trim().replace(/^["']|["']$/g, "");
                    if (k === "OPENWEATHER_KEY" && v) apiKeyInput.text = v;
                    else if (k === "OPENWEATHER_LAT" && v) latInput.text = v;
                    else if (k === "OPENWEATHER_LON" && v) lonInput.text = v;
                    else if (k === "OPENWEATHER_UNIT" && v) root.selectedUnit = v;
                }
            }
        }
    }

    // Load active theme info
    Process {
        id: loadThemeProc
        command: ["bash", "-c", "\"" + root.themeSwitchSafeCmd + "\" --current"]
        stdout: StdioCollector {
            onStreamFinished: {
                let activeFromConfig = String(ThemeConfig.theme || "").trim();
                let active = activeFromConfig !== "" ? activeFromConfig : this.text.trim();
                if (active !== "") {
                    loadThemeDetailProc.themeId = active;
                    loadThemeDetailProc.running = true;
                }
            }
        }
    }
    Process {
        id: loadThemeDetailProc
        property string themeId: ""
        command: [root.themeReadSafeCmd, "--json", root.themeFilePath(themeId)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    let meta = data.meta || {};
                    root.activeThemeId = loadThemeDetailProc.themeId;
                    root.activeThemeData = data;
                    root.activeThemeName = meta.name || loadThemeDetailProc.themeId;
                    root.activeThemeIcon = meta.icon || "󰏘";
                    root.themeAppearance = data.appearance || {};
                    if (root.themeEditThemeId === "" || root.themeEditThemeId === loadThemeDetailProc.themeId) {
                        root.loadThemeEditForm(data, loadThemeDetailProc.themeId);
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: themeWriteProc
        property string themeId: ""
        property bool applyAfterSave: false
        stderr: StdioCollector {
            onStreamFinished: {
                root.themeSaveError = this.text.trim();
            }
        }
        onExited: {
            root.themeSaveBusy = false;
            if (root.themeSaveError !== "") {
                root.notify("Theme", "Opslaan mislukt: " + root.themeSaveError);
                root.setThemeStatus("Opslaan mislukt: " + root.themeSaveError, "error");
                root.themeSaveError = "";
                return;
            }

            root.notify("Theme", "Thema opgeslagen: " + themeWriteProc.themeId);
            root.themeLoadedSignature = root.currentThemeSignature();
            root.setThemeStatus(
                themeWriteProc.applyAfterSave
                    ? "Opgeslagen. Actief thema wordt toegepast..."
                    : "Opgeslagen in " + themeWriteProc.themeId + ".toml",
                themeWriteProc.applyAfterSave ? "info" : "ok"
            );
            loadThemeDetailProc.themeId = themeWriteProc.themeId;
            loadThemeDetailProc.running = true;

            if (themeCarouselLoader.item && themeCarouselLoader.item.refreshThemes) {
                themeCarouselLoader.item.refreshThemes(themeWriteProc.themeId);
            }

            if (themeWriteProc.applyAfterSave) {
                themeReapplyProc.themeName = themeWriteProc.themeId;
                themeReapplyProc.running = true;
            }
        }
    }

    Process {
        id: themeReapplyProc
        property string themeName: ""
        command: ["bash", "-c", "\"" + root.themeSwitchSafeCmd + "\" \"" + themeName + "\""]
        onExited: {
            root.refreshActiveTheme();
            root.setThemeStatus("Opgeslagen en toegepast: " + themeName, "ok");
            if (themeCarouselLoader.item && themeCarouselLoader.item.refreshThemes) {
                themeCarouselLoader.item.refreshThemes(themeName);
            }
        }
    }

    Process {
        id: topbarReloadProc
        command: ["bash", "-lc", "true"]
        stderr: StdioCollector {
            onStreamFinished: {
                root.topbarReloadError = this.text.trim();
            }
        }
        onExited: {
            root.topbarReloadBusy = false;
            if (root.topbarReloadError !== "") {
                root.notify("Topbar", "Herladen mislukt: " + root.topbarReloadError);
                root.setThemeStatus("Topbar herladen mislukt: " + root.topbarReloadError, "error");
                root.topbarReloadError = "";
                return;
            }
            root.notify("Topbar", "Topbar herladen voltooid");
            root.setThemeStatus("Topbar herladen voltooid", "ok");
        }
    }

    SequentialAnimation {
        id: startupSequence
        PauseAnimation { duration: ThemeConfig.duration(30) }
        // Geen terugverende overshoot meer: die las als trillen naast de
        // strakke paneelgroei. Volgt nu ook de animatiesnelheid.
        NumberAnimation { target: root; property: "introBase"; to: 1.0; duration: ThemeConfig.duration(240); easing.type: Easing.OutQuint }
        NumberAnimation { target: root; property: "introSidebar"; to: 1.0; duration: ThemeConfig.duration(200); easing.type: Easing.OutQuint }
        NumberAnimation { target: root; property: "introContent"; to: 1.0; duration: ThemeConfig.duration(240); easing.type: Easing.OutQuint }
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { target: root; property: "introContent"; to: 0.0; duration: 150; easing.type: Easing.InExpo }
            NumberAnimation { target: root; property: "introSidebar"; to: 0.0; duration: 150; easing.type: Easing.InExpo }
        }
        NumberAnimation { target: root; property: "introBase"; to: 0.0; duration: 200; easing.type: Easing.InQuart }
        ScriptAction { script: root.finishClose() }
    }

    // -------------------------------------------------------------------------
    // HELPER: save settings.json
    // -------------------------------------------------------------------------
    function saveSettings(timeFormat, dateFormat, touchpadScrollPercent, mouseScrollPercent, touchpadRightClickButtonArea, keyboardLayout, keyboardDeadKeys, idleLockSeconds, idleScreenOffSeconds, idleSuspendSeconds, idleProfiles) {
        var configRoot = configHome();
        var settingsDir = configRoot + "/quickshell/settings";
        var path = settingsDir + "/settings.json";
        var inputOverridesPath = configRoot + "/hypr/lua/input-overrides.lua";
        var touchpadFactor = scrollFactorFromPercent(touchpadScrollPercent, 0.45);
        var mouseFactor = scrollFactorFromPercent(mouseScrollPercent, 1.35);
        var safeKeyboardLayout = normalizeKeyboardLayout(keyboardLayout);
        var safeKeyboardDeadKeys = normalizeKeyboardDeadKeys(keyboardDeadKeys, safeKeyboardLayout);
        var safeKeyboardVariant = keyboardVariant(safeKeyboardLayout, safeKeyboardDeadKeys);
        var useButtonArea = touchpadRightClickButtonArea === true;
        var safeIdleLockSeconds = normalizeIdleSeconds(idleLockSeconds, settingsData.idleLockSeconds || 300);
        var safeIdleScreenOffSeconds = normalizeIdleSeconds(idleScreenOffSeconds, settingsData.idleScreenOffSeconds || 480);
        var safeIdleSuspendSeconds = normalizeIdleSeconds(idleSuspendSeconds, settingsData.idleSuspendSeconds || 1800);
        var safeIdleProfiles = idleProfiles || settingsData.idleProfiles || normalizeIdleProfiles({});
        var payload = {
            timeFormat: timeFormat,
            dateFormat: dateFormat,
            touchpadScrollFactor: touchpadFactor,
            mouseScrollFactor: mouseFactor,
            touchpadRightClickButtonArea: useButtonArea,
            keyboardLayout: safeKeyboardLayout,
            keyboardDeadKeys: safeKeyboardDeadKeys,
            idleLockSeconds: safeIdleLockSeconds,
            idleScreenOffSeconds: safeIdleScreenOffSeconds,
            idleSuspendSeconds: safeIdleSuspendSeconds,
            idleProfiles: safeIdleProfiles
        };
        var json = JSON.stringify(payload, null, 4);
        var inputOverrides =
            "-- =============================================================================\n" +
            "-- input-overrides.lua — Settings-popup overrides\n" +
            "-- =============================================================================\n" +
            "-- Aangepast via de Settings-popup.\n" +
            "-- =============================================================================\n\n" +
            "return {\n" +
            "    apply = function()\n" +
            "        hl.config({\n" +
            "            input = {\n" +
            "                scroll_factor = " + mouseFactor.toFixed(2) + ",\n" +
            "                kb_layout = \"" + safeKeyboardLayout + "\",\n" +
            "                kb_variant = \"" + safeKeyboardVariant + "\",\n" +
            "                kb_options = \"\",\n" +
            "                touchpad = { scroll_factor = " + touchpadFactor.toFixed(2) + ", clickfinger_behavior = " + (useButtonArea ? "false" : "true") + " },\n" +
            "            },\n" +
            "        })\n" +
            "    end,\n" +
            "}\n";
        var cmd = [
            "mkdir -p '" + shellSingleQuote(settingsDir) + "'",
            "mkdir -p '" + shellSingleQuote(configRoot + "/hypr/lua") + "'",
            "printf '%s' '" + shellSingleQuote(json) + "' > '" + shellSingleQuote(path) + "'",
            "input_tmp=\"$(mktemp '" + shellSingleQuote(inputOverridesPath + ".tmp.XXXXXX") + "')\"",
            "trap 'rm -f -- \"$input_tmp\"' EXIT",
            "printf '%s' '" + shellSingleQuote(inputOverrides) + "' > \"$input_tmp\"",
            "luac -p \"$input_tmp\"",
            "mv -- \"$input_tmp\" '" + shellSingleQuote(inputOverridesPath) + "'",
            "trap - EXIT",
            "hyprctl reload >/dev/null 2>&1 || true",
            "'" + shellSingleQuote(idleApplyScript) + "' >/dev/null 2>&1 || true"
        ].join(" && ");
        root.settingsData = payload;
        Quickshell.execDetached(["bash", "-c", cmd]);
        notify("Settings", "Input, time, date en idle settings opgeslagen");
    }

    function saveWeatherConfig() {
        var file = Quickshell.env("HOME") + "/.config/quickshell/calendar/.env";
        var cmds = [
            "mkdir -p $(dirname " + file + ")",
            "echo 'OPENWEATHER_KEY=" + apiKeyInput.text + "' > " + file,
            "echo 'OPENWEATHER_UNIT=" + root.selectedUnit + "' >> " + file,
            "echo 'OPENWEATHER_LAT=" + latInput.text + "' >> " + file,
            "echo 'OPENWEATHER_LON=" + lonInput.text + "' >> " + file,
            "echo 'OPENWEATHER_CITY_ID=' >> " + file
        ];
        Quickshell.execDetached(["bash", "-c", cmds.join(" && ")]);
        notify("Weather", "API configuration saved");
        // Trigger immediate weather refresh by clearing cache
        weatherRefreshTimer.start();
    }

    Timer {
        id: weatherRefreshTimer; interval: 500
        onTriggered: {
            Quickshell.execDetached(["bash", "-c", "rm -f ~/.cache/quickshell/weather/weather.json 2>/dev/null; bash ~/.config/quickshell/calendar/weather.sh &"]);
        }
    }

    // Voeg catalogus-acties toe die nog niet gebonden zijn
    function mergeKeybinds(rawData) {
        keybindsModel.clear();
        var boundKeys = {};
        for (var i = 0; i < rawData.length; i++) {
            rawData[i].bound = true;
            keybindsModel.append(rawData[i]);
            boundKeys[rawData[i].d + "|" + rawData[i].args] = true;
        }
        for (var j = 0; j < keybindCatalog.length; j++) {
            var entry = keybindCatalog[j];
            if (!boundKeys[entry.d + "|" + entry.args]) {
                keybindsModel.append({
                    file: entry.file, cat: entry.cat, ln: 0,
                    t: entry.t, mods: "", key: "",
                    d: entry.d, args: entry.args,
                    label: entry.label, bound: false
                });
            }
        }
    }

    function saveKeybind(index, newMods, newKey) {
        var item = keybindsModel.get(index);
        var cleanedMods = String(newMods || "").trim().replace(/\s+/g, " ");
        var cleanedKey = String(newKey || "").trim().replace(/\s+/g, " ");
        if (cleanedKey === "") {
            notify("Keybinds", "Key mag niet leeg zijn");
            return;
        }
        if (cleanedMods.indexOf(",") >= 0 || cleanedKey.indexOf(",") >= 0) {
            notify("Keybinds", "Mods/Key mogen geen komma bevatten");
            return;
        }

        var script = Quickshell.env("HOME") + "/.config/quickshell/settings/write_keybind.sh";
        root.keybindWriteError = "";
        if (item.bound && Number(item.ln) > 0) {
            keybindWriteProc.command = ["bash", script, "--update", item.ln.toString(), cleanedMods, cleanedKey];
            root.keybindWriteSuccessMessage = "Keybinding bijgewerkt";
        } else {
            keybindWriteProc.command = ["bash", script, "--add", cleanedMods, cleanedKey, String(item.args || "")];
            root.keybindWriteSuccessMessage = "Keybinding toegevoegd";
        }
        keybindWriteProc.running = true;
    }

    function removeKeybind(index) {
        var item = keybindsModel.get(index);
        if (!item.bound) return;
        if (Number(item.ln) <= 0) {
            notify("Keybinds", "Kan deze binding niet verwijderen (ongeldige regel)");
            return;
        }
        var script = Quickshell.env("HOME") + "/.config/quickshell/settings/write_keybind.sh";
        root.keybindWriteError = "";
        root.keybindWriteSuccessMessage = "Keybinding verwijderd";
        keybindWriteProc.command = ["bash", script, "--remove", item.ln.toString()];
        keybindWriteProc.running = true;
    }

    function notify(title, msg) {
        Quickshell.execDetached(["notify-send", title, msg]);
    }

    function runUpdateBootstrap() {
        var bootstrapUrl = "https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh";
        var command = "bash <(curl -fsSL " + bootstrapUrl + ")";
        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", command]);
        notify("Settings", "Update gestart in terminal");
        // Sluit meteen zonder close-animatie.
        introContent = 0.0;
        introSidebar = 0.0;
        introBase = 0.0;
        root.finishClose();
    }

    function runUninstallFlow(noRestore) {
        var uninstallArg = noRestore ? "--no-restore" : "";
        var command =
            "marker=\"${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/install-complete\"; " +
            "repo=\"\"; " +
            "if [ -f \"$marker\" ]; then repo=\"$(sed -n 's/^Repo:[[:space:]]*//p' \"$marker\" | head -n 1)\"; fi; " +
            "if [ -z \"$repo\" ]; then repo=\"$HOME/kingstra-dots\"; fi; " +
            "if [ ! -x \"$repo/uninstall.sh\" ]; then echo \"uninstall.sh niet gevonden in: $repo\"; exit 1; fi; " +
            "cd \"$repo\" && ./uninstall.sh " + uninstallArg;
        advancedStatusText = noRestore ? "Uninstall zonder restore gestart" : "Uninstall met restore gestart";
        showUninstallConfirm = false;
        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", command]);
        notify("Advanced", noRestore ? "Uninstall zonder restore gestart" : "Uninstall met restore gestart");
        introContent = 0.0;
        introSidebar = 0.0;
        introBase = 0.0;
        root.finishClose();
    }

    // -------------------------------------------------------------------------
    // BACKGROUND
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)

        Rectangle {
            anchors.fill: parent; radius: root.themedRadius
            // Transparant: de PanelBackdrop-blob eronder versmelt met de chrome
            // (zelfde SDF-groep als network/music). Een eigen dekkende doos met
            // rand brak die overloop en werd een los zwevend blok.
            color: "transparent"; border.width: 0
            clip: true

            property real time: 0
            NumberAnimation on time { from: 0; to: Math.PI * 2; duration: 20000; loops: Animation.Infinite; running: true }

            Rectangle {
                width: root.s(600); height: root.s(600); radius: root.s(300)
                x: parent.width * 0.6 + Math.cos(parent.time) * root.s(100)
                y: parent.height * 0.1 + Math.sin(parent.time * 1.5) * root.s(100)
                color: root.ambientPurple; opacity: 0.04
                layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
            }
            Rectangle {
                width: root.s(700); height: root.s(700); radius: root.s(350)
                x: parent.width * 0.1 + Math.sin(parent.time * 0.8) * root.s(150)
                y: parent.height * 0.4 + Math.cos(parent.time * 1.2) * root.s(100)
                color: root.ambientBlue; opacity: 0.03
                layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blurMax: 90; blur: 1.0 }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MAIN LAYOUT
    // -------------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(20)

        // =====================================================================
        // SIDEBAR
        // =====================================================================
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: root.s(220)
            radius: root.themedInnerRadius; color: root.popupPanelFill
            border.color: root.surface1; border.width: 1
            opacity: introSidebar
            transform: Translate { x: root.s(-30) * (1.0 - introSidebar) }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(10)

                // Header
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: root.s(60)
                    RowLayout {
                        anchors.fill: parent; spacing: root.s(12)
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: root.s(36); height: root.s(36); radius: root.s(10)
                            color: root.ambientPurple
                            Text { anchors.centerIn: parent; text: ""; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(20); color: root.base }
                        }
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter; spacing: root.s(2)
                            Text { text: "Settings"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(15); color: root.text }
                            Text { text: "kingstra-dots"; font.family: root.uiFontFamily; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(11); color: root.subtext0 }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.surface1, 0.5); Layout.bottomMargin: root.s(10) }

                // Zoeken: filtert de tabbladen; Enter opent het eerste.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: root.s(38); radius: root.s(19)
                    color: root.surface0; border.color: settingsSearchInput.activeFocus ? root.ambientPurple : root.surface2; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: root.s(12); anchors.rightMargin: root.s(12); spacing: root.s(8)
                        Text { text: "󰍉"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(15); color: root.subtext0 }
                        TextInput {
                            id: settingsSearchInput
                            Layout.fillWidth: true; Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: root.uiFontFamily; font.pixelSize: root.s(12); color: root.text
                            clip: true; selectByMouse: true
                            onTextChanged: root.settingsQuery = text
                            onAccepted: root.acceptSettingsQuery()
                            Keys.onEscapePressed: (event) => {
                                if (text !== "") { text = ""; event.accepted = true; }
                                else event.accepted = false;
                            }
                            Text { text: "Zoeken…"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                ScrollView {
                    id: sidebarTabsView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: sidebarTabsView.availableWidth
                        spacing: root.s(8)

                        // Losse instellingen die bij de zoekterm passen.
                        Text {
                            visible: root.settingResults.length > 0
                            text: "Instellingen"
                            Layout.leftMargin: root.s(6)
                            font.family: root.uiFontFamily; font.pixelSize: root.s(10); font.weight: Font.Bold
                            font.letterSpacing: root.themedLetterSpacing; color: root.subtext0
                        }
                        Repeater {
                            model: root.settingResults
                            Rectangle {
                                id: resultRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(46); radius: root.s(8)
                                color: resultMa.containsMouse || (index === 0 && settingsSearchInput.activeFocus)
                                    ? root.popupPanelFill : "transparent"
                                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                ColumnLayout {
                                    anchors.fill: parent; anchors.leftMargin: root.s(15); anchors.rightMargin: root.s(10)
                                    spacing: 0
                                    Item { Layout.fillHeight: true }
                                    Text { text: resultRow.modelData.label; Layout.fillWidth: true; elide: Text.ElideRight; font.family: root.uiFontFamily; font.pixelSize: root.s(12); font.weight: Font.Medium; color: root.text }
                                    Text { text: resultRow.modelData.where; Layout.fillWidth: true; elide: Text.ElideRight; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0 }
                                    Item { Layout.fillHeight: true }
                                }
                                MouseArea { id: resultMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openSetting(resultRow.modelData) }
                            }
                        }
                        Rectangle {
                            visible: root.settingResults.length > 0 && root.visibleTabIndexes.length > 0
                            Layout.fillWidth: true; height: 1; color: Qt.alpha(root.surface1, 0.5)
                            Layout.topMargin: root.s(2); Layout.bottomMargin: root.s(2)
                        }

                        // Tabbladen (gefilterd door het zoekveld)
                        Repeater {
                            model: root.visibleTabIndexes
                            Rectangle {
                                id: tabButton
                                required property int modelData
                                readonly property var tab: root.tabs[modelData]
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(44); radius: root.s(8)
                                property bool isActive: root.currentTab === modelData
                                color: isActive ? root.popupPanelHoverFill : (tabMa.containsMouse ? root.popupPanelFill : "transparent")
                                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: root.s(15); spacing: root.s(12)
                                    Item {
                                        Layout.preferredWidth: root.s(24); Layout.alignment: Qt.AlignVCenter
                                        Text { anchors.centerIn: parent; text: tabButton.tab.icon; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(18); color: tabButton.isActive ? root.ambientPurple : root.subtext0; Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } } }
                                    }
                                    Text { text: tabButton.tab.label; elide: Text.ElideRight; font.family: root.uiFontFamily; font.weight: tabButton.isActive ? root.themedFontWeight : Font.Medium; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(13); color: tabButton.isActive ? root.text : root.subtext0; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } } }
                                }

                                Rectangle {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    width: root.s(3); height: tabButton.isActive ? root.s(20) : 0; radius: root.s(2)
                                    color: root.ambientPurple
                                    Behavior on height { NumberAnimation { duration: ThemeConfig.duration(250); easing.type: Easing.OutBack } }
                                }

                                MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openTab(tabButton.modelData) }
                            }
                        }

                        // Geen tabblad gevonden: zoek dan in de sneltoetsen.
                        Rectangle {
                            visible: root.settingsQuery.trim() !== "" && root.visibleTabIndexes.length === 0 && root.settingResults.length === 0
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(44); radius: root.s(8)
                            color: keybindSearchMa.containsMouse ? root.popupPanelFill : "transparent"
                            border.color: root.surface1; border.width: 1
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: root.s(15); anchors.rightMargin: root.s(10); spacing: root.s(12)
                                Text { text: "󰌌"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(18); color: root.subtext0 }
                                Text { text: "Zoek in sneltoetsen"; font.family: root.uiFontFamily; font.pixelSize: root.s(12); color: root.subtext0; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            MouseArea { id: keybindSearchMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.searchKeybinds(root.settingsQuery.trim()) }
                        }
                    }
                }

                // Close button
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: root.s(44); radius: root.s(8)
                    color: closeHover.containsMouse ? Qt.alpha(root.red, 0.1) : "transparent"
                    border.color: closeHover.containsMouse ? root.red : root.surface1; border.width: 1
                    scale: closeHover.pressed ? 0.95 : (closeHover.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(250); easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(8)

                        Text {
                            text: "󰅖"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: root.s(16)
                            color: closeHover.containsMouse ? root.red : root.subtext0
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                        }
                        Text {
                            text: "Sluiten"
                            font.family: root.uiFontFamily
                            font.weight: Font.Medium
                            font.letterSpacing: root.themedLetterSpacing
                            font.pixelSize: root.s(12)
                            color: closeHover.containsMouse ? root.red : root.subtext0
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                        }
                    }
                    MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: closeSequence.start() }
                }
            }
        }

        // =====================================================================
        // CONTENT AREA
        // =====================================================================
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            opacity: introContent; scale: 0.95 + (0.05 * introContent)
            transform: Translate { y: root.s(20) * (1.0 - introContent) }

            // Pagina's binnen het onderwerp (Invoer | Sneltoetsen) als ronde
            // knoppen. Op een dieper liggende pagina (extra) staat hier een
            // knop terug naar de hoofdpagina. Anders klapt de rij in tot niets.
            Row {
                id: subPageRow
                readonly property var tab: root.tabs[root.currentTab]
                readonly property int extraIndex: tab ? tab.extra.indexOf(root.currentPage) : -1
                readonly property bool onExtra: extraIndex >= 0
                readonly property bool shown: tab && (tab.pages.length > 1 || onExtra)
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: root.s(20)
                anchors.topMargin: shown ? root.s(14) : 0
                height: shown ? root.s(32) : 0
                spacing: root.s(8)
                opacity: shown ? 1 : 0
                visible: opacity > 0.01
                Behavior on height { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
                Behavior on anchors.topMargin { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(180) } }

                Rectangle {
                    visible: subPageRow.onExtra
                    height: root.s(32)
                    width: backLabel.implicitWidth + root.s(28)
                    radius: height / 2
                    color: backMa.containsMouse ? root.popupPanelFill : "transparent"
                    border.width: 1
                    border.color: root.surface1
                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                    Text {
                        id: backLabel
                        anchors.centerIn: parent
                        text: "󰁍  " + (subPageRow.tab ? subPageRow.tab.pageLabels[0] : "")
                        font.family: root.uiFontFamily
                        font.pixelSize: root.s(12)
                        font.weight: Font.Medium
                        color: root.subtext0
                    }
                    MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openTab(root.currentTab) }
                }
                Text {
                    visible: subPageRow.onExtra
                    anchors.verticalCenter: parent.verticalCenter
                    text: subPageRow.onExtra ? subPageRow.tab.extraLabels[subPageRow.extraIndex] : ""
                    font.family: root.uiFontFamily
                    font.pixelSize: root.s(13)
                    font.weight: root.themedFontWeight
                    color: root.text
                }

                Repeater {
                    model: subPageRow.tab && !subPageRow.onExtra && subPageRow.tab.pages.length > 1 ? subPageRow.tab.pages.length : 0
                    Rectangle {
                        id: subPageButton
                        required property int index
                        readonly property int page: subPageRow.tab.pages[index]
                        readonly property bool isActive: root.currentPage === page
                        height: root.s(32)
                        width: subPageLabel.implicitWidth + root.s(28)
                        radius: height / 2
                        color: isActive ? Qt.alpha(root.ambientPurple, 0.18) : (subPageMa.containsMouse ? root.popupPanelFill : "transparent")
                        border.width: 1
                        border.color: isActive ? Qt.alpha(root.ambientPurple, 0.55) : root.surface1
                        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                        Text {
                            id: subPageLabel
                            anchors.centerIn: parent
                            text: subPageRow.tab.pageLabels[subPageButton.index]
                            font.family: root.uiFontFamily
                            font.pixelSize: root.s(12)
                            font.weight: subPageButton.isActive ? root.themedFontWeight : Font.Medium
                            color: subPageButton.isActive ? root.text : root.subtext0
                        }
                        MouseArea { id: subPageMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.currentPage = subPageButton.page }
                    }
                }
            }

            Item {
                id: pageArea
                anchors.top: subPageRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Loader {
                    anchors.fill: parent
                    active: root.currentPage === 0
                    source: "BedieningPage.qml"
                    onLoaded: item.pageRequested.connect(root.openNamedPage)
                }
                Loader {
                    anchors.fill: parent
                    active: root.currentPage === 16
                    source: "StartPage.qml"
                    onLoaded: { item.unit = root.s(100) / 100; item.pageRequested.connect(root.openNamedPage); }
                }
                Loader {
                    anchors.fill: parent
                    active: root.currentPage === 17
                    source: "AppearancePage.qml"
                    onLoaded: { item.unit = root.s(100) / 100; item.pageRequested.connect(root.openNamedPage); }
                }
                Loader {
                    anchors.fill: parent
                    active: root.currentPage === 18
                    source: "DesktopPage.qml"
                    onLoaded: { item.unit = root.s(100) / 100; item.pageRequested.connect(root.openNamedPage); }
                }
                Loader {
                    anchors.fill: parent
                    active: root.currentPage === 19
                    source: "RestPage.qml"
                    onLoaded: { item.unit = root.s(100) / 100; item.pageRequested.connect(root.openNamedPage); }
                }
                Loader {
                    anchors.fill: parent
                    active: root.currentPage === 15
                    source: "RailLayoutPage.qml"
                    onLoaded: item.pageRequested.connect(root.openNamedPage)
                }

            // =================================================================
            // TAB 13: ABOUT
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 13
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ListModel {
                    id: systemModel
                    ListElement { pkg: "Hyprland";    role: "Wayland Compositor";     icon: "";  clr: "blue";   link: "https://hyprland.org/" }
                    ListElement { pkg: "Quickshell";  role: "Desktop Shell (QML)";    icon: "󰣆"; clr: "mauve";  link: "https://git.outfoxxed.me/outfoxxed/quickshell" }
                    ListElement { pkg: "skwd-wall";   role: "Wallpaper Daemon";       icon: "󰸉"; clr: "green";  link: "https://aur.archlinux.org/packages/skwd-wall" }
                    ListElement { pkg: "Kitty";       role: "Terminal Emulator";       icon: "󰄛"; clr: "yellow"; link: "https://sw.kovidgoyal.net/kitty/" }
                    ListElement { pkg: "SwayOSD";     role: "On-screen Display";       icon: "󰕾"; clr: "pink";   link: "https://github.com/ErikReider/SwayOSD" }
                    ListElement { pkg: "Matugen";     role: "Material You Theming";    icon: "󰏘"; clr: "peach";  link: "https://github.com/InioX/matugen" }
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(20)

                    // Author block — JorisKooistra
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(80); radius: root.s(12)
                        color: authorMa.containsMouse ? Qt.alpha(root.surface1, 0.6) : Qt.alpha(root.surface0, 0.4)
                        border.color: authorMa.containsMouse ? root.mauve : root.surface1; border.width: 1
                        scale: authorMa.pressed ? 0.98 : (authorMa.containsMouse ? 1.01 : 1.0)
                        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(250); easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(200) } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(15)
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: root.s(48); height: root.s(48); radius: root.s(10)
                                color: root.surface0; border.color: root.surface2; border.width: 1
                                Text { anchors.centerIn: parent; text: ""; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(28); color: root.text }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter; spacing: root.s(2)
                                Text { text: "Gemaakt door"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0; font.weight: Font.Medium }
                                Row {
                                    spacing: root.s(1)
                                    Repeater {
                                        model: [
                                            { l: "J", c: root.blue },
                                            { l: "o", c: root.sapphire },
                                            { l: "r", c: root.green },
                                            { l: "i", c: root.yellow },
                                            { l: "s", c: root.peach },
                                            { l: "K", c: root.red },
                                            { l: "o", c: root.mauve },
                                            { l: "o", c: root.pink },
                                            { l: "i", c: root.blue },
                                            { l: "s", c: root.sapphire },
                                            { l: "t", c: root.green },
                                            { l: "r", c: root.yellow },
                                            { l: "a", c: root.peach }
                                        ]
                                        Text {
                                            text: modelData.l; font.family: ThemeConfig.textFont; font.weight: Font.Black; font.pixelSize: root.s(22); color: modelData.c
                                            property real hoverOffset: authorMa.containsMouse ? root.s(-4) : 0
                                            transform: Translate { y: hoverOffset }
                                            Behavior on hoverOffset { NumberAnimation { duration: ThemeConfig.duration(300) + (index * 25); easing.type: Easing.OutBack } }
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: root.s(32); height: root.s(32); radius: root.s(8)
                                color: authorMa.containsMouse ? root.surface1 : "transparent"
                                Text { anchors.centerIn: parent; text: ""; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(18); color: authorMa.containsMouse ? root.mauve : root.subtext0; Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } } }
                            }
                        }
                        MouseArea { id: authorMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/JorisKooistra/kingstra-dots"]) }
                    }

                    Text { text: "Systeemonderdelen"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text; Layout.topMargin: root.s(5) }

                    GridLayout {
                        Layout.fillWidth: true; columns: 2; rowSpacing: root.s(15); columnSpacing: root.s(15)
                        Repeater {
                            model: systemModel
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(70); radius: root.s(10)
                                color: sysCardMa.containsMouse ? Qt.alpha(root[model.clr], 0.14) : root.popupPanelFill
                                border.color: sysCardMa.containsMouse ? root[model.clr] : root.surface1; border.width: 1
                                scale: sysCardMa.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(150); easing.type: Easing.OutQuart } }
                                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
                                Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(200) } }

                                Item {
                                    anchors.fill: parent; anchors.margins: root.s(15)
                                    Item {
                                        id: sysIconBox; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        width: root.s(40); height: root.s(40)
                                        Text { anchors.centerIn: parent; text: model.icon; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(24); color: root[model.clr] }
                                    }
                                    Column {
                                        anchors.left: sysIconBox.right; anchors.leftMargin: root.s(15); anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: root.s(2)
                                        Text { text: model.pkg; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(15); color: root.text }
                                        Text { text: model.role; font.family: root.uiFontFamily; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(12); color: root.subtext0 }
                                    }
                                }
                                MouseArea { id: sysCardMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", model.link]) }
                            }
                        }
                    }


                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 4: KEYBINDINGS
            // =================================================================
            Item {
                id: keybindTab
                anchors.fill: parent
                visible: root.currentPage === 4
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(15)

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Sneltoetsen"; font.family: ThemeConfig.textFont; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text; Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: root.s(36); Layout.preferredHeight: root.s(36); radius: root.s(8)
                            color: reloadMa.containsMouse ? root.surface1 : Qt.alpha(root.surface0, 0.6)
                            border.color: reloadMa.containsMouse ? root.blue : root.surface1; border.width: 1
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                            Text { anchors.centerIn: parent; text: "󰑓"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(16); color: reloadMa.containsMouse ? root.blue : root.subtext0; Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } } }
                            MouseArea { id: reloadMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { keybindsModel.clear(); loadKeybindsProc.running = true; } }
                        }
                    }

                    // Search bar
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(40); radius: root.s(8)
                        color: root.surface0; border.color: filterInput.activeFocus ? root.blue : root.surface2; border.width: 1
                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(8); spacing: root.s(8)
                            Text { text: "󰍉"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(16); color: root.subtext0 }
                            TextInput {
                                id: filterInput; Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(13); color: root.text
                                clip: true; selectByMouse: true
                                onTextChanged: root.keybindFilter = text.toLowerCase()
                                Text { text: "Sneltoetsen filteren…"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Keybind list
                    ScrollView {
                        id: keybindScroll
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentWidth: availableWidth; clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                        ColumnLayout {
                            width: parent.width; spacing: root.s(6)

                            Repeater {
                                model: keybindsModel

                                Rectangle {
                                    id: bindRow
                                    Layout.fillWidth: true; radius: root.s(8)
                                    visible: {
                                        if (!root.keybindFilter) return true;
                                        var txt = (model.mods + " " + model.key + " " + model.d + " " + model.args + " " + model.label).toLowerCase();
                                        return txt.indexOf(root.keybindFilter) >= 0;
                                    }
                                    Layout.preferredHeight: visible ? (isEditing ? root.s(90) : root.s(46)) : 0
                                    Layout.topMargin: visible ? 0 : -root.s(6)

                                    property bool isEditing: root.editingIndex === index
                                    property string editMods: model.mods
                                    property string editKey: model.key

                                    color: isEditing ? Qt.alpha(root.blue, 0.08) : (bindMa.containsMouse ? root.surface1 : Qt.alpha(root.surface0, 0.4))
                                    border.color: isEditing ? root.blue : (bindMa.containsMouse ? root.peach : "transparent"); border.width: 1
                                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                    Behavior on Layout.preferredHeight { NumberAnimation { duration: ThemeConfig.duration(200); easing.type: Easing.OutQuart } }

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(6)

                                        // Display row
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: root.s(10)

                                            // Key badges
                                            Item {
                                                Layout.preferredWidth: root.s(200); Layout.minimumWidth: root.s(200)
                                                Layout.fillHeight: true

                                                // Unbound
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !model.bound
                                                    width: unboundTxt.implicitWidth + root.s(16); height: root.s(26); radius: root.s(4)
                                                    color: Qt.alpha(root.overlay0, 0.12); border.color: Qt.alpha(root.overlay0, 0.3); border.width: 1
                                                    Text { id: unboundTxt; anchors.centerIn: parent; text: "Niet ingesteld"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(10); color: root.overlay0 }
                                                }

                                                // Bound
                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter; spacing: root.s(6)
                                                    visible: model.bound
                                                    Rectangle {
                                                        width: k1t.implicitWidth + root.s(14); height: root.s(26); radius: root.s(4)
                                                        color: root.surface0; border.color: root.surface2; border.width: 1
                                                        Text { id: k1t; anchors.centerIn: parent; text: model.mods; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.peach }
                                                    }
                                                    Text { text: "+"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(12); color: root.overlay0; anchors.verticalCenter: parent.verticalCenter; visible: model.key !== "" }
                                                    Rectangle {
                                                        visible: model.key !== ""
                                                        width: k2t.implicitWidth + root.s(14); height: root.s(26); radius: root.s(4)
                                                        color: root.surface0; border.color: root.surface2; border.width: 1
                                                        Text { id: k2t; anchors.centerIn: parent; text: model.key; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.peach }
                                                    }
                                                }
                                            }

                                            // Action label
                                            Text {
                                                text: model.label || (model.d + (model.args ? " " + model.args : ""))
                                                font.family: ThemeConfig.textFont; font.pixelSize: root.s(13); color: root.text
                                                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                                elide: Text.ElideRight; clip: true
                                            }

                                            RowLayout {
                                                visible: !bindRow.isEditing
                                                spacing: root.s(6)

                                                Rectangle {
                                                    Layout.preferredWidth: root.s(70); Layout.preferredHeight: root.s(28); radius: root.s(6)
                                                    color: editBtnMa.containsMouse ? Qt.alpha(root.blue, 0.20) : "transparent"
                                                    border.color: editBtnMa.containsMouse ? root.blue : root.surface1
                                                    border.width: 1
                                                    Text { anchors.centerIn: parent; text: "Bewerk"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: editBtnMa.containsMouse ? root.blue : root.subtext0 }
                                                    MouseArea {
                                                        id: editBtnMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            bindRow.editMods = model.mods;
                                                            bindRow.editKey = model.key;
                                                            root.editingIndex = index;
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: root.s(82); Layout.preferredHeight: root.s(28); radius: root.s(6)
                                                    visible: model.bound
                                                    color: deleteBtnMa.containsMouse ? Qt.alpha(root.red, 0.15) : "transparent"
                                                    border.color: deleteBtnMa.containsMouse ? root.red : root.surface1
                                                    border.width: 1
                                                    Text { anchors.centerIn: parent; text: "Verwijder"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: deleteBtnMa.containsMouse ? root.red : root.subtext0 }
                                                    MouseArea {
                                                        id: deleteBtnMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.removeKeybind(index)
                                                    }
                                                }
                                            }
                                        }

                                        // Edit row (only visible when editing)
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: root.s(8)
                                            visible: bindRow.isEditing

                                            Text { text: "Mods:"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(12); color: root.subtext0 }
                                            Rectangle {
                                                Layout.preferredWidth: root.s(200); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: root.surface0; border.color: modsEdit.activeFocus ? root.blue : root.surface2; border.width: 1
                                                TextInput {
                                                    id: modsEdit; anchors.fill: parent; anchors.margins: root.s(6)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(12); color: root.text
                                                    text: bindRow.editMods; selectByMouse: true; clip: true
                                                    onTextChanged: bindRow.editMods = text
                                                }
                                            }

                                            Text { text: "Key:"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(12); color: root.subtext0 }
                                            Rectangle {
                                                Layout.preferredWidth: root.s(120); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: root.surface0; border.color: keyEdit.activeFocus ? root.blue : root.surface2; border.width: 1
                                                TextInput {
                                                    id: keyEdit; anchors.fill: parent; anchors.margins: root.s(6)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(12); color: root.text
                                                    text: bindRow.editKey; selectByMouse: true; clip: true
                                                    onTextChanged: bindRow.editKey = text
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Save button
                                            Rectangle {
                                                Layout.preferredWidth: root.s(70); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: saveBMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                                Text { anchors.centerIn: parent; text: "Opslaan"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.base }
                                                MouseArea { id: saveBMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveKeybind(index, bindRow.editMods, bindRow.editKey) }
                                            }
                                            // Remove button (alleen bij bestaande bind)
                                            Rectangle {
                                                Layout.preferredWidth: root.s(30); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                visible: model.bound
                                                color: removeBMa.containsMouse ? Qt.alpha(root.red, 0.15) : "transparent"
                                                border.color: removeBMa.containsMouse ? root.red : root.surface1; border.width: 1
                                                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                                Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                                Text { anchors.centerIn: parent; text: "󰆴"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(14); color: removeBMa.containsMouse ? root.red : root.subtext0; Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } } }
                                                MouseArea { id: removeBMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeKeybind(index) }
                                            }
                                            // Cancel button
                                            Rectangle {
                                                Layout.preferredWidth: root.s(70); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: cancelMa.containsMouse ? Qt.alpha(root.red, 0.15) : "transparent"
                                                border.color: root.surface1; border.width: 1
                                                Text { anchors.centerIn: parent; text: "Annuleer"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                                MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editingIndex = -1 }
                                            }
                                        }
                                    }

                                    MouseArea { id: bindMa; anchors.fill: parent; hoverEnabled: true; z: -1 }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: keybindWheelCatcher
                    anchors.fill: parent
                    enabled: !TouchProfile.isTouchscreen
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onWheel: (wheel) => {
                        if (root.scrollFlickableByWheel(keybindScroll.contentItem, wheel)) {
                            wheel.accepted = true;
                        }
                    }
                }
            }

            // =================================================================
            // TAB 9: WEATHER & TIME
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 9
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(15)

                        Text { text: "Tijd & weer"; font.family: ThemeConfig.textFont; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }

                        // ---- WEATHER API CONFIG ----
                        RowLayout {
                            spacing: root.s(8)
                            Text { text: "󰖐"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(20); color: root.yellow }
                            Text { text: "Weer"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                        }

                        Text { text: "Voor het weer in de bar: een gratis OpenWeatherMap-sleutel en je locatie."; font.family: ThemeConfig.textFont; font.pixelSize: root.s(12); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        // API Key
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                            color: root.surface0; border.color: apiKeyInput.activeFocus ? root.blue : root.surface2; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                            RowLayout {
                                anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                                Text { text: "󰌆"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(18); color: root.subtext0 }
                                TextInput {
                                    id: apiKeyInput; Layout.fillWidth: true; Layout.fillHeight: true
                                    verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(13); color: root.text
                                    clip: true; selectByMouse: true; echoMode: TextInput.Password
                                    Text { text: "OpenWeather API-sleutel…"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }

                        // Coordinates
                        RowLayout {
                            Layout.fillWidth: true; spacing: root.s(15)
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                                color: root.surface0; border.color: latInput.activeFocus ? root.peach : root.surface2; border.width: 1
                                Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                TextInput {
                                    id: latInput; anchors.fill: parent; anchors.margins: root.s(10)
                                    verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(13); color: root.text; clip: true; selectByMouse: true
                                    Text { text: "Breedtegraad (bijv. 52.3676)"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                                color: root.surface0; border.color: lonInput.activeFocus ? root.peach : root.surface2; border.width: 1
                                Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                TextInput {
                                    id: lonInput; anchors.fill: parent; anchors.margins: root.s(10)
                                    verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(13); color: root.text; clip: true; selectByMouse: true
                                    Text { text: "Lengtegraad (bijv. 4.9041)"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }

                        // Units
                        RowLayout {
                            Layout.fillWidth: true; spacing: root.s(15)
                            Text { text: "Eenheden:"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                            Repeater {
                                model: ["metric", "imperial", "standard"]
                                Rectangle {
                                    Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(32); radius: root.s(6)
                                    color: root.selectedUnit === modelData ? Qt.alpha(root.mauve, 0.2) : "transparent"
                                    border.color: root.selectedUnit === modelData ? root.mauve : root.surface1; border.width: 1
                                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                    Text { anchors.centerIn: parent; text: modelData; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); font.capitalization: Font.Capitalize; color: root.selectedUnit === modelData ? root.mauve : root.subtext0 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedUnit = modelData }
                                }
                            }
                        }

                        // Save weather button
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredWidth: root.s(160); Layout.preferredHeight: root.s(42); radius: root.s(8)
                                color: wSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                scale: wSaveMa.pressed ? 0.95 : (wSaveMa.containsMouse ? 1.02 : 1.0)
                                Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(200); easing.type: Easing.OutBack } }
                                RowLayout {
                                    anchors.centerIn: parent; spacing: root.s(8)
                                    Text { text: "󰆓"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(18); color: root.base }
                                    Text { text: "Weer opslaan"; font.family: ThemeConfig.textFont; font.weight: Font.Black; font.pixelSize: root.s(14); color: root.base }
                                }
                                MouseArea { id: wSaveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveWeatherConfig() }
                            }
                        }

                        AdvancedSection {
                            id: timeAdvancedSection
                            unit: root.s(100) / 100
                            title: "Tijd- en datumnotatie"
                            icon: "󰥔"
                            hint: "Notatie van tijd en datum in de bar en op het vergrendelscherm"
                            // ---- DATE & TIME FORMAT ----
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: timeFormatColumn.implicitHeight + root.s(30); radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.4); border.color: root.surface1; border.width: 1

                                ColumnLayout {
                                    id: timeFormatColumn
                                    anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(12)

                                    RowLayout {
                                        spacing: root.s(8)
                                        Text { text: "󰥔"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(20); color: root.blue }
                                        Text { text: "Tijd- en datumnotatie"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                                    }

                                    Text { text: "Qt-notatie, bijv. HH:mm (24 uur), hh:mm AP (12 uur), dddd d MMMM (maandag 7 april)"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: root.s(15)

                                        // Time format
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: root.s(4)
                                            Text { text: "Tijdnotatie"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: root.s(38); radius: root.s(6)
                                                color: root.surface0; border.color: timeFmtInput.activeFocus ? root.blue : root.surface2; border.width: 1
                                                Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                                TextInput {
                                                    id: timeFmtInput; anchors.fill: parent; anchors.margins: root.s(8)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(13); color: root.text
                                                    text: root.settingsData.timeFormat || "HH:mm:ss"; selectByMouse: true; clip: true
                                                }
                                            }
                                        }

                                        // Date format
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: root.s(4)
                                            Text { text: "Datumnotatie"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: root.s(38); radius: root.s(6)
                                                color: root.surface0; border.color: dateFmtInput.activeFocus ? root.blue : root.surface2; border.width: 1
                                                Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                                TextInput {
                                                    id: dateFmtInput; anchors.fill: parent; anchors.margins: root.s(8)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: ThemeConfig.textFont; font.pixelSize: root.s(13); color: root.text
                                                    text: root.settingsData.dateFormat || "dddd, MMMM dd"; selectByMouse: true; clip: true
                                                }
                                            }
                                        }
                                    }

                                    // Preview
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: root.s(10)
                                        Text { text: "Voorbeeld:"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                        Text {
                                            property string preview: Qt.formatDateTime(new Date(), timeFmtInput.text) + "  ·  " + Qt.formatDateTime(new Date(), dateFmtInput.text)
                                            text: preview; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.peach
                                            Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.preview = Qt.formatDateTime(new Date(), timeFmtInput.text) + "  ·  " + Qt.formatDateTime(new Date(), dateFmtInput.text) }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(30); radius: root.s(6)
                                            color: dtSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                            scale: dtSaveMa.pressed ? 0.95 : 1.0
                                            Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(150) } }
                                            Text { anchors.centerIn: parent; text: "Opslaan"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
                                            MouseArea {
                                                id: dtSaveMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.saveSettings(
                                                    timeFmtInput.text,
                                                    dateFmtInput.text,
                                                    touchpadScrollSpin.value,
                                                    mouseScrollSpin.value,
                                                    touchpadRightClickCombo.currentIndex === 0,
                                                    root.keyboardLayoutCodes[keyboardLayoutCombo.currentIndex],
                                                    keyboardDeadKeysCombo.currentIndex === 0
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 5: INPUT
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 5
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(15)

                        Text { text: "Invoer"; font.family: ThemeConfig.textFont; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: inputCardColumn.implicitHeight + root.s(30); radius: root.s(12)
                            color: Qt.alpha(root.surface0, 0.4); border.color: root.surface1; border.width: 1

                            ColumnLayout {
                                id: inputCardColumn
                                anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(12)

                                RowLayout {
                                    spacing: root.s(8)
                                    Text { text: "󰍽"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(20); color: root.peach }
                                    Text { text: "Scrollsnelheid"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                                }

                                Text {
                                    text: "Het touchpad scrolt standaard iets rustiger, de muis reageert sterker. Waarden zijn percentages van de standaardsnelheid van Hyprland."
                                    font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0
                                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: root.s(15)

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: root.s(6)
                                        Text { text: "Touchpad"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                        ThemedSpinBox {
                                            id: touchpadScrollSpin
                                            from: 20; to: 300; stepSize: 5
                                            value: root.scrollPercentFromSetting(root.settingsData.touchpadScrollFactor, 0.45)
                                        }
                                        Text {
                                            text: touchpadScrollSpin.value + "%  (" + root.scrollFactorFromPercent(touchpadScrollSpin.value, 0.45).toFixed(2) + "x)"
                                            font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.peach
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: root.s(6)
                                        Text { text: "Muis"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                        ThemedSpinBox {
                                            id: mouseScrollSpin
                                            from: 20; to: 300; stepSize: 5
                                            value: root.scrollPercentFromSetting(root.settingsData.mouseScrollFactor, 1.35)
                                        }
                                        Text {
                                            text: mouseScrollSpin.value + "%  (" + root.scrollFactorFromPercent(mouseScrollSpin.value, 1.35).toFixed(2) + "x)"
                                            font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.blue
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(1)
                                    color: Qt.alpha(root.surface2, 0.65)
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: root.s(15)

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: root.s(6)
                                        Text { text: "Toetsenbordindeling"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                        ThemedComboBox {
                                            id: keyboardLayoutCombo
                                            model: root.keyboardLayoutLabels
                                            currentIndex: root.keyboardLayoutIndex(root.settingsData.keyboardLayout)
                                            // Elke layout heeft zijn eigen dode-toetsen-standaard; bij een wissel
                                            // wint die standaard van de vorige keuze. Alleen onActivated: dat
                                            // vuurt puur bij een gebruikersselectie, terwijl onCurrentIndexChanged
                                            // ook bij het opbouwen van de UI afgaat en dan de binding hieronder
                                            // sloopt vóór settings.json is ingelezen.
                                            onActivated: function(index) {
                                                let code = root.keyboardLayoutCodes[index] || "us";
                                                let saved = code === root.settingsData.keyboardLayout
                                                    ? root.settingsData.keyboardDeadKeys
                                                    : undefined;
                                                keyboardDeadKeysCombo.currentIndex =
                                                    root.normalizeKeyboardDeadKeys(saved, code) ? 0 : 1;
                                            }
                                        }
                                        Text {
                                            text: "Kiest de actieve toetsenbordtaal en -indeling in Hyprland."
                                            font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.blue
                                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                AdvancedSection {
                                    id: inputAdvancedSection
                                    unit: root.s(100) / 100
                                    hint: "Rechtsklikgebied van het touchpad en dode toetsen voor accenten"
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: root.s(15)

                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: root.s(6)
                                            Text { text: "Rechtsklik op touchpad"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                            ThemedComboBox {
                                                id: touchpadRightClickCombo
                                                model: ["Aan", "Uit"]
                                                currentIndex: root.settingsData.touchpadRightClickButtonArea ? 0 : 1
                                            }
                                            Text {
                                                text: touchpadRightClickCombo.currentIndex === 0
                                                    ? "Aan: rechtsonder op het touchpad klikken is rechtsklik, zoals op Windows."
                                                    : "Uit: klik met twee vingers voor rechtsklik, zonder vast klikgebied."
                                                font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.peach
                                                wrapMode: Text.WordWrap; Layout.fillWidth: true
                                            }
                                        }

                                        ColumnLayout {
                                            id: keyboardDeadKeysColumn
                                            property string layoutCode: root.keyboardLayoutCodes[keyboardLayoutCombo.currentIndex] || "us"
                                            property bool adjustable: root.keyboardDeadKeysAdjustable(layoutCode)

                                            Layout.fillWidth: true; spacing: root.s(6)
                                            Text { text: "Dode toetsen (accenten)"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0 }
                                            ThemedComboBox {
                                                id: keyboardDeadKeysCombo
                                                model: ["Aan", "Uit"]
                                                enabled: keyboardDeadKeysColumn.adjustable
                                                opacity: enabled ? 1.0 : 0.5
                                                currentIndex: root.normalizeKeyboardDeadKeys(
                                                    root.settingsData.keyboardDeadKeys, root.settingsData.keyboardLayout) ? 0 : 1
                                            }
                                            Text {
                                                text: !keyboardDeadKeysColumn.adjustable
                                                    ? "Deze indeling heeft geen variant zonder dode toetsen, dus ze blijven aan."
                                                    : (keyboardDeadKeysCombo.currentIndex === 0
                                                        ? "Aan: ´ ` ^ ¨ wachten op de volgende toets en maken zo é è ê ë."
                                                        : "Uit: accenttekens verschijnen meteen, zonder samen te stellen.")
                                                font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.mauve
                                                wrapMode: Text.WordWrap; Layout.fillWidth: true
                                            }
                                        }

                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: root.s(10)
                                    Text { text: "Wordt direct opgeslagen en live toegepast in Hyprland."; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(30); radius: root.s(6)
                                        color: scrollSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                        scale: scrollSaveMa.pressed ? 0.95 : 1.0
                                        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(150) } }
                                        Text { anchors.centerIn: parent; text: "Opslaan"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
                                        MouseArea {
                                            id: scrollSaveMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.saveSettings(
                                                timeFmtInput.text,
                                                dateFmtInput.text,
                                                touchpadScrollSpin.value,
                                                mouseScrollSpin.value,
                                                touchpadRightClickCombo.currentIndex === 0,
                                                root.keyboardLayoutCodes[keyboardLayoutCombo.currentIndex],
                                                keyboardDeadKeysCombo.currentIndex === 0
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =================================================================
            // TAB 2: BAR
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 2
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Thema aanpassen"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        Text { text: "Wijzigingen gelden voor één thema en worden pas bewaard als je op Opslaan drukt."; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        // Welk thema je bewerkt: altijd bovenaan, zodat duidelijk is waar
                        // Opslaan heen schrijft.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: editTargetRow.implicitHeight + root.s(28)
                            radius: root.themedRadius
                            color: Qt.alpha(root.ambientPurple, 0.10)
                            border.width: 1
                            border.color: Qt.alpha(root.ambientPurple, 0.55)
                            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(200) } }

                            RowLayout {
                                id: editTargetRow
                                anchors.fill: parent
                                anchors.margins: root.s(14)
                                spacing: root.s(12)

                                Text { text: "󰏘"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(22); color: root.ambientPurple; Layout.alignment: Qt.AlignVCenter }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: root.s(3)
                                    Text {
                                        text: root.themeEditThemeId === ""
                                              ? "Nog geen thema geladen"
                                              : "Je past thema " + root.themeEditThemeId.charAt(0).toUpperCase() + root.themeEditThemeId.slice(1) + " aan"
                                        font.family: root.displayFontFamily
                                        font.weight: root.themedFontWeight
                                        font.pixelSize: root.s(15)
                                        color: root.text
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        text: root.themeEditThemeId !== "" && root.themeEditThemeId === root.activeThemeId
                                              ? "Dit is je actieve thema. Opslaan past het meteen toe."
                                              : "Dit thema is nu niet actief. Je ziet de wijzigingen pas als je het kiest onder Thema."
                                        font.family: root.uiFontFamily
                                        font.pixelSize: root.s(11)
                                        color: root.subtext0
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                SettingsActionButton { label: "Ander thema"; icon: "󰏘"; accent: root.mauve; implicitWidth: root.s(140); onTriggered: root.openPage(1) }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(8)
                            Rectangle {
                                Layout.preferredHeight: root.s(34)
                                Layout.preferredWidth: root.s(220)
                                radius: root.s(8)
                                color: root.themeDirty
                                       ? (themeEditMa.containsMouse ? Qt.alpha(root.green, 0.90) : root.green)
                                       : Qt.alpha(root.surface1, 0.72)
                                opacity: themeCarousel.selectedThemeId === "" || root.themeSaveBusy ? 0.55 : 1.0
                                border.color: "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: root.s(6)
                                    Text {
                                        text: root.themeSaveBusy ? "󰔟" : (root.themeDirty ? "󰆓" : "󰄬")
                                        font.family: ThemeConfig.iconFont
                                        font.pixelSize: root.s(14)
                                        color: root.themeDirty ? root.base : root.subtext0
                                    }
                                    Text {
                                        text: root.themeSaveBusy
                                              ? "Opslaan..."
                                              : (root.themeDirty
                                                  ? (root.themeEditThemeId === root.activeThemeId ? "Opslaan & toepassen" : "Opslaan")
                                                  : "Geen wijzigingen")
                                        font.family: ThemeConfig.textFont
                                        font.weight: Font.Bold
                                        font.pixelSize: root.s(11)
                                        color: root.themeDirty ? root.base : root.subtext0
                                    }
                                }

                                MouseArea {
                                    id: themeEditMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: themeCarousel.selectedThemeId !== "" && !root.themeSaveBusy && root.themeDirty
                                    onClicked: root.saveThemeEdits()
                                }
                            }
                            Rectangle {
                                Layout.preferredHeight: root.s(34)
                                Layout.preferredWidth: root.s(150)
                                radius: root.s(8)
                                color: resetThemeMa.containsMouse ? Qt.alpha(root.peach, 0.20) : Qt.alpha(root.surface0, 0.65)
                                opacity: root.themeDirty && !root.themeSaveBusy ? 1.0 : 0.45
                                border.color: resetThemeMa.containsMouse ? root.peach : root.surface2
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: root.s(6)
                                    Text { text: "󰑓"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(13); color: root.peach }
                                    Text { text: "Herstel"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.text }
                                }

                                MouseArea {
                                    id: resetThemeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.themeDirty && !root.themeSaveBusy
                                    onClicked: root.resetThemeEdits()
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Rectangle {
                            visible: root.themeEditThemeId !== ""
                            Layout.fillWidth: true
                            implicitHeight: themeStatusRow.implicitHeight + root.s(14)
                            radius: root.s(8)
                            color: root.themeDirty
                                   ? Qt.alpha(root.yellow, 0.12)
                                   : (root.themeStatusKind === "error"
                                      ? Qt.alpha(root.red, 0.14)
                                      : (root.themeStatusKind === "ok"
                                         ? Qt.alpha(root.green, 0.12)
                                         : Qt.alpha(root.surface0, 0.46)))
                            border.width: 1
                            border.color: root.themeDirty
                                          ? Qt.alpha(root.yellow, 0.55)
                                          : (root.themeStatusKind === "error"
                                             ? Qt.alpha(root.red, 0.65)
                                             : (root.themeStatusKind === "ok"
                                                ? Qt.alpha(root.green, 0.55)
                                                : Qt.alpha(root.surface2, 0.72)))

                            RowLayout {
                                id: themeStatusRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: root.s(10)
                                spacing: root.s(8)

                                Text {
                                    text: root.themeDirty ? "󰐖" : (root.themeStatusKind === "error" ? "󰅚" : (root.themeStatusKind === "ok" ? "󰄬" : "󰋼"))
                                    font.family: ThemeConfig.iconFont
                                    font.pixelSize: root.s(13)
                                    color: root.themeDirty ? root.yellow : (root.themeStatusKind === "error" ? root.red : (root.themeStatusKind === "ok" ? root.green : root.blue))
                                }
                                Text {
                                    text: root.themeDirty
                                          ? "Onopgeslagen wijzigingen in " + root.themeEditThemeId + ".toml"
                                          : (root.themeStatusText !== "" ? root.themeStatusText : "Klaar")
                                    Layout.fillWidth: true
                                    font.family: ThemeConfig.textFont
                                    font.pixelSize: root.s(10)
                                    color: root.text
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(8)

                            Repeater {
                                model: root.themeEditorTabs

                                Rectangle {
                                    required property var modelData
                                    readonly property bool active: root.themeEditorTab === modelData.id

                                    width: tabContent.implicitWidth + root.s(22)
                                    height: root.s(34)
                                    radius: root.s(8)
                                    color: active
                                           ? Qt.alpha(root.blue, 0.24)
                                           : (themeEditorTabMa.containsMouse ? Qt.alpha(root.surface1, 0.72) : Qt.alpha(root.surface0, 0.56))
                                    border.width: 1
                                    border.color: active ? root.blue : (themeEditorTabMa.containsMouse ? root.surface2 : Qt.alpha(root.surface2, 0.72))

                                    RowLayout {
                                        id: tabContent
                                        anchors.centerIn: parent
                                        spacing: root.s(6)

                                        Text {
                                            text: modelData.icon
                                            font.family: ThemeConfig.iconFont
                                            font.pixelSize: root.s(13)
                                            color: parent.parent.active ? root.blue : root.subtext0
                                        }
                                        Text {
                                            text: modelData.label
                                            font.family: ThemeConfig.textFont
                                            font.weight: parent.parent.active ? Font.Bold : Font.Normal
                                            font.pixelSize: root.s(10)
                                            color: parent.parent.active ? root.text : root.subtext0
                                        }
                                    }

                                    MouseArea {
                                        id: themeEditorTabMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.themeEditorTab = modelData.id
                                    }
                                }
                            }
                        }

                        // ── Kleuren ─────────────────────────────────────────────────────────
                        ColumnLayout {
                            visible: root.themeEditorTab === "colors"
                            Layout.fillWidth: true
                            spacing: root.s(12)

                            EditorCard {
                                heading: "Kleuren"
                                hint: "De kleuren komen uit je wallpaper. Hier bepaal je hoe ze eruit worden gehaald."
                                glyph: "󰏘"
                                ChoiceRow {
                                    label: "Licht of donker"
                                    options: [{ v: "dark", t: "Donker" }, { v: "light", t: "Licht" }]
                                    current: root.editMode
                                    onPicked: (choice) => root.editMode = choice
                                }
                                ChoiceRow {
                                    label: "Kleurstijl"
                                    options: [
                                        { v: "scheme-tonal-spot", t: "Rustig" },
                                        { v: "scheme-neutral", t: "Gedempt" },
                                        { v: "scheme-monochrome", t: "Grijstinten" },
                                        { v: "scheme-fidelity", t: "Trouw aan wallpaper" },
                                        { v: "scheme-content", t: "Volgt de wallpaper" },
                                        { v: "scheme-expressive", t: "Uitgesproken" },
                                        { v: "scheme-rainbow", t: "Regenboog" },
                                        { v: "scheme-fruit-salad", t: "Fruitsalade" }
                                    ]
                                    current: root.editSchemeType
                                    hint: "Rustig is de standaard. Trouw aan wallpaper blijft het dichtst bij de echte kleuren van de afbeelding."
                                    onPicked: (choice) => root.editSchemeType = choice
                                }
                                NumberRow {
                                    label: "Contrast"
                                    hint: "0 is normaal. Hoger maakt verschillen scherper, lager zachter."
                                    minimum: -100; maximum: 100; step: 5
                                    amount: Math.round(parseFloat(root.editContrast) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editContrast", newAmount)
                                }
                                NumberRow {
                                    label: "Welke kleur uit de wallpaper"
                                    hint: "0 is de kleur die het meest voorkomt. Een hoger nummer pakt een andere kleur uit dezelfde afbeelding."
                                    minimum: 0; maximum: 12
                                    amount: root.editColorIndex
                                    onEdited: (newAmount) => root.editColorIndex = newAmount
                                }
                            }

                            EditorCard {
                                heading: "Iconen"
                                glyph: "󰀻"
                                ListRow {
                                    label: "Icoonthema"
                                    hint: "Voor apps en bestandsbeheer (GTK en Qt)."
                                    choices: root.iconThemeOptions
                                    current: root.editIconTheme
                                    onPicked: (choice) => root.editIconTheme = choice
                                }
                            }
                        }

                        // ── Letters ─────────────────────────────────────────────────────────
                        ColumnLayout {
                            visible: root.themeEditorTab === "fonts"
                            Layout.fillWidth: true
                            spacing: root.s(12)

                            EditorCard {
                                heading: "Lettertypes"
                                hint: "Gelden voor de shell, de launcher, meldingen en GTK-apps."
                                glyph: "󰛖"
                                ListRow {
                                    label: "Tekst"
                                    choices: root.fontOptions
                                    current: root.editUiFont
                                    onPicked: (choice) => root.editUiFont = choice
                                }
                                NumberRow {
                                    label: "Tekstgrootte"
                                    minimum: 8; maximum: 28
                                    amount: root.editUiFontSize
                                    onEdited: (newAmount) => root.editUiFontSize = newAmount
                                }
                                ListRow {
                                    label: "Koppen"
                                    hint: "Titels en grote getallen, zoals de klok."
                                    choices: root.fontOptions
                                    current: root.editDisplayFont
                                    onPicked: (choice) => root.editDisplayFont = choice
                                }
                                ListRow {
                                    label: "Code en terminal"
                                    choices: root.fontOptions
                                    current: root.editMonoFont
                                    onPicked: (choice) => root.editMonoFont = choice
                                }
                                NumberRow {
                                    label: "Grootte van code en terminal"
                                    minimum: 8; maximum: 28
                                    amount: root.editMonoFontSize
                                    onEdited: (newAmount) => root.editMonoFontSize = newAmount
                                }
                                ChoiceRow {
                                    label: "Dikte"
                                    options: [{ v: "light", t: "Dun" }, { v: "regular", t: "Normaal" }, { v: "medium", t: "Medium" }, { v: "bold", t: "Vet" }]
                                    current: root.editFontWeight
                                    onPicked: (choice) => root.editFontWeight = choice
                                }
                                NumberRow {
                                    label: "Letterafstand"
                                    hint: "In honderdsten van een pixel; 0 is normaal."
                                    minimum: -300; maximum: 300; step: 5
                                    amount: Math.round(parseFloat(root.editLetterSpacing) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editLetterSpacing", newAmount)
                                }
                            }
                        }

                        // ── Vensters ────────────────────────────────────────────────────────
                        ColumnLayout {
                            visible: root.themeEditorTab === "windows"
                            Layout.fillWidth: true
                            spacing: root.s(12)

                            EditorCard {
                                heading: "Vensters"
                                hint: "Hoe Hyprland je appvensters tekent. Waarden in pixels."
                                glyph: "󰖯"
                                NumberRow {
                                    label: "Hoekrondheid"
                                    minimum: 0; maximum: 64
                                    amount: root.editBorderRadius
                                    onEdited: (newAmount) => root.editBorderRadius = newAmount
                                }
                                NumberRow {
                                    label: "Randdikte"
                                    minimum: 0; maximum: 12
                                    amount: root.editBorderWidth
                                    onEdited: (newAmount) => root.editBorderWidth = newAmount
                                }
                                NumberRow {
                                    label: "Ruimte tussen vensters"
                                    minimum: 0; maximum: 60
                                    amount: root.editGapsIn
                                    onEdited: (newAmount) => root.editGapsIn = newAmount
                                }
                                NumberRow {
                                    label: "Ruimte tot de schermrand"
                                    minimum: 0; maximum: 80
                                    amount: root.editGapsOut
                                    onEdited: (newAmount) => root.editGapsOut = newAmount
                                }
                                NumberRow {
                                    label: "Vervaging achter doorzichtige vensters"
                                    hint: "0 zet vervaging uit."
                                    minimum: 0; maximum: 64
                                    amount: root.editBlurSize
                                    onEdited: (newAmount) => root.editBlurSize = newAmount
                                }
                                NumberRow {
                                    label: "Vervaging: aantal lagen"
                                    hint: "Meer lagen is zachter, maar zwaarder voor de videokaart."
                                    minimum: 0; maximum: 12
                                    amount: root.editBlurPasses
                                    onEdited: (newAmount) => root.editBlurPasses = newAmount
                                }
                            }
                        }

                        // ── Shell ───────────────────────────────────────────────────────────
                        ColumnLayout {
                            visible: root.themeEditorTab === "shell"
                            Layout.fillWidth: true
                            spacing: root.s(12)

                            EditorCard {
                                heading: "Strook en zijbalk"
                                hint: "De zijbalk zelf zet je aan of uit onder Bureaublad › Zijbalk-indeling."
                                glyph: "󰕮"
                                ChoiceRow {
                                    label: "Strook met klok en status"
                                    options: [{ v: "top", t: "Boven" }, { v: "bottom", t: "Onder" }, { v: "off", t: "Uit" }]
                                    current: root.editBarStatusStripEnabled ? root.editBarStatusStripEdge : "off"
                                    onPicked: (choice) => {
                                        if (choice === "off") {
                                            root.editBarStatusStripEnabled = false;
                                        } else {
                                            root.editBarStatusStripEnabled = true;
                                            root.editBarStatusStripEdge = choice;
                                        }
                                    }
                                }
                                NumberRow {
                                    label: "Hoogte van de strook"
                                    minimum: 30; maximum: 72
                                    amount: root.editBarStatusStripHeight
                                    onEdited: (newAmount) => root.editBarStatusStripHeight = newAmount
                                }
                                ChoiceRow {
                                    label: "Zijbalk aan de"
                                    options: [{ v: "left", t: "Linkerkant" }, { v: "right", t: "Rechterkant" }]
                                    current: root.editBarRailEdge
                                    onPicked: (choice) => root.editBarRailEdge = choice
                                }
                                NumberRow {
                                    label: "Breedte van de zijbalk"
                                    minimum: 44; maximum: 96
                                    amount: root.editBarRailWidth
                                    onEdited: (newAmount) => root.editBarRailWidth = newAmount
                                }
                            }

                            EditorCard {
                                heading: "Panelen en beweging"
                                glyph: "󰟤"
                                NumberRow {
                                    label: "Rondheid van panelen"
                                    minimum: 4; maximum: 40
                                    amount: root.editWidgetRadius
                                    onEdited: (newAmount) => root.editWidgetRadius = newAmount
                                }
                                NumberRow {
                                    label: "Dekking van panelen (%)"
                                    hint: "100 is helemaal dicht, lager laat de achtergrond doorschijnen."
                                    minimum: 10; maximum: 100
                                    amount: Math.round(parseFloat(root.editPopupOpacity) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editPopupOpacity", newAmount)
                                }
                                NumberRow {
                                    label: "Animatiesnelheid (%)"
                                    hint: "100 is normaal, hoger is sneller."
                                    minimum: 25; maximum: 300; step: 5
                                    amount: Math.round(parseFloat(root.editAnimationSpeed) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editAnimationSpeed", newAmount)
                                }
                                // Geldt direct en voor elk thema (geen opslaan nodig).
                                ChoiceRow {
                                    label: "Thema-effecten in vensters"
                                    options: [{ v: "aan", t: "Aan" }, { v: "uit", t: "Uit" }]
                                    current: ThemeConfig.themeEffects ? "aan" : "uit"
                                    onPicked: (choice) => Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/kingstra", "effecten", choice])
                                }
                                ChoiceRow {
                                    label: "Verende panelen"
                                    options: [{ v: "aan", t: "Aan" }, { v: "uit", t: "Uit" }]
                                    current: ThemeConfig.springMotion ? "aan" : "uit"
                                    onPicked: (choice) => Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/kingstra", "veren", choice])
                                }
                                ChoiceRow {
                                    label: "Bewegingsstijl"
                                    options: [{ v: "calm", t: "Rustig" }, { v: "gentle", t: "Zacht" }, { v: "snappy", t: "Vlot" }, { v: "firm", t: "Strak" }]
                                    current: root.editStyleMotion
                                    onPicked: (choice) => root.editStyleMotion = choice
                                }
                                NumberRow {
                                    label: "Randen (%)"
                                    hint: "Hoe duidelijk de randen van panelen zijn."
                                    minimum: 0; maximum: 100
                                    amount: Math.round(parseFloat(root.editOutlineStrength) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editOutlineStrength", newAmount)
                                }
                                NumberRow {
                                    label: "Glas (%)"
                                    hint: "Hoeveel glans en doorschijn panelen hebben."
                                    minimum: 0; maximum: 100
                                    amount: Math.round(parseFloat(root.editGlassStrength) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editGlassStrength", newAmount)
                                }
                                NumberRow {
                                    label: "Gloed (%)"
                                    minimum: 0; maximum: 100
                                    amount: Math.round(parseFloat(root.editGlowIntensity) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editGlowIntensity", newAmount)
                                }
                                NumberRow {
                                    label: "Thema-effecten (%)"
                                    hint: "Sterkte van effecten zoals het neonraster; 0 zet ze uit."
                                    minimum: 0; maximum: 200; step: 5
                                    amount: Math.round(parseFloat(root.editEffectIntensity) * 100)
                                    onEdited: (newAmount) => root.setEditFloat("editEffectIntensity", newAmount)
                                }
                            }

                            AdvancedSection {
                                unit: root.s(100) / 100
                                title: "Fijnafstelling"
                                icon: "󰒓"
                                hint: "Basisstijl, dichtheid, oppervlak, schaduw en marges; vooral zichtbaar in launcher en meldingen"
                                EditorCard {
                                    heading: "Stijl"
                                    glyph: "󱥰"
                                    ChoiceRow {
                                        label: "Basisstijl"
                                        hint: "Bepaalt onder meer de vorm van de muziekspeler en de lockscreen-look."
                                        options: [{ v: "paper", t: "Papier" }, { v: "organic", t: "Organisch" }, { v: "neon", t: "Neon" }, { v: "mono", t: "Mono" }, { v: "matte", t: "Mat" }]
                                        current: root.editStyleFamily
                                        onPicked: (choice) => root.editStyleFamily = choice
                                    }
                                    ChoiceRow {
                                        label: "Dichtheid"
                                        options: [{ v: "compact", t: "Compact" }, { v: "comfortable", t: "Normaal" }, { v: "airy", t: "Ruim" }]
                                        current: root.editStyleDensity
                                        onPicked: (choice) => root.editStyleDensity = choice
                                    }
                                    ChoiceRow {
                                        label: "Oppervlak"
                                        options: [{ v: "paper-glass", t: "Papierglas" }, { v: "soft-glass", t: "Zacht glas" }, { v: "hard-surface", t: "Hard" }, { v: "solid", t: "Dicht" }]
                                        current: root.editSurfaceMode
                                        onPicked: (choice) => root.editSurfaceMode = choice
                                    }
                                    NumberRow {
                                        label: "Schaduw (%)"
                                        minimum: 0; maximum: 100
                                        amount: Math.round(parseFloat(root.editPanelShadow) * 100)
                                        onEdited: (newAmount) => root.setEditFloat("editPanelShadow", newAmount)
                                    }
                                    NumberRow {
                                        label: "Binnenmarge van panelen"
                                        minimum: 6; maximum: 40
                                        amount: root.editPanelPadding
                                        onEdited: (newAmount) => root.editPanelPadding = newAmount
                                    }
                                }
                            }
                        }

                        AdvancedSection {
                            id: themeAdvancedSection
                            unit: root.s(100) / 100
                            title: "Alle themavariabelen"
                            icon: "󰘦"
                            hint: "Elke waarde uit het themabestand en de Matugen-sjablonen die bij toepassen worden gevuld"
                            Rectangle {
                                id: allVarsPanel
                                visible: true
                                Layout.fillWidth: true
                                implicitHeight: allVarsCol.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.surface1
                                border.width: 1

                                property var flatEntries: root.flattenThemeData(themeCarousel.selectedThemeData)

                                ColumnLayout {
                                    id: allVarsCol
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(8)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Alle variabelen (" + allVarsPanel.flatEntries.length + ")"
                                            font.family: ThemeConfig.textFont
                                            font.weight: Font.Bold
                                            font.pixelSize: root.s(13)
                                            color: root.text
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: themeCarousel.selectedThemeId !== "" ? themeCarousel.selectedThemeId + ".toml" : ""
                                            font.family: ThemeConfig.textFont
                                            font.pixelSize: root.s(10)
                                            color: root.overlay0
                                        }
                                    }

                                    Text {
                                        text: "Volledige key-paths uit het geselecteerde thema. Alleen ter inzage; aanpassen doe je in de blokken hierboven."
                                        font.family: ThemeConfig.textFont
                                        font.pixelSize: root.s(10)
                                        color: root.subtext0
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                Column {
                                    id: allVarsList
                                    Layout.fillWidth: true
                                    spacing: root.s(4)

                                    Repeater {
                                        model: allVarsPanel.flatEntries

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: allVarsList.width
                                            height: rowData.implicitHeight + root.s(8)
                                            radius: root.s(6)
                                            color: Qt.alpha(root.surface0, 0.52)
                                            border.color: Qt.alpha(root.surface2, 0.75)
                                            border.width: 1

                                            RowLayout {
                                                id: rowData
                                                anchors.fill: parent
                                                anchors.margins: root.s(6)
                                                spacing: root.s(10)

                                                Text {
                                                    text: String(modelData.key || "—")
                                                    font.family: ThemeConfig.textFont
                                                    font.pixelSize: root.s(10)
                                                    color: root.subtext0
                                                    Layout.preferredWidth: root.s(250)
                                                    wrapMode: Text.WrapAnywhere
                                                }

                                                Text {
                                                    text: String(modelData.value || "—")
                                                    font.family: ThemeConfig.textFont
                                                    font.pixelSize: root.s(10)
                                                    font.weight: Font.Bold
                                                    color: root.text
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WrapAnywhere
                                                }
                                            }
                                        }
                                    }
                                }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                            RowLayout {
                                spacing: root.s(8)
                                Text { text: "󰇚"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(18); color: root.ambientPurple }
                                Text { text: "Matugen Pipeline"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(14); color: root.text }
                            }

                            Text { text: "Bij toepassen van een thema worden de huidige wallpaper-kleuren opnieuw door Matugen gerenderd en in deze templates geïnjecteerd:"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                            GridLayout {
                                Layout.fillWidth: true; columns: 3; rowSpacing: root.s(6); columnSpacing: root.s(8)
                                Repeater {
                                    model: [
                                        { f: "kitty/colors.conf", i: "󰄛", c: "yellow" },
                                        { f: "quickshell/colors.json", i: "󰣆", c: "mauve" },
                                        { f: "walker/colors.css", i: "󰀻", c: "green" },
                                        { f: "zsh/omp-colors.toml", i: "󱆃", c: "blue" },
                                        { f: "hypr/lua/colors.lua", i: "󰆍", c: "peach" }
                                    ]
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: root.s(36); radius: root.s(6)
                                        color: tplMa.containsMouse ? Qt.alpha(root[modelData.c], 0.1) : root.surface0
                                        border.color: tplMa.containsMouse ? root[modelData.c] : "transparent"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: root.s(8); spacing: root.s(8)
                                            Text { text: modelData.i; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(14); color: root[modelData.c] }
                                            Text { text: modelData.f; font.family: ThemeConfig.textFont; font.pixelSize: root.s(10); color: root.text; Layout.fillWidth: true }
                                        }
                                        MouseArea { id: tplMa; anchors.fill: parent; hoverEnabled: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 6: DISPLAY
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 6
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Beeldschermen"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        SettingsInfoCard { title: "Monitorstatus"; icon: "󰍹"; accent: root.blue; value: root.displayStatusText }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: primaryDisplayColumn.implicitHeight + root.s(24)
                            radius: root.s(10)
                            color: Qt.alpha(root.surface0, 0.46)
                            border.width: 1
                            border.color: Qt.alpha(root.blue, 0.58)

                            ColumnLayout {
                                id: primaryDisplayColumn
                                anchors.fill: parent
                                anchors.margins: root.s(12)
                                spacing: root.s(8)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: root.s(8)
                                    Text { text: "󰍹"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17); color: root.blue }
                                    Text { text: "Hoofdscherm"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(14); color: root.text; Layout.fillWidth: true }
                                    Text {
                                        text: root.primaryDisplayName === "" ? "automatisch" : "vast"
                                        font.family: root.monoFontFamily
                                        font.pixelSize: root.s(10)
                                        color: root.primaryDisplayName === "" ? root.subtext0 : root.blue
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Dit scherm is het stabiele anker voor de uitgebreide zijbalk. Alle schermen houden dezelfde gesloten, afgeronde omlijsting; zo blijven de hoeken consistent."
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.s(11)
                                    color: root.subtext0
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: root.s(10)
                                    Text { text: "Hoofdzijbalk"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.text }
                                    ThemedComboBox {
                                        id: primaryDisplayCombo
                                        Layout.fillWidth: true
                                        model: root.primaryDisplayOptions
                                        currentIndex: Math.max(0, root.primaryDisplayOptions.indexOf(root.primaryDisplayName === "" ? "Automatisch (gefocusd)" : root.primaryDisplayName))
                                        enabled: !root.primaryDisplaySaveBusy
                                        onActivated: root.setPrimaryDisplay(currentText)
                                    }
                                }

                                Text {
                                    visible: root.primaryDisplayEffective !== ""
                                    text: "Nu actief: " + root.primaryDisplayEffective
                                    font.family: root.monoFontFamily
                                    font.pixelSize: root.s(10)
                                    color: root.blue
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Schermindeling openen"; icon: "󰍹"; accent: root.blue; primary: true; onTriggered: root.openShellWidget("monitors", "") }
                            SettingsActionButton { label: "Tabletmodus"; icon: "󰓶"; accent: root.peach; onTriggered: root.toggleTabletMode() }
                            SettingsActionButton { label: "Helderheid -"; icon: "󰃞"; accent: root.yellow; onTriggered: root.adjustBrightness(-5) }
                            SettingsActionButton { label: "Helderheid +"; icon: "󰃠"; accent: root.yellow; onTriggered: root.adjustBrightness(5) }
                            SettingsActionButton { label: "Nachtlicht…"; icon: "󰖔"; accent: root.peach; onTriggered: root.openPage(19) }
                            SettingsActionButton { label: "Per scherm…"; icon: "󰍹"; accent: root.mauve; onTriggered: root.openPage(0) }
                        }

                        AdvancedSection {
                            id: displayAdvancedSection
                            unit: root.s(100) / 100
                            hint: "Status per onderdeel, layout herstellen en werkruimtes vastzetten op een scherm"
                            SettingsInfoCard { title: "Actieve layout"; icon: "󰹑"; accent: root.mauve; value: root.displayLayoutText }
                            SettingsInfoCard { title: "Touch & tablet"; icon: "󰗧"; accent: root.sapphire; value: root.displayTouchText }
                            SettingsInfoCard { title: "Helderheid"; icon: "󰃠"; accent: root.yellow; value: root.displayBrightnessText }
                            SettingsInfoCard { title: "Workspace monitors"; icon: "󰧨"; accent: root.sapphire; value: root.workspaceMonitorText }
                            Flow {
                                Layout.fillWidth: true
                                spacing: root.s(10)
                                SettingsActionButton { label: "Layout herstellen"; icon: "󰁯"; accent: root.green; onTriggered: root.restoreDisplayLayout() }
                                SettingsActionButton { label: "Status verversen"; icon: "󰑓"; accent: root.green; onTriggered: root.refreshDisplayStatus() }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: workspaceMonitorColumn.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.46)
                                border.color: root.workspaceMonitorDirty ? root.sapphire : Qt.alpha(root.surface2, 0.82)
                                border.width: root.workspaceMonitorDirty ? 2 : 1

                                ColumnLayout {
                                    id: workspaceMonitorColumn
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(10)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(8)
                                        Text { text: "󰧨"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17); color: root.sapphire }
                                        Text { text: "Workspaces vastzetten"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(14); color: root.text; Layout.fillWidth: true }
                                        Text { text: root.workspaceMonitorDirty ? "gewijzigd" : "opgeslagen"; font.family: root.monoFontFamily; font.pixelSize: root.s(10); color: root.workspaceMonitorDirty ? root.sapphire : root.subtext0 }
                                    }

                                    Text {
                                        text: "Kies per workspace een monitor, of laat hem Vrij. Toegewezen workspaces verschijnen alleen op die monitor."
                                        font.family: root.uiFontFamily
                                        font.pixelSize: root.s(11)
                                        color: root.subtext0
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: width >= root.s(640) ? 2 : 1
                                        rowSpacing: root.s(8)
                                        columnSpacing: root.s(10)

                                        Repeater {
                                            model: workspaceMonitorModel

                                            delegate: RowLayout {
                                                id: workspaceMonitorRow
                                                required property int index
                                                required property int ws
                                                required property string monitor
                                                readonly property int rowIndex: index

                                                Layout.fillWidth: true
                                                spacing: root.s(8)

                                                Text {
                                                    text: "Workspace " + ws
                                                    font.family: root.uiFontFamily
                                                    font.weight: Font.Bold
                                                    font.pixelSize: root.s(11)
                                                    color: root.text
                                                    Layout.preferredWidth: root.s(105)
                                                }

                                                ThemedComboBox {
                                                    Layout.fillWidth: true
                                                    model: root.workspaceMonitorOptions
                                                    currentIndex: Math.max(0, root.workspaceMonitorOptions.indexOf(monitor === "" ? "Vrij" : monitor))
                                                    onActivated: root.setWorkspaceMonitorAssignment(workspaceMonitorRow.rowIndex, currentText === "Vrij" ? "" : currentText)

                                                    background: Rectangle {
                                                        radius: root.s(8)
                                                        color: Qt.alpha(root.surface0, 0.78)
                                                        border.width: 1
                                                        border.color: parent.visualFocus
                                                            ? root.blue
                                                            : parent.hovered
                                                                ? Qt.alpha(root.surface2, 0.95)
                                                                : workspaceMonitorRow.monitor !== ""
                                                                    ? Qt.alpha(root.sapphire, 0.55)
                                                                    : Qt.alpha(root.surface2, 0.78)
                                                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(120) } }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        SettingsActionButton {
                                            label: root.workspaceMonitorSaveBusy ? "Opslaan..." : (root.workspaceMonitorDirty ? "Toewijzingen opslaan" : "Opgeslagen")
                                            icon: root.workspaceMonitorDirty ? "󰆓" : "󰄬"
                                            accent: root.sapphire
                                            primary: root.workspaceMonitorDirty
                                            onTriggered: if (root.workspaceMonitorDirty && !root.workspaceMonitorSaveBusy) root.saveWorkspaceMonitorAssignments()
                                        }
                                        SettingsActionButton { label: "Herlaad toewijzingen"; icon: "󰑓"; accent: root.green; onTriggered: workspaceMonitorLoadProc.running = true }
                                    }
                                }
                            }

                            SettingsInfoCard { title: "Opslaan"; icon: "󰆓"; accent: root.peach; value: "De monitor UI bewaart layouts in lokale Lua-bestanden. Die blijven buiten Git, terwijl vrije workspaces gewoon overal gebruikt blijven worden." }
                        }
                        Item { Layout.preferredHeight: root.s(8) }
                    }
                }
            }

            // =================================================================
            // TAB 7: NETWORK
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 7
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    spacing: root.s(14)

                    Text { text: "Netwerk"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                    SettingsInfoCard { title: "Wifi"; icon: "󰤨"; accent: root.blue; value: root.networkStatusText }

                    Flow {
                        Layout.fillWidth: true
                        spacing: root.s(10)
                        SettingsActionButton { label: "Wifi-paneel"; icon: "󰤨"; accent: root.blue; primary: true; onTriggered: root.openShellWidget("network", "wifi") }
                        SettingsActionButton { label: "Bluetooth-paneel"; icon: "󰂯"; accent: root.sapphire; onTriggered: root.openShellWidget("network", "bt") }
                        SettingsActionButton { label: "Status verversen"; icon: "󰑓"; accent: root.green; onTriggered: networkStatusProc.running = true }
                    }

                    SettingsInfoCard { title: "Verbinden"; icon: "󰌾"; accent: root.yellow; value: "Netwerken kiezen en wachtwoorden invullen doe je in het wifi-paneel." }
                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 8: AUDIO
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 8
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Geluid"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        Text {
                            text: "Snelle mixer voor output, input en actieve streams. Het volumepaneel (Geluid & media) heeft daarnaast apparaatkeuze, poorten, per-app volume en de speler."
                            font.family: root.uiFontFamily
                            font.pixelSize: root.s(11)
                            color: root.subtext0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        SettingsInfoCard { title: "Audiostatus"; icon: "󰕾"; accent: root.green; value: root.audioStatusText }

                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Volume-paneel"; icon: "󰕾"; accent: root.green; primary: true; onTriggered: root.openShellWidget("volume", "") }
                            SettingsActionButton { label: "Status verversen"; icon: "󰑓"; accent: root.blue; onTriggered: root.refreshAudioState() }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width >= root.s(820) ? 2 : 1
                            rowSpacing: root.s(10)
                            columnSpacing: root.s(10)

                            AudioVolumeCard {
                                Layout.fillWidth: true
                                property var activeOutput: root.audioPrimaryNode(root.audioOutputs)
                                title: activeOutput ? (activeOutput.description || activeOutput.name || "Default output") : "Default output"
                                subtitle: root.audioSummaryText("outputs", activeOutput)
                                icon: root.audioIconFor("outputs", activeOutput)
                                accent: root.green
                                volume: activeOutput ? activeOutput.volume : 0
                                muted: activeOutput ? !!activeOutput.mute : false
                                audioType: "sink"
                                audioId: activeOutput ? activeOutput.id : ""
                                allowSetDefault: false
                                isDefault: true
                            }

                            AudioVolumeCard {
                                Layout.fillWidth: true
                                property var activeInput: root.audioPrimaryNode(root.audioInputs)
                                title: activeInput ? (activeInput.description || activeInput.name || "Default input") : "Default input"
                                subtitle: root.audioSummaryText("inputs", activeInput)
                                icon: root.audioIconFor("inputs", activeInput)
                                accent: root.sapphire
                                volume: activeInput ? activeInput.volume : 0
                                muted: activeInput ? !!activeInput.mute : false
                                audioType: "source"
                                audioId: activeInput ? activeInput.id : ""
                                allowSetDefault: false
                                isDefault: true
                            }
                        }

                        SettingsInfoCard {
                            visible: !root.audioStateBusy && root.audioOutputs.length === 0 && root.audioInputs.length === 0
                            title: "Geen audio stack"
                            icon: "󰖁"
                            accent: root.peach
                            value: "Er zijn geen audio devices gevonden. Controleer PipeWire, WirePlumber of PulseAudio."
                        }

                        AdvancedSection {
                            id: audioAdvancedSection
                            unit: root.s(100) / 100
                            title: "Alle apparaten en apps"
                            icon: "󰕾"
                            hint: "Elk uitvoer- en invoerapparaat apart, standaard kiezen en volume per app"
                            Text { text: "Uitvoer"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(18); color: root.text }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.s(10)

                                Repeater {
                                    model: root.audioOutputs
                                    delegate: AudioVolumeCard {
                                        required property var modelData
                                        title: String(modelData.description || modelData.name || "Output")
                                        subtitle: String(modelData.name || "")
                                        icon: root.audioIconFor("outputs", modelData)
                                        accent: root.green
                                        volume: Number(modelData.volume) || 0
                                        muted: !!modelData.mute
                                        audioType: "sink"
                                        audioId: String(modelData.id || "")
                                        allowSetDefault: true
                                        isDefault: !!modelData.is_default
                                        onSetDefaultRequested: root.setDefaultAudioDevice("sink", modelData.id, modelData.name)
                                    }
                                }
                            }

                            Text { text: "Invoer"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(18); color: root.text }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.s(10)

                                Repeater {
                                    model: root.audioInputs
                                    delegate: AudioVolumeCard {
                                        required property var modelData
                                        title: String(modelData.description || modelData.name || "Input")
                                        subtitle: String(modelData.name || "")
                                        icon: root.audioIconFor("inputs", modelData)
                                        accent: root.sapphire
                                        volume: Number(modelData.volume) || 0
                                        muted: !!modelData.mute
                                        audioType: "source"
                                        audioId: String(modelData.id || "")
                                        allowSetDefault: true
                                        isDefault: !!modelData.is_default
                                        onSetDefaultRequested: root.setDefaultAudioDevice("source", modelData.id, modelData.name)
                                    }
                                }
                            }

                            Text { text: "App-streams"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(18); color: root.text }
                            SettingsInfoCard {
                                visible: root.audioApps.length === 0
                                title: "Geen actieve streams"
                                icon: "󰎆"
                                accent: root.mauve
                                value: "Start media of een app met geluid om hier per-app volume te regelen."
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.s(10)

                                Repeater {
                                    model: root.audioApps
                                    delegate: AudioVolumeCard {
                                        required property var modelData
                                        title: String(modelData.description || modelData.name || "App-stream")
                                        subtitle: String(modelData.name || "")
                                        icon: root.audioIconFor("apps", modelData)
                                        accent: root.mauve
                                        volume: Number(modelData.volume) || 0
                                        muted: !!modelData.mute
                                        audioType: "sink-input"
                                        audioId: String(modelData.id || "")
                                        allowSetDefault: false
                                        isDefault: false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 10: SESSION
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 10
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Sessie"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }


                        SettingsInfoCard { title: "Stand"; icon: "󰒲"; accent: root.mauve; value: "Werken, Kijken en luisteren of Spelen kies je met Super+A; per scherm onder Schermen › Per scherm. Nu actief: " + (root.sessionModeText || "onbekend") }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Vergrendelen"; icon: "󰌾"; accent: root.yellow; onTriggered: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"]) }
                            SettingsActionButton { label: "Uitlogmenu"; icon: "󰍃"; accent: root.red; onTriggered: Quickshell.execDetached(["wlogout"]) }
                            Item { Layout.fillWidth: true }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: closeFullyEditor.implicitHeight + root.s(28)
                            radius: root.s(12)
                            color: Qt.alpha(root.surface0, 0.46)
                            border.color: Qt.alpha(root.surface2, 0.82)
                            border.width: 1

                            ColumnLayout {
                                id: closeFullyEditor
                                anchors.fill: parent
                                anchors.margins: root.s(14)
                                spacing: root.s(10)

                                Text { text: "Apps echt sluiten"; font.family: root.uiFontFamily; font.weight: Font.Bold; font.pixelSize: root.s(14); color: root.text }
                                Text {
                                    text: "Apps op deze lijst stoppen helemaal zodra je hun laatste venster sluit (Super+Q of de X), in plaats van op de achtergrond in de tray te blijven. Een naam past op elke app-klasse waar hij in voorkomt. Daarnaast sluit Super+Shift+Q elke app direct af, en Shift+klik op een tray-icoon ook."
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.s(11)
                                    color: root.subtext0
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: root.s(8)

                                    Text {
                                        visible: root.closeFullyList.length === 0
                                        text: "Nog geen apps: alles mag naar de tray."
                                        font.family: root.uiFontFamily
                                        font.pixelSize: root.s(11)
                                        color: root.subtext0
                                    }

                                    Repeater {
                                        model: root.closeFullyList
                                        delegate: Rectangle {
                                            id: closeFullyChip
                                            required property var modelData
                                            implicitWidth: closeFullyChipRow.implicitWidth + root.s(20)
                                            implicitHeight: root.s(30)
                                            radius: root.s(15)
                                            color: Qt.alpha(root.red, closeFullyChipMa.containsMouse ? 0.22 : 0.12)
                                            border.width: 1
                                            border.color: Qt.alpha(root.red, closeFullyChipMa.containsMouse ? 0.9 : 0.45)
                                            scale: closeFullyChipMa.pressed ? 0.96 : 1.0
                                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                            Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }

                                            RowLayout {
                                                id: closeFullyChipRow
                                                anchors.centerIn: parent
                                                spacing: root.s(6)
                                                Text { text: closeFullyChip.modelData; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.text }
                                                Text { text: "󰅖"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(12); color: closeFullyChipMa.containsMouse ? root.red : root.subtext0 }
                                            }
                                            MouseArea {
                                                id: closeFullyChipMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.changeCloseFully("remove", closeFullyChip.modelData)
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: root.s(10)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.s(36)
                                        radius: root.s(8)
                                        color: root.surface0
                                        border.color: closeFullyInput.activeFocus ? root.blue : root.surface2
                                        border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }

                                        TextInput {
                                            id: closeFullyInput
                                            anchors.fill: parent
                                            anchors.leftMargin: root.s(10)
                                            anchors.rightMargin: root.s(10)
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: ThemeConfig.textFont
                                            font.pixelSize: root.s(12)
                                            color: root.text
                                            clip: true
                                            selectByMouse: true
                                            onAccepted: { root.changeCloseFully("add", text); text = ""; }
                                            Text { text: "App-klasse, bijv. chatgpt of discord"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                    }

                                    SettingsActionButton {
                                        implicitWidth: root.s(120)
                                        label: "Toevoegen"
                                        icon: "󰐕"
                                        accent: root.red
                                        onTriggered: { root.changeCloseFully("add", closeFullyInput.text); closeFullyInput.text = ""; }
                                    }
                                }

                                Text {
                                    visible: closeFullyOpenFlow.shownCount > 0
                                    text: "Nu open, klik om toe te voegen:"
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.s(11)
                                    color: root.subtext0
                                }

                                Flow {
                                    id: closeFullyOpenFlow
                                    readonly property int shownCount: root.closeFullyOpenClasses.filter(c => !root.closeFullyCovers(c)).length
                                    Layout.fillWidth: true
                                    spacing: root.s(8)

                                    Repeater {
                                        model: root.closeFullyOpenClasses.filter(c => !root.closeFullyCovers(c))
                                        delegate: Rectangle {
                                            id: openClassChip
                                            required property var modelData
                                            implicitWidth: openClassRow.implicitWidth + root.s(20)
                                            implicitHeight: root.s(30)
                                            radius: root.s(15)
                                            color: openClassMa.containsMouse ? root.popupPanelHoverFill : Qt.alpha(root.surface0, 0.62)
                                            border.width: 1
                                            border.color: openClassMa.containsMouse ? root.blue : root.surface2
                                            scale: openClassMa.pressed ? 0.96 : 1.0
                                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                            Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }

                                            RowLayout {
                                                id: openClassRow
                                                anchors.centerIn: parent
                                                spacing: root.s(6)
                                                Text { text: "󰐕"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(12); color: openClassMa.containsMouse ? root.blue : root.subtext0 }
                                                Text { text: openClassChip.modelData; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.text }
                                            }
                                            MouseArea {
                                                id: openClassMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.changeCloseFully("add", openClassChip.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        AdvancedSection {
                            id: sessionAdvancedSection
                            unit: root.s(100) / 100
                            title: "Automatisch vergrendelen en slaapstand"
                            icon: "󰒲"
                            hint: "Per energieprofiel: wanneer vergrendelen, scherm uit en slaapstand"
                            SettingsInfoCard { title: "Idle gedrag"; icon: "󰒳"; accent: root.blue; value: root.sessionIdleSummary() }
                            Flow {
                                Layout.fillWidth: true
                                spacing: root.s(10)
                                SettingsActionButton { label: "Stand opnieuw toepassen"; icon: "󰑓"; accent: root.sapphire; onTriggered: sessionModeProc.running = true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: sessionIdleEditor.implicitHeight + root.s(28)
                                radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.46)
                                border.color: Qt.alpha(root.surface2, 0.82)
                                border.width: 1

                                ColumnLayout {
                                    id: sessionIdleEditor
                                    anchors.fill: parent
                                    anchors.margins: root.s(14)
                                    spacing: root.s(12)

                                    Text { text: "Automatische idle-acties"; font.family: root.uiFontFamily; font.weight: Font.Bold; font.pixelSize: root.s(14); color: root.text }
                                    Text {
                                        text: "Stel idle-gedrag per batterijmodus in. Alles hieronder wordt samen opgeslagen; het actieve power profile gebruikt daarna automatisch zijn eigen lock-, scherm-uit- en suspend-waardes."
                                        font.family: root.uiFontFamily
                                        font.pixelSize: root.s(11)
                                        color: root.subtext0
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    SettingsInfoCard {
                                        title: "Power profile"
                                        icon: "󰌪"
                                        accent: root.green
                                        value: "Actief: " + root.powerProfileLabel(root.currentPowerProfileText) +
                                            "\n" + root.idleProfileSummary("performance") +
                                            "\n" + root.idleProfileSummary("balanced") +
                                            "\n" + root.idleProfileSummary("power-saver")
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: width >= root.s(720) ? 3 : 1
                                        rowSpacing: root.s(10)
                                        columnSpacing: root.s(10)

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: perfIdleEditor.implicitHeight + root.s(24)
                                            radius: root.s(10)
                                            color: Qt.alpha(root.surface0, 0.50)
                                            border.color: Qt.alpha(root.red, 0.35)
                                            border.width: 1

                                            ColumnLayout {
                                                id: perfIdleEditor
                                                anchors.fill: parent
                                                anchors.margins: root.s(12)
                                                spacing: root.s(8)

                                                Text { text: "Performance"; font.family: root.uiFontFamily; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.red }
                                                Text { text: "Ruimere timeouts, bedoeld voor aan de lader of lange actieve sessies."; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                                                Text { text: "Automatisch locken"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: perfIdleLockCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("performance").idleLockSeconds)
                                                }

                                                Text { text: "Scherm uit (DPMS)"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: perfIdleScreenOffCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("performance").idleScreenOffSeconds)
                                                }

                                                Text { text: "Suspend / slaapstand"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: perfIdleSuspendCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("performance").idleSuspendSeconds)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: balancedIdleEditor.implicitHeight + root.s(24)
                                            radius: root.s(10)
                                            color: Qt.alpha(root.surface0, 0.50)
                                            border.color: Qt.alpha(root.blue, 0.35)
                                            border.width: 1

                                            ColumnLayout {
                                                id: balancedIdleEditor
                                                anchors.fill: parent
                                                anchors.margins: root.s(12)
                                                spacing: root.s(8)

                                                Text { text: "Balanced"; font.family: root.uiFontFamily; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.blue }
                                                Text { text: "Dagelijks profiel met een normale balans tussen comfort en batterijduur."; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                                                Text { text: "Automatisch locken"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: balancedIdleLockCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("balanced").idleLockSeconds)
                                                }

                                                Text { text: "Scherm uit (DPMS)"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: balancedIdleScreenOffCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("balanced").idleScreenOffSeconds)
                                                }

                                                Text { text: "Suspend / slaapstand"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: balancedIdleSuspendCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("balanced").idleSuspendSeconds)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: saverIdleEditor.implicitHeight + root.s(24)
                                            radius: root.s(10)
                                            color: Qt.alpha(root.surface0, 0.50)
                                            border.color: Qt.alpha(root.green, 0.35)
                                            border.width: 1

                                            ColumnLayout {
                                                id: saverIdleEditor
                                                anchors.fill: parent
                                                anchors.margins: root.s(12)
                                                spacing: root.s(8)

                                                Text { text: "Saver"; font.family: root.uiFontFamily; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.green }
                                                Text { text: "Strakkere timeouts voor onderweg of batterij sparen."; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                                                Text { text: "Automatisch locken"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: saverIdleLockCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("power-saver").idleLockSeconds)
                                                }

                                                Text { text: "Scherm uit (DPMS)"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: saverIdleScreenOffCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("power-saver").idleScreenOffSeconds)
                                                }

                                                Text { text: "Suspend / slaapstand"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                                ThemedComboBox {
                                                    id: saverIdleSuspendCombo
                                                    model: root.idleTimeoutOptions
                                                    currentIndex: root.idleTimeoutOptionIndex(root.idleProfileSettings("power-saver").idleSuspendSeconds)
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text {
                                            text: "Opslaan herschrijft ~/.config/hypridle/hypridle.conf en start hypridle opnieuw."
                                            font.family: root.uiFontFamily
                                            font.pixelSize: root.s(11)
                                            color: root.subtext0
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.preferredWidth: root.s(94)
                                            Layout.preferredHeight: root.s(32)
                                            radius: root.s(8)
                                            color: sessionSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                            scale: sessionSaveMa.pressed ? 0.95 : 1.0
                                            Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(150) } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Opslaan"
                                                font.family: root.uiFontFamily
                                                font.weight: Font.Bold
                                                font.pixelSize: root.s(12)
                                                color: root.base
                                            }

                                            MouseArea {
                                                id: sessionSaveMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.saveSettings(
                                                    root.settingsData.timeFormat,
                                                    root.settingsData.dateFormat,
                                                    root.scrollPercentFromSetting(root.settingsData.touchpadScrollFactor, 0.45),
                                                    root.scrollPercentFromSetting(root.settingsData.mouseScrollFactor, 1.35),
                                                    root.settingsData.touchpadRightClickButtonArea,
                                                    root.settingsData.keyboardLayout,
                                                    root.settingsData.keyboardDeadKeys,
                                                    root.idleTimeoutSeconds(balancedIdleLockCombo.currentIndex),
                                                    root.idleTimeoutSeconds(balancedIdleScreenOffCombo.currentIndex),
                                                    root.idleTimeoutSeconds(balancedIdleSuspendCombo.currentIndex),
                                                    ({
                                                        "performance": {
                                                            idleLockSeconds: root.idleTimeoutSeconds(perfIdleLockCombo.currentIndex),
                                                            idleScreenOffSeconds: root.idleTimeoutSeconds(perfIdleScreenOffCombo.currentIndex),
                                                            idleSuspendSeconds: root.idleTimeoutSeconds(perfIdleSuspendCombo.currentIndex)
                                                        },
                                                        "balanced": {
                                                            idleLockSeconds: root.idleTimeoutSeconds(balancedIdleLockCombo.currentIndex),
                                                            idleScreenOffSeconds: root.idleTimeoutSeconds(balancedIdleScreenOffCombo.currentIndex),
                                                            idleSuspendSeconds: root.idleTimeoutSeconds(balancedIdleSuspendCombo.currentIndex)
                                                        },
                                                        "power-saver": {
                                                            idleLockSeconds: root.idleTimeoutSeconds(saverIdleLockCombo.currentIndex),
                                                            idleScreenOffSeconds: root.idleTimeoutSeconds(saverIdleScreenOffCombo.currentIndex),
                                                            idleSuspendSeconds: root.idleTimeoutSeconds(saverIdleSuspendCombo.currentIndex)
                                                        }
                                                    })
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            SettingsInfoCard { title: "Bewuste beperking"; icon: "󰅚"; accent: root.red; value: "Shutdown/reboot staan hier nog niet als directe knoppen. Die horen achter een bevestiging of in wlogout." }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =================================================================
            // TAB 11: UPDATES — wat er klaarstaat, bijwerken, uitkomst
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 11
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Updates"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily
                            font.pixelSize: root.s(11)
                            color: root.subtext0
                            text: root.upPlanBusy ? "Zoeken naar updates…"
                                : (root.upPlan.checked ? ("Gecontroleerd " + root.fmtWhen(root.upPlan.checked) + ". Er wordt niets geïnstalleerd tot je op Bijwerken drukt.")
                                                       : "Nog niet gecontroleerd.")
                        }

                        // Samenvatting met de grote knop.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: upSummaryRow.implicitHeight + root.s(28)
                            radius: root.s(14)
                            color: Qt.alpha(root.upPlan.total > 0 ? root.green : root.surface0, root.upPlan.total > 0 ? 0.12 : 0.46)
                            border.width: 1
                            border.color: Qt.alpha(root.upPlan.total > 0 ? root.green : root.surface2, 0.6)
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }

                            RowLayout {
                                id: upSummaryRow
                                anchors.fill: parent
                                anchors.margins: root.s(14)
                                spacing: root.s(14)
                                Text {
                                    text: root.upPlanBusy ? "󰑓" : (root.upPlan.total > 0 ? "󰚰" : "󰄬")
                                    font.family: ThemeConfig.iconFont
                                    font.pixelSize: root.s(30)
                                    color: root.upPlan.total > 0 ? root.green : root.subtext0
                                    RotationAnimation on rotation { running: root.upPlanBusy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: root.s(2)
                                    Text {
                                        text: root.upPlan.total > 0 ? (root.upPlan.total + " updates klaar") : (root.upPlanBusy ? "Even zoeken…" : "Alles is bij")
                                        font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(18); color: root.text
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        visible: root.upPlan.repo > 0
                                        font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0
                                        text: (root.upPlan.downloaded || 0) + " van " + (root.upPlan.repo || 0) + " pakketten al gedownload"
                                              + (root.upPlan.kernel ? " · nieuwe kernel, daarna herstarten" : "")
                                    }
                                }
                                SettingsActionButton { label: "Bijwerken"; icon: "󰚰"; accent: root.green; primary: true; onTriggered: root.runPackageUpgrade() }
                            }
                        }

                        // Arch-nieuws: soms is er handwerk nodig vóór de update.
                        Rectangle {
                            Layout.fillWidth: true
                            visible: (root.upPlan.news || []).length > 0
                            implicitHeight: upNewsCol.implicitHeight + root.s(24)
                            radius: root.s(10)
                            color: Qt.alpha(root.yellow, 0.12)
                            border.width: 1
                            border.color: Qt.alpha(root.yellow, 0.55)
                            ColumnLayout {
                                id: upNewsCol
                                anchors.fill: parent
                                anchors.margins: root.s(12)
                                spacing: root.s(6)
                                RowLayout {
                                    spacing: root.s(8)
                                    Text { text: "󰎕"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17); color: root.yellow }
                                    Text { text: "Arch-nieuws sinds je vorige update"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(14); color: root.text }
                                }
                                Repeater {
                                    model: root.upPlan.news || []
                                    delegate: Text {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        font.family: root.uiFontFamily; font.pixelSize: root.s(12); color: root.text
                                        text: modelData.date + "  " + modelData.title
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0
                                    text: "Lees ze op archlinux.org/news als er handwerk bij staat. De update vraagt het ook nog."
                                }
                            }
                        }

                        // Groepen: Systeem en kernel, Apps, AUR, Flatpak, Kingstra.
                        Repeater {
                            model: (root.upPlan.groups || []).filter(function(g) { return (g.items || []).length > 0 || (g.notes || []).length > 0; })
                            delegate: Rectangle {
                                id: upGroup
                                required property var modelData
                                property bool open: modelData.id === "systeem" || modelData.id === "kingstra"
                                Layout.fillWidth: true
                                implicitHeight: upGroupCol.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.46)
                                border.width: 1
                                border.color: Qt.alpha(root.surface2, 0.82)
                                Behavior on implicitHeight { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }

                                ColumnLayout {
                                    id: upGroupCol
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(6)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(8)
                                        Text {
                                            text: upGroup.modelData.id === "systeem" ? "󰒓" : upGroup.modelData.id === "kingstra" ? "󰣇"
                                                  : upGroup.modelData.id === "flatpak" ? "󰏖" : upGroup.modelData.id === "aur" ? "󰣇" : "󰀻"
                                            font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17)
                                            color: upGroup.modelData.id === "systeem" ? root.peach : root.blue
                                        }
                                        Text {
                                            text: upGroup.modelData.title
                                            font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(14); color: root.text
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: upGroup.modelData.id === "kingstra"
                                                  ? ((upGroup.modelData.items || []).length + " nieuw")
                                                  : String((upGroup.modelData.items || []).length)
                                            font.family: root.uiFontFamily; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.subtext0
                                        }
                                        Text {
                                            text: upGroup.open ? "󰅃" : "󰅀"
                                            font.family: ThemeConfig.iconFont; font.pixelSize: root.s(15); color: root.subtext0
                                        }
                                    }
                                    // Kingstra: de CHANGELOG-regels, anders de pakketten met versiesprong.
                                    Repeater {
                                        model: upGroup.open
                                               ? (upGroup.modelData.id === "kingstra" && (upGroup.modelData.notes || []).length > 0
                                                  ? upGroup.modelData.notes : (upGroup.modelData.items || []).slice(0, 60))
                                               : []
                                        delegate: Text {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            font.family: typeof modelData === "string" ? root.uiFontFamily : "monospace"
                                            font.pixelSize: root.s(typeof modelData === "string" ? 12 : 11)
                                            color: typeof modelData === "string" ? root.text
                                                   : (modelData.downloaded ? root.subtext0 : root.text)
                                            text: typeof modelData === "string" ? ("• " + modelData) : root.upGroupLine(modelData)
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: upGroup.open = !upGroup.open
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Opnieuw zoeken"; icon: "󰑓"; accent: root.peach; onTriggered: root.refreshUpdatePage(true) }
                            SettingsActionButton { label: "Laatste update terugdraaien"; icon: "󰕍"; accent: root.red; onTriggered: root.runSystemRollback() }
                            SettingsActionButton { label: "Herstelmenu"; icon: "󰁨"; accent: root.mauve; onTriggered: root.openRescueMenu() }
                            SettingsActionButton { label: "Dotfiles update"; icon: "󰐕"; accent: root.blue; onTriggered: root.runUpdateBootstrap() }
                        }

                        // Uitkomst van de vorige run.
                        Rectangle {
                            Layout.fillWidth: true
                            visible: (root.upResult.items || []).length > 0
                            implicitHeight: upResultCol.implicitHeight + root.s(24)
                            radius: root.s(10)
                            color: Qt.alpha(root.surface0, 0.46)
                            border.width: 1
                            border.color: Qt.alpha(root.upResult.exit ? root.red : root.surface2, 0.82)
                            ColumnLayout {
                                id: upResultCol
                                anchors.fill: parent
                                anchors.margins: root.s(12)
                                spacing: root.s(6)
                                RowLayout {
                                    spacing: root.s(8)
                                    Text { text: root.upResult.exit ? "󰅚" : "󰄬"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17); color: root.upResult.exit ? root.red : root.green }
                                    Text {
                                        text: "Vorige update · " + root.fmtWhen(root.upResult.time)
                                        font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(14); color: root.text
                                    }
                                }
                                Repeater {
                                    model: root.upResult.items || []
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: root.s(8)
                                        Text {
                                            text: modelData.kind === "ok" ? "󰄬" : (modelData.kind === "warn" ? "󰀦" : "󰅚")
                                            font.family: ThemeConfig.iconFont; font.pixelSize: root.s(13)
                                            color: modelData.kind === "ok" ? root.green : (modelData.kind === "warn" ? root.yellow : root.red)
                                            Layout.alignment: Qt.AlignTop
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            font.family: root.uiFontFamily; font.pixelSize: root.s(12); color: root.text
                                            text: modelData.text
                                        }
                                    }
                                }
                            }
                        }

                        // Gezondheid: dezelfde check als na een update.
                        Rectangle {
                            Layout.fillWidth: true
                            visible: root.vnHealth.length > 0
                            implicitHeight: vnHealthCol.implicitHeight + root.s(24)
                            radius: root.s(10)
                            color: Qt.alpha(root.surface0, 0.46)
                            border.width: 1
                            border.color: Qt.alpha(root.surface2, 0.82)
                            ColumnLayout {
                                id: vnHealthCol
                                anchors.fill: parent
                                anchors.margins: root.s(12)
                                spacing: root.s(6)
                                RowLayout {
                                    spacing: root.s(8)
                                    Text { text: "󰓙"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(17); color: root.sapphire }
                                    Text { text: "Gezondheid"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(14); color: root.text }
                                }
                                Repeater {
                                    model: root.vnHealth
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: root.s(8)
                                        Text {
                                            text: modelData.level === 0 ? "󰄬" : (modelData.level === 1 ? "󰀦" : "󰅚")
                                            font.family: ThemeConfig.iconFont; font.pixelSize: root.s(13)
                                            color: modelData.level === 0 ? root.green : (modelData.level === 1 ? root.yellow : root.red)
                                            Layout.alignment: Qt.AlignTop
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            font.family: root.uiFontFamily; font.pixelSize: root.s(12); color: root.text
                                            text: modelData.text
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0
                            text: "Bijwerken opent een terminal, want daar vraagt het systeem je wachtwoord. Pakketten worden 's nachts alvast gedownload; geïnstalleerd wordt pas als jij het zegt."
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =================================================================
            // TAB 20: BACK-UP
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 20
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Back-up"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0
                            text: "Elk uur een versie van je persoonlijke map op een andere schijf. Alleen wat veranderd is wordt opgeslagen. Bewaard: 24 per uur, 14 per dag, 8 per week en 12 per maand."
                        }

                        Rectangle {
                            id: bkCard
                            readonly property bool healthy: !!root.bkStatus.last_ok && (Date.now() / 1000 - root.bkStatus.last_ok) < 3 * 86400
                            readonly property color tone: root.bkStatus.enabled === false ? root.subtext0
                                                          : (root.bkStatus.running ? root.blue : (healthy ? root.green : root.yellow))
                            Layout.fillWidth: true
                            implicitHeight: bkRow.implicitHeight + root.s(28)
                            radius: root.s(14)
                            color: Qt.alpha(tone, 0.12)
                            border.width: 1
                            border.color: Qt.alpha(tone, 0.6)
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }

                            RowLayout {
                                id: bkRow
                                anchors.fill: parent
                                anchors.margins: root.s(14)
                                spacing: root.s(14)
                                Text {
                                    text: root.bkStatus.running ? "󰑓" : "󰁯"
                                    font.family: ThemeConfig.iconFont; font.pixelSize: root.s(30); color: bkCard.tone
                                    RotationAnimation on rotation { running: !!root.bkStatus.running; from: 0; to: 360; duration: 1400; loops: Animation.Infinite }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: root.s(2)
                                    Text {
                                        font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(18); color: root.text
                                        text: root.bkStatus.enabled === false ? "Back-up staat uit"
                                              : root.bkStatus.running ? "Bezig met een back-up…"
                                              : ("Laatste back-up: " + root.fmtWhen(root.bkStatus.last_ok))
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0
                                        text: root.bkStatus.enabled === false
                                              ? "Geen datadisk gevonden. Zet hem aan in ~/.config/kingstra/backup.conf."
                                              : ((root.bkStatus.snapshots || 0) + " versies · " + root.fmtBytes(root.bkStatus.repo_size)
                                                 + " in " + (root.bkStatus.repo || "?")
                                                 + (root.bkStatus.free ? " · " + root.fmtBytes(root.bkStatus.free) + " vrij" : ""))
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: !!root.bkStatus.error
                                        wrapMode: Text.WordWrap
                                        font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.yellow
                                        text: root.bkStatus.error || ""
                                    }
                                }
                                SettingsActionButton {
                                    label: "Nu maken"; icon: "󰁯"; accent: root.green; primary: true
                                    onTriggered: root.backupAction("run")
                                }
                            }
                        }

                        SettingsInfoCard {
                            title: "Tweede kopie"
                            icon: "󰆏"
                            accent: root.sapphire
                            value: root.bkStatus.copy
                                   ? ("Wekelijks naar " + root.bkStatus.copy + ". Laatst: " + root.fmtWhen(root.bkStatus.copy_ok) + ".")
                                   : "Nog geen tweede kopie gemaakt. Die komt wekelijks op een andere schijf, zodat één kapotte schijf je niets kost."
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Versies bekijken"; icon: "󰉋"; accent: root.blue; onTriggered: root.backupAction("browse") }
                            SettingsActionButton { label: "Map sluiten"; icon: "󰉖"; accent: root.overlay0; onTriggered: root.backupAction("close") }
                            SettingsActionButton { label: "Tweede kopie nu"; icon: "󰆏"; accent: root.sapphire; onTriggered: root.backupAction("copy") }
                        }

                        SettingsInfoCard {
                            title: "Iets terughalen"
                            icon: "󰕍"
                            accent: root.mauve
                            value: "Versies bekijken opent ~/Back-up/snapshots in Bestanden: elke map is een moment. Sleep wat je nodig hebt terug. Of in een terminal: kingstra backup restore <pad>, dan komt het naast het origineel als <naam>.terug."
                        }
                        SettingsInfoCard {
                            title: "Wat er niet in zit"
                            icon: "󰈉"
                            accent: root.overlay0
                            value: "Caches, prullenbak, Steam en ~/Games, Claude-VM's, node_modules. Eigen uitzonderingen zet je in ~/.config/kingstra/backup-exclude.local.txt, één pad per regel."
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =================================================================
            // TAB 21: RUIMTE — wat neemt ruimte in, wat kan veilig weg
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 21
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Ruimte"; Layout.fillWidth: true; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                            SettingsActionButton {
                                label: root.spaceBusy ? "Meten…" : "Opnieuw meten"; icon: "󰑓"; accent: root.blue
                                onTriggered: if (!root.spaceBusy) root.refreshSpacePage(true)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0
                            text: "Wat er op je schijven staat en wat veilig weg kan. "
                                  + (root.spaceData.checked ? "Gemeten " + root.fmtWhen(root.spaceData.checked) + "." : "Nog niet gemeten.")
                        }

                        // Schijven: één afgeronde balk per schijf.
                        Repeater {
                            model: root.spaceData.disks || []
                            delegate: Rectangle {
                                id: diskCard
                                required property var modelData
                                readonly property real frac: Math.max(0, Math.min(1, Number(modelData.pct || 0) / 100))
                                readonly property color tone: frac >= 0.9 ? root.red : (frac >= 0.8 ? root.yellow : root.green)
                                Layout.fillWidth: true
                                implicitHeight: diskCol.implicitHeight + root.s(24)
                                radius: root.s(14)
                                color: Qt.alpha(root.text, 0.04)
                                border.width: 1
                                border.color: Qt.alpha(tone, 0.35)
                                ColumnLayout {
                                    id: diskCol
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(6)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "󰋊"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(16); color: diskCard.tone }
                                        Text { text: String(diskCard.modelData.label) + "  ·  " + String(diskCard.modelData.mount); Layout.fillWidth: true; elide: Text.ElideRight; font.family: root.uiFontFamily; font.weight: Font.DemiBold; font.pixelSize: root.s(13); color: root.text }
                                        Text { text: root.fmtBytes(diskCard.modelData.free) + " vrij van " + root.fmtBytes(diskCard.modelData.size); font.family: root.monoFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: root.s(8)
                                        radius: height / 2
                                        color: Qt.alpha(root.text, 0.08)
                                        Rectangle {
                                            width: parent.width * diskCard.frac
                                            height: parent.height
                                            radius: height / 2
                                            color: diskCard.tone
                                            Behavior on width { NumberAnimation { duration: ThemeConfig.duration(420); easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }
                        }

                        Text { text: "Kan veilig weg"; Layout.topMargin: root.s(6); font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(17); color: root.text }
                        Repeater {
                            model: (root.spaceData.cleaners || []).filter(c => Number(c.bytes) > 0)
                            delegate: Rectangle {
                                id: cleanRow
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: cleanLayout.implicitHeight + root.s(20)
                                radius: root.s(12)
                                color: Qt.alpha(root.text, 0.04)
                                RowLayout {
                                    id: cleanLayout
                                    anchors.fill: parent
                                    anchors.margins: root.s(10)
                                    spacing: root.s(12)
                                    Text { text: root.fmtBytes(cleanRow.modelData.bytes); Layout.preferredWidth: root.s(78); horizontalAlignment: Text.AlignRight; font.family: root.monoFontFamily; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.peach }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(1)
                                        Text { text: String(cleanRow.modelData.label) + (cleanRow.modelData.sudo ? "  ·  wachtwoord nodig" : ""); font.family: root.uiFontFamily; font.weight: Font.DemiBold; font.pixelSize: root.s(12); color: root.text }
                                        Text { text: String(cleanRow.modelData.detail); Layout.fillWidth: true; wrapMode: Text.WordWrap; font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0 }
                                    }
                                    SettingsActionButton {
                                        label: root.spaceCleaning === cleanRow.modelData.id ? "Bezig…" : "Opruimen"
                                        icon: "󰃢"; accent: root.peach
                                        onTriggered: if (root.spaceCleaning === "") root.spaceClean(cleanRow.modelData)
                                    }
                                }
                            }
                        }
                        Text {
                            visible: !!root.spaceData.checked && (root.spaceData.cleaners || []).filter(c => Number(c.bytes) > 0).length === 0
                            text: "Niets om op te ruimen."
                            font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0
                        }

                        Text { text: "Grootste mappen in je persoonlijke map"; Layout.topMargin: root.s(6); font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(17); color: root.text }
                        Repeater {
                            model: root.spaceData.home || []
                            delegate: Item {
                                id: homeRow
                                required property var modelData
                                readonly property real maxSize: Math.max(1, Number(((root.spaceData.home || [])[0] || {}).size || 1))
                                Layout.fillWidth: true
                                implicitHeight: root.s(30)
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    width: parent.width * Math.max(0.02, Number(homeRow.modelData.size) / homeRow.maxSize)
                                    radius: root.s(8)
                                    color: Qt.alpha(root.blue, homeMouse.containsMouse ? 0.28 : 0.16)
                                    Behavior on width { NumberAnimation { duration: ThemeConfig.duration(420); easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: root.s(10)
                                    anchors.rightMargin: root.s(10)
                                    Text { text: String(homeRow.modelData.name); Layout.fillWidth: true; elide: Text.ElideMiddle; font.family: root.uiFontFamily; font.pixelSize: root.s(12); color: root.text }
                                    Text { text: root.fmtBytes(homeRow.modelData.size); font.family: root.monoFontFamily; font.pixelSize: root.s(11); color: root.subtext0 }
                                }
                                MouseArea {
                                    id: homeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", String(homeRow.modelData.path)])
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily; font.pixelSize: root.s(10); color: root.subtext0
                            text: "Klik op een map om hem te openen. In een terminal geeft kingstra-ruimte hetzelfde overzicht."
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =================================================================
            // TAB 12: ADVANCED
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentPage === 12
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Onderhoud"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        Text { text: "Voor als de shell of de kleuren niet goed meer bijwerken."; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Shell herstarten"; icon: "󰜉"; accent: root.peach; onTriggered: root.restartQuickshell() }
                            SettingsActionButton { label: "Kleuren opnieuw maken"; icon: "󰏘"; accent: root.mauve; onTriggered: root.rerenderTheme() }
                        }

                        AdvancedSection {
                            id: uninstallAdvancedSection
                            unit: root.s(100) / 100
                            title: "Meer onderhoud"
                            icon: "󰆴"
                            hint: "Alleen de bar herladen, status verversen, Kingstra verwijderen en waar de configuratie staat"
                            SettingsInfoCard { title: "Status"; icon: "󰋼"; accent: root.blue; value: root.advancedStatusText }
                            Flow {
                                Layout.fillWidth: true
                                spacing: root.s(10)
                                SettingsActionButton { label: "Alleen de bar herladen"; icon: "󰑓"; accent: root.blue; onTriggered: root.reloadTopbar() }
                                SettingsActionButton { label: "Alle status verversen"; icon: "󰑓"; accent: root.green; onTriggered: root.refreshOperationalStatus() }
                                SettingsActionButton {
                                    label: root.showUninstallConfirm ? "Verwijderen gekozen" : "Kingstra verwijderen"
                                    icon: "󰆴"
                                    accent: root.red
                                    primary: root.showUninstallConfirm
                                    onTriggered: root.showUninstallConfirm = !root.showUninstallConfirm
                                }
                            }

                            SettingsInfoCard {
                                visible: root.showUninstallConfirm
                                title: "Verwijderen bevestigen"
                                icon: "󰅚"
                                accent: root.red
                                value: "Dit opent uninstall.sh in Kitty. Met restore zet het de gekoppelde install-backup terug; zonder restore verwijdert het alleen Kingstra-beheerde bestanden."
                            }

                            Flow {
                                visible: root.showUninstallConfirm
                                Layout.fillWidth: true
                                spacing: root.s(10)
                                SettingsActionButton { label: "Met restore"; icon: "󰁯"; accent: root.green; primary: true; onTriggered: root.runUninstallFlow(false) }
                                SettingsActionButton { label: "Zonder restore"; icon: "󰆴"; accent: root.peach; onTriggered: root.runUninstallFlow(true) }
                                SettingsActionButton { label: "Annuleren"; icon: "󰜺"; accent: root.blue; onTriggered: root.showUninstallConfirm = false }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: width >= root.s(760) ? 2 : 1
                                rowSpacing: root.s(10)
                                columnSpacing: root.s(10)
                                SettingsInfoCard { title: "Config home"; icon: "󰉋"; accent: root.sapphire; value: root.configHome() }
                                SettingsInfoCard { title: "Actief thema"; icon: "󰏘"; accent: root.mauve; value: root.activeThemeId || "onbekend" }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =================================================================
            // TAB 1: THEME (MATUGEN)
            // =================================================================
            Item {
                id: themeTab
                anchors.fill: parent
                visible: root.currentPage === 1
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(250) } }

                QtObject {
                    id: themeCarousel
                    property string selectedThemeId: ""
                    property var selectedThemeData: ({})
                    property bool isApplying: false

                    function applySelectedTheme() {
                        if (themeCarouselLoader.item && themeCarouselLoader.item.applySelectedTheme) {
                            themeCarouselLoader.item.applySelectedTheme();
                        }
                    }
                }

                ScrollView {
                    id: themeScroll
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(15)

                        Text { text: "Thema"; font.family: ThemeConfig.textFont; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }
                        Text { text: "Kies een thema en pas het toe. Lettertypes, kleuren en effecten stel je in onder Thema aanpassen."; font.family: ThemeConfig.textFont; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(12)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(92)
                                radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.ambientPurple
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: root.s(14); spacing: root.s(12)

                                    Rectangle {
                                        width: root.s(52); height: root.s(52); radius: root.s(12)
                                        color: root.surface1
                                        Text { anchors.centerIn: parent; text: root.activeThemeIcon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.s(24); color: root.ambientPurple }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: root.s(2)
                                        Text { text: "Actief thema"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(10); color: root.subtext0 }
                                        Text { text: root.activeThemeName || "Geen thema actief"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                        Text { text: root.activeThemeId || ""; font.family: ThemeConfig.textFont; font.pixelSize: root.s(10); color: root.overlay0; visible: text !== "" }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(92)
                                radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.blue
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: root.s(14); spacing: root.s(12)

                                    Rectangle {
                                        width: root.s(52); height: root.s(52); radius: root.s(12)
                                        color: root.surface1
                                        Text { anchors.centerIn: parent; text: themeCarousel.selectedThemeData.icon || "󰏘"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.s(24); color: root.blue }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: root.s(2)
                                        Text { text: "Geselecteerd"; font.family: ThemeConfig.textFont; font.pixelSize: root.s(10); color: root.subtext0 }
                                        Text { text: themeCarousel.selectedThemeData.name || "Selecteer een thema"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                        Text { text: themeCarousel.selectedThemeId || ""; font.family: ThemeConfig.textFont; font.pixelSize: root.s(10); color: root.overlay0; visible: text !== "" }
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: root.s(8)

                                Rectangle {
                                    Layout.preferredWidth: root.s(170); Layout.preferredHeight: root.s(42); radius: root.s(8)
                                    color: themeApplyMa.containsMouse ? Qt.alpha(root.green, 0.82) : root.green
                                    opacity: themeCarousel.selectedThemeId === "" || themeCarousel.isApplying ? 0.55 : 1.0
                                    scale: themeApplyMa.pressed ? 0.97 : (themeApplyMa.containsMouse ? 1.02 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(200); easing.type: Easing.OutBack } }
                                    RowLayout {
                                        anchors.centerIn: parent; spacing: root.s(6)
                                        Text { text: themeCarousel.selectedThemeId === root.activeThemeId ? "󰄬" : "󰑐"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(16); color: root.base }
                                        Text { text: themeCarousel.selectedThemeId === root.activeThemeId ? "Al actief" : "Thema toepassen"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
                                    }
                                    MouseArea {
                                        id: themeApplyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        enabled: themeCarousel.selectedThemeId !== "" && !themeCarousel.isApplying && themeCarousel.selectedThemeId !== root.activeThemeId
                                        onClicked: themeCarousel.applySelectedTheme()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: root.s(170); Layout.preferredHeight: root.s(36); radius: root.s(8)
                                    color: themeFullscreenMa.containsMouse ? Qt.alpha(root.mauve, 0.2) : Qt.alpha(root.surface1, 0.65)
                                    border.color: themeFullscreenMa.containsMouse ? root.mauve : root.surface2
                                    border.width: 1
                                    RowLayout {
                                        anchors.centerIn: parent; spacing: root.s(6)
                                        Text { text: "󰍹"; font.family: ThemeConfig.iconFont; font.pixelSize: root.s(14); color: root.text }
                                        Text { text: "Sfeer (Super+A)"; font.family: ThemeConfig.textFont; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.text }
                                    }
                                    MouseArea {
                                        id: themeFullscreenMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "bediening"])
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(290)

                            Loader {
                                id: themeCarouselLoader
                                anchors.fill: parent
                                source: Qt.resolvedUrl("../themes/ThemeCarousel.qml")

                                onLoaded: {
                                    if (item) {
                                        item.embedded = true;
                                        themeCarousel.selectedThemeId = item.selectedThemeId || "";
                                        themeCarousel.selectedThemeData = item.selectedThemeData || ({});
                                        themeCarousel.isApplying = !!item.isApplying;
                                        if (themeCarousel.selectedThemeId !== "") {
                                            root.loadThemeEditForm(themeCarousel.selectedThemeData, themeCarousel.selectedThemeId);
                                        }
                                    }
                                }
                            }

                            Connections {
                                target: themeCarouselLoader.item
                                ignoreUnknownSignals: true

                                function onThemeSelected(themeId) {
                                    themeCarousel.selectedThemeId = themeId || "";
                                    themeCarousel.selectedThemeData = themeCarouselLoader.item && themeCarouselLoader.item.selectedThemeData ? themeCarouselLoader.item.selectedThemeData : ({});
                                    if (themeCarousel.selectedThemeId !== "") {
                                        root.loadThemeEditForm(themeCarousel.selectedThemeData, themeCarousel.selectedThemeId);
                                    }
                                }

                                function onThemeApplied(themeId) {
                                    themeCarousel.selectedThemeId = themeId || themeCarousel.selectedThemeId;
                                    themeCarousel.selectedThemeData = themeCarouselLoader.item && themeCarouselLoader.item.selectedThemeData ? themeCarouselLoader.item.selectedThemeData : themeCarousel.selectedThemeData;
                                    themeCarousel.isApplying = false;
                                    if (themeCarousel.selectedThemeId !== "") {
                                        root.loadThemeEditForm(themeCarousel.selectedThemeData, themeCarousel.selectedThemeId);
                                    }
                                    root.refreshActiveTheme();
                                }
                            }

                            Timer {
                                interval: 120
                                running: true
                                repeat: true
                                onTriggered: {
                                    if (themeCarouselLoader.item) {
                                        themeCarousel.isApplying = !!themeCarouselLoader.item.isApplying;
                                        if (themeCarousel.selectedThemeId === "" && themeCarouselLoader.item.selectedThemeId) {
                                            themeCarousel.selectedThemeId = themeCarouselLoader.item.selectedThemeId;
                                            themeCarousel.selectedThemeData = themeCarouselLoader.item.selectedThemeData || ({});
                                            root.loadThemeEditForm(themeCarousel.selectedThemeData, themeCarousel.selectedThemeId);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: themeCarouselLoader.status === Loader.Error
                                anchors.fill: parent
                                radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.red
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Theme carousel kon niet geladen worden"
                                    font.family: ThemeConfig.textFont
                                    font.pixelSize: root.s(12)
                                    color: root.text
                                }
                            }
                        }

                        // Kleuren, letters en vorm staan op hun eigen pagina.
                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Kleuren en letters"; icon: "󰏘"; accent: root.mauve; primary: true; onTriggered: root.openThemeEditor("colors") }
                            SettingsActionButton { label: "Vensters"; icon: "󰖯"; accent: root.blue; onTriggered: root.openThemeEditor("windows") }
                            SettingsActionButton { label: "Strook, zijbalk en panelen"; icon: "󰕮"; accent: root.sapphire; onTriggered: root.openThemeEditor("shell") }
                        }
                    }
                }

                MouseArea {
                    id: themeWheelCatcher
                    anchors.fill: parent
                    enabled: !TouchProfile.isTouchscreen
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onWheel: (wheel) => {
                        if (root.scrollFlickableByWheel(themeScroll.contentItem, wheel)) {
                            wheel.accepted = true;
                        }
                    }
                }
            }
            } // pageArea
        }
    }
}
