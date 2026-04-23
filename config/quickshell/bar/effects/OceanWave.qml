import QtQuick
import "../.."  // ThemeConfig — voor ThemeConfig.duration()

// ── OceanWave ─────────────────────────────────────────────────────────────────
// Een teal-blauw verloop dat horizontaal heen en weer schuift als een golf.
// Aan/uit via OceanBar.qml:  showWaveShimmer: true/false
// Sterkte via OceanBar.qml:  waveShimmerAlpha: 0.055
// Snelheid via OceanBar.qml: waveCycleMs: 6000  (ms per halve cyclus)
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    required property var shell
    required property var mocha
    required property var surface

    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
    z: 0.1
    visible: surface.ambientEnabled("ocean-wave", "ocean") && surface.skinBool("showWaveShimmer", false)
    clip: true  // verberg de golf buiten de barrand

    Rectangle {
        id: oceanWave
        // Dubbele breedte zodat de golf naadloos van rechts naar links kan schuiven
        width: parent.width * 2; height: parent.height; x: -parent.width
        opacity: surface.effectAlpha(surface.skinNumber("waveShimmerAlpha", 0.055))
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.4; color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 1.0) }
            GradientStop { position: 0.6; color: Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 1.0) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        SequentialAnimation on x {
            running: surface.isOcean; loops: Animation.Infinite
            NumberAnimation { to: 0;             duration: ThemeConfig.duration(surface.effectCycleMs(surface.skinNumber("waveCycleMs", 6000))); easing.type: Easing.InOutSine }
            NumberAnimation { to: -parent.width; duration: ThemeConfig.duration(surface.effectCycleMs(surface.skinNumber("waveCycleMs", 6000))); easing.type: Easing.InOutSine }
        }
    }

    Repeater {
        model: Math.ceil(root.width / shell.s(46))
        Rectangle {
            width: shell.s(26)
            height: shell.s(2)
            radius: height / 2
            x: index * shell.s(46) + shell.s(6)
            y: root.height - shell.s(5 + (index % 3))
            opacity: surface.effectAlpha(0.36)
            color: Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.95)
        }
    }

    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: shell.s(5)
        opacity: surface.effectAlpha(0.22)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 1.0) }
        }
    }
}
