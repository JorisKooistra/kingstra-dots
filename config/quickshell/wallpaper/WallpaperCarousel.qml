import QtQuick
import "PickerLogic.js" as Logic

// One camera; a small ring of reused columns. ListView's layout/highlight and
// flick corrections cannot write back into the camera. Geometry, colour order
// and timing are based on skwd v1; see SKWD-LICENSE.txt.
Item {
    id: carousel
    required property var controller
    required property var colors
    clip: true
    readonly property string mode: controller.mode
    readonly property var layout: controller.pickerLayout || ({})
    readonly property bool hex: mode === "hex"
    readonly property bool coverflow: mode === "coverflow"
    readonly property bool orbit: mode === "orbit"
    readonly property bool looping: controller.sourceTab === "local"
    readonly property int rows: hex ? Math.max(1, Math.min(5, layout.hexRows || 2)) : (mode === "mosaic" ? 2 : 1)
    readonly property int baseColumns: Math.ceil(controller.items.length / rows)
    readonly property real gap: 6
    readonly property int visibleColumns: Math.max(3, layout.hexCols || 9)
    readonly property real arcIntensity: hex ? (layout.hexArc === false ? 0 : (layout.hexArcIntensity === undefined ? 1.2 : layout.hexArcIntensity)) : 0
    readonly property real radius: Math.max(16, Math.min(layout.hexRadius || 140, (height - 36) / (Math.sqrt(3) * (rows + 0.5) + arcIntensity), (width - 32 - (visibleColumns - 1) * gap) / (1.5 * (visibleColumns - 1) + 2)))
    readonly property real hexWidth: 2 * radius
    readonly property real hexHeight: Math.sqrt(3) * radius
    readonly property real stepX: 1.5 * radius + gap
    readonly property real stepY: hexHeight + gap
    readonly property real gridHeight: rows * hexHeight + (rows - 1) * gap + hexHeight / 2
    readonly property real arcHeight: radius * arcIntensity
    readonly property real hexY: (height - gridHeight + arcHeight) / 2
    readonly property real sliceExpanded: Math.min(width * 0.48, 680)
    readonly property real mosaicHeight: Math.min(height * 0.44, 245)
    readonly property real coverWidth: orbit ? Math.min(490, width * 0.38, height * 1.1) : Math.min(680, width * 0.48, height * 1.5)
    readonly property real pitch: hex ? stepX : (coverflow || orbit ? coverWidth * 0.46 : (mode === "slices" ? 112 + (layout.sliceSpacing === undefined ? -30 : layout.sliceSpacing) : Math.min(370, width * 0.3) + 12))
    readonly property real cardWidth: hex ? hexWidth : (coverflow || orbit ? coverWidth : (mode === "slices" ? 112 : Math.min(370, width * 0.3)))
    readonly property real origin: (width - cardWidth) / 2
    readonly property int visualIndex: Math.round(cameraX / pitch)
    readonly property int poolSize: Math.ceil(width / pitch) + 10
    readonly property int firstColumn: Math.floor(cameraX / pitch) - Math.ceil(poolSize / 2)
    readonly property real contentX: cameraX
    readonly property bool moving: motion.running || drag.active
    property real cameraX: 0
    property real targetX: 0
    property bool initialized: false
    property bool snapping: false
    property bool animateCamera: true
    property int selectionRow: 0
    property var modelKeys: []
    property bool tracing: false
    property var frameSamples: []
    property var lastWheel: ({})

    function screenOffset(screenX) {
        let half = Math.max(1, width / 2), normalized = (screenX - half) / half;
        return hex ? half * 0.14 * normalized * normalized * normalized : 0;
    }
    function cellY(column, row) {
        return hexY + row * stepY + Logic.modulo(column, 2) * hexHeight / 2;
    }
    function limited(x) {
        return looping ? x : Math.max(0, Math.min(Math.max(0, baseColumns - 1) * pitch, x));
    }
    function syncSelection() {
        if (!initialized || snapping || !baseColumns || controller.previewOpen)
            return;
        let col = looping ? Logic.modulo(visualIndex, baseColumns) : Math.max(0, Math.min(baseColumns - 1, visualIndex));
        controller.selected = col * rows + Math.min(selectionRow, controller.items.length - col * rows - 1);
    }
    onCameraXChanged: syncSelection()
    function moveTo(x, animate) {
        targetX = limited(x);
        if (animate === false) {
            animateCamera = false;
            cameraX = targetX;
            animateCamera = true;
        } else
            cameraX = targetX;
    }
    function pause() {
        moveTo(cameraX, false);
    }
    function positionSelected(animate) {
        if (!baseColumns || width <= 0 || height <= 0)
            return;
        let col = Math.floor(Math.max(0, controller.selected) / rows);
        selectionRow = Logic.modulo(controller.selected, rows);
        if (looping && initialized)
            col += Math.round((targetX / pitch - col) / baseColumns) * baseColumns;
        if (!initialized || animate === false) {
            snapping = true;
            moveTo(col * pitch, false);
            initialized = true;
            snapTimer.restart();
        } else {
            moveTo(col * pitch, true);
            syncSelection();
        }
    }
    function navigateColumns(delta) {
        selectionRow = Logic.modulo(controller.selected, rows);
        moveTo((Math.round(targetX / pitch) + delta) * pitch, true);
        syncSelection();
    }
    function reset() {
        initialized = false;
        Qt.callLater(function () {
            positionSelected(false);
        });
    }
    function modelChanged() {
        let keys = controller.items.map(item => item.id || item.path || item.name);
        let appendOnly = !looping && modelKeys.length > 0 && keys.length >= modelKeys.length && modelKeys.every((key, i) => keys[i] === key);
        let same = keys.length === modelKeys.length && keys.every((key, i) => key === modelKeys[i]);
        modelKeys = keys;
        if (!same && !appendOnly)
            reset();
    }
    function scrollInput(event) {
        event.accepted = true;
        if (!baseColumns)
            return;
        let pixels = event.pixelDelta ? (event.pixelDelta.y || event.pixelDelta.x) : 0;
        let angle = event.angleDelta.y || event.angleDelta.x;
        let gesture = event.phase !== undefined && event.phase !== Qt.NoScrollPhase;
        let factor = Math.max(0.01, controller.wheelFactor || 1);
        let delta = pixels && (!angle || gesture) ? -pixels : -angle / (120 * factor) * pitch * (hex ? Math.max(1, layout.hexScrollStep || 1) : 1);
        if (tracing)
            lastWheel = {
                pixels: pixels,
                angle: angle,
                phase: event.phase,
                delta: delta
            };
        if (delta) {
            moveTo(targetX + delta, true);
            syncSelection();
        }
    }
    function nearEnd() {
        return cameraX / pitch > baseColumns - Math.ceil(width / pitch) - 3;
    }
    function selectionPoint() {
        let base = Math.floor(controller.selected / rows);
        let virtual = looping ? base + Math.round((visualIndex - base) / Math.max(1, baseColumns)) * baseColumns : base;
        let slot = Logic.modulo(virtual, poolSize), column = pool.itemAt(slot);
        return column ? column.cardPoint(Logic.modulo(controller.selected, rows)) : {
            x: -1,
            y: -1
        };
    }
    function inspect() {
        let currentColumn = pool.itemAt(Logic.modulo(visualIndex, poolSize));
        return {
            currentWidth: currentColumn ? currentColumn.visualWidth : 0,
            contentX: cameraX,
            targetX: targetX,
            visualIndex: visualIndex,
            moving: moving,
            radius: radius,
            hexWidth: hexWidth,
            hexHeight: hexHeight,
            stepX: stepX,
            stepY: stepY,
            stagger: hexHeight / 2,
            curve: arcHeight,
            delegates: pool.count,
            lastWheel: lastWheel,
            selectionPoint: selectionPoint()
        };
    }
    function trace(enabled) {
        frameSamples = [];
        tracing = enabled;
    }
    onModeChanged: reset()
    onWidthChanged: reset()
    onHeightChanged: reset()
    Connections {
        target: carousel.controller
        function onItemsChanged() {
            carousel.modelChanged();
        }
    }
    Timer {
        id: snapTimer
        interval: 20
        onTriggered: {
            carousel.snapping = false;
            carousel.syncSelection();
        }
    }
    Behavior on cameraX {
        enabled: carousel.initialized && carousel.animateCamera && !carousel.snapping && !drag.active
        SmoothedAnimation {
            id: motion
            duration: 300
            velocity: -1
            maximumEasingTime: 120
            reversingMode: SmoothedAnimation.Eased
        }
    }
    FrameAnimation {
        running: carousel.tracing
        onTriggered: {
            if (carousel.frameSamples.length < 1600)
                carousel.frameSamples.push({
                    t: Date.now(),
                    x: carousel.cameraX,
                    target: carousel.targetX,
                    selected: carousel.controller.selected,
                    dt: frameTime * 1000
                });
        }
    }
    WheelHandler {
        target: null
        blocking: true
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => carousel.scrollInput(event)
    }
    DragHandler {
        id: drag
        target: null
        yAxis.enabled: false
        property real start: 0
        onActiveChanged: {
            if (active) {
                carousel.pause();
                start = carousel.cameraX;
            } else if (Math.abs(centroid.velocity.x) > 70)
                carousel.moveTo(carousel.cameraX - centroid.velocity.x * 0.12, true);
        }
        onTranslationChanged: {
            if (active)
                carousel.moveTo(start - translation.x, false);
        }
    }
    Repeater {
        id: pool
        model: carousel.baseColumns ? carousel.poolSize : 0
        delegate: Item {
            id: column
            required property int index
            readonly property int virtualIndex: carousel.firstColumn + Logic.modulo(index - carousel.firstColumn, carousel.poolSize)
            readonly property int baseIndex: carousel.looping ? Logic.modulo(virtualIndex, carousel.baseColumns) : virtualIndex
            visible: baseIndex >= 0 && baseIndex < carousel.baseColumns && (!carousel.orbit || Math.abs(distance) < 6)
            x: carousel.orbit ? carousel.origin + Math.sin(distance * 0.53) * carousel.width * 0.37 : carousel.origin + virtualIndex * carousel.pitch - carousel.cameraX
            width: carousel.coverflow || carousel.orbit ? carousel.cardWidth : carousel.pitch
            height: carousel.height
            readonly property real distance: virtualIndex - carousel.cameraX / carousel.pitch
            z: carousel.coverflow || carousel.orbit ? 100 - Math.abs(distance) : 0
            readonly property real centerX: x + carousel.hexWidth / 2
            readonly property real spacingOffset: carousel.screenOffset(centerX)
            readonly property real side: centerX < carousel.width / 2 ? -1 : 1
            readonly property real edgeDistance: Math.abs(centerX + spacingOffset - carousel.width / 2)
            readonly property real coreHalf: carousel.width / 2 - carousel.hexWidth * 0.7
            readonly property real flight: carousel.hex ? Math.max(0, Math.min(1, (edgeDistance - coreHalf) / (carousel.hexWidth * 0.9))) : 0
            readonly property real flightEase: flight * flight * (3 - 2 * flight)
            scale: carousel.orbit ? 1 - Math.min(0.48, Math.abs(distance) * 0.12) : (carousel.coverflow ? 1 - Math.min(0.35, Math.abs(distance) * 0.14) : 1 - flightEase)
            opacity: carousel.coverflow || carousel.orbit ? Math.max(0, 1 - Math.max(0, Math.abs(distance) - 2) * 0.25) : 1 - flightEase
            transformOrigin: carousel.coverflow || carousel.orbit ? Item.Center : (side < 0 ? Item.Left : Item.Right)
            transform: [Translate {
                x: column.spacingOffset + column.side * column.flightEase * carousel.radius * 0.4
                y: carousel.orbit ? -(1 - Math.cos(column.distance * 0.53)) * carousel.height * 0.18 : -column.flightEase * carousel.radius * 0.25
            }, Rotation {
                origin.x: carousel.cardWidth / 2
                origin.y: carousel.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: carousel.orbit ? -Math.max(-65, Math.min(65, column.distance * 24)) : (carousel.coverflow ? -Math.max(-1, Math.min(1, column.distance)) * 52 : 0)
            }]
            property real visualWidth: carousel.mode === "slices" && virtualIndex === carousel.visualIndex ? carousel.sliceExpanded : carousel.cardWidth
            property real cardOffset: carousel.mode === "slices" ? (virtualIndex <= carousel.visualIndex ? -1 : 1) * (carousel.sliceExpanded - 112) / 2 : 0
            Behavior on visualWidth {
                enabled: carousel.initialized && !carousel.snapping && carousel.mode === "slices"
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on cardOffset {
                enabled: carousel.initialized && !carousel.snapping && carousel.mode === "slices"
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            function cardPoint(row) {
                let card = cards.itemAt(row);
                return card ? card.mapToItem(carousel, card.width / 2, card.height / 2 + card.bend(card.width / 2)) : {
                    x: -1,
                    y: -1
                };
            }
            Repeater {
                id: cards
                model: column.visible ? Math.max(0, Math.min(carousel.rows, carousel.controller.items.length - column.baseIndex * carousel.rows)) : 0
                WallpaperCard {
                    required property int index
                    readonly property int flatIndex: column.baseIndex * carousel.rows + index
                    itemData: carousel.controller.items[flatIndex] || ({})
                    remote: carousel.controller.sourceTab !== "local"
                    actionBusy: !!carousel.controller.busy
                    removable: !!itemData.path && itemData.path !== carousel.controller.currentPath
                    thumbnail: carousel.controller.thumbnailFor(itemData)
                    shaderSource: carousel.controller.cardShader || ""
                    vertexSource: carousel.controller.cardVertexShader || ""
                    colors: carousel.colors
                    fontFamily: carousel.controller.uiFont || "Sans Serif"
                    shape: carousel.mode
                    selected: carousel.controller.selected === flatIndex && column.virtualIndex === Math.floor(carousel.controller.selected / carousel.rows) + Math.round((carousel.visualIndex - Math.floor(carousel.controller.selected / carousel.rows)) / Math.max(1, carousel.baseColumns)) * carousel.baseColumns
                    current: !!itemData.path && itemData.path === carousel.controller.currentPath
                    width: column.visualWidth
                    x: column.cardOffset
                    height: carousel.hex ? carousel.hexHeight : (carousel.coverflow || carousel.orbit ? carousel.cardWidth * 0.64 : (carousel.mode === "slices" ? Math.min(carousel.height * 0.85, 560) : carousel.mosaicHeight * (index === 0 ? (column.virtualIndex % 2 ? 0.8 : 1.2) : (column.virtualIndex % 2 ? 1.2 : 0.8))))
                    y: carousel.hex ? carousel.cellY(column.virtualIndex, index) : (carousel.coverflow || carousel.orbit || carousel.mode === "slices" ? (carousel.height - height) / 2 : (carousel.height - carousel.mosaicHeight * 2 - 12) / 2 + (index === 0 ? 0 : carousel.mosaicHeight * (column.virtualIndex % 2 ? 0.8 : 1.2) + 12))
                    curveX: column.x + x + column.spacingOffset
                    curveViewportWidth: carousel.hex ? carousel.width : 0
                    curveAmount: carousel.arcHeight
                    interactiveHover: carousel.coverflow || carousel.orbit ? Math.abs(column.distance) < 3.5 : (!carousel.hex || column.flight < 0.8)
                    onPicked: carousel.controller.activate(flatIndex)
                    onApplyRequested: carousel.controller.applyAt(flatIndex)
                    onDownloadRequested: carousel.controller.downloadAt(flatIndex)
                    onRemoveRequested: carousel.controller.removeAt(flatIndex)
                    onFavoriteRequested: carousel.controller.favorite(flatIndex)
                }
            }
        }
    }
}
