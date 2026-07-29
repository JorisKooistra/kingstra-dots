import QtQuick
import QtQuick.Layouts
import Quickshell
import "modules"
import "../mail"

// Horizontal bar layout: left modules | center clock/weather | right status pills.
// All shared theme colors/flags live here and are passed to modules via ctx: root.
//
// ── Hoe mode-filtering werkt ──────────────────────────────────────────────────
// BarShell.qml leest elke 2 seconden ~/.config/kingstra/state/mode.json en zet
// daarmee shell.activeMode en shell.moduleList.
//
// shell.moduleList is een array met strings, één string per module die zichtbaar
// moet zijn. Iedere module controleert zelf of zijn naam erin staat:
//
//   visible: shell.moduleList.includes("network")
//
// Als de array die naam NIET bevat, is de module onzichtbaar.
//
// De drie modi en hun standaard moduleList (zie BarShell._defaultModules):
//
//   office  → workspaces · clock · updates · cpu_temp · network · bluetooth · volume · notifications · mail · battery
//   gaming  → workspaces · clock · cpu_temp · gpu_temp · ram_usage · volume · game_launcher · battery
//   media   → clock · volume · brightness · media_controls · battery
//
// Daarnaast zorgt _normalizeModules dat "updates" en "cpu_temp" altijd aanwezig
// zijn in office-mode en "battery" altijd aanwezig is in alle modi, ook als
// mode.json ze weglaat.
//
// De namen in de array matchen exact de strings die modules checken — wil je een
// module aan/uitzetten, pas dan mode.json aan of de _defaultModules functie in
// BarShell.qml.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    required property var shell
    required property var surface
    required property var mocha



    // ── Theme chrome helpers ───────────────────────────────────────────────
    readonly property int edgeInset: shell.edgeAttachedBar ? shell.s(10) : 0
    readonly property bool flattenScreenEdgeCorners: shell.edgeAttachedBar
                                                     && String(shell.activeThemeName || "").toLowerCase() === "organic"
    readonly property int panelTopLeftRadius:     flattenScreenEdgeCorners && (shell.isTopBar || shell.isLeftBar)   ? 0 : surface.panelRadius
    readonly property int panelTopRightRadius:    flattenScreenEdgeCorners && (shell.isTopBar || shell.isRightBar)  ? 0 : surface.panelRadius
    readonly property int panelBottomLeftRadius:  flattenScreenEdgeCorners && (shell.isBottomBar || shell.isLeftBar)  ? 0 : surface.panelRadius
    readonly property int panelBottomRightRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isRightBar) ? 0 : surface.panelRadius

    readonly property bool neonContinuousLine: surface.continuousBarMode
                                               && String(shell.activeThemeName || "").toLowerCase() === "neon"
    readonly property bool neonCenterFeature: String(shell.activeThemeName || "").toLowerCase() === "neon"
                                             && shell.isTopBar
    readonly property bool neonChrome:   String(shell.activeThemeName || "").toLowerCase() === "neon"
    readonly property bool paperChrome:  String(shell.activeThemeName || "").toLowerCase() === "paper"
    readonly property bool organicChrome: String(shell.activeThemeName || "").toLowerCase() === "organic"
    readonly property bool monoChrome: {
        let themeName = String(shell.activeThemeName || "").toLowerCase();
        return themeName === "mono" || themeName === "mono-accent";
    }
    readonly property int moduleSpacing: organicChrome ? 0 : shell.s(4)
    readonly property int centerGap: organicChrome ? 0 : shell.s(12)
    readonly property string moduleFillColorName: surface.moduleFillColorName
    readonly property string moduleHoverFillColorName: surface.moduleHoverFillColorName
    readonly property string accentColorName: surface.accentColorName
    readonly property string accentHotColorName: surface.accentHotColorName
    readonly property string textHotColorName: surface.textHotColorName
    readonly property real chromeBorderAlphaMultiplier: surface.chromeBorderAlphaMultiplier
    readonly property bool showModuleTick: surface.showModuleTick
    function roleColor(name, fallbackColor) {
        return mocha[name] !== undefined ? mocha[name] : fallbackColor;
    }
    readonly property color neonAccentColor: roleColor(accentColorName, mocha.mauve)
    readonly property color neonHotColor: roleColor(accentHotColorName, mocha.teal)
    readonly property color neonSignalColor: roleColor(textHotColorName, mocha.pink)

    readonly property color themeAccentBorderColor:
        paperChrome   ? Qt.rgba(mocha.teal.r,  mocha.teal.g,  mocha.teal.b,  0.28) :
        organicChrome ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.0) :
        monoChrome    ? Qt.rgba(mocha.text.r,  mocha.text.g,  mocha.text.b,  0.30) :
                          surface.panelBorderColor
    readonly property color themeAccentBorderHoverColor: organicChrome
        ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.0)
        : Qt.rgba(
            themeAccentBorderColor.r,
            themeAccentBorderColor.g,
            themeAccentBorderColor.b,
            Math.min(0.9, themeAccentBorderColor.a + 0.18)
        )

    // Neon center colors
    readonly property color neonCenterColor:            Qt.rgba(mocha.crust.r,   mocha.crust.g,   mocha.crust.b,   0.18)
    readonly property color neonCenterHoverColor:       Qt.rgba(mocha.base.r,    mocha.base.g,    mocha.base.b,    0.30)
    readonly property color neonCenterBorderColor:      Qt.rgba(neonAccentColor.r, neonAccentColor.g, neonAccentColor.b, 0.62)
    readonly property color neonCenterBorderHoverColor: Qt.rgba(neonHotColor.r,    neonHotColor.g,    neonHotColor.b,    0.84)
    readonly property color neonCenterInnerLineColor:   Qt.rgba(neonHotColor.r,    neonHotColor.g,    neonHotColor.b,    0.38)
    readonly property color neonCenterAccentColor:      Qt.rgba(neonAccentColor.r, neonAccentColor.g, neonAccentColor.b, 0.92)
    readonly property color neonCenterDividerColor:     Qt.rgba(neonHotColor.r,    neonHotColor.g,    neonHotColor.b,    0.72)

    // Neon weather colors
    readonly property color neonWeatherTempOnColor:  Qt.lighter(neonSignalColor, 1.08)
    readonly property color neonWeatherTempOffColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.14)

    // Neon module (pill) colors — used by every status pill
    readonly property color neonModuleColor:            Qt.rgba(mocha.crust.r,   mocha.crust.g,   mocha.crust.b,   0.16)
    readonly property color neonModuleHoverColor:       Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.26)
    readonly property color neonModuleBorderColor:      Qt.rgba(neonHotColor.r,    neonHotColor.g,    neonHotColor.b,    0.44)
    readonly property color neonModuleBorderHoverColor: Qt.rgba(neonAccentColor.r, neonAccentColor.g, neonAccentColor.b, 0.74)
    readonly property color neonModuleTickColor:        Qt.rgba(neonHotColor.r,    neonHotColor.g,    neonHotColor.b,    0.72)

    // Neon text colors
    readonly property color neonTextColor:      Qt.rgba(mocha.text.r,   mocha.text.g,   mocha.text.b,   0.98)
    readonly property color neonTextMutedColor: Qt.rgba(mocha.text.r,   mocha.text.g,   mocha.text.b,   0.84)
    readonly property color neonTextHotColor:   Qt.rgba(neonSignalColor.r, neonSignalColor.g, neonSignalColor.b, 1.0)

    // Neon workspace colors
    readonly property color neonWorkspaceActiveColor:   Qt.rgba(neonAccentColor.r, neonAccentColor.g, neonAccentColor.b, 0.94)
    readonly property color neonWorkspaceOccupiedColor: Qt.rgba(neonHotColor.r,    neonHotColor.g,    neonHotColor.b,    0.14)

    // Neon center geometry
    readonly property real neonCenterScale:        neonCenterFeature ? 1.6 : 1.0
    readonly property int  neonWindowUnderhang:    Number(shell.neonUnderhang || 0)
    readonly property int  neonRailCenterOffset:   neonCenterFeature ? -Math.round(neonWindowUnderhang * 0.5) : 0
    readonly property int  neonCenterBodyHeight:   shell.barHeight
    readonly property int  neonSideYOffset:        neonRailCenterOffset
    readonly property int  neonSideModuleHeight:   shell.barHeight

    // Right-group pill colors (system tray + system elements)
    readonly property color rightGroupColor: surface.continuousBarMode
                                            ? (neonContinuousLine
                                                ? neonModuleColor
                                                : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.42))
                                            : surface.panelColor
    readonly property color rightGroupBorderColor: surface.continuousBarMode
                                                  ? (neonContinuousLine
                                                        ? neonModuleBorderColor
                                                        : (organicChrome
                                                            ? Qt.rgba(mocha.overlay1.r, mocha.overlay1.g, mocha.overlay1.b, 0.0)
                                                            : Qt.rgba(mocha.overlay1.r, mocha.overlay1.g, mocha.overlay1.b, 0.70)))
                                                  : themeAccentBorderColor

    // ── Center pill ────────────────────────────────────────────────────────
    CenterBox {
        id: centerBox
        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: shell.isHorizontalBar && shell.edgeAttachedBar ? parent.top : undefined
        anchors.bottom: shell.isHorizontalBar && shell.edgeAttachedBar ? parent.bottom : undefined
        anchors.verticalCenter: shell.edgeAttachedBar && (shell.isTopBar || shell.isBottomBar) ? undefined : parent.verticalCenter
        shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root
    }

    // ── Left side ──────────────────────────────────────────────────────────
    RowLayout {
        id: leftLayout
        anchors.left: parent.left
        anchors.leftMargin: root.edgeInset
        anchors.right: centerBox.left
        anchors.rightMargin: root.centerGap
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: root.moduleSpacing

        property int moduleHeight: root.neonSideModuleHeight

        // Altijd zichtbaar (geen moduleList-check)
        SearchButton        { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // Zichtbaar als "notifications" in de lijst staat → office
        NotificationsButton { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // Zichtbaar als "mail" in de lijst staat → office
        MailButton          { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // Zichtbaar als "workspaces" in de lijst staat → office + gaming
        WorkspacesModule    { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // Zichtbaar zodra een mediaspeler via MPRIS actief is (alle modi, alle schermen)
        MediaPlayerModule   { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        Item { Layout.fillWidth: true }
    }

    // ── Right side ─────────────────────────────────────────────────────────
    RowLayout {
        id: rightLayout
        anchors.right: parent.right
        anchors.rightMargin: root.edgeInset
        anchors.left: centerBox.right
        anchors.leftMargin: root.centerGap
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: root.moduleSpacing

        Item { Layout.fillWidth: true }

        // Altijd zichtbaar wanneer er tray-iconen zijn (geen moduleList-check)
        SystemTrayPill    { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // De grote statuspil rechts. Bevat meerdere sub-pills, elk met hun eigen
        // moduleList-check. Zie SystemElementsPill.qml voor welke string elke
        // sub-pill controleert.
        SystemElementsPill { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root; layoutVisible: true }
    }
}
