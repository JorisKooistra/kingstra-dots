import QtQuick
import QtQuick.Effects
import ".."

// Draaitafel voor de lopende track, overgenomen uit de oude muziekpopup.
// De plaat draait alleen tijdens afspelen, het hoesje zit als label in het
// midden en de toonarm schuift met de voortgang van de buitenste groef naar
// binnen. Met vinyl uit toont hij gewoon de hoes met afgeronde hoeken; de
// wissel tussen beide is een vloeiende overgang, geen sprong.
Item {
    id: deck

    required property var mocha
    property string artUrl: ""
    property bool playing: false
    // 0..1; alleen gebruikt voor de stand van de toonarm.
    property real progress: 0
    // Er is een track met lengte: de arm ligt op de plaat. Anders rust hij.
    property bool tracking: false
    property bool vinylMode: true
    property bool showArm: true
    property color accent: mocha.accent3
    property real coverRadius: 14
    property string playerStyle: "theme"
    readonly property bool paperDeck: playerStyle === "theme" && ThemeConfig.theme === "paper"
    readonly property bool woodDeck: playerStyle === "theme" && ThemeConfig.theme === "organic"
    readonly property bool compactDisc: playerStyle === "theme" && ThemeConfig.theme === "neon"
    property real angularVelocity: 0
    property real discAngle: 0
    property real lastTick: Date.now()
    Timer {
        interval: 16
        repeat: true
        running: deck.visible && deck.vinyl > 0.01 && (deck.playing || deck.angularVelocity > 0.05)
        onRunningChanged: deck.lastTick = Date.now()
        onTriggered: {
            let now = Date.now(), dt = Math.min(0.1, Math.max(0, (now - deck.lastTick) / 1000));
            deck.lastTick = now;
            let target = deck.playing ? 45 : 0;
            deck.angularVelocity += (target - deck.angularVelocity) * (1 - Math.exp(-dt / 0.5));
            if (!deck.playing && deck.angularVelocity < 0.05) deck.angularVelocity = 0;
            deck.discAngle = (deck.discAngle + deck.angularVelocity * dt) % 360;
        }
    }

    readonly property bool hasArt: art.status === Image.Ready
    // 0 = hoes, 1 = plaat. Hierop hangen alle overgangen.
    property real vinyl: vinylMode ? 1 : 0
    Behavior on vinyl {
        NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") }
    }

    implicitWidth: 132
    implicitHeight: 132

    // Rustige terugvering bij pauzeren, zoals in de popup.
    scale: playing ? 1.0 : 0.985
    Behavior on scale {
        NumberAnimation { duration: ThemeConfig.duration(500); easing.type: Easing.OutCubic }
    }

    Image {
        id: art
        source: deck.artUrl
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 256
        sourceSize.height: 256
        visible: false
    }

    // Gloed achter de plaat; licht op tijdens afspelen.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 14
        height: width
        radius: deck.vinyl > 0.5 ? width / 2 : deck.coverRadius + 6
        color: deck.accent
        opacity: deck.playing ? 0.30 : 0.0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
    }

    // --- Hoes (vinyl uit) ---------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: 1 - deck.vinyl
        visible: opacity > 0.01
        scale: 0.9 + 0.1 * (1 - deck.vinyl)

        Rectangle {
            id: coverMask
            anchors.fill: parent
            radius: deck.coverRadius
            visible: false
            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent
            radius: deck.coverRadius
            color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.10)
        }
        MultiEffect {
            anchors.fill: parent
            source: art
            maskEnabled: true
            maskSource: coverMask
            opacity: deck.hasArt ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
        }
        Text {
            anchors.centerIn: parent
            visible: !deck.hasArt
            text: "󰎆"
            font.family: ThemeConfig.iconFont
            font.pixelSize: Math.round(deck.width * 0.32)
            color: deck.accent
        }
    }

    // The plinth stays still while platter, grooves and label rotate.
    Rectangle {
        anchors.fill: parent
        radius: deck.paperDeck ? 5 : 12
        visible: deck.vinyl > 0.01
        opacity: deck.vinyl
        color: deck.woodDeck ? Qt.tint(deck.mocha.surface0, Qt.alpha(deck.mocha.peach, 0.18)) : deck.mocha.surface0
        border.color: deck.paperDeck ? deck.mocha.text : deck.mocha.overlay1
        border.width: deck.paperDeck ? 1 : 2
        Repeater {
            model: deck.woodDeck ? 8 : 0
            Rectangle {
                required property int index
                x: 5
                y: 5 + index * (parent.height - 10) / 8
                width: parent.width - 10
                height: 1
                color: Qt.alpha(deck.mocha.peach, index % 2 ? 0.10 : 0.06)
            }
        }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 3; height: 3; radius: 1.5
                x: index % 2 ? parent.width - 7 : 4
                y: index < 2 ? 4 : parent.height - 7
                color: deck.mocha.overlay2
            }
        }
    }

    // --- Plaat (vinyl aan) ----------------------------------------------------
    Item {
        id: record
        anchors.fill: parent
        anchors.margins: deck.width * 0.075
        opacity: deck.vinyl
        visible: opacity > 0.01
        scale: 0.9 + 0.1 * deck.vinyl

        // Vaste plint; alleen de plaat en het label draaien.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: deck.mocha.surface0
            border.width: Math.max(2, Math.round(deck.width * 0.022))
            border.color: deck.playing ? deck.accent : deck.mocha.overlay0
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: deck.width * 0.035
            radius: width / 2
            color: Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b, 0.50)
        }

        Item {
            id: disc
            anchors.fill: parent
            anchors.margins: deck.width * 0.06

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(deck.mocha.surface1.r, deck.mocha.surface1.g, deck.mocha.surface1.b, 0.98)
                border.width: 1
                border.color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.12)
            }

            // Fijne groeven, zodat de plaat ook zonder hoes echt oogt.
            Repeater {
                model: deck.compactDisc ? 3 : Math.max(3, Math.round(deck.width / 16))
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: Math.max(disc.width * 0.40, disc.width - 6 - index * (disc.width * 0.07))
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b,
                        index % 2 === 0 ? 0.20 : 0.11)
                }
            }

            // Label met de hoes.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (deck.compactDisc ? 0.24 : 0.38)
                height: width
                radius: width / 2
                color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.42)
                border.width: 1
                border.color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.30)

                Rectangle {
                    id: labelMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: art
                    maskEnabled: true
                    maskSource: labelMask
                    opacity: deck.hasArt ? 0.86 : 0
                    Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !deck.hasArt && deck.width >= 90
                    text: deck.compactDisc ? "CD" : "KANT A"
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: 7
                    font.weight: Font.Bold
                    color: deck.mocha.text
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(5, parent.width * 0.20)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, 0.96)
                    border.width: 1
                    border.color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.22)
                }
            }

            // Zachte glans op de lak.
            Rectangle {
                width: parent.width * 0.16
                height: parent.height * 0.72
                radius: width / 2
                x: parent.width * 0.20
                y: parent.height * 0.10
                rotation: -28
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.11) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            rotation: deck.discAngle
        }

        // Toonarm: draait niet mee met de plaat. Pivot → arm → element.
        Item {
            id: tonearm
            visible: deck.showArm && !deck.compactDisc
            readonly property real u: deck.width / 220
            width: 94 * u
            height: 96 * u
            x: parent.width - width - 4 * u
            y: 5 * u
            readonly property real trackingAngle: deck.tracking
                ? 4 + Math.max(0, Math.min(1, deck.progress)) * 31
                : -7

            Rectangle {
                width: 31 * tonearm.u
                height: width
                radius: width / 2
                x: parent.width - width
                y: -2 * tonearm.u
                color: Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b, 0.68)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: width
                    radius: width / 2
                    color: Qt.rgba(deck.mocha.surface1.r, deck.mocha.surface1.g, deck.mocha.surface1.b, 0.92)
                    border.width: 1
                    border.color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.34)
                }
            }

            Rectangle {
                id: arm
                width: Math.max(2, 4 * tonearm.u)
                height: 73 * tonearm.u
                radius: width / 2
                x: parent.width - 16 * tonearm.u
                y: 15 * tonearm.u
                transformOrigin: Item.Top
                rotation: tonearm.trackingAngle
                Behavior on rotation { NumberAnimation { duration: ThemeConfig.duration(520); easing.type: Easing.OutCubic } }
                color: deck.mocha.overlay2

                Rectangle {
                    width: 13 * tonearm.u
                    height: 17 * tonearm.u
                    radius: 5 * tonearm.u
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -10 * tonearm.u
                    color: Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, 0.96)
                    border.width: 1
                    border.color: Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b, 0.72)
                }
                Rectangle {
                    width: 13 * tonearm.u
                    height: 7 * tonearm.u
                    radius: 2 * tonearm.u
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -2 * tonearm.u
                    color: deck.mocha.surface2
                    border.width: 1
                    border.color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.56)
                }
            }

            // Kleine pivot bovenop de arm.
            Rectangle {
                width: 18 * tonearm.u
                height: width
                radius: width / 2
                x: parent.width - width - 5 * tonearm.u
                y: 4 * tonearm.u
                color: deck.mocha.surface0
                border.width: 1
                border.color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.72)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width / 3
                    height: width
                    radius: width / 2
                    color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.92)
                }
            }
        }
    }
}
