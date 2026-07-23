import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

FocusScope {
    id: root

    MatugenColors { id: mocha }

    readonly property int pad: 16
    readonly property int itemRadius: Math.max(12, ThemeConfig.styleWidgetRadius)
    readonly property color subtleBorder: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    Keys.onEscapePressed: event => {
        closePanel();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: root.itemRadius
                color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: "󰇮"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 19
                    color: mocha.blue
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: "Mail"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: Font.Black
                    color: mocha.text
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: MailService.statusText
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            HeaderButton {
                icon: "󰜉"
                accent: mocha.teal
                onTriggered: MailService.refresh()
            }

            HeaderButton {
                icon: "󰈹"
                accent: mocha.blue
                onTriggered: MailService.openThunderbird()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: MailService.recent
            visible: MailService.recent.length > 0

            delegate: Rectangle {
                id: mailRow
                required property var modelData

                width: ListView.view.width
                height: rowContent.implicitHeight + 18
                radius: root.itemRadius
                color: rowHover.hovered
                    ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.38)
                    : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.28)
                border.width: 1
                border.color: root.subtleBorder

                ColumnLayout {
                    id: rowContent
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: String(mailRow.modelData.title || "Bericht")
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: mocha.text
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: String(mailRow.modelData.sender || "") !== ""
                        text: String(mailRow.modelData.sender || "")
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 10
                        color: mocha.subtext0
                        elide: Text.ElideRight
                    }
                }

                HoverHandler { id: rowHover }
                TapHandler { onTapped: MailService.openThunderbird() }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: MailService.recent.length === 0

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: MailService.available ? "󰇮" : "󰅚"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 34
                color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.28)
            }

            Text {
                Layout.fillWidth: true
                text: MailService.available
                    ? (MailService.profileFound ? "Geen recente mails gevonden" : "Thunderbird-profiel niet gevonden")
                    : "Thunderbird is niet geïnstalleerd"
                font.family: ThemeConfig.displayFont
                font.pixelSize: 14
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                color: mocha.text
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: MailService.available
                    ? "Open Thunderbird om je inbox te bekijken."
                    : "Installeer Thunderbird om deze widget te gebruiken."
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                color: mocha.subtext0
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
        }
    }

    component HeaderButton: Rectangle {
        id: buttonRoot
        property string icon: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 9
        color: buttonMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
            : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.24)
        border.width: 1
        border.color: buttonMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.42)
            : root.subtleBorder

        Text {
            anchors.centerIn: parent
            text: buttonRoot.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 15
            color: buttonRoot.accent
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: buttonRoot.triggered()
        }
    }
}
