import QtQuick
import QtQuick.Layouts
import "../"

// Een paar standen naast elkaar met een glijdende markering. Klik is meteen
// toepassen. options: [{id, title, glyph?}].
Item {
    id: choice
    required property var colors
    property string label: ""
    property string hint: ""
    property var options: []
    property string current: ""
    property bool allowed: true
    property string blockedReason: ""
    signal picked(string value)

    readonly property int activeIndex: {
        for (let i = 0; i < options.length; ++i) if (options[i].id === current) return i;
        return -1;
    }
    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 6
        Text {
            visible: choice.label !== ""
            Layout.fillWidth: true
            text: choice.label
            color: choice.colors.text
            font.family: ThemeConfig.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: height / 2
            color: Qt.alpha(choice.colors.surface1, 0.35)
            border.width: 1
            border.color: choice.colors.shellOutline
            opacity: choice.allowed ? 1 : 0.5
            readonly property real slotWidth: choice.options.length ? (width - 8) / choice.options.length : 0
            Rectangle {
                visible: choice.activeIndex >= 0
                x: 4 + Math.max(0, choice.activeIndex) * track.slotWidth
                y: 4
                width: track.slotWidth
                height: track.height - 8
                radius: height / 2
                color: Qt.alpha(choice.colors.primary, 0.24)
                border.width: 1
                border.color: choice.colors.primary
                Behavior on x { NumberAnimation { duration: ThemeConfig.duration(280); easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: ThemeConfig.duration(280); easing.type: Easing.OutCubic } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 4
                Repeater {
                    model: choice.options
                    delegate: Item {
                        id: slot
                        required property var modelData
                        required property int index
                        width: track.slotWidth
                        height: parent.height
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                visible: !!slot.modelData.glyph
                                text: slot.modelData.glyph || ""
                                color: slot.index === choice.activeIndex ? choice.colors.primary : choice.colors.subtext1
                                font.family: ThemeConfig.iconFont
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: slot.modelData.title
                                color: slot.index === choice.activeIndex ? choice.colors.text : choice.colors.subtext0
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 12
                                font.bold: slot.index === choice.activeIndex
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: choice.allowed
                            cursorShape: Qt.PointingHandCursor
                            onClicked: choice.picked(slot.modelData.id)
                        }
                    }
                }
            }
        }
        Text {
            readonly property string say: !choice.allowed && choice.blockedReason !== "" ? choice.blockedReason : choice.hint
            visible: say !== ""
            Layout.fillWidth: true
            text: say
            color: !choice.allowed && choice.blockedReason !== "" ? choice.colors.yellow : choice.colors.subtext0
            font.family: ThemeConfig.uiFont
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }
}
