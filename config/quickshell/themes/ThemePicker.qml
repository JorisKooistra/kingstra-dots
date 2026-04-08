import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    width: Screen.width

    // --- Responsive Scaling ---
    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }

    // -------------------------------------------------------------------------
    // PROPERTIES
    // -------------------------------------------------------------------------
    property string widgetArg: ""
    property bool initialFocusSet: false
    property bool isReady: false
    property bool isApplying: false
    property bool isItemAnimating: false
    property int scrollAccum: 0
    property real scrollThreshold: window.s(300)

    // Carousel sizing
    readonly property real itemWidth: window.s(400)
    readonly property real itemHeight: window.s(300)
    readonly property real spacing: window.s(20)
    readonly property real borderWidth: window.s(3)
    readonly property real skewFactor: -0.08

    // Active theme
    property string activeTheme: ""

    // Theme list model
    ListModel { id: themeModel }

    // -------------------------------------------------------------------------
    // LIFECYCLE
    // -------------------------------------------------------------------------
    Component.onCompleted: {
        loadThemes.running = true;
    }

    Timer { id: readyTimer; interval: 100; onTriggered: window.isReady = true }
    Timer {
        id: itemAnimationTimer; interval: 600
        onTriggered: window.isItemAnimating = false
    }

    // -------------------------------------------------------------------------
    // LOAD THEMES VIA PYTHON HELPER
    // -------------------------------------------------------------------------
    Process {
        id: loadThemes
        command: ["bash", "-c", "kingstra-theme-read --list \"${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/themes\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try {
                    let arr = JSON.parse(raw);
                    themeModel.clear();
                    for (let i = 0; i < arr.length; i++) {
                        themeModel.append(arr[i]);
                    }
                } catch(e) { console.warn("ThemePicker: JSON parse error:", e); }

                // Load current active theme
                loadActiveTheme.running = true;
            }
        }
    }

    Process {
        id: loadActiveTheme
        command: ["bash", "-c", "kingstra-theme-switch --current"]
        stdout: StdioCollector {
            onStreamFinished: {
                let active = this.text.trim();
                if (active !== "") window.activeTheme = active;
                // Position to active theme
                focusActiveTheme();
                readyTimer.start();
            }
        }
    }

    function focusActiveTheme() {
        if (window.activeTheme === "" || themeModel.count === 0) return;
        for (let i = 0; i < themeModel.count; i++) {
            if (themeModel.get(i).id === window.activeTheme) {
                window.initialFocusSet = false;
                view.currentIndex = i;
                view.positionViewAtIndex(i, ListView.Center);
                initialFocusTimer.start();
                return;
            }
        }
        window.initialFocusSet = true;
    }

    Timer {
        id: initialFocusTimer; interval: 50
        onTriggered: window.initialFocusSet = true
    }

    // -------------------------------------------------------------------------
    // APPLY THEME
    // -------------------------------------------------------------------------
    Process {
        id: applyProc
        property string themeName: ""
        command: ["bash", "-c", "kingstra-theme-switch " + themeName]
        stdout: StdioCollector {
            onStreamFinished: {
                window.activeTheme = applyProc.themeName;
                window.isApplying = false;
                applyNotifTimer.start();
            }
        }
    }

    Timer {
        id: applyNotifTimer; interval: 800
        onTriggered: {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        }
    }

    function applyTheme(themeId) {
        if (window.isApplying) return;
        window.isApplying = true;
        applyProc.themeName = themeId;
        applyProc.running = true;
    }

    // -------------------------------------------------------------------------
    // KEYBOARD NAVIGATION
    // -------------------------------------------------------------------------
    function stepToIndex(direction) {
        let newIdx = view.currentIndex + direction;
        if (newIdx < 0) newIdx = 0;
        if (newIdx >= themeModel.count) newIdx = themeModel.count - 1;
        view.currentIndex = newIdx;
    }

    Keys.onLeftPressed: stepToIndex(-1)
    Keys.onRightPressed: stepToIndex(1)
    Keys.onReturnPressed: {
        if (view.currentIndex >= 0 && view.currentIndex < themeModel.count && !window.isApplying) {
            applyTheme(themeModel.get(view.currentIndex).id);
        }
    }
    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    focus: true

    // -------------------------------------------------------------------------
    // BACKGROUND
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.92)
    }

    // -------------------------------------------------------------------------
    // CAROUSEL
    // -------------------------------------------------------------------------
    ListView {
        id: view
        anchors.fill: parent

        opacity: window.isReady ? 1.0 : 0.0
        anchors.margins: window.isReady ? 0 : window.s(40)

        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuart } }
        Behavior on anchors.margins { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }

        spacing: 0
        orientation: ListView.Horizontal
        clip: false

        interactive: !window.isApplying
        cacheBuffer: 2000

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2)
        preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2)

        highlightMoveDuration: window.initialFocusSet ? 500 : 0
        focus: true

        onCurrentIndexChanged: {
            window.isItemAnimating = true;
            itemAnimationTimer.restart();
        }

        add: Transition {
            enabled: window.initialFocusSet
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: 400; easing.type: Easing.OutBack }
            }
        }
        addDisplaced: Transition {
            enabled: window.initialFocusSet
            NumberAnimation { property: "x"; duration: 400; easing.type: Easing.OutCubic }
        }

        header: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5) / 2)) }
        footer: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5) / 2)) }

        model: themeModel

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (window.isApplying) { wheel.accepted = true; return; }
                if (scrollThrottle.running) { wheel.accepted = true; return; }

                let dx = wheel.angleDelta.x;
                let dy = wheel.angleDelta.y;
                let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
                scrollAccum += delta;

                if (Math.abs(scrollAccum) >= scrollThreshold) {
                    window.stepToIndex(scrollAccum > 0 ? -1 : 1);
                    scrollAccum = 0;
                    scrollThrottle.start();
                }
                wheel.accepted = true;
            }
        }

        Timer { id: scrollThrottle; interval: 120 }

        delegate: Item {
            id: delegateRoot

            readonly property string themeId: model.id !== undefined ? String(model.id) : ""
            readonly property string themeName: model.name !== undefined ? String(model.name) : ""
            readonly property string themeIcon: model.icon !== undefined ? String(model.icon) : "󰏘"
            readonly property string themeDesc: model.description !== undefined ? String(model.description) : ""
            readonly property string previewImg: model.preview_image !== undefined ? String(model.preview_image) : ""
            readonly property string schemeType: model.scheme_type !== undefined ? String(model.scheme_type) : ""
            readonly property int borderRadius: model.border_radius !== undefined ? model.border_radius : 12
            readonly property int gapsOut: model.gaps_out !== undefined ? model.gaps_out : 10

            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isActive: themeId === window.activeTheme

            readonly property real targetWidth: isCurrent ? (window.itemWidth * 1.5) : (window.itemWidth * 0.5)
            readonly property real targetHeight: isCurrent ? (window.itemHeight + window.s(30)) : window.itemHeight

            width: targetWidth + window.spacing
            opacity: isCurrent ? 1.0 : 0.6
            height: targetHeight
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: window.s(15)
            z: isCurrent ? 10 : 1

            Behavior on width { enabled: window.initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on height { enabled: window.initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on opacity { enabled: window.initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

            Item {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: ((window.itemHeight - height) / 2) * window.skewFactor
                width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + window.spacing)) : 0
                height: parent.height

                transform: Matrix4x4 {
                    property real s: window.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !window.isApplying
                    onClicked: {
                        view.currentIndex = index;
                        window.applyTheme(delegateRoot.themeId);
                    }
                }

                // Skewed card
                Item {
                    anchors.fill: parent
                    anchors.margins: window.borderWidth
                    clip: true

                    // Background
                    Rectangle {
                        anchors.fill: parent
                        color: _theme.base
                    }

                    // Preview image (from assets/wallpapers/ or a theme preview dir)
                    Image {
                        id: previewImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: delegateRoot.previewImg !== "" ?
                            "file://" + Quickshell.env("HOME") + "/.config/kingstra/themes/previews/" + delegateRoot.previewImg : ""
                        asynchronous: true
                        visible: status === Image.Ready

                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }

                    // Fallback gradient when no preview image
                    Rectangle {
                        anchors.fill: parent
                        visible: previewImage.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 1.0) }
                            GradientStop { position: 1.0; color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 1.0) }
                        }
                    }

                    // Bottom info overlay
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: window.s(80)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                        }

                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: window.s(16)
                            anchors.bottomMargin: window.s(10)
                            spacing: window.s(2)

                            Row {
                                spacing: window.s(8)
                                Text {
                                    text: delegateRoot.themeIcon
                                    font.pixelSize: window.s(20)
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: _theme.text
                                }
                                Text {
                                    text: delegateRoot.themeName
                                    font.pixelSize: window.s(16)
                                    font.bold: true
                                    color: _theme.text
                                }
                            }

                            Text {
                                text: delegateRoot.themeDesc
                                font.pixelSize: window.s(11)
                                color: _theme.subtext0
                                visible: text !== "" && delegateRoot.isCurrent
                                opacity: delegateRoot.isCurrent ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                            }
                        }
                    }

                    // Active theme checkmark badge
                    Rectangle {
                        visible: delegateRoot.isActive
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: window.s(10)
                        width: window.s(32)
                        height: window.s(32)
                        radius: window.s(16)
                        color: Qt.rgba(_theme.green.r, _theme.green.g, _theme.green.b, 0.9)

                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰄬"
                            font.pixelSize: window.s(18)
                            font.family: "JetBrainsMono Nerd Font"
                            color: _theme.crust
                        }
                    }

                    // Border highlight for current
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: delegateRoot.isCurrent ?
                            Qt.rgba(_theme.blue.r, _theme.blue.g, _theme.blue.b, 0.8) :
                            Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.3)
                        border.width: delegateRoot.isCurrent ? window.s(2) : 1
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // TITLE BAR
    // -------------------------------------------------------------------------
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.topMargin: window.isReady ? window.s(40) : window.s(-80)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.topMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(48)
        width: titleRow.width + window.s(32)
        radius: window.s(14)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.90)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8)
        border.width: 1

        Row {
            id: titleRow
            anchors.centerIn: parent
            spacing: window.s(10)

            Text {
                text: "󰏘"
                font.pixelSize: window.s(18)
                font.family: "JetBrainsMono Nerd Font"
                color: _theme.blue
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Thema kiezen"
                font.pixelSize: window.s(14)
                font.bold: true
                color: _theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // -------------------------------------------------------------------------
    // BOTTOM HINT BAR
    // -------------------------------------------------------------------------
    Rectangle {
        id: hintBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.isReady ? window.s(30) : window.s(-60)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(40)
        width: hintRow.width + window.s(28)
        radius: window.s(10)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.85)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.6)
        border.width: 1

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: window.s(16)

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(20); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "←"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Rectangle {
                    width: window.s(20); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "→"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Bladeren"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.s(20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(44); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Enter"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Toepassen"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.s(20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(32); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Sluiten"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // -------------------------------------------------------------------------
    // APPLYING OVERLAY
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.6)
        visible: window.isApplying
        z: 50

        Column {
            anchors.centerIn: parent
            spacing: window.s(12)

            Text {
                text: "󰑓"
                font.pixelSize: window.s(32)
                font.family: "JetBrainsMono Nerd Font"
                color: _theme.blue
                anchors.horizontalCenter: parent.horizontalCenter

                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 1200
                }
            }

            Text {
                text: "Thema wordt toegepast…"
                font.pixelSize: window.s(14)
                color: _theme.text
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
