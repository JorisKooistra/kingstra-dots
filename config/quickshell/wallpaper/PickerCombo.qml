import QtQuick
import QtQuick.Controls
import "../"

ComboBox {
    id: control
    required property var colors
    implicitWidth: Math.max(138, implicitContentWidth + 44)
    implicitHeight: 36
    font.pixelSize: 13
    font.family: ThemeConfig.uiFont
    palette.text: colors.text
    palette.buttonText: colors.text
    palette.window: colors.surfaceContainer
    palette.base: colors.surfaceContainer
    palette.highlight: colors.primary
    palette.highlightedText: colors.materialOnPrimary
    contentItem: PickerText {
        text: control.displayText
        color: control.colors.text
        font: control.font
        verticalAlignment: Text.AlignVCenter
        leftPadding: 12
        rightPadding: 26
        elide: Text.ElideRight
    }
    indicator: PickerText {
        x: control.width - 24
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        color: control.colors.text
    }
    background: Rectangle {
        color: control.hovered ? control.colors.surfaceContainerHigh : control.colors.surfaceContainer
        radius: Math.max(0, Math.min(12, ThemeConfig.styleWidgetRadius))
    }
    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: control.width
        contentItem: PickerText {
            text: parent.modelData
            font: control.font
            color: control.colors.text
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: parent.highlighted ? control.colors.surfaceContainerHighest : control.colors.surfaceContainer
            radius: Math.max(0, Math.min(8, ThemeConfig.styleWidgetRadius))
        }
        highlighted: control.highlightedIndex === index
    }
    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: contentItem.implicitHeight + 12
        padding: 6
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
        background: Rectangle {
            color: control.colors.surfaceContainer
            radius: Math.max(0, Math.min(12, ThemeConfig.styleWidgetRadius))
            border.color: control.colors.surfaceContainerHighest
        }
    }
}
