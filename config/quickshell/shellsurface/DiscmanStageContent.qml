import QtQuick
import QtQuick.Layouts
import ".."

// Schermvullende discman, zoals de draaitafel: de speler ligt achterover met
// het deksel en de lcd naar boven, de voorrand met de knoppen kijkt naar je.
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
    frontRatio: 0.11
    widthShare: 0.46
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

    frontData: [
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.max(stage.cornerX * 0.8, stage.rigWidth * 0.04)
            anchors.rightMargin: Math.max(stage.cornerX * 0.8, stage.rigWidth * 0.04)
            anchors.topMargin: stage.frontHeight * 0.14
            anchors.bottomMargin: stage.frontHeight * 0.22
            spacing: stage.rigWidth * 0.02

            // Koptelefoonaansluiting.
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: stage.frontHeight * 0.12
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

            Item { Layout.fillWidth: true; Layout.fillHeight: true }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: stage.rigWidth * 0.01
                DeckKey {
                    id: prevKey
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰒮"
                    frontFacing: true
                    lean: -0.3
                    viewLean: stage.viewLean
                    lit: seeker.windDir < 0
                    keyWidth: stage.frontHeight * 0.8
                    keyHeight: stage.frontHeight * 0.56
                    property bool held: false
                    onDownChanged: if (down) { held = false; prevHold.restart(); } else { prevHold.stop(); if (held) seeker.stopWind(); }
                    onActivated: if (!held && stage.canPrevious) stage.previous()
                    Timer { id: prevHold; interval: 380; onTriggered: { prevKey.held = true; seeker.startWind(-1); } }
                }
                DeckKey {
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    // Eén icoon; blijft ingedrukt zolang er muziek speelt.
                    icon: "󰐎"
                    latched: stage.playing
                    lit: stage.playing
                    frontFacing: true
                    lean: 0
                    viewLean: stage.viewLean
                    keyWidth: stage.frontHeight * 1.05
                    keyHeight: stage.frontHeight * 0.56
                    onActivated: stage.togglePlay()
                }
                DeckKey {
                    id: nextKey
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰒭"
                    frontFacing: true
                    lean: 0.3
                    viewLean: stage.viewLean
                    lit: seeker.windDir > 0
                    keyWidth: stage.frontHeight * 0.8
                    keyHeight: stage.frontHeight * 0.56
                    property bool held: false
                    onDownChanged: if (down) { held = false; nextHold.restart(); } else { nextHold.stop(); if (held) seeker.stopWind(); }
                    onActivated: if (!held && stage.canNext) stage.next()
                    Timer { id: nextHold; interval: 380; onTriggered: { nextKey.held = true; seeker.startWind(1); } }
                }
                Item { width: stage.rigWidth * 0.012; height: 1 }
                DeckKey {
                    mocha: stage.mocha
                    accent: stage.accent
                    skin: stage.skin
                    icon: "󰓛"
                    frontFacing: true
                    lean: 0.5
                    viewLean: stage.viewLean
                    keyWidth: stage.frontHeight * 0.62
                    keyHeight: stage.frontHeight * 0.56
                    onActivated: stage.closeRequested()
                }
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: stage.frontHeight * 0.12
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
                    height: stage.frontHeight * 0.52
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
