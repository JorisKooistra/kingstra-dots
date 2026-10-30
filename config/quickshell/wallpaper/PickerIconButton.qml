import QtQuick
import QtQuick.Controls

Rectangle {
    id: button
    required property var colors
    property string icon: "download"
    property string label: ""
    property bool available: true
    property bool selected: false
    readonly property bool hovered: mouse.containsMouse
    signal clicked
    implicitWidth: 32
    implicitHeight: 32
    radius: 9
    color: selected ? colors.primary : (hovered ? colors.surfaceContainerHigh : colors.surface)
    border.width: 1
    border.color: colors.primary
    opacity: available ? 1 : 0.4
    activeFocusOnTab: available && visible
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: { if (available) clicked(); }
    Keys.onReturnPressed: { if (available) clicked(); }
    Keys.onSpacePressed: { if (available) clicked(); }
    ToolTip.visible: hovered
    ToolTip.text: label
    PickerIcon {
        anchors.centerIn: parent
        name: button.icon
        color: button.selected ? button.colors.materialOnPrimary : button.colors.primary
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => {
            event.accepted = true;
            if (button.available) button.clicked();
        }
    }
}
