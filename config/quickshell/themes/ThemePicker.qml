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

    property alias activeTheme: carousel.activeTheme
    property alias selectedThemeId: carousel.selectedThemeId
    property alias selectedThemeData: carousel.selectedThemeData
    property alias isApplying: carousel.isApplying
    property alias isReady: carousel.isReady
    signal themeApplied(string themeId)

    Keys.onLeftPressed: { carousel.stepToIndex(-1); event.accepted = true; }
    Keys.onRightPressed: { carousel.stepToIndex(1); event.accepted = true; }
    Keys.onReturnPressed: { carousel.applySelectedTheme(); event.accepted = true; }
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
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.92)
    }

    ThemeCarousel {
        id: carousel
        anchors.fill: parent
        anchors.topMargin: window.s(100)
        anchors.bottomMargin: window.s(90)
        anchors.leftMargin: window.s(32)
        anchors.rightMargin: window.s(32)
        applyOnItemClick: true
        onThemeApplied: (themeId) => {
            window.themeApplied(themeId);
            applyNotifTimer.start();
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
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.90)
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
                color: _theme.blue
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Thema kiezen"
                font.pixelSize: window.s(14)
                font.bold: true
                color: _theme.text
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
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.85)
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
                    Text { anchors.centerIn: parent; text: "←"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Rectangle {
                    width: window.s(20); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "→"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Bladeren"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.s(20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(44); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Enter"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Toepassen"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.s(20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(32); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Sluiten"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
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
