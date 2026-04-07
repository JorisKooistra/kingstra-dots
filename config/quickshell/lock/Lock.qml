// =============================================================================
// Lock.qml — Kingstra vergrendelscherm
// =============================================================================
// Gebruikt WlSessionLock (ext-session-lock-v1) + PamContext voor authenticatie.
// Stijl volgt automatisch de Matugen-kleuren via colors.json.
//
// Aanroepen:  quickshell -p ~/.config/quickshell/lock/Lock.qml
// Hypridle:   lock_cmd = quickshell -p ~/.config/quickshell/lock/Lock.qml
// =============================================================================
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    // ---------------------------------------------------------------------------
    // Kleuren — geladen vanuit colors.json (zelfde bestand als de bar)
    // ---------------------------------------------------------------------------
    property var clr: ({
        primary:          "#89b4fa",
        on_primary:       "#1e1e2e",
        secondary:        "#cba6f7",
        tertiary:         "#a6e3a1",
        error:            "#f38ba8",
        background:       "#1e1e2e",
        surface:          "#313244",
        on_background:    "#cdd6f4",
        on_surface_variant: "#bac2de",
        outline:          "#6c7086",
        shadow:           "#000000"
    })

    Component.onCompleted: _loadColors()

    function _loadColors() {
        let xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + StandardPaths.writableLocation(StandardPaths.HomeLocation)
                 + "/.config/quickshell/colors.json", false)
        xhr.send()
        if (xhr.status === 0 && xhr.responseText !== "") {
            try { clr = JSON.parse(xhr.responseText) } catch(_) {}
        }
    }

    // ---------------------------------------------------------------------------
    // Gedeelde staat — wordt gesynchroniseerd over alle monitors
    // ---------------------------------------------------------------------------
    QtObject {
        id: lockState
        property bool inputActive:    false
        property bool authenticating: false
        property bool failed:         false
        property string statusText:   ""
    }

    // ---------------------------------------------------------------------------
    // PAM authenticatie
    // ---------------------------------------------------------------------------
    PamContext {
        id: pam
        Component.onCompleted: start()

        onCompleted: (result) => {
            lockState.authenticating = false
            if (result === PamResult.Success) {
                sessionLock.locked = false
                Qt.quit()
            } else {
                lockState.failed = true
                lockState.statusText = "Toegang geweigerd"
                failTimer.start()
                pam.start()
            }
        }
    }

    // Reset foutmelding na 2 seconden
    Timer {
        id: failTimer
        interval: 2000
        onTriggered: {
            lockState.failed = false
            lockState.statusText = ""
        }
    }

    // ---------------------------------------------------------------------------
    // Wayland session lock
    // ---------------------------------------------------------------------------
    WlSessionLock {
        id: sessionLock
        locked: true

        // Één oppervlak per monitor
        WlSessionLockSurface {
            id: lockSurface

            // -----------------------------------------------------------------
            // Achtergrondkleur (fallback terwijl wallpaper laadt)
            // -----------------------------------------------------------------
            Rectangle {
                anchors.fill: parent
                color: root.clr.background ?? "#1e1e2e"
            }

            // -----------------------------------------------------------------
            // Wallpaper — laad de laatste wallpaper uit de state
            // -----------------------------------------------------------------
            Image {
                id: wallpaperImg
                anchors.fill: parent
                source: {
                    let xhr = new XMLHttpRequest()
                    let stateFile = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                                   + "/.cache/kingstra/last-wallpaper"
                    xhr.open("GET", "file://" + stateFile, false)
                    xhr.send()
                    let p = xhr.responseText.trim()
                    return (p !== "") ? "file://" + p : ""
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                cache: false
            }

            // Wallpaper met blur
            MultiEffect {
                source: wallpaperImg
                anchors.fill: wallpaperImg
                blurEnabled: true
                blurMax: 64
                blur: 1.0
                visible: wallpaperImg.source !== ""
            }

            // Donker dimmer bovenop
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.45
            }

            // -----------------------------------------------------------------
            // Animerende kleurdruppels (subtiele achtergrondanimatie)
            // -----------------------------------------------------------------
            property real orbitAngle: 0
            NumberAnimation on orbitAngle {
                from: 0; to: Math.PI * 2
                duration: 80000
                loops: Animation.Infinite
                running: true
            }

            Rectangle {
                width: parent.width * 0.75; height: width; radius: width / 2
                x: parent.width  / 2 - width  / 2 + Math.cos(lockSurface.orbitAngle * 1.7) * 180
                y: parent.height / 2 - height / 2 + Math.sin(lockSurface.orbitAngle * 1.7) * 130
                color: root.clr.primary ?? "#89b4fa"
                opacity: lockState.inputActive ? 0.04 : 0.07
                Behavior on opacity { NumberAnimation { duration: 600 } }
            }
            Rectangle {
                width: parent.width * 0.65; height: width; radius: width / 2
                x: parent.width  / 2 - width  / 2 + Math.sin(lockSurface.orbitAngle * 1.3) * (-180)
                y: parent.height / 2 - height / 2 + Math.cos(lockSurface.orbitAngle * 1.3) * (-120)
                color: root.clr.secondary ?? "#cba6f7"
                opacity: lockState.inputActive ? 0.03 : 0.055
                Behavior on opacity { NumberAnimation { duration: 600 } }
            }

            // -----------------------------------------------------------------
            // Klik → inputveld activeren
            // -----------------------------------------------------------------
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    lockState.inputActive = true
                    passwordField.forceActiveFocus()
                }
            }

            // -----------------------------------------------------------------
            // KLOKMODULE — zichtbaar als inputveld niet actief is
            // -----------------------------------------------------------------
            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: lockState.inputActive ? -140 : -30
                spacing: 4
                opacity: lockState.inputActive ? 0.0 : 1.0
                visible: opacity > 0.01

                Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                // Uren : minuten
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0

                    Text {
                        id: clockH
                        font { family: "JetBrains Mono"; pixelSize: 120; bold: true }
                        color: root.clr.on_background ?? "#cdd6f4"
                    }
                    Text {
                        text: ":"
                        font { family: "JetBrains Mono"; pixelSize: 120; bold: true }
                        color: root.clr.on_background ?? "#cdd6f4"
                        opacity: 0.45
                    }
                    Text {
                        id: clockM
                        font { family: "JetBrains Mono"; pixelSize: 120; bold: true }
                        color: root.clr.on_background ?? "#cdd6f4"
                    }
                }

                // Datum
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    id: dateLabel
                    font { family: "JetBrains Mono"; pixelSize: 20 }
                    color: root.clr.on_surface_variant ?? "#bac2de"
                }

                // Klik-hint
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Klik om te ontgrendelen"
                    font { family: "JetBrains Mono"; pixelSize: 13 }
                    color: root.clr.outline ?? "#6c7086"
                    topPadding: 8
                }

                Timer {
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: {
                        let d = new Date()
                        clockH.text   = Qt.formatDateTime(d, "hh")
                        clockM.text   = Qt.formatDateTime(d, "mm")
                        dateLabel.text = Qt.formatDateTime(d, "dddd d MMMM")
                    }
                }
            }

            // -----------------------------------------------------------------
            // AUTHENTICATIEMODULE — zichtbaar als inputveld actief is
            // -----------------------------------------------------------------
            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: lockState.inputActive ? 0 : 60
                spacing: 20
                opacity: lockState.inputActive ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                // Gebruikersnaam
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: userPoller.userName
                    font { family: "JetBrains Mono"; pixelSize: 22; bold: true }
                    color: root.clr.on_background ?? "#cdd6f4"
                }

                // Wachtwoord-inputveld
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 320; height: 52
                    radius: 26
                    color: Qt.rgba(
                        parseInt((root.clr.surface ?? "#313244").slice(1,3), 16) / 255,
                        parseInt((root.clr.surface ?? "#313244").slice(3,5), 16) / 255,
                        parseInt((root.clr.surface ?? "#313244").slice(5,7), 16) / 255,
                        0.75
                    )
                    border {
                        width: 2
                        color: lockState.failed        ? (root.clr.error     ?? "#f38ba8")
                             : lockState.authenticating ? (root.clr.secondary ?? "#cba6f7")
                             :                            (root.clr.primary   ?? "#89b4fa")
                    }
                    Behavior on border.color { ColorAnimation { duration: 250 } }

                    TextInput {
                        id: passwordField
                        anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        font { family: "JetBrains Mono"; pixelSize: 16 }
                        color: root.clr.on_background ?? "#cdd6f4"
                        passwordCharacter: "●"
                        focus: lockState.inputActive
                        cursorVisible: false

                        // Plaatstekst
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: lockState.failed ? lockState.statusText : "Wachtwoord..."
                            font: passwordField.font
                            color: lockState.failed
                                   ? (root.clr.error ?? "#f38ba8")
                                   : (root.clr.outline ?? "#6c7086")
                            visible: passwordField.text.length === 0
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        onAccepted: {
                            if (text.length === 0) return
                            lockState.authenticating = true
                            lockState.failed = false
                            pam.response = text
                            text = ""
                        }

                        // Schud-animatie bij fout
                        SequentialAnimation {
                            id: shakeAnim
                            running: lockState.failed
                            NumberAnimation { target: passwordField.parent; property: "x"; to: -12; duration: 60 }
                            NumberAnimation { target: passwordField.parent; property: "x"; to:  12; duration: 60 }
                            NumberAnimation { target: passwordField.parent; property: "x"; to:  -8; duration: 50 }
                            NumberAnimation { target: passwordField.parent; property: "x"; to:   8; duration: 50 }
                            NumberAnimation { target: passwordField.parent; property: "x"; to:   0; duration: 40 }
                        }
                    }
                }

                // Status (laden / fout)
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: lockState.authenticating ? "Controleren..." : (lockState.failed ? lockState.statusText : "")
                    font { family: "JetBrains Mono"; pixelSize: 13 }
                    color: lockState.failed
                           ? (root.clr.error ?? "#f38ba8")
                           : (root.clr.on_surface_variant ?? "#bac2de")
                    opacity: text !== "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            // -----------------------------------------------------------------
            // Gebruikersnaam ophalen
            // -----------------------------------------------------------------
            QtObject {
                id: userPoller
                property string userName: ""
                Component.onCompleted: {
                    let xhr = new XMLHttpRequest()
                    xhr.open("GET", "file:///etc/passwd", false)
                    xhr.send()
                    // Simpeler: gebruik $USER env-var via Process
                    userNameProc.running = true
                }
            }

            Process {
                id: userNameProc
                command: ["bash", "-c", "echo $USER"]
                stdout: StdioCollector {
                    onStreamFinished: userPoller.userName = text.trim()
                }
            }
        }
    }
}
