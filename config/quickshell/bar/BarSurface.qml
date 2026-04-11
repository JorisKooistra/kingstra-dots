import QtQuick
import Quickshell
import ".."
import "effects"
import "skins"

Item {
    id: barSurfaceRoot
    required property var shell
    required property var mocha

    readonly property string activeTheme: String(ThemeConfig.theme || "botanical").toLowerCase()
    readonly property bool isOcean: activeTheme === "ocean"
    readonly property bool isSpace: activeTheme === "space"
    readonly property bool isBotanical: activeTheme === "botanical"
    readonly property bool isRocky: activeTheme === "rocky"
    readonly property bool isAnimated: activeTheme === "animated"
    readonly property string skinSource: {
        if (activeTheme === "rocky") return "skins/RockyBar.qml";
        if (activeTheme === "ocean") return "skins/OceanBar.qml";
        if (activeTheme === "space") return "skins/SpaceBar.qml";
        if (activeTheme === "cyber") return "skins/CyberBar.qml";
        if (activeTheme === "animated") return "skins/AnimatedBar.qml";
        return "skins/BotanicalBar.qml";
    }

    Loader {
        id: barSkin
        source: barSurfaceRoot.skinSource
        visible: false
    }

    readonly property var skin: barSkin.item

    function skinNumber(name, fallbackValue) {
        if (!skin || skin[name] === undefined) return fallbackValue;
        return Number(skin[name]);
    }

    function skinBool(name, fallbackValue) {
        if (!skin || skin[name] === undefined) return fallbackValue;
        return !!skin[name];
    }

    readonly property bool skinContinuousBarMode: barSurfaceRoot.skinBool("continuousBar", false)
                                                && (!barSurfaceRoot.skinBool("continuousBarTopOnly", false) || shell.isTopBar)
    readonly property bool topBarLooseBlocksOverrideActive: shell.isTopBar && ThemeConfig.topBarLooseBlocksOverride >= 0
    readonly property bool topBarLooseBlocksEnabled: ThemeConfig.topBarLooseBlocksOverride === 1
    readonly property bool continuousBarMode: shell.edgeAttachedBar
                                            && (topBarLooseBlocksOverrideActive ? !topBarLooseBlocksEnabled : skinContinuousBarMode)
    readonly property bool isCyberContinuousBar: continuousBarMode && activeTheme === "cyber"
    readonly property bool themeHasDefaultTexture: activeTheme === "botanical"
                                                   || activeTheme === "rocky"
                                                   || activeTheme === "ocean"
                                                   || activeTheme === "space"
    readonly property string configuredTextureOverlaySource: String(shell.textureOverlayAsset || "")
    readonly property string fallbackTextureOverlayPrimary: themeHasDefaultTexture
                                                           ? (Quickshell.env("HOME") + "/kingstra-dots/assets/themes/" + activeTheme + "/texture-overlay.png")
                                                           : ""
    readonly property string fallbackTextureOverlaySecondary: themeHasDefaultTexture
                                                             ? (Quickshell.env("HOME") + "/.config/kingstra-dots/assets/themes/" + activeTheme + "/texture-overlay.png")
                                                             : ""
    property string activeTextureOverlaySource: ""
    readonly property real minTextureOpacity: activeTheme === "rocky" ? 0.14
                                            : (activeTheme === "botanical" ? 0.12 : 0.08)
    readonly property real textureOverlayOpacity: activeTextureOverlaySource !== ""
                                                 ? Math.max(minTextureOpacity, ThemeConfig.materialOverlayOpacity)
                                                 : 0.0

    function resetTextureOverlaySource() {
        if (configuredTextureOverlaySource !== "") {
            activeTextureOverlaySource = configuredTextureOverlaySource;
            return;
        }
        if (fallbackTextureOverlayPrimary !== "") {
            activeTextureOverlaySource = fallbackTextureOverlayPrimary;
            return;
        }
        activeTextureOverlaySource = "";
    }

    onConfiguredTextureOverlaySourceChanged: resetTextureOverlaySource()
    onActiveThemeChanged: resetTextureOverlaySource()
    Component.onCompleted: resetTextureOverlaySource()

    property int panelRadius: shell.s(Math.max(6, ThemeConfig.styleWidgetRadius + skinNumber("cornerRadiusDelta", 0)))
    property int innerPillRadius: shell.s(Math.max(6, ThemeConfig.styleWidgetRadius - 4 + Math.floor(skinNumber("cornerRadiusDelta", 0) / 2)))
    property color basePanelColor: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Math.min(1.0, ThemeConfig.barOpacity + skinNumber("panelOpacityBoost", 0.0)))
    property color basePanelHoverColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, Math.min(0.98, ThemeConfig.barOpacity + 0.12 + ThemeConfig.styleGlassStrength * 0.35 + skinNumber("hoverBoost", 0.0)))
    property color basePanelBorderColor: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05 + ThemeConfig.styleOutlineStrength + ThemeConfig.materialGlowIntensity * 0.5 + skinNumber("borderBoost", 0.0))
    property color basePanelBorderHoverColor: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10 + ThemeConfig.styleOutlineStrength + ThemeConfig.materialGlowIntensity * 0.7 + skinNumber("borderBoost", 0.0))
    property color panelColor: continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelColor
    property color panelHoverColor: continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelHoverColor
    property color panelBorderColor: continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelBorderColor
    property color panelBorderHoverColor: continuousBarMode ? Qt.rgba(0, 0, 0, 0) : basePanelBorderHoverColor
    property color innerPillColor: continuousBarMode
                                  ? (isCyberContinuousBar
                                        ? Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.08)
                                        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.10))
                                  : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, Math.min(0.95, ThemeConfig.popupOpacity * (0.42 + ThemeConfig.styleGlassStrength * 0.5 + skinNumber("innerBoost", 0.0))))
    property color innerPillHoverColor: continuousBarMode
                                       ? (isCyberContinuousBar
                                            ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.22)
                                            : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.18))
                                       : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, Math.min(0.98, ThemeConfig.popupOpacity * (0.58 + ThemeConfig.styleGlassStrength * 0.6 + skinNumber("innerBoost", 0.0))))
    readonly property bool cyberTopWithBulge: isCyberContinuousBar && shell.isTopBar
    readonly property int cyberRailHeight: cyberTopWithBulge
                                           ? shell.barHeight
                                           : barSurfaceRoot.height
    readonly property int continuousRailHeight: continuousBarMode
                                                ? (cyberTopWithBulge ? cyberRailHeight : barSurfaceRoot.height)
                                                : barSurfaceRoot.height

    Item {
        anchors.fill: parent
        opacity: (!shell.barAutoHide || shell.autoHideVisible) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
        transform: Translate {
            x: shell.autoHideOffsetX
            y: shell.autoHideOffsetY
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onEntered: {
                if (shell.barAutoHide) {
                    shell.autoHideVisible = true;
                    shell.autoHideTimer.restart();
                }
            }
            onExited: {
                if (shell.barAutoHide) shell.autoHideTimer.restart();
            }
            onClicked: (mouse) => mouse.accepted = false
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousRailHeight
            visible: barSurfaceRoot.continuousBarMode
            z: 0.25
            radius: 0
            color: barSurfaceRoot.basePanelColor
            border.width: 1
            border.color: barSurfaceRoot.basePanelBorderColor
        }

        Image {
            id: textureOverlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : parent.height
            z: 0.35
            source: barSurfaceRoot.activeTextureOverlaySource
            fillMode: Image.Tile
            opacity: barSurfaceRoot.textureOverlayOpacity
            visible: barSurfaceRoot.textureOverlayOpacity > 0.0 && source !== "" && status !== Image.Error
            smooth: true
            asynchronous: true
            sourceSize.width: Math.max(64, shell.s(240))
            sourceSize.height: Math.max(32, shell.s(100))
            onStatusChanged: {
                if (status !== Image.Error) return;
                if (barSurfaceRoot.activeTextureOverlaySource === barSurfaceRoot.fallbackTextureOverlayPrimary
                        && barSurfaceRoot.fallbackTextureOverlaySecondary !== "") {
                    barSurfaceRoot.activeTextureOverlaySource = barSurfaceRoot.fallbackTextureOverlaySecondary;
                    return;
                }
                if (barSurfaceRoot.configuredTextureOverlaySource !== "") {
                    console.warn("[BarSurface] texture overlay asset missing: " + barSurfaceRoot.configuredTextureOverlaySource);
                }
            }
        }

        ParticleLayer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : parent.height
            shell: barSurfaceRoot.shell
            mocha: barSurfaceRoot.mocha
            fireflyBoost: barSurfaceRoot.isBotanical ? 1.25 : 1.0
            z: 0
        }

        Rectangle {
            visible: barSurfaceRoot.isBotanical && barSurfaceRoot.skinBool("showWarmGlow", false)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : parent.height
            z: 0.1
            opacity: barSurfaceRoot.skinNumber("warmGlowAlpha", 0.04)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 1.0) }
                GradientStop { position: 0.5; color: Qt.rgba(mocha.peach.r, mocha.peach.g, mocha.peach.b, 0.4) }
                GradientStop { position: 1.0; color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.6) }
            }
        }

        Item {
            visible: barSurfaceRoot.isOcean && barSurfaceRoot.skinBool("showWaveShimmer", false)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : parent.height
            clip: true
            z: 0.1

            Rectangle {
                id: oceanWave
                width: parent.width * 2
                height: parent.height
                x: -parent.width
                opacity: barSurfaceRoot.skinNumber("waveShimmerAlpha", 0.055)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.4; color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 1.0) }
                    GradientStop { position: 0.6; color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 1.0) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                SequentialAnimation on x {
                    running: barSurfaceRoot.isOcean
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0
                        duration: barSurfaceRoot.skinNumber("waveCycleMs", 6000)
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: -parent.width
                        duration: barSurfaceRoot.skinNumber("waveCycleMs", 6000)
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        Rectangle {
            visible: barSurfaceRoot.isSpace && barSurfaceRoot.skinBool("showNebulaGlow", false)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : parent.height
            z: 0.1
            opacity: barSurfaceRoot.skinNumber("nebulaAlpha", 0.06)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 1.0) }
                GradientStop { position: 0.5; color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.5) }
                GradientStop { position: 1.0; color: Qt.rgba(mocha.pink.r, mocha.pink.g, mocha.pink.b, 1.0) }
            }
        }

        Rectangle {
            id: rainbowLayer
            visible: barSurfaceRoot.isAnimated && barSurfaceRoot.skinBool("showRainbowShift", false)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : parent.height
            z: 0.1
            property color c1: mocha.mauve
            property color c2: mocha.blue
            opacity: barSurfaceRoot.skinNumber("rainbowAlpha", 0.07)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: rainbowLayer.c1 }
                GradientStop { position: 1.0; color: rainbowLayer.c2 }
            }
            SequentialAnimation {
                running: barSurfaceRoot.isAnimated
                loops: Animation.Infinite
                ColorAnimation { target: rainbowLayer; property: "c1"; to: mocha.pink; duration: barSurfaceRoot.skinNumber("rainbowCycleMs", 8000) / 4 }
                ColorAnimation { target: rainbowLayer; property: "c2"; to: mocha.peach; duration: barSurfaceRoot.skinNumber("rainbowCycleMs", 8000) / 4 }
                ColorAnimation { target: rainbowLayer; property: "c1"; to: mocha.teal; duration: barSurfaceRoot.skinNumber("rainbowCycleMs", 8000) / 4 }
                ColorAnimation { target: rainbowLayer; property: "c2"; to: mocha.green; duration: barSurfaceRoot.skinNumber("rainbowCycleMs", 8000) / 4 }
            }
        }

        Rectangle {
            visible: barSurfaceRoot.isRocky && barSurfaceRoot.skinBool("showBevelHighlight", false)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 2
            z: 0.6
            color: Qt.rgba(1, 1, 1, barSurfaceRoot.skinNumber("bevelLightAlpha", 0.12))
        }

        Rectangle {
            visible: barSurfaceRoot.isRocky && barSurfaceRoot.skinBool("showBevelHighlight", false)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            z: 0.6
            color: Qt.rgba(0, 0, 0, barSurfaceRoot.skinNumber("bevelDarkAlpha", 0.18))
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barSurfaceRoot.continuousBarMode ? barSurfaceRoot.continuousRailHeight : parent.height
            visible: barSurfaceRoot.skinBool("showCyberGrid", false)
            z: 0.5
            clip: true

            Repeater {
                model: Math.ceil(barSurfaceRoot.width / shell.s(13))
                Rectangle {
                    width: 1
                    height: parent.height
                    x: index * shell.s(13)
                    color: Qt.rgba(
                        mocha.blue.r,
                        mocha.blue.g,
                        mocha.blue.b,
                        Math.max(
                            0.0,
                            Math.min(
                                0.60,
                                barSurfaceRoot.skinNumber("gridAlpha", 0.0) * ((index % 3) === 0 ? 0.72 : 0.22)
                            )
                        )
                    )
                }
            }

            Repeater {
                model: Math.ceil(parent.height / shell.s(26))
                Rectangle {
                    width: barSurfaceRoot.width
                    height: 1
                    y: index * shell.s(26)
                    color: Qt.rgba(
                        mocha.teal.r,
                        mocha.teal.g,
                        mocha.teal.b,
                        Math.max(
                            0.0,
                            Math.min(
                                0.44,
                                barSurfaceRoot.skinNumber("gridAlpha", 0.0) * 0.56
                            )
                        )
                    )
                }
            }

            Repeater {
                model: Math.ceil(parent.height / shell.s(6))
                Rectangle {
                    width: barSurfaceRoot.width
                    height: 1
                    y: index * shell.s(6)
                    color: Qt.rgba(
                        mocha.teal.r,
                        mocha.teal.g,
                        mocha.teal.b,
                        Math.max(
                            0.0,
                            Math.min(
                                0.34,
                                barSurfaceRoot.skinNumber("gridAlpha", 0.0) * ((index % 2) === 0 ? 0.52 : 0.30)
                            )
                        )
                    )
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, Math.max(0.0, Math.min(0.34, barSurfaceRoot.skinNumber("gridAlpha", 0.0) * 0.82)))
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: shell.s(2)
                color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, Math.max(0.0, Math.min(0.48, barSurfaceRoot.skinNumber("gridAlpha", 0.0) * 1.3)))
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: shell.s(9)
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, Math.max(0.0, Math.min(0.22, barSurfaceRoot.skinNumber("gridAlpha", 0.0) * 0.95))) }
                }
            }
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            z: 1
            sourceComponent: shell.isVerticalBar ? sidebarContentComponent : horizontalContentComponent
        }

        Component {
            id: horizontalContentComponent
            BarContent {
                shell: barSurfaceRoot.shell
                surface: barSurfaceRoot
                mocha: barSurfaceRoot.mocha
            }
        }

        Component {
            id: sidebarContentComponent
            BarContentSidebar {
                shell: barSurfaceRoot.shell
                surface: barSurfaceRoot
                mocha: barSurfaceRoot.mocha
            }
        }

    }
}
