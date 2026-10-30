import QtQuick

// Eén invoerlaag voor de kaart. De muis blijft zoals hij was. Een aanraakscherm
// sleept met één vinger, knijpt om te zoomen en houdt een venster vast om het
// te verplaatsen (het aanraak-equivalent van Super+slepen).
Item {
    id: root
    required property var controller
    property int pressedIndex: -1
    property int hoverIndex: -1

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: event => {
            if (!controller.mapReady) { event.accepted = false; return; }
            root.pressedIndex = controller.hitAt(event.x, event.y);
            if (event.modifiers & Qt.MetaModifier) {
                if (root.pressedIndex < 0) { event.accepted = false; return; }
                controller.selected = root.pressedIndex;
                controller.beginMove(root.pressedIndex, event.x, event.y);
            } else controller.beginDrag(event.x, event.y);
        }
        onPositionChanged: event => {
            if (!pressed) { root.hoverIndex = controller.hitAt(event.x, event.y); return; }
            root.hoverIndex = -1;
            if (controller.cameraDragging) controller.drag(event.x, event.y);
            else if (controller.movingAddress) controller.move(event.x, event.y);
        }
        onReleased: {
            if (controller.cameraDragging) {
                let choose = !controller.dragged && root.pressedIndex >= 0;
                controller.endDrag();
                if (choose) controller.choose(root.pressedIndex);
            } else controller.finishMove();
        }
        onExited: root.hoverIndex = -1
        onCanceled: { if (controller.cameraDragging) controller.endDrag(); controller.cancelMove(); }
    }
    // Wiel en touchpadscroll zoomen de kaart, ook als de aanraaklaag erboven ligt.
    WheelHandler {
        onWheel: event => {
            if (mouse.pressed || touch.pinching) return;
            controller.zoomBy(event.angleDelta.y);
        }
    }

    MultiPointTouchArea {
        id: touch
        objectName: "touch"
        anchors.fill: parent
        z: 1
        mouseEnabled: false
        minimumTouchPoints: 1
        maximumTouchPoints: 2
        touchPoints: [ TouchPoint { id: first }, TouchPoint { id: second } ]
        property bool holding: false
        property int heldIndex: -1
        property real span: 0
        property bool pinching: false

        function center() {
            if (first.pressed && second.pressed) return Qt.point((first.x + second.x) / 2, (first.y + second.y) / 2);
            return Qt.point(first.x, first.y);
        }
        function distance() {
            let dx = first.x - second.x, dy = first.y - second.y;
            return Math.sqrt(dx * dx + dy * dy);
        }
        Timer {
            id: hold
            interval: 450
            onTriggered: {
                if (!first.pressed || second.pressed || controller.dragged) return;
                let index = controller.hitAt(first.x, first.y);
                if (index < 0) return;
                if (controller.cameraDragging) controller.endDrag();
                touch.holding = true;
                touch.heldIndex = index;
                controller.selected = index;
                controller.beginMove(index, first.x, first.y);
            }
        }
        onPressed: {
            if (!controller.mapReady) return;
            let point = center();
            holding = false;
            heldIndex = -1;
            pinching = first.pressed && second.pressed;
            span = pinching ? distance() : 0;
            hold.stop();
            if (pinching) {
                if (controller.movingAddress) controller.cancelMove();
                if (!controller.cameraDragging) controller.beginDrag(point.x, point.y);
                return;
            }
            root.pressedIndex = controller.hitAt(point.x, point.y);
            controller.beginDrag(point.x, point.y);
            hold.restart();
        }
        onUpdated: {
            let point = center();
            let two = first.pressed && second.pressed;
            if (two) {
                hold.stop();
                if (holding) { controller.cancelMove(); holding = false; }
                if (!pinching) {
                    pinching = true;
                    span = distance();
                    if (!controller.cameraDragging) controller.beginDrag(point.x, point.y);
                }
                let next = distance();
                if (span > 8) {
                    let ratio = next / span;
                    if (ratio > 1.08) { controller.zoomBy(120); span = next; }
                    else if (ratio < 1 / 1.08) { controller.zoomBy(-120); span = next; }
                } else span = next;
                if (controller.cameraDragging) controller.drag(point.x, point.y);
                return;
            }
            if (holding || controller.movingAddress) controller.move(first.x, first.y);
            else if (controller.cameraDragging) controller.drag(first.x, first.y);
            if (controller.dragged) hold.stop();
        }
        onReleased: {
            hold.stop();
            if (holding || controller.movingAddress) controller.finishMove();
            else if (controller.cameraDragging) {
                let choose = !controller.dragged && !pinching && root.pressedIndex >= 0;
                controller.endDrag();
                if (choose) controller.choose(root.pressedIndex);
            }
            holding = false;
            pinching = false;
            span = 0;
        }
        onCanceled: {
            hold.stop();
            if (controller.cameraDragging) controller.endDrag();
            controller.cancelMove();
            holding = false;
            pinching = false;
        }
    }
}
