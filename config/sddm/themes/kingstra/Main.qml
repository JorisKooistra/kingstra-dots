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
    property bool loginInProgress: false
    property bool biometricActive: false
    property string authStatusText: "Klaar voor fingerprint of wachtwoord"
    property string authHintText: "Raak de scanner aan of gebruik je wachtwoord"

    function setAuthFeedback(statusText, hintText, biometric) {
        authStatusText = statusText
        authHintText = hintText
        biometricActive = biometric
    }

    function startFingerprintLogin() {
        if (loginInProgress || !currentUserName || currentUserName === "gebruiker")
            return

        loginFailed = false
        loginInProgress = true
        inputActive = true
        passwordField.text = ""
        passwordField.forceActiveFocus()
        setAuthFeedback("Raak de vingerafdrukscanner aan", "Typ iets om fingerprint over te slaan", true)
        sddm.login(currentUserName, "", sessionModel.lastIndex)
    }

    function startPasswordLogin(password) {
        if (loginInProgress || password.length === 0)
            return

        loginFailed = false
        loginInProgress = true
        setAuthFeedback("Wachtwoord controleren...", "Even controleren via PAM", false)
        sddm.login(currentUserName, password, sessionModel.lastIndex)
    }

    Component.onCompleted: {
        // Herstel laatste gebruiker
        for (var i = 0; i < userModel.count; i++) {
            if (userModel.data(userModel.index(i, 0), 257) === userModel.lastUser) {
                currentUserIndex = i
                break
            }
        }
        setAuthFeedback("Klaar voor fingerprint of wachtwoord", "Druk Enter op leeg veld of raak het icoon aan", false)
    }

    property string currentUserName: userModel.count > 0
        ? userModel.data(userModel.index(currentUserIndex, 0), 257)
        : "gebruiker"
    onCurrentUserNameChanged: {
        loginFailed = false
        loginInProgress = false
        passwordField.text = ""
        setAuthFeedback("Klaar voor fingerprint of wachtwoord", "Druk Enter op leeg veld of raak het icoon aan", false)
    }

    // Fout-afhandeling vanuit SDDM
    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.loginInProgress = false
        }

        function onLoginFailed() {
            passwordField.text = ""
            root.loginInProgress = false
            root.loginFailed   = true
            root.setAuthFeedback("Vingerafdruk of wachtwoord mislukt", "Probeer opnieuw of typ je wachtwoord", false)
            shakeAnim.restart()
            errorTimer.restart()
        }
    }

    Timer {
        id: errorTimer
        interval: 3000
        onTriggered: {
            root.loginFailed = false
            root.setAuthFeedback("Klaar voor fingerprint of wachtwoord", "Druk Enter op leeg veld of raak het icoon aan", false)
        }
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
                passwordField.forceActiveFocus()
                // De toets die het invoerveld opent hoort bij het wachtwoord.
                if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                    passwordField.insert(passwordField.cursorPosition, event.text)
                event.accepted = true
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
        // Zelfde klok als het vergrendelscherm (Lock.qml): uren en minuten
        // los, een gedimde dubbelepunt, en bij het typen een kleine krimp.
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.inputActive ? -120 : -40
        spacing: -10
        opacity: root.inputActive ? 0.0 : 1.0
        scale: root.inputActive ? 0.9 : 1.0
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            Text {
                id: clockHours
                font { family: "JetBrains Mono"; pixelSize: 140; bold: true }
                color: Colors.text
            }
            Text {
                text: ":"
                font { family: "JetBrains Mono"; pixelSize: 140; bold: true }
                opacity: 0.5
                color: Colors.text
            }
            Text {
                id: clockMinutes
                font { family: "JetBrains Mono"; pixelSize: 140; bold: true }
                color: Colors.text
            }
        }

        Text {
            id: dateLabel
            Layout.alignment: Qt.AlignHCenter
            font { family: "JetBrains Mono"; pixelSize: 22; bold: true }
            color: Colors.text
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Klik of typ om in te loggen"
            font { family: "JetBrains Mono"; pixelSize: 13 }
            color: Colors.outline
            topPadding: 18
        }

        Timer {
            interval: 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                let d = new Date()
                clockHours.text = Qt.formatTime(d, "hh")
                clockMinutes.text = Qt.formatTime(d, "mm")
                dateLabel.text = Qt.formatDate(d, "dddd d MMMM")
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
                    if (text.length === 0) {
                        root.startFingerprintLogin()
                    } else {
                        root.startPasswordLogin(text)
                    }
                }

                onTextChanged: {
                    root.loginFailed = false
                    if (text.length > 0) {
                        root.biometricActive = false
                        if (!root.loginInProgress) {
                            root.setAuthFeedback("Wachtwoord invoer actief", "Druk Enter om in te loggen", false)
                        }
                    } else if (!root.biometricActive) {
                        root.setAuthFeedback("Klaar voor fingerprint of wachtwoord", "Druk Enter op leeg veld of raak het icoon aan", false)
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 300; height: 78; radius: 22
            color: Qt.rgba(Colors.surface0.r, Colors.surface0.g, Colors.surface0.b, 0.34)
            border {
                width: 1
                color: root.loginFailed
                       ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.78)
                       : (root.biometricActive
                          ? Qt.rgba(Colors.green.r, Colors.green.g, Colors.green.b, 0.72)
                          : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.42))
            }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on border.color { ColorAnimation { duration: 220 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Item {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48

                    Rectangle {
                        anchors.centerIn: parent
                        width: 48; height: 48; radius: 24
                        color: "transparent"
                        border.width: 2
                        border.color: root.loginFailed
                                      ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.68)
                                      : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.46)
                        opacity: root.biometricActive ? 0.85 : 0.35
                        scale: fingerprintPulse.running ? 1.14 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Behavior on border.color { ColorAnimation { duration: 220 } }
                        Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: 17
                        color: root.loginFailed
                               ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.16)
                               : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.12)
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.loginFailed ? "󰌾" : "󰈷"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 21 }
                        color: root.loginFailed
                               ? Colors.red
                               : (root.biometricActive ? Colors.green : Colors.primary)
                        scale: root.biometricActive ? 1.08 : 1.0
                        Behavior on color { ColorAnimation { duration: 220 } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.loginInProgress
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startFingerprintLogin()
                    }

                    SequentialAnimation {
                        id: fingerprintPulse
                        running: root.biometricActive && !root.loginFailed
                        loops: Animation.Infinite
                        NumberAnimation { target: fingerprintHalo; property: "opacity"; from: 0.55; to: 0.0; duration: 1200; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 220 }
                    }

                    Rectangle {
                        id: fingerprintHalo
                        anchors.centerIn: parent
                        width: 46; height: 46; radius: 23
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(Colors.green.r, Colors.green.g, Colors.green.b, 0.72)
                        opacity: 0.0
                        scale: opacity > 0.0 ? 1.45 - opacity * 0.42 : 1.0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: root.authStatusText
                        font { family: "JetBrains Mono"; pixelSize: 12; bold: true }
                        color: root.loginFailed
                               ? Colors.red
                               : (root.biometricActive ? Colors.text : Colors.subtext0)
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.authHintText
                        font { family: "JetBrains Mono"; pixelSize: 10 }
                        color: Colors.outline
                        opacity: 0.95
                        elide: Text.ElideRight
                    }
                }
            }
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
    // Onderaan: sessie + power-knoppen, als pillen zoals op het
    // vergrendelscherm (48 px, licht glas, iets groter bij hover).
    // -------------------------------------------------------------------------
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property color accent: Colors.mauve
        property bool danger: false
        signal clicked()
        readonly property bool hovered: pillMa.containsMouse

        height: 48
        width: pillRow.implicitWidth + 36
        radius: height / 2
        color: hovered ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
                       : Qt.rgba(Colors.surface0.r, Colors.surface0.g, Colors.surface0.b, 0.4)
        border.width: 1
        border.color: hovered ? (danger ? Colors.red : accent) : Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.08)
        scale: hovered ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: pill.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                color: pill.hovered ? (pill.danger ? Colors.red : pill.accent) : Colors.subtext0
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                visible: pill.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                font { family: "JetBrains Mono"; pixelSize: 14; weight: Font.Black }
                color: Colors.text
            }
        }
        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: pill.clicked()
        }
    }

    RowLayout {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 40
        }
        spacing: 16

        Pill {
            icon: "󰌌"
            label: keyboard && keyboard.layouts.length > 0 && keyboard.currentLayout < keyboard.layouts.length
                ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : "US"
            onClicked: if (keyboard && keyboard.layouts.length > 1)
                keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
        Pill {
            icon: "󰍹"
            label: sessionModel.data(sessionModel.index(sessionModel.lastIndex, 0), 256) || "Hyprland"
        }
        Pill {
            icon: "󰑐"
            danger: true
            onClicked: sddm.reboot()
        }
        Pill {
            icon: "󰐥"
            danger: true
            onClicked: sddm.powerOff()
        }
    }
}
