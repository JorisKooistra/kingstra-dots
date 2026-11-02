// =============================================================================
// Main.qml — Kingstra SDDM-inlogscherm
// =============================================================================
// Zelfde ontwerp als het vergrendelscherm (config/quickshell/Lock.qml):
// intro met ringen → klok → klik of typ → avatar + wachtwoordpil.
// Kleuren komen uit Colors.qml (matugen), lettertype/tempo/sfeer uit
// Style.qml (actief thema). Beide schrijft kingstra-sddm-sync.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: root
    width:  Screen.width  > 0 ? Screen.width  : 1920
    height: Screen.height > 0 ? Screen.height : 1080
    color:  cBase

    // -------------------------------------------------------------------------
    // Palet — dezelfde rollen als Lock.qml. Een oudere Colors.qml (van vóór
    // deze rollen) valt terug op de oude namen in plaats van leeg te blijven.
    // -------------------------------------------------------------------------
    function pick(value, fallback) { return value !== undefined ? value : fallback }
    readonly property color cBase:     pick(Colors.base, Colors.background)
    readonly property color cText:     Colors.text
    readonly property color cSubtext:  Colors.subtext0
    readonly property color cOutline:  Colors.outline
    readonly property color cSurface0: pick(Colors.surface1 !== undefined ? Colors.surface0 : undefined, Colors.surface)
    readonly property color cSurface1: pick(Colors.surface1, Colors.surface0)
    readonly property color cMauve:    Colors.mauve
    readonly property color cBlue:     pick(Colors.peach !== undefined ? Colors.blue : undefined, Colors.primary)
    readonly property color cGreen:    Colors.green
    readonly property color cPeach:    pick(Colors.peach, Colors.primary)
    readonly property color cRed:      Colors.red
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // -------------------------------------------------------------------------
    // Thema: lettertype zoals ThemeConfig.textFont, tempo zoals duration().
    // -------------------------------------------------------------------------
    readonly property var fontList: Qt.fontFamilies()
    function hasFont(name) {
        if (!name) return false
        for (var i = 0; i < fontList.length; i++)
            if (fontList[i] === name) return true
        return false
    }
    readonly property string textFont: Style.theme === "matte" && hasFont(Style.uiFont) ? Style.uiFont
        : hasFont(Style.monoFont) ? Style.monoFont : "JetBrains Mono"
    readonly property string iconFont: hasFont("Iosevka Nerd Font") ? "Iosevka Nerd Font" : "JetBrainsMono Nerd Font"
    readonly property int headingWeight: Style.theme === "matte" ? Font.Medium : Font.Bold
    function dur(ms) { return Math.max(1, Math.round(ms * (Style.motionScale > 0 ? Style.motionScale : 1.0))) }
    // De intro blijft kort, ook bij een traag thema (Paper).
    function introDur(ms) { return Math.max(1, Math.round(ms * Math.min(1.2, Style.motionScale > 0 ? Style.motionScale : 1.0))) }

    // Zelfde schaal als Scaler.qml: 1920 breed = 1.0.
    readonly property real sc: Math.max(0.35, Math.pow(Math.max(1, width) / 1920.0, 0.85))

    // -------------------------------------------------------------------------
    // UI-staat
    // -------------------------------------------------------------------------
    property bool inputActive: false
    property bool loginFailed: false
    property bool loginInProgress: false
    property bool biometricActive: false
    property bool leaving: false
    property real introState: 0.0
    property bool introDone: false
    property int  currentUserIndex: 0
    property int  sessionIndex: (typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    readonly property string typedText: passwordField.text
    property string authStatusText: "Vingerafdruk of wachtwoord"
    property string authHintText: "Enter op leeg veld = vingerafdruk"

    // Gebruikers en sessies via hun rolnamen (name, realName, icon), niet via
    // rolnummers: die verschillen per SDDM-versie.
    Repeater {
        id: userList
        model: typeof userModel !== "undefined" ? userModel : 0
        delegate: Item {
            property string uName: model.name || ""
            property string uReal: model.realName || ""
            property string uIcon: model.icon || ""
        }
        onItemAdded: (index, item) => {
            if (typeof userModel !== "undefined" && item.uName === userModel.lastUser)
                root.currentUserIndex = index
        }
    }
    Repeater {
        id: sessionList
        model: typeof sessionModel !== "undefined" ? sessionModel : 0
        delegate: Item { property string sName: model.name || "" }
    }

    readonly property var currentUser: userList.count > 0 ? userList.itemAt(Math.min(currentUserIndex, userList.count - 1)) : null
    readonly property string currentUserName: currentUser && currentUser.uName !== ""
        ? currentUser.uName
        : (typeof userModel !== "undefined" && userModel.lastUser ? userModel.lastUser : "")
    readonly property string currentUserLabel: currentUser && currentUser.uReal !== "" ? currentUser.uReal
        : (currentUserName !== "" ? currentUserName : "gebruiker")
    readonly property string currentUserIcon: currentUser && currentUser.uIcon !== ""
        ? currentUser.uIcon
        : (currentUserName !== "" ? sddm.facesDir + "/" + currentUserName + ".face.icon" : "")
    readonly property var currentSession: sessionList.count > 0 ? sessionList.itemAt(Math.min(sessionIndex, sessionList.count - 1)) : null
    readonly property string sessionName: currentSession && currentSession.sName !== "" ? currentSession.sName : "Hyprland"

    readonly property bool hasKeyboard: typeof keyboard !== "undefined" && keyboard !== null && keyboard.layouts !== undefined
    readonly property string kbLabel: {
        if (!hasKeyboard || keyboard.layouts.length === 0 || keyboard.currentLayout >= keyboard.layouts.length) return "US"
        var label = String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase()
        return keyboard.capsLock ? label + " · CAPS" : label
    }

    function setAuthFeedback(statusText, hintText, biometric) {
        authStatusText = statusText
        authHintText = hintText
        biometricActive = biometric
    }
    function resetFeedback() {
        setAuthFeedback("Vingerafdruk of wachtwoord", "Enter op leeg veld = vingerafdruk", false)
    }
    function activate() {
        inputActive = true
        passwordField.forceActiveFocus()
    }
    function startFingerprintLogin() {
        if (loginInProgress || currentUserName === "") return
        loginFailed = false
        loginInProgress = true
        activate()
        passwordField.text = ""
        setAuthFeedback("Raak de scanner aan", "Of typ je wachtwoord", true)
        sddm.login(currentUserName, "", sessionIndex)
    }
    function startPasswordLogin(password) {
        if (loginInProgress || password.length === 0) return
        loginFailed = false
        loginInProgress = true
        setAuthFeedback("Controleren…", "Even geduld", false)
        sddm.login(currentUserName, password, sessionIndex)
    }
    function cycleUser(step) {
        if (userList.count < 2 || loginInProgress) return
        currentUserIndex = (currentUserIndex + step + userList.count) % userList.count
    }

    onCurrentUserNameChanged: {
        loginFailed = false
        loginInProgress = false
        passwordField.text = ""
        resetFeedback()
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.loginInProgress = false
            root.leaving = true
        }
        function onLoginFailed() {
            passwordField.text = ""
            root.loginInProgress = false
            root.loginFailed = true
            root.setAuthFeedback("Inloggen mislukt", "Probeer het opnieuw", false)
            shakeAnim.restart()
            errorTimer.restart()
        }
    }

    Timer {
        id: errorTimer
        interval: 3000
        onTriggered: { root.loginFailed = false; root.resetFeedback() }
    }

    // Leeg en 15 s niets gedaan: terug naar de klok (zoals Lock.qml).
    Timer {
        interval: 15000
        running: root.inputActive && passwordField.text.length === 0 && !root.loginInProgress
        onTriggered: root.inputActive = false
    }

    // Klik overal → invoer actief
    MouseArea {
        anchors.fill: parent
        onClicked: root.activate()
    }

    // Eerste toets opent de invoer en telt mee als wachtwoordteken.
    Item {
        anchors.fill: parent
        focus: !root.inputActive
        Keys.onPressed: (event) => {
            if (root.inputActive) return
            root.activate()
            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return
                    && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape)
                passwordField.insert(passwordField.cursorPosition, event.text)
            event.accepted = true
        }
    }

    // -------------------------------------------------------------------------
    // 1. LEVENDE ACHTERGROND
    // -------------------------------------------------------------------------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background !== "" ? config.background : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        cache: false
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blurMax: 64 * root.sc
        blur: 1.0
        visible: wallpaper.status === Image.Ready
    }

    // Licht thema (Paper) dimt naar papier, donkere thema's naar zwart.
    Rectangle {
        anchors.fill: parent
        color: Style.light ? root.cBase : "black"
        opacity: Style.light ? 0.38 : 0.25
    }

    property real orbit: 0
    NumberAnimation on orbit {
        from: 0; to: Math.PI * 2
        duration: 90000; loops: Animation.Infinite; running: !root.leaving
    }

    Item {
        anchors.fill: parent

        Rectangle {
            width: parent.width * 0.8; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(root.orbit * 2) * (200 * root.sc)
            y: (parent.height / 2 - height / 2) + Math.sin(root.orbit * 2) * (150 * root.sc)
            scale: 1.0 + Math.sin(root.orbit * 6) * 0.05
            color: root.cMauve
            opacity: (root.inputActive ? 0.04 : 0.08) * (1.0 + Style.glow)
            Behavior on opacity { NumberAnimation { duration: root.dur(600) } }
        }
        Rectangle {
            width: parent.width * 0.9; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(root.orbit * 1.5) * (-200 * root.sc)
            y: (parent.height / 2 - height / 2) + Math.cos(root.orbit * 1.5) * (-150 * root.sc)
            scale: 1.0 + Math.cos(root.orbit * 5) * 0.05
            color: root.cBlue
            opacity: (root.inputActive ? 0.03 : 0.06) * (1.0 + Style.glow)
            Behavior on opacity { NumberAnimation { duration: root.dur(600) } }
        }

        // Concentrische ringen achter klok en avatar; rood bij een fout.
        Item {
            anchors.fill: parent
            opacity: root.introState
            scale: 1.1 - 0.1 * root.introState
            Repeater {
                model: 4
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -40 * root.sc
                    width: (400 + index * 220) * root.sc
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: root.loginFailed ? root.cRed : root.cText
                    border.width: Math.max(1, 1 * root.sc)
                    opacity: root.loginFailed ? (0.1 - index * 0.02)
                           : (root.inputActive ? (0.02 - index * 0.005) : (0.04 - index * 0.01))
                    Behavior on border.color { ColorAnimation { duration: root.dur(600); easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: root.dur(600); easing.type: Easing.OutExpo } }
                }
            }
        }
    }

    // Neon: dezelfde scanlijnen als de bar.
    Column {
        anchors.fill: parent
        visible: Style.texture === "scanline"
        opacity: Style.textureOpacity
        Repeater {
            model: Style.texture === "scanline" ? Math.ceil(root.height / 4) : 0
            Item {
                width: root.width; height: 4
                Rectangle { width: parent.width; height: 1; color: root.cText }
            }
        }
    }

    // -------------------------------------------------------------------------
    // 2. INHOUD
    // -------------------------------------------------------------------------
    Item {
        id: content
        anchors.fill: parent
        opacity: root.introState * (root.leaving ? 0.0 : 1.0)
        scale: root.leaving ? 1.06 : 1.0
        transform: Translate { y: (30 * root.sc) * (1.0 - root.introState) }
        Behavior on opacity { enabled: root.leaving; NumberAnimation { duration: root.dur(350); easing.type: Easing.InCubic } }
        Behavior on scale { NumberAnimation { duration: root.dur(400); easing.type: Easing.InCubic } }

        // --- KLOK (rust) ---
        ColumnLayout {
            id: clockModule
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.inputActive ? -120 * root.sc : -40 * root.sc
            spacing: -10 * root.sc
            opacity: root.inputActive ? 0.0 : 1.0
            scale: root.inputActive ? 0.9 : 1.0
            visible: opacity > 0.01

            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: root.dur(600); easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: root.dur(400); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.dur(500); easing.type: Easing.OutBack } }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0
                Text {
                    id: clockHours
                    font.family: root.textFont
                    font.pixelSize: 140 * root.sc
                    font.weight: root.headingWeight
                    color: root.cText
                }
                Text {
                    text: ":"
                    font.family: root.textFont
                    font.pixelSize: 140 * root.sc
                    font.weight: root.headingWeight
                    opacity: 0.5
                    color: root.cText
                }
                Text {
                    id: clockMinutes
                    font.family: root.textFont
                    font.pixelSize: 140 * root.sc
                    font.weight: root.headingWeight
                    color: root.cText
                }
            }

            Text {
                id: dateLabel
                Layout.alignment: Qt.AlignHCenter
                font.family: root.textFont
                font.pixelSize: 22 * root.sc
                font.weight: root.headingWeight
                color: root.cText
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                topPadding: 26 * root.sc
                text: "KLIK OF TYP OM IN TE LOGGEN"
                font.family: root.textFont
                font.pixelSize: 12 * root.sc
                font.weight: Font.Medium
                font.letterSpacing: 2.0
                color: root.alpha(root.cText, 0.55)
            }

            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    var d = new Date()
                    var h = Qt.formatTime(d, "hh"), m = Qt.formatTime(d, "mm"), t = Qt.formatDate(d, "dddd d MMMM")
                    if (clockHours.text !== h) clockHours.text = h
                    if (clockMinutes.text !== m) clockMinutes.text = m
                    if (dateLabel.text !== t) dateLabel.text = t
                }
            }
        }

        // --- AUTHENTICATIE (invoer) ---
        RowLayout {
            id: authModule
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.inputActive ? -40 * root.sc : 40 * root.sc
            spacing: 32 * root.sc
            opacity: root.inputActive ? 1.0 : 0.0
            scale: root.inputActive ? 1.0 : 0.9
            visible: opacity > 0.01

            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: root.dur(600); easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: root.dur(400); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.dur(500); easing.type: Easing.OutBack } }

            // Links: avatar
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 170 * root.sc
                implicitHeight: implicitWidth

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: height / 2
                    color: "black"
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.alpha(root.cSurface0, 0.5)
                    visible: avatarImg.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text: "󰀄"
                        font.family: root.iconFont
                        font.pixelSize: 64 * root.sc
                        color: root.cSubtext
                    }
                }
                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: root.currentUserIcon
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    cache: false
                    asynchronous: true
                }
                MultiEffect {
                    anchors.fill: avatarImg
                    source: avatarImg
                    maskEnabled: true
                    maskSource: avatarMask
                    visible: avatarImg.status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: Math.max(1, 3 * root.sc)
                    border.color: root.loginFailed ? root.cRed
                                : (root.loginInProgress ? root.cPeach : root.alpha(root.cText, 0.5))
                    Behavior on border.color { ColorAnimation { duration: root.dur(300) } }
                }
            }

            // Rechts: naam, status en wachtwoordpil
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 16 * root.sc

                RowLayout {
                    spacing: 10 * root.sc
                    Text {
                        text: root.currentUserLabel
                        font.family: root.textFont
                        font.pixelSize: 28 * root.sc
                        font.weight: root.headingWeight
                        color: root.cText
                    }
                    // Meerdere gebruikers: wisselen met de pijl.
                    Rectangle {
                        visible: userList.count > 1
                        implicitWidth: 30 * root.sc; implicitHeight: implicitWidth
                        radius: height / 2
                        color: userSwitch.containsMouse ? root.alpha(root.cSurface1, 0.6) : "transparent"
                        border.width: 1
                        border.color: root.alpha(root.cText, userSwitch.containsMouse ? 0.25 : 0.08)
                        Behavior on color { ColorAnimation { duration: root.dur(200) } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰁔"
                            font.family: root.iconFont
                            font.pixelSize: 16 * root.sc
                            color: root.cSubtext
                        }
                        MouseArea { id: userSwitch; anchors.fill: parent; hoverEnabled: true; onClicked: root.cycleUser(1) }
                    }
                }

                RowLayout {
                    spacing: 12 * root.sc

                    // Statusbol: vingerafdruk/slot; klik start vingerafdruk.
                    Item {
                        implicitWidth: 36 * root.sc; implicitHeight: implicitWidth

                        Rectangle {
                            id: fingerprintHalo
                            anchors.centerIn: parent
                            width: parent.width; height: width; radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: root.cGreen
                            opacity: 0.0
                            scale: 1.0 + (1.0 - opacity) * 0.5
                        }
                        SequentialAnimation {
                            running: root.biometricActive && !root.loginFailed
                            loops: Animation.Infinite
                            NumberAnimation { target: fingerprintHalo; property: "opacity"; from: 0.6; to: 0.0; duration: 1200; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 220 }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: root.loginFailed ? root.alpha(root.cRed, 0.2)
                                 : (root.loginInProgress && !root.biometricActive ? root.alpha(root.cPeach, 0.2)
                                 : (root.biometricActive ? root.alpha(root.cGreen, 0.18) : root.alpha(root.cMauve, 0.15)))
                            border.width: Math.max(1, 1 * root.sc)
                            border.color: root.loginFailed ? root.cRed
                                        : (root.loginInProgress && !root.biometricActive ? root.cPeach
                                        : (root.biometricActive ? root.cGreen : root.cMauve))
                            scale: fpMouse.containsMouse ? 1.1 : 1.0
                            Behavior on color { ColorAnimation { duration: root.dur(300) } }
                            Behavior on border.color { ColorAnimation { duration: root.dur(300) } }
                            Behavior on scale { NumberAnimation { duration: root.dur(250); easing.type: Easing.OutBack } }

                            Text {
                                anchors.centerIn: parent
                                text: root.loginFailed ? "󰌾"
                                    : (passwordField.text.length === 0 ? "󰈷" : (root.loginInProgress ? "󰌿" : "󰌾"))
                                font.family: root.iconFont
                                font.pixelSize: 18 * root.sc
                                color: parent.border.color
                            }
                        }
                        MouseArea {
                            id: fpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.loginInProgress
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startFingerprintLogin()
                        }
                    }

                    Text {
                        Layout.maximumWidth: 420 * root.sc
                        elide: Text.ElideRight
                        text: root.authStatusText.toUpperCase()
                        font.family: root.textFont
                        font.pixelSize: 14 * root.sc
                        font.weight: Font.Medium
                        font.letterSpacing: 2.0
                        color: root.loginFailed ? root.cRed
                             : (root.loginInProgress && !root.biometricActive ? root.cPeach : root.cText)
                        Behavior on color { ColorAnimation { duration: root.dur(300) } }
                    }
                }

                // Wachtwoordpil met bolletjes, zoals op het vergrendelscherm.
                Rectangle {
                    id: pinPill
                    implicitWidth: 280 * root.sc
                    implicitHeight: 60 * root.sc
                    radius: height / 2
                    clip: true
                    color: root.loginFailed ? root.alpha(root.cRed, 0.1) : root.alpha(root.cSurface0, 0.5)
                    border.width: Math.max(1, 2 * root.sc)
                    border.color: root.loginFailed ? root.cRed
                                : (root.loginInProgress && !root.biometricActive ? root.cPeach
                                : (passwordField.text.length > 0 ? root.cText : root.alpha(root.cText, 0.08)))
                    scale: root.loginFailed ? 1.05 : (root.loginInProgress ? 0.98 : 1.0)
                    Behavior on color { ColorAnimation { duration: root.dur(250); easing.type: Easing.OutExpo } }
                    Behavior on border.color { ColorAnimation { duration: root.dur(250); easing.type: Easing.OutExpo } }
                    Behavior on scale { NumberAnimation { duration: root.dur(300); easing.type: Easing.OutBack } }

                    transform: Translate { id: shakeTr; x: 0 }
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: shakeTr; property: "x"; from: 0; to: -8 * root.sc; duration: 120; easing.type: Easing.InOutSine }
                        NumberAnimation { target: shakeTr; property: "x"; from: -8 * root.sc; to: 8 * root.sc; duration: 120; easing.type: Easing.InOutSine }
                        NumberAnimation { target: shakeTr; property: "x"; from: 8 * root.sc; to: 0; duration: 120; easing.type: Easing.InOutSine }
                    }

                    TextInput {
                        id: passwordField
                        anchors.fill: parent
                        opacity: 0
                        echoMode: TextInput.Password
                        focus: root.inputActive
                        enabled: !root.leaving

                        Keys.onEscapePressed: {
                            text = ""
                            root.inputActive = false
                        }
                        onAccepted: {
                            if (text.length === 0) root.startFingerprintLogin()
                            else root.startPasswordLogin(text)
                        }
                        onTextChanged: {
                            while (dotModel.count < text.length) dotModel.append({})
                            while (dotModel.count > text.length) dotModel.remove(dotModel.count - 1)
                            if (text.length > 0) {
                                root.loginFailed = false
                                root.biometricActive = false
                                if (!root.loginInProgress)
                                    root.setAuthFeedback("Wachtwoord", "Enter om in te loggen", false)
                            } else if (!root.biometricActive && !root.loginInProgress && !root.loginFailed) {
                                root.resetFeedback()
                            }
                        }
                    }

                    ListModel { id: dotModel }

                    Text {
                        anchors.centerIn: parent
                        visible: dotModel.count === 0
                        width: parent.width - 40 * root.sc
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.authHintText
                        font.family: root.textFont
                        font.pixelSize: 12 * root.sc
                        color: root.alpha(root.cText, 0.45)
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 20 * root.sc
                        anchors.rightMargin: 20 * root.sc
                        clip: true
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: width > parent.width ? parent.width - width : (parent.width - width) / 2
                            spacing: 4 * root.sc
                            Behavior on x { NumberAnimation { duration: root.dur(150); easing.type: Easing.OutQuad } }
                            Repeater {
                                model: dotModel
                                delegate: Text {
                                    text: "•"
                                    font.family: root.textFont
                                    font.pixelSize: 32 * root.sc
                                    font.weight: Font.Bold
                                    color: root.loginFailed ? root.cRed : (root.loginInProgress ? root.cPeach : root.cText)
                                    verticalAlignment: Text.AlignVCenter
                                    height: pinPill.height
                                    NumberAnimation on opacity { from: 0; to: 1; duration: 150 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // 3. ONDERAAN: pillen zoals op het vergrendelscherm
    // -------------------------------------------------------------------------
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property color accent: root.cMauve
        signal clicked()
        readonly property bool hovered: pillMa.containsMouse

        implicitHeight: 48 * root.sc
        implicitWidth: pillRow.implicitWidth + 36 * root.sc
        radius: height / 2
        color: hovered ? root.alpha(root.cSurface1, 0.6) : root.alpha(root.cSurface0, 0.4)
        border.width: Math.max(1, 1 * root.sc)
        border.color: hovered ? accent : root.alpha(root.cText, 0.08)
        scale: hovered ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: root.dur(250); easing.type: Easing.OutExpo } }
        Behavior on color { ColorAnimation { duration: root.dur(200) } }
        Behavior on border.color { ColorAnimation { duration: root.dur(200) } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8 * root.sc
            Text {
                visible: pill.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                font.family: root.iconFont
                font.pixelSize: 18 * root.sc
                color: pill.hovered ? pill.accent : root.cSubtext
                Behavior on color { ColorAnimation { duration: root.dur(200) } }
            }
            Text {
                visible: pill.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                font.family: root.textFont
                font.pixelSize: 14 * root.sc
                font.weight: Font.Black
                color: root.cText
            }
        }
        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40 * root.sc
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16 * root.sc
        opacity: root.introState * (root.leaving ? 0.0 : 1.0)
        transform: Translate { y: (20 * root.sc) * (1.0 - root.introState) }
        Behavior on opacity { enabled: root.leaving; NumberAnimation { duration: root.dur(300) } }

        Pill {
            icon: "󰌌"
            label: root.kbLabel
            onClicked: if (root.hasKeyboard && keyboard.layouts.length > 1)
                keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
        Pill {
            icon: "󰍹"
            label: root.sessionName
            accent: root.cBlue
            onClicked: if (sessionList.count > 1)
                root.sessionIndex = (root.sessionIndex + 1) % sessionList.count
        }
        Pill {
            visible: sddm.canSuspend === true
            icon: "󰒲"
            accent: root.cMauve
            onClicked: sddm.suspend()
        }
        Pill {
            icon: "󰜉"
            accent: root.cBlue
            onClicked: sddm.reboot()
        }
        Pill {
            icon: "󰐥"
            accent: root.cRed
            onClicked: sddm.powerOff()
        }
    }

    // -------------------------------------------------------------------------
    // 4. INTRO — bol met ringen die openspringt, daarna de klok
    // -------------------------------------------------------------------------
    Item {
        id: introOverlay
        anchors.fill: parent
        visible: !root.introDone

        Repeater {
            model: [
                { size: 360, base: 0.5, grow: 1.5, from: 0.3, ms: 350, width: 1 },
                { size: 300, base: 0.8, grow: 1.4, from: 0.4, ms: 300, width: 1 },
                { size: 240, base: 0.8, grow: 1.25, from: 0.6, ms: 250, width: 2 }
            ]
            Rectangle {
                id: ring
                required property var modelData
                required property int index
                anchors.centerIn: parent
                width: modelData.size * root.sc
                height: width
                radius: height / 2
                color: "transparent"
                border.color: index === 0 ? root.cMauve : root.cText
                border.width: Math.max(1, modelData.width * root.sc)
                scale: modelData.base
                opacity: 0.0
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: ring; property: "scale"; from: ring.modelData.base; to: ring.modelData.grow; duration: root.introDur(ring.modelData.ms * 1.6); easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring; property: "opacity"; from: ring.modelData.from; to: 0.0; duration: root.introDur(ring.modelData.ms * 1.6); easing.type: Easing.OutCubic }
                }
            }
        }

        Item {
            id: introOrb
            width: 170 * root.sc
            height: width
            anchors.centerIn: parent
            scale: 0.0
            opacity: 0.0
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.alpha(root.cSurface0, 0.9)
                border.color: root.cText
                border.width: Math.max(1, 2 * root.sc)
            }
            Text {
                id: introIconPower
                anchors.centerIn: parent
                text: "󰐥"
                font.family: root.iconFont
                font.pixelSize: 64 * root.sc
                color: root.cText
            }
            Text {
                id: introIconUser
                anchors.centerIn: parent
                text: "󰀄"
                font.family: root.iconFont
                font.pixelSize: 64 * root.sc
                color: root.cText
                opacity: 0.0
                scale: 1.6
            }
        }

        SequentialAnimation {
            running: true
            ParallelAnimation {
                NumberAnimation { target: introOrb; property: "scale"; from: 0.0; to: 1.0; duration: root.introDur(420); easing.type: Easing.OutCubic }
                NumberAnimation { target: introOrb; property: "opacity"; from: 0.0; to: 1.0; duration: root.introDur(280); easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: root.introDur(380) }
                    ParallelAnimation {
                        NumberAnimation { target: introIconPower; property: "scale"; from: 1.0; to: 0.5; duration: root.introDur(140); easing.type: Easing.InCubic }
                        NumberAnimation { target: introIconPower; property: "opacity"; from: 1.0; to: 0.0; duration: root.introDur(80) }
                        NumberAnimation { target: introIconUser; property: "scale"; from: 1.6; to: 1.0; duration: root.introDur(260); easing.type: Easing.OutBack }
                        NumberAnimation { target: introIconUser; property: "opacity"; from: 0.0; to: 1.0; duration: root.introDur(140) }
                    }
                }
            }
            PauseAnimation { duration: root.introDur(160) }
            ParallelAnimation {
                NumberAnimation { target: introOrb; property: "scale"; to: 1.8; duration: root.introDur(160); easing.type: Easing.InCubic }
                NumberAnimation { target: introOverlay; property: "opacity"; to: 0.0; duration: root.introDur(160); easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "introState"; from: 0.0; to: 1.0; duration: root.introDur(380); easing.type: Easing.OutCubic }
            }
            PropertyAction { target: root; property: "introDone"; value: true }
        }
    }

    // Na een geslaagde login vervaagt alles naar de basiskleur.
    Rectangle {
        anchors.fill: parent
        color: root.cBase
        opacity: root.leaving ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.dur(450); easing.type: Easing.InOutCubic } }
    }
}
