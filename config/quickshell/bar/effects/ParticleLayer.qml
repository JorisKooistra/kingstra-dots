import QtQuick

Item {
    id: root
    required property var shell
    required property var mocha
    property real fireflyBoost: 1.0
    property bool pointerActive: false
    property real pointerX: -9999
    property real pointerY: -9999

    readonly property string normalizedType: {
        let t = String(shell.particleType || "none").toLowerCase();
        if (t === "fireflies" || t === "space-specks" || t === "space-specks-layered") return t;
        return "none";
    }
    readonly property int safeCount: Math.max(0, Math.min(50, Number(shell.particleCount || 0)))
    readonly property real safeSpeed: Math.max(0.1, Math.min(2.0, Number(shell.particleSpeed || 1.0)))

    Repeater {
        model: root.normalizedType === "none" ? 0 : root.safeCount

        delegate: Item {
            id: particle
            readonly property bool isFireflies: root.normalizedType === "fireflies"
            readonly property bool isLayeredSpecks: root.normalizedType === "space-specks-layered"
            readonly property bool largeLayeredSpeck: isLayeredSpecks && (index % 2) === 1
            width: isFireflies
                   ? shell.s(root.fireflyBoost > 1.0 ? 5 : 4)
                   : (largeLayeredSpeck ? 2 : 1)
            height: width

            property real baseX: ((index * 137) % Math.max(1, root.width))
            property real baseY: ((index * 97) % Math.max(1, root.height))
            property real glowPulse: 0.0
            property real pathPhase: 0.0
            readonly property real pathOffset: index * 1.37
            readonly property real fireflyDriftX: shell.s(root.fireflyBoost > 1.0 ? 18 : 13)
            readonly property real fireflyDriftY: shell.s(root.fireflyBoost > 1.0 ? 12 : 9)
            readonly property real naturalX: isFireflies
               ? baseX
                 + Math.cos(pathPhase + pathOffset) * fireflyDriftX
                 + Math.cos(pathPhase * 2 + pathOffset * 0.7) * fireflyDriftX * 0.28
               : baseX
            readonly property real naturalY: isFireflies
               ? baseY
                 + Math.sin(pathPhase + pathOffset) * fireflyDriftY
                 + Math.sin(pathPhase * 2 + pathOffset * 0.7) * fireflyDriftY * 0.24
               : baseY
            readonly property real pointerDx: naturalX + width / 2 - root.pointerX
            readonly property real pointerDy: naturalY + height / 2 - root.pointerY
            readonly property real pointerDistance: Math.sqrt(pointerDx * pointerDx + pointerDy * pointerDy)
            readonly property real scareRadius: shell.s(root.fireflyBoost > 1.0 ? 76 : 58)
            readonly property real scareStrength: (isFireflies && root.pointerActive)
                                                  ? Math.max(0.0, 1.0 - pointerDistance / scareRadius)
                                                  : 0.0
            readonly property real scareNorm: Math.max(1.0, pointerDistance)
            readonly property real scarePush: scareStrength * scareStrength * shell.s(root.fireflyBoost > 1.0 ? 34 : 26)
            readonly property real startledGlow: Math.min(1.25, glowPulse + scareStrength * 0.55)
            x: isFireflies ? naturalX + (pointerDx / scareNorm) * scarePush : naturalX
            y: isFireflies ? naturalY + (pointerDy / scareNorm) * scarePush : naturalY
            opacity: isFireflies ? (root.fireflyBoost > 1.0 ? 0.35 : 0.25) + scareStrength * 0.20 : (largeLayeredSpeck ? 0.22 : 0.16)

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 11.0 : 8.0)
                height: width
                radius: width / 2
                scale: 0.70 + particle.startledGlow * 0.50
                opacity: (root.fireflyBoost > 1.0 ? 0.06 : 0.04) * particle.startledGlow
                color: Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 0.35)
            }

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 7.8 : 5.8)
                height: width
                radius: width / 2
                scale: 0.78 + particle.startledGlow * 0.40
                opacity: (root.fireflyBoost > 1.0 ? 0.22 : 0.16) * particle.startledGlow
                color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.58)
            }

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 4.8 : 3.6)
                height: width
                radius: width / 2
                scale: 0.88 + particle.startledGlow * 0.26
                opacity: (root.fireflyBoost > 1.0 ? 0.56 : 0.42) * particle.startledGlow
                color: Qt.rgba(1.0, 0.78, 0.28, 0.82)
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                scale: 1.0 + particle.scareStrength * 0.36
                color: isFireflies
                    ? Qt.rgba(1.0, 0.94, 0.78, 1.0)
                    : Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, largeLayeredSpeck ? 0.88 : 0.72)
            }

            SequentialAnimation on glowPulse {
                running: particle.isFireflies
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1.0
                    duration: (1500 + (index % 5) * 180) / root.safeSpeed
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.28
                    duration: (1800 + (index % 5) * 220) / root.safeSpeed
                    easing.type: Easing.InOutSine
                }
            }

            NumberAnimation on pathPhase {
                running: particle.isFireflies
                from: 0
                to: Math.PI * 2
                duration: (9000 + (index % 6) * 650) / root.safeSpeed
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }

            SequentialAnimation on opacity {
                running: root.normalizedType !== "none"
                loops: Animation.Infinite
                NumberAnimation {
                    to: isFireflies ? (root.fireflyBoost > 1.0 ? 1.0 : 0.95) : (largeLayeredSpeck ? 0.52 : 0.38)
                    duration: (2200 + (index % 7) * 240) / (root.safeSpeed * (largeLayeredSpeck ? 1.2 : 1.0))
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: isFireflies ? (root.fireflyBoost > 1.0 ? 0.35 : 0.25) : (largeLayeredSpeck ? 0.18 : 0.12)
                    duration: (2200 + (index % 7) * 260) / (root.safeSpeed * (largeLayeredSpeck ? 1.1 : 0.9))
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on y {
                running: root.normalizedType !== "none" && !particle.isFireflies
                loops: Animation.Infinite
                NumberAnimation {
                    to: particle.baseY + (largeLayeredSpeck ? shell.s(5) : shell.s(3))
                    duration: (3800 + (index % 5) * 220) / (root.safeSpeed * (largeLayeredSpeck ? 1.15 : 0.75))
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.baseY - (largeLayeredSpeck ? shell.s(4) : shell.s(2))
                    duration: (3600 + (index % 5) * 260) / (root.safeSpeed * (largeLayeredSpeck ? 1.05 : 0.7))
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.normalizedType === "fireflies"
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onPositionChanged: mouse => {
            root.pointerActive = true;
            root.pointerX = mouse.x;
            root.pointerY = mouse.y;
        }
        onExited: {
            root.pointerActive = false;
            root.pointerX = -9999;
            root.pointerY = -9999;
        }
    }
}
