import QtQuick
import "../"

// Ronde knop. chosen markeert hem als aan; met glyph een icoon ervoor.
Rectangle {
    id: chip
    required property var colors
    property string label: ""
    property string glyph: ""
    property bool chosen: false
    property bool allowed: true
    signal triggered()

    implicitHeight: 34
    implicitWidth: chipRow.implicitWidth + 26
    radius: height / 2
    opacity: allowed ? 1 : 0.45
    scale: chipMouse.pressed ? 0.96 : 1.0
    color: chosen ? Qt.alpha(colors.primary, 0.22) : chipMouse.containsMouse ? colors.shellHoverFill : Qt.alpha(colors.surface1, 0.35)
    border.width: 1
    border.color: chosen ? colors.primary : colors.shellOutline
    Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(150) } }
    Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(180) } }
    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(180) } }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: chip.glyph !== ""
            text: chip.glyph
            color: chip.chosen ? chip.colors.primary : chip.colors.subtext1
            font.family: ThemeConfig.iconFont
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: chip.label
            color: chip.colors.text
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: chip.allowed
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.triggered()
    }
}
