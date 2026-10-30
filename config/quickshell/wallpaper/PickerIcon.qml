import QtQuick
import QtQuick.Shapes

// Small vector icons stay legible regardless of the installed icon font.
Shape {
    id: icon
    property string name: "download"
    property color color: "white"
    implicitWidth: 20
    implicitHeight: 20
    layer.enabled: false
    ShapePath {
        strokeColor: icon.color
        strokeWidth: 1.7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg {
            path: icon.name === "trash" ? "M4 6 L16 6 M8 3 L12 3 L13 6 M6 6 L7 17 L13 17 L14 6 M9 9 L9 14 M11 9 L11 14" : icon.name === "apply" ? "M3 4 L17 4 L17 14 L3 14 Z M7 18 L13 18 M10 14 L10 18 M6 9 L9 12 L14 7" : icon.name === "check" ? "M4 10 L8 14 L16 5" : "M10 2 L10 13 M6 9 L10 13 L14 9 M3 13 L3 17 L17 17 L17 13"
        }
    }
}
