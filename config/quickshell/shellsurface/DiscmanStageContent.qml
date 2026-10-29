import QtQuick
import ".."

// Schermvullende discman, rond zoals de klassieke Sony: de speler ligt op
// tafel, iets rechtop naar je toe gekanteld, met het deksel en de lcd
// bovenop; op de gebogen voorrand zitten de ronde knoppen.
// Play/pauze blijft ingedrukt tijdens afspelen; ⏮ en ⏭ gaan naar het
// vorige/volgende nummer en zoeken als je ze vasthoudt. Slepen over de balk
// op de lcd spoelt. Volume zit in het wieltje rechts.
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
    readonly property alias deck: disc
    signal seek(real fraction)
    signal volumeRequested(real value)

    skin: disc.skin
    look: disc.look
    topAspect: 1.0
    frontRatio: 0.09
    widthShare: look === "wood" ? 0.3 : 0.42
    phonesScale: 1.3
    maxTilt: 24
    bodyRadius: disc.bodyRadius
    hint: "Spatie afspelen  ·  ⏮ ⏭ vorige/volgende, vasthouden zoekt  ·  sleep over de balk op het scherm  ·  ← → spoelen  ·  Esc sluit"
    onNudge: seconds => seeker.nudge(seconds)

    SeekControl {
        id: seeker
        progress: stage.progress
        length: stage.length
        canSeek: stage.canSeek && stage.tracking
        onSeek: fraction => stage.seek(fraction)
    }

    // Nummer op de lcd: telt mee als het album hetzelfde blijft.
    property int trackNumber: 1
    property string lastTitle: ""
    onTitleChanged: {
        if (lastTitle !== "" && title !== "" && title !== lastTitle) trackNumber = trackNumber % 99 + 1;
        lastTitle = title;
    }
    onTrackKeyChanged: trackNumber = 1

    topData: [
        DiscDeck {
            id: disc
            anchors.fill: parent
            mocha: stage.mocha
            accent: stage.accent
            title: stage.title
            artist: stage.artist
            artUrl: stage.artUrl
            playing: stage.playing
            tracking: stage.tracking
            position: stage.tracking ? seeker.shown : 0
            length: stage.length
            trackNumber: stage.trackNumber
            detail: stage.detailT
            marquee: stage.settled
            searching: seeker.windDir !== 0
            seekable: seeker.canSeek
            viewLean: stage.viewLean
            onTogglePlay: stage.togglePlay()
            onScrubPressed: fraction => seeker.begin(fraction)
            onScrubMoved: fraction => seeker.move(fraction)
            onScrubReleased: fraction => seeker.commit(fraction)
        }
    ]

    // Knoppen en opschrift op de gebogen voorrand: x als deel van de
    // breedte. Ze staan op de cilinder van de kast: de hoogte volgt de
    // bovenrand van de band, ze kantelen mee met de helling en worden naar
    // de zijkant smaller, zoals op een echte ronde rand.
    function bandX(f) { return frontWidth * f; }
    function bandY(f, h) { return rimY(frontWidth * f) + (frontHeight - h) / 2; }
    function bandSin(f) { return Math.max(-0.95, Math.min(0.95, 2 * f - 1)); }
    function bandScale(f) { return Math.sqrt(1 - bandSin(f) * bandSin(f)); }
    function bandAngle(f) {
        let x = frontWidth * f, e = Math.max(1, frontWidth * 0.01);
        return Math.atan2(rimY(x + e) - rimY(x - e), 2 * e) * 180 / Math.PI;
    }
    readonly property real keySize: frontHeight * 0.6

    component OnBand: Item {
        id: slot
        property real f: 0.5
        readonly property Item first: children.length > 0 ? children[0] : null
        width: first ? first.width : 0
        height: first ? first.height : 0
        x: stage.bandX(f) - width / 2
        y: stage.bandY(f, height)
        transform: [
            Scale { origin.x: slot.width / 2; origin.y: slot.height / 2; xScale: stage.bandScale(slot.f) },
            Rotation { origin.x: slot.width / 2; origin.y: slot.height / 2; angle: stage.bandAngle(slot.f) }
        ]
    }

    frontData: [
        Item {
            anchors.fill: parent

            // Koptelefoonaansluiting met opschrift.
            OnBand {
                f: 0.27
                Row {
                    spacing: stage.frontHeight * 0.1
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: stage.frontHeight * 0.34
                        height: width
                        radius: width / 2
                        color: stage.look === "paper" ? stage.mocha.base : stage.skin.metal
                        border.width: stage.look === "paper" ? 1.5 : 1
                        border.color: stage.look === "paper" ? stage.mocha.text : Qt.rgba(0, 0, 0, 0.5)
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.5
                            height: width
                            radius: width / 2
                            color: stage.look === "paper" ? stage.mocha.text : Qt.rgba(0, 0, 0, 0.85)
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: stage.detailT
                        text: "PHONES"
                        font.family: ThemeConfig.monoFont
                        font.pixelSize: Math.max(8, stage.frontHeight * 0.13)
                        font.letterSpacing: 1
                        color: stage.skin.brandColor
                    }
                }
            }

            OnBand {
                f: 0.41
                DeckKey {
                    id: prevKey
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰒮"
                    round: true
                    frontFacing: true
                    lean: stage.bandSin(0.41)
                    viewLean: stage.viewLean
                    lit: seeker.windDir < 0
                    keyWidth: stage.keySize
                    keyHeight: stage.keySize
                    property bool held: false
                    onDownChanged: if (down) { held = false; prevHold.restart(); } else { prevHold.stop(); if (held) seeker.stopWind(); }
                    onActivated: if (!held && stage.canPrevious) stage.previous()
                    Timer { id: prevHold; interval: 380; onTriggered: { prevKey.held = true; seeker.startWind(-1); } }
                }
            }
            OnBand {
                f: 0.5
                DeckKey {
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    // Eén icoon; blijft ingedrukt zolang er muziek speelt.
                    icon: "󰐎"
                    round: true
                    latched: stage.playing
                    lit: stage.playing
                    frontFacing: true
                    lean: 0
                    viewLean: stage.viewLean
                    keyWidth: stage.keySize * 1.2
                    keyHeight: stage.keySize
                    onActivated: stage.togglePlay()
                }
            }
            OnBand {
                f: 0.59
                DeckKey {
                    id: nextKey
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰒭"
                    round: true
                    frontFacing: true
                    lean: stage.bandSin(0.59)
                    viewLean: stage.viewLean
                    lit: seeker.windDir > 0
                    keyWidth: stage.keySize
                    keyHeight: stage.keySize
                    property bool held: false
                    onDownChanged: if (down) { held = false; nextHold.restart(); } else { nextHold.stop(); if (held) seeker.stopWind(); }
                    onActivated: if (!held && stage.canNext) stage.next()
                    Timer { id: nextHold; interval: 380; onTriggered: { nextKey.held = true; seeker.startWind(1); } }
                }
            }
            OnBand {
                f: 0.675
                DeckKey {
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰓛"
                    round: true
                    frontFacing: true
                    lean: stage.bandSin(0.675)
                    viewLean: stage.viewLean
                    keyWidth: stage.keySize * 0.8
                    keyHeight: stage.keySize * 0.8
                    onActivated: stage.closeRequested()
                }
            }

            // Volumewieltje met opschrift.
            OnBand {
                f: 0.78
                Row {
                    spacing: stage.frontHeight * 0.1
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: stage.detailT
                        text: "VOL"
                        font.family: ThemeConfig.monoFont
                        font.pixelSize: Math.max(8, stage.frontHeight * 0.13)
                        font.letterSpacing: 1
                        color: stage.skin.brandColor
                    }
                    VolumeWheel {
                        anchors.verticalCenter: parent.verticalCenter
                        width: stage.frontHeight * 0.36
                        height: stage.frontHeight * 0.56
                        skin: stage.skin
                        value: stage.volume
                        flat: stage.look === "paper"
                        viewLean: stage.viewLean
                        onRequested: value => stage.volumeRequested(value)
                    }
                }
            }
        }
    ]
}
