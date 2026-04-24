import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

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
    Keys.onTabPressed: { currentTab = (currentTab + 1) % tabNames.length; event.accepted = true; }
    Keys.onBacktabPressed: { currentTab = (currentTab - 1 + tabNames.length) % tabNames.length; event.accepted = true; }

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
    readonly property color popupFill: Qt.rgba(root.base.r, root.base.g, root.base.b, settingsOpacity)
    readonly property color popupPanelFill: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, Math.max(0.68, Math.min(0.94, settingsOpacity * (0.52 + ThemeConfig.styleGlassStrength * 0.5))))
    readonly property color popupPanelHoverFill: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, Math.max(0.76, Math.min(0.98, settingsOpacity * (0.66 + ThemeConfig.styleGlassStrength * 0.6))))

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
    property int currentTab: 0
    property var tabNames: ["Theme", "Bar", "Widgets", "Keybinds", "Input", "Display", "Network", "Audio", "Weather & Time", "Session", "Updates", "Advanced", "About"]
    property var tabIcons: ["󰏘", "󰓡", "󰀻", "󰌌", "󰍽", "󰍹", "󰤨", "󰕾", "󰖐", "󰒲", "󰚰", "󰒓", ""]
    onCurrentTabChanged: if (currentTab === 7) refreshAudioState()

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0

    // Keybinds state
    ListModel { id: keybindsModel }
    property int editingIndex: -1
    property string keybindFilter: ""
    property string keybindWriteError: ""
    property string keybindWriteSuccessMessage: ""

    // Operational tab state
    property string displayStatusText: "Monitorstatus nog niet geladen"
    property string displayLayoutText: "Display-layout nog niet geladen"
    property string displayTouchText: "Touch-profiel nog niet geladen"
    property string displayBrightnessText: "Helderheid nog niet geladen"
    property string networkStatusText: "Netwerkstatus nog niet geladen"
    property string audioStatusText: "Audiostatus nog niet geladen"
    property bool audioStateBusy: false
    property var audioOutputs: []
    property var audioInputs: []
    property var audioApps: []
    property string sessionModeText: "office"
    property string currentPowerProfileText: "balanced"
    property string updateStatusText: "Nog niet gecontroleerd"
    property string advancedStatusText: "Klaar"
    readonly property string monitorRestoreScript: Quickshell.env("HOME") + "/.config/hypr/scripts/monitor-hotplug-restore.sh"
    readonly property string tabletModeScript: Quickshell.env("HOME") + "/.config/hypr/scripts/tablet-mode.sh"
    readonly property string displayStatusScript: Quickshell.env("HOME") + "/.config/quickshell/settings/display_status.sh"
    readonly property string idleApplyScript: Quickshell.env("HOME") + "/.config/shared/scripts/kingstra-idle-apply"

    // Catalog van bekende acties zonder vaste keybinding — worden als "Niet ingesteld" getoond
    readonly property var keybindCatalog: [
        { label: "Kleurenkiezer",    cat: "apps",  file: "81-binds-apps.conf",  d: "exec", args: "hyprpicker -r -n -f hex",              t: "bind", ln: 0, mods: "", key: "" },
        { label: "Schermopname",     cat: "apps",  file: "81-binds-apps.conf",  d: "exec", args: "wf-recorder",                          t: "bind", ln: 0, mods: "", key: "" },
        { label: "Uitlogmenu",       cat: "core",  file: "80-binds-core.conf",  d: "exec", args: "wlogout",                               t: "bind", ln: 0, mods: "", key: "" },
        { label: "Emoji-kiezer",     cat: "apps",  file: "81-binds-apps.conf",  d: "exec", args: "walker --modules emojis",               t: "bind", ln: 0, mods: "", key: "" }
    ]

    // Settings file
    property var settingsData: ({
        timeFormat: "HH:mm:ss",
        dateFormat: "dddd, MMMM dd",
        touchpadScrollFactor: 0.45,
        mouseScrollFactor: 1.35,
        touchpadRightClickButtonArea: true,
        keyboardLayout: "us",
        idleLockSeconds: 300,
        idleScreenOffSeconds: 480,
        idleSuspendSeconds: 1800,
        idleProfiles: ({
            "performance": { idleLockSeconds: 900, idleScreenOffSeconds: 1800, idleSuspendSeconds: 0 },
            "balanced": { idleLockSeconds: 300, idleScreenOffSeconds: 480, idleSuspendSeconds: 1800 },
            "power-saver": { idleLockSeconds: 180, idleScreenOffSeconds: 300, idleSuspendSeconds: 900 }
        })
    })
    property var keyboardLayoutCodes: ["us", "us,intl", "nl", "be", "gb", "de", "fr"]
    property var keyboardLayoutLabels: [
        "English (US)",
        "English (US International)",
        "Nederlands",
        "Belgisch",
        "English (UK)",
        "Deutsch",
        "Français"
    ]
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

    // Load settings via Process in plaats van FileView
    Process {
        id: loadSettingsProc
        command: ["bash", "-c", "cat ~/.config/quickshell/settings/settings.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.settingsData = {
                        timeFormat: String(parsed.timeFormat || "HH:mm:ss"),
                        dateFormat: String(parsed.dateFormat || "dddd, MMMM dd"),
                        touchpadScrollFactor: root.scrollFactorFromPercent(root.scrollPercentFromSetting(parsed.touchpadScrollFactor, 0.45), 0.45),
                        mouseScrollFactor: root.scrollFactorFromPercent(root.scrollPercentFromSetting(parsed.mouseScrollFactor, 1.35), 1.35),
                        touchpadRightClickButtonArea: parsed.touchpadRightClickButtonArea !== false,
                        keyboardLayout: root.normalizeOption(parsed.keyboardLayout, root.keyboardLayoutCodes, "us"),
                        idleLockSeconds: root.normalizeIdleSeconds(parsed.idleLockSeconds, 300),
                        idleScreenOffSeconds: root.normalizeIdleSeconds(parsed.idleScreenOffSeconds, 480),
                        idleSuspendSeconds: root.normalizeIdleSeconds(parsed.idleSuspendSeconds, 1800),
                        idleProfiles: root.normalizeIdleProfiles(parsed)
                    };
                } catch(e) {}
            }
        }
    }

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
    property bool showAllThemeVariables: false
    property bool themeSaveBusy: false
    property string themeSaveError: ""
    property string themeEditThemeId: ""
    property string themeLoadedSignature: ""
    property string themeStatusText: ""
    property string themeStatusKind: "info"
    property string themeEditorTab: "appearance"
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
    property string editStyleFamily: "botanical"
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
    property var styleFamilyOptions: ["botanical", "cyber", "rocky", "ocean", "space", "animated"]
    property var styleDensityOptions: ["compact", "comfortable", "airy"]
    property var surfaceModeOptions: ["soft-glass", "vivid-glass", "hard-surface", "mist", "solid", "cinematic-glass"]
    property var styleMotionOptions: ["gentle", "snappy", "smooth", "firm", "float", "playful"]
    property var ambientEffectOptions: ["theme-default", "none", "botanical-glow", "cyber-grid", "animated-rainbow", "ocean-wave", "space-nebula", "rocky-bevel"]
    property var drawerStyleOptions: ["none", "context-card", "rail-panel"]
    property var moduleDensityOptions: ["minimal", "balanced", "rich"]
    property var workspacePreviewOptions: ["numbers", "app-icons", "hybrid"]
    property var railAccentOptions: ["none", "edge-line", "pulse-line", "segmented"]
    property var themeEditorTabs: [
        { id: "appearance", label: "Uiterlijk", icon: "󰉼" },
        { id: "fonts", label: "Fonts", icon: "󰛖" },
        { id: "colors", label: "Kleuren", icon: "󰏘" },
        { id: "bar", label: "Bar", icon: "󰓡" },
        { id: "character", label: "Karakter", icon: "󱥰" },
        { id: "effects", label: "Effecten", icon: "󰟤" }
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

    function keyboardLayoutIndex(value) {
        let normalized = normalizeOption(value, keyboardLayoutCodes, "us");
        let index = keyboardLayoutCodes.indexOf(normalized);
        return index >= 0 ? index : 0;
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
            "    after_sleep_cmd  = hyprctl dispatch dpms on",
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
                "    on-resume  = hyprctl dispatch dpms on",
                "}",
                ""
            );
        }

        if (safeScreenOff > 0) {
            blocks.push(
                "# Scherm uitschakelen via DPMS",
                "listener {",
                "    timeout   = " + safeScreenOff,
                "    on-timeout = hyprctl dispatch dpms off",
                "    on-resume  = hyprctl dispatch dpms on",
                "}",
                ""
            );
        }

        if (safeSuspend > 0) {
            blocks.push(
                "# Suspend / slaapstand",
                "listener {",
                "    timeout   = " + safeSuspend,
                "    on-timeout = systemctl suspend",
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
        if (safeThemeId === "rocky" || safeThemeId === "cyber") return false;
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

        editStyleFamily = normalizeOption(themeValue(themeData, "style_profile", "family", safeThemeId), styleFamilyOptions, "botanical");
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
            "style_profile.family", normalizeOption(editStyleFamily, styleFamilyOptions, "botanical"),
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
    }

    function openShellWidget(name, subtarget) {
        let args = ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", name];
        if (subtarget && String(subtarget) !== "") args.push(String(subtarget));
        Quickshell.execDetached(args);
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

    function setDefaultAudioDevice(type, name) {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/volume/audio_control.sh", "set-default", type, String(name)]);
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
        Quickshell.execDetached(["kitty", "--hold", "bash", Quickshell.env("HOME") + "/.config/quickshell/package_upgrade.sh"]);
        notify("Updates", "Package update gestart in terminal");
    }

    function restartQuickshell() {
        advancedStatusText = "Quickshell herstart aangevraagd";
        Quickshell.execDetached(["bash", "-lc", "pkill -f 'quickshell.*TopBar.qml' >/dev/null 2>&1 || true; pkill -f 'quickshell.*Main.qml' >/dev/null 2>&1 || true; sleep 0.3; quickshell -p '$HOME/.config/quickshell/TopBar.qml' >/dev/null 2>&1 & quickshell -p '$HOME/.config/quickshell/Main.qml' >/dev/null 2>&1 &"]);
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
            font.family: "Iosevka Nerd Font"
            font.pixelSize: root.s(13)
            color: combo.hovered || combo.visualFocus ? root.blue : root.subtext0
        }

        background: Rectangle {
            radius: root.s(8)
            color: Qt.alpha(root.surface0, 0.78)
            border.width: 1
            border.color: combo.visualFocus ? root.blue : (combo.hovered ? Qt.alpha(root.surface2, 0.95) : Qt.alpha(root.surface2, 0.78))
            Behavior on border.color { ColorAnimation { duration: 120 } }
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
        function stepUp() {
            spin.value = Math.min(spin.to, spin.value + spin.stepSize)
        }
        function stepDown() {
            spin.value = Math.max(spin.from, spin.value - spin.stepSize)
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
            onTextEdited: spin.value = spin.valueFromText(text, spin.locale)
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
                font.family: "JetBrains Mono"
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
                font.family: "JetBrains Mono"
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
            Behavior on border.color { ColorAnimation { duration: 120 } }
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

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }

        RowLayout {
            anchors.centerIn: parent
            spacing: root.s(7)
            Text {
                text: actionButton.icon
                font.family: "Iosevka Nerd Font"
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
                Text { text: infoCard.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(17); color: infoCard.accent }
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

                Text { text: volumeCard.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: volumeCard.accent }

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
        // Laad settings via Process
        loadSettingsProc.running = true;
        // Laad keybinds via Process
        loadKeybindsProc.running = true;
        // Load weather .env values
        loadEnvProc.running = true;
        // Load active theme info
        refreshActiveTheme();
        refreshOperationalStatus();
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
        running: root.currentTab === 7
        onTriggered: root.refreshAudioState()
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
                root.updateStatusText = count === "" ? "Updatecheck niet beschikbaar" : (count + " package updates beschikbaar");
            }
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
        PauseAnimation { duration: 50 }
        NumberAnimation { target: root; property: "introBase"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        NumberAnimation { target: root; property: "introSidebar"; to: 1.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        NumberAnimation { target: root; property: "introContent"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { target: root; property: "introContent"; to: 0.0; duration: 150; easing.type: Easing.InExpo }
            NumberAnimation { target: root; property: "introSidebar"; to: 0.0; duration: 150; easing.type: Easing.InExpo }
        }
        NumberAnimation { target: root; property: "introBase"; to: 0.0; duration: 200; easing.type: Easing.InQuart }
        ScriptAction { script: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]) }
    }

    // -------------------------------------------------------------------------
    // HELPER: save settings.json
    // -------------------------------------------------------------------------
    function saveSettings(timeFormat, dateFormat, touchpadScrollPercent, mouseScrollPercent, touchpadRightClickButtonArea, keyboardLayout, idleLockSeconds, idleScreenOffSeconds, idleSuspendSeconds, idleProfiles) {
        var configRoot = configHome();
        var settingsDir = configRoot + "/quickshell/settings";
        var path = settingsDir + "/settings.json";
        var scrollPath = configRoot + "/hypr/conf.d/73-scroll-settings.conf";
        var inputPath = configRoot + "/hypr/conf.d/74-input-settings.conf";
        var touchpadFactor = scrollFactorFromPercent(touchpadScrollPercent, 0.45);
        var mouseFactor = scrollFactorFromPercent(mouseScrollPercent, 1.35);
        var safeKeyboardLayout = normalizeOption(keyboardLayout, keyboardLayoutCodes, "us");
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
            idleLockSeconds: safeIdleLockSeconds,
            idleScreenOffSeconds: safeIdleScreenOffSeconds,
            idleSuspendSeconds: safeIdleSuspendSeconds,
            idleProfiles: safeIdleProfiles
        };
        var json = JSON.stringify(payload, null, 4);
        var scrollConf =
            "# =============================================================================\n" +
            "# 73-scroll-settings.conf — Scroll-tuning overrides\n" +
            "# =============================================================================\n" +
            "# Aangepast via de Settings-popup.\n" +
            "# =============================================================================\n\n" +
            "input {\n" +
            "    scroll_factor = " + mouseFactor.toFixed(2) + "\n\n" +
            "    touchpad {\n" +
            "        scroll_factor = " + touchpadFactor.toFixed(2) + "\n" +
            "    }\n" +
            "}\n";
        var inputConf =
            "# =============================================================================\n" +
            "# 74-input-settings.conf — Input overrides\n" +
            "# =============================================================================\n" +
            "# Aangepast via de Settings-popup.\n" +
            "# =============================================================================\n\n" +
            "input {\n" +
            "    kb_layout = " + safeKeyboardLayout + "\n" +
            "    kb_options =\n\n" +
            "    touchpad {\n" +
            "        # false = button areas (Windows-achtig), true = clickfinger gedrag\n" +
            "        clickfinger_behavior = " + (useButtonArea ? "false" : "true") + "\n" +
            "    }\n" +
            "}\n";
        var cmd = [
            "mkdir -p '" + shellSingleQuote(settingsDir) + "'",
            "mkdir -p '" + shellSingleQuote(configRoot + "/hypr/conf.d") + "'",
            "printf '%s' '" + shellSingleQuote(json) + "' > '" + shellSingleQuote(path) + "'",
            "printf '%s' '" + shellSingleQuote(scrollConf) + "' > '" + shellSingleQuote(scrollPath) + "'",
            "printf '%s' '" + shellSingleQuote(inputConf) + "' > '" + shellSingleQuote(inputPath) + "'",
            "hyprctl keyword input:scroll_factor '" + mouseFactor.toFixed(2) + "' >/dev/null 2>&1 || true",
            "hyprctl keyword input:touchpad:scroll_factor '" + touchpadFactor.toFixed(2) + "' >/dev/null 2>&1 || true",
            "hyprctl keyword input:touchpad:clickfinger_behavior '" + (useButtonArea ? "false" : "true") + "' >/dev/null 2>&1 || true",
            "hyprctl keyword input:kb_layout '" + shellSingleQuote(safeKeyboardLayout) + "' >/dev/null 2>&1 || true",
            "hyprctl keyword input:kb_options '' >/dev/null 2>&1 || true",
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

        var line = (item.t || "bind") + " = " + cleanedMods + ", " + cleanedKey + ", " + item.d;
        if (item.args) line += ", " + item.args;
        if (item.label) line += "   # " + item.label;
        var script = Quickshell.env("HOME") + "/.config/quickshell/settings/write_keybind.sh";
        root.keybindWriteError = "";
        if (item.bound && Number(item.ln) > 0) {
            keybindWriteProc.command = ["bash", script, "--update", item.file, item.ln.toString(), line];
            root.keybindWriteSuccessMessage = "Keybinding bijgewerkt";
        } else {
            keybindWriteProc.command = ["bash", script, "--add", item.file, line];
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
        keybindWriteProc.command = ["bash", script, "--remove", item.file, item.ln.toString()];
        keybindWriteProc.running = true;
    }

    function notify(title, msg) {
        Quickshell.execDetached(["notify-send", title, msg]);
    }

    function runUpdateBootstrap() {
        var bootstrapUrl = "https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh";
        var command = "bash <(curl -fsSL " + bootstrapUrl + ")";
        Quickshell.execDetached(["kitty", "--hold", "bash", "-lc", command]);
        notify("Settings", "Update gestart in terminal");
        // Sluit meteen zonder close-animatie.
        introContent = 0.0;
        introSidebar = 0.0;
        introBase = 0.0;
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
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
            color: root.popupFill; border.color: root.surface0; border.width: Math.max(1, ThemeConfig.borderWidth)
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
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.base }
                        }
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter; spacing: root.s(2)
                            Text { text: "Settings"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(15); color: root.text }
                            Text { text: "kingstra-dots"; font.family: root.uiFontFamily; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(11); color: root.subtext0 }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.surface1, 0.5); Layout.bottomMargin: root.s(10) }

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

                        // Tab buttons
                        Repeater {
                            model: root.tabNames.length
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(44); radius: root.s(8)
                                property bool isActive: root.currentTab === index
                                color: isActive ? root.popupPanelHoverFill : (tabMa.containsMouse ? root.popupPanelFill : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: root.s(15); spacing: root.s(12)
                                    Item {
                                        Layout.preferredWidth: root.s(24); Layout.alignment: Qt.AlignVCenter
                                        Text { anchors.centerIn: parent; text: root.tabIcons[index]; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: parent.parent.parent.isActive ? root.ambientPurple : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                                    }
                                    Text { text: root.tabNames[index]; font.family: root.uiFontFamily; font.weight: parent.parent.isActive ? root.themedFontWeight : Font.Medium; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(13); color: parent.parent.isActive ? root.text : root.subtext0; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; Behavior on color { ColorAnimation { duration: 150 } } }
                                }

                                Rectangle {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    width: root.s(3); height: parent.isActive ? root.s(20) : 0; radius: root.s(2)
                                    color: root.ambientPurple
                                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                }

                                MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = index }
                            }
                        }
                    }
                }

                // Close button
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: root.s(44); radius: root.s(8)
                    color: closeHover.containsMouse ? Qt.alpha(root.red, 0.1) : "transparent"
                    border.color: closeHover.containsMouse ? root.red : root.surface1; border.width: 1
                    scale: closeHover.pressed ? 0.95 : (closeHover.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(8)

                        Text {
                            text: "󰅖"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(16)
                            color: closeHover.containsMouse ? root.red : root.subtext0
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text: "Sluiten"
                            font.family: root.uiFontFamily
                            font.weight: Font.Medium
                            font.letterSpacing: root.themedLetterSpacing
                            font.pixelSize: root.s(12)
                            color: closeHover.containsMouse ? root.red : root.subtext0
                            Behavior on color { ColorAnimation { duration: 150 } }
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

            // =================================================================
            // TAB 12: ABOUT
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 12
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ListModel {
                    id: systemModel
                    ListElement { pkg: "Hyprland";    role: "Wayland Compositor";     icon: "";  clr: "blue";   link: "https://hyprland.org/" }
                    ListElement { pkg: "Quickshell";  role: "Desktop Shell (QML)";    icon: "󰣆"; clr: "mauve";  link: "https://git.outfoxxed.me/outfoxxed/quickshell" }
                    ListElement { pkg: "Walker";      role: "App Launcher";           icon: "";  clr: "green";  link: "https://github.com/abenz1267/walker" }
                    ListElement { pkg: "Kitty";       role: "Terminal Emulator";       icon: "󰄛"; clr: "yellow"; link: "https://sw.kovidgoyal.net/kitty/" }
                    ListElement { pkg: "SwayNC";      role: "Notification Center";     icon: "󰂚"; clr: "pink";   link: "https://github.com/ErikReider/SwayNotificationCenter" }
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
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(15)
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: root.s(48); height: root.s(48); radius: root.s(10)
                                color: root.surface0; border.color: root.surface2; border.width: 1
                                Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(28); color: root.text }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter; spacing: root.s(2)
                                Text { text: "Created by"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; font.weight: Font.Medium }
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
                                            text: modelData.l; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(22); color: modelData.c
                                            property real hoverOffset: authorMa.containsMouse ? root.s(-4) : 0
                                            transform: Translate { y: hoverOffset }
                                            Behavior on hoverOffset { NumberAnimation { duration: 300 + (index * 25); easing.type: Easing.OutBack } }
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: root.s(32); height: root.s(32); radius: root.s(8)
                                color: authorMa.containsMouse ? root.surface1 : "transparent"
                                Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: authorMa.containsMouse ? root.mauve : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                            }
                        }
                        MouseArea { id: authorMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/JorisKooistra/kingstra-dots"]) }
                    }

                    Text { text: "System Components"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text; Layout.topMargin: root.s(5) }

                    GridLayout {
                        Layout.fillWidth: true; columns: 2; rowSpacing: root.s(15); columnSpacing: root.s(15)
                        Repeater {
                            model: systemModel
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(70); radius: root.s(10)
                                color: sysCardMa.containsMouse ? Qt.alpha(root[model.clr], 0.14) : root.popupPanelFill
                                border.color: sysCardMa.containsMouse ? root[model.clr] : root.surface1; border.width: 1
                                scale: sysCardMa.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Item {
                                    anchors.fill: parent; anchors.margins: root.s(15)
                                    Item {
                                        id: sysIconBox; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        width: root.s(40); height: root.s(40)
                                        Text { anchors.centerIn: parent; text: model.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(24); color: root[model.clr] }
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

                    Rectangle {
                        Layout.alignment: Qt.AlignLeft
                        Layout.preferredWidth: root.s(220)
                        Layout.preferredHeight: root.s(48)
                        radius: root.themedInnerRadius
                        color: updateMa.containsMouse ? Qt.alpha(root.green, 0.14) : root.popupPanelFill
                        border.color: updateMa.containsMouse ? root.green : root.surface1
                        border.width: 1
                        scale: updateMa.pressed ? 0.98 : (updateMa.containsMouse ? 1.01 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: root.s(12)
                            spacing: root.s(10)

                            Text {
                                text: "󰚰"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(18)
                                color: updateMa.containsMouse ? root.green : root.subtext0
                            }
                            Text {
                                text: "Update uitvoeren"
                                font.family: root.uiFontFamily
                                font.weight: root.themedFontWeight
                                font.letterSpacing: root.themedLetterSpacing
                                font.pixelSize: root.s(12)
                                color: root.text
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: updateMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runUpdateBootstrap()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 3: KEYBINDINGS
            // =================================================================
            Item {
                id: keybindTab
                anchors.fill: parent
                visible: root.currentTab === 3
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(15)

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Keybindings"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text; Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: root.s(36); Layout.preferredHeight: root.s(36); radius: root.s(8)
                            color: reloadMa.containsMouse ? root.surface1 : Qt.alpha(root.surface0, 0.6)
                            border.color: reloadMa.containsMouse ? root.blue : root.surface1; border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "󰑓"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: reloadMa.containsMouse ? root.blue : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                            MouseArea { id: reloadMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { keybindsModel.clear(); loadKeybindsProc.running = true; } }
                        }
                    }

                    // Search bar
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(40); radius: root.s(8)
                        color: root.surface0; border.color: filterInput.activeFocus ? root.blue : root.surface2; border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(8); spacing: root.s(8)
                            Text { text: "󰍉"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.subtext0 }
                            TextInput {
                                id: filterInput; Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                clip: true; selectByMouse: true
                                onTextChanged: root.keybindFilter = text.toLowerCase()
                                Text { text: "Filter keybindings..."; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
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
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

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
                                                    Text { id: unboundTxt; anchors.centerIn: parent; text: "Niet ingesteld"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.overlay0 }
                                                }

                                                // Bound
                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter; spacing: root.s(6)
                                                    visible: model.bound
                                                    Rectangle {
                                                        width: k1t.implicitWidth + root.s(14); height: root.s(26); radius: root.s(4)
                                                        color: root.surface0; border.color: root.surface2; border.width: 1
                                                        Text { id: k1t; anchors.centerIn: parent; text: model.mods; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.peach }
                                                    }
                                                    Text { text: "+"; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.overlay0; anchors.verticalCenter: parent.verticalCenter; visible: model.key !== "" }
                                                    Rectangle {
                                                        visible: model.key !== ""
                                                        width: k2t.implicitWidth + root.s(14); height: root.s(26); radius: root.s(4)
                                                        color: root.surface0; border.color: root.surface2; border.width: 1
                                                        Text { id: k2t; anchors.centerIn: parent; text: model.key; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.peach }
                                                    }
                                                }
                                            }

                                            // Action label
                                            Text {
                                                text: model.label || (model.d + (model.args ? " " + model.args : ""))
                                                font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
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
                                                    Text { anchors.centerIn: parent; text: "Bewerk"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: editBtnMa.containsMouse ? root.blue : root.subtext0 }
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
                                                    Text { anchors.centerIn: parent; text: "Verwijder"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: deleteBtnMa.containsMouse ? root.red : root.subtext0 }
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

                                            Text { text: "Mods:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.subtext0 }
                                            Rectangle {
                                                Layout.preferredWidth: root.s(200); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: root.surface0; border.color: modsEdit.activeFocus ? root.blue : root.surface2; border.width: 1
                                                TextInput {
                                                    id: modsEdit; anchors.fill: parent; anchors.margins: root.s(6)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.text
                                                    text: bindRow.editMods; selectByMouse: true; clip: true
                                                    onTextChanged: bindRow.editMods = text
                                                }
                                            }

                                            Text { text: "Key:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.subtext0 }
                                            Rectangle {
                                                Layout.preferredWidth: root.s(120); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: root.surface0; border.color: keyEdit.activeFocus ? root.blue : root.surface2; border.width: 1
                                                TextInput {
                                                    id: keyEdit; anchors.fill: parent; anchors.margins: root.s(6)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.text
                                                    text: bindRow.editKey; selectByMouse: true; clip: true
                                                    onTextChanged: bindRow.editKey = text
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Save button
                                            Rectangle {
                                                Layout.preferredWidth: root.s(70); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: saveBMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                                Text { anchors.centerIn: parent; text: "Opslaan"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.base }
                                                MouseArea { id: saveBMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveKeybind(index, bindRow.editMods, bindRow.editKey) }
                                            }
                                            // Remove button (alleen bij bestaande bind)
                                            Rectangle {
                                                Layout.preferredWidth: root.s(30); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                visible: model.bound
                                                color: removeBMa.containsMouse ? Qt.alpha(root.red, 0.15) : "transparent"
                                                border.color: removeBMa.containsMouse ? root.red : root.surface1; border.width: 1
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                                Text { anchors.centerIn: parent; text: "󰆴"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: removeBMa.containsMouse ? root.red : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                                                MouseArea { id: removeBMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeKeybind(index) }
                                            }
                                            // Cancel button
                                            Rectangle {
                                                Layout.preferredWidth: root.s(70); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: cancelMa.containsMouse ? Qt.alpha(root.red, 0.15) : "transparent"
                                                border.color: root.surface1; border.width: 1
                                                Text { anchors.centerIn: parent; text: "Annuleer"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
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
            // TAB 8: WEATHER & TIME
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 8
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(15)

                    Text { text: "Weather & Time"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }

                    // ---- DATE & TIME FORMAT ----
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(180); radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.4); border.color: root.surface1; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(12)

                            RowLayout {
                                spacing: root.s(8)
                                Text { text: "󰥔"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.blue }
                                Text { text: "Date & Time Format"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                            }

                            Text { text: "Qt format strings — e.g. HH:mm (24h), hh:mm AP (12h), dddd d MMMM (Monday 7 April)"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                            RowLayout {
                                Layout.fillWidth: true; spacing: root.s(15)

                                // Time format
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: root.s(4)
                                    Text { text: "Time format"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: root.s(38); radius: root.s(6)
                                        color: root.surface0; border.color: timeFmtInput.activeFocus ? root.blue : root.surface2; border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        TextInput {
                                            id: timeFmtInput; anchors.fill: parent; anchors.margins: root.s(8)
                                            verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                            text: root.settingsData.timeFormat || "HH:mm:ss"; selectByMouse: true; clip: true
                                        }
                                    }
                                }

                                // Date format
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: root.s(4)
                                    Text { text: "Date format"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: root.s(38); radius: root.s(6)
                                        color: root.surface0; border.color: dateFmtInput.activeFocus ? root.blue : root.surface2; border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        TextInput {
                                            id: dateFmtInput; anchors.fill: parent; anchors.margins: root.s(8)
                                            verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                            text: root.settingsData.dateFormat || "dddd, MMMM dd"; selectByMouse: true; clip: true
                                        }
                                    }
                                }
                            }

                            // Preview
                            RowLayout {
                                Layout.fillWidth: true; spacing: root.s(10)
                                Text { text: "Preview:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                Text {
                                    property string preview: Qt.formatDateTime(new Date(), timeFmtInput.text) + "  ·  " + Qt.formatDateTime(new Date(), dateFmtInput.text)
                                    text: preview; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.peach
                                    Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.preview = Qt.formatDateTime(new Date(), timeFmtInput.text) + "  ·  " + Qt.formatDateTime(new Date(), dateFmtInput.text) }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(30); radius: root.s(6)
                                    color: dtSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                    scale: dtSaveMa.pressed ? 0.95 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "Save"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
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
                                            root.keyboardLayoutCodes[keyboardLayoutCombo.currentIndex]
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // ---- SEPARATOR ----
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                    // ---- WEATHER API CONFIG ----
                    RowLayout {
                        spacing: root.s(8)
                        Text { text: "󰖐"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.yellow }
                        Text { text: "Weather API"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                    }

                    Text { text: "Enter your OpenWeatherMap API key and coordinates."; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                    // API Key
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                        color: root.surface0; border.color: apiKeyInput.activeFocus ? root.blue : root.surface2; border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                            Text { text: "󰌆"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: root.subtext0 }
                            TextInput {
                                id: apiKeyInput; Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                clip: true; selectByMouse: true; echoMode: TextInput.Password
                                Text { text: "OpenWeather API Key..."; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Coordinates
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(15)
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                            color: root.surface0; border.color: latInput.activeFocus ? root.peach : root.surface2; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            TextInput {
                                id: latInput; anchors.fill: parent; anchors.margins: root.s(10)
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text; clip: true; selectByMouse: true
                                Text { text: "Latitude (e.g. 52.3676)"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                            color: root.surface0; border.color: lonInput.activeFocus ? root.peach : root.surface2; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            TextInput {
                                id: lonInput; anchors.fill: parent; anchors.margins: root.s(10)
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text; clip: true; selectByMouse: true
                                Text { text: "Longitude (e.g. 4.9041)"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Units
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(15)
                        Text { text: "Units:"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                        Repeater {
                            model: ["metric", "imperial", "standard"]
                            Rectangle {
                                Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(32); radius: root.s(6)
                                color: root.selectedUnit === modelData ? Qt.alpha(root.mauve, 0.2) : "transparent"
                                border.color: root.selectedUnit === modelData ? root.mauve : root.surface1; border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: modelData; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.capitalization: Font.Capitalize; color: root.selectedUnit === modelData ? root.mauve : root.subtext0 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedUnit = modelData }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Save weather button
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: root.s(160); Layout.preferredHeight: root.s(42); radius: root.s(8)
                            color: wSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                            scale: wSaveMa.pressed ? 0.95 : (wSaveMa.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                            RowLayout {
                                anchors.centerIn: parent; spacing: root.s(8)
                                Text { text: "󰆓"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: root.base }
                                Text { text: "Save Weather"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(14); color: root.base }
                            }
                            MouseArea { id: wSaveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveWeatherConfig() }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 4: INPUT
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 4
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(15)

                    Text { text: "Input"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(340); radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.4); border.color: root.surface1; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(12)

                            RowLayout {
                                spacing: root.s(8)
                                Text { text: "󰍽"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.peach }
                                Text { text: "Scroll Tuning"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                            }

                            Text {
                                text: "Touchpad scrolls a bit calmer by default, while the mouse gets a stronger wheel response. Values are percentages of Hyprland's default speed."
                                font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0
                                wrapMode: Text.WordWrap; Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: root.s(15)

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: root.s(6)
                                    Text { text: "Touchpad"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    ThemedSpinBox {
                                        id: touchpadScrollSpin
                                        from: 20; to: 300; stepSize: 5
                                        value: root.scrollPercentFromSetting(root.settingsData.touchpadScrollFactor, 0.45)
                                    }
                                    Text {
                                        text: touchpadScrollSpin.value + "%  (" + root.scrollFactorFromPercent(touchpadScrollSpin.value, 0.45).toFixed(2) + "x)"
                                        font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.peach
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: root.s(6)
                                    Text { text: "Mouse"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    ThemedSpinBox {
                                        id: mouseScrollSpin
                                        from: 20; to: 300; stepSize: 5
                                        value: root.scrollPercentFromSetting(root.settingsData.mouseScrollFactor, 1.35)
                                    }
                                    Text {
                                        text: mouseScrollSpin.value + "%  (" + root.scrollFactorFromPercent(mouseScrollSpin.value, 1.35).toFixed(2) + "x)"
                                        font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.blue
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
                                    Text { text: "Keyboard layout"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    ThemedComboBox {
                                        id: keyboardLayoutCombo
                                        model: root.keyboardLayoutLabels
                                        currentIndex: root.keyboardLayoutIndex(root.settingsData.keyboardLayout)
                                    }
                                    Text {
                                        text: "Chooses the active Hyprland keyboard language/layout."
                                        font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.blue
                                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: root.s(6)
                                    Text { text: "Touchpad right click"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    ThemedComboBox {
                                        id: touchpadRightClickCombo
                                        model: ["On", "Off"]
                                        currentIndex: root.settingsData.touchpadRightClickButtonArea ? 0 : 1
                                    }
                                    Text {
                                        text: touchpadRightClickCombo.currentIndex === 0
                                            ? "On uses a Windows-style right button area on the touchpad."
                                            : "Off switches to clickfinger behavior instead of a dedicated right-click zone."
                                        font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.peach
                                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: root.s(10)
                                Text { text: "Saved instantly and applied live in Hyprland."; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(30); radius: root.s(6)
                                    color: scrollSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                    scale: scrollSaveMa.pressed ? 0.95 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "Save"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
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
                                            root.keyboardLayoutCodes[keyboardLayoutCombo.currentIndex]
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 1: BAR
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 1
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Bar"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        Text { text: "Bar-instellingen worden opgeslagen in het geselecteerde theme en kunnen daarna live worden toegepast op de topbar."; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        SettingsInfoCard {
                            title: "Huidige context"
                            icon: "󰏘"
                            accent: root.mauve
                            value: "Actief: " + (root.activeThemeId || "onbekend") + "\nBewerken: " + (root.themeEditThemeId || "geen theme geladen")
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width >= root.s(820) ? 2 : 1
                            rowSpacing: root.s(10)
                            columnSpacing: root.s(10)

                            SettingsInfoCard {
                                title: "Positie en vorm"
                                icon: "󰓡"
                                accent: root.blue
                                value: "Kies waar de bar staat. Links/rechts schakelt automatisch naar een sidebar-template."
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: barPositionEditor.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.46)
                                border.color: Qt.alpha(root.surface2, 0.82)
                                border.width: 1

                                ColumnLayout {
                                    id: barPositionEditor
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(9)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Positie"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedComboBox { model: root.barPositionOptions; currentIndex: Math.max(0, model.indexOf(root.editBarPosition)); onActivated: root.setEditBarPosition(currentText) }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Hoogte"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedSpinBox { from: 30; to: 72; value: root.editBarHeight; onValueChanged: root.editBarHeight = value }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Breedte"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedComboBox { model: root.barWidthModeOptions; currentIndex: Math.max(0, model.indexOf(root.editBarWidthMode)); onActivated: root.editBarWidthMode = currentText }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Vorm"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedComboBox { model: root.barShapeOptions; currentIndex: Math.max(0, model.indexOf(root.editBarShape)); onActivated: root.editBarShape = currentText }
                                    }
                                }
                            }

                            SettingsInfoCard {
                                title: "Details"
                                icon: "󰥔"
                                accent: root.peach
                                value: "Clock style, randen en topbar-blokken bewegen mee met theme-switches."
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: barDetailEditor.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.46)
                                border.color: Qt.alpha(root.surface2, 0.82)
                                border.width: 1

                                ColumnLayout {
                                    id: barDetailEditor
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(9)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Klok"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedComboBox { model: root.clockStyleOptions; currentIndex: Math.max(0, model.indexOf(root.editClockStyle)); onActivated: root.editClockStyle = currentText }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Bovenrand"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedComboBox { model: root.barEdgeStyleOptions; currentIndex: Math.max(0, model.indexOf(root.editBarTopEdgeStyle)); onActivated: root.editBarTopEdgeStyle = currentText }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Onderrand"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedComboBox { model: root.barEdgeStyleOptions; currentIndex: Math.max(0, model.indexOf(root.editBarBottomEdgeStyle)); onActivated: root.editBarBottomEdgeStyle = currentText }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Topbar stijl"; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.preferredWidth: root.s(110) }
                                        ThemedComboBox {
                                            model: ["losse blokken", "strakke lijn"]
                                            currentIndex: root.editTopbarLooseBlocks ? 0 : 1
                                            enabled: root.editBarPosition === "top"
                                            onActivated: root.editTopbarLooseBlocks = (currentIndex === 0)
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: root.themeDirty ? "Opslaan" : "Geen wijzigingen"; icon: root.themeDirty ? "󰆓" : "󰄬"; accent: root.green; primary: root.themeDirty; onTriggered: root.saveThemeEdits() }
                            SettingsActionButton { label: "Topbar toepassen"; icon: "󰑓"; accent: root.blue; onTriggered: root.applyTopbarEdits() }
                            SettingsActionButton { label: "Open Theme-editor"; icon: "󰏘"; accent: root.mauve; onTriggered: { root.themeEditorTab = "bar"; root.currentTab = 0; } }
                            Item { Layout.fillWidth: true }
                        }

                        SettingsInfoCard {
                            title: "Status"
                            icon: root.themeDirty ? "󰐖" : "󰋼"
                            accent: root.themeDirty ? root.yellow : root.green
                            value: root.themeDirty ? ("Onopgeslagen wijzigingen in " + root.themeEditThemeId + ".toml") : (root.themeStatusText || "Klaar")
                        }
                    }
                }
            }

            // =================================================================
            // TAB 2: WIDGETS
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 2
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    spacing: root.s(14)

                    Text { text: "Widgets"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                    Text { text: "Voor nu is dit een werkende widget-hub: je opent bestaande popups vanuit dezelfde settings-shell. Module toggles volgen zodra de bar die config daadwerkelijk leest."; font.family: root.uiFontFamily; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= root.s(760) ? 2 : 1
                        rowSpacing: root.s(10)
                        columnSpacing: root.s(10)

                        SettingsInfoCard { title: "Systeemwidgets"; icon: "󰀻"; accent: root.blue; value: "Netwerk, volume, notificaties en monitoren openen via de bestaande qs_manager-routes." }
                        SettingsInfoCard { title: "Mode-aware modules"; icon: "󰒲"; accent: root.mauve; value: "Office, gaming en media kiezen nu al andere modulelijsten in BarShell.qml." }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: root.s(10)

                        SettingsActionButton { label: "Netwerk"; icon: "󰤨"; accent: root.blue; onTriggered: root.openShellWidget("network", "wifi") }
                        SettingsActionButton { label: "Bluetooth"; icon: "󰂯"; accent: root.sapphire; onTriggered: root.openShellWidget("network", "bt") }
                        SettingsActionButton { label: "Volume"; icon: "󰕾"; accent: root.green; onTriggered: root.openShellWidget("volume", "") }
                        SettingsActionButton { label: "Monitoren"; icon: "󰍹"; accent: root.peach; onTriggered: root.openShellWidget("monitors", "") }
                        SettingsActionButton { label: "Notificaties"; icon: "󰂚"; accent: root.pink; onTriggered: root.openShellWidget("notifications", "") }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 5: DISPLAY
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 5
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    spacing: root.s(14)

                    Text { text: "Display"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                    SettingsInfoCard { title: "Monitorstatus"; icon: "󰍹"; accent: root.blue; value: root.displayStatusText }
                    SettingsInfoCard { title: "Actieve layout"; icon: "󰹑"; accent: root.mauve; value: root.displayLayoutText }
                    SettingsInfoCard { title: "Touch & tablet"; icon: "󰗧"; accent: root.sapphire; value: root.displayTouchText }
                    SettingsInfoCard { title: "Helderheid"; icon: "󰃠"; accent: root.yellow; value: root.displayBrightnessText }

                    Flow {
                        Layout.fillWidth: true
                        spacing: root.s(10)
                        SettingsActionButton { label: "Monitor UI openen"; icon: "󰍹"; accent: root.blue; primary: true; onTriggered: root.openShellWidget("monitors", "") }
                        SettingsActionButton { label: "Layout herstellen"; icon: "󰁯"; accent: root.green; onTriggered: root.restoreDisplayLayout() }
                        SettingsActionButton { label: "Tabletmodus"; icon: "󰓶"; accent: root.peach; onTriggered: root.toggleTabletMode() }
                        SettingsActionButton { label: "Helderheid -"; icon: "󰃞"; accent: root.yellow; onTriggered: root.adjustBrightness(-5) }
                        SettingsActionButton { label: "Helderheid +"; icon: "󰃠"; accent: root.yellow; onTriggered: root.adjustBrightness(5) }
                        SettingsActionButton { label: "Status verversen"; icon: "󰑓"; accent: root.green; onTriggered: root.refreshDisplayStatus() }
                    }

                    SettingsInfoCard { title: "Opslaan"; icon: "󰆓"; accent: root.peach; value: "De monitor UI bewaart layouts in 10-monitors.conf; 'Layout herstellen' hergebruikt hetzelfde hotplug-herstelpad als de sessie zelf." }
                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 6: NETWORK
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 6
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    spacing: root.s(14)

                    Text { text: "Network"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                    SettingsInfoCard { title: "Wifi"; icon: "󰤨"; accent: root.blue; value: root.networkStatusText }

                    Flow {
                        Layout.fillWidth: true
                        spacing: root.s(10)
                        SettingsActionButton { label: "Wifi-paneel"; icon: "󰤨"; accent: root.blue; primary: true; onTriggered: root.openShellWidget("network", "wifi") }
                        SettingsActionButton { label: "Bluetooth-paneel"; icon: "󰂯"; accent: root.sapphire; onTriggered: root.openShellWidget("network", "bt") }
                        SettingsActionButton { label: "Status verversen"; icon: "󰑓"; accent: root.green; onTriggered: networkStatusProc.running = true }
                    }

                    SettingsInfoCard { title: "Veiligheid"; icon: "󰌾"; accent: root.yellow; value: "Wifi-wachtwoorden blijven in de bestaande network popup; deze tab toont alleen status en opent de juiste workflow." }
                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 7: AUDIO
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 7
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Audio"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                        Text {
                            text: "Snelle mixer voor output, input en actieve streams. De losse VolumePopup blijft beschikbaar voor de volledige audioweergave."
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
                            SettingsActionButton {
                                label: "Mute output"
                                icon: "󰖁"
                                accent: root.peach
                                onTriggered: {
                                    let output = root.audioPrimaryNode(root.audioOutputs);
                                    if (output) root.toggleAudioMute("sink", output.id);
                                }
                            }
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

                        Text { text: "Outputs"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(18); color: root.text }
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
                                    onSetDefaultRequested: root.setDefaultAudioDevice("sink", modelData.name)
                                }
                            }
                        }

                        Text { text: "Inputs"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.pixelSize: root.s(18); color: root.text }
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
                                    onSetDefaultRequested: root.setDefaultAudioDevice("source", modelData.name)
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

            // =================================================================
            // TAB 9: SESSION
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 9
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true
                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(14)

                        Text { text: "Session"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width >= root.s(820) ? 2 : 1
                            rowSpacing: root.s(10)
                            columnSpacing: root.s(10)

                            SettingsInfoCard { title: "Actieve mode"; icon: "󰒲"; accent: root.mauve; value: root.sessionModeText }
                            SettingsInfoCard { title: "Idle gedrag"; icon: "󰒳"; accent: root.blue; value: root.sessionIdleSummary() }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Office"; icon: "󰈹"; accent: root.blue; primary: root.sessionModeText === "office"; onTriggered: root.switchSessionMode("office") }
                            SettingsActionButton { label: "Gaming"; icon: "󰊴"; accent: root.green; primary: root.sessionModeText === "gaming"; onTriggered: root.switchSessionMode("gaming") }
                            SettingsActionButton { label: "Media"; icon: "󰝚"; accent: root.peach; primary: root.sessionModeText === "media"; onTriggered: root.switchSessionMode("media") }
                            SettingsActionButton { label: "Mode verversen"; icon: "󰑓"; accent: root.sapphire; onTriggered: sessionModeProc.running = true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(10)
                            SettingsActionButton { label: "Vergrendelen"; icon: "󰌾"; accent: root.yellow; onTriggered: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"]) }
                            SettingsActionButton { label: "Uitlogmenu"; icon: "󰍃"; accent: root.red; onTriggered: Quickshell.execDetached(["wlogout"]) }
                            Item { Layout.fillWidth: true }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: root.s(12)
                            color: Qt.alpha(root.surface0, 0.46)
                            border.color: Qt.alpha(root.surface2, 0.82)
                            border.width: 1

                            ColumnLayout {
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
                                        radius: root.s(10)
                                        color: Qt.alpha(root.surface0, 0.50)
                                        border.color: Qt.alpha(root.red, 0.35)
                                        border.width: 1

                                        ColumnLayout {
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
                                        radius: root.s(10)
                                        color: Qt.alpha(root.surface0, 0.50)
                                        border.color: Qt.alpha(root.blue, 0.35)
                                        border.width: 1

                                        ColumnLayout {
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
                                        radius: root.s(10)
                                        color: Qt.alpha(root.surface0, 0.50)
                                        border.color: Qt.alpha(root.green, 0.35)
                                        border.width: 1

                                        ColumnLayout {
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
                                        Behavior on scale { NumberAnimation { duration: 150 } }

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
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =================================================================
            // TAB 10: UPDATES
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 10
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    spacing: root.s(14)

                    Text { text: "Updates"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                    SettingsInfoCard { title: "Packages"; icon: "󰚰"; accent: root.green; value: root.updateStatusText }

                    Flow {
                        Layout.fillWidth: true
                        spacing: root.s(10)
                        SettingsActionButton { label: "Package update"; icon: "󰚰"; accent: root.green; primary: true; onTriggered: root.runPackageUpgrade() }
                        SettingsActionButton { label: "Dotfiles update"; icon: "󰐕"; accent: root.blue; onTriggered: root.runUpdateBootstrap() }
                        SettingsActionButton { label: "Check opnieuw"; icon: "󰑓"; accent: root.peach; onTriggered: updatesStatusProc.running = true }
                    }

                    SettingsInfoCard { title: "Uitvoering"; icon: "󰄛"; accent: root.yellow; value: "Updates draaien bewust in Kitty met hold, zodat output en fouten zichtbaar blijven." }
                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 11: ADVANCED
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 11
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    spacing: root.s(14)

                    Text { text: "Advanced"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text }
                    SettingsInfoCard { title: "Status"; icon: "󰋼"; accent: root.blue; value: root.advancedStatusText }

                    Flow {
                        Layout.fillWidth: true
                        spacing: root.s(10)
                        SettingsActionButton { label: "Topbar herladen"; icon: "󰑓"; accent: root.blue; onTriggered: root.reloadTopbar() }
                        SettingsActionButton { label: "Quickshell herstart"; icon: "󰜉"; accent: root.peach; onTriggered: root.restartQuickshell() }
                        SettingsActionButton { label: "Matugen render"; icon: "󰏘"; accent: root.mauve; onTriggered: root.rerenderTheme() }
                        SettingsActionButton { label: "Alle status verversen"; icon: "󰑓"; accent: root.green; onTriggered: root.refreshOperationalStatus() }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= root.s(760) ? 2 : 1
                        rowSpacing: root.s(10)
                        columnSpacing: root.s(10)
                        SettingsInfoCard { title: "Config home"; icon: "󰉋"; accent: root.sapphire; value: root.configHome() }
                        SettingsInfoCard { title: "Actief theme"; icon: "󰏘"; accent: root.mauve; value: root.activeThemeId || "onbekend" }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 0: THEME (MATUGEN)
            // =================================================================
            Item {
                id: themeTab
                anchors.fill: parent
                visible: root.currentTab === 0
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

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

                        Text { text: "Theming Engine"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }
                        Text { text: "Kies een thema, bekijk direct fonts, icons en Matugen-scene, en pas het daarna expliciet toe."; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

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
                                        Text { text: "Actief thema"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0 }
                                        Text { text: root.activeThemeName || "Geen thema actief"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                        Text { text: root.activeThemeId || ""; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.overlay0; visible: text !== "" }
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
                                        Text { text: "Geselecteerd"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0 }
                                        Text { text: themeCarousel.selectedThemeData.name || "Selecteer een thema"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                        Text { text: themeCarousel.selectedThemeId || ""; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.overlay0; visible: text !== "" }
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
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    RowLayout {
                                        anchors.centerIn: parent; spacing: root.s(6)
                                        Text { text: themeCarousel.selectedThemeId === root.activeThemeId ? "󰄬" : "󰑐"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.base }
                                        Text { text: themeCarousel.selectedThemeId === root.activeThemeId ? "Al actief" : "Thema toepassen"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
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
                                        Text { text: "󰍹"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: root.text }
                                        Text { text: "Vol scherm"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.text }
                                    }
                                    MouseArea {
                                        id: themeFullscreenMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "theme"])
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
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(12)
                                    color: root.text
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                        Text { text: "Thema-instellingen"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                        Text {
                            text: "Kies een groep, pas waarden aan en sla daarna het thema op."
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(10)
                            color: root.subtext0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(8)

                            Rectangle {
                                Layout.preferredHeight: root.s(34)
                                Layout.preferredWidth: root.s(220)
                                radius: root.s(8)
                                color: allVarsToggleMa.containsMouse ? Qt.alpha(root.blue, 0.20) : Qt.alpha(root.surface0, 0.65)
                                border.color: allVarsToggleMa.containsMouse ? root.blue : root.surface2
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: root.s(8)
                                    spacing: root.s(8)
                                    Text {
                                        text: root.showAllThemeVariables ? "󰅂" : "󰅀"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: root.s(14)
                                        color: root.blue
                                    }
                                    Text {
                                        text: root.showAllThemeVariables ? "Verberg alle variabelen" : "Toon alle variabelen"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: root.s(11)
                                        font.weight: Font.Bold
                                        color: root.text
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: allVarsToggleMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showAllThemeVariables = !root.showAllThemeVariables
                                }
                            }

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
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: root.s(14)
                                        color: root.themeDirty ? root.base : root.subtext0
                                    }
                                    Text {
                                        text: root.themeSaveBusy
                                              ? "Opslaan..."
                                              : (root.themeDirty
                                                  ? (root.themeEditThemeId === root.activeThemeId ? "Opslaan & toepassen" : "Opslaan")
                                                  : "Geen wijzigingen")
                                        font.family: "JetBrains Mono"
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
                                    Text { text: "󰑓"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(13); color: root.peach }
                                    Text { text: "Herstel"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.text }
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
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(13)
                                            color: parent.parent.active ? root.blue : root.subtext0
                                        }
                                        Text {
                                            text: modelData.label
                                            font.family: "JetBrains Mono"
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
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(13)
                                    color: root.themeDirty ? root.yellow : (root.themeStatusKind === "error" ? root.red : (root.themeStatusKind === "ok" ? root.green : root.blue))
                                }
                                Text {
                                    text: root.themeDirty
                                          ? "Onopgeslagen wijzigingen in " + root.themeEditThemeId + ".toml"
                                          : (root.themeStatusText !== "" ? root.themeStatusText : "Klaar")
                                    Layout.fillWidth: true
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(10)
                                    color: root.text
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        GridLayout {
                            id: themeEditorsGrid
                            Layout.fillWidth: true
                            columns: width >= root.s(1040) ? 2 : 1
                            rowSpacing: root.s(10)
                            columnSpacing: root.s(10)
                            property int labelWidth: root.s(106)
                            property int spinWidth: root.s(150)
                            property int comboWidth: root.s(220)

                            Rectangle {
                                visible: root.themeEditorTab === "appearance"
                                Layout.fillWidth: true
                                Layout.preferredWidth: root.s(470)
                                Layout.maximumWidth: root.s(560)
                                Layout.alignment: Qt.AlignHCenter
                                implicitHeight: appearanceEditor.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.48)
                                border.color: Qt.alpha(root.surface2, 0.88)
                                border.width: 1

                                ColumnLayout {
                                    id: appearanceEditor
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(8)

                                    Text { text: "Uiterlijk"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Hoekrondheid"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 64; value: root.editBorderRadius; onValueChanged: root.editBorderRadius = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Randdikte"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 12; value: root.editBorderWidth; onValueChanged: root.editBorderWidth = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Binnenmarge"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 60; value: root.editGapsIn; onValueChanged: root.editGapsIn = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Buitenmarge"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 80; value: root.editGapsOut; onValueChanged: root.editGapsOut = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Blur size"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 64; value: root.editBlurSize; onValueChanged: root.editBlurSize = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Blur passes"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 12; value: root.editBlurPasses; onValueChanged: root.editBlurPasses = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.themeEditorTab === "fonts"
                                Layout.fillWidth: true
                                Layout.preferredWidth: root.s(470)
                                Layout.maximumWidth: root.s(560)
                                Layout.alignment: Qt.AlignHCenter
                                implicitHeight: fontsEditor.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.48)
                                border.color: Qt.alpha(root.surface2, 0.88)
                                border.width: 1

                                ColumnLayout {
                                    id: fontsEditor
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(8)

                                    Text { text: "Fonts"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "UI font"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.fontOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editUiFont))
                                            onActivated: root.editUiFont = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "UI size"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 8; to: 28; value: root.editUiFontSize; onValueChanged: root.editUiFontSize = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Mono font"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.fontOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editMonoFont))
                                            onActivated: root.editMonoFont = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Mono size"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 8; to: 28; value: root.editMonoFontSize; onValueChanged: root.editMonoFontSize = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Display font"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.fontOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editDisplayFont))
                                            onActivated: root.editDisplayFont = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Font weight"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.fontWeightOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editFontWeight))
                                            onActivated: root.editFontWeight = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Letter spacing"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: -300
                                            to: 300
                                            stepSize: 1
                                            value: Math.round(parseFloat(root.editLetterSpacing) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) {
                                                var n = parseFloat(text);
                                                if (isNaN(n)) return 0;
                                                return Math.round(n * 100);
                                            }
                                            onValueChanged: root.editLetterSpacing = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.themeEditorTab === "colors"
                                Layout.fillWidth: true
                                Layout.preferredWidth: root.s(470)
                                Layout.maximumWidth: root.s(560)
                                Layout.alignment: Qt.AlignHCenter
                                implicitHeight: colorEditor.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.48)
                                border.color: Qt.alpha(root.surface2, 0.88)
                                border.width: 1

                                ColumnLayout {
                                    id: colorEditor
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(8)

                                    Text { text: "Icons & Matugen"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Icon theme"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.iconThemeOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editIconTheme))
                                            onActivated: root.editIconTheme = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Scene"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.schemeOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editSchemeType))
                                            onActivated: root.editSchemeType = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Mode"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.modeOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editMode))
                                            onActivated: root.editMode = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Color index"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 12; value: root.editColorIndex; onValueChanged: root.editColorIndex = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Contrast"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: -100
                                            to: 100
                                            stepSize: 1
                                            value: Math.round(parseFloat(root.editContrast) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) {
                                                var n = parseFloat(text);
                                                if (isNaN(n)) return 0;
                                                return Math.round(n * 100);
                                            }
                                            onValueChanged: root.editContrast = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    Text {
                                        text: "Scene bepaalt de Matugen-kleurberekening; mode schakelt donker/licht; icon theme wordt toegepast op GTK en Qt6."
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: root.s(10)
                                        color: root.subtext0
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.themeEditorTab === "bar" || root.themeEditorTab === "effects" || root.themeEditorTab === "character"
                                Layout.fillWidth: true
                                Layout.preferredWidth: root.s(470)
                                Layout.maximumWidth: root.s(560)
                                Layout.alignment: Qt.AlignHCenter
                                implicitHeight: shellEditor.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.48)
                                border.color: Qt.alpha(root.surface2, 0.88)
                                border.width: 1

                                ColumnLayout {
                                    id: shellEditor
                                    anchors.fill: parent
                                    anchors.margins: root.s(12)
                                    spacing: root.s(8)

                                    Text { text: root.themeEditorTab === "effects" ? "Effecten" : (root.themeEditorTab === "character" ? "Karakter" : "Bar"); font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                                    Text {
                                        text: root.themeEditorTab === "effects"
                                              ? "Regel transparantie, materiaalgevoel, animaties en deeltjes."
                                              : (root.themeEditorTab === "character"
                                                 ? "Visuele eigenschappen per thema. Modes blijven bepalen welke modules zichtbaar zijn."
                                                 : "Positie kiest de schermrand en bepaalt automatisch of de bar horizontaal of verticaal loopt.")
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: root.s(10)
                                        color: root.subtext0
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Bar height"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 30; to: 72; value: root.editBarHeight; onValueChanged: root.editBarHeight = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Bar position"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.barPositionOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editBarPosition))
                                            onActivated: root.setEditBarPosition(currentText)
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Bar width"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.barWidthModeOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editBarWidthMode))
                                            onActivated: root.editBarWidthMode = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Bar shape"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.barShapeOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editBarShape))
                                            onActivated: root.editBarShape = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Top edge"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.barEdgeStyleOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editBarTopEdgeStyle))
                                            onActivated: root.editBarTopEdgeStyle = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Bottom edge"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.barEdgeStyleOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editBarBottomEdgeStyle))
                                            onActivated: root.editBarBottomEdgeStyle = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Clock style"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.clockStyleOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editClockStyle))
                                            onActivated: root.editClockStyle = currentText
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Topbar stijl"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: ["losse blokken", "strakke lijn"]
                                            currentIndex: root.editTopbarLooseBlocks ? 0 : 1
                                            enabled: root.editBarPosition === "top"
                                            onActivated: root.editTopbarLooseBlocks = (currentIndex === 0)
                                            Layout.fillWidth: false
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    // ── Transparantie & animatie ──────────────────────────────────────
                                    Text { visible: root.themeEditorTab === "effects"; text: "Transparantie & animatie"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.overlay0; topPadding: root.s(4) }

                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Bar opacity"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: 10; to: 100; stepSize: 1
                                            value: Math.round(parseFloat(root.editBarOpacity) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 72 : Math.round(n * 100); }
                                            onValueChanged: root.editBarOpacity = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Popup opacity"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: 10; to: 100; stepSize: 1
                                            value: Math.round(parseFloat(root.editPopupOpacity) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 80 : Math.round(n * 100); }
                                            onValueChanged: root.editPopupOpacity = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Animatiesnelheid"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: 10; to: 300; stepSize: 5
                                            value: Math.round(parseFloat(root.editAnimationSpeed) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 75 : Math.round(n * 100); }
                                            onValueChanged: root.editAnimationSpeed = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    // ── Materiaal ────────────────────────────────────────────────────
                                    Text { visible: root.themeEditorTab === "effects"; text: "Materiaal"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.overlay0; topPadding: root.s(4) }

                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Overlay opacity"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: 0; to: 50; stepSize: 1
                                            value: Math.round(parseFloat(root.editOverlayOpacity) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 6 : Math.round(n * 100); }
                                            onValueChanged: root.editOverlayOpacity = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Glow intensiteit"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: 0; to: 50; stepSize: 1
                                            value: Math.round(parseFloat(root.editGlowIntensity) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 4 : Math.round(n * 100); }
                                            onValueChanged: root.editGlowIntensity = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    // ── Effecten ─────────────────────────────────────────────────────
                                    Text { visible: root.themeEditorTab === "effects"; text: "Deeltjes"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.overlay0; topPadding: root.s(4) }

                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Particle type"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox {
                                            model: root.particleTypeOptions
                                            currentIndex: Math.max(0, model.indexOf(root.editParticleType))
                                            onActivated: root.editParticleType = currentText
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Particle count"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: 0; to: 100; stepSize: 1
                                            value: root.editParticleCount
                                            onValueChanged: root.editParticleCount = value
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "effects"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Particle speed"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox {
                                            from: 1; to: 500; stepSize: 1
                                            value: Math.round(parseFloat(root.editParticleSpeed) * 100)
                                            textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }
                                            valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 18 : Math.round(n * 100); }
                                            onValueChanged: root.editParticleSpeed = (value / 100.0).toFixed(2)
                                            Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    // ── Karakter: style profile ──────────────────────────────────────
                                    Text { visible: root.themeEditorTab === "character"; text: "Style profile"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.overlay0; topPadding: root.s(4) }

                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Family"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.styleFamilyOptions; currentIndex: Math.max(0, model.indexOf(root.editStyleFamily)); onActivated: root.editStyleFamily = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Density"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.styleDensityOptions; currentIndex: Math.max(0, model.indexOf(root.editStyleDensity)); onActivated: root.editStyleDensity = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Surface"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.surfaceModeOptions; currentIndex: Math.max(0, model.indexOf(root.editSurfaceMode)); onActivated: root.editSurfaceMode = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Motion"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.styleMotionOptions; currentIndex: Math.max(0, model.indexOf(root.editStyleMotion)); onActivated: root.editStyleMotion = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Shadow"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 50; stepSize: 1; value: Math.round(parseFloat(root.editPanelShadow) * 100); textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }; valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 22 : Math.round(n * 100); }; onValueChanged: root.editPanelShadow = (value / 100.0).toFixed(2); Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Outline"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 50; stepSize: 1; value: Math.round(parseFloat(root.editOutlineStrength) * 100); textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }; valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 18 : Math.round(n * 100); }; onValueChanged: root.editOutlineStrength = (value / 100.0).toFixed(2); Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Glass"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 50; stepSize: 1; value: Math.round(parseFloat(root.editGlassStrength) * 100); textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }; valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 10 : Math.round(n * 100); }; onValueChanged: root.editGlassStrength = (value / 100.0).toFixed(2); Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Radius"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 4; to: 48; value: root.editWidgetRadius; onValueChanged: root.editWidgetRadius = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Padding"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 6; to: 28; value: root.editPanelPadding; onValueChanged: root.editPanelPadding = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }

                                    // ── Karakter: effectgedrag ───────────────────────────────────────
                                    Text { visible: root.themeEditorTab === "character"; text: "Effectgedrag"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.overlay0; topPadding: root.s(4) }

                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Ambient"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.ambientEffectOptions; currentIndex: Math.max(0, model.indexOf(root.editAmbientEffect)); onActivated: root.editAmbientEffect = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Intensity"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 200; stepSize: 5; value: Math.round(parseFloat(root.editEffectIntensity) * 100); textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }; valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 100 : Math.round(n * 100); }; onValueChanged: root.editEffectIntensity = (value / 100.0).toFixed(2); Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Cycle ms"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 30000; stepSize: 100; value: root.editEffectCycleMs; onValueChanged: root.editEffectCycleMs = value; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Hover"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedSpinBox { from: 0; to: 100; stepSize: 5; value: Math.round(parseFloat(root.editHoverReactivity) * 100); textFromValue: function(v, locale) { return (v / 100.0).toFixed(2); }; valueFromText: function(text, locale) { var n = parseFloat(text); return isNaN(n) ? 40 : Math.round(n * 100); }; onValueChanged: root.editHoverReactivity = (value / 100.0).toFixed(2); Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.spinWidth }
                                        Item { Layout.fillWidth: true }
                                    }

                                    // ── Karakter: bar dynamics ───────────────────────────────────────
                                    Text { visible: root.themeEditorTab === "character"; text: "Bar dynamics"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.overlay0; topPadding: root.s(4) }

                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Drawer"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.drawerStyleOptions; currentIndex: Math.max(0, model.indexOf(root.editDrawerStyle)); onActivated: root.editDrawerStyle = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Modules"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.moduleDensityOptions; currentIndex: Math.max(0, model.indexOf(root.editModuleDensity)); onActivated: root.editModuleDensity = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Workspace"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.workspacePreviewOptions; currentIndex: Math.max(0, model.indexOf(root.editWorkspacePreview)); onActivated: root.editWorkspacePreview = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }
                                    RowLayout {
                                        visible: root.themeEditorTab === "character"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Rail accent"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        ThemedComboBox { model: root.railAccentOptions; currentIndex: Math.max(0, model.indexOf(root.editRailAccent)); onActivated: root.editRailAccent = currentText; Layout.fillWidth: false; Layout.preferredWidth: themeEditorsGrid.comboWidth }
                                        Item { Layout.fillWidth: true }
                                    }

                                    // ── Topbar acties ─────────────────────────────────────────────────
                                    Text { visible: root.themeEditorTab === "bar"; text: "Acties"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.overlay0; topPadding: root.s(4) }

                                    RowLayout {
                                        visible: root.themeEditorTab === "bar"
                                        Layout.fillWidth: true
                                        spacing: root.s(10)
                                        Text { text: "Topbar toepassen"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.preferredWidth: themeEditorsGrid.labelWidth }
                                        Rectangle {
                                            Layout.preferredHeight: root.s(32)
                                            Layout.preferredWidth: themeEditorsGrid.comboWidth
                                            radius: root.s(8)
                                            color: topbarReloadMa.containsMouse ? Qt.alpha(root.blue, 0.24) : Qt.alpha(root.surface1, 0.68)
                                            border.width: 1
                                            border.color: topbarReloadMa.containsMouse ? root.blue : root.surface2
                                            opacity: root.topbarReloadBusy || root.themeSaveBusy ? 0.65 : 1.0
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: root.s(6)
                                                Text { text: root.topbarReloadBusy || root.themeSaveBusy ? "󰔟" : "󰑓"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(13); color: root.text }
                                                Text { text: root.topbarReloadBusy || root.themeSaveBusy ? "Toepassen..." : "Topbar toepassen"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: root.text }
                                            }
                                            MouseArea {
                                                id: topbarReloadMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !root.topbarReloadBusy && !root.themeSaveBusy
                                                onClicked: root.applyTopbarEdits()
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    Text {
                                        text: root.themeEditorTab === "effects"
                                              ? "Effecten worden per theme opgeslagen en bewegen mee met theme-switches."
                                              : "Bar-instellingen worden per theme opgeslagen en blijven behouden na herstart of theme-switch."
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: root.s(10)
                                        color: root.subtext0
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: allVarsPanel
                            visible: root.showAllThemeVariables
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
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: root.s(13)
                                        color: root.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: themeCarousel.selectedThemeId !== "" ? themeCarousel.selectedThemeId + ".toml" : ""
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: root.s(10)
                                        color: root.overlay0
                                    }
                                }

                                Text {
                                    text: "Volledige key-paths uit het geselecteerde thema. Pas waarden bovenaan aan en klik 'Opslaan in thema'."
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(10)
                                    color: root.subtext0
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                ScrollView {
                                    id: allVarsScroll
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(280)
                                    clip: true
                                    ScrollBar.vertical.policy: TouchProfile.isTouchscreen ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded

                                    ListView {
                                        anchors.fill: parent
                                        model: allVarsPanel.flatEntries
                                        spacing: root.s(4)
                                        clip: true

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: ListView.view.width
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
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: root.s(10)
                                                    color: root.subtext0
                                                    Layout.preferredWidth: root.s(250)
                                                    wrapMode: Text.WrapAnywhere
                                                }

                                                Text {
                                                    text: String(modelData.value || "—")
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: root.s(10)
                                                    font.weight: Font.Bold
                                                    color: root.text
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WrapAnywhere
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: allVarsWheelCatcher
                                        anchors.fill: parent
                                        enabled: !TouchProfile.isTouchscreen
                                        acceptedButtons: Qt.NoButton
                                        hoverEnabled: true
                                        propagateComposedEvents: true
                                        onWheel: (wheel) => {
                                            if (root.scrollFlickableByWheel(allVarsScroll.contentItem, wheel)) {
                                                wheel.accepted = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                        RowLayout {
                            spacing: root.s(8)
                            Text { text: "󰇚"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: root.ambientPurple }
                            Text { text: "Matugen Pipeline"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(14); color: root.text }
                        }

                        Text { text: "Bij toepassen van een thema worden de huidige wallpaper-kleuren opnieuw door Matugen gerenderd en in deze templates geïnjecteerd:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        GridLayout {
                            Layout.fillWidth: true; columns: 3; rowSpacing: root.s(6); columnSpacing: root.s(8)
                            Repeater {
                                model: [
                                    { f: "kitty/colors.conf", i: "󰄛", c: "yellow" },
                                    { f: "quickshell/colors.json", i: "󰣆", c: "mauve" },
                                    { f: "swaync/colors.css", i: "󰂚", c: "pink" },
                                    { f: "walker/colors.css", i: "󰀻", c: "green" },
                                    { f: "zsh/omp-colors.toml", i: "󱆃", c: "blue" },
                                    { f: "hypr/colors.conf", i: "󰆍", c: "peach" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: root.s(36); radius: root.s(6)
                                    color: tplMa.containsMouse ? Qt.alpha(root[modelData.c], 0.1) : root.surface0
                                    border.color: tplMa.containsMouse ? root[modelData.c] : "transparent"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: root.s(8); spacing: root.s(8)
                                        Text { text: modelData.i; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: root[modelData.c] }
                                        Text { text: modelData.f; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.text; Layout.fillWidth: true }
                                    }
                                    MouseArea { id: tplMa; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
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
                        if (root.showAllThemeVariables
                                && allVarsScroll.visible
                                && allVarsWheelCatcher.containsMouse
                                && root.scrollFlickableByWheel(allVarsScroll.contentItem, wheel)) {
                            wheel.accepted = true;
                            return;
                        }
                        if (root.scrollFlickableByWheel(themeScroll.contentItem, wheel)) {
                            wheel.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
