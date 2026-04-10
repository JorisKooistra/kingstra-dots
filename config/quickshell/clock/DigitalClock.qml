import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var mocha
    readonly property string activeTheme: String(shell.activeThemeName || "").toLowerCase()
    readonly property bool cyberTheme: activeTheme === "cyber"
    readonly property string cyberTimeText: String(shell.timeStr || "--:--")
    readonly property color cyberSegmentOnColor: Qt.lighter(mocha.blue, 1.25)
    readonly property color cyberSegmentOffColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.28)

    implicitWidth: clockLoader.implicitWidth
    implicitHeight: clockLoader.implicitHeight

    Loader {
        id: clockLoader
        anchors.centerIn: parent
        sourceComponent: root.cyberTheme ? cyberClockComponent : defaultClockComponent
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
                color: mocha.blue
                renderType: Text.NativeRendering
            }

            Text {
                text: shell.dateStr
                Layout.alignment: Qt.AlignHCenter
                font.family: shell.uiFontFamily
                font.pixelSize: shell.s(11)
                font.weight: Font.DemiBold
                font.letterSpacing: shell.themeLetterSpacing
                color: mocha.subtext0
                renderType: Text.NativeRendering
            }
        }
    }

    Component {
        id: cyberClockComponent
        ColumnLayout {
            anchors.centerIn: parent
            spacing: shell.s(3)

            RowLayout {
                spacing: shell.s(3)
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: root.cyberTimeText.length
                    delegate: Item {
                        property string glyph: root.cyberTimeText.charAt(index)
                        implicitWidth: glyph === ":" ? shell.s(8) : shell.s(18)
                        implicitHeight: shell.s(30)

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
                                    ctx.fillStyle = active ? root.cyberSegmentOnColor : root.cyberSegmentOffColor;
                                    ctx.fillRect(Math.round(x), Math.round(y), Math.max(1, Math.round(rw)), Math.max(1, Math.round(rh)));
                                }

                                if (glyphVal === ":") {
                                    let dot = Math.max(2, Math.floor(Math.min(w, h) * 0.36));
                                    let cx = Math.floor((w - dot) / 2);
                                    let topDotY = Math.floor(h * 0.28);
                                    let bottomDotY = Math.floor(h * 0.68) - dot;
                                    drawRect(cx, topDotY, dot, dot, true);
                                    drawRect(cx, bottomDotY, dot, dot, true);
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
                                    "-": "g"
                                };
                                let activeSegments = segmentsByGlyph[glyphVal] || "";
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

            Text {
                text: String(shell.dateStr || "").toUpperCase()
                Layout.alignment: Qt.AlignHCenter
                font.family: shell.monoFontFamily
                font.pixelSize: shell.s(9)
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6
                color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.92)
                renderType: Text.NativeRendering
            }
        }
    }
}
