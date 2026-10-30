import QtQuick
import QtQuick.Controls

CheckBox {
    id: control
    required property var colors
    implicitHeight: 36
    implicitWidth: label.implicitWidth + 8
    spacing: 8
    padding: 4
    indicator: Rectangle {
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: 5
        color: control.checked ? control.colors.primary : control.colors.surfaceContainer
        border.color: control.checked ? control.colors.primary : control.colors.onSurfaceVariant
        PickerText {
            anchors.centerIn: parent
            text: control.checked ? "✓" : ""
            color: control.colors.materialOnPrimary
        }
    }
    contentItem: PickerText {
        id: label
        text: control.text
        leftPadding: 28
        verticalAlignment: Text.AlignVCenter
        color: control.colors.text
    }
}
