import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Eén venster als kaart, gelijk in het werkruimte-overzicht en de
// werkvlak-kaart: live beeld, anders het bewaarde plaatje, anders het
// app-icoon; titel met icoon als label onderin; zelfde rand, hover en keuze.
Item {
    id: card
    required property var look
    property var captureSource: null
    property bool liveCapture: true
    property string stillSource: ""
    property string iconSource: ""
    property string label: ""
    property bool floatingWindow: false
    property bool chosen: false
    property bool hovering: false
    property bool pressing: false
    property real cornerRadius: look.cardRadius

    readonly property bool hasPreview: preview.hasContent || still.status === Image.Ready
    readonly property bool roomForLabel: height > 40 && width > 64

    readonly property int borderWidth: chosen ? 2 : 1

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: card.cornerRadius
        color: card.look.base
    }
    // Beeld en plaatje volgen de ronde hoek: zelfde masker als ThemeCarousel.
    Rectangle {
        id: mediaMask
        anchors.fill: parent
        radius: card.cornerRadius
        visible: false
        layer.enabled: true
    }
    Item {
        id: media
        anchors.fill: parent
        layer.enabled: card.hasPreview
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mediaMask
        }

        ScreencopyView {
            id: preview
            anchors.fill: parent
            anchors.margins: card.borderWidth
            captureSource: card.captureSource
            live: card.liveCapture
            opacity: hasContent ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: card.look.duration(200) } }
        }
        // Buiten beeld geeft Hyprland geen live beeld: dan het laatst
        // bewaarde plaatje.
        Image {
            id: still
            anchors.fill: parent
            anchors.margins: card.borderWidth
            visible: !preview.hasContent && card.stillSource !== ""
            source: card.stillSource
            cache: false
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: card.look.duration(200) } }
        }
        // Zonder beeld: groot app-icoon in het midden in plaats van tekst.
        Image {
            readonly property real side: Math.max(12, Math.min(card.width, card.height) * 0.36)
            anchors.centerIn: parent
            anchors.verticalCenterOffset: card.roomForLabel ? -10 : 0
            visible: !card.hasPreview && card.iconSource !== ""
            source: card.iconSource
            width: side
            height: side
            sourceSize: Qt.size(Math.round(side), Math.round(side))
            asynchronous: true
        }
    }
    Item {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: card.chosen || card.pressing ? card.look.selectedTint
                : card.hovering ? card.look.hoverTint : "transparent"
            Behavior on color { ColorAnimation { duration: card.look.duration(150) } }
        }
        Rectangle {
            id: chip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            visible: card.roomForLabel && card.label !== ""
            height: Math.min(24, parent.height / 3)
            radius: height / 2
            color: Qt.rgba(card.look.base.r, card.look.base.g, card.look.base.b, 0.82)
            Row {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 10
                spacing: 6
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.iconSource !== "" && card.hasPreview
                    source: card.iconSource
                    width: chip.height - 8
                    height: width
                    sourceSize: Qt.size(Math.max(1, Math.round(width)), Math.max(1, Math.round(height)))
                    asynchronous: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    text: (card.floatingWindow ? "◇  " : "") + card.label
                    color: card.look.text
                    font.family: card.look.uiFont
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: card.cornerRadius
        color: "transparent"
        border.color: card.chosen ? card.look.primary : card.look.outline
        border.width: card.borderWidth
        Behavior on border.color { ColorAnimation { duration: card.look.duration(150) } }
    }
}
