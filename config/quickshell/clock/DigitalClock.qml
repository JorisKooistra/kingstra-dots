import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var mocha
    readonly property string activeTheme: String(shell.activeThemeName || "").toLowerCase()
    readonly property bool cyberTheme: activeTheme === "cyber"
    readonly property string clockFontFamily: cyberTheme ? "Digital-7" : shell.displayFontFamily

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: clockColumn.implicitHeight

    ColumnLayout {
        id: clockColumn
        anchors.centerIn: parent
        spacing: root.cyberTheme ? -1 : -2

        Text {
            text: shell.timeStr
            Layout.alignment: Qt.AlignHCenter
            font.family: root.clockFontFamily
            font.pixelSize: shell.s(root.cyberTheme ? 19 : 16)
            font.weight: root.cyberTheme ? Font.Bold : shell.themeFontWeight
            font.letterSpacing: root.cyberTheme ? 2.2 : shell.themeLetterSpacing
            color: root.cyberTheme ? Qt.lighter(mocha.blue, 1.2) : mocha.blue
            style: root.cyberTheme ? Text.Outline : Text.Normal
            styleColor: root.cyberTheme
                        ? Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.92)
                        : Qt.rgba(0, 0, 0, 0)
            renderType: Text.NativeRendering
        }

        Text {
            text: shell.dateStr
            Layout.alignment: Qt.AlignHCenter
            font.family: root.cyberTheme ? shell.monoFontFamily : shell.uiFontFamily
            font.pixelSize: shell.s(root.cyberTheme ? 10 : 11)
            font.weight: Font.DemiBold
            font.letterSpacing: root.cyberTheme ? 1.4 : shell.themeLetterSpacing
            color: root.cyberTheme ? Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.9) : mocha.subtext0
            renderType: Text.NativeRendering
        }
    }
}
