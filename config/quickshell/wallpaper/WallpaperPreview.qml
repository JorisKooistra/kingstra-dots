import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: preview
    required property var controller
    required property var colors
    color: colors.surface
    property real zoom: 1
    readonly property bool isVideo: controller.chosen.type === "video"
    readonly property bool local: !controller.online
    readonly property point panPosition: Qt.point(pan.contentX, pan.contentY)
    onVisibleChanged: {
        if (visible) {
            zoom = 1;
            forceActiveFocus();
        }
    }
    focus: visible
    function zoomTo(value, x, y) {
        let nx = (pan.contentX + x) / Math.max(1, pan.contentWidth), ny = (pan.contentY + y) / Math.max(1, pan.contentHeight);
        zoom = Math.max(1, Math.min(6, value));
        pan.contentX = Math.max(0, Math.min(pan.width * (zoom - 1), nx * pan.width * zoom - x));
        pan.contentY = Math.max(0, Math.min(pan.height * (zoom - 1), ny * pan.height * zoom - y));
    }
    function zoomBy(delta) {
        zoomTo(zoom * Math.pow(1.18, delta), imageArea.width / 2, imageArea.height / 2);
    }
    Connections {
        target: preview.controller
        function onSelectedChanged() {
            if (preview.visible) {
                preview.zoom = 1;
                pan.contentX = 0;
                pan.contentY = 0;
            }
        }
    }
    Keys.onEscapePressed: controller.previewOpen = false
    Keys.onLeftPressed: controller.previewNavigate(-1)
    Keys.onRightPressed: controller.previewNavigate(1)
    Keys.onReturnPressed: controller.applyChosen()
    Keys.onEnterPressed: controller.applyChosen()
    Keys.onDeletePressed: controller.removeAt(controller.selected)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            zoomBy(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Minus) {
            zoomBy(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_0) {
            zoomTo(1, 0, 0);
            event.accepted = true;
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: preview.controller.previewOpen = false
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            PickerButton {
                objectName: "preview-back"
                colors: preview.colors
                text: "← Terug"
                onClicked: preview.controller.previewOpen = false
            }
            PickerText {
                text: preview.controller.chosen.displayName || preview.controller.chosen.name || "Wallpaper"
                color: preview.colors.text
                font.pixelSize: 22
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
            }
            PickerButton {
                objectName: "preview-zoom-out"
                colors: preview.colors
                text: "−"
                onClicked: preview.zoomBy(-1)
            }
            PickerButton {
                objectName: "preview-zoom-reset"
                colors: preview.colors
                text: Math.round(preview.zoom * 100) + "%"
                onClicked: preview.zoomTo(1, 0, 0)
            }
            PickerButton {
                objectName: "preview-zoom-in"
                colors: preview.colors
                text: "+"
                onClicked: preview.zoomBy(1)
            }
            PickerButton {
                objectName: "preview-close"
                colors: preview.colors
                text: "Sluiten ×"
                onClicked: preview.controller.previewOpen = false
            }
        }
        Item {
            id: imageArea
            objectName: "preview-image-area"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Flickable {
                id: pan
                anchors.fill: parent
                contentWidth: width * preview.zoom
                contentHeight: height * preview.zoom
                boundsBehavior: Flickable.StopAtBounds
                Image {
                    id: fullImage
                    objectName: "preview-image"
                    width: pan.contentWidth
                    height: pan.contentHeight
                    // Video: het stilstaande beeld tot het filmpje speelt.
                    source: preview.isVideo ? (preview.controller.thumbnailFor(preview.controller.chosen).thumb || preview.controller.chosen.thumb || "") : preview.controller.previewSource
                    asynchronous: true
                    cache: false
                    sourceSize.width: Math.min(4096, Math.round(imageArea.width * 2))
                    sourceSize.height: Math.min(3072, Math.round(imageArea.height * 2))
                    fillMode: Image.PreserveAspectFit
                }
                Loader {
                    id: videoPlayer
                    objectName: "preview-video"
                    width: pan.contentWidth
                    height: pan.contentHeight
                    active: preview.visible && preview.isVideo && !!preview.controller.previewSource
                    source: "WallpaperVideo.qml"
                    onLoaded: item.source = Qt.binding(() => preview.controller.previewSource)
                    opacity: item && item.ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: event => {
                        if (preview.isVideo && videoPlayer.item) {
                            videoPlayer.item.toggle();
                            return;
                        }
                        let left = (fullImage.width - fullImage.paintedWidth) / 2;
                        let top = (fullImage.height - fullImage.paintedHeight) / 2;
                        if (fullImage.status !== Image.Ready || event.x < left || event.x > left + fullImage.paintedWidth || event.y < top || event.y > top + fullImage.paintedHeight)
                            preview.controller.previewOpen = false;
                    }
                    onDoubleClicked: event => preview.zoomTo(preview.zoom > 1 ? 1 : 2, event.x - pan.contentX, event.y - pan.contentY)
                }
            }
            WheelHandler {
                target: null
                onWheel: event => {
                    preview.zoomTo(preview.zoom * Math.pow(1.18, (event.angleDelta.y || event.pixelDelta.y) / 120), event.x, event.y);
                    event.accepted = true;
                }
            }
            PickerText {
                anchors.centerIn: parent
                visible: fullImage.status !== Image.Ready && !preview.isVideo
                text: fullImage.status === Image.Error ? "Afbeelding laden mislukt" : "Volledige afbeelding laden…"
                color: preview.colors.onSurfaceVariant
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                visible: preview.isVideo && !(videoPlayer.item && videoPlayer.item.playing)
                width: videoNote.implicitWidth + 28
                height: 34
                radius: 17
                color: Qt.rgba(preview.colors.surface.r, preview.colors.surface.g, preview.colors.surface.b, 0.85)
                PickerText {
                    id: videoNote
                    anchors.centerIn: parent
                    text: videoPlayer.status === Loader.Error ? "Bewegend voorbeeld kan niet (qt6-multimedia ontbreekt) · Instellen werkt wel" : (videoPlayer.item && videoPlayer.item.failed ? "Video afspelen mislukt" : (videoPlayer.item && videoPlayer.item.ready ? "▶ Gepauzeerd · klik om af te spelen" : "Video laden…"))
                    color: preview.colors.text
                }
            }
        }
        PickerText {
            Layout.fillWidth: true
            text: (preview.isVideo ? "▶ Video" + ((preview.controller.previewInfo.duration || preview.controller.chosen.duration) ? " · " + (preview.controller.previewInfo.duration || preview.controller.chosen.duration) + " s" : "") + "   ·   " : "") + (preview.controller.previewInfo.dimensions || preview.controller.chosen.dimensions || "") + (preview.controller.previewInfo.uploader ? "   ·   " + preview.controller.previewInfo.uploader : "") + (preview.controller.previewInfo.license ? "   ·   " + preview.controller.previewInfo.license : "") + (preview.controller.previewInfo.notice ? "   ·   " + preview.controller.previewInfo.notice : "") + (preview.controller.previewLoading ? (preview.isVideo ? "   ·   Video laden…" : "   ·   Volledige afbeelding laden…") : "")
            elide: Text.ElideRight
            color: preview.colors.onSurfaceVariant
            textFormat: Text.PlainText
        }
        WallpaperPalette {
            Layout.fillWidth: true
            colors: preview.colors
            swatches: preview.controller.selectedPalette
            onCopied: hex => preview.controller.copyColor(hex)
        }
        PickerTagBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(55, implicitHeight)
            visible: values.length > 0
            clip: true
            colors: preview.colors
            values: preview.controller.previewInfo.tags || preview.controller.selectedTags
            onPicked: tag => preview.controller.searchTag(tag)
        }
        PickerText {
            Layout.fillWidth: true
            text: (preview.isVideo ? "Klik om te pauzeren    " : "") + "Scroll of +/− zoomen    Sleep om te verplaatsen    ← → bladeren    Enter instellen    Esc terug"
            color: preview.colors.onSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            PickerButton {
                colors: preview.colors
                text: "← Vorige"
                available: preview.controller.selected > 0
                onClicked: {
                    preview.zoom = 1;
                    preview.controller.previewNavigate(-1);
                }
            }
            PickerButton {
                objectName: "preview-next"
                colors: preview.colors
                text: "Volgende →"
                available: preview.controller.selected < preview.controller.items.length - 1
                onClicked: {
                    preview.zoom = 1;
                    preview.controller.previewNavigate(1);
                }
            }
            PickerText {
                Layout.fillWidth: true
                text: preview.controller.busy ? preview.controller.operationLabel : preview.controller.previewMessage
                color: preview.colors.onSurfaceVariant
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            PickerButton {
                objectName: "preview-retry"
                colors: preview.colors
                text: "Opnieuw laden"
                visible: !!preview.controller.previewMessage && !preview.controller.previewInfo.id
                available: !preview.controller.previewLoading
                onClicked: preview.controller.openPreview(preview.controller.selected)
            }
            PickerButton {
                colors: preview.colors
                visible: !preview.local
                text: preview.controller.sourceName + "-bron"
                onClicked: Qt.openUrlExternally(preview.controller.previewInfo.page || preview.controller.chosen.page || "https://wallhaven.cc/w/" + preview.controller.chosen.id)
            }
            PickerButton {
                objectName: "preview-download"
                visible: !preview.local
                colors: preview.colors
                text: preview.controller.chosen.path ? "Opgeslagen" : "Downloaden"
                available: !preview.controller.busy && !preview.controller.chosen.path
                onClicked: preview.controller.downloadChosen()
            }
            PickerButton {
                objectName: "preview-remove"
                colors: preview.colors
                text: !preview.controller.canRemove(preview.controller.chosen) ? "In gebruik" : (preview.controller.confirmRemovePath === preview.controller.chosen.path ? "Echt weggooien?" : "Naar prullenbak")
                selected: preview.controller.confirmRemovePath === preview.controller.chosen.path
                visible: !!preview.controller.chosen.path
                available: !preview.controller.busy && preview.controller.canRemove(preview.controller.chosen)
                onClicked: preview.controller.removeAt(preview.controller.selected)
            }
            PickerButton {
                objectName: "preview-apply"
                colors: preview.colors
                text: preview.controller.busy ? preview.controller.operationButtonLabel : "Instellen"
                selected: true
                available: !preview.controller.busy
                onClicked: preview.controller.applyChosen()
            }
        }
    }
}
