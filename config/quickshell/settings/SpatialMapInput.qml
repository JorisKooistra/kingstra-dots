import QtQuick

// Eén muisgrab voor de hele kaart; miniaturen blijven vrij bewegen.
MouseArea {
    required property var controller
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    property int pressedIndex: -1
    // Venster onder de muis, voor dezelfde hover als het werkruimte-overzicht.
    property int hoverIndex: -1
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    onPressed: mouse => {
        if (!controller.mapReady) {mouse.accepted=false;return;}
        pressedIndex=controller.hitAt(mouse.x,mouse.y);
        if (mouse.modifiers & Qt.MetaModifier) {
            if (pressedIndex<0) {mouse.accepted=false;return;}
            controller.selected=pressedIndex;
            controller.beginMove(pressedIndex,mouse.x,mouse.y);
        } else controller.beginDrag(mouse.x,mouse.y);
    }
    onPositionChanged: mouse => {
        if (!pressed) { hoverIndex=controller.hitAt(mouse.x,mouse.y); return; }
        hoverIndex=-1;
        if (controller.cameraDragging) controller.drag(mouse.x,mouse.y);
        else if (controller.movingAddress) controller.move(mouse.x,mouse.y);
    }
    onReleased: {
        if (controller.cameraDragging) {
            let choose=!controller.dragged && pressedIndex>=0;
            controller.endDrag();
            if (choose) controller.choose(pressedIndex);
        } else controller.finishMove();
    }
    onExited: hoverIndex=-1
    onCanceled: {if (controller.cameraDragging) controller.endDrag(); controller.cancelMove();}
    onWheel: wheel => {if (!pressed) controller.zoomBy(wheel.angleDelta.y); wheel.accepted=true;}
}
