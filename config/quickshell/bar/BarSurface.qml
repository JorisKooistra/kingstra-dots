import QtQuick
import Quickshell
import ".."
import "effects"
import "skins"

// ── Wat is dit bestand? ───────────────────────────────────────────────────────
// BarSurface is de visuele ondergrond van de bar. Het tekent geen knoppen of
// modules — dat doet BarContent. BarSurface tekent uitsluitend:
//
//   1. De achtergrond-rail (in continuous-mode: één doorgaande balk)
//   2. De textuurlaag (grain/noise overlay per theme)
//   3. De deeltjeslaag (fireflies, sparkles, enz.) via ParticleLayer
//   4. Per-theme sfeereffecten — elk in een eigen bestand in effects/
//   5. De bar-inhoud zelf via een Loader → BarContent of BarContentSidebar
//
// Alle kleuren en radii die modules nodig hebben (panelColor, panelRadius ...)
// worden hier berekend en via `surface: barSurfaceRoot` doorgegeven.
//
// ── Hoe skins werken ─────────────────────────────────────────────────────────
// Een skin (bijv. CyberBar.qml) is een klein QtObject met alleen properties:
//   readonly property bool showCyberGrid: true
//   readonly property real gridAlpha: 0.38
//
// BarSurface laadt de juiste skin via een Loader en leest de waarden op via
// skinBool("showCyberGrid", false) en skinNumber("gridAlpha", 0.0).
// Zo hoeft de rendercode hier niets te weten van welk theme actief is.
//
// ── Effecten (effects/) ───────────────────────────────────────────────────────
// Elk sfeereffect staat in een eigen bestand. Ze ontvangen allemaal:
//   shell   — voor shell.s() schaling
//   mocha   — kleurenpalet
//   surface — barSurfaceRoot (heeft skinBool/skinNumber/continuousBarMode/...)
//
//   BotanicalGlow.qml  — warme geel-perzik-groen gloed
//   OceanWave.qml      — teal-blauw golf die heen en weer schuift
//   SpaceNebula.qml    — mauve-blauw-roze nevelgloed
//   AnimatedRainbow.qml — regenboogverschuiving + aurora-sweep
//   RockyBevel.qml     — licht/donker randlijnen (gebeiteld effect)
//   CyberGrid.qml      — raster met sweep-licht
//   ParticleLayer.qml  — bewegende deeltjes (fireflies, space-specks)
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: barSurfaceRoot
    required property var shell
    required property var mocha

    // ── Actief theme & skin ───────────────────────────────────────────────────
    readonly property string activeTheme: String(ThemeConfig.theme || "botanical").toLowerCase()
    readonly property bool isOcean:     activeTheme === "ocean"
    readonly property bool isSpace:     activeTheme === "space"
    readonly property bool isBotanical: activeTheme === "botanical"
    readonly property bool isRocky:     activeTheme === "rocky"
    readonly property bool isAnimated:  activeTheme === "animated"
    readonly property string activeBarTemplate: String(ThemeConfig.effectiveBarTemplate || "horizontal").toLowerCase()
    readonly property bool useSidebarTemplate: activeBarTemplate === "sidebar"
                                             || activeBarTemplate === "compact-sidebar"

    // Delayed version used by the Loader. When switching from sidebar → horizontal
    // the Wayland compositor resizes the surface asynchronously. Switching the
    // Loader immediately would create BarContent in the old narrow (~62px) surface,
    // causing items to lay out with no space. A 350ms delay lets the compositor
    // finish the resize before BarContent is instantiated.
    property bool _loaderUseSidebar: useSidebarTemplate
    onUseSidebarTemplateChanged: _sidebarSwitchTimer.restart()
    Timer {
        id: _sidebarSwitchTimer
        interval: 350
        onTriggered: barSurfaceRoot._loaderUseSidebar = barSurfaceRoot.useSidebarTemplate
    }

    readonly property string skinSource: {
        if (activeTheme === "rocky")    return "skins/RockyBar.qml";
        if (activeTheme === "ocean")    return "skins/OceanBar.qml";
        if (activeTheme === "space")    return "skins/SpaceBar.qml";
        if (activeTheme === "cyber")    return "skins/CyberBar.qml";
        if (activeTheme === "animated") return "skins/AnimatedBar.qml";
        return "skins/BotanicalBar.qml";
    }

    Loader { id: barSkin; source: barSurfaceRoot.skinSource; visible: false }
    readonly property var skin: barSkin.item

    function skinNumber(name, fallbackValue) {
        if (!skin || skin[name] === undefined) return fallbackValue;
        return Number(skin[name]);
    }
    function skinBool(name, fallbackValue) {
        if (!skin || skin[name] === undefined) return fallbackValue;
        return !!skin[name];
    }
    function effectAlpha(baseValue) {
        return Math.max(0.0, Math.min(1.0, Number(baseValue) * ThemeConfig.effectIntensity));
    }
    function effectCycleMs(fallbackValue) {
        return ThemeConfig.effectCycleMs > 0 ? ThemeConfig.effectCycleMs : fallbackValue;
    }
    function ambientEnabled(effectName, themeName) {
        let configured = String(ThemeConfig.ambientEffect || "theme-default").toLowerCase();
        if (configured === "none") return false;
        if (configured === "theme-default") return activeTheme === themeName;
        return configured === effectName;
    }


    // ── Bar-modus: losse blokken vs. doorgaande rail ──────────────────────────
    readonly property bool skinContinuousBarMode: barSurfaceRoot.skinBool("continuousBar", false)
                                                && (!barSurfaceRoot.skinBool("continuousBarTopOnly", false) || shell.isTopBar)
    readonly property bool topBarLooseBlocksOverrideActive: shell.isTopBar && ThemeConfig.topBarLooseBlocksOverride >= 0
    readonly property bool topBarLooseBlocksEnabled: ThemeConfig.topBarLooseBlocksOverride === 1
    readonly property bool continuousBarMode: shell.edgeAttachedBar
                                            && (topBarLooseBlocksOverrideActive ? !topBarLooseBlocksEnabled : skinContinuousBarMode)
    readonly property bool isCyberContinuousBar: continuousBarMode && activeTheme === "cyber"

    readonly property bool cyberTopWithBulge:    isCyberContinuousBar && shell.isTopBar
    readonly property int  particleOverflow:     shell.isHorizontalBar ? (shell.particleVisualOverflow || 0) : 0
    readonly property int  visualContentY:       shell.isBottomBar ? particleOverflow : 0
    readonly property int  visualContentHeight:  Math.max(1, barSurfaceRoot.height - particleOverflow)
    readonly property int  cyberRailHeight:      cyberTopWithBulge ? shell.barHeight : barSurfaceRoot.height
    readonly property int  continuousRailHeight: continuousBarMode
                                                 ? (cyberTopWithBulge ? cyberRailHeight : visualContentHeight)
                                                 : visualContentHeight

    // ── Textuuroverlay ────────────────────────────────────────────────────────
    readonly property bool   themeHasDefaultTexture: activeTheme === "botanical" || activeTheme === "rocky"
                                                      || activeTheme === "ocean"  || activeTheme === "space"
    readonly property string configuredTextureOverlaySource: String(shell.textureOverlayAsset || "")
    readonly property string fallbackTextureOverlayPrimary:  themeHasDefaultTexture
                                                             ? (Quickshell.env("HOME") + "/kingstra-dots/assets/themes/" + activeTheme + "/texture-overlay.png")
                                                             : ""
    readonly property string fallbackTextureOverlaySecondary: themeHasDefaultTexture
                                                              ? (Quickshell.env("HOME") + "/.config/kingstra-dots/assets/themes/" + activeTheme + "/texture-overlay.png")
                                                              : ""
    property string activeTextureOverlaySource: ""
    readonly property real minTextureOpacity: activeTheme === "rocky" ? 0.14 : (activeTheme === "botanical" ? 0.12 : 0.08)
    readonly property real textureOverlayOpacity: activeTextureOverlaySource !== ""
                                                 ? Math.max(minTextureOpacity, ThemeConfig.materialOverlayOpacity)
                                                 : 0.0

    function resetTextureOverlaySource() {
        if (configuredTextureOverlaySource !== "") { activeTextureOverlaySource = configuredTextureOverlaySource; return; }
        if (fallbackTextureOverlayPrimary  !== "") { activeTextureOverlaySource = fallbackTextureOverlayPrimary;  return; }
        activeTextureOverlaySource = "";
    }
    onConfiguredTextureOverlaySourceChanged: resetTextureOverlaySource()
    onActiveThemeChanged:                    resetTextureOverlaySource()
    Component.onCompleted: { resetTextureOverlaySource(); }

    // ── Gedeelde kleur- en radiuseigenschappen ────────────────────────────────
    // Worden via `surface: barSurfaceRoot` doorgegeven aan alle modules.
    property int   panelRadius:               shell.s(Math.max(6, ThemeConfig.styleWidgetRadius + skinNumber("cornerRadiusDelta", 0)))
    property int   innerPillRadius:           shell.s(Math.max(6, ThemeConfig.styleWidgetRadius - 4 + Math.floor(skinNumber("cornerRadiusDelta", 0) / 2)))
    property color basePanelColor:            Qt.rgba(mocha.base.r,     mocha.base.g,     mocha.base.b,     Math.min(1.0,  ThemeConfig.barOpacity + skinNumber("panelOpacityBoost", 0.0)))
    property color basePanelHoverColor:       Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, Math.min(0.98, ThemeConfig.barOpacity + 0.12 + ThemeConfig.styleGlassStrength * 0.35 + skinNumber("hoverBoost", 0.0)))
    property color basePanelBorderColor:      Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05 + ThemeConfig.styleOutlineStrength + ThemeConfig.materialGlowIntensity * 0.5 + skinNumber("borderBoost", 0.0))
    property color basePanelBorderHoverColor: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10 + ThemeConfig.styleOutlineStrength + ThemeConfig.materialGlowIntensity * 0.7 + skinNumber("borderBoost", 0.0))
    property color panelColor:            continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelColor
    property color panelHoverColor:       continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelHoverColor
    property color panelBorderColor:      continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelBorderColor
    property color panelBorderHoverColor: continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelBorderHoverColor
    property color innerPillColor: continuousBarMode
                                  ? (isCyberContinuousBar
                                        ? Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.08)
                                        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.10))
                                  : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, Math.min(0.95, ThemeConfig.popupOpacity * (0.42 + ThemeConfig.styleGlassStrength * 0.5 + skinNumber("innerBoost", 0.0))))
    property color innerPillHoverColor: continuousBarMode
                                       ? (isCyberContinuousBar
                                            ? Qt.rgba(mocha.blue.r,     mocha.blue.g,     mocha.blue.b,     0.22)
                                            : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.18))
                                       : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, Math.min(0.98, ThemeConfig.popupOpacity * (0.58 + ThemeConfig.styleGlassStrength * 0.6 + skinNumber("innerBoost", 0.0))))

    // ─────────────────────────────────────────────────────────────────────────
    // Visuele lagen — z-volgorde (laag = verder naar achteren):
    //
    //   z=0.00  ParticleLayer      effects/ParticleLayer.qml
    //   z=0.10  Sfeereffecten      effects/Botanical|Ocean|Space|AnimatedRainbow
    //   z=0.25  Continuous rail    inline Rectangle
    //   z=0.35  Textuuroverlay     inline Image
    //   z=0.50  CyberGrid          effects/CyberGrid.qml
    //   z=0.60  RockyBevel         effects/RockyBevel.qml
    //   z=1.00  BarContent         via Loader
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: (!shell.barAutoHide || shell.autoHideVisible) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(300); easing.type: Easing.InOutSine } }
        transform: Translate {
            x: shell.autoHideOffsetX; y: shell.autoHideOffsetY
            Behavior on x { NumberAnimation { duration: ThemeConfig.duration(300); easing.type: Easing.InOutSine } }
            Behavior on y { NumberAnimation { duration: ThemeConfig.duration(300); easing.type: Easing.InOutSine } }
        }

        MouseArea {
            anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true
            onEntered: { if (shell.barAutoHide) { shell.autoHideVisible = true; shell.autoHideTimer.restart(); } }
            onExited:  { if (shell.barAutoHide) shell.autoHideTimer.restart(); }
            onClicked: (mouse) => mouse.accepted = false
        }

        // z=0.25 — doorgaande achtergrond-rail (alleen in continuous-mode)
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.topMargin: barSurfaceRoot.visualContentY
            height: barSurfaceRoot.continuousRailHeight
            visible: barSurfaceRoot.continuousBarMode
            z: 0.25; radius: 0
            color: barSurfaceRoot.basePanelColor
            border.width: 1; border.color: barSurfaceRoot.basePanelBorderColor
        }

        Rectangle {
            visible: ThemeConfig.railAccent === "edge-line"
            anchors.left: parent.left; anchors.right: parent.right
            y: barSurfaceRoot.visualContentY + barSurfaceRoot.visualContentHeight - height
            height: shell.s(2)
            z: 0.48
            color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, barSurfaceRoot.effectAlpha(0.38))
        }

        Repeater {
            model: ThemeConfig.railAccent === "segmented" ? Math.ceil(parent.width / shell.s(44)) : 0
            Rectangle {
                x: index * shell.s(44)
                y: barSurfaceRoot.visualContentY + barSurfaceRoot.visualContentHeight - height
                width: shell.s(18)
                height: shell.s(2)
                z: 0.48
                color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, barSurfaceRoot.effectAlpha(0.38))
            }
        }

        // z=0.35 — textuuroverlay (herhalende PNG)
        Image {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.topMargin: barSurfaceRoot.visualContentY
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : barSurfaceRoot.visualContentHeight
            z: 0.35
            source: barSurfaceRoot.activeTextureOverlaySource
            fillMode: Image.Tile
            opacity: barSurfaceRoot.textureOverlayOpacity
            visible: barSurfaceRoot.textureOverlayOpacity > 0.0 && source !== "" && status !== Image.Error
            smooth: true; asynchronous: true
            sourceSize.width: Math.max(64, shell.s(240)); sourceSize.height: Math.max(32, shell.s(100))
            onStatusChanged: {
                if (status !== Image.Error) return;
                if (barSurfaceRoot.activeTextureOverlaySource === barSurfaceRoot.fallbackTextureOverlayPrimary
                        && barSurfaceRoot.fallbackTextureOverlaySecondary !== "") {
                    barSurfaceRoot.activeTextureOverlaySource = barSurfaceRoot.fallbackTextureOverlaySecondary;
                    return;
                }
                if (barSurfaceRoot.configuredTextureOverlaySource !== "")
                    console.warn("[BarSurface] texture overlay asset missing: " + barSurfaceRoot.configuredTextureOverlaySource);
            }
        }

        // z=0.00 — deeltjeslaag
        ParticleLayer {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: barSurfaceRoot.visualContentHeight + barSurfaceRoot.particleOverflow
            trackY: barSurfaceRoot.visualContentY
            trackHeight: barSurfaceRoot.visualContentHeight
            shell: barSurfaceRoot.shell; mocha: barSurfaceRoot.mocha
            fireflyBoost: barSurfaceRoot.isBotanical ? 1.25 : 1.0
            z: 0.42
        }

        // z=0.10 — Botanical: warme geel-perzik-groen gloed
        BotanicalGlow   { shell: barSurfaceRoot.shell; mocha: barSurfaceRoot.mocha; surface: barSurfaceRoot }

        // z=0.10 — Ocean: teal-blauw golf
        OceanWave       { shell: barSurfaceRoot.shell; mocha: barSurfaceRoot.mocha; surface: barSurfaceRoot }

        // z=0.10 — Space: mauve-blauw-roze nevelgloed
        SpaceNebula     { shell: barSurfaceRoot.shell; mocha: barSurfaceRoot.mocha; surface: barSurfaceRoot }

        // z=0.10/0.12 — Animated: regenboogverschuiving + aurora-sweep
        AnimatedRainbow { shell: barSurfaceRoot.shell; mocha: barSurfaceRoot.mocha; surface: barSurfaceRoot }

        // z=0.50 — Cyber: rasteroverlay met sweep-licht
        CyberGrid       { shell: barSurfaceRoot.shell; mocha: barSurfaceRoot.mocha; surface: barSurfaceRoot }

        // z=0.60 — Rocky: gebeitelde randlijnen
        RockyBevel      { shell: barSurfaceRoot.shell; mocha: barSurfaceRoot.mocha; surface: barSurfaceRoot }

        // z=1.00 — bar-inhoud (modules, knoppen, klok)
        Loader {
            id: contentLoader
            anchors.fill: parent
            anchors.topMargin: shell.isBottomBar ? barSurfaceRoot.particleOverflow : 0
            anchors.bottomMargin: shell.isTopBar ? barSurfaceRoot.particleOverflow : 0
            z: 1
            sourceComponent: barSurfaceRoot._loaderUseSidebar ? sidebarContentComponent : horizontalContentComponent
        }
        Component {
            id: horizontalContentComponent
            BarContent { shell: barSurfaceRoot.shell; surface: barSurfaceRoot; mocha: barSurfaceRoot.mocha }
        }
        Component {
            id: sidebarContentComponent
            BarContentSidebar { shell: barSurfaceRoot.shell; surface: barSurfaceRoot; mocha: barSurfaceRoot.mocha }
        }
    }
}
