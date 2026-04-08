pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string theme: "botanical"
    property string name: "Botanical"
    property string icon: "󰌪"

    property int borderRadius: 12
    property int borderWidth: 2
    property int gapsIn: 5
    property int gapsOut: 10
    property real barOpacity: 0.85
    property real popupOpacity: 0.92
    property int blurSize: 8
    property int blurPasses: 3
    property real animationSpeed: 1.0

    property string uiFont: "Inter"
    property int uiFontSize: 13
    property string monoFont: "JetBrainsMono Nerd Font"
    property int monoFontSize: 12
    property string displayFont: "Inter"
    property string fontWeightName: "regular"
    property real letterSpacing: 0.0
    property string iconTheme: "Papirus-Dark"

    property int barHeight: 36
    property string barPosition: "top"

    property string materialTexture: "none"
    property real materialOverlayOpacity: 0.0
    property real materialGlowIntensity: 0.0

    property string terminalCursorStyle: "block"
    property real terminalBgOpacity: 0.90
    property bool terminalBlur: false
    property int terminalPadding: 10

    property string rawJson: ""

    readonly property int fontWeight: mapFontWeight(fontWeightName)

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function mapFontWeight(value) {
        let normalized = String(value || "regular").toLowerCase();
        if (normalized === "thin") return Font.Thin;
        if (normalized === "extralight" || normalized === "ultralight") return Font.ExtraLight;
        if (normalized === "light") return Font.Light;
        if (normalized === "medium") return Font.Medium;
        if (normalized === "demibold" || normalized === "semibold") return Font.DemiBold;
        if (normalized === "bold") return Font.Bold;
        if (normalized === "extrabold" || normalized === "ultrabold") return Font.ExtraBold;
        if (normalized === "black" || normalized === "heavy") return Font.Black;
        return Font.Normal;
    }

    Process {
        id: themeReader
        command: ["bash", "-c", "cat ~/.config/quickshell/theme.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "" || txt === root.rawJson) return;

                root.rawJson = txt;
                try {
                    let data = JSON.parse(txt);
                    let material = data.material || {};
                    let terminal = data.terminal || {};

                    if (data.theme !== undefined) root.theme = String(data.theme);
                    if (data.name !== undefined) root.name = String(data.name);
                    if (data.icon !== undefined) root.icon = String(data.icon);

                    if (data.border_radius !== undefined) root.borderRadius = parseInt(data.border_radius) || root.borderRadius;
                    if (data.border_width !== undefined) root.borderWidth = parseInt(data.border_width) || root.borderWidth;
                    if (data.gaps_in !== undefined) root.gapsIn = parseInt(data.gaps_in) || root.gapsIn;
                    if (data.gaps_out !== undefined) root.gapsOut = parseInt(data.gaps_out) || root.gapsOut;
                    if (data.bar_opacity !== undefined) root.barOpacity = root.clamp(Number(data.bar_opacity), 0.15, 1.0);
                    if (data.popup_opacity !== undefined) root.popupOpacity = root.clamp(Number(data.popup_opacity), 0.15, 1.0);
                    if (data.blur_size !== undefined) root.blurSize = parseInt(data.blur_size) || root.blurSize;
                    if (data.blur_passes !== undefined) root.blurPasses = parseInt(data.blur_passes) || root.blurPasses;
                    if (data.animation_speed !== undefined) root.animationSpeed = root.clamp(Number(data.animation_speed), 0.25, 3.0);

                    if (data.ui_font !== undefined) root.uiFont = String(data.ui_font);
                    if (data.ui_font_size !== undefined) root.uiFontSize = parseInt(data.ui_font_size) || root.uiFontSize;
                    if (data.mono_font !== undefined) root.monoFont = String(data.mono_font);
                    if (data.mono_font_size !== undefined) root.monoFontSize = parseInt(data.mono_font_size) || root.monoFontSize;
                    if (data.display_font !== undefined) root.displayFont = String(data.display_font);
                    if (data.font_weight !== undefined) root.fontWeightName = String(data.font_weight);
                    if (data.letter_spacing !== undefined) root.letterSpacing = Number(data.letter_spacing) || 0.0;
                    if (data.icon_theme !== undefined) root.iconTheme = String(data.icon_theme);

                    if (data.bar_height !== undefined) root.barHeight = parseInt(data.bar_height) || root.barHeight;
                    if (data.bar_position !== undefined) root.barPosition = String(data.bar_position);

                    if (material.texture !== undefined) root.materialTexture = String(material.texture);
                    if (material.overlay_opacity !== undefined) root.materialOverlayOpacity = root.clamp(Number(material.overlay_opacity), 0.0, 0.35);
                    if (material.glow_intensity !== undefined) root.materialGlowIntensity = root.clamp(Number(material.glow_intensity), 0.0, 0.35);

                    if (terminal.cursor_style !== undefined) root.terminalCursorStyle = String(terminal.cursor_style);
                    if (terminal.bg_opacity !== undefined) root.terminalBgOpacity = root.clamp(Number(terminal.bg_opacity), 0.15, 1.0);
                    if (terminal.blur !== undefined) root.terminalBlur = !!terminal.blur;
                    if (terminal.padding !== undefined) root.terminalPadding = parseInt(terminal.padding) || root.terminalPadding;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: themeReader.running = true
    }
}
