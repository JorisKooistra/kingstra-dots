import QtQuick
import QtQuick.Layouts
import Quickshell
import "modules"

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
//   office  → workspaces · clock · updates · cpu_temp · network · bluetooth · volume · notifications · battery
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
                                                     && String(shell.activeThemeName || "").toLowerCase() === "botanical"
    readonly property int panelTopLeftRadius:     flattenScreenEdgeCorners && (shell.isTopBar || shell.isLeftBar)   ? 0 : surface.panelRadius
    readonly property int panelTopRightRadius:    flattenScreenEdgeCorners && (shell.isTopBar || shell.isRightBar)  ? 0 : surface.panelRadius
    readonly property int panelBottomLeftRadius:  flattenScreenEdgeCorners && (shell.isBottomBar || shell.isLeftBar)  ? 0 : surface.panelRadius
    readonly property int panelBottomRightRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isRightBar) ? 0 : surface.panelRadius

    readonly property bool cyberContinuousLine: surface.continuousBarMode
                                               && String(shell.activeThemeName || "").toLowerCase() === "cyber"
    readonly property bool cyberCenterFeature: String(shell.activeThemeName || "").toLowerCase() === "cyber"
                                             && shell.isTopBar
    readonly property bool cyberChrome:     String(shell.activeThemeName || "").toLowerCase() === "cyber"
    readonly property bool oceanChrome:     String(shell.activeThemeName || "").toLowerCase() === "ocean"
    readonly property bool spaceChrome:     String(shell.activeThemeName || "").toLowerCase() === "space"
    readonly property bool botanicalChrome: String(shell.activeThemeName || "").toLowerCase() === "botanical"
    readonly property bool rockyChrome:     String(shell.activeThemeName || "").toLowerCase() === "rocky"
    readonly property bool animatedChrome:  String(shell.activeThemeName || "").toLowerCase() === "animated"

    readonly property color themeAccentBorderColor:
        oceanChrome     ? Qt.rgba(mocha.teal.r,  mocha.teal.g,  mocha.teal.b,  0.28) :
        spaceChrome     ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.28) :
        botanicalChrome ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.24) :
        rockyChrome     ? Qt.rgba(mocha.text.r,  mocha.text.g,  mocha.text.b,  0.30) :
        animatedChrome  ? Qt.rgba(mocha.pink.r,  mocha.pink.g,  mocha.pink.b,  0.28) :
                          surface.panelBorderColor
    readonly property color themeAccentBorderHoverColor: Qt.rgba(
        themeAccentBorderColor.r,
        themeAccentBorderColor.g,
        themeAccentBorderColor.b,
        Math.min(0.9, themeAccentBorderColor.a + 0.18)
    )

    // Cyber center colors
    readonly property color cyberCenterColor:            Qt.rgba(mocha.crust.r,   mocha.crust.g,   mocha.crust.b,   0.44)
    readonly property color cyberCenterHoverColor:       Qt.rgba(mocha.base.r,    mocha.base.g,    mocha.base.b,    0.56)
    readonly property color cyberCenterBorderColor:      Qt.rgba(mocha.blue.r,    mocha.blue.g,    mocha.blue.b,    0.88)
    readonly property color cyberCenterBorderHoverColor: Qt.rgba(mocha.teal.r,    mocha.teal.g,    mocha.teal.b,    0.94)
    readonly property color cyberCenterInnerLineColor:   Qt.rgba(mocha.teal.r,    mocha.teal.g,    mocha.teal.b,    0.30)
    readonly property color cyberCenterAccentColor:      Qt.rgba(mocha.blue.r,    mocha.blue.g,    mocha.blue.b,    0.82)
    readonly property color cyberCenterDividerColor:     Qt.rgba(mocha.teal.r,    mocha.teal.g,    mocha.teal.b,    0.62)

    // Cyber weather colors
    readonly property color cyberWeatherTempOnColor:  Qt.lighter(mocha.yellow, 1.06)
    readonly property color cyberWeatherTempOffColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.14)

    // Cyber module (pill) colors — used by every status pill
    readonly property color cyberModuleColor:            Qt.rgba(mocha.crust.r,   mocha.crust.g,   mocha.crust.b,   0.42)
    readonly property color cyberModuleHoverColor:       Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
    readonly property color cyberModuleBorderColor:      Qt.rgba(mocha.teal.r,    mocha.teal.g,    mocha.teal.b,    0.92)
    readonly property color cyberModuleBorderHoverColor: Qt.rgba(mocha.blue.r,    mocha.blue.g,    mocha.blue.b,    1.0)
    readonly property color cyberModuleTickColor:        Qt.rgba(mocha.teal.r,    mocha.teal.g,    mocha.teal.b,    1.0)

    // Cyber text colors
    readonly property color cyberTextColor:      Qt.rgba(mocha.text.r,   mocha.text.g,   mocha.text.b,   0.98)
    readonly property color cyberTextMutedColor: Qt.rgba(mocha.text.r,   mocha.text.g,   mocha.text.b,   0.84)
    readonly property color cyberTextHotColor:   Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 1.0)

    // Cyber workspace colors
    readonly property color cyberWorkspaceActiveColor:   Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.88)
    readonly property color cyberWorkspaceOccupiedColor: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.18)

    // Cyber center geometry
    readonly property real cyberCenterScale:        cyberCenterFeature ? 1.6 : 1.0
    readonly property int  cyberWindowUnderhang:    Number(shell.cyberUnderhang || 0)
    readonly property int  cyberRailCenterOffset:   cyberCenterFeature ? -Math.round(cyberWindowUnderhang * 0.5) : 0
    readonly property int  cyberCenterBodyHeight:   shell.barHeight
    readonly property int  cyberSideYOffset:        cyberRailCenterOffset
    readonly property int  cyberSideModuleHeight:   shell.barHeight

    // Right-group pill colors (system tray + system elements)
    readonly property color rightGroupColor: surface.continuousBarMode
                                            ? (cyberContinuousLine
                                                ? cyberModuleColor
                                                : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.42))
                                            : surface.panelColor
    readonly property color rightGroupBorderColor: surface.continuousBarMode
                                                  ? (cyberContinuousLine
                                                        ? cyberModuleBorderColor
                                                        : Qt.rgba(mocha.overlay1.r, mocha.overlay1.g, mocha.overlay1.b, 0.70))
                                                  : themeAccentBorderColor

    // ── Center pill ────────────────────────────────────────────────────────
    CenterBox {
        id: centerBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: shell.isTopBar && shell.edgeAttachedBar ? parent.top : undefined
        anchors.bottom: shell.isBottomBar && shell.edgeAttachedBar ? parent.bottom : undefined
        anchors.verticalCenter: shell.edgeAttachedBar && (shell.isTopBar || shell.isBottomBar) ? undefined : parent.verticalCenter
        shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root
    }

    // ── Left side ──────────────────────────────────────────────────────────
    RowLayout {
        id: leftLayout
        anchors.left: parent.left
        anchors.leftMargin: root.edgeInset
        anchors.right: centerBox.left
        anchors.rightMargin: shell.s(12)
        anchors.top: shell.isTopBar && shell.edgeAttachedBar ? parent.top : undefined
        anchors.bottom: shell.isBottomBar && shell.edgeAttachedBar ? parent.bottom : undefined
        anchors.verticalCenter: shell.edgeAttachedBar && (shell.isTopBar || shell.isBottomBar) ? undefined : parent.verticalCenter
        anchors.verticalCenterOffset: shell.edgeAttachedBar && (shell.isTopBar || shell.isBottomBar) ? 0 : root.cyberSideYOffset
        spacing: shell.s(4)

        property int moduleHeight: root.cyberSideModuleHeight

        // Staggered left slide-in
        property bool showLayout: false
        opacity: showLayout ? 1 : 0
        transform: Translate {
            x: leftLayout.showLayout ? 0 : shell.s(-30)
            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }
        Timer { running: shell.isStartupReady; interval: 10; onTriggered: leftLayout.showLayout = true }
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        // Altijd zichtbaar (geen moduleList-check)
        SearchButton        { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // Zichtbaar als "notifications" in de lijst staat → office
        NotificationsButton { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // Zichtbaar als "workspaces" in de lijst staat → office + gaming
        WorkspacesModule    { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // Zichtbaar als "media_controls" in de lijst staat én er muziek speelt → media
        MediaPlayerModule   { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        Item { Layout.fillWidth: true }
    }

    // ── Right side ─────────────────────────────────────────────────────────
    RowLayout {
        id: rightLayout
        anchors.right: parent.right
        anchors.rightMargin: root.edgeInset
        anchors.left: centerBox.right
        anchors.leftMargin: shell.s(12)
        anchors.top: shell.isTopBar && shell.edgeAttachedBar ? parent.top : undefined
        anchors.bottom: shell.isBottomBar && shell.edgeAttachedBar ? parent.bottom : undefined
        anchors.verticalCenter: shell.edgeAttachedBar && (shell.isTopBar || shell.isBottomBar) ? undefined : parent.verticalCenter
        anchors.verticalCenterOffset: shell.edgeAttachedBar && (shell.isTopBar || shell.isBottomBar) ? 0 : root.cyberSideYOffset
        spacing: shell.s(4)

        // Staggered right slide-in
        property bool showLayout: false
        opacity: showLayout ? 1 : 0
        transform: Translate {
            x: rightLayout.showLayout ? 0 : shell.s(30)
            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }
        Timer { running: shell.isStartupReady && shell.isDataReady; interval: 250; onTriggered: rightLayout.showLayout = true }
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Item { Layout.fillWidth: true }

        // Altijd zichtbaar wanneer er tray-iconen zijn (geen moduleList-check)
        SystemTrayPill    { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root }

        // De grote statuspil rechts. Bevat meerdere sub-pills, elk met hun eigen
        // moduleList-check. Zie SystemElementsPill.qml voor welke string elke
        // sub-pill controleert.
        SystemElementsPill { shell: root.shell; surface: root.surface; mocha: root.mocha; ctx: root; layoutVisible: rightLayout.showLayout }
    }
}
