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
    // Hoogte van de zijkant: de kap staat zichtbaar boven de kast.
    readonly property real depth: Math.max(2, Math.round(keyHeight * 0.16))
    readonly property real capRadius: Math.min(keyHeight / 2, skin.radius < 10 ? 4 : 10)
    implicitWidth: keyWidth
    implicitHeight: keyHeight + depth
    opacity: enabled ? 1 : 0.4

    // Schaduw op de kast.
    Rectangle {
        x: 1
        y: key.depth + 1
        width: parent.width
        height: key.keyHeight
        radius: key.capRadius
        color: Qt.rgba(0, 0, 0, 0.35)
    }
    // Zijkant van de knop; de kap schuift erover bij indrukken.
    Rectangle {
        y: key.depth
        width: parent.width
        height: key.keyHeight
        radius: key.capRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: key.skin.capSide }
            GradientStop { position: 1.0; color: Qt.darker(key.skin.capSide, 1.4) }
        }
    }
    Rectangle {
        id: cap
        y: keyMouse.pressed ? key.depth * 0.8 : 0
        width: parent.width
        height: key.keyHeight
        radius: key.capRadius
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

        // Glanslijn langs de bovenrand.
        Rectangle {
            x: key.capRadius * 0.6
            y: 1
            width: parent.width - key.capRadius * 1.2
            height: 1
            color: Qt.rgba(1, 1, 1, key.skin.capShine !== undefined ? key.skin.capShine : 0.18)
        }

        Text {
            anchors.centerIn: parent
            visible: key.icon !== "" || key.keyHeight >= 14
            text: key.icon !== "" ? key.icon : key.label
            font.family: key.icon !== "" ? ThemeConfig.iconFont : ThemeConfig.monoFont
            font.pixelSize: key.icon !== "" ? Math.max(12, key.keyHeight * 0.48) : Math.max(6, key.keyHeight * 0.34)
            font.weight: Font.Bold
            font.letterSpacing: key.icon !== "" ? 0 : 1
            // Opschrift blijft leesbaar; "aan" zie je aan het ledje en de rand.
            color: key.lit && key.skin.litText === true ? key.skin.lit : key.skin.capText
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
        }
        // Lichtstreepje onder een icoonknop die aan staat.
        Rectangle {
            visible: key.icon !== "" && key.skin.litText !== true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(3, key.keyHeight * 0.12)
            width: parent.width * 0.3
            height: Math.max(2, key.keyHeight * 0.05)
            radius: height / 2
            color: key.skin.lit
            opacity: key.lit ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
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
