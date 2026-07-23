import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import ".."

FocusScope {
    id: root

    MatugenColors { id: mocha }

    readonly property int pad: 16
    readonly property int panelRadius: Math.max(18, ThemeConfig.styleWidgetRadius + 6)
    readonly property int itemRadius: Math.max(12, Math.round(panelRadius * 0.56))
    readonly property color cardColor: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.28)
    readonly property color cardHoverColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.36)
    readonly property color subtleBorder: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function cleanText(value) {
        return String(value || "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<\/p>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .trim();
    }

    function appInitial(notification) {
        let name = String(notification && notification.appName ? notification.appName : "?").trim();
        return name.length > 0 ? name.charAt(0).toUpperCase() : "?";
    }

    function urgencyColor(notification) {
        if (notification && notification.urgency === NotificationUrgency.Critical) return mocha.red;
        if (notification && notification.urgency === NotificationUrgency.Low) return mocha.subtext0;
        return mocha.yellow;
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
                color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: NotificationService.dnd ? "󰂛" : "󰍜"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 19
                    color: mocha.yellow
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: "Meldingen"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: Font.Black
                    color: mocha.text
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: NotificationService.dnd
                        ? "Niet storen actief"
                        : (NotificationService.count === 1
                            ? "1 melding"
                            : NotificationService.count + " meldingen")
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            HeaderButton {
                icon: NotificationService.dnd ? "󰂚" : "󰂛"
                tooltip: NotificationService.dnd ? "Niet storen uit" : "Niet storen aan"
                accent: mocha.mauve
                onTriggered: NotificationService.toggleDnd()
            }

            HeaderButton {
                icon: "󰆴"
                tooltip: "Alles wissen"
                accent: mocha.red
                enabled: NotificationService.count > 0
                onTriggered: NotificationService.clearAll()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 320)
                spacing: 8
                visible: NotificationService.count === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: NotificationService.dnd ? "󰂛" : "󰂚"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 36
                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.28)
                }

                Text {
                    Layout.fillWidth: true
                    text: NotificationService.dnd ? "Ruststand staat aan" : "Geen meldingen"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    color: mocha.text
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: NotificationService.dnd
                        ? "Kritieke meldingen komen nog door."
                        : "Nieuwe meldingen verschijnen hier."
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    color: mocha.subtext0
                    wrapMode: Text.WordWrap
                }
            }

            ListView {
                id: notificationList
                anchors.fill: parent
                visible: NotificationService.count > 0
                clip: true
                spacing: 8
                model: NotificationService.notifications
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: notificationCard
                    required property var modelData

                    width: notificationList.width
                    height: contentColumn.implicitHeight + 18
                    radius: root.itemRadius
                    color: cardHover.hovered ? root.cardHoverColor : root.cardColor
                    border.width: 1
                    border.color: root.subtleBorder

                    Behavior on color {
                        ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignTop
                            radius: 9
                            color: Qt.rgba(root.urgencyColor(notificationCard.modelData).r,
                                           root.urgencyColor(notificationCard.modelData).g,
                                           root.urgencyColor(notificationCard.modelData).b,
                                           0.18)

                            Text {
                                anchors.centerIn: parent
                                text: root.appInitial(notificationCard.modelData)
                                font.family: ThemeConfig.displayFont
                                font.pixelSize: 14
                                font.weight: Font.Black
                                color: root.urgencyColor(notificationCard.modelData)
                            }
                        }

                        ColumnLayout {
                            id: contentColumn
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: String(notificationCard.modelData.summary || notificationCard.modelData.appName || "Melding")
                                    font.family: ThemeConfig.displayFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: String(notificationCard.modelData.appName || "") !== ""
                                    text: String(notificationCard.modelData.appName || "")
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 10
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 110
                                }

                                IconButton {
                                    icon: "󰅖"
                                    accent: mocha.subtext0
                                    onTriggered: NotificationService.dismiss(notificationCard.modelData)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: root.cleanText(notificationCard.modelData.body)
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                lineHeight: 1.1
                                color: mocha.subtext1
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            Flow {
                                Layout.fillWidth: true
                                visible: notificationCard.modelData.actions.length > 0
                                spacing: 6

                                Repeater {
                                    model: notificationCard.modelData.actions

                                    delegate: ActionButton {
                                        required property var modelData
                                        label: String(modelData.text || "")
                                        accent: root.urgencyColor(notificationCard.modelData)
                                        onTriggered: {
                                            modelData.invoke();
                                            NotificationService.dismiss(notificationCard.modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: cardHover
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: NotificationService.dismiss(notificationCard.modelData)
                    }
                }
            }
        }
    }

    component HeaderButton: Rectangle {
        id: buttonRoot
        property string icon: ""
        property string tooltip: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 9
        opacity: enabled ? 1.0 : 0.35
        color: headerMouse.containsMouse && enabled
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
            : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.24)
        border.width: 1
        border.color: headerMouse.containsMouse && enabled
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
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: buttonRoot.enabled
            onClicked: buttonRoot.triggered()
        }
    }

    component IconButton: Rectangle {
        id: buttonRoot
        property string icon: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 7
        color: iconMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
            : "transparent"

        Text {
            anchors.centerIn: parent
            text: buttonRoot.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 13
            color: buttonRoot.accent
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: buttonRoot.triggered()
        }
    }

    component ActionButton: Rectangle {
        id: buttonRoot
        property string label: ""
        property color accent: mocha.blue
        signal triggered()

        width: actionLabel.implicitWidth + 18
        height: 26
        radius: 8
        color: actionMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.20)
            : Qt.rgba(accent.r, accent.g, accent.b, 0.11)
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, actionMouse.containsMouse ? 0.44 : 0.24)

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: buttonRoot.label
            font.family: ThemeConfig.uiFont
            font.pixelSize: 11
            font.weight: Font.Bold
            color: buttonRoot.accent
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: buttonRoot.triggered()
        }
    }
}
