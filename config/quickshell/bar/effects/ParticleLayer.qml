import QtQuick

Item {
    id: root
    required property var shell
    required property var mocha

    readonly property string normalizedType: {
        let t = String(shell.particleType || "none").toLowerCase();
        if (t === "fireflies" || t === "space-specks") return t;
        return "none";
    }
    readonly property int safeCount: Math.max(0, Math.min(50, Number(shell.particleCount || 0)))
    readonly property real safeSpeed: Math.max(0.1, Math.min(2.0, Number(shell.particleSpeed || 1.0)))

    Repeater {
        model: root.normalizedType === "none" ? 0 : root.safeCount

        delegate: Item {
            id: particle
            width: root.normalizedType === "fireflies" ? shell.s(4) : 2
            height: width

            property real baseX: ((index * 137) % Math.max(1, root.width))
            property real baseY: ((index * 97) % Math.max(1, root.height))
            x: baseX
            y: baseY
            opacity: root.normalizedType === "fireflies" ? 0.25 : 0.18

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.normalizedType === "fireflies"
                    ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.9)
                    : Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.75)
            }

            SequentialAnimation on opacity {
                running: root.normalizedType !== "none"
                loops: Animation.Infinite
                NumberAnimation {
                    to: root.normalizedType === "fireflies" ? 0.95 : 0.45
                    duration: (2200 + (index % 7) * 240) / root.safeSpeed
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.normalizedType === "fireflies" ? 0.25 : 0.15
                    duration: (2200 + (index % 7) * 260) / root.safeSpeed
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on y {
                running: root.normalizedType !== "none"
                loops: Animation.Infinite
                NumberAnimation {
                    to: particle.baseY + (root.normalizedType === "fireflies" ? shell.s(14) : shell.s(4))
                    duration: (3800 + (index % 5) * 220) / root.safeSpeed
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.baseY - (root.normalizedType === "fireflies" ? shell.s(10) : shell.s(3))
                    duration: (3600 + (index % 5) * 260) / root.safeSpeed
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
