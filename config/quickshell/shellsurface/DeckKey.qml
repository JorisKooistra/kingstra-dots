import QtQuick
import ".."

// Knop op de draaitafel: rond, zakt in bij indrukken, licht op als hij aan
// staat. Kleuren komen uit de skin van TurntableDeck.
Item {
    id: key
    required property var mocha
    required property color accent
    required property var skin
    property string label: ""
    property string icon: ""
    property bool lit: false
    property real keyWidth: 40
    property real keyHeight: 26
    signal activated()
    implicitWidth: keyWidth
    implicitHeight: keyHeight + 3
    opacity: enabled ? 1 : 0.4

    // Zijkant van de knop; de kap schuift erover bij indrukken.
    Rectangle {
        y: 3
        width: parent.width
        height: key.keyHeight
        radius: Math.min(height / 2, key.skin.radius < 10 ? 4 : 10)
        color: key.skin.capSide
    }
    Rectangle {
        id: cap
        y: keyMouse.pressed ? 2.5 : 0
        width: parent.width
        height: key.keyHeight
        radius: Math.min(height / 2, key.skin.radius < 10 ? 4 : 10)
        Behavior on y { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: keyMouse.containsMouse ? key.skin.capHover : key.skin.capA }
            GradientStop { position: 1.0; color: key.skin.capB }
        }
        border.width: 1
        border.color: key.lit
            ? key.skin.lit
            : key.skin.capBorder
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }

        Text {
            anchors.centerIn: parent
            visible: key.icon !== "" || key.keyHeight >= 14
            text: key.icon !== "" ? key.icon : key.label
            font.family: key.icon !== "" ? ThemeConfig.iconFont : ThemeConfig.monoFont
            font.pixelSize: key.icon !== "" ? Math.max(12, key.keyHeight * 0.48) : Math.max(6, key.keyHeight * 0.34)
            font.weight: Font.Bold
            font.letterSpacing: key.icon !== "" ? 0 : 1
            color: key.lit ? key.skin.lit : key.skin.capText
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
        }
        // Ledje.
        Rectangle {
            visible: key.label !== ""
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            width: 4; height: 4; radius: 2
            color: key.lit ? key.skin.lit : key.skin.capText
            opacity: key.lit ? 1 : 0.25
        }
    }
    MouseArea {
        id: keyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.activated()
    }
}
