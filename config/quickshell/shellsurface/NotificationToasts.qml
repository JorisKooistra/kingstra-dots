import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import ".."

// Pop-ups voor nieuwe meldingen, naast de rail op het gefocuste scherm.
// Ronde kaarten schuiven in en weer uit; maximaal drie tegelijk. Kritieke
// meldingen blijven staan tot je ze wegklikt. Bij Niet storen en in de
// gaming-modus verschijnt niets: de melding staat dan alleen in het archief.
Item {
    id: root

    required property var shellWindow
    required property var mocha
    property int leftInset: 0
    property int rightInset: 0
    property int topInset: 0
    property string activeMode: "office"
    // Aan zolang het Kingstra-eiland de meldingen overneemt.
    property bool suppressed: false

    readonly property int cardWidth: 360
    readonly property int maxToasts: 3
    readonly property bool railLeft: ThemeConfig.barRailEnabled && ThemeConfig.barRailEdge === "left"
    property var byKey: ({})
    property int nextKey: 1

    // De mask-Region volgt de geometrie: zonder kaarten is dit item 0×0 en
    // blijft het scherm volledig click-through.
    width: toastModel.count > 0 ? cardWidth : 0
    height: toastModel.count > 0 ? toastList.contentHeight : 0
    x: railLeft ? leftInset + 14 : parent.width - rightInset - cardWidth - 14
    y: topInset + 14
    z: 52

    function onFocusedScreen() {
        let monitor = Hyprland.monitorFor(shellWindow.screen);
        return monitor !== null && Hyprland.focusedMonitor !== null
            && Number(monitor.id) === Number(Hyprland.focusedMonitor.id);
    }

    function urgencyColor(notification) {
        if (notification && notification.urgency === NotificationUrgency.Critical) return mocha.red;
        if (notification && notification.urgency === NotificationUrgency.Low) return mocha.subtext0;
        return mocha.yellow;
    }

    function cleanText(value) {
        return String(value || "")
            .replace(/<br\s*\/?>/gi, " ")
            .replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .trim();
    }

    function show(notification) {
        if (suppressed || !notification || activeMode === "gaming" || !onFocusedScreen()) return;
        let key = nextKey++;
        let map = Object.assign({}, byKey);
        map[key] = notification;
        byKey = map;
        toastModel.insert(0, { key: key });
        while (toastModel.count > maxToasts) removeAt(toastModel.count - 1);
    }

    function removeKey(key) {
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).key === key) {
                removeAt(i);
                return;
            }
        }
    }

    function removeAt(index) {
        let key = toastModel.get(index).key;
        toastModel.remove(index);
        let map = Object.assign({}, byKey);
        delete map[key];
        byKey = map;
    }

    Connections {
        target: NotificationService
        function onPopupRequested(notification) { root.show(notification); }
    }

    ListModel { id: toastModel }

    ListView {
        id: toastList
        width: root.cardWidth
        height: contentHeight
        interactive: false
        spacing: 8
        model: toastModel

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("standard") }
                NumberAnimation { property: "x"; from: root.railLeft ? -24 : 24; to: 0; duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("emphasized") }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                NumberAnimation { property: "x"; to: root.railLeft ? -36 : 36; duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        delegate: Rectangle {
            id: toast
            required property int key
            readonly property var notification: root.byKey[key] || null
            readonly property color accent: root.urgencyColor(notification)
            readonly property string iconSource: NotificationService.iconSource(notification)

            width: root.cardWidth
            height: Math.max(68, toastRow.implicitHeight + 22)
            radius: Math.max(14, ThemeConfig.styleWidgetRadius + 2)
            color: toastHover.hovered ? root.mocha.shellHoverFill : Qt.rgba(root.mocha.surface0.r, root.mocha.surface0.g, root.mocha.surface0.b, 0.97)
            border.width: 1
            border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

            // Een melding die elders (paneel, app zelf) verdwijnt, verdwijnt
            // ook hier.
            Connections {
                target: toast.notification
                function onClosed() { root.removeKey(toast.key); }
            }

            Timer {
                interval: toast.notification && toast.notification.urgency === NotificationUrgency.Critical
                    ? 0 : (toast.notification && toast.notification.expireTimeout > 0
                        ? Math.max(3000, Math.min(12000, toast.notification.expireTimeout * 1000))
                        : 5500)
                running: interval > 0 && !toastHover.hovered
                onTriggered: root.removeKey(toast.key)
            }

            RowLayout {
                id: toastRow
                anchors.fill: parent
                anchors.margins: 11
                spacing: 11

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignTop
                    radius: 12
                    color: Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.16)

                    Image {
                        id: toastIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        sourceSize.width: 48
                        sourceSize.height: 48
                        source: toast.iconSource
                        visible: status === Image.Ready
                        smooth: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !toastIcon.visible
                        text: String(toast.notification && toast.notification.appName ? toast.notification.appName : "?").charAt(0).toUpperCase()
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 15
                        font.weight: Font.Black
                        color: toast.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: toast.notification ? String(toast.notification.summary || toast.notification.appName || "Melding") : ""
                            elide: Text.ElideRight
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: root.mocha.text
                        }
                        Text {
                            text: toast.notification ? String(toast.notification.appName || "") : ""
                            visible: text !== ""
                            Layout.maximumWidth: 110
                            elide: Text.ElideRight
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 10
                            color: root.mocha.subtext0
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: toast.notification ? root.cleanText(toast.notification.body) : ""
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 11
                        color: root.mocha.subtext1
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    Layout.alignment: Qt.AlignTop
                    visible: toastImage.status === Image.Ready
                    radius: 10
                    clip: true
                    color: "transparent"
                    Image {
                        id: toastImage
                        anchors.fill: parent
                        source: toast.notification ? String(toast.notification.image || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 104
                        sourceSize.height: 104
                        asynchronous: true
                    }
                }
            }

            HoverHandler { id: toastHover }

            // Links: standaardactie (of het meldingenpaneel). Rechts: weg.
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    let n = toast.notification;
                    if (NotificationService.invokeDefault(n)) {
                        NotificationService.dismiss(n);
                    } else {
                        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "notifications"]);
                    }
                    root.removeKey(toast.key);
                }
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: NotificationService.dismiss(toast.notification)
            }
            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: root.removeKey(toast.key)
            }
        }
    }
}
