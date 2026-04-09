import QtQuick

Item {
    id: root
    required property var shell

    readonly property bool ornamentsActive: shell.ornamentEnabled && shell.ornamentOpacity > 0.0
    readonly property real levelOpacity: Math.max(0.0, Math.min(1.0, shell.ornamentOpacity))

    function warnMissing(assetPath, slotName) {
        if (assetPath && assetPath !== "") {
            console.warn("[OrnamentLayer] missing asset for " + slotName + ": " + assetPath);
        }
    }

    Image {
        id: topLeft
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: shell.s(8)
        anchors.topMargin: shell.s(2)
        width: shell.s(90)
        height: shell.s(44)
        fillMode: Image.PreserveAspectFit
        source: root.ornamentsActive ? String(shell.ornamentTopLeft || "") : ""
        opacity: root.levelOpacity
        visible: source !== "" && status !== Image.Error
        smooth: true
        asynchronous: true
        onStatusChanged: if (status === Image.Error) root.warnMissing(source, "top-left")
    }

    Image {
        id: topRight
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: shell.s(8)
        anchors.topMargin: shell.s(2)
        width: shell.s(90)
        height: shell.s(44)
        fillMode: Image.PreserveAspectFit
        source: root.ornamentsActive ? String(shell.ornamentTopRight || "") : ""
        opacity: root.levelOpacity
        visible: source !== "" && status !== Image.Error
        smooth: true
        asynchronous: true
        onStatusChanged: if (status === Image.Error) root.warnMissing(source, "top-right")
    }

    Image {
        id: lowerLeft
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: shell.s(8)
        anchors.bottomMargin: shell.s(2)
        width: shell.s(70)
        height: shell.s(32)
        fillMode: Image.PreserveAspectFit
        source: ""
        opacity: root.levelOpacity
        visible: source !== "" && status !== Image.Error
        smooth: true
        asynchronous: true
    }

    Image {
        id: lowerRight
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: shell.s(8)
        anchors.bottomMargin: shell.s(2)
        width: shell.s(70)
        height: shell.s(32)
        fillMode: Image.PreserveAspectFit
        source: ""
        opacity: root.levelOpacity
        visible: source !== "" && status !== Image.Error
        smooth: true
        asynchronous: true
    }
}
