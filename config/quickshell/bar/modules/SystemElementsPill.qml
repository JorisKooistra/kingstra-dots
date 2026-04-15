import QtQuick
import Quickshell
import "../../monitors"

// Right-bar grouped pill met alle statusindicatoren.
// (cpu/gpu/ram/brightness/game-launcher zijn al losse componenten in monitors/)
//
// Elke sub-pill heeft een eigen moduleList-check. Overzicht per mode:
//
//   Sub-pill        moduleList-naam   office  gaming  media
//   ─────────────── ─────────────── ──────── ─────── ──────
//   Keyboard        (altijd aan)       ✓       ✓       ✓
//   Updates         "updates"          ✓       –       –
//   CpuTemp         "cpu_temp"         –       ✓       –
//   GpuTemp         "gpu_temp"         –       ✓       –
//   RamUsage        "ram_usage"        –       ✓       –
//   WiFi            "network"          ✓       –       –
//   Bluetooth       "bluetooth"        ✓       –       –
//   Volume          "volume"           ✓       ✓       ✓
//   Brightness      "brightness"       –       –       ✓
//   GameLauncher    "game_launcher"    –       ✓       –
//   Battery         "battery"          ✓       ✓       ✓
//
// layoutVisible: doorgeven vanuit rightLayout.showLayout zodat pills hun
// entry-animatie staggered kunnen starten.
Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx           // BarContent root — supplies theme chrome colors/flags
    required property bool layoutVisible

    Layout.preferredHeight: ctx.cyberSideModuleHeight
    Layout.alignment: Qt.AlignVCenter
    radius: surface.panelRadius
    topLeftRadius: ctx.panelTopLeftRadius
    topRightRadius: ctx.panelTopRightRadius
    bottomLeftRadius: ctx.panelBottomLeftRadius
    bottomRightRadius: ctx.panelBottomRightRadius
    border.color: ctx.rightGroupBorderColor
    border.width: 1
    color: ctx.rightGroupColor
    clip: false

    property real targetWidth: sysLayout.width + shell.s(20)
    Layout.preferredWidth: targetWidth
    Layout.maximumWidth: targetWidth

    // Cyber bottom tick line
    Rectangle {
        visible: ctx.cyberChrome
        anchors.left: parent.left; anchors.leftMargin: shell.s(10)
        anchors.right: parent.right; anchors.rightMargin: shell.s(10)
        anchors.bottom: parent.bottom; anchors.bottomMargin: shell.s(4)
        height: 1
        color: ctx.cyberModuleTickColor
        opacity: 0.48
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        spacing: shell.s(8)
        property int pillHeight: shell.s(34)

        // ── Keyboard layout ────────────────────────────────────────────────
        Rectangle {
            id: kbPill
            property bool isHovered: kbMouse.containsMouse
            color: ctx.cyberChrome
                   ? (isHovered ? ctx.cyberModuleHoverColor : ctx.cyberModuleColor)
                   : (isHovered ? surface.innerPillHoverColor : surface.innerPillColor)
            radius: surface.innerPillRadius
            height: sysLayout.pillHeight
            clip: true

            property real targetWidth: kbLayoutRow.width + shell.s(24)
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }

            property bool initAnimTrigger: false
            Timer { running: root.layoutVisible && !kbPill.initAnimTrigger; interval: 0; onTriggered: kbPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1 : 0
            transform: Translate { y: kbPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Row {
                id: kbLayoutRow
                anchors.centerIn: parent
                spacing: shell.s(8)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: ctx.cyberChrome ? ctx.cyberTextColor : (kbPill.isHovered ? mocha.text : mocha.overlay2) }
                Text { anchors.verticalCenter: parent.verticalCenter; text: shell.kbLayout; font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing; color: ctx.cyberChrome ? ctx.cyberTextColor : mocha.text }
            }
            MouseArea { id: kbMouse; anchors.fill: parent; hoverEnabled: true }
        }

        // ── Package updates (office mode) ─────────────────────────────────
        Rectangle {
            id: updatesPill
            visible: shell.moduleList.includes("updates")
            property bool isHovered: updatesMouse.containsMouse
            property int updates: Math.max(0, parseInt(shell.updateCount) || 0)
            radius: surface.innerPillRadius
            height: sysLayout.pillHeight
            clip: true
            color: ctx.cyberChrome
                   ? (isHovered ? ctx.cyberModuleHoverColor : ctx.cyberModuleColor)
                   : (isHovered ? surface.innerPillHoverColor : surface.innerPillColor)

            // Active-updates gradient background
            Rectangle {
                anchors.fill: parent
                radius: surface.innerPillRadius
                opacity: ctx.cyberChrome ? 0.0 : (updatesPill.updates > 0 ? 1.0 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 300 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: mocha.yellow }
                    GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.2) }
                }
            }

            property real targetWidth: updatesLayoutRow.width + shell.s(24)
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }

            property bool initAnimTrigger: false
            Timer { running: root.layoutVisible && !updatesPill.initAnimTrigger; interval: 25; onTriggered: updatesPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1 : 0
            transform: Translate { y: updatesPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Row {
                id: updatesLayoutRow
                anchors.centerIn: parent
                spacing: shell.s(8)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "󰚰"; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: ctx.cyberChrome ? ctx.cyberTextHotColor : (updatesPill.updates > 0 ? mocha.base : mocha.subtext0) }
                Text { anchors.verticalCenter: parent.verticalCenter; text: updatesPill.updates.toString(); font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing; color: ctx.cyberChrome ? ctx.cyberTextColor : (updatesPill.updates > 0 ? mocha.base : mocha.text) }
            }
            MouseArea { id: updatesMouse; hoverEnabled: true; anchors.fill: parent; onClicked: shell.openUpdatesTerminal() }
        }

        // ── CPU temperature (gaming mode) — external component ─────────────
        CpuTemp {
            id: cpuTempPill
            visible: shell.moduleList.includes("cpu_temp")
            mocha: root.mocha
            pillHeight: sysLayout.pillHeight
            radius: surface.innerPillRadius
        }

        // ── GPU temperature (gaming mode) — external component ─────────────
        GpuTemp {
            id: gpuTempPill
            visible: shell.moduleList.includes("gpu_temp")
            mocha: root.mocha
            pillHeight: sysLayout.pillHeight
            radius: surface.innerPillRadius
        }

        // ── RAM usage (gaming mode) — external component ───────────────────
        RamUsage {
            id: ramUsagePill
            visible: shell.moduleList.includes("ram_usage")
            mocha: root.mocha
            pillHeight: sysLayout.pillHeight
            radius: surface.innerPillRadius
        }

        // ── WiFi ───────────────────────────────────────────────────────────
        Rectangle {
            id: wifiPill
            visible: shell.moduleList.includes("network")
            property bool isHovered: wifiMouse.containsMouse
            radius: surface.innerPillRadius; height: sysLayout.pillHeight
            color: ctx.cyberChrome
                   ? (isHovered ? ctx.cyberModuleHoverColor : ctx.cyberModuleColor)
                   : (isHovered ? surface.innerPillHoverColor : surface.innerPillColor)
            clip: true

            Rectangle {
                anchors.fill: parent; radius: surface.innerPillRadius
                opacity: ctx.cyberChrome ? 0.0 : (shell.isWifiOn ? 1.0 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 300 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: mocha.blue }
                    GradientStop { position: 1.0; color: Qt.lighter(mocha.blue, 1.3) }
                }
            }

            property real targetWidth: wifiLayoutRow.width + shell.s(24)
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }

            property bool initAnimTrigger: false
            Timer { running: root.layoutVisible && !wifiPill.initAnimTrigger; interval: 50; onTriggered: wifiPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1 : 0
            transform: Translate { y: wifiPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Row {
                id: wifiLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                Text { anchors.verticalCenter: parent.verticalCenter; text: shell.wifiIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: ctx.cyberChrome ? (shell.isWifiOn ? ctx.cyberTextColor : ctx.cyberTextMutedColor) : (shell.isWifiOn ? mocha.base : mocha.subtext0) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.sysPollerLoaded ? (shell.isWifiOn ? (shell.wifiSsid !== "" ? shell.wifiSsid : "On") : "Off") : ""
                    visible: text !== ""
                    font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing
                    color: ctx.cyberChrome ? (shell.isWifiOn ? ctx.cyberTextColor : ctx.cyberTextMutedColor) : (shell.isWifiOn ? mocha.base : mocha.text)
                    width: Math.min(implicitWidth, shell.s(100)); elide: Text.ElideRight
                }
            }
            MouseArea { id: wifiMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"]) }
        }

        // ── Bluetooth ──────────────────────────────────────────────────────
        Rectangle {
            id: btPill
            visible: shell.moduleList.includes("bluetooth")
            property bool isHovered: btMouse.containsMouse
            radius: surface.innerPillRadius; height: sysLayout.pillHeight
            color: ctx.cyberChrome
                   ? (isHovered ? ctx.cyberModuleHoverColor : ctx.cyberModuleColor)
                   : (isHovered ? surface.innerPillHoverColor : surface.innerPillColor)
            clip: true

            Rectangle {
                anchors.fill: parent; radius: surface.innerPillRadius
                opacity: ctx.cyberChrome ? 0.0 : (shell.isBtOn ? 1.0 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 300 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: mocha.mauve }
                    GradientStop { position: 1.0; color: Qt.lighter(mocha.mauve, 1.3) }
                }
            }

            property real targetWidth: btLayoutRow.width + shell.s(24)
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }

            property bool initAnimTrigger: false
            Timer { running: root.layoutVisible && !btPill.initAnimTrigger; interval: 100; onTriggered: btPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1 : 0
            transform: Translate { y: btPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Row {
                id: btLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                Text { anchors.verticalCenter: parent.verticalCenter; text: shell.btIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: ctx.cyberChrome ? (shell.isBtOn ? ctx.cyberTextColor : ctx.cyberTextMutedColor) : (shell.isBtOn ? mocha.base : mocha.subtext0) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.sysPollerLoaded ? shell.btDevice : ""
                    visible: text !== ""
                    font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing
                    color: ctx.cyberChrome ? (shell.isBtOn ? ctx.cyberTextColor : ctx.cyberTextMutedColor) : (shell.isBtOn ? mocha.base : mocha.text)
                    width: Math.min(implicitWidth, shell.s(100)); elide: Text.ElideRight
                }
            }
            MouseArea { id: btMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"]) }
        }

        // ── Volume ─────────────────────────────────────────────────────────
        Rectangle {
            id: volPill
            visible: shell.moduleList.includes("volume")
            property bool isHovered: volMouse.containsMouse
            color: ctx.cyberChrome
                   ? (isHovered ? ctx.cyberModuleHoverColor : ctx.cyberModuleColor)
                   : (isHovered ? surface.innerPillHoverColor : surface.innerPillColor)
            radius: surface.innerPillRadius; height: sysLayout.pillHeight
            clip: true

            Rectangle {
                anchors.fill: parent; radius: surface.innerPillRadius
                opacity: ctx.cyberChrome ? 0.0 : (shell.isSoundActive ? 1.0 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 300 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: mocha.peach }
                    GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.3) }
                }
            }

            property real targetWidth: volLayoutRow.width + shell.s(24)
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }

            property bool initAnimTrigger: false
            Timer { running: root.layoutVisible && !volPill.initAnimTrigger; interval: 150; onTriggered: volPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1 : 0
            transform: Translate { y: volPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Row {
                id: volLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                Text { anchors.verticalCenter: parent.verticalCenter; text: shell.volIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: ctx.cyberChrome ? (shell.isSoundActive ? ctx.cyberTextColor : ctx.cyberTextMutedColor) : (shell.isSoundActive ? mocha.base : mocha.subtext0) }
                Text { anchors.verticalCenter: parent.verticalCenter; text: shell.volPercent; font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing; color: ctx.cyberChrome ? (shell.isSoundActive ? ctx.cyberTextColor : ctx.cyberTextMutedColor) : (shell.isSoundActive ? mocha.base : mocha.text) }
            }
            MouseArea {
                id: volMouse; hoverEnabled: true; anchors.fill: parent
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle volume"])
                onWheel: (wheel) => { shell.handleVolumeWheel(wheel.angleDelta.y); wheel.accepted = true; }
            }
        }

        // ── Brightness (media mode) — external component ───────────────────
        BrightnessControl {
            id: brightnessPill
            visible: shell.moduleList.includes("brightness")
            mocha: root.mocha
            pillHeight: sysLayout.pillHeight
            radius: surface.innerPillRadius
        }

        // ── Game launcher (gaming mode) — external component ───────────────
        GameLauncher {
            id: gameLauncherPill
            visible: shell.moduleList.includes("game_launcher")
            mocha: root.mocha
            pillHeight: sysLayout.pillHeight
            radius: surface.innerPillRadius
        }

        // ── Battery ────────────────────────────────────────────────────────
        Rectangle {
            id: batPill
            visible: shell.moduleList.includes("battery")
            property bool isHovered: batMouse.containsMouse
            color: ctx.cyberChrome
                   ? (isHovered ? ctx.cyberModuleHoverColor : ctx.cyberModuleColor)
                   : (isHovered ? surface.innerPillHoverColor : surface.innerPillColor)
            radius: surface.innerPillRadius; height: sysLayout.pillHeight
            clip: true

            Rectangle {
                anchors.fill: parent; radius: surface.innerPillRadius
                opacity: ctx.cyberChrome ? 0.0 : ((shell.isCharging || shell.batCap <= 20) ? 1.0 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 300 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: shell.batDynamicColor; Behavior on color { ColorAnimation { duration: 300 } } }
                    GradientStop { position: 1.0; color: Qt.lighter(shell.batDynamicColor, 1.3); Behavior on color { ColorAnimation { duration: 300 } } }
                }
            }

            property real targetWidth: batLayoutRow.width + shell.s(24)
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }

            property bool initAnimTrigger: false
            Timer { running: root.layoutVisible && !batPill.initAnimTrigger; interval: 200; onTriggered: batPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1 : 0
            transform: Translate { y: batPill.initAnimTrigger ? 0 : shell.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Row {
                id: batLayoutRow; anchors.centerIn: parent; spacing: shell.s(8)
                Text { anchors.verticalCenter: parent.verticalCenter; text: shell.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(16); color: ctx.cyberChrome ? ((shell.isCharging || shell.batCap <= 20) ? ctx.cyberTextHotColor : ctx.cyberTextColor) : ((shell.isCharging || shell.batCap <= 20) ? mocha.base : shell.batDynamicColor); Behavior on color { ColorAnimation { duration: 300 } } }
                Text { anchors.verticalCenter: parent.verticalCenter; text: shell.batPercent; font.family: shell.monoFontFamily; font.pixelSize: shell.s(13); font.weight: shell.themeFontWeight; font.letterSpacing: shell.themeLetterSpacing; color: ctx.cyberChrome ? ((shell.isCharging || shell.batCap <= 20) ? ctx.cyberTextHotColor : ctx.cyberTextColor) : ((shell.isCharging || shell.batCap <= 20) ? mocha.base : shell.batDynamicColor); Behavior on color { ColorAnimation { duration: 300 } } }
            }
            MouseArea { id: batMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"]) }
        }
    }

    // Gaming stats popup — floats above this pill when hovering cpu/gpu/ram
    GamingPopup {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: shell.s(8)
        shell: root.shell
        mocha: root.mocha
        surface: root.surface
        isVisible: cpuTempPill.isHovered || gpuTempPill.isHovered || ramUsagePill.isHovered
    }
}
