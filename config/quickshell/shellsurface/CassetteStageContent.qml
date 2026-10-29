import QtQuick
import QtQuick.Layouts
import ".."

// Schermvullende cassettespeler (walkman), zoals de draaitafel: de kast ligt
// achterover met het venster en de cassette naar boven, de bovenrand met de
// pianotoetsen kijkt naar je. Play blijft ingedrukt tijdens afspelen; ◀◀ en
// ▶▶ gaan naar het vorige/volgende nummer en spoelen als je ze vasthoudt,
// dan winden de spoelen zichtbaar door. Volume zit in het wieltje rechts.
DeviceStage {
    id: stage

    property string trackKey: ""
    property bool tracking: false
    property bool canSeek: false
    property bool canPrevious: true
    property bool canNext: true
    property real progress: 0
    property real length: 0
    property real volume: -1
    readonly property alias deck: cassette
    signal seek(real fraction)
    signal volumeRequested(real value)

    skin: cassette.skin
    look: cassette.look
    topAspect: 0.72
    frontRatio: 0.13
    bodyRadius: cassette.bodyRadius
    hint: "Spatie afspelen  ·  ◀◀ ▶▶ vorige/volgende, vasthouden spoelt  ·  sleep over de tape  ·  ← → spoelen  ·  Esc sluit"
    onNudge: seconds => seeker.nudge(seconds)

    SeekControl {
        id: seeker
        progress: stage.progress
        length: stage.length
        canSeek: stage.canSeek && stage.tracking
        onSeek: fraction => stage.seek(fraction)
    }

    topData: [
        CassetteDeck {
            id: cassette
            anchors.fill: parent
            mocha: stage.mocha
            accent: stage.accent
            title: stage.title
            artist: stage.artist
            playing: stage.playing
            position: stage.tracking ? seeker.shown : 0
            detail: stage.detailT
            marquee: stage.settled
            viewLean: stage.viewLean
            onTogglePlay: stage.togglePlay()
        }
    ]

    frontData: [
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.max(stage.cornerX * 0.7, stage.rigWidth * 0.035)
            anchors.rightMargin: Math.max(stage.cornerX * 0.7, stage.rigWidth * 0.035)
            anchors.topMargin: stage.frontHeight * 0.16
            anchors.bottomMargin: stage.frontHeight * 0.2
            spacing: stage.rigWidth * 0.02

            // Mechanische teller: speeltijd op losse rolletjes; loopt mee met
            // de tape, dus ook tijdens het winden.
            Rectangle {
                id: counter
                Layout.alignment: Qt.AlignVCenter
                readonly property string digits: stage.tracking ? stage.clock(cassette.tapePos * stage.length) : "-:--"
                readonly property real cell: stage.frontHeight * 0.3
                implicitWidth: counterRow.implicitWidth + cell * 0.5
                implicitHeight: cell * 1.45
                radius: stage.look === "neon" ? 2 : cell * 0.18
                color: stage.skin.counterFrame
                border.width: stage.look === "paper" ? 2 : 1
                border.color: stage.look === "paper" ? stage.mocha.text : Qt.rgba(0, 0, 0, 0.5)
                Row {
                    id: counterRow
                    anchors.centerIn: parent
                    spacing: counter.cell * 0.08
                    Repeater {
                        // Vaste plekken; alleen de tekst verandert.
                        model: counter.digits.length
                        Rectangle {
                            required property int index
                            readonly property string modelData: counter.digits.charAt(index)
                            readonly property bool sep: modelData === ":"
                            width: sep ? counter.cell * 0.35 : counter.cell * 0.78
                            height: counter.cell * 1.15
                            radius: 1
                            color: sep ? "transparent" : stage.skin.counterBg
                            // Rolletje: donker naar boven en onder.
                            Rectangle {
                                anchors.fill: parent
                                visible: !parent.sep && stage.look !== "paper"
                                radius: parent.radius
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.6) }
                                    GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.10) }
                                    GradientStop { position: 0.65; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.family: ThemeConfig.monoFont
                                font.pixelSize: counter.cell * 0.82
                                font.weight: Font.Bold
                                color: parent.sep && stage.look !== "paper" ? stage.skin.counterBg : stage.skin.counterText
                            }
                        }
                    }
                }
            }

            // Tapebalk: slepen windt de tape naar de nieuwe plek.
            Item {
                id: scrub
                Layout.fillWidth: true
                Layout.fillHeight: true
                enabled: seeker.canSeek
                opacity: enabled ? 1 : 0.4
                Rectangle {
                    id: slot
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Math.max(5, stage.frontHeight * 0.14)
                    radius: stage.look === "neon" ? 1 : height / 2
                    color: stage.skin.track
                    border.width: stage.look === "paper" ? 1.5 : 0
                    border.color: stage.mocha.text
                    Rectangle {
                        visible: stage.look !== "paper"
                        width: parent.width
                        height: parent.height * 0.5
                        radius: parent.radius
                        color: Qt.rgba(0, 0, 0, 0.35)
                    }
                    // Tape die al gespeeld is (rechterspoel).
                    Rectangle {
                        width: Math.max(height, parent.width * seeker.shown)
                        height: parent.height
                        radius: parent.radius
                        color: stage.skin.fill
                        opacity: 0.85
                    }
                }
                // Schuifje als uitgetrokken blokje, zelfde 3D als de knoppen.
                Extruded {
                    id: thumb
                    width: stage.frontHeight * 0.2
                    height: stage.frontHeight * 0.34
                    x: seeker.shown * (scrub.width - width)
                    y: (scrub.height - height) / 2 - depth * 0.5
                    radius: stage.look === "neon" ? 1.5 : 3
                    depth: Math.max(2, height * 0.22)
                    frontFacing: true
                    lean: 0.1 + stage.viewLean
                    flat: stage.look === "paper"
                    faceTop: Qt.lighter(stage.skin.capA, 1.08)
                    faceBottom: stage.skin.capB
                    side: stage.skin.capSide
                    borderWidth: 1
                    borderColor: stage.skin.capBorder
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -stage.frontHeight * 0.1
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    function at(mx) { return Math.max(0, Math.min(1, mx / scrub.width)); }
                    onPressed: mouse => seeker.begin(at(mouse.x))
                    onPositionChanged: mouse => { if (pressed) seeker.move(at(mouse.x)); }
                    onReleased: mouse => seeker.commit(at(mouse.x))
                    onCanceled: seeker.cancel()
                }
            }

            // Pianotoetsen.
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: stage.rigWidth * 0.008
                DeckKey {
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰇪"
                    frontFacing: true
                    lean: 0.15
                    viewLean: stage.viewLean
                    keyWidth: stage.frontHeight * 0.62
                    keyHeight: stage.frontHeight * 0.56
                    onActivated: stage.closeRequested()
                }
                DeckKey {
                    id: rewKey
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰑟"
                    frontFacing: true
                    lean: 0.3
                    viewLean: stage.viewLean
                    lit: seeker.windDir < 0
                    keyWidth: stage.frontHeight * 0.8
                    keyHeight: stage.frontHeight * 0.56
                    property bool held: false
                    onDownChanged: if (down) { held = false; rewHold.restart(); } else { rewHold.stop(); if (held) seeker.stopWind(); }
                    onActivated: if (!held && stage.canPrevious) stage.previous()
                    Timer { id: rewHold; interval: 380; onTriggered: { rewKey.held = true; seeker.startWind(-1); } }
                }
                DeckKey {
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    // Eén icoon; blijft ingedrukt zolang er muziek speelt.
                    icon: "󰐊"
                    latched: stage.playing
                    lit: stage.playing
                    frontFacing: true
                    lean: 0.45
                    viewLean: stage.viewLean
                    keyWidth: stage.frontHeight * 1.05
                    keyHeight: stage.frontHeight * 0.56
                    onActivated: stage.togglePlay()
                }
                DeckKey {
                    id: ffKey
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰈑"
                    frontFacing: true
                    lean: 0.6
                    viewLean: stage.viewLean
                    lit: seeker.windDir > 0
                    keyWidth: stage.frontHeight * 0.8
                    keyHeight: stage.frontHeight * 0.56
                    property bool held: false
                    onDownChanged: if (down) { held = false; ffHold.restart(); } else { ffHold.stop(); if (held) seeker.stopWind(); }
                    onActivated: if (!held && stage.canNext) stage.next()
                    Timer { id: ffHold; interval: 380; onTriggered: { ffKey.held = true; seeker.startWind(1); } }
                }
            }

            // Volumewieltje met opschrift.
            Column {
                Layout.alignment: Qt.AlignVCenter
                spacing: stage.frontHeight * 0.04
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: stage.detailT
                    text: "VOL"
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: Math.max(8, stage.frontHeight * 0.12)
                    font.letterSpacing: 1
                    color: stage.skin.brandColor
                }
                VolumeWheel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: stage.frontHeight * 0.36
                    height: stage.frontHeight * 0.48
                    skin: stage.skin
                    value: stage.volume
                    flat: stage.look === "paper"
                    viewLean: stage.viewLean
                    onRequested: value => stage.volumeRequested(value)
                }
            }
        }
    ]
}
