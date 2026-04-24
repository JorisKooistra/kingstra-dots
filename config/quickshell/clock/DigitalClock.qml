import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var mocha
    property real cyberScale: 1.0
    readonly property string activeTheme: String(shell.activeThemeName || "").toLowerCase()
    readonly property bool cyberTheme: activeTheme === "cyber"
    readonly property string cyberRawTimeText: String(shell.timeStr || "--:--")
    readonly property string cyberTimeText: {
        let parts = cyberRawTimeText.split(":");
        if (parts.length >= 2) return parts[0] + ":" + parts[1];
        return cyberRawTimeText;
    }
    readonly property string cyberDateText: {
        let d = new Date();
        let dd = String(d.getDate()).padStart(2, "0");
        let mm = String(d.getMonth() + 1).padStart(2, "0");
        return dd + "-" + mm;
    }
    readonly property color cyberSegmentOnColor: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.98)
    readonly property color cyberSegmentOffColor: Qt.rgba(mocha.primaryContainer.r, mocha.primaryContainer.g, mocha.primaryContainer.b, 0.20)
    readonly property color cyberDateOnColor: Qt.rgba(mocha.onSurfaceVariant.r, mocha.onSurfaceVariant.g, mocha.onSurfaceVariant.b, 0.94)
    readonly property color cyberDateOffColor: Qt.rgba(mocha.surfaceContainerHighest.r, mocha.surfaceContainerHighest.g, mocha.surfaceContainerHighest.b, 0.16)
    readonly property real effectiveCyberScale: Math.max(1.0, Number(cyberScale) || 1.0)
    readonly property int cyberGlyphWidth: Math.round(shell.s(15) * effectiveCyberScale)
    readonly property int cyberGlyphHeight: Math.round(shell.s(25) * effectiveCyberScale)
    readonly property int cyberGlyphSpacing: Math.max(shell.s(2), Math.round(shell.s(2) * effectiveCyberScale))
    readonly property int cyberDateGlyphWidth: Math.round(shell.s(8) * effectiveCyberScale)
    readonly property int cyberDateGlyphHeight: Math.round(shell.s(12) * effectiveCyberScale)
    readonly property int cyberDateGlyphSpacing: Math.max(shell.s(1), Math.round(shell.s(1) * effectiveCyberScale))

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
                color: mocha.primary
                renderType: Text.NativeRendering
            }

            Text {
                text: shell.dateStr
                Layout.alignment: Qt.AlignHCenter
                font.family: shell.uiFontFamily
                font.pixelSize: shell.s(11)
                font.weight: Font.DemiBold
                font.letterSpacing: shell.themeLetterSpacing
                color: mocha.onSurfaceVariant
                renderType: Text.NativeRendering
            }
        }
    }

    Component {
        id: cyberClockComponent
        RowLayout {
            anchors.centerIn: parent
            spacing: shell.s(6)

            SevenSegmentText {
                text: root.cyberTimeText
                Layout.alignment: Qt.AlignVCenter
                glyphWidth: root.cyberGlyphWidth
                glyphHeight: root.cyberGlyphHeight
                glyphSpacing: root.cyberGlyphSpacing
                segmentOnColor: root.cyberSegmentOnColor
                segmentOffColor: root.cyberSegmentOffColor
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1
                height: shell.s(16)
                color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.45)
            }

            SevenSegmentText {
                text: root.cyberDateText
                Layout.alignment: Qt.AlignVCenter
                glyphWidth: root.cyberDateGlyphWidth
                glyphHeight: root.cyberDateGlyphHeight
                glyphSpacing: root.cyberDateGlyphSpacing
                segmentOnColor: root.cyberDateOnColor
                segmentOffColor: root.cyberDateOffColor
            }
        }
    }
}
