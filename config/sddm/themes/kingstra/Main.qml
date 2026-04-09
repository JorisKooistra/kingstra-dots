// =============================================================================
// Main.qml — Kingstra SDDM-loginscherm
// =============================================================================
// Zelfde visuele taal als Lock.qml: klok → klik → wachtwoordinput.
// Kleuren komen uit Colors.qml (gegenereerd door matugen).
// =============================================================================
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: root
    width:  Screen.width  > 0 ? Screen.width  : 1920
    height: Screen.height > 0 ? Screen.height : 1080
    color:  Colors.background

    // UI-staat
    property bool inputActive: false
    property bool loginFailed: false
    property int  currentUserIndex: 0
    property bool autoPamKickDone: false

    function kickPamAuthOnce() {
        if (autoPamKickDone)
            return
        if (!currentUserName || currentUserName === "gebruiker")
            return
        autoPamKickTimer.restart()
    }

    Component.onCompleted: {
        // Herstel laatste gebruiker
        for (var i = 0; i < userModel.count; i++) {
            if (userModel.data(userModel.index(i, 0), 257) === userModel.lastUser) {
                currentUserIndex = i
                break
            }
        }
        kickPamAuthOnce()
    }

    property string currentUserName: userModel.count > 0
        ? userModel.data(userModel.index(currentUserIndex, 0), 257)
        : "gebruiker"
    onCurrentUserNameChanged: kickPamAuthOnce()

    Timer {
        id: autoPamKickTimer
        interval: 550
        repeat: false
        onTriggered: {
            if (root.autoPamKickDone || !root.currentUserName || root.currentUserName === "gebruiker")
                return
            root.autoPamKickDone = true
            root.inputActive = true
            passwordField.forceActiveFocus()
            sddm.login(root.currentUserName, "", sessionModel.lastIndex)
        }
    }

    // Fout-afhandeling vanuit SDDM
    Connections {
        target: sddm
        function onLoginFailed() {
            passwordField.text = ""
            root.loginFailed   = true
            shakeAnim.restart()
            errorTimer.restart()
        }
    }

    Timer {
        id: errorTimer
        interval: 3000
        onTriggered: root.loginFailed = false
    }

    // Klik overal → inputveld activeren
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.inputActive = true
            passwordField.forceActiveFocus()
        }
    }

    // Toetsenbord → ook direct activeren
    Item {
        anchors.fill: parent
        focus: !root.inputActive
        Keys.onPressed: (event) => {
            if (!root.inputActive) {
                root.inputActive = true
                event.accepted   = true
            }
        }
    }

    // -------------------------------------------------------------------------
    // Achtergrond: wallpaper + blur + dimmer
    // -------------------------------------------------------------------------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background !== "" ? config.background : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: false
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        visible: wallpaper.source !== ""
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.35
    }

    // -------------------------------------------------------------------------
    // Animerende kleurdruppels
    // -------------------------------------------------------------------------
    property real orbit: 0
    NumberAnimation on orbit {
        from: 0; to: Math.PI * 2
        duration: 80000; loops: Animation.Infinite; running: true
    }

    Rectangle {
        width: parent.width * 0.7; height: width; radius: width / 2
        x: parent.width  / 2 - width  / 2 + Math.cos(root.orbit * 1.7) * 180
        y: parent.height / 2 - height / 2 + Math.sin(root.orbit * 1.7) * 130
        color: Colors.blue
        opacity: root.inputActive ? 0.04 : 0.07
        Behavior on opacity { NumberAnimation { duration: 600 } }
    }
    Rectangle {
        width: parent.width * 0.6; height: width; radius: width / 2
        x: parent.width  / 2 - width  / 2 + Math.sin(root.orbit * 1.3) * (-180)
        y: parent.height / 2 - height / 2 + Math.cos(root.orbit * 1.3) * (-120)
        color: Colors.mauve
        opacity: root.inputActive ? 0.03 : 0.055
        Behavior on opacity { NumberAnimation { duration: 600 } }
    }

    // -------------------------------------------------------------------------
    // KLOKMODULE — zichtbaar als inputveld niet actief is
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.inputActive ? -140 : -30
        spacing: 4
        opacity: root.inputActive ? 0.0 : 1.0
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        Text {
            id: clockLabel
            Layout.alignment: Qt.AlignHCenter
            font { family: "JetBrains Mono"; pixelSize: 120; bold: true }
            color: Colors.text
        }

        Text {
            id: dateLabel
            Layout.alignment: Qt.AlignHCenter
            font { family: "JetBrains Mono"; pixelSize: 20 }
            color: Colors.subtext0
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Klik om in te loggen"
            font { family: "JetBrains Mono"; pixelSize: 13 }
            color: Colors.outline
            topPadding: 8
        }

        Timer {
            interval: 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                clockLabel.text = Qt.formatTime(new Date(), "hh:mm")
                dateLabel.text  = Qt.formatDate(new Date(), "dddd d MMMM")
            }
        }
    }

    // -------------------------------------------------------------------------
    // AUTHENTICATIEMODULE — zichtbaar als inputveld actief is
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.inputActive ? 0 : 60
        spacing: 20
        opacity: root.inputActive ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        // Gebruikersavatar
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 110; height: 110; radius: 55
            color: Qt.rgba(Colors.surface0.r, Colors.surface0.g, Colors.surface0.b, 0.5)
            border {
                width: 3
                color: root.loginFailed ? Colors.red : Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.4)
            }
            Behavior on border.color { ColorAnimation { duration: 300 } }
            clip: true

            Image {
                anchors.fill: parent
                source: sddm.facesDir + "/" + root.currentUserName + ".face.icon"
                fillMode: Image.PreserveAspectCrop
                onStatusChanged: if (status === Image.Error) source = ""
            }

            // Fallback icoon
            Text {
                anchors.centerIn: parent
                text: "󰀄"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 48 }
                color: Colors.subtext0
                visible: parent.children[0].status !== Image.Ready
            }
        }

        // Gebruikersnaam
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.currentUserName
            font { family: "JetBrains Mono"; pixelSize: 22; bold: true }
            color: Colors.text
        }

        // Wachtwoordveld
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 300; height: 52; radius: 26
            color: Qt.rgba(Colors.surface0.r, Colors.surface0.g, Colors.surface0.b, 0.6)
            border {
                width: 2
                color: root.loginFailed ? Colors.red : Colors.primary
            }
            Behavior on border.color { ColorAnimation { duration: 250 } }

            transform: Translate { id: shakeTr; x: 0 }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeTr; property: "x"; from: 0;   to: -10; duration: 80 }
                NumberAnimation { target: shakeTr; property: "x"; from: -10; to:  10; duration: 80 }
                NumberAnimation { target: shakeTr; property: "x"; from:  10; to:  -6; duration: 60 }
                NumberAnimation { target: shakeTr; property: "x"; from:  -6; to:   0; duration: 60 }
            }

            TextInput {
                id: passwordField
                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                font { family: "JetBrains Mono"; pixelSize: 16 }
                color: Colors.text
                focus: root.inputActive

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wachtwoord..."
                    font: passwordField.font
                    color: Colors.outline
                    visible: passwordField.text.length === 0
                }

                Keys.onEscapePressed: root.inputActive = false

                onAccepted: {
                    sddm.login(root.currentUserName, text, sessionModel.lastIndex)
                }

                onTextChanged: root.loginFailed = false
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Fingerprint/PAM start automatisch; druk Enter op leeg veld als fallback"
            font { family: "JetBrains Mono"; pixelSize: 11 }
            color: Colors.outline
            opacity: 0.9
        }

        // Foutmelding
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Inloggen mislukt — probeer opnieuw"
            font { family: "JetBrains Mono"; pixelSize: 12 }
            color: Colors.red
            opacity: root.loginFailed ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // -------------------------------------------------------------------------
    // Onderaan: sessiekiezer + power-knoppen
    // -------------------------------------------------------------------------
    RowLayout {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 32
        }
        spacing: 16
        opacity: root.inputActive ? 0.7 : 0.35
        Behavior on opacity { NumberAnimation { duration: 300 } }

        // Sessie
        Rectangle {
            width: sessionLabel.implicitWidth + 24; height: 32; radius: 16
            color: Qt.rgba(Colors.surface0.r, Colors.surface0.g, Colors.surface0.b, 0.4)

            Text {
                id: sessionLabel
                anchors.centerIn: parent
                text: sessionModel.data(sessionModel.index(sessionModel.lastIndex, 0), 256) || "Hyprland"
                font { family: "JetBrains Mono"; pixelSize: 12 }
                color: Colors.subtext0
            }
        }

        // Reboot
        Rectangle {
            width: 32; height: 32; radius: 16
            color: rebootMa.containsMouse
                   ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2)
                   : Qt.rgba(Colors.surface0.r, Colors.surface0.g, Colors.surface0.b, 0.4)
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "󰑐"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                color: Colors.subtext0
            }

            MouseArea {
                id: rebootMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.reboot()
            }
        }

        // Afsluiten
        Rectangle {
            width: 32; height: 32; radius: 16
            color: powerMa.containsMouse
                   ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2)
                   : Qt.rgba(Colors.surface0.r, Colors.surface0.g, Colors.surface0.b, 0.4)
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                color: Colors.subtext0
            }

            MouseArea {
                id: powerMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.powerOff()
            }
        }
    }
}
