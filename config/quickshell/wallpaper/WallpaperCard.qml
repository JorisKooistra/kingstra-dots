import QtQuick
import QtQuick.Controls
import "PickerLogic.js" as Logic

Item {
    id: card
    required property var itemData
    required property var colors
    property string shape: "wall"
    property bool selected: false
    property bool current: false
    property var thumbnail: ({})
    property url shaderSource: ""
    property url vertexSource: ""
    property real curveX: 0
    property real curveViewportWidth: 0
    property real curveAmount: 0
    property bool interactiveHover: true
    property bool remote: false
    property bool actionBusy: false
    property bool removable: false
    readonly property int actionSize: width < 150 ? (shape === "hex" ? 24 : 26) : 32
    readonly property int actionRows: width < 150 && shape !== "hex" ? (itemData.path ? 3 : 2) : 1
    readonly property int actionsHeight: actionRows * actionSize + (actionRows - 1) * 4
    readonly property bool hovered: interactiveHover && (input.containsMouse || applyButton.hovered || downloadButton.hovered || removeButton.hovered)
    readonly property bool highlighted: selected || hovered
    readonly property bool captionVisible: highlighted || current || itemData.favorite === true
    property string fontFamily: "Sans Serif"
    signal picked
    signal favoriteRequested
    signal applyRequested
    signal downloadRequested
    signal removeRequested
    readonly property string imageSource: thumbnail.thumb || itemData.thumb || ""
    function inspect() {
        return {
            source: imageSource,
            image: image.status,
            shader: effect.status,
            log: effect.log,
            width: width,
            height: height
        };
    }
    function bend(x) {
        if (!curveViewportWidth)
            return 0;
        let normalized = (curveX + x - curveViewportWidth / 2) / (curveViewportWidth / 2);
        return -normalized * normalized * curveAmount;
    }

    // The image texture goes straight into the shape shader: no offscreen
    // layers, Canvas masks or full-size original images per card.
    Image {
        id: image
        visible: false
        source: card.imageSource
        asynchronous: true
        cache: true
        sourceSize.width: 768
        sourceSize.height: 480
    }
    Image {
        id: placeholder
        visible: false
        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1" fill="' + String(card.colors.surfaceContainerHigh) + '"/></svg>')
    }
    ShaderEffect {
        id: effect
        anchors.fill: parent
        visible: image.status === Image.Ready || placeholder.status === Image.Ready
        property var source: image.status === Image.Ready ? image : placeholder
        property vector2d cardSize: Qt.vector2d(width, height)
        readonly property real sourceAspect: Math.max(1, image.implicitWidth) / Math.max(1, image.implicitHeight)
        readonly property real targetAspect: Math.max(1, width) / Math.max(1, height)
        property vector2d cropScale: Qt.vector2d(Math.min(1, targetAspect / sourceAspect), Math.min(1, sourceAspect / targetAspect))
        property color accent: card.colors.primary
        property real shapeKind: card.shape === "hex" ? 2 : (card.shape === "slices" ? 1 : 0)
        property real borderWidth: card.highlighted ? 3 : (card.current ? 1 : 0)
        property real imageOpacity: card.highlighted ? 1 : 0.8
        property vector4d curveParams: Qt.vector4d(card.curveX, card.curveViewportWidth, card.curveAmount, 0)
        mesh: GridMesh {
            resolution: card.curveViewportWidth ? Qt.size(12, 6) : Qt.size(1, 1)
        }
        fragmentShader: card.shaderSource
        vertexShader: card.vertexSource
    }
    MouseArea {
        id: input
        width: card.width
        y: Math.min(0, card.bend(0), card.bend(card.width))
        height: card.height - y
        hoverEnabled: true
        containmentMask: QtObject {
            function contains(point: point): bool {
                return Logic.contains(card.shape, point.x, point.y + input.y - card.bend(point.x), card.width, card.height);
            }
        }
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                card.favoriteRequested();
            else
                card.picked();
        }
        // The first click has already activated this picture. A double click
        // must not submit a second download or wallpaper change.
        onDoubleClicked: event => event.accepted = true
        Grid {
            x: (card.width - width) / 2
            y: 10 + card.bend(card.width / 2) - input.y
            columns: card.width < 150 && card.shape !== "hex" ? 1 : (card.itemData.path ? 3 : 2)
            spacing: 4
            // Keep the centre of small cards clickable. The persistent footer
            // and preview provide the same actions when inline icons won't fit.
            visible: card.remote && card.height > 2 * (10 + card.actionsHeight) + 16 && (card.hovered || card.selected)
            PickerIconButton {
                id: applyButton
                width: card.actionSize
                height: width
                objectName: "wallpaper-apply"
                colors: card.colors
                icon: "apply"
                label: card.current ? "Al ingesteld" : "Instellen"
                available: !card.actionBusy && !card.current
                selected: card.current
                onClicked: card.applyRequested()
            }
            PickerIconButton {
                id: downloadButton
                width: card.actionSize
                height: width
                objectName: "wallpaper-download"
                colors: card.colors
                icon: card.itemData.path ? "check" : "download"
                label: card.itemData.path ? "Opgeslagen in je collectie" : "Downloaden"
                available: !card.actionBusy && !card.itemData.path
                onClicked: card.downloadRequested()
            }
            PickerIconButton {
                id: removeButton
                width: card.actionSize
                height: width
                objectName: "wallpaper-remove"
                colors: card.colors
                icon: "trash"
                label: card.removable ? "Naar prullenbak" : "Deze wallpaper is actief"
                visible: !!card.itemData.path
                available: !card.actionBusy && card.removable
                onClicked: card.removeRequested()
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: card.horizontalCenter
        anchors.bottom: card.bottom
        anchors.bottomMargin: (card.shape === "hex" ? 20 : 14) - card.bend(card.width / 2)
        width: Math.min(card.width - 32, caption.implicitWidth + 24)
        height: 28
        radius: 10
        color: card.colors.surface
        visible: card.captionVisible
        Text {
            id: caption
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 16)
            text: (card.current ? "✓  " : "") + (card.itemData.favorite ? "♥  " : "") + (card.itemData.displayName || card.itemData.name)
            textFormat: Text.PlainText
            color: card.colors.text
            elide: Text.ElideMiddle
            font.pixelSize: 11
            font.family: card.fontFamily
        }
    }
}
