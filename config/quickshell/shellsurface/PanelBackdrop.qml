import QtQuick
import Kingstra.Blobs 1.0
import ".."

Rectangle {
    id: root
    required property bool open
    required property var mocha
    property bool squareCorners: false
    // Vlak op de schermrand landen: onderhoeken vierkant en de barkleur
    // overnemen, zodat het paneel uit de omlijning lijkt te groeien.
    property bool flushBottom: false
    property string edge: flushBottom ? "bottom" : ""
    property color fillOverride: "transparent"
    property color fillStartOverride: "transparent"
    property color fillEndOverride: "transparent"
    property color borderOverride: "transparent"
    property color borderStartOverride: "transparent"
    property color borderEndOverride: "transparent"
    property int bottomConnectorRadius: Math.max(14, ThemeConfig.styleWidgetRadius + 8)
    property int bottomConnectorLift: 0
    property int sideConnectorOverlap: 0
    property var blobGroup: null
    readonly property string _styleFamily: String(ThemeConfig.styleFamily || "").toLowerCase()
    readonly property bool _paperStyle: _styleFamily === "paper"
    readonly property bool _monoStyle: _styleFamily === "mono"
    readonly property bool _neonStyle: _styleFamily === "neon"
    readonly property color _paperBase: "#f6ecd6"
    readonly property bool nativeBlob: edge !== "" && blobGroup !== null
    readonly property var nativeDeformMatrix: nativePanelBlob.deformMatrix
    readonly property int edgeOverlap: nativeBlob
        ? (edge === "left" || edge === "right"
            ? Math.max(sideConnectorOverlap, _strokeW + 2)
            : Math.max(bottomConnectorRadius,
                       edge === "top" ? ThemeConfig.barStatusStripHeight : bottomConnectorRadius,
                       _strokeW + 2))
        : (_strokeW + 2)

    // Zelfde matugen-tint als de bar-chrome: mantle/crust is in veel paletten
    // bijna zwart, waardoor panelen ongethematiseerd oogden naast de bar.
    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       1.0);
    }
    readonly property color _baseFill: _paperStyle ? _paperBase
        : (_monoStyle || _neonStyle ? mocha.crust : mocha.mantle)
    readonly property color _tintColor: _paperStyle ? (mocha.accent2Container || mocha.accent2)
        : (_monoStyle ? mocha.text : (_neonStyle ? mocha.blue : (mocha.accent3Container || mocha.primary)))
    readonly property color _tinted: _mix(_baseFill, _tintColor, _paperStyle ? 0.06 : (_monoStyle ? 0.0 : (_neonStyle ? 0.22 : 0.18)))
    readonly property color _defaultFill: fillOverride.a > 0
        ? fillOverride
        : Qt.rgba(_tinted.r, _tinted.g, _tinted.b, _monoStyle ? 1.0 : ThemeConfig.popupOpacity)
    readonly property color _fillStart: fillStartOverride.a > 0 ? fillStartOverride : _defaultFill
    readonly property color _fillEnd: fillEndOverride.a > 0 ? fillEndOverride : _defaultFill
    readonly property color _borderColor: _monoStyle ? mocha.text
        : (_paperStyle ? (mocha.accent2Container || mocha.text) : (_neonStyle ? mocha.teal : mocha.accent1))
    readonly property color _defaultBorder: borderOverride.a > 0
        ? borderOverride
        : Qt.rgba(_borderColor.r, _borderColor.g, _borderColor.b, _monoStyle ? 0.34 : (_paperStyle ? 0.30 : (_neonStyle ? 0.54 : 0.32)))
    readonly property color _borderStart: borderStartOverride.a > 0 ? borderStartOverride : _defaultBorder
    readonly property color _borderEnd: borderEndOverride.a > 0 ? borderEndOverride : _defaultBorder
    readonly property int _strokeW: (flushBottom || nativeBlob) ? 2 : border.width

    anchors.fill: parent
    // Bij flushBottom rekt het vlak onder de host uit; PanelHost clipt, dus de
    // onderste randlijn valt weg. Zo loopt de accentrand alleen over de top en
    // de zijkanten, en sluit hij aan op de bogen in de omlijning.
    anchors.leftMargin: edge === "left" ? -edgeOverlap : 0
    anchors.rightMargin: edge === "right" ? -edgeOverlap : 0
    anchors.topMargin: edge === "top" ? -edgeOverlap : 0
    anchors.bottomMargin: (edge === "bottom" || flushBottom) ? -edgeOverlap : 0
    radius: squareCorners || _monoStyle ? 0
        : (_paperStyle ? Math.max(8, ThemeConfig.styleWidgetRadius + 2)
            : Math.max(14, ThemeConfig.styleWidgetRadius + 8))
    topLeftRadius: radius
    topRightRadius: radius
    bottomLeftRadius: edge === "bottom" || edge === "left" ? 0 : radius
    bottomRightRadius: edge === "bottom" || edge === "right" ? 0 : radius
    color: nativeBlob ? "transparent" : _defaultFill
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.nativeBlob ? "transparent" : root._fillStart }
        GradientStop { position: 1.0; color: root.nativeBlob ? "transparent" : root._fillEnd }
    }
    border.width: nativeBlob || flushBottom ? 0 : 1
    border.color: _defaultBorder
    opacity: open ? 1.0 : 0.0
    scale: flushBottom ? 1.0 : (open ? 1.0 : 0.98)

    BlobRect {
        id: nativePanelBlob

        anchors.fill: parent
        visible: root.nativeBlob
        group: root.blobGroup
        radius: root.radius
        topLeftRadius: root.edge === "top" || root.edge === "left" ? 0 : -1
        topRightRadius: root.edge === "top" || root.edge === "right" ? 0 : -1
        bottomLeftRadius: root.edge === "bottom" || root.edge === "left" ? 0 : -1
        bottomRightRadius: root.edge === "bottom" || root.edge === "right" ? 0 : -1
        deformScale: 0.00001
    }

    // De accentrand van een native blob komt volledig uit de blob-shader (band
    // op de samengesmolten SDF). De vroegere Canvas-outline hier tekende er
    // een losse rechthoek overheen en is verwijderd.

    Rectangle {
        visible: root.flushBottom && !root.nativeBlob
        z: 3
        x: root.radius
        y: 0
        width: Math.max(0, root.width - root.radius * 2)
        height: root._strokeW
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root._borderStart }
            GradientStop { position: 1.0; color: root._borderEnd }
        }
    }

    TopCornerStroke {
        visible: root.flushBottom && !root.nativeBlob
        z: 3
        mirrorH: false
        strokeColor: root._borderStart
    }

    TopCornerStroke {
        visible: root.flushBottom && !root.nativeBlob
        z: 3
        mirrorH: true
        strokeColor: root._borderEnd
    }

    Rectangle {
        visible: root.flushBottom && !root.nativeBlob
        z: 3
        x: 0
        y: root.radius
        width: root._strokeW
        height: Math.max(0, root.height - root.radius - root.bottomConnectorRadius - root.bottomConnectorLift)
        color: root._borderStart
    }

    Rectangle {
        visible: root.flushBottom && !root.nativeBlob
        z: 3
        width: root._strokeW
        x: root.width - width
        y: root.radius
        height: Math.max(0, root.height - root.radius - root.bottomConnectorRadius - root.bottomConnectorLift)
        color: root._borderEnd
    }

    // The bar chrome draws the curved connector into a flush-bottom panel.
    // Hide the straight panel sides inside that connector zone, otherwise the
    // launcher reads as a separate rectangle sitting on top of the bar.
    Rectangle {
        visible: root.flushBottom && !root.nativeBlob
        z: 2
        x: 0
        y: Math.max(0, root.height - root.bottomConnectorRadius - root.bottomConnectorLift - root._strokeW)
        width: root._strokeW + 1
        height: root.height - y
        color: root._fillStart
    }

    Rectangle {
        visible: root.flushBottom && !root.nativeBlob
        z: 2
        width: root._strokeW + 1
        x: root.width - width
        y: Math.max(0, root.height - root.bottomConnectorRadius - root.bottomConnectorLift - root._strokeW)
        height: root.height - y
        color: root._fillEnd
    }

    Behavior on opacity {
        NumberAnimation { duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("standard") }
    }
    Behavior on scale {
        enabled: !root.flushBottom
        NumberAnimation { duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("emphasized") }
    }

    component TopCornerStroke: Canvas {
        id: corner
        property bool mirrorH: false
        property color strokeColor: root._defaultBorder

        width: root.radius
        height: root.radius
        x: mirrorH ? root.width - root.radius : 0
        y: 0
        antialiasing: true

        onMirrorHChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            let r = root.radius;
            let half = root._strokeW / 2;
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.save();
            if (corner.mirrorH) {
                ctx.translate(r, 0);
                ctx.scale(-1, 1);
            }
            ctx.beginPath();
            ctx.arc(r, r, Math.max(0, r - half), Math.PI, Math.PI * 1.5, false);
            ctx.strokeStyle = corner.strokeColor;
            ctx.lineWidth = root._strokeW;
            ctx.lineCap = "butt";
            ctx.stroke();
            ctx.restore();
        }
    }
}
