import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var mocha
    readonly property string activeTheme: String(shell.activeThemeName || "").toLowerCase()
    readonly property bool cyberTheme: activeTheme === "cyber"
    readonly property string cyberTimeText: String(shell.timeStr || "--:--")
    readonly property color cyberSegmentOnColor: Qt.lighter(mocha.blue, 1.25)
    readonly property color cyberSegmentOffColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.28)

    implicitWidth: clockLoader.implicitWidth
    implicitHeight: clockLoader.implicitHeight

    Loader {
        id: clockLoader
        anchors.centerIn: parent
        sourceComponent: root.cyberTheme ? cyberClockComponent : defaultClockComponent
    }

    Component {
        id: defaultClockComponent
        ColumnLayout {
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
                renderType: Text.NativeRendering
            }

            Text {
                text: shell.dateStr
                Layout.alignment: Qt.AlignHCenter
                font.family: shell.uiFontFamily
                font.pixelSize: shell.s(11)
                font.weight: Font.DemiBold
                font.letterSpacing: shell.themeLetterSpacing
                color: mocha.subtext0
                renderType: Text.NativeRendering
            }
        }
    }

    Component {
        id: cyberClockComponent
        ColumnLayout {
            anchors.centerIn: parent
            spacing: shell.s(4)

            RowLayout {
                spacing: shell.s(3)
                Layout.alignment: Qt.AlignHCenter

                SevenSegmentText {
                    text: root.cyberTimeText
                    glyphWidth: shell.s(18)
                    glyphHeight: shell.s(30)
                    glyphSpacing: shell.s(3)
                    segmentOnColor: root.cyberSegmentOnColor
                    segmentOffColor: root.cyberSegmentOffColor
                }
            }

            Text {
                text: String(shell.dateStr || "").toUpperCase()
                Layout.alignment: Qt.AlignHCenter
                font.family: shell.monoFontFamily
                font.pixelSize: shell.s(11)
                font.weight: Font.DemiBold
                font.letterSpacing: 1.9
                color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.92)
                renderType: Text.NativeRendering
            }
        }
    }
}
