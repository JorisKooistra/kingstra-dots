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
    property string barShape: "rounded"
    property string barWidthMode: "full"
    property bool barFloating: false
    property bool barAttachToScreenEdge: true
    property string barTopEdgeStyle: "soft"
    property string barBottomEdgeStyle: "soft"
    property string clockStyle: "digital"
    property string widgetShape: "rounded"
    property string widgetSurfaceStyle: "standard"
    property bool ornamentEnabled: false
    property string ornamentTopLeft: ""
    property string ornamentTopRight: ""
    property real ornamentOpacity: 0.0
    property string particleType: "none"
    property int particleCount: 0
    property real particleSpeed: 0.0
    property string terminalOverlayAsset: ""
    property real terminalOverlayOpacity: 0.0

    property string materialTexture: "none"
    property real materialOverlayOpacity: 0.0
    property real materialGlowIntensity: 0.0

    property string styleFamily: "botanical"
    property string styleDensity: "comfortable"
    property string styleSurfaceMode: "soft-glass"
    property string styleMotion: "gentle"
    property string styleOrnament: "organic"
    property real stylePanelShadow: 0.22
    property real styleOutlineStrength: 0.18
    property real styleGlassStrength: 0.10
    property int styleWidgetRadius: 16
    property int stylePanelPadding: 14

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
                    if (data.bar_shape !== undefined) root.barShape = String(data.bar_shape);
                    if (data.bar_width_mode !== undefined) root.barWidthMode = String(data.bar_width_mode);
                    if (data.bar_floating !== undefined) root.barFloating = !!data.bar_floating;
                    if (data.bar_attach_to_screen_edge !== undefined) root.barAttachToScreenEdge = !!data.bar_attach_to_screen_edge;
                    if (data.bar_top_edge_style !== undefined) root.barTopEdgeStyle = String(data.bar_top_edge_style);
                    if (data.bar_bottom_edge_style !== undefined) root.barBottomEdgeStyle = String(data.bar_bottom_edge_style);
                    if (data.clock_style !== undefined) root.clockStyle = String(data.clock_style);
                    if (data.widget_shape !== undefined) root.widgetShape = String(data.widget_shape);
                    if (data.widget_surface !== undefined) root.widgetSurfaceStyle = String(data.widget_surface);
                    if (data.ornament_enabled !== undefined) root.ornamentEnabled = !!data.ornament_enabled;
                    if (data.ornament_top_left !== undefined) root.ornamentTopLeft = String(data.ornament_top_left);
                    if (data.ornament_top_right !== undefined) root.ornamentTopRight = String(data.ornament_top_right);
                    if (data.ornament_opacity !== undefined) root.ornamentOpacity = root.clamp(Number(data.ornament_opacity), 0.0, 1.0);
                    if (data.particle_type !== undefined) root.particleType = String(data.particle_type);
                    if (data.particle_count !== undefined) root.particleCount = parseInt(root.clamp(Number(data.particle_count), 0, 50));
                    if (data.particle_speed !== undefined) root.particleSpeed = root.clamp(Number(data.particle_speed), 0.0, 2.0);
                    if (data.terminal_overlay_asset !== undefined) root.terminalOverlayAsset = String(data.terminal_overlay_asset);
                    if (data.terminal_overlay_opacity !== undefined) root.terminalOverlayOpacity = root.clamp(Number(data.terminal_overlay_opacity), 0.0, 1.0);

                    if (material.texture !== undefined) root.materialTexture = String(material.texture);
                    if (material.overlay_opacity !== undefined) root.materialOverlayOpacity = root.clamp(Number(material.overlay_opacity), 0.0, 0.35);
                    if (material.glow_intensity !== undefined) root.materialGlowIntensity = root.clamp(Number(material.glow_intensity), 0.0, 0.35);

                    let style = data.style_profile || {};
                    if (style.family !== undefined) root.styleFamily = String(style.family);
                    if (style.density !== undefined) root.styleDensity = String(style.density);
                    if (style.surface_mode !== undefined) root.styleSurfaceMode = String(style.surface_mode);
                    if (style.motion !== undefined) root.styleMotion = String(style.motion);
                    if (style.ornament !== undefined) root.styleOrnament = String(style.ornament);
                    if (style.panel_shadow !== undefined) root.stylePanelShadow = root.clamp(Number(style.panel_shadow), 0.0, 0.5);
                    if (style.outline_strength !== undefined) root.styleOutlineStrength = root.clamp(Number(style.outline_strength), 0.0, 0.5);
                    if (style.glass_strength !== undefined) root.styleGlassStrength = root.clamp(Number(style.glass_strength), 0.0, 0.5);
                    if (style.widget_radius !== undefined) root.styleWidgetRadius = parseInt(style.widget_radius) || root.styleWidgetRadius;
                    if (style.panel_padding !== undefined) root.stylePanelPadding = parseInt(style.panel_padding) || root.stylePanelPadding;

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
