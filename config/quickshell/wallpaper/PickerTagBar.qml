import QtQuick
import QtQuick.Controls

Flow {
    id: tags
    required property var colors
    property var values: []
    signal picked(string tag)
    spacing: 5
    Repeater {
        model: tags.values.slice(0, 8)
        Rectangle {
            required property string modelData
            objectName: "tag-" + modelData
            width: Math.min(190, label.implicitWidth + 20)
            height: 25
            radius: 9
            color: mouse.containsMouse ? tags.colors.surfaceContainerHigh : tags.colors.surfaceContainer
            ToolTip.visible: mouse.containsMouse
            ToolTip.text: "Zoeken: " + modelData
            Text {
                id: label
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 20)
                text: parent.modelData
                textFormat: Text.PlainText
                color: tags.colors.text
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tags.picked(parent.modelData)
            }
        }
    }
}
