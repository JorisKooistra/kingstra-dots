import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    anchors.fill: parent
    clip: true
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }
    function sf(val, minimumPx) { return Math.max(minimumPx, scaler.s(val)); }

    MatugenColors { id: _theme }

    property var modeModel: [
        { id: "office", icon: "\uf0b1", label: "Office", desc: "Werk & productiviteit" },
        { id: "gaming", icon: "\uf11b", label: "Gaming", desc: "Prestaties & hardware" },
        { id: "media", icon: "\uf001", label: "Media", desc: "Muziek & video" }
    ]
    property string activeMode: "office"
    property int selectedIndex: 0
    property bool isApplying: false
    property bool isReady: false
    property real cardSpacing: s(24)
    property real contentMaxWidth: Math.max(0, width - s(48))
    property real cardWidth: {
        if (modeModel.length <= 0) return s(180);
        const totalSpacing = cardSpacing * (modeModel.length - 1);
        const fittedWidth = (contentMaxWidth - totalSpacing) / modeModel.length;
        return Math.max(s(132), Math.min(s(200), fittedWidth));
    }
    property real cardHeight: Math.max(s(180), Math.min(s(250), height - s(170)))

    function indexForMode(modeId) {
        for (let i = 0; i < modeModel.length; ++i) {
            if (modeModel[i].id === modeId) return i;
        }
        return 0;
    }

    function syncSelectionToActiveMode() {
        selectedIndex = indexForMode(activeMode);
    }

    function stepSelection(delta) {
        if (isApplying || modeModel.length === 0) return;
        const count = modeModel.length;
        selectedIndex = (selectedIndex + delta + count) % count;
    }

    function applySelectedMode() {
        if (modeModel.length === 0) return;
        applyMode(modeModel[selectedIndex].id);
    }

    Process {
        id: modeReader
        command: ["bash", "-c",
            "jq -r '.name // \"office\"' \"${HOME}/.config/kingstra/state/mode.json\" 2>/dev/null || echo office"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = this.text.trim();
                if (m !== "") window.activeMode = m;
                window.syncSelectionToActiveMode();
                window.isReady = true;
            }
        }
    }

    Component.onCompleted: {
        modeReader.running = true;
        window.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.35)
    }

    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.topMargin: window.isReady ? window.s(40) : window.s(-80)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.topMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.sf(58, 58)
        width: titleRow.width + window.sf(40, 40)
        radius: window.s(14)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.90)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8)
        border.width: 1

        Row {
            id: titleRow
            anchors.centerIn: parent
            spacing: window.s(10)

            Text {
                text: "\uf085"
                font.pixelSize: window.sf(20, 20)
                font.family: "Iosevka Nerd Font"
                color: _theme.blue
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Mode kiezen"
                font.pixelSize: window.sf(18, 18)
                font.bold: true
                color: _theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Row {
        id: modeRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: window.s(-10)
        spacing: window.cardSpacing
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        Repeater {
            model: window.modeModel

            delegate: Rectangle {
                required property var modelData
                required property int index

                property bool isActive: window.activeMode === modelData.id
                property bool isSelected: window.selectedIndex === index

                width: window.cardWidth
                height: window.cardHeight
                radius: window.s(18)

                color: (isActive || isSelected)
                    ? Qt.rgba(_theme.blue.r, _theme.blue.g, _theme.blue.b, 0.18)
                    : Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.75)

                border.color: isSelected
                    ? Qt.rgba(_theme.lavender.r, _theme.lavender.g, _theme.lavender.b, 0.95)
                    : isActive
                        ? Qt.rgba(_theme.blue.r, _theme.blue.g, _theme.blue.b, 0.8)
                        : Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.4)
                border.width: (isActive || isSelected) ? 2 : 1

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                scale: hoverArea.containsMouse ? 1.04 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Column {
                    anchors.centerIn: parent
                    spacing: window.s(12)
                    width: parent.width - window.s(28)

                    Text {
                        text: modelData.icon
                        font.pixelSize: window.sf(46, 42)
                        font.family: "Iosevka Nerd Font"
                        color: (isActive || isSelected) ? _theme.blue : _theme.subtext1
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        text: modelData.label
                        font.pixelSize: window.sf(18, 18)
                        font.bold: true
                        color: (isActive || isSelected) ? _theme.text : _theme.subtext0
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        text: modelData.desc
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: window.sf(13, 13)
                        color: Qt.rgba(_theme.subtext0.r, _theme.subtext0.g, _theme.subtext0.b, 0.7)
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: window.selectedIndex = index
                    onClicked: {
                        window.selectedIndex = index;
                        window.applyMode(modelData.id);
                    }
                }
            }
        }
    }

    Rectangle {
        id: hintBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.isReady ? window.s(30) : window.s(-60)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.sf(52, 52)
        width: hintRow.width + window.sf(36, 36)
        radius: window.sf(12, 12)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.85)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.6)
        border.width: 1

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: window.s(16)

            Row {
                spacing: window.sf(6, 6)
                Rectangle {
                    width: window.sf(26, 26); height: window.sf(26, 26); radius: window.sf(6, 6)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "←"; font.pixelSize: window.sf(13, 13); color: _theme.text; font.bold: true }
                }
                Rectangle {
                    width: window.sf(26, 26); height: window.sf(26, 26); radius: window.sf(6, 6)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "→"; font.pixelSize: window.sf(13, 13); color: _theme.text; font.bold: true }
                }
                Text { text: "Bladeren"; font.pixelSize: window.sf(13, 13); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.sf(24, 24); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.sf(6, 6)
                Rectangle {
                    width: window.sf(54, 54); height: window.sf(26, 26); radius: window.sf(6, 6)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Enter"; font.pixelSize: window.sf(12, 12); color: _theme.text; font.bold: true }
                }
                Text { text: "Toepassen"; font.pixelSize: window.sf(13, 13); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.sf(24, 24); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.sf(6, 6)
                Rectangle {
                    width: window.sf(42, 42); height: window.sf(26, 26); radius: window.sf(6, 6)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: window.sf(12, 12); color: _theme.text; font.bold: true }
                }
                Text { text: "Sluiten"; font.pixelSize: window.sf(13, 13); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.6)
        visible: window.isApplying
        z: 50

        Column {
            anchors.centerIn: parent
            spacing: window.s(12)

            Text {
                text: "\uf110"
                font.pixelSize: window.sf(34, 30)
                font.family: "Iosevka Nerd Font"
                color: _theme.blue
                anchors.horizontalCenter: parent.horizontalCenter

                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 1200
                }
            }

            Text {
                text: "Mode wordt toegepast…"
                font.pixelSize: window.sf(16, 16)
                color: _theme.text
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Keys.onLeftPressed: {
        window.stepSelection(-1);
        event.accepted = true;
    }

    Keys.onRightPressed: {
        window.stepSelection(1);
        event.accepted = true;
    }

    Keys.onReturnPressed: {
        window.applySelectedMode();
        event.accepted = true;
    }

    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        event.accepted = true;
    }

    Timer {
        id: closeTimer
        interval: 600
        onTriggered: {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        }
    }

    function applyMode(modeId) {
        if (window.isApplying) return;
        window.isApplying = true;
        window.activeMode = modeId;
        window.syncSelectionToActiveMode();

        Quickshell.execDetached([
            "bash",
            Quickshell.env("HOME") + "/.local/bin/kingstra-mode-switch",
            modeId
        ]);

        closeTimer.start();
    }
}
