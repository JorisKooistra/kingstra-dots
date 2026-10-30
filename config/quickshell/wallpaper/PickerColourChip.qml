import QtQuick
import QtQuick.Controls

Rectangle {
    id: chip
    required property color fill
    required property color outline
    required property string label
    property bool selected: false
    signal clicked
    width: 28
    height: 28
    radius: width / 2
    color: fill
    border.width: selected || activeFocus ? 3 : 0
    border.color: outline
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checkable: true
    Accessible.checked: selected
    Accessible.onToggleAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    ToolTip.visible: input.containsMouse || activeFocus
    ToolTip.text: label
    MouseArea {
        id: input
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
