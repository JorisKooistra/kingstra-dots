import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }

    property bool embedded: false
    property bool applyOnItemClick: false
    property bool initialFocusSet: false
    property bool isReady: false
    property bool isApplying: false
    property bool isItemAnimating: false
    property int scrollAccum: 0
    property real scrollThreshold: root.s(300)

    readonly property real itemWidth: embedded ? root.s(260) : root.s(400)
    readonly property real itemHeight: embedded ? root.s(180) : root.s(300)
    readonly property real spacing: embedded ? root.s(16) : root.s(20)
    readonly property real borderWidth: embedded ? root.s(2) : root.s(3)
    readonly property real skewFactor: embedded ? -0.05 : -0.08
    readonly property real previewInfoHeight: embedded ? root.s(72) : root.s(84)
    readonly property real maxPreviewHeight: itemHeight + root.s(30)
    readonly property real maxSkewCompensation: Math.abs(skewFactor) * maxPreviewHeight
    readonly property real maxPreviewWidth: (itemWidth * 1.5) + maxSkewCompensation
    readonly property int previewDecodeWidth: Math.max(1, Math.round(maxPreviewWidth * Screen.devicePixelRatio))
    readonly property int previewDecodeHeight: Math.max(1, Math.round(maxPreviewHeight * Screen.devicePixelRatio))
    readonly property int previewCacheBuffer: Math.round(itemWidth * 8)
    readonly property string themeSwitchSafeCmd: Quickshell.env("HOME") + "/.config/hypr/scripts/theme-switch-safe.sh"
    property bool preloadVisiblePreviews: false

    property string activeTheme: ""
    property string selectedThemeId: ""
    property var selectedThemeData: ({})

    signal themeSelected(string themeId)
    signal themeApplied(string themeId)
    signal themesLoaded()

    ListModel { id: themeModel }
    Repeater {
        id: preloadRepeater
        model: root.preloadVisiblePreviews ? themeModel : null
        delegate: Image {
            visible: false
            source: (model.preview_path || "") !== ""
                ? model.preview_path
                : ((model.preview_image || "") !== ""
                    ? ("file://" + Quickshell.env("HOME") + "/.config/kingstra/themes/previews/" + model.preview_image)
                    : "")
            cache: true
            asynchronous: true
            sourceSize.width: root.previewDecodeWidth
            sourceSize.height: root.previewDecodeHeight
        }
    }

    Component.onCompleted: refreshThemes()

    Timer { id: readyTimer; interval: 100; onTriggered: root.isReady = true }
    Timer { id: preloadTimer; interval: 900; onTriggered: root.preloadVisiblePreviews = true }
    Timer {
        id: itemAnimationTimer; interval: 600
        onTriggered: root.isItemAnimating = false
    }
    Timer {
        id: initialFocusTimer; interval: 50
        onTriggered: root.initialFocusSet = true
    }
    Timer { id: scrollThrottle; interval: 120 }

    function refreshThemes() {
        loadThemes.running = true;
    }

    function themeObjectAt(index) {
        if (index < 0 || index >= themeModel.count) return ({});
        return themeModel.get(index);
    }

    function syncSelection() {
        let data = themeObjectAt(view.currentIndex);
        if (!data || data.id === undefined) return;
        root.selectedThemeId = String(data.id);
        root.selectedThemeData = data;
        root.themeSelected(root.selectedThemeId);
    }

    function focusThemeById(themeId, shouldCenter) {
        if (!themeId || themeModel.count === 0) return false;
        for (let i = 0; i < themeModel.count; i++) {
            if (String(themeModel.get(i).id) === String(themeId)) {
                root.initialFocusSet = false;
                view.currentIndex = i;
                if (shouldCenter) view.positionViewAtIndex(i, ListView.Center);
                syncSelection();
                initialFocusTimer.start();
                return true;
            }
        }
        return false;
    }

    function focusActiveTheme() {
        if (focusThemeById(root.activeTheme, true)) {
            readyTimer.start();
            return;
        }

        if (themeModel.count > 0) {
            view.currentIndex = 0;
            syncSelection();
        }

        root.initialFocusSet = true;
        readyTimer.start();
    }

    function stepToIndex(direction) {
        if (themeModel.count === 0) return;
        let newIdx = view.currentIndex + direction;
        if (newIdx < 0) newIdx = 0;
        if (newIdx >= themeModel.count) newIdx = themeModel.count - 1;
        view.currentIndex = newIdx;
    }

    function applyTheme(themeId) {
        if (!themeId || root.isApplying) return;
        root.isApplying = true;
        applyProc.themeName = themeId;
        applyProc.running = true;
    }

    function applySelectedTheme() {
        if (!root.selectedThemeId) return;
        applyTheme(root.selectedThemeId);
    }

    function accentForScheme(schemeType) {
        let value = String(schemeType || "");
        if (value.indexOf("monochrome") >= 0) return _theme.overlay2;
        if (value.indexOf("neutral") >= 0) return _theme.yellow;
        if (value.indexOf("fidelity") >= 0) return _theme.green;
        if (value.indexOf("content") >= 0) return _theme.blue;
        return _theme.mauve;
    }

    function formatSchemeLabel(schemeType) {
        let cleaned = String(schemeType || "scheme-tonal-spot").replace(/^scheme-/, "");
        let parts = cleaned.split("-");
        for (let i = 0; i < parts.length; i++) {
            if (parts[i].length > 0) {
                parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
            }
        }
        return parts.join(" ");
    }

    Keys.onLeftPressed: { stepToIndex(-1); event.accepted = true; }
    Keys.onRightPressed: { stepToIndex(1); event.accepted = true; }
    Keys.onReturnPressed: {
        applySelectedTheme();
        event.accepted = true;
    }

    Process {
        id: loadThemes
        command: ["bash", "-c", "\"" + root.themeSwitchSafeCmd + "\" --list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                themeModel.clear();
                if (raw !== "") {
                    try {
                        let arr = JSON.parse(raw);
                        for (let i = 0; i < arr.length; i++) {
                            themeModel.append(arr[i]);
                        }
                    } catch(e) {
                        console.warn("ThemeCarousel: JSON parse error:", e);
                    }
                }

                root.themesLoaded();
                loadActiveTheme.running = true;
                preloadTimer.restart();
            }
        }
    }

    Process {
        id: loadActiveTheme
        command: ["bash", "-c", "\"" + root.themeSwitchSafeCmd + "\" --current"]
        stdout: StdioCollector {
            onStreamFinished: {
                let activeFromConfig = String(ThemeConfig.theme || "").trim();
                let active = activeFromConfig !== "" ? activeFromConfig : this.text.trim();
                if (active !== "") root.activeTheme = active;
                focusActiveTheme();
            }
        }
    }

    Process {
        id: applyProc
        property string themeName: ""
        command: ["bash", "-c", "\"" + root.themeSwitchSafeCmd + "\" \"" + themeName + "\""]
        stdout: StdioCollector {
            onStreamFinished: {
                // handled in onExited to avoid false-positive "applied" feedback
            }
        }
        onExited: (exitCode) => {
            root.isApplying = false;
            if (exitCode === 0) {
                root.activeTheme = applyProc.themeName;
                root.themeApplied(applyProc.themeName);
            } else {
                Quickshell.execDetached(["notify-send", "Theme", "Thema toepassen mislukt"]);
            }
        }
    }

    ListView {
        id: view
        anchors.fill: parent

        opacity: root.isReady ? 1.0 : 0.0
        anchors.margins: root.isReady ? 0 : root.s(40)

        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuart } }
        Behavior on anchors.margins { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }

        spacing: 0
        orientation: ListView.Horizontal
        layoutDirection: Qt.LeftToRight
        clip: false
        interactive: !root.isApplying
        cacheBuffer: root.previewCacheBuffer
        displayMarginBeginning: root.itemWidth * 2
        displayMarginEnd: root.itemWidth * 2
        reuseItems: false

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((root.itemWidth * 1.5 + root.spacing) / 2)
        preferredHighlightEnd: (width / 2) + ((root.itemWidth * 1.5 + root.spacing) / 2)
        highlightMoveDuration: root.initialFocusSet ? 500 : 0
        focus: true

        onCurrentIndexChanged: {
            root.isItemAnimating = true;
            itemAnimationTimer.restart();
            root.syncSelection();
        }

        add: Transition {
            enabled: root.initialFocusSet
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: 400; easing.type: Easing.OutBack }
            }
        }
        addDisplaced: Transition {
            enabled: root.initialFocusSet
            NumberAnimation { property: "x"; duration: 400; easing.type: Easing.OutCubic }
        }

        header: Item { width: Math.max(0, (view.width / 2) - ((root.itemWidth * 1.5) / 2)) }
        footer: Item { width: Math.max(0, (view.width / 2) - ((root.itemWidth * 1.5) / 2)) }
        model: themeModel

        MouseArea {
            anchors.fill: parent
            // In de embedded settings-weergave moet verticaal wielscrollen de
            // bovenliggende Theme-tab scrollen, niet de carousel zelf.
            enabled: !root.embedded
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (root.isApplying || scrollThrottle.running) {
                    wheel.accepted = true;
                    return;
                }

                let dx = wheel.angleDelta.x;
                let dy = wheel.angleDelta.y;
                let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
                root.scrollAccum += delta;

                if (Math.abs(root.scrollAccum) >= root.scrollThreshold) {
                    root.stepToIndex(root.scrollAccum > 0 ? -1 : 1);
                    root.scrollAccum = 0;
                    scrollThrottle.start();
                }
                wheel.accepted = true;
            }
        }

        delegate: Item {
            id: delegateRoot

            readonly property var appearanceData: appearance !== undefined && appearance !== null ? appearance : ({})
            readonly property var fontsData: fonts !== undefined && fonts !== null ? fonts : ({})
            readonly property var iconsData: icons !== undefined && icons !== null ? icons : ({})
            readonly property var matugenData: matugen !== undefined && matugen !== null ? matugen : ({})
            readonly property string themeId: id !== undefined ? String(id) : ""
            readonly property string themeName: name !== undefined ? String(name) : ""
            readonly property string themeIcon: icon !== undefined ? String(icon) : "󰏘"
            readonly property string themeDesc: description !== undefined ? String(description) : ""
            readonly property string previewImg: preview_image !== undefined ? String(preview_image) : ""
            readonly property string previewPath: preview_path !== undefined ? String(preview_path) : ""
            readonly property string previewSource: previewPath !== "" ? previewPath :
                (previewImg !== "" ? "file://" + Quickshell.env("HOME") + "/.config/kingstra/themes/previews/" + previewImg : "")
            readonly property string schemeType: matugenData.scheme_type !== undefined ? String(matugenData.scheme_type) : (scheme_type !== undefined ? String(scheme_type) : "")
            readonly property string iconTheme: iconsData.icon_theme !== undefined ? String(iconsData.icon_theme) : "Papirus-Dark"
            readonly property int borderRadius: appearanceData.border_radius !== undefined ? appearanceData.border_radius : (border_radius !== undefined ? border_radius : 12)
            readonly property int gapsOut: appearanceData.gaps_out !== undefined ? appearanceData.gaps_out : (gaps_out !== undefined ? gaps_out : 10)
            readonly property int previewRadius: root.s(Math.max(12, borderRadius))
            readonly property color accentColor: root.accentForScheme(schemeType)

            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isActive: themeId === root.activeTheme

            readonly property real targetWidth: isCurrent ? (root.itemWidth * 1.5) : (root.itemWidth * 0.5)
            readonly property real targetHeight: isCurrent ? (root.itemHeight + root.s(30)) : root.itemHeight

            width: targetWidth + root.spacing
            opacity: isCurrent ? 1.0 : 0.6
            height: targetHeight
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.embedded ? root.s(6) : root.s(15)
            z: isCurrent ? 10 : 1

            Behavior on width { enabled: root.initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on height { enabled: root.initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            Behavior on opacity { enabled: root.initialFocusSet; NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

            Item {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: ((root.itemHeight - height) / 2) * root.skewFactor
                width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + root.spacing)) : 0
                height: parent.height

                transform: Matrix4x4 {
                    property real s: root.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.isApplying
                    onClicked: {
                        view.currentIndex = index;
                        root.syncSelection();
                        if (root.applyOnItemClick) root.applySelectedTheme();
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: root.borderWidth

                    Rectangle {
                        id: previewMask
                        anchors.fill: parent
                        radius: delegateRoot.previewRadius
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        id: maskedVisualLayer
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: previewMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: delegateRoot.previewRadius
                            color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.96)
                        }

                        Image {
                            id: previewImage
                            readonly property real counterSkew: -root.skewFactor
                            readonly property real skewCompensation: Math.abs(counterSkew) * height
                            x: counterSkew > 0 ? -skewCompensation : 0
                            y: 0
                            width: parent.width + skewCompensation
                            height: parent.height
                            fillMode: Image.PreserveAspectCrop
                            source: delegateRoot.previewSource
                            asynchronous: true
                            cache: true
                            mipmap: true
                            sourceSize.width: root.previewDecodeWidth
                            sourceSize.height: root.previewDecodeHeight
                            visible: status === Image.Ready

                            transform: Matrix4x4 {
                                property real s: -root.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: previewImage.status !== Image.Ready
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(delegateRoot.accentColor.r, delegateRoot.accentColor.g, delegateRoot.accentColor.b, 0.92) }
                                GradientStop { position: 0.55; color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.98) }
                                GradientStop { position: 1.0; color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 1.0) }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(delegateRoot.accentColor.r, delegateRoot.accentColor.g, delegateRoot.accentColor.b, delegateRoot.isCurrent ? 0.10 : 0.05)
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: root.previewInfoHeight
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.28; color: Qt.rgba(0, 0, 0, 0.45) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                            }

                            transform: Matrix4x4 {
                                property real s: -root.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: root.s(16)
                                anchors.rightMargin: root.s(16)
                                anchors.bottomMargin: root.s(12)
                                spacing: root.s(4)

                                Row {
                                    spacing: root.s(8)
                                    Text {
                                        text: delegateRoot.themeIcon
                                        font.pixelSize: root.embedded ? root.s(18) : root.s(20)
                                        font.family: "JetBrainsMono Nerd Font"
                                        color: _theme.text
                                    }
                                    Text {
                                        text: delegateRoot.themeName
                                        font.pixelSize: root.embedded ? root.s(14) : root.s(16)
                                        font.bold: true
                                        color: _theme.text
                                    }
                                }

                                Row {
                                    spacing: root.s(6)
                                    Rectangle {
                                        radius: root.s(6)
                                        color: Qt.rgba(delegateRoot.accentColor.r, delegateRoot.accentColor.g, delegateRoot.accentColor.b, 0.24)
                                        height: root.s(20)
                                        width: schemeText.implicitWidth + root.s(14)
                                        visible: delegateRoot.isCurrent
                                        Text {
                                            id: schemeText
                                            anchors.centerIn: parent
                                            text: root.formatSchemeLabel(delegateRoot.schemeType)
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: root.s(10)
                                            font.bold: true
                                            color: _theme.text
                                        }
                                    }
                                    Rectangle {
                                        radius: root.s(6)
                                        color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.30)
                                        height: root.s(20)
                                        width: iconThemeText.implicitWidth + root.s(14)
                                        visible: delegateRoot.isCurrent
                                        Text {
                                            id: iconThemeText
                                            anchors.centerIn: parent
                                            text: delegateRoot.iconTheme
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: root.s(10)
                                            color: _theme.text
                                        }
                                    }
                                }

                                Text {
                                    text: delegateRoot.themeDesc
                                    font.pixelSize: root.s(11)
                                    color: _theme.subtext0
                                    visible: text !== "" && delegateRoot.isCurrent
                                    opacity: delegateRoot.isCurrent ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                }
                            }
                        }

                        Rectangle {
                            visible: delegateRoot.isActive
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: root.s(10)
                            width: root.s(32)
                            height: root.s(32)
                            radius: root.s(16)
                            color: Qt.rgba(_theme.green.r, _theme.green.g, _theme.green.b, 0.92)

                            transform: Matrix4x4 {
                                property real s: -root.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                font.pixelSize: root.s(18)
                                font.family: "JetBrainsMono Nerd Font"
                                color: _theme.crust
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: delegateRoot.previewRadius
                        color: "transparent"
                        border.color: delegateRoot.isCurrent ?
                            Qt.rgba(delegateRoot.accentColor.r, delegateRoot.accentColor.g, delegateRoot.accentColor.b, 0.85) :
                            Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.30)
                        border.width: delegateRoot.isCurrent ? root.s(2) : 1
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }
    }
}
