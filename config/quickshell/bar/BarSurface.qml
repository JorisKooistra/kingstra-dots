import QtQuick
import Quickshell
import ".."
import "ornaments"
import "effects"
import "skins"

Item {
    id: barSurfaceRoot
    required property var shell
    required property var mocha

    readonly property string activeTheme: String(ThemeConfig.theme || "botanical").toLowerCase()
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
                                        ? Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.0)
                                        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.10))
                                  : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, Math.min(0.95, ThemeConfig.popupOpacity * (0.42 + ThemeConfig.styleGlassStrength * 0.5 + skinNumber("innerBoost", 0.0))))
    property color innerPillHoverColor: continuousBarMode
                                       ? (isCyberContinuousBar
                                            ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.14)
                                            : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.18))
                                       : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, Math.min(0.98, ThemeConfig.popupOpacity * (0.58 + ThemeConfig.styleGlassStrength * 0.6 + skinNumber("innerBoost", 0.0))))

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
            anchors.fill: parent
            visible: barSurfaceRoot.continuousBarMode
            z: 0.25
            radius: 0
            color: barSurfaceRoot.basePanelColor
            border.width: 1
            border.color: barSurfaceRoot.basePanelBorderColor
        }

        Image {
            id: textureOverlay
            anchors.fill: parent
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
            anchors.fill: parent
            shell: barSurfaceRoot.shell
            mocha: barSurfaceRoot.mocha
            z: 0
        }

        Item {
            anchors.fill: parent
            visible: barSurfaceRoot.skinBool("showCyberGrid", false)
            z: 0.5

            Repeater {
                model: Math.ceil(barSurfaceRoot.width / shell.s(48))
                Rectangle {
                    width: 1
                    height: barSurfaceRoot.height
                    x: index * shell.s(48)
                    color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, Math.max(0.0, Math.min(0.6, barSurfaceRoot.skinNumber("gridAlpha", 0.0))))
                }
            }

            Repeater {
                model: Math.ceil(barSurfaceRoot.height / shell.s(22))
                Rectangle {
                    width: barSurfaceRoot.width
                    height: 1
                    y: index * shell.s(22)
                    color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, Math.max(0.0, Math.min(0.4, barSurfaceRoot.skinNumber("gridAlpha", 0.0) * 0.7)))
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

        OrnamentLayer {
            anchors.fill: parent
            shell: barSurfaceRoot.shell
            mocha: barSurfaceRoot.mocha
            z: 0.8
        }
    }
}
