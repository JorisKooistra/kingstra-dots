import QtQuick
import Quickshell

Item {
    id: root
    required property var shell
    required property var mocha

    readonly property bool hasRequestedAssets: requestedTopLeft !== "" || requestedTopRight !== "" || requestedTopCenter !== ""
    readonly property bool allowThemeFallbackAssets: activeTheme === "botanical"
    readonly property bool ornamentAssetsAllowed: hasRequestedAssets || allowThemeFallbackAssets
    readonly property bool ornamentsActive: shell.ornamentEnabled && shell.ornamentOpacity > 0.0 && ornamentAssetsAllowed
    readonly property string activeTheme: String(shell.activeThemeName || "botanical").toLowerCase()
    readonly property real themeOpacityBoost: activeTheme === "botanical" ? 0.62
                                            : (activeTheme === "rocky" ? 0.55 : 0.60)
    readonly property real levelOpacity: ornamentsActive
                                       ? Math.max(0.0, Math.min(0.32, Number(shell.ornamentOpacity || 0.0) * themeOpacityBoost))
                                       : 0.0
    readonly property bool allowGeneratedFallback: false

    property string requestedTopLeft: String(shell.ornamentTopLeft !== undefined ? shell.ornamentTopLeft : "")
    property string requestedTopRight: String(shell.ornamentTopRight !== undefined ? shell.ornamentTopRight : "")
    property string requestedTopCenter: String(shell.ornamentTopCenter !== undefined ? shell.ornamentTopCenter : "")

    readonly property string fallbackRootPrimary: Quickshell.env("HOME") + "/kingstra-dots/assets/themes/" + root.activeTheme + "/"
    readonly property string fallbackRootSecondary: Quickshell.env("HOME") + "/.config/kingstra-dots/assets/themes/" + root.activeTheme + "/"

    readonly property string fallbackTopLeftPrimary: fallbackRootPrimary + "ornament-top-left.svg"
    readonly property string fallbackTopLeftSecondary: fallbackRootPrimary + "ornament-top-left.png"
    readonly property string fallbackTopLeftTertiary: fallbackRootSecondary + "ornament-top-left.svg"
    readonly property string fallbackTopLeftQuaternary: fallbackRootSecondary + "ornament-top-left.png"

    readonly property string fallbackTopRightPrimary: fallbackRootPrimary + "ornament-top-right.svg"
    readonly property string fallbackTopRightSecondary: fallbackRootPrimary + "ornament-top-right.png"
    readonly property string fallbackTopRightTertiary: fallbackRootSecondary + "ornament-top-right.svg"
    readonly property string fallbackTopRightQuaternary: fallbackRootSecondary + "ornament-top-right.png"

    readonly property string fallbackTopCenterPrimary: fallbackRootPrimary + "ornament-center.svg"
    readonly property string fallbackTopCenterSecondary: fallbackRootPrimary + "ornament-center.png"
    readonly property string fallbackTopCenterTertiary: fallbackRootSecondary + "ornament-center.svg"
    readonly property string fallbackTopCenterQuaternary: fallbackRootSecondary + "ornament-center.png"

    property string effectiveTopLeft: ""
    property string effectiveTopRight: ""
    property string effectiveTopCenter: ""

    onRequestedTopLeftChanged: resetTopLeftSource()
    onRequestedTopRightChanged: resetTopRightSource()
    onRequestedTopCenterChanged: resetTopCenterSource()
    onActiveThemeChanged: {
        resetTopLeftSource();
        resetTopRightSource();
        resetTopCenterSource();
    }
    onOrnamentsActiveChanged: {
        resetTopLeftSource();
        resetTopRightSource();
        resetTopCenterSource();
    }
    Component.onCompleted: {
        resetTopLeftSource();
        resetTopRightSource();
        resetTopCenterSource();
    }

    function resetTopLeftSource() {
        if (!root.ornamentsActive) {
            root.effectiveTopLeft = "";
            return;
        }
        root.effectiveTopLeft = root.requestedTopLeft !== "" ? root.requestedTopLeft : root.fallbackTopLeftPrimary;
    }

    function resetTopRightSource() {
        if (!root.ornamentsActive) {
            root.effectiveTopRight = "";
            return;
        }
        root.effectiveTopRight = root.requestedTopRight !== "" ? root.requestedTopRight : root.fallbackTopRightPrimary;
    }

    function resetTopCenterSource() {
        if (!root.ornamentsActive) {
            root.effectiveTopCenter = "";
            return;
        }
        root.effectiveTopCenter = root.requestedTopCenter !== "" ? root.requestedTopCenter : root.fallbackTopCenterPrimary;
    }

    function warnMissing(assetPath, slotName) {
        if (assetPath && assetPath !== "") {
            console.warn("[OrnamentLayer] missing asset for " + slotName + ": " + assetPath);
        }
    }

    function pngVariant(assetPath) {
        let src = String(assetPath || "");
        let lower = src.toLowerCase();
        if (lower.endsWith(".svg")) {
            return src.slice(0, src.length - 4) + ".png";
        }
        return "";
    }

    function accentForTheme() {
        if (root.activeTheme === "rocky") {
            if (mocha && mocha.overlay2 !== undefined) return mocha.overlay2;
            return Qt.rgba(0.78, 0.76, 0.72, 1.0);
        }
        if (root.activeTheme === "ocean" || root.activeTheme === "space") {
            if (mocha && mocha.blue !== undefined) return mocha.blue;
            return Qt.rgba(0.55, 0.78, 0.98, 1.0);
        }
        if (mocha && mocha.green !== undefined) return mocha.green;
        return Qt.rgba(0.60, 0.84, 0.62, 1.0);
    }

    Image {
        id: topLeft
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: shell.s(14)
        anchors.topMargin: shell.s(1)
        width: shell.s(root.activeTheme === "botanical" ? 86 : 78)
        height: shell.s(root.activeTheme === "botanical" ? 34 : 30)
        fillMode: Image.PreserveAspectFit
        source: root.effectiveTopLeft
        opacity: Math.min(0.40, root.levelOpacity)
        visible: root.ornamentsActive && source !== "" && status !== Image.Error
        smooth: true
        asynchronous: true
        property bool alreadyWarned: false
        onSourceChanged: alreadyWarned = false
        onStatusChanged: {
            if (status !== Image.Error) return;
            let png = root.pngVariant(source);
            if (png !== "" && png !== source) {
                root.effectiveTopLeft = png;
                return;
            }
            if (source === root.fallbackTopLeftPrimary) {
                root.effectiveTopLeft = root.fallbackTopLeftSecondary;
                return;
            }
            if (source === root.fallbackTopLeftSecondary) {
                root.effectiveTopLeft = root.fallbackTopLeftTertiary;
                return;
            }
            if (source === root.fallbackTopLeftTertiary) {
                root.effectiveTopLeft = root.fallbackTopLeftQuaternary;
                return;
            }
            if (!alreadyWarned) {
                alreadyWarned = true;
                root.warnMissing(source, "top-left");
            }
        }
    }

    Image {
        id: topRight
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: shell.s(12)
        anchors.topMargin: shell.s(1)
        width: shell.s(root.activeTheme === "botanical" ? 86 : 78)
        height: shell.s(root.activeTheme === "botanical" ? 34 : 30)
        fillMode: Image.PreserveAspectFit
        source: root.effectiveTopRight
        opacity: Math.min(0.40, root.levelOpacity)
        visible: root.ornamentsActive && source !== "" && status !== Image.Error
        smooth: true
        asynchronous: true
        property bool alreadyWarned: false
        onSourceChanged: alreadyWarned = false
        onStatusChanged: {
            if (status !== Image.Error) return;
            let png = root.pngVariant(source);
            if (png !== "" && png !== source) {
                root.effectiveTopRight = png;
                return;
            }
            if (source === root.fallbackTopRightPrimary) {
                root.effectiveTopRight = root.fallbackTopRightSecondary;
                return;
            }
            if (source === root.fallbackTopRightSecondary) {
                root.effectiveTopRight = root.fallbackTopRightTertiary;
                return;
            }
            if (source === root.fallbackTopRightTertiary) {
                root.effectiveTopRight = root.fallbackTopRightQuaternary;
                return;
            }
            if (!alreadyWarned) {
                alreadyWarned = true;
                root.warnMissing(source, "top-right");
            }
        }
    }

    Image {
        id: topCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: shell.s(2)
        width: shell.s(root.activeTheme === "botanical" ? 108 : 92)
        height: shell.s(root.activeTheme === "botanical" ? 20 : 16)
        fillMode: Image.PreserveAspectFit
        source: root.effectiveTopCenter
        opacity: Math.min(0.44, root.levelOpacity)
        visible: root.ornamentsActive && source !== "" && status !== Image.Error
        smooth: true
        asynchronous: true
        property bool alreadyWarned: false
        onSourceChanged: alreadyWarned = false
        onStatusChanged: {
            if (status !== Image.Error) return;
            let png = root.pngVariant(source);
            if (png !== "" && png !== source) {
                root.effectiveTopCenter = png;
                return;
            }
            if (source === root.fallbackTopCenterPrimary) {
                root.effectiveTopCenter = root.fallbackTopCenterSecondary;
                return;
            }
            if (source === root.fallbackTopCenterSecondary) {
                root.effectiveTopCenter = root.fallbackTopCenterTertiary;
                return;
            }
            if (source === root.fallbackTopCenterTertiary) {
                root.effectiveTopCenter = root.fallbackTopCenterQuaternary;
                return;
            }
            if (!alreadyWarned) {
                alreadyWarned = true;
                root.warnMissing(source, "top-center");
            }
        }
    }

    Item {
        id: generatedLeft
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: shell.s(14)
        anchors.topMargin: shell.s(6)
        width: shell.s(70)
        height: shell.s(24)
        visible: root.allowGeneratedFallback && root.ornamentsActive && (topLeft.source === "" || topLeft.status === Image.Error)
        opacity: Math.min(0.98, root.levelOpacity * 0.95)

        readonly property color accent: root.accentForTheme()
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: shell.s(2)
            color: Qt.rgba(generatedLeft.accent.r, generatedLeft.accent.g, generatedLeft.accent.b, 0.52)
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: shell.s(2)
            height: parent.height
            color: Qt.rgba(generatedLeft.accent.r, generatedLeft.accent.g, generatedLeft.accent.b, 0.52)
        }
        Rectangle {
            visible: root.activeTheme !== "rocky"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: shell.s(12)
            anchors.topMargin: shell.s(6)
            width: shell.s(8)
            height: shell.s(8)
            radius: width / 2
            color: Qt.rgba(generatedLeft.accent.r, generatedLeft.accent.g, generatedLeft.accent.b, 0.46)
        }
    }

    Item {
        id: generatedRight
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: shell.s(14)
        anchors.topMargin: shell.s(6)
        width: shell.s(70)
        height: shell.s(24)
        visible: root.allowGeneratedFallback && root.ornamentsActive && (topRight.source === "" || topRight.status === Image.Error)
        opacity: Math.min(0.98, root.levelOpacity * 0.95)

        readonly property color accent: root.accentForTheme()
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: parent.width
            height: shell.s(2)
            color: Qt.rgba(generatedRight.accent.r, generatedRight.accent.g, generatedRight.accent.b, 0.52)
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: shell.s(2)
            height: parent.height
            color: Qt.rgba(generatedRight.accent.r, generatedRight.accent.g, generatedRight.accent.b, 0.52)
        }
        Rectangle {
            visible: root.activeTheme !== "rocky"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: shell.s(12)
            anchors.topMargin: shell.s(6)
            width: shell.s(8)
            height: shell.s(8)
            radius: width / 2
            color: Qt.rgba(generatedRight.accent.r, generatedRight.accent.g, generatedRight.accent.b, 0.46)
        }
    }

    Item {
        id: generatedCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: shell.s(root.activeTheme === "rocky" ? 3 : 1)
        width: shell.s(root.activeTheme === "rocky" ? 112 : 148)
        height: shell.s(root.activeTheme === "rocky" ? 18 : 22)
        visible: root.allowGeneratedFallback && root.ornamentsActive && (topCenter.source === "" || topCenter.status === Image.Error)
        opacity: Math.min(0.98, root.levelOpacity * (root.activeTheme === "rocky" ? 0.74 : 0.92))

        readonly property color accent: root.accentForTheme()

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: shell.s(2)
            width: parent.width
            height: shell.s(2)
            color: Qt.rgba(generatedCenter.accent.r, generatedCenter.accent.g, generatedCenter.accent.b, 0.54)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: shell.s(7)
            width: shell.s(7)
            height: shell.s(7)
            radius: shell.s(2)
            rotation: 45
            color: Qt.rgba(generatedCenter.accent.r, generatedCenter.accent.g, generatedCenter.accent.b, 0.52)
        }

        Rectangle {
            visible: root.activeTheme !== "rocky"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.horizontalCenterOffset: -shell.s(26)
            anchors.topMargin: shell.s(4)
            width: shell.s(20)
            height: shell.s(2)
            rotation: -22
            color: Qt.rgba(generatedCenter.accent.r, generatedCenter.accent.g, generatedCenter.accent.b, 0.44)
        }

        Rectangle {
            visible: root.activeTheme !== "rocky"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.horizontalCenterOffset: shell.s(26)
            anchors.topMargin: shell.s(4)
            width: shell.s(20)
            height: shell.s(2)
            rotation: 22
            color: Qt.rgba(generatedCenter.accent.r, generatedCenter.accent.g, generatedCenter.accent.b, 0.44)
        }
    }
}
