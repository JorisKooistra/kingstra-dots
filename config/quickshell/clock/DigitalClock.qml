import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var mocha

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: clockColumn.implicitHeight

    ColumnLayout {
        id: clockColumn
        anchors.centerIn: parent
        spacing: -2

        Text {
            text: shell.timeStr
            Layout.alignment: Qt.AlignHCenter
            font.family: shell.displayFontFamily
            font.pixelSize: shell.s(16)
            font.weight: shell.themeFontWeight
            font.letterSpacing: shell.themeLetterSpacing
            color: mocha.blue
        }

        Text {
            text: shell.dateStr
            Layout.alignment: Qt.AlignHCenter
            font.family: shell.uiFontFamily
            font.pixelSize: shell.s(11)
            font.weight: Font.DemiBold
            font.letterSpacing: shell.themeLetterSpacing
            color: mocha.subtext0
        }
    }
}
