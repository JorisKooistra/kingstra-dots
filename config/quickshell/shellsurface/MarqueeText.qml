import QtQuick
import ".."

// Tekst die langzaam heen en weer loopt als hij niet past, zoals een
// display: eerst even stil, dan naar het eind, weer stil en terug. Gedeeld
// door de cassettespeler en de discman (label, lcd).
Item {
    id: marquee

    property string text: ""
    property color color: "white"
    property string fontFamily: ThemeConfig.monoFont
    property real pixelSize: 12
    property int fontWeight: Font.Normal
    property real letterSpacing: 0
    // Uit tijdens een animatie of als het niet zichtbaar is.
    property bool running: true
    readonly property real overflow: Math.max(0, label.implicitWidth - width)

    implicitHeight: label.implicitHeight
    clip: true

    Text {
        id: label
        text: marquee.text
        color: marquee.color
        font.family: marquee.fontFamily
        font.pixelSize: marquee.pixelSize
        font.weight: marquee.fontWeight
        font.letterSpacing: marquee.letterSpacing
        onTextChanged: x = 0
    }
    SequentialAnimation {
        running: marquee.running && marquee.overflow > 0 && marquee.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running) label.x = 0
        PauseAnimation { duration: 2200 }
        NumberAnimation {
            target: label; property: "x"; to: -marquee.overflow
            duration: Math.max(1500, marquee.overflow * 35); easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 1600 }
        NumberAnimation {
            target: label; property: "x"; to: 0
            duration: Math.max(1500, marquee.overflow * 35); easing.type: Easing.InOutSine
        }
    }
}
