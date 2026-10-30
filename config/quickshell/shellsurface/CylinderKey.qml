import QtQuick
import ".."

// Ronde knop die rechtop op een bovenvlak staat, zoals bovenop een
// draagbare cassettespeler: een cilinder van voren-boven gezien. De kap is
// een ellips (k = hoe plat het bovenvlak in beeld staat), de zijkant is
// rond belicht en zakt in bij indrukken. Vergrendeld (play) blijft hij half
// ingedrukt staan.
Item {
    id: key

    // Straal van de knop en hoogte van de cilinder, in pixels.
    property real r: 20
    property real k: 0.45
    property real h: 12
    property string icon: ""
    property bool lit: false
    property bool latched: false
    property bool flat: false
    property color capA: "#dddddd"
    property color capB: "#aaaaaa"
    property color side: "#888888"
    property color border: Qt.rgba(0, 0, 0, 0.3)
    property color iconColor: "#222222"
    property color litColor: "orange"
    property real viewLean: 0
    signal activated()
    readonly property alias down: mouse.pressed

    property real press: mouse.pressed ? 1 : latched ? 0.6 : 0
    Behavior on press { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
    readonly property real lift: h * (1 - 0.75 * press)
    readonly property real ry: r * k
    // Bodem en kap: middelpunten van de ellipsen.
    readonly property real baseY: h + ry
    readonly property real capY: baseY - lift
    readonly property real shiftX: viewLean * lift * 0.5

    width: 2 * r
    height: 2 * ry + h
    opacity: enabled ? 1 : 0.4

    // Slagschaduw op het bovenvlak (licht van linksboven).
    Item {
        visible: !key.flat
        x: key.lift * 0.35
        y: key.baseY - key.ry + key.lift * 0.1
        width: 2 * key.r
        height: 2 * key.r
        transform: Scale { yScale: key.k }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.28)
        }
    }
    // Opening in het bovenvlak.
    Item {
        x: -1.5
        y: key.baseY - key.ry - 1.5 * key.k
        width: 2 * key.r + 3
        height: width
        transform: Scale { yScale: key.k }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: key.flat ? "transparent" : Qt.rgba(0, 0, 0, 0.5)
            border.width: key.flat ? 1.5 : 0
            border.color: key.border
        }
    }
    // Onderste ellips en de ronde zijkant.
    Item {
        x: key.shiftX
        y: key.baseY - key.ry
        width: 2 * key.r
        height: 2 * key.r
        transform: Scale { yScale: key.k }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.darker(key.side, key.flat ? 1 : 1.25)
            border.width: key.flat ? 1.5 : 0
            border.color: key.border
        }
    }
    Rectangle {
        x: key.shiftX
        y: key.capY
        width: 2 * key.r
        height: key.baseY - key.capY
        border.width: key.flat ? 1.5 : 0
        border.color: key.border
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.darker(key.side, key.flat ? 1 : 1.5) }
            GradientStop { position: 0.32; color: key.flat ? key.side : Qt.lighter(key.side, 1.35) }
            GradientStop { position: 0.6; color: key.side }
            GradientStop { position: 1.0; color: Qt.darker(key.side, key.flat ? 1 : 1.7) }
        }
    }
    // Kap.
    Item {
        x: key.shiftX
        y: key.capY - key.ry
        width: 2 * key.r
        height: 2 * key.r
        transform: Scale { yScale: key.k }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            border.width: key.lit ? Math.max(1.5, key.r * 0.08) : key.flat ? 1.5 : 1
            border.color: key.lit ? key.litColor : key.border
            gradient: Gradient {
                GradientStop { position: 0.0; color: mouse.containsMouse ? Qt.lighter(key.capA, 1.08) : key.capA }
                GradientStop { position: 1.0; color: key.capB }
            }
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            // Fijne draairing op de kap (geborsteld).
            Rectangle {
                visible: !key.flat
                anchors.centerIn: parent
                width: parent.width * 0.72
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)
            }
            Text {
                anchors.centerIn: parent
                text: key.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: key.r * 0.8
                color: key.lit ? key.litColor : key.iconColor
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.activated()
    }
}
