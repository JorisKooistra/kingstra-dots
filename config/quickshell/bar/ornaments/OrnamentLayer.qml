import QtQuick

Item {
    id: root
    required property var shell
    required property var mocha

    readonly property bool ornamentsActive: shell.ornamentEnabled && shell.ornamentOpacity > 0.0
    readonly property real levelOpacity: Math.max(0.0, Math.min(1.0, shell.ornamentOpacity))
    readonly property string activeTheme: String(shell.activeThemeName || "botanical").toLowerCase()
    property string requestedTopLeft: root.ornamentsActive ? String(shell.ornamentTopLeft || "") : ""
    property string requestedTopRight: root.ornamentsActive ? String(shell.ornamentTopRight || "") : ""
    property string effectiveTopLeft: requestedTopLeft
    property string effectiveTopRight: requestedTopRight
    onRequestedTopLeftChanged: effectiveTopLeft = requestedTopLeft
    onRequestedTopRightChanged: effectiveTopRight = requestedTopRight

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
        if (mocha && mocha.green !== undefined) return mocha.green;
        return Qt.rgba(0.60, 0.84, 0.62, 1.0);
    }

    Image {
        id: topLeft
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: shell.s(14)
        anchors.topMargin: shell.s(1)
        width: shell.s(126)
        height: shell.s(52)
        fillMode: Image.PreserveAspectFit
        source: root.effectiveTopLeft
        opacity: root.levelOpacity
        visible: source !== "" && status !== Image.Error
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
        anchors.rightMargin: shell.s(14)
        anchors.topMargin: shell.s(1)
        width: shell.s(126)
        height: shell.s(52)
        fillMode: Image.PreserveAspectFit
        source: root.effectiveTopRight
        opacity: root.levelOpacity
        visible: source !== "" && status !== Image.Error
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
            if (!alreadyWarned) {
                alreadyWarned = true;
                root.warnMissing(source, "top-right");
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
        visible: root.ornamentsActive && (root.requestedTopLeft === "" || topLeft.status === Image.Error)
        opacity: root.levelOpacity * 0.9

        readonly property color accent: root.accentForTheme()
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: shell.s(2)
            color: Qt.rgba(generatedLeft.accent.r, generatedLeft.accent.g, generatedLeft.accent.b, 0.42)
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: shell.s(2)
            height: parent.height
            color: Qt.rgba(generatedLeft.accent.r, generatedLeft.accent.g, generatedLeft.accent.b, 0.42)
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
            color: Qt.rgba(generatedLeft.accent.r, generatedLeft.accent.g, generatedLeft.accent.b, 0.35)
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
        visible: root.ornamentsActive && (root.requestedTopRight === "" || topRight.status === Image.Error)
        opacity: root.levelOpacity * 0.9

        readonly property color accent: root.accentForTheme()
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: parent.width
            height: shell.s(2)
            color: Qt.rgba(generatedRight.accent.r, generatedRight.accent.g, generatedRight.accent.b, 0.42)
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: shell.s(2)
            height: parent.height
            color: Qt.rgba(generatedRight.accent.r, generatedRight.accent.g, generatedRight.accent.b, 0.42)
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
            color: Qt.rgba(generatedRight.accent.r, generatedRight.accent.g, generatedRight.accent.b, 0.35)
        }
    }
}
