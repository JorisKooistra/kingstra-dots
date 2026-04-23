import QtQuick
import "../.."  // ThemeConfig — voor ThemeConfig.duration()

// ── AnimatedRainbow ───────────────────────────────────────────────────────────
// Twee animaties voor het Animated-theme, samen in één component:
//
//   Rainbow shift — een horizontaal kleurverloop waarvan de kleuren langzaam
//                   rouleren: mauve → roze → teal → groen → ...
//                   Aan/uit: showRainbowShift. Sterkte: rainbowAlpha.
//                   Snelheid: rainbowCycleMs (ms per kleurovergang).
//
//   Aurora sweep  — een diagonaal kleurvlak (roze + saffier) dat van links
//                   naar rechts over de bar trekt, alsof er een poollichtkrans
//                   voorbijkomt. Aan/uit: showAuroraSweep. Sterkte: auroraAlpha.
//                   Snelheid: auroraCycleMs (ms per sweep).
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    required property var shell
    required property var mocha
    required property var surface

    anchors.fill: parent

    // ── Rainbow shift (z=0.10) ────────────────────────────────────────────────
    Rectangle {
        id: rainbowLayer
        visible: surface.ambientEnabled("animated-rainbow", "animated") && surface.skinBool("showRainbowShift", false)
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
        z: 0.1; opacity: surface.effectAlpha(surface.skinNumber("rainbowAlpha", 0.07))

        // c1/c2 zijn de linker- en rechterkleur van het verloop.
        // De animatie hieronder wisselt ze cyclisch van kleur.
        property color c1: mocha.mauve
        property color c2: mocha.blue
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: rainbowLayer.c1 }
            GradientStop { position: 1.0; color: rainbowLayer.c2 }
        }
        SequentialAnimation {
            running: rainbowLayer.visible; loops: Animation.Infinite
            ColorAnimation { target: rainbowLayer; property: "c1"; to: mocha.pink;  duration: ThemeConfig.duration(surface.effectCycleMs(surface.skinNumber("rainbowCycleMs", 8000)) / 4) }
            ColorAnimation { target: rainbowLayer; property: "c2"; to: mocha.peach; duration: ThemeConfig.duration(surface.effectCycleMs(surface.skinNumber("rainbowCycleMs", 8000)) / 4) }
            ColorAnimation { target: rainbowLayer; property: "c1"; to: mocha.teal;  duration: ThemeConfig.duration(surface.effectCycleMs(surface.skinNumber("rainbowCycleMs", 8000)) / 4) }
            ColorAnimation { target: rainbowLayer; property: "c2"; to: mocha.green; duration: ThemeConfig.duration(surface.effectCycleMs(surface.skinNumber("rainbowCycleMs", 8000)) / 4) }
        }
    }

    // ── Aurora sweep (z=0.12) ─────────────────────────────────────────────────
    Item {
        visible: surface.ambientEnabled("animated-rainbow", "animated") && surface.skinBool("showAuroraSweep", false)
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: surface.continuousBarMode ? surface.continuousRailHeight : parent.height
        z: 0.12; clip: true

        Rectangle {
            id: auroraSweep
            // Smaller dan de bar zodat de randen uitfaden in transparant
            width: parent.width * 0.55; height: parent.height * 1.4
            y: -parent.height * 0.2   // iets boven de rand voor een zachte overloop
            x: -width                  // startpositie links buiten beeld
            opacity: surface.effectAlpha(surface.skinNumber("auroraAlpha", 0.13))
            rotation: -8               // lichte diagonaal voor een natuurlijker effect
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.25; color: Qt.rgba(mocha.pink.r,     mocha.pink.g,     mocha.pink.b,     0.95) }
                GradientStop { position: 0.7;  color: Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 0.90) }
                GradientStop { position: 1.0;  color: "transparent" }
            }
            SequentialAnimation on x {
                running: parent.visible; loops: Animation.Infinite
                NumberAnimation { to: parent.width + auroraSweep.width * 0.2; duration: ThemeConfig.duration(surface.effectCycleMs(surface.skinNumber("auroraCycleMs", 4200))); easing.type: Easing.InOutSine }
                NumberAnimation { to: -auroraSweep.width; duration: 0 }  // reset zonder animatie
            }
        }
    }

    // ── Sidebar pulse spine ──────────────────────────────────────────────────
    Repeater {
        model: surface.isAnimated && shell.isVerticalBar ? 10 : 0
        Rectangle {
            anchors.left: shell.isLeftBar ? parent.left : undefined
            anchors.right: shell.isRightBar ? parent.right : undefined
            y: index * root.height / 10
            width: shell.s(4)
            height: shell.s(18)
            radius: width / 2
            z: 0.19
            opacity: surface.effectAlpha(0.34)
            color: (index % 2) === 0 ? mocha.pink : mocha.teal
        }
    }

    Rectangle {
        id: pulseSpine
        visible: surface.isAnimated && shell.isVerticalBar && ThemeConfig.railAccent === "pulse-line"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: shell.isLeftBar ? parent.left : undefined
        anchors.right: shell.isRightBar ? parent.right : undefined
        width: shell.s(2)
        z: 0.18
        opacity: surface.effectAlpha(0.82)
        property color spineA: mocha.pink
        property color spineB: mocha.teal
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(pulseSpine.spineA.r, pulseSpine.spineA.g, pulseSpine.spineA.b, 0.12) }
            GradientStop { position: 0.5; color: Qt.rgba(pulseSpine.spineB.r, pulseSpine.spineB.g, pulseSpine.spineB.b, 0.96) }
            GradientStop { position: 1.0; color: Qt.rgba(pulseSpine.spineA.r, pulseSpine.spineA.g, pulseSpine.spineA.b, 0.12) }
        }
        SequentialAnimation {
            running: pulseSpine.visible
            loops: Animation.Infinite
            ColorAnimation { target: pulseSpine; property: "spineA"; to: mocha.yellow; duration: ThemeConfig.duration(1100); easing.type: Easing.InOutSine }
            ColorAnimation { target: pulseSpine; property: "spineB"; to: mocha.mauve;  duration: ThemeConfig.duration(1100); easing.type: Easing.InOutSine }
            ColorAnimation { target: pulseSpine; property: "spineA"; to: mocha.pink;   duration: ThemeConfig.duration(1100); easing.type: Easing.InOutSine }
            ColorAnimation { target: pulseSpine; property: "spineB"; to: mocha.teal;   duration: ThemeConfig.duration(1100); easing.type: Easing.InOutSine }
        }
    }
}
