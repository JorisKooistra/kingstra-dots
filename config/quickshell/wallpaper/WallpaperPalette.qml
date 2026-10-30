import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: paletteStrip
    required property var colors
    property var swatches: []
    signal copied(string hex)
    spacing: 12
    PickerText {
        text: "Beeldkleuren"
        color: paletteStrip.colors.onSurfaceVariant
        font.pixelSize: 12
    }
    Row {
        Layout.fillWidth: true
        Layout.maximumWidth: 560
        height: 24
        Repeater {
            model: paletteStrip.swatches
            Rectangle {
                required property string modelData
                objectName: "swatch-" + modelData
                width: parent.width / Math.max(1, paletteStrip.swatches.length)
                height: 24
                color: modelData
                ToolTip.visible: mouse.containsMouse
                ToolTip.text: modelData + " · klik om te kopiëren"
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: paletteStrip.copied(parent.modelData)
                }
            }
        }
    }
    Item { Layout.fillWidth: true }
    PickerText {
        text: "Thema · 3 accenten"
        color: paletteStrip.colors.onSurfaceVariant
        font.pixelSize: 12
    }
    Repeater {
        model: [paletteStrip.colors.primary, paletteStrip.colors.accent2 || paletteStrip.colors.primary, paletteStrip.colors.accent3 || paletteStrip.colors.primary]
        Rectangle {
            required property color modelData
            width: 18
            height: 18
            radius: 9
            color: modelData
        }
    }
}
