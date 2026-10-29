import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".."

// Schermvullende draaitafel, als een rustige screensaver. De bovenkant staat
// in perspectief (voor/bovenaanzicht) met de plaat en de gebogen arm; de
// voorkant kijkt recht naar je en draagt een display, de spoelbalk en echte
// knoppen. Spoelen tilt de naald op, zwenkt hem en laat hem weer zakken.
//
// Alleen QtQuick: het venster eromheen staat in VinylStage.qml.
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
    // Plek van de kleine speler op het bureaublad (in schermpixels). Is die
    // bekend, dan groeit de grote speler daaruit: plat en klein op die plek,
    // kantelt achterover en vouwt de voorkant uit. Anders vervaagt hij in beeld.
    property rect originRect: Qt.rect(0, 0, 0, 0)
    readonly property bool fromOrigin: originRect.width > 0
    function lerp(a, b, t) { return a + (b - a) * t; }

    signal togglePlay()
    signal previous()
    signal next()
    signal seek(real fraction)
    signal closeRequested()

    // Uitvoering per thema: Organic walnoot met messing, Neon zwart glas met
    // lichtlijnen, Paper inkt op papier, de rest geborsteld en neutraal.
    property string look: {
        let f = ThemeConfig.styleFamily;
        return f === "organic" ? "wood" : f === "neon" ? "neon" : f === "paper" ? "paper" : "mono";
    }
    readonly property var skin: table.skin
    readonly property var vinyl: table.vinyl

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
        color: stage.look === "paper"
            ? Qt.rgba(stage.mocha.base.r * 0.9, stage.mocha.base.g * 0.9, stage.mocha.base.b * 0.9, 0.96)
            : Qt.rgba(stage.mocha.base.r * 0.5, stage.mocha.base.g * 0.5, stage.mocha.base.b * 0.5, 0.94)
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
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, stage.look === "paper" ? 0.06 : 0.35) }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, stage.look === "paper" ? 0.12 : 0.55) }
        }
    }
    // Klik naast de speler sluit.
    MouseArea {
        anchors.fill: parent
        onClicked: stage.closeRequested()
    }

    // --- De speler -----------------------------------------------------------
    readonly property real rigWidth: Math.min(width * 0.58, height * 0.9)
    readonly property real topDepth: rigWidth * 0.78
    readonly property real frontHeight: rigWidth * 0.12
    readonly property real tilt: fromOrigin ? 38 * reveal : 8 + 30 * reveal
    readonly property real finalX: (width - rigWidth) / 2
    readonly property real finalY: (height - topDepth - frontHeight) / 2 - height * 0.09

    Item {
        id: rig
        width: stage.rigWidth
        height: stage.topDepth + stage.frontHeight
        x: stage.fromOrigin ? stage.lerp(stage.originRect.x, stage.finalX, stage.reveal) : stage.finalX
        y: stage.fromOrigin ? stage.lerp(stage.originRect.y, stage.finalY, stage.reveal)
                            : stage.finalY + (1 - stage.reveal) * 60
        transformOrigin: stage.fromOrigin ? Item.TopLeft : Item.Center
        opacity: stage.fromOrigin ? 1 : stage.reveal
        scale: stage.fromOrigin
            ? stage.lerp(stage.originRect.width / stage.rigWidth, 1, stage.reveal)
            : 0.9 + 0.1 * stage.reveal
        transform: Rotation {
            origin.x: rig.width / 2
            origin.y: rig.height
            axis { x: 0; y: 1; z: 0 }
            angle: stage.sway
        }

        // Neon: lichtrand rond de hele kast.
        Rectangle {
            visible: stage.look === "neon"
            opacity: stage.reveal
            anchors.fill: parent
            anchors.margins: -6
            radius: stage.skin.radius + 6
            color: "transparent"
            border.width: 4
            border.color: Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, stage.playing ? 0.55 : 0.3)
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(600) } }
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
        }
        // Paper: harde inktschaduw, zoals een getekende speler.
        Rectangle {
            visible: stage.look === "paper"
            opacity: stage.reveal
            x: 10
            y: stage.topDepth + 10
            width: parent.width
            height: stage.frontHeight
            radius: stage.skin.radius
            color: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.85)
        }

        // Zachte schaduw onder de kast.
        Rectangle {
            visible: stage.look !== "paper"
            opacity: stage.reveal
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

            TurntableDeck {
                id: table
                anchors.fill: parent
                mocha: stage.mocha
                accent: stage.accent
                look: stage.look
                artUrl: stage.artUrl
                trackKey: stage.trackKey
                playing: stage.playing
                tracking: stage.tracking
                progress: stage.progress
                canSeek: stage.canSeek
                onTogglePlay: stage.togglePlay()
                onSeek: fraction => stage.seek(fraction)
            }
        }

        // Voorkant: recht naar de kijker, onder de voorrand van de bovenplaat.
        Item {
            id: front
            y: stage.topDepth
            width: parent.width
            height: stage.frontHeight
            // Vouwt uit onder de bovenplaat als de speler uit de kleine groeit.
            opacity: stage.fromOrigin ? Math.min(1, stage.reveal * 1.6) : 1
            transform: Rotation {
                origin.x: front.width / 2
                origin.y: 0
                axis { x: 1; y: 0; z: 0 }
                angle: stage.fromOrigin ? (1 - stage.reveal) * 88 : 0
            }

            Rectangle {
                anchors.fill: parent
                radius: stage.skin.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: stage.skin.frontA }
                    GradientStop { position: 1.0; color: stage.skin.frontB }
                }
                border.width: stage.look === "paper" ? 2 : 1
                border.color: stage.look === "paper" ? stage.mocha.text
                    : stage.look === "neon" ? Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.6)
                    : Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.10)
            }
            // Bovenrand recht, zodat hij naadloos op de bovenplaat aansluit.
            Rectangle {
                width: parent.width
                height: parent.height / 2
                color: stage.skin.frontA
                border.width: stage.look === "paper" ? 2 : 0
                border.color: stage.mocha.text
                Rectangle {
                    width: parent.width
                    height: stage.look === "wood" ? 3 : stage.look === "neon" ? 2 : 1
                    color: stage.skin.frontEdge
                }
            }
            // Neon: scanlijnen over de voorkant.
            Repeater {
                model: stage.look === "neon" ? Math.floor(front.height / 4) : 0
                Rectangle {
                    required property int index
                    x: 2
                    width: front.width - 4
                    y: 3 + index * 4
                    height: 1
                    color: Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.035)
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
                    radius: stage.look === "neon" ? 3 : 8
                    color: stage.skin.dispBg
                    border.width: 1
                    border.color: stage.skin.dispBorder
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
                            color: stage.skin.dispText
                        }
                        Text {
                            width: parent.width
                            text: stage.tracking
                                ? stage.clock(vinyl.shownProgress * stage.length) + " / " + stage.clock(stage.length)
                                : (stage.artist !== "" ? stage.artist : "--:--")
                            elide: Text.ElideRight
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: Math.max(9, stage.frontHeight * 0.16)
                            color: stage.skin.dispText
                            opacity: 0.72
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
                        color: stage.skin.track
                        Rectangle {
                            width: Math.max(height, parent.width * scrub.shown)
                            height: parent.height
                            radius: height / 2
                            color: stage.skin.fill
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
                            color: stage.skin.needle
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
                        skin: stage.skin
                        icon: "󰒮"
                        enabled: stage.canPrevious
                        keyWidth: stage.frontHeight * 0.78
                        keyHeight: stage.frontHeight * 0.56
                        onActivated: stage.previous()
                    }
                    DeckKey {
                        mocha: stage.mocha
                        accent: stage.accent
                        skin: stage.skin
                        icon: stage.playing ? "󰏤" : "󰐊"
                        lit: stage.playing
                        keyWidth: stage.frontHeight * 1.0
                        keyHeight: stage.frontHeight * 0.56
                        onActivated: stage.togglePlay()
                    }
                    DeckKey {
                        mocha: stage.mocha
                        accent: stage.accent
                        skin: stage.skin
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
                        skin: stage.skin
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
        y: stage.finalY + rig.height + stage.height * 0.04
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
        color: stage.skin.hint
    }
}
