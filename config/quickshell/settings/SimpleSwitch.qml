import QtQuick
import QtQuick.Layouts
import "../"

// Regel met uitleg en een schakelaar. De hele regel is klikbaar.
Item {
    id: row
    required property var colors
    property string label: ""
    property string hint: ""
    property bool checked: false
    property bool allowed: true
    property string blockedReason: ""
    signal toggled(bool on)

    Layout.fillWidth: true
    implicitHeight: Math.max(36, line.implicitHeight)
    opacity: allowed ? 1 : 0.55

    RowLayout {
        id: line
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: row.label
                color: row.colors.text
                font.family: ThemeConfig.uiFont
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Text {
                readonly property string say: !row.allowed && row.blockedReason !== "" ? row.blockedReason : row.hint
                visible: say !== ""
                Layout.fillWidth: true
                text: say
                color: !row.allowed && row.blockedReason !== "" ? row.colors.yellow : row.colors.subtext0
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }
        Rectangle {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 26
            radius: height / 2
            color: row.checked ? Qt.alpha(row.colors.primary, 0.85) : Qt.alpha(row.colors.surface1, 0.7)
            border.width: 1
            border.color: row.checked ? row.colors.primary : row.colors.shellOutline
            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                x: row.checked ? parent.width - width - 3 : 3
                color: row.checked ? row.colors.base : row.colors.subtext0
                Behavior on x { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: row.allowed
        cursorShape: Qt.PointingHandCursor
        onClicked: row.toggled(!row.checked)
    }
}
