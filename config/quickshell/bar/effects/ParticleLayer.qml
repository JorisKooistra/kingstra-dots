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
            x: baseX
            y: baseY
            opacity: isFireflies ? (root.fireflyBoost > 1.0 ? 0.35 : 0.25) : (largeLayeredSpeck ? 0.22 : 0.16)

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 7.8 : 5.6)
                height: width
                radius: width / 2
                scale: 0.78 + particle.glowPulse * 0.34
                opacity: (root.fireflyBoost > 1.0 ? 0.34 : 0.22) * particle.glowPulse
                color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.55)
            }

            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 4.6 : 3.4)
                height: width
                radius: width / 2
                scale: 0.88 + particle.glowPulse * 0.24
                opacity: (root.fireflyBoost > 1.0 ? 0.48 : 0.32) * particle.glowPulse
                color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.70)
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: isFireflies
                    ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.9)
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
                running: root.normalizedType !== "none"
                loops: Animation.Infinite
                NumberAnimation {
                    to: particle.baseY + (isFireflies ? shell.s(14) : (largeLayeredSpeck ? shell.s(5) : shell.s(3)))
                    duration: (3800 + (index % 5) * 220) / (root.safeSpeed * (largeLayeredSpeck ? 1.15 : 0.75))
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.baseY - (isFireflies ? shell.s(10) : (largeLayeredSpeck ? shell.s(4) : shell.s(2)))
                    duration: (3600 + (index % 5) * 260) / (root.safeSpeed * (largeLayeredSpeck ? 1.05 : 0.7))
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on x {
                running: root.normalizedType === "fireflies"
                loops: Animation.Infinite
                NumberAnimation {
                    to: particle.baseX + shell.s(10)
                    duration: (4300 + (index % 6) * 180) / root.safeSpeed
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.baseX - shell.s(8)
                    duration: (4100 + (index % 6) * 210) / root.safeSpeed
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
