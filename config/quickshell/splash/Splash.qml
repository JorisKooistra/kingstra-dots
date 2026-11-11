//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QPA_PLATFORMTHEME=

// Kingstra-startscherm na het inloggen (en afsluitbeeld vanuit de shell).
// Zelfde beeld als het Plymouth-opstartbeeld: vervaagde achtergrond, bol en
// ringen. Het dekt alle schermen af terwijl balk en achtergrond opstarten en
// vervaagt in één keer zodra die er zijn, zodat je niets half ziet verschijnen.
//
//   quickshell -p Splash.qml                         startscherm (vanzelf weg)
//   KINGSTRA_SPLASH_MODE=out quickshell -p Splash.qml   afsluiten: invagen en blijven
//
// Altijd met een harde tijdslimiet: de sessie start het onder `timeout`, en
// de QML zelf stopt na maxMs. Een hangend startscherm kan je scherm dus niet
// blijvend afdekken.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: splashRoot

    readonly property bool leaving: Quickshell.env("KINGSTRA_SPLASH_MODE") === "out"
    readonly property string themeDir: "file:///usr/share/plymouth/themes/kingstra/"
    // Startscherm: hooguit zo lang in beeld, ook als er nooit "klaar" komt.
    readonly property int maxMs: 12000
    // Kort minimum, zodat het geen flits wordt.
    readonly property int minMs: 900

    // Pas tonen als de achtergrond op elk scherm geladen is, zodat alle
    // schermen tegelijk afgedekt worden (anders verscheen het per scherm).
    property int loadedScreens: 0
    readonly property bool allLoaded: loadedScreens >= Quickshell.screens.length
    property real cover: 0
    property bool fading: false
    property real spin: 0
    property real breathe: 0

    Behavior on cover {
        NumberAnimation {
            duration: splashRoot.fading ? 750 : (splashRoot.leaving ? 400 : 180)
            easing.type: Easing.OutCubic
        }
    }

    function finish() {
        if (splashRoot.leaving || splashRoot.fading)
            return;
        splashRoot.fading = true;
        splashRoot.cover = 0;
        quitTimer.start();
    }

    function reveal() {
        if (splashRoot.cover > 0 || splashRoot.fading)
            return;
        splashRoot.cover = 1;
        if (splashRoot.leaving)
            coveredTimer.start();
    }

    onAllLoadedChanged: if (allLoaded) reveal()

    // Vangnet: laadt een afbeelding niet, toch tonen.
    Timer {
        interval: 700
        running: true
        onTriggered: splashRoot.reveal()
    }

    // Afsluiten: kingstra-power wacht op dit bestand voordat het systemctl roept.
    Timer {
        id: coveredTimer
        interval: 450
        onTriggered: coveredSignal.running = true
    }
    Process {
        id: coveredSignal
        command: ["sh", "-c", "touch \"${XDG_RUNTIME_DIR:-/tmp}/kingstra-splash-covered\""]
    }

    Timer {
        id: quitTimer
        interval: 850
        onTriggered: Qt.quit()
    }

    Timer {
        interval: splashRoot.maxMs
        running: !splashRoot.leaving
        onTriggered: splashRoot.finish()
    }

    // Draaiende boog en ademende ringen, net als in Plymouth.
    NumberAnimation on spin {
        from: 0
        to: 360
        duration: 2600
        loops: Animation.Infinite
    }
    SequentialAnimation on breathe {
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 1600; easing.type: Easing.InOutSine }
    }

    // Klaar = de shell-surface van de balk en de achtergrond staan er.
    property int elapsedMs: 0
    property bool readySeen: false

    Timer {
        id: pollTimer
        interval: 250
        repeat: true
        running: !splashRoot.leaving && !splashRoot.fading
        onTriggered: {
            splashRoot.elapsedMs += interval;
            if (!layerProbe.running)
                layerProbe.running = true;
        }
    }

    Process {
        id: layerProbe
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let names = [];
                try {
                    const data = JSON.parse(text);
                    for (const mon in data) {
                        const levels = data[mon].levels || {};
                        for (const lvl in levels)
                            for (const layerItem of levels[lvl])
                                names.push(String(layerItem.namespace));
                    }
                } catch (e) {
                    return;
                }
                const shell = names.indexOf("quickshell:kingstra-shell-surface") >= 0;
                const paper = names.some(n => n.indexOf("skwd-paper") === 0 || n === "mpvpaper");
                if (shell && paper && !splashRoot.readySeen) {
                    splashRoot.readySeen = true;
                    settleTimer.start();
                }
            }
        }
    }

    // Even laten zakken (eerste frames van balk en achtergrond), dan weg.
    Timer {
        id: settleTimer
        interval: Math.max(350, splashRoot.minMs - splashRoot.elapsedMs)
        onTriggered: splashRoot.finish()
    }

    IpcHandler {
        target: "splash"
        function done(): void { splashRoot.finish(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: splashWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:kingstra-shell-splash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Klikken gaan erdoorheen: het startscherm houdt niets tegen.
            mask: Region {}

            Item {
                id: stage
                anchors.fill: parent
                opacity: splashRoot.cover

                readonly property real sc: Math.max(0.35, 1 + (width - 1920) / 1920 * 0.85)

                Rectangle {
                    anchors.fill: parent
                    color: "#0d0d12"
                }

                Image {
                    anchors.fill: parent
                    source: splashRoot.themeDir + "background.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    property bool counted: false
                    onStatusChanged: {
                        if (!counted && (status === Image.Ready || status === Image.Error)) {
                            counted = true;
                            splashRoot.loadedScreens += 1;
                        }
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: 360 * stage.sc
                    height: width
                    source: splashRoot.themeDir + "ring-outer.png"
                    opacity: 0.18 + 0.12 * splashRoot.breathe
                    smooth: true
                    mipmap: true
                }
                Image {
                    anchors.centerIn: parent
                    width: 300 * stage.sc
                    height: width
                    source: splashRoot.themeDir + "ring-mid.png"
                    opacity: 0.28 + 0.12 * (1 - splashRoot.breathe)
                    smooth: true
                    mipmap: true
                }
                Image {
                    anchors.centerIn: parent
                    width: 240 * stage.sc
                    height: width
                    source: splashRoot.themeDir + "ring-arc.png"
                    rotation: splashRoot.spin
                    smooth: true
                    mipmap: true
                }
                Image {
                    anchors.centerIn: parent
                    width: 170 * stage.sc
                    height: width
                    // Startscherm: bol zonder aan/uit-teken; afsluiten: met.
                    source: splashRoot.themeDir + (splashRoot.leaving || plainMissing ? "orb.png" : "orb-plain.png")
                    property bool plainMissing: false
                    onStatusChanged: if (status === Image.Error && !splashRoot.leaving) plainMissing = true
                    smooth: true
                    mipmap: true
                    // Bij het weggaan zakt de bol iets terug, zoals de intro van de shell.
                    scale: splashRoot.fading ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
