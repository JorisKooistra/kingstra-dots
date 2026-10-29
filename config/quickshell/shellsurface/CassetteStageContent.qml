import QtQuick
import ".."

// Schermvullende cassettespeler, staand zoals een moderne walkman (FiiO
// CP13): het front met het venster kijkt naar je, bovenop staan de ronde
// knoppen en uit de rechterzijkant steekt het volumewieltje. Play blijft
// ingedrukt tijdens afspelen; ◀◀ en ▶▶ gaan naar het vorige/volgende nummer
// en spoelen als je ze vasthoudt, dan winden de spoelen zichtbaar door.
// Slepen over het venster spoelt ook.
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
    upright: true
    faceAspect: 0.71
    widthShare: 0.4
    bodyRadius: cassette.bodyRadius
    hint: "Spatie afspelen  ·  ◀◀ ▶▶ vorige/volgende, vasthouden spoelt  ·  sleep over het venster  ·  ← → spoelen  ·  Esc sluit"
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
            tracking: stage.tracking
            length: stage.length
            position: stage.tracking ? seeker.shown : 0
            detail: stage.detailT
            marquee: stage.settled
            seekable: seeker.canSeek
            onTogglePlay: stage.togglePlay()
            onScrubPressed: fraction => seeker.begin(fraction)
            onScrubMoved: fraction => seeker.move(fraction)
            onScrubReleased: fraction => seeker.commit(fraction)
        }
    ]

    // Op de bovenkant: midden van de diepte. Alles hier komt in beeld als
    // de kast is uitgevouwen.
    readonly property real keyR: rigWidth * 0.056
    readonly property real keyK: 0.46
    readonly property real keyH: rigWidth * 0.034
    readonly property real shellIn: clamp01((extrudeT - 0.55) / 0.45)
    function topX(f) { return rigWidth * f + offX * 0.5; }
    readonly property real topY: -offY * 0.5

    shellData: [
        Item {
            opacity: stage.shellIn
            visible: opacity > 0.01

            Repeater {
                model: [
                    { f: 0.17, icon: "󰇪", kind: "eject" },
                    { f: 0.37, icon: "󰑟", kind: "rew" },
                    { f: 0.57, icon: "󰐊", kind: "play" },
                    { f: 0.77, icon: "󰈑", kind: "ff" }
                ]
                CylinderKey {
                    id: key
                    required property var modelData
                    readonly property bool isPlay: modelData.kind === "play"
                    readonly property int wind: modelData.kind === "rew" ? -1 : modelData.kind === "ff" ? 1 : 0
                    r: stage.keyR * (isPlay ? 1.12 : 1)
                    k: stage.keyK
                    h: stage.keyH
                    x: stage.topX(modelData.f) - r
                    y: stage.topY - baseY
                    icon: modelData.icon
                    flat: stage.skin.flat === true
                    latched: isPlay && stage.playing
                    lit: isPlay ? stage.playing : wind !== 0 && seeker.windDir === wind
                    capA: isPlay ? stage.skin.playA : stage.skin.keyA
                    capB: isPlay ? stage.skin.playB : stage.skin.keyB
                    side: isPlay ? stage.skin.playSide : stage.skin.keySide
                    border: stage.skin.border
                    iconColor: isPlay ? stage.skin.playIcon : stage.skin.keyIcon
                    litColor: isPlay && stage.look !== "neon" ? stage.skin.playIcon : stage.skin.lit
                    viewLean: stage.viewLean + (modelData.f - 0.5) * 0.5
                    // Klik = vorige/volgende, vasthouden = spoelen.
                    property bool held: false
                    onDownChanged: {
                        if (wind === 0) return;
                        if (down) { held = false; holdTimer.restart(); }
                        else { holdTimer.stop(); if (held) seeker.stopWind(); }
                    }
                    onActivated: {
                        if (isPlay) stage.togglePlay();
                        else if (modelData.kind === "eject") stage.closeRequested();
                        else if (!held && wind < 0 && stage.canPrevious) stage.previous();
                        else if (!held && wind > 0 && stage.canNext) stage.next();
                    }
                    Timer { id: holdTimer; interval: 380; onTriggered: { key.held = true; seeker.startWind(key.wind); } }
                }
            }

            // Koptelefoonaansluiting bovenop, rechts.
            Item {
                readonly property real rr: stage.rigWidth * 0.022
                x: stage.topX(0.92) - rr
                y: stage.topY - rr * stage.keyK
                width: 2 * rr
                height: 2 * rr
                transform: Scale { yScale: stage.keyK }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: stage.skin.metal
                    border.width: stage.look === "paper" ? 2 / stage.keyK : 1
                    border.color: stage.look === "paper" ? stage.mocha.text : Qt.rgba(0, 0, 0, 0.45)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: width
                        radius: width / 2
                        color: stage.look === "paper" ? stage.mocha.text : Qt.rgba(0, 0, 0, 0.85)
                    }
                }
            }

            // Volumewieltje dat uit de rechterzijkant steekt.
            VolumeWheel {
                width: stage.rigWidth * 0.042
                height: stage.rigWidth * 0.17
                x: stage.rigWidth + stage.offX * 0.5 - width * 0.3
                y: stage.topDepth * 0.2 - stage.offY * 0.5
                skin: stage.skin
                value: stage.volume
                flat: stage.look === "paper"
                viewLean: stage.viewLean
                onRequested: value => stage.volumeRequested(value)
            }
            Text {
                x: stage.rigWidth + stage.offX * 0.5 - width / 2
                y: stage.topDepth * 0.2 - stage.offY * 0.5 + stage.rigWidth * 0.19
                opacity: stage.detailT
                text: "VOL"
                font.family: ThemeConfig.monoFont
                font.pixelSize: Math.max(8, stage.rigWidth * 0.017)
                font.letterSpacing: 1
                color: stage.skin.print
            }
        }
    ]
}
