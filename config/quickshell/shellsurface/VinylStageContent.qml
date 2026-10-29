import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".."

// Schermvullende draaitafel, als een rustige screensaver. De bovenkant staat
// in perspectief (voor/bovenaanzicht) met de plaat en de gebogen arm; de
// voorkant kijkt recht naar je en draagt een display, de spoelbalk en echte
// knoppen. Spoelen tilt de naald op, zwenkt hem en laat hem weer zakken.
//
// Alleen QtQuick: het venster eromheen staat in desktop/VinylStage.qml.
FocusScope {
    id: stage

    required property var mocha
    property color accent: mocha.primary

    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string trackKey: ""
    property bool playing: false
    property bool tracking: false
    property bool canSeek: false
    property bool canPrevious: true
    property bool canNext: true
    property real progress: 0
    // In seconden, alleen voor het display.
    property real length: 0

    // 0 = dicht, 1 = open; het venster animeert dit.
    property real reveal: 1

    signal togglePlay()
    signal previous()
    signal next()
    signal seek(real fraction)
    signal closeRequested()

    property int rpm: 33
    property real sway: 0
    // Langzaam meedraaiende camera zolang er muziek speelt.
    SequentialAnimation {
        running: stage.playing && stage.reveal > 0.99
        loops: Animation.Infinite
        NumberAnimation { target: stage; property: "sway"; to: 2.4; duration: 9000; easing.type: Easing.InOutSine }
        NumberAnimation { target: stage; property: "sway"; to: -2.4; duration: 18000; easing.type: Easing.InOutSine }
        NumberAnimation { target: stage; property: "sway"; to: 0; duration: 9000; easing.type: Easing.InOutSine }
    }

    function clock(sec) {
        let s = Math.max(0, Math.floor(Number(sec) || 0));
        let m = Math.floor(s / 60);
        let r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    function nudge(seconds) {
        if (!canSeek || length <= 0) return;
        vinyl.cueTo(Math.max(0, Math.min(1, vinyl.shownProgress + seconds / length)));
    }

    focus: true
    Keys.onEscapePressed: event => { stage.closeRequested(); event.accepted = true; }
    Keys.onSpacePressed: event => { stage.togglePlay(); event.accepted = true; }
    Keys.onLeftPressed: event => { stage.nudge(-10); event.accepted = true; }
    Keys.onRightPressed: event => { stage.nudge(10); event.accepted = true; }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_N) { stage.next(); event.accepted = true; }
        else if (event.key === Qt.Key_P) { stage.previous(); event.accepted = true; }
        else if (event.key === Qt.Key_Q) { stage.closeRequested(); event.accepted = true; }
    }

    // --- Achtergrond ---------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(stage.mocha.base.r * 0.5, stage.mocha.base.g * 0.5, stage.mocha.base.b * 0.5, 0.94)
        opacity: stage.reveal
    }
    Image {
        id: backdropArt
        anchors.fill: parent
        source: stage.artUrl
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 512
        sourceSize.height: 512
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: backdropArt
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        saturation: 0.2
        opacity: backdropArt.status === Image.Ready ? 0.32 * stage.reveal : 0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(600) } }
    }
    // Vignet zodat de speler het licht pakt.
    Rectangle {
        anchors.fill: parent
        opacity: stage.reveal
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }
    // Klik naast de speler sluit.
    MouseArea {
        anchors.fill: parent
        onClicked: stage.closeRequested()
    }

    // --- De speler -----------------------------------------------------------
    readonly property real rigWidth: Math.min(width * 0.62, height * 1.12)
    readonly property real topDepth: rigWidth * 0.64
    readonly property real frontHeight: rigWidth * 0.12
    readonly property real tilt: 8 + 30 * reveal

    Item {
        id: rig
        width: stage.rigWidth
        height: stage.topDepth + stage.frontHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -stage.height * 0.09 + (1 - stage.reveal) * 60
        opacity: stage.reveal
        scale: 0.9 + 0.1 * stage.reveal
        transform: Rotation {
            origin.x: rig.width / 2
            origin.y: rig.height
            axis { x: 0; y: 1; z: 0 }
            angle: stage.sway
        }

        // Zachte schaduw onder de kast.
        Rectangle {
            width: parent.width * 1.04
            height: stage.frontHeight * 1.2
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height * 0.35
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.55)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 1.0 }
        }

        // Klikken op de speler zelf sluit niet.
        MouseArea { anchors.fill: parent }

        // Bovenkant, achterover gekanteld rond de voorrand.
        Item {
            id: topFace
            width: parent.width
            height: stage.topDepth
            transform: Rotation {
                origin.x: topFace.width / 2
                origin.y: topFace.height
                axis { x: 1; y: 0; z: 0 }
                angle: stage.tilt
            }

            Rectangle {
                id: plinth
                anchors.fill: parent
                radius: Math.max(14, ThemeConfig.styleWidgetRadius + 6)
                border.width: 1
                border.color: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.16)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(stage.mocha.surface0, 1.18) }
                    GradientStop { position: 1.0; color: stage.mocha.surface0 }
                }

                // Houtnerf bij Organic, fijne lijnen bij de rest.
                Repeater {
                    model: 14
                    Rectangle {
                        required property int index
                        x: 10
                        y: 10 + index * (plinth.height - 20) / 14
                        width: plinth.width - 20
                        height: 1
                        color: ThemeConfig.theme === "organic"
                            ? Qt.rgba(stage.mocha.peach.r, stage.mocha.peach.g, stage.mocha.peach.b, index % 2 ? 0.08 : 0.05)
                            : Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.025)
                    }
                }
                // Schroefjes in de hoeken.
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 6; height: 6; radius: 3
                        x: index % 2 ? plinth.width - 16 : 10
                        y: index < 2 ? 10 : plinth.height - 16
                        color: stage.mocha.overlay1
                    }
                }
            }

            MediaVinyl {
                id: vinyl
                readonly property real side: stage.topDepth * 0.9
                width: side
                height: side
                x: stage.topDepth * 0.05
                y: stage.topDepth * 0.05
                mocha: stage.mocha
                accent: stage.accent
                showPlinth: false
                showArm: true
                vinylMode: true
                playerStyle: "vinyl"
                artUrl: stage.artUrl
                trackKey: stage.trackKey
                playing: stage.playing
                tracking: stage.tracking
                progress: stage.progress
                canSeek: stage.canSeek
                spinSpeed: stage.rpm === 45 ? 64 : 48
                onSeekRequested: fraction => stage.seek(fraction)
            }

            // Rechterkant van de bovenplaat: start/stop, toerental, pitch.
            Item {
                id: deckSide
                x: vinyl.x + vinyl.width + stage.topDepth * 0.04
                y: vinyl.y
                width: topFace.width - x - stage.topDepth * 0.06
                height: vinyl.height

                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    text: "KINGSTRA · DIRECT DRIVE"
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: Math.max(9, stage.rigWidth * 0.014)
                    font.letterSpacing: 2
                    color: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.45)
                }

                // Pitch-schuif (sier, zoals op een echte draaitafel).
                Rectangle {
                    id: pitchTrack
                    anchors.right: parent.right
                    anchors.rightMargin: parent.width * 0.12
                    y: parent.height * 0.22
                    width: Math.max(6, stage.rigWidth * 0.012)
                    height: parent.height * 0.5
                    radius: width / 2
                    color: Qt.rgba(stage.mocha.base.r, stage.mocha.base.g, stage.mocha.base.b, 0.8)
                    border.width: 1
                    border.color: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.12)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height / 2 - height / 2
                        width: parent.width * 3.2
                        height: parent.width * 1.6
                        radius: 3
                        color: stage.mocha.surface2
                        border.width: 1
                        border.color: stage.mocha.overlay1
                    }
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    spacing: stage.rigWidth * 0.014

                    Row {
                        spacing: stage.rigWidth * 0.012
                        Repeater {
                            model: [33, 45]
                            delegate: DeckKey {
                                mocha: stage.mocha
                                accent: stage.accent
                                required property int modelData
                                label: String(modelData)
                                lit: stage.rpm === modelData
                                keyWidth: stage.rigWidth * 0.06
                                keyHeight: stage.rigWidth * 0.032
                                onActivated: stage.rpm = modelData
                            }
                        }
                    }
                    DeckKey {
                        mocha: stage.mocha
                        accent: stage.accent
                        label: "START · STOP"
                        lit: stage.playing
                        keyWidth: stage.rigWidth * 0.17
                        keyHeight: stage.rigWidth * 0.05
                        onActivated: stage.togglePlay()
                    }
                }
            }
        }

        // Voorkant: recht naar de kijker, onder de voorrand van de bovenplaat.
        Item {
            id: front
            y: stage.topDepth
            width: parent.width
            height: stage.frontHeight

            Rectangle {
                anchors.fill: parent
                radius: Math.max(12, ThemeConfig.styleWidgetRadius + 4)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.darker(stage.mocha.surface0, 1.25) }
                    GradientStop { position: 1.0; color: Qt.darker(stage.mocha.surface0, 1.7) }
                }
                border.width: 1
                border.color: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.10)
            }
            // Bovenrand recht, zodat hij naadloos op de bovenplaat aansluit.
            Rectangle {
                width: parent.width
                height: parent.height / 2
                color: Qt.darker(stage.mocha.surface0, 1.25)
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.18)
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: stage.rigWidth * 0.03
                anchors.rightMargin: stage.rigWidth * 0.03
                anchors.topMargin: stage.frontHeight * 0.2
                anchors.bottomMargin: stage.frontHeight * 0.2
                spacing: stage.rigWidth * 0.022

                // Display met titel en tijd.
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: stage.rigWidth * 0.27
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.25)
                    clip: true

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        width: parent.width - 24
                        spacing: 2
                        Text {
                            width: parent.width
                            text: stage.title !== "" ? stage.title : "Geen nummer"
                            elide: Text.ElideRight
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: Math.max(10, stage.frontHeight * 0.2)
                            font.weight: Font.Bold
                            color: stage.accent
                        }
                        Text {
                            width: parent.width
                            text: stage.tracking
                                ? stage.clock(vinyl.shownProgress * stage.length) + " / " + stage.clock(stage.length)
                                : (stage.artist !== "" ? stage.artist : "--:--")
                            elide: Text.ElideRight
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: Math.max(9, stage.frontHeight * 0.16)
                            color: Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.7)
                        }
                    }
                }

                // Spoelbalk met een naaldje: slepen tilt de arm op, loslaten
                // laat hem op de nieuwe plek zakken.
                Item {
                    id: scrub
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    enabled: stage.canSeek && stage.tracking
                    opacity: enabled ? 1 : 0.4
                    property bool dragging: false
                    property real dragFraction: 0
                    readonly property real shown: dragging ? dragFraction : vinyl.shownProgress

                    Rectangle {
                        id: scrubTrack
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: stage.frontHeight * 0.1
                        width: parent.width
                        height: Math.max(4, stage.frontHeight * 0.07)
                        radius: height / 2
                        color: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.12)
                        Rectangle {
                            width: Math.max(height, parent.width * scrub.shown)
                            height: parent.height
                            radius: height / 2
                            color: stage.accent
                        }
                    }
                    // Naaldje boven de balk; gaat omhoog zolang de arm in de lucht is.
                    Item {
                        id: needleMark
                        width: stage.frontHeight * 0.22
                        height: stage.frontHeight * 0.42
                        x: scrub.shown * scrub.width - width / 2
                        y: scrubTrack.y - height + scrubTrack.height / 2 - vinyl.armLift * stage.frontHeight * 0.14
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(2, parent.width * 0.16)
                            height: parent.height * 0.7
                            radius: width / 2
                            color: stage.mocha.overlay2
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: parent.width * 0.62
                            height: parent.height * 0.36
                            radius: width * 0.3
                            color: stage.mocha.surface2
                            border.width: 1
                            border.color: stage.accent
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.bottom
                                width: 3; height: 3; radius: 1.5
                                color: stage.accent
                                opacity: 1 - vinyl.armLift
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -stage.frontHeight * 0.1
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        function fractionAt(mx) { return Math.max(0, Math.min(1, mx / scrub.width)); }
                        onPressed: mouse => {
                            scrub.dragFraction = fractionAt(mouse.x);
                            scrub.dragging = true;
                            vinyl.previewCue(scrub.dragFraction);
                        }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            scrub.dragFraction = fractionAt(mouse.x);
                            vinyl.previewCue(scrub.dragFraction);
                        }
                        onReleased: mouse => {
                            scrub.dragging = false;
                            vinyl.cueTo(fractionAt(mouse.x));
                        }
                        onCanceled: { scrub.dragging = false; vinyl.cancelCue(); }
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: stage.rigWidth * 0.01
                    DeckKey {
                        mocha: stage.mocha
                        accent: stage.accent
                        icon: "󰒮"
                        enabled: stage.canPrevious
                        keyWidth: stage.frontHeight * 0.78
                        keyHeight: stage.frontHeight * 0.56
                        onActivated: stage.previous()
                    }
                    DeckKey {
                        mocha: stage.mocha
                        accent: stage.accent
                        icon: stage.playing ? "󰏤" : "󰐊"
                        lit: stage.playing
                        keyWidth: stage.frontHeight * 1.0
                        keyHeight: stage.frontHeight * 0.56
                        onActivated: stage.togglePlay()
                    }
                    DeckKey {
                        mocha: stage.mocha
                        accent: stage.accent
                        icon: "󰒭"
                        enabled: stage.canNext
                        keyWidth: stage.frontHeight * 0.78
                        keyHeight: stage.frontHeight * 0.56
                        onActivated: stage.next()
                    }
                    Item { width: stage.rigWidth * 0.01; height: 1 }
                    DeckKey {
                        mocha: stage.mocha
                        accent: stage.accent
                        icon: "󰅖"
                        keyWidth: stage.frontHeight * 0.56
                        keyHeight: stage.frontHeight * 0.56
                        onActivated: stage.closeRequested()
                    }
                }
            }
        }
    }

    // --- Titel en hint -------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: rig.y + rig.height + stage.height * 0.04
        spacing: 4
        opacity: stage.reveal
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, stage.width * 0.8)
            horizontalAlignment: Text.AlignHCenter
            text: stage.title
            elide: Text.ElideRight
            font.family: ThemeConfig.displayFont
            font.pixelSize: Math.max(20, stage.height * 0.034)
            font.weight: Font.Black
            color: stage.mocha.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, stage.width * 0.8)
            horizontalAlignment: Text.AlignHCenter
            text: [stage.artist, stage.album].filter(t => t !== "").join("  ·  ")
            visible: text !== ""
            elide: Text.ElideRight
            font.family: ThemeConfig.uiFont
            font.pixelSize: Math.max(13, stage.height * 0.017)
            color: stage.mocha.subtext0
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        opacity: 0.55 * stage.reveal
        text: "Spatie afspelen  ·  ← → spoelen  ·  sleep de naald of de balk  ·  Esc sluit"
        font.family: ThemeConfig.uiFont
        font.pixelSize: 12
        color: stage.mocha.subtext0
    }

    // Knop op de speler: rond, zakt in bij indrukken, licht op als hij aan staat.
    component DeckKey: Item {
        id: key
        // Eigen kleuren: een inline component ziet de ids van dit bestand niet altijd.
        required property var mocha
        required property color accent
        property string label: ""
        property string icon: ""
        property bool lit: false
        property real keyWidth: 40
        property real keyHeight: 26
        signal activated()
        implicitWidth: keyWidth
        implicitHeight: keyHeight + 3
        opacity: enabled ? 1 : 0.4

        // Zijkant van de knop; de kap schuift erover bij indrukken.
        Rectangle {
            y: 3
            width: parent.width
            height: key.keyHeight
            radius: Math.min(height / 2, 10)
            color: Qt.darker(key.mocha.surface1, 1.6)
        }
        Rectangle {
            id: cap
            y: keyMouse.pressed ? 2.5 : 0
            width: parent.width
            height: key.keyHeight
            radius: Math.min(height / 2, 10)
            Behavior on y { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: keyMouse.containsMouse ? Qt.lighter(key.mocha.surface1, 1.25) : Qt.lighter(key.mocha.surface1, 1.1) }
                GradientStop { position: 1.0; color: key.mocha.surface1 }
            }
            border.width: 1
            border.color: key.lit
                ? Qt.rgba(key.accent.r, key.accent.g, key.accent.b, 0.8)
                : Qt.rgba(key.mocha.text.r, key.mocha.text.g, key.mocha.text.b, 0.14)
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }

            Text {
                anchors.centerIn: parent
                text: key.icon !== "" ? key.icon : key.label
                font.family: key.icon !== "" ? ThemeConfig.iconFont : ThemeConfig.monoFont
                font.pixelSize: key.icon !== "" ? Math.max(12, key.keyHeight * 0.48) : Math.max(8, key.keyHeight * 0.34)
                font.weight: Font.Bold
                font.letterSpacing: key.icon !== "" ? 0 : 1
                color: key.lit ? key.accent : key.mocha.text
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            }
            // Ledje.
            Rectangle {
                visible: key.label !== ""
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 4; height: 4; radius: 2
                color: key.lit ? key.accent : Qt.rgba(key.mocha.text.r, key.mocha.text.g, key.mocha.text.b, 0.2)
            }
        }
        MouseArea {
            id: keyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: key.activated()
        }
    }
}
