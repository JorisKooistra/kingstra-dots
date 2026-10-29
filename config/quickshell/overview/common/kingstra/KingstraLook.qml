import QtQuick
import Quickshell
import Quickshell.Io

// Gedeelde stijl voor beide Super+Tab-overzichten (werkruimte-overzicht en
// werkvlak-kaart). Het overzicht draait als eigen Quickshell-proces en kan
// MatugenColors/ThemeConfig niet importeren, dus dit leest dezelfde
// colors.json en theme.json. Beide overzichten gebruiken dit object, zodat
// kleur, hoeken, letters en tempo altijd gelijk zijn.
Item {
    id: look
    visible: false

    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color overlay0: "#6c7086"
    property color red: "#f38ba8"
    property color primary: "#89b4fa"
    property color primaryText: "#11111b"
    property color primaryContainer: "#74c7ec"
    property color primaryContainerText: "#cdd6f4"
    property color secondary: "#cba6f7"
    property color secondaryText: "#11111b"
    property color secondaryContainer: "#94e2d5"
    property color secondaryContainerText: "#cdd6f4"
    property color surface: "#11111b"
    property color surfaceText: "#cdd6f4"
    property color surfaceVariantText: "#a6adc8"
    property color surfaceContainer: "#313244"
    property color surfaceContainerHigh: "#45475a"
    property color surfaceContainerHighest: "#585b70"

    property string uiFont: "Inter"
    property string monoFont: "JetBrainsMono Nerd Font"
    property int borderRadius: 12
    property real popupOpacity: 0.85
    property real animationSpeed: 1.0
    property string motion: "gentle"
    property real outlineStrength: 0.18
    property real glassStrength: 0.10

    // Panelen (achtergrond, werkruimte, kaartvlak) en kaarten (vensters).
    readonly property int panelRadius: Math.max(8, borderRadius)
    readonly property int cardRadius: Math.max(6, Math.round(borderRadius * 0.66))
    readonly property real raisedOpacity: Math.max(0.46, Math.min(0.66,
        0.30 + popupOpacity * 0.32 + glassStrength * 0.22))
    readonly property color panelFill: Qt.rgba(base.r, base.g, base.b,
        Math.max(0.68, Math.min(0.84, 0.50 + popupOpacity * 0.34)))
    readonly property color raisedFill: Qt.rgba(surface0.r, surface0.g, surface0.b, raisedOpacity)
    readonly property color hoverFill: Qt.rgba(surface2.r, surface2.g, surface2.b, Math.min(0.82, raisedOpacity + 0.18))
    readonly property color outline: Qt.rgba(text.r, text.g, text.b,
        Math.max(0.10, Math.min(0.22, 0.08 + outlineStrength * 0.42)))
    readonly property color selectedTint: Qt.rgba(primary.r, primary.g, primary.b, 0.16)
    readonly property color hoverTint: Qt.rgba(primary.r, primary.g, primary.b, 0.08)

    readonly property real motionScale: {
        let speed = Math.max(0.25, Math.min(3.0, Number(animationSpeed) || 1.0));
        let m = String(motion || "gentle").toLowerCase();
        let modifier = m === "firm" ? 0.78 : m === "gentle" ? 1.08 : m === "minimal" ? 0.60
            : m === "snappy" ? 0.88 : m === "calm" ? 1.15 : 1.0;
        return modifier / speed;
    }
    function duration(ms) {
        let parsed = Number(ms);
        if (isNaN(parsed) || parsed <= 0) return 0;
        return Math.max(1, Math.round(parsed * motionScale));
    }

    readonly property string configDir: Quickshell.env("HOME") + "/.config/quickshell"

    FileView {
        id: colorsFile
        path: look.configDir + "/colors.json"
        preload: true
        watchChanges: true
        onInternalTextChanged: {
            try {
                let c = JSON.parse(__text);
                let pick = (key, fallback) => c[key] ? c[key] : fallback;
                look.base = pick("base", look.base);
                look.mantle = pick("mantle", look.mantle);
                look.surface0 = pick("surface0", look.surface0);
                look.surface1 = pick("surface1", look.surface1);
                look.surface2 = pick("surface2", look.surface2);
                look.text = pick("text", look.text);
                look.subtext0 = pick("subtext0", look.subtext0);
                look.overlay0 = pick("overlay0", look.overlay0);
                look.red = pick("red", look.red);
                look.primary = pick("primary", look.primary);
                look.primaryText = pick("on_primary", look.primaryText);
                look.primaryContainer = pick("primary_container", look.primaryContainer);
                look.primaryContainerText = pick("on_primary_container", look.primaryContainerText);
                look.secondary = pick("secondary", look.secondary);
                look.secondaryText = pick("on_secondary", look.secondaryText);
                look.secondaryContainer = pick("secondary_container", look.secondaryContainer);
                look.secondaryContainerText = pick("on_secondary_container", look.secondaryContainerText);
                look.surface = pick("surface", look.surface);
                look.surfaceText = pick("on_surface", look.surfaceText);
                look.surfaceVariantText = pick("on_surface_variant", look.surfaceVariantText);
                look.surfaceContainer = pick("surface_container", look.surfaceContainer);
                look.surfaceContainerHigh = pick("surface_container_high", look.surfaceContainerHigh);
                look.surfaceContainerHighest = pick("surface_container_highest", look.surfaceContainerHighest);
            } catch (e) {}
        }
    }
    FileView {
        id: themeFile
        path: look.configDir + "/theme.json"
        preload: true
        watchChanges: true
        onInternalTextChanged: {
            try {
                let d = JSON.parse(__text);
                let style = d.style_profile || {};
                if (d.ui_font !== undefined) look.uiFont = String(d.ui_font);
                if (d.mono_font !== undefined) look.monoFont = String(d.mono_font);
                if (d.border_radius !== undefined && !isNaN(parseInt(d.border_radius))) look.borderRadius = parseInt(d.border_radius);
                if (d.popup_opacity !== undefined) look.popupOpacity = Math.max(0.15, Math.min(1, Number(d.popup_opacity) || 0.85));
                if (d.animation_speed !== undefined) look.animationSpeed = Number(d.animation_speed) || 1.0;
                if (style.motion !== undefined) look.motion = String(style.motion);
                if (style.outline_strength !== undefined) look.outlineStrength = Math.max(0, Math.min(0.5, Number(style.outline_strength) || 0));
                if (style.glass_strength !== undefined) look.glassStrength = Math.max(0, Math.min(0.5, Number(style.glass_strength) || 0));
            } catch (e) {}
        }
    }
    // Zelfde vangnet als MatugenColors: watchChanges mist inode-vervanging.
    Timer {
        interval: 5000; repeat: true; running: true
        onTriggered: { colorsFile.reload(); themeFile.reload(); }
    }
}
