import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"

// Start van Instellingen: acht onderwerpen als grote tegels, plus een paar
// instellingen die mensen het vaakst zoeken. Zelf heeft de pagina geen
// schakelaars; zoeken staat linksboven in de zijbalk.
Item {
    id: root
    signal pageRequested(string page)
    property real unit: 1.0

    MatugenColors { id: pageColors }
    readonly property var c: pageColors

    readonly property var topics: [
        {page: "uiterlijk", glyph: "󰏘", title: "Uiterlijk", detail: "Kleur, licht of donker, rondheid, ruimte en letters"},
        {page: "bureaublad", glyph: "󰕮", title: "Bureaublad", detail: "Zijbalk, indeling, wat vanzelf gebeurt, de speler"},
        {page: "beeldschermen", glyph: "󰍹", title: "Schermen", detail: "Indeling, helderheid, tablet en per scherm"},
        {page: "geluid", glyph: "󰕾", title: "Geluid", detail: "Koptelefoon of speakers, microfoon, volume per app"},
        {page: "netwerk", glyph: "󰤨", title: "Netwerk en Bluetooth", detail: "Wi-Fi, bedraad en apparaten"},
        {page: "invoer", glyph: "󰌌", title: "Invoer en sneltoetsen", detail: "Toetsenbord, muis, touchpad en sneltoetsen"},
        {page: "rust", glyph: "󰂛", title: "Meldingen en rust", detail: "Niet storen, nachtlicht en meldingen per app"},
        {page: "sessie", glyph: "󰒓", title: "Systeem", detail: "Energie en slaap, tijd, updates en onderhoud"}
    ]
    readonly property var popular: [
        {page: "rust", title: "Nachtlicht"},
        {page: "beeldschermen", title: "Schermindeling"},
        {page: "invoer", title: "Toetsenbordindeling"},
        {page: "sneltoetsen", title: "Sneltoetsen"},
        {page: "geluid", title: "Uitvoer en invoer"},
        {page: "updates", title: "Updates"},
        {page: "rail", title: "Zijbalk-indeling"}
    ]

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: body.implicitHeight + 24
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 18

            Text { text: "Instellingen"; color: root.c.text; font.family: ThemeConfig.uiFont; font.pixelSize: 24; font.bold: true }
            Text {
                Layout.fillWidth: true
                text: "Waar wil je iets aan veranderen? Typ linksboven om direct te zoeken. Thema en wallpaper wissel je met Super+A, aan en uit zetten doe je in Snelle instellingen."
                color: root.c.subtext0
                font.family: ThemeConfig.uiFont
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: body.width > 900 ? 4 : body.width > 560 ? 2 : 1
                rowSpacing: 12
                columnSpacing: 12
                Repeater {
                    model: root.topics
                    delegate: Rectangle {
                        id: topic
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 118
                        radius: Math.max(14, ThemeConfig.styleWidgetRadius)
                        color: topicMouse.containsMouse ? root.c.shellHoverFill : Qt.alpha(root.c.shellRaisedFill, 0.55)
                        border.width: 1
                        border.color: topicMouse.containsMouse ? Qt.alpha(root.c.primary, 0.6) : root.c.shellOutline
                        scale: topicMouse.pressed ? 0.97 : 1.0
                        opacity: shown ? 1 : 0
                        property bool shown: false
                        Component.onCompleted: revealTimer.start()
                        Timer { id: revealTimer; interval: 30 + topic.index * 35; onTriggered: topic.shown = true }
                        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(320); easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(180) } }
                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(180) } }
                        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 4
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: width / 2
                                color: Qt.alpha(root.c.primary, 0.16)
                                Text { anchors.centerIn: parent; text: topic.modelData.glyph; color: root.c.primary; font.family: ThemeConfig.iconFont; font.pixelSize: 17 }
                            }
                            Item { Layout.fillHeight: true }
                            Text { Layout.fillWidth: true; text: topic.modelData.title; color: root.c.text; font.family: ThemeConfig.uiFont; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: topic.modelData.detail; color: root.c.subtext0; font.family: ThemeConfig.uiFont; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                        }
                        MouseArea {
                            id: topicMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pageRequested(topic.modelData.page)
                        }
                    }
                }
            }

            Text { text: "Vaak gezocht"; color: root.c.text; font.family: ThemeConfig.uiFont; font.pixelSize: 15; font.bold: true }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.popular
                    delegate: SimpleChip {
                        required property var modelData
                        colors: root.c
                        label: modelData.title
                        glyph: "󰁔"
                        onTriggered: root.pageRequested(modelData.page)
                    }
                }
            }
        }
    }
}
