import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var mocha
    property real cyberScale: 1.0
    readonly property string activeTheme: String(shell.activeThemeName || "").toLowerCase()
    readonly property bool cyberTheme: activeTheme === "cyber"
    readonly property string cyberTimeText: String(shell.timeStr || "--:--")
    readonly property color cyberSegmentOnColor: Qt.lighter(mocha.blue, 1.25)
    readonly property color cyberSegmentOffColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.28)
    readonly property real effectiveCyberScale: Math.max(1.0, Number(cyberScale) || 1.0)
    readonly property int cyberGlyphWidth: Math.round(shell.s(18) * effectiveCyberScale)
    readonly property int cyberGlyphHeight: Math.round(shell.s(30) * effectiveCyberScale)
    readonly property int cyberGlyphSpacing: Math.max(shell.s(3), Math.round(shell.s(3) * effectiveCyberScale))
    readonly property int cyberDateFontSize: Math.max(shell.s(11), Math.round(shell.s(11) * (1.0 + (effectiveCyberScale - 1.0) * 0.75)))

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
            spacing: shell.s(2)

            RowLayout {
                spacing: shell.s(3)
                Layout.alignment: Qt.AlignHCenter

                SevenSegmentText {
                    text: root.cyberTimeText
                    glyphWidth: root.cyberGlyphWidth
                    glyphHeight: root.cyberGlyphHeight
                    glyphSpacing: root.cyberGlyphSpacing
                    segmentOnColor: root.cyberSegmentOnColor
                    segmentOffColor: root.cyberSegmentOffColor
                }
            }

            Text {
                text: String(shell.dateStr || "").toUpperCase()
                Layout.alignment: Qt.AlignHCenter
                font.family: shell.monoFontFamily
                font.pixelSize: root.cyberDateFontSize
                font.weight: Font.DemiBold
                font.letterSpacing: 2.4
                color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.74)
                renderType: Text.NativeRendering
            }
        }
    }
}
