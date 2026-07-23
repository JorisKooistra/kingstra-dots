import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var mocha
    property real neonScale: 1.0
    readonly property string activeTheme: String(shell.activeThemeName || "").toLowerCase()
    readonly property bool neonTheme: activeTheme === "neon"
    readonly property string neonRawTimeText: String(shell.timeStr || "--:--")
    readonly property string neonTimeText: {
        let parts = neonRawTimeText.split(":");
        if (parts.length >= 2) return parts[0] + ":" + parts[1];
        return neonRawTimeText;
    }
    readonly property string neonDateText: {
        let d = new Date();
        let dd = String(d.getDate()).padStart(2, "0");
        let mm = String(d.getMonth() + 1).padStart(2, "0");
        return dd + "-" + mm;
    }
    readonly property color neonSegmentOnColor: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.98)
    readonly property color neonSegmentOffColor: Qt.rgba(mocha.primaryContainer.r, mocha.primaryContainer.g, mocha.primaryContainer.b, 0.20)
    readonly property color neonDateOnColor: Qt.rgba(mocha.onSurfaceVariant.r, mocha.onSurfaceVariant.g, mocha.onSurfaceVariant.b, 0.94)
    readonly property color neonDateOffColor: Qt.rgba(mocha.surfaceContainerHighest.r, mocha.surfaceContainerHighest.g, mocha.surfaceContainerHighest.b, 0.16)
    readonly property real effectiveNeonScale: Math.max(1.0, Number(neonScale) || 1.0)
    readonly property int neonGlyphWidth: Math.round(shell.s(15) * effectiveNeonScale)
    readonly property int neonGlyphHeight: Math.round(shell.s(25) * effectiveNeonScale)
    readonly property int neonGlyphSpacing: Math.max(shell.s(2), Math.round(shell.s(2) * effectiveNeonScale))
    readonly property int neonDateGlyphWidth: Math.round(shell.s(8) * effectiveNeonScale)
    readonly property int neonDateGlyphHeight: Math.round(shell.s(12) * effectiveNeonScale)
    readonly property int neonDateGlyphSpacing: Math.max(shell.s(1), Math.round(shell.s(1) * effectiveNeonScale))

    implicitWidth: clockLoader.implicitWidth
    implicitHeight: clockLoader.implicitHeight

    Loader {
        id: clockLoader
        anchors.centerIn: parent
        sourceComponent: root.neonTheme ? neonClockComponent : defaultClockComponent
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
        id: neonClockComponent
        RowLayout {
            anchors.centerIn: parent
            spacing: shell.s(6)

            SevenSegmentText {
                text: root.neonTimeText
                Layout.alignment: Qt.AlignVCenter
                glyphWidth: root.neonGlyphWidth
                glyphHeight: root.neonGlyphHeight
                glyphSpacing: root.neonGlyphSpacing
                segmentOnColor: root.neonSegmentOnColor
                segmentOffColor: root.neonSegmentOffColor
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1
                height: shell.s(16)
                color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.45)
            }

            SevenSegmentText {
                text: root.neonDateText
                Layout.alignment: Qt.AlignVCenter
                glyphWidth: root.neonDateGlyphWidth
                glyphHeight: root.neonDateGlyphHeight
                glyphSpacing: root.neonDateGlyphSpacing
                segmentOnColor: root.neonDateOnColor
                segmentOffColor: root.neonDateOffColor
            }
        }
    }
}
