import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string text: ""
    property int glyphWidth: 18
    property int glyphHeight: 30
    property int glyphSpacing: 3
    property color segmentOnColor: "white"
    property color segmentOffColor: Qt.rgba(1, 1, 1, 0.2)

    function canvasColor(colorValue) {
        return "rgba("
            + Math.round(colorValue.r * 255) + ", "
            + Math.round(colorValue.g * 255) + ", "
            + Math.round(colorValue.b * 255) + ", "
            + colorValue.a + ")";
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.glyphSpacing

        Repeater {
            model: root.text.length
            delegate: Item {
                property string glyph: root.text.charAt(index)
                implicitWidth: {
                    if (glyph === ":" || glyph === "." || glyph === "°") return Math.max(6, Math.floor(root.glyphWidth * 0.45));
                    return root.glyphWidth;
                }
                implicitHeight: root.glyphHeight

                onGlyphChanged: segmentCanvas.requestPaint()
                onWidthChanged: segmentCanvas.requestPaint()
                onHeightChanged: segmentCanvas.requestPaint()

                Canvas {
                    id: segmentCanvas
                    anchors.fill: parent
                    antialiasing: true
                    smooth: true

                    onPaint: {
                        let ctx = getContext("2d");
                        let w = width;
                        let h = height;
                        let glyphVal = parent.glyph;
                        ctx.reset();
                        ctx.clearRect(0, 0, w, h);

                        function drawRect(x, y, rw, rh, active) {
                            ctx.fillStyle = root.canvasColor(active ? root.segmentOnColor : root.segmentOffColor);
                            ctx.fillRect(Math.round(x), Math.round(y), Math.max(1, Math.round(rw)), Math.max(1, Math.round(rh)));
                        }

                        if (glyphVal === " ") return;

                        if (glyphVal === ":") {
                            let dot = Math.max(2, Math.floor(Math.min(w, h) * 0.34));
                            let cx = Math.floor((w - dot) / 2);
                            drawRect(cx, Math.floor(h * 0.27), dot, dot, true);
                            drawRect(cx, Math.floor(h * 0.67), dot, dot, true);
                            return;
                        }

                        if (glyphVal === ".") {
                            let dot = Math.max(2, Math.floor(Math.min(w, h) * 0.36));
                            let cx = Math.floor((w - dot) / 2);
                            drawRect(cx, h - dot - Math.max(1, Math.floor(h * 0.08)), dot, dot, true);
                            return;
                        }

                        if (glyphVal === "°") {
                            let dot = Math.max(2, Math.floor(Math.min(w, h) * 0.42));
                            let cx = Math.floor((w - dot) / 2);
                            drawRect(cx, Math.max(1, Math.floor(h * 0.12)), dot, dot, true);
                            return;
                        }

                        let segmentsByGlyph = {
                            "0": "abcedf",
                            "1": "bc",
                            "2": "abdeg",
                            "3": "abcdg",
                            "4": "bcfg",
                            "5": "acdfg",
                            "6": "acdefg",
                            "7": "abc",
                            "8": "abcdefg",
                            "9": "abcdfg",
                            "-": "g",
                            "A": "abcefg",
                            "C": "adef",
                            "E": "adefg",
                            "F": "aefg",
                            "P": "abefg"
                        };

                        let upperGlyph = String(glyphVal || "").toUpperCase();
                        let activeSegments = segmentsByGlyph[upperGlyph] || "";
                        function hasSegment(name) { return activeSegments.indexOf(name) !== -1; }

                        let thick = Math.max(2, Math.floor(w * 0.18));
                        let margin = Math.max(1, Math.floor(w * 0.08));
                        let hLen = Math.max(2, w - 2 * (margin + thick));

                        let topY = margin;
                        let midY = Math.floor((h - thick) / 2);
                        let bottomY = h - margin - thick;

                        let vTopY = topY + thick;
                        let vTopH = Math.max(2, midY - vTopY);
                        let vBottomY = midY + thick;
                        let vBottomH = Math.max(2, bottomY - vBottomY);

                        let leftX = margin;
                        let rightX = w - margin - thick;
                        let hX = margin + thick;

                        drawRect(hX, topY, hLen, thick, hasSegment("a"));
                        drawRect(rightX, vTopY, thick, vTopH, hasSegment("b"));
                        drawRect(rightX, vBottomY, thick, vBottomH, hasSegment("c"));
                        drawRect(hX, bottomY, hLen, thick, hasSegment("d"));
                        drawRect(leftX, vBottomY, thick, vBottomH, hasSegment("e"));
                        drawRect(leftX, vTopY, thick, vTopH, hasSegment("f"));
                        drawRect(hX, midY, hLen, thick, hasSegment("g"));
                    }
                }
            }
        }
    }
}
