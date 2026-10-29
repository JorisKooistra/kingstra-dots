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

    // Echt 3D: de kap is een uitgetrokken blokje boven een voetafdruk.
    // Bovenop de tafel (frontFacing uit) kijk je schuin van voren tegen de
    // kap aan: de kap staat hoger in beeld en je ziet de voorkant eronder.
    // Op het staande voorpaneel (frontFacing aan) steekt hij naar je toe en
    // kijk je er van boven op: de kap staat lager en je ziet de bovenkant,
    // met de schaduw eronder op het paneel. lean (-1..1) is waar de knop
    // links of rechts van het midden staat; dan zie je ook een zijkant.
    property bool frontFacing: false
    property real lean: 0
    property real depthScale: frontFacing ? 0.24 : 0.16
    readonly property real depth: Math.max(2, Math.round(keyHeight * depthScale))
    readonly property real capRadius: Math.min(keyHeight / 2, skin.radius < 10 ? 4 : 10)
    // 0 = uit, 1 = ingedrukt; de kap zakt dan bijna tot in de voet.
    property real press: keyMouse.pressed ? 1 : 0
    Behavior on press { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
    readonly property real reach: 1 - 0.75 * press
    readonly property real dxFull: lean * depth * 0.6
    readonly property real baseX: dxFull < 0 ? -dxFull : 0
    readonly property real baseY: frontFacing ? 0 : depth
    readonly property real faceX: baseX + dxFull * reach
    readonly property real faceY: frontFacing ? depth * reach : depth * (1 - reach)
    implicitWidth: keyWidth + Math.abs(dxFull)
    implicitHeight: keyHeight + depth
    opacity: enabled ? 1 : 0.4

    // Uitsparing in de kast rond de voet.
    Rectangle {
        x: key.baseX - 1.5
        y: key.baseY - 1.5
        width: key.keyWidth + 3
        height: key.keyHeight + 3
        radius: key.capRadius + 1.5
        color: Qt.rgba(0, 0, 0, key.skin.capShine === 0 ? 0 : 0.45)
    }
    // Zachte slagschaduw: licht van boven, dus naar beneden en iets opzij.
    Repeater {
        model: key.skin.capShine === 0 ? 0 : 3
        Rectangle {
            required property int index
            readonly property real spread: index * Math.max(1, key.depth * 0.25)
            x: key.baseX + (key.depth * 0.2 + key.dxFull * 0.5) * key.reach - spread
            y: key.baseY + (key.frontFacing ? key.depth * 0.9 : key.depth * 0.35) * key.reach - spread * 0.5
            width: key.keyWidth + spread * 2
            height: key.keyHeight + spread
            radius: key.capRadius + spread
            color: Qt.rgba(0, 0, 0, 0.16 - index * 0.04)
        }
    }
    // Zijwanden: laagjes van de voet naar de kap. Op het voorpaneel is dat
    // de bovenkant (licht), bovenop de tafel de voorkant (schaduwzijde).
    Repeater {
        model: Math.max(2, Math.ceil(key.depth * key.reach))
        Rectangle {
            required property int index
            readonly property real t: index / Math.max(1, Math.ceil(key.depth * key.reach))
            readonly property color far: key.frontFacing ? Qt.darker(key.skin.capSide, 1.2) : Qt.darker(key.skin.capSide, 1.45)
            readonly property color near: key.frontFacing ? Qt.darker(key.skin.capB, 1.18) : key.skin.capSide
            x: key.baseX + (key.faceX - key.baseX) * t
            y: key.baseY + (key.faceY - key.baseY) * t
            width: key.keyWidth
            height: key.keyHeight
            radius: key.capRadius
            color: Qt.tint(far, Qt.rgba(near.r, near.g, near.b, t))
        }
    }
    Rectangle {
        id: cap
        x: key.faceX
        y: key.faceY
        width: key.keyWidth
        height: key.keyHeight
        radius: key.capRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: keyMouse.containsMouse ? key.skin.capHover : key.skin.capA }
            GradientStop { position: 1.0; color: key.skin.capB }
        }
        border.width: 1
        border.color: key.lit
            ? key.skin.lit
            : key.skin.capBorder
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }

        // Afgeronde onderrand vangt minder licht.
        Rectangle {
            x: key.capRadius * 0.6
            y: parent.height - 2
            width: parent.width - key.capRadius * 1.2
            height: 1
            color: Qt.rgba(0, 0, 0, key.skin.capShine === 0 ? 0 : 0.18)
        }
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
