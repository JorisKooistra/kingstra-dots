import QtQuick
import ".."

// Uitgetrokken vorm voor de draaitafel, met dezelfde 3D-regels als DeckKey:
// een voetafdruk (dit item), zijwanden in laagjes en een kap die `depth`
// pixels uitsteekt. Bovenop de tafel (frontFacing uit) staat de kap hoger in
// beeld en zie je de voorkant; op het voorpaneel steekt hij naar je toe en
// zie je de bovenkant. lean (-1..1) laat bij plaatsing links of rechts van
// het midden ook een zijkant zien. Licht komt van boven, de schaduw valt
// naar beneden. Iets op de kap leggen: zet het naast dit item op
// x + dx, y + dy (dan beweegt het mee bij indrukken).
Item {
    id: ex

    property real radius: 4
    property real depth: 4
    property bool frontFacing: false
    property real lean: 0
    // 0 = uit, 1 = helemaal ingedrukt.
    property real press: 0
    // Plat (Paper): geen schaduw en geen zijwanden.
    property bool flat: false
    property bool recess: false
    property color faceTop: "#dddddd"
    property color faceBottom: "#bbbbbb"
    property color side: "#777777"
    property real borderWidth: 0
    property color borderColor: "transparent"
    property real shadowStrength: 1

    readonly property real reach: flat ? 0 : 1 - 0.75 * press
    readonly property real dx: lean * depth * 0.6 * reach
    readonly property real dy: (frontFacing ? depth : -depth) * reach

    Rectangle {
        visible: ex.recess && !ex.flat
        x: -1.5
        y: -1.5
        width: ex.width + 3
        height: ex.height + 3
        radius: ex.radius + 1.5
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Repeater {
        model: ex.flat ? 0 : 3
        Rectangle {
            required property int index
            readonly property real spread: index * Math.max(1, ex.depth * 0.25)
            x: (ex.depth * 0.2 + ex.dx * 0.5 / Math.max(0.01, ex.reach)) * ex.reach - spread
            y: (ex.frontFacing ? ex.depth * 0.9 : ex.depth * 0.35) * ex.reach - spread * 0.5
            width: ex.width + spread * 2
            height: ex.height + spread
            radius: ex.radius + spread
            color: Qt.rgba(0, 0, 0, (0.16 - index * 0.04) * ex.shadowStrength)
        }
    }
    Repeater {
        model: ex.flat ? 0 : Math.max(2, Math.ceil(ex.depth * ex.reach))
        Rectangle {
            required property int index
            readonly property real t: index / Math.max(1, Math.ceil(ex.depth * ex.reach))
            readonly property color far: ex.frontFacing ? Qt.darker(ex.side, 1.2) : Qt.darker(ex.side, 1.45)
            readonly property color near: ex.frontFacing ? Qt.darker(ex.faceBottom, 1.18) : ex.side
            x: ex.dx * t
            y: ex.dy * t
            width: ex.width
            height: ex.height
            radius: ex.radius
            color: Qt.tint(far, Qt.rgba(near.r, near.g, near.b, t))
        }
    }
    Rectangle {
        id: face
        x: ex.dx
        y: ex.dy
        width: ex.width
        height: ex.height
        radius: ex.radius
        border.width: ex.borderWidth
        border.color: ex.borderColor
        gradient: Gradient {
            GradientStop { position: 0.0; color: ex.faceTop }
            GradientStop { position: 1.0; color: ex.faceBottom }
        }
        // Glans langs de bovenrand en een iets donkerdere onderrand.
        Rectangle {
            visible: !ex.flat && ex.height >= 8
            x: Math.min(ex.radius * 0.6, parent.width * 0.25)
            y: 1
            width: parent.width - 2 * x
            height: 1
            color: Qt.rgba(1, 1, 1, 0.35)
        }
        Rectangle {
            visible: !ex.flat && ex.height >= 8
            x: Math.min(ex.radius * 0.6, parent.width * 0.25)
            y: parent.height - 2
            width: parent.width - 2 * x
            height: 1
            color: Qt.rgba(0, 0, 0, 0.2)
        }
    }
}
