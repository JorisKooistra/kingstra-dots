import QtQuick
import "../.."  // ThemeConfig — voor ThemeConfig.duration()

// ── SpaceNebula ───────────────────────────────────────────────────────────────
// Trage mauve-blauw-roze nevel die over de bar drijft.
// Aan/uit via ambient_effect: "space-nebula" of theme-default bij Space.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    required property var shell
    required property var mocha
    required property var surface

    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
    z: 0.1
    visible: surface.ambientEnabled("space-nebula", "space") && surface.skinBool("showNebulaGlow", false)
    clip: true

    Rectangle {
        id: nebula
        width: parent.width * 1.8
        height: parent.height
        x: -parent.width * 0.4
        opacity: surface.effectAlpha(surface.skinNumber("nebulaAlpha", 0.06))

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.18; color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 1.0) }
            GradientStop { position: 0.48; color: Qt.rgba(mocha.blue.r,  mocha.blue.g,  mocha.blue.b,  0.55) }
            GradientStop { position: 0.76; color: Qt.rgba(mocha.pink.r,  mocha.pink.g,  mocha.pink.b,  0.9) }
            GradientStop { position: 1.00; color: "transparent" }
        }

        SequentialAnimation on x {
            running: nebula.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: -parent.width * 0.8
                duration: ThemeConfig.duration(surface.effectCycleMs(11000))
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: -parent.width * 0.25
                duration: ThemeConfig.duration(surface.effectCycleMs(11000))
                easing.type: Easing.InOutSine
            }
        }
    }

    Repeater {
        model: Math.ceil(root.width / shell.s(52))
        Rectangle {
            width: (index % 5) === 0 ? shell.s(2) : 1
            height: width
            radius: width / 2
            x: index * shell.s(52) + ((index * 17) % Math.max(1, shell.s(34)))
            y: shell.s(6 + ((index * 11) % Math.max(1, root.height - shell.s(12))))
            opacity: surface.effectAlpha((index % 5) === 0 ? 0.62 : 0.34)
            color: (index % 4) === 0
                   ? Qt.rgba(mocha.pink.r, mocha.pink.g, mocha.pink.b, 0.92)
                   : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.86)
        }
    }
}
