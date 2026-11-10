import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// Short-lived, shell-native feedback for local actions such as screenshots.
// It deliberately lives in the existing fullscreen ShellSurface: no separate
// notification daemon, no focus grab and no input blocker.
Item {
    id: root

    required property var shellWindow
    required property var mocha
    property int topInset: 0
    property int rightInset: 0

    readonly property int toastWidth: Math.min(360, Math.max(260, Math.round((shellWindow?.width || 1920) * 0.20)))
    property bool primed: false
    property string lastToken: ""
    property bool shown: false
    property string icon: "󰄀"
    property string title: ""
    property string detail: ""
    property string urgency: "normal"
    // Optioneel: een knop "Ongedaan maken" die dit shell-commando draait.
    property string undoCommand: ""
    property string undoLabel: "Ongedaan maken"
    // Aan: niet zelf tonen maar doorgeven aan het eiland (ShellSurface).
    property bool routeToIsland: false
    signal routed(var payload)
    // Klikbaar stuk voor de input-mask van ShellSurface; 0×0 zonder knop.
    readonly property Item undoHit: undoHitItem

    width: toastWidth
    height: undoCommand !== "" ? 116 : 76
    Behavior on height { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: topInset + 16
    anchors.rightMargin: rightInset + 16
    z: 50
    opacity: shown ? 1.0 : 0.0
    visible: opacity > 0.01

    transform: Translate {
        y: shown ? 0 : -12
        Behavior on y { NumberAnimation { duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("emphasized") } }
    }
    Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }

    function accentForUrgency() {
        if (urgency === "critical") return mocha.red;
        if (urgency === "warning") return mocha.yellow;
        return mocha.mauve;
    }

    function onFocusedScreen() {
        let monitor = Hyprland.monitorFor(shellWindow.screen);
        return monitor !== null && Hyprland.focusedMonitor !== null
            && Number(monitor.id) === Number(Hyprland.focusedMonitor.id);
    }

    function handleFeedback(raw) {
        let payload;
        try {
            payload = JSON.parse(String(raw || "").trim());
        } catch (error) {
            return;
        }

        let token = String(payload.token || "");
        if (token === "") return;

        // A stale file must never replay a toast after a shell restart. A
        // freshly written action during startup is valid though; otherwise the
        // first screenshot after login would be silently swallowed.
        if (!primed) {
            primed = true;
            lastToken = token;
            let tokenMillis = Number(token.substring(0, 13));
            if (isNaN(tokenMillis) || Date.now() - tokenMillis > 6000)
                return;
        }
        if (token === lastToken) return;
        lastToken = token;

        if (String(payload.scope || "focused") === "focused" && !onFocusedScreen())
            return;

        // Het eiland neemt het over (één plek voor "wat gebeurt er nu").
        if (routeToIsland) {
            routed(payload);
            return;
        }

        icon = String(payload.icon || "󰄀");
        title = String(payload.title || "Klaar");
        detail = String(payload.detail || "");
        urgency = String(payload.urgency || "normal");
        undoCommand = String(payload.undo || "");
        undoLabel = String(payload.undoLabel || "Ongedaan maken");
        shown = true;
        expireTimer.interval = Math.max(1200, Math.min(8000, Number(payload.timeout || 2400)));
        expireTimer.restart();
    }

    FileView {
        id: feedbackFile
        path: "/tmp/kingstra-feedback.json"
        // Bestaat pas na de eerste melding; reload elke 125 ms mag niet loggen.
        printErrors: false
        watchChanges: true
        preload: true
        onInternalTextChanged: root.handleFeedback(__text)
    }

    // Quickshell 0.3 FileView occasionally misses a write after preload.
    Timer {
        interval: TmpWatch.pollInterval(125)
        running: true
        repeat: true
        onTriggered: feedbackFile.reload()
    }
    Connections {
        target: TmpWatch
        function onChanged(path) { if (path === "/tmp/kingstra-feedback.json") feedbackFile.reload(); }
    }

    Timer {
        id: expireTimer
        repeat: false
        onTriggered: { root.shown = false; root.undoCommand = ""; }
    }

    function runUndo() {
        if (undoCommand === "") return;
        Quickshell.execDetached(["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\"; " + undoCommand]);
        undoCommand = "";
        expireTimer.interval = 900;
        expireTimer.restart();
    }

    // Alleen dit stuk vangt klikken; de rest van de toast blijft doorklikbaar.
    Item {
        id: undoHitItem
        x: undoButton.x + undoRow.x
        y: undoButton.y + undoRow.y
        width: root.shown && root.undoCommand !== "" ? undoButton.width : 0
        height: root.shown && root.undoCommand !== "" ? undoButton.height : 0
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(12, ThemeConfig.styleWidgetRadius)
        color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(root.accentForUrgency().r, root.accentForUrgency().g, root.accentForUrgency().b, 0.64)

        Rectangle {
            width: 3
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 12
            radius: width / 2
            color: root.accentForUrgency()
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 54
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            anchors.topMargin: 11
            spacing: 11

            Rectangle {
                width: 38
                height: width
                anchors.verticalCenter: parent.verticalCenter
                radius: 11
                color: Qt.rgba(root.accentForUrgency().r, root.accentForUrgency().g, root.accentForUrgency().b, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 19
                    color: root.accentForUrgency()
                }
            }

            Column {
                width: parent.width - 65
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: mocha.text
                }

                Text {
                    width: parent.width
                    text: root.detail
                    elide: Text.ElideRight
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }
            }
        }

        Item {
            id: undoRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 65
            anchors.rightMargin: 14
            anchors.bottomMargin: 11
            height: 30
            opacity: root.undoCommand !== "" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }

            Rectangle {
                id: undoButton
                height: parent.height
                width: undoText.implicitWidth + 28
                radius: height / 2
                color: undoMouse.containsMouse
                    ? Qt.rgba(root.accentForUrgency().r, root.accentForUrgency().g, root.accentForUrgency().b, 0.30)
                    : Qt.rgba(root.accentForUrgency().r, root.accentForUrgency().g, root.accentForUrgency().b, 0.16)
                border.width: 1
                border.color: Qt.rgba(root.accentForUrgency().r, root.accentForUrgency().g, root.accentForUrgency().b, 0.6)
                scale: undoMouse.pressed ? 0.95 : 1.0
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutQuart } }
                Text {
                    id: undoText
                    anchors.centerIn: parent
                    text: "󰕌  " + root.undoLabel
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: mocha.text
                }
                MouseArea {
                    id: undoMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runUndo()
                    onContainsMouseChanged: if (containsMouse) expireTimer.stop(); else if (root.shown) expireTimer.restart()
                }
            }
        }
    }
}
