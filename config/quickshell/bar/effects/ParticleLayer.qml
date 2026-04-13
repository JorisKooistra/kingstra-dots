import QtQuick

Item {
    id: root
    required property var shell
    required property var mocha
    property real fireflyBoost: 1.0

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
            x: isFireflies
               ? baseX
                 + Math.cos(pathPhase + pathOffset) * fireflyDriftX
                 + Math.cos(pathPhase * 2 + pathOffset * 0.7) * fireflyDriftX * 0.28
               : baseX
            y: isFireflies
               ? baseY
                 + Math.sin(pathPhase + pathOffset) * fireflyDriftY
                 + Math.sin(pathPhase * 2 + pathOffset * 0.7) * fireflyDriftY * 0.24
               : baseY
            opacity: isFireflies ? (root.fireflyBoost > 1.0 ? 0.35 : 0.25) : (largeLayeredSpeck ? 0.22 : 0.16)

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 11.0 : 8.0)
                height: width
                radius: width / 2
                scale: 0.70 + particle.glowPulse * 0.44
                opacity: (root.fireflyBoost > 1.0 ? 0.14 : 0.09) * particle.glowPulse
                color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.55)
            }

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 7.0 : 5.2)
                height: width
                radius: width / 2
                scale: 0.78 + particle.glowPulse * 0.34
                opacity: (root.fireflyBoost > 1.0 ? 0.26 : 0.18) * particle.glowPulse
                color: Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 0.68)
            }

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 4.2 : 3.2)
                height: width
                radius: width / 2
                scale: 0.88 + particle.glowPulse * 0.22
                opacity: (root.fireflyBoost > 1.0 ? 0.48 : 0.34) * particle.glowPulse
                color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.76)
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: isFireflies
                    ? ((index % 4) === 0
                       ? Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 0.92)
                       : Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.96))
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
}
