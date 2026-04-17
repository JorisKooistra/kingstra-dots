import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import "../"

Item {
    id: window
    width: Screen.width
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }

    function mixColor(a, b, t, alphaValue) {
        let ratio = Math.max(0.0, Math.min(1.0, Number(t)));
        let alpha = Math.max(0.0, Math.min(1.0, Number(alphaValue)));
        return Qt.rgba(
            a.r + (b.r - a.r) * ratio,
            a.g + (b.g - a.g) * ratio,
            a.b + (b.b - a.b) * ratio,
            alpha
        );
    }

    function _srgbChannelToLinear(value) {
        return value <= 0.04045 ? (value / 12.92) : Math.pow((value + 0.055) / 1.055, 2.4);
    }

    function luminance(colorValue) {
        return 0.2126 * _srgbChannelToLinear(colorValue.r)
             + 0.7152 * _srgbChannelToLinear(colorValue.g)
             + 0.0722 * _srgbChannelToLinear(colorValue.b);
    }

    function contrastRatio(a, b) {
        let la = luminance(a);
        let lb = luminance(b);
        let hi = Math.max(la, lb);
        let lo = Math.min(la, lb);
        return (hi + 0.05) / (lo + 0.05);
    }

    function pickReadableColor(bg, candidates, fallback) {
        let best = fallback;
        let bestRatio = -1;
        for (let i = 0; i < candidates.length; i++) {
            let ratio = contrastRatio(bg, candidates[i]);
            if (ratio > bestRatio) {
                bestRatio = ratio;
                best = candidates[i];
            }
        }
        return best;
    }

    property string activeTheme: carouselLoader.item && carouselLoader.item.activeTheme ? carouselLoader.item.activeTheme : ""
    property string selectedThemeId: carouselLoader.item && carouselLoader.item.selectedThemeId ? carouselLoader.item.selectedThemeId : ""
    property var selectedThemeData: carouselLoader.item && carouselLoader.item.selectedThemeData ? carouselLoader.item.selectedThemeData : ({})
    property bool isApplying: carouselLoader.item ? carouselLoader.item.isApplying : false
    property bool isReady: carouselLoader.item ? carouselLoader.item.isReady : true
    readonly property string activeThemeName: String(ThemeConfig.theme || "").toLowerCase()
    readonly property color titleBarColor: {
        let mixed = mixColor(_theme.mantle, _theme.surface0, 0.32, 0.94);
        if (activeThemeName === "ocean") {
            return mixColor(mixed, _theme.surface1, 0.22, 0.95);
        }
        return mixed;
    }
    readonly property color hintBarColor: mixColor(_theme.mantle, _theme.surface0, 0.24, 0.88)
    readonly property color titleTextColor: pickReadableColor(titleBarColor, [
        _theme.text,
        _theme.subtext1,
        _theme.base,
        _theme.crust,
        Qt.rgba(1, 1, 1, 0.97),
        Qt.rgba(0, 0, 0, 0.97)
    ], _theme.text)
    readonly property color titleAccentColor: pickReadableColor(titleBarColor, [
        _theme.blue,
        _theme.sapphire,
        _theme.teal,
        _theme.mauve,
        _theme.yellow,
        titleTextColor
    ], titleTextColor)
    readonly property color hintPrimaryColor: pickReadableColor(hintBarColor, [
        _theme.text,
        _theme.subtext1,
        _theme.base,
        _theme.crust,
        Qt.rgba(1, 1, 1, 0.95),
        Qt.rgba(0, 0, 0, 0.95)
    ], _theme.text)
    readonly property color hintSecondaryColor: pickReadableColor(hintBarColor, [
        _theme.subtext0,
        _theme.subtext1,
        _theme.text,
        _theme.base,
        _theme.crust,
        Qt.rgba(1, 1, 1, 0.8),
        Qt.rgba(0, 0, 0, 0.8)
    ], _theme.subtext0)
    signal themeApplied(string themeId)

    function stepToIndex(delta) {
        if (carouselLoader.item && carouselLoader.item.stepToIndex) {
            carouselLoader.item.stepToIndex(delta);
        }
    }

    function applySelectedTheme() {
        if (carouselLoader.item && carouselLoader.item.applySelectedTheme) {
            carouselLoader.item.applySelectedTheme();
        }
    }

    Keys.onLeftPressed: { stepToIndex(-1); event.accepted = true; }
    Keys.onRightPressed: { stepToIndex(1); event.accepted = true; }
    Keys.onReturnPressed: { applySelectedTheme(); event.accepted = true; }
    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        event.accepted = true;
    }

    Timer {
        id: applyNotifTimer; interval: 800
        onTriggered: {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.35)
    }

    Loader {
        id: carouselLoader
        anchors.fill: parent
        anchors.topMargin: window.s(100)
        anchors.bottomMargin: window.s(90)
        anchors.leftMargin: window.s(32)
        anchors.rightMargin: window.s(32)
        source: Qt.resolvedUrl("ThemeCarousel.qml")

        onLoaded: {
            if (item) {
                item.applyOnItemClick = true;
            }
        }
    }

    Connections {
        target: carouselLoader.item
        ignoreUnknownSignals: true
        function onThemeApplied(themeId) {
            window.themeApplied(themeId);
            applyNotifTimer.start();
        }
    }

    Rectangle {
        visible: carouselLoader.status === Loader.Error
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.8)
        z: 40

        Text {
            anchors.centerIn: parent
            text: "Thema carousel kon niet laden"
            font.family: "JetBrains Mono"
            font.pixelSize: window.s(14)
            color: _theme.text
        }
    }

    // -------------------------------------------------------------------------
    // TITLE BAR
    // -------------------------------------------------------------------------
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.topMargin: window.isReady ? window.s(40) : window.s(-80)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.topMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(48)
        width: titleRow.width + window.s(32)
        radius: window.s(14)
        color: window.titleBarColor
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8)
        border.width: 1

        Row {
            id: titleRow
            anchors.centerIn: parent
            spacing: window.s(10)

            Text {
                text: "󰏘"
                font.pixelSize: window.s(18)
                font.family: "JetBrainsMono Nerd Font"
                color: window.titleAccentColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Thema kiezen"
                font.pixelSize: window.s(14)
                font.bold: true
                color: window.titleTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // -------------------------------------------------------------------------
    // BOTTOM HINT BAR
    // -------------------------------------------------------------------------
    Rectangle {
        id: hintBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.isReady ? window.s(30) : window.s(-60)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(40)
        width: hintRow.width + window.s(28)
        radius: window.s(10)
        color: window.hintBarColor
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.6)
        border.width: 1

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: window.s(16)

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(20); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "←"; font.pixelSize: window.s(10); color: window.hintPrimaryColor; font.bold: true }
                }
                Rectangle {
                    width: window.s(20); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "→"; font.pixelSize: window.s(10); color: window.hintPrimaryColor; font.bold: true }
                }
                Text { text: "Bladeren"; font.pixelSize: window.s(11); color: window.hintSecondaryColor; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.s(20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(44); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Enter"; font.pixelSize: window.s(10); color: window.hintPrimaryColor; font.bold: true }
                }
                Text { text: "Toepassen"; font.pixelSize: window.s(11); color: window.hintSecondaryColor; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.s(20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(32); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: window.s(10); color: window.hintPrimaryColor; font.bold: true }
                }
                Text { text: "Sluiten"; font.pixelSize: window.s(11); color: window.hintSecondaryColor; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // -------------------------------------------------------------------------
    // APPLYING OVERLAY
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.6)
        visible: window.isApplying
        z: 50

        Column {
            anchors.centerIn: parent
            spacing: window.s(12)

            Text {
                text: "󰑓"
                font.pixelSize: window.s(32)
                font.family: "JetBrainsMono Nerd Font"
                color: _theme.blue
                anchors.horizontalCenter: parent.horizontalCenter

                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 1200
                }
            }

            Text {
                text: "Thema wordt toegepast…"
                font.pixelSize: window.s(14)
                color: _theme.text
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
