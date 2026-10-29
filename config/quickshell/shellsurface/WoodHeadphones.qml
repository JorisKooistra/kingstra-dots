import QtQuick
import QtQuick.Shapes
import ".."

// Houten koptelefoon als versiering naast de walkman of discman (Organic),
// van bovenaf gezien: twee houten oorschelpen met kussens, een beugel van
// leer op metaal en een snoer. Wordt één keer getekend; DeviceStage legt hem
// in perspectief op tafel.
Item {
    id: phones

    required property var mocha
    property color wood: "#8a5a3a"
    property color metal: "#bbbbbb"
    property color leather: "#3a2a20"

    readonly property real u: width / 100
    // Oorschelpen: links en rechts, iets naar binnen gedraaid.
    readonly property real cup: u * 34

    // Snoer: van de linkerschelp in een losse lus naar rechtsonder.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: Math.max(1.5, phones.u * 1.1)
            strokeColor: Qt.darker(phones.leather, 1.8)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: phones.u * 22; startY: phones.u * 74
            PathCubic {
                x: phones.width * 1.02; y: phones.height * 0.98
                control1X: phones.u * 10; control1Y: phones.height * 1.05
                control2X: phones.u * 70; control2Y: phones.height * 0.72
            }
        }
    }
    // Beugel: metalen band met leer eronder, in een boog over de schelpen.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: phones.u * 8
            strokeColor: phones.leather
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: phones.u * 20; startY: phones.u * 50
            PathArc { x: phones.u * 80; y: phones.u * 50; radiusX: phones.u * 30; radiusY: phones.u * 34 }
        }
        ShapePath {
            strokeWidth: phones.u * 0.5
            strokeColor: Qt.lighter(phones.leather, 1.35)
            strokeStyle: ShapePath.DashLine
            fillColor: "transparent"
            startX: phones.u * 20; startY: phones.u * 50
            PathArc { x: phones.u * 80; y: phones.u * 50; radiusX: phones.u * 30; radiusY: phones.u * 34 }
        }
        ShapePath {
            strokeWidth: phones.u * 1.6
            strokeColor: phones.metal
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: phones.u * 17; startY: phones.u * 52
            PathArc { x: phones.u * 83; y: phones.u * 52; radiusX: phones.u * 33; radiusY: phones.u * 37 }
        }
    }
    Repeater {
        model: [{ x: 6, r: -10 }, { x: 60, r: 10 }]
        Item {
            id: cupItem
            required property var modelData
            x: phones.u * modelData.x
            y: phones.u * 46
            width: phones.cup
            height: phones.cup * 1.18
            rotation: modelData.r
            // Kussen (zacht, donker) onder de houten schaal.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -phones.u * 1.6
                radius: width / 2
                color: Qt.darker(phones.leather, 1.9)
            }
            Extruded {
                anchors.fill: parent
                radius: width / 2
                depth: Math.max(2, phones.u * 2.4)
                faceTop: Qt.lighter(phones.wood, 1.15)
                faceBottom: Qt.darker(phones.wood, 1.15)
                side: Qt.darker(phones.wood, 1.7)
                borderWidth: 1
                borderColor: Qt.darker(phones.wood, 1.8)
            }
            WoodGrain {
                x: 2
                y: -Math.max(2, phones.u * 2.4) + 2
                width: parent.width - 4
                height: parent.height - 4
                radius: width / 2
                dark: phones.mocha.crust
                light: phones.mocha.text
                seed: 5 + cupItem.modelData.x
                strength: 0.9
            }
            // Metalen logo-ringetje in het midden.
            Rectangle {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Math.max(2, phones.u * 2.4)
                width: parent.width * 0.26
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1, phones.u * 0.8)
                border.color: phones.metal
            }
        }
    }
}
