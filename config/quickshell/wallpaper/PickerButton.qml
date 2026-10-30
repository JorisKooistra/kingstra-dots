import QtQuick
import "../"

Rectangle {
    id: button
    required property var colors
    property string text: ""
    property bool selected: false
    property bool available: true
    activeFocusOnTab: available
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: {
        if (available)
            clicked();
    }
    Keys.onReturnPressed: {
        if (available)
            clicked();
    }
    Keys.onSpacePressed: {
        if (available)
            clicked();
    }
    signal clicked
    implicitWidth: label.implicitWidth + 26
    implicitHeight: 36
    radius: Math.max(0, Math.min(12, ThemeConfig.styleWidgetRadius))
    border.width: activeFocus ? 2 : 0
    border.color: colors.primary
    color: selected ? colors.primary : (mouse.containsMouse ? colors.surfaceContainerHighest : colors.surfaceContainer)
    opacity: available ? 1 : 0.4
    PickerText {
        id: label
        anchors.centerIn: parent
        text: button.text
        textFormat: Text.PlainText
        color: button.selected ? button.colors.materialOnPrimary : button.colors.text
        font.pixelSize: 13
        font.family: ThemeConfig.uiFont
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.available
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
