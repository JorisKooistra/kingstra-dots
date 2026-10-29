import QtQuick
import QtQuick.Effects
import ".."

// Draaitafel voor de lopende track, overgenomen uit de oude muziekpopup.
// De plaat draait alleen tijdens afspelen, het hoesje zit als label in het
// midden en de gebogen toonarm schuift met de voortgang van de buitenste
// groef naar binnen. Met vinyl uit toont hij gewoon de hoes met afgeronde
// hoeken; de wissel tussen beide is een vloeiende overgang, geen sprong.
//
// Spoelen gaat zoals bij een echte speler: de arm gaat omhoog, zwenkt naar
// de nieuwe plek en zakt weer op de plaat (cueTo, of de naald zelf slepen
// als canSeek aan staat). Bij een nieuw album (trackKey) gaat de arm naar
// zijn steun, schuift de oude plaat eraf en de nieuwe erop.
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
    // Album of hoes-URL; verandert dit, dan wisselt de plaat met een animatie.
    property string trackKey: ""
    // Naald slepen om te spoelen; seekRequested krijgt een fractie 0..1.
    property bool canSeek: false
    signal seekRequested(real fraction)
    // Eigen plint uit, voor wie de plaat in een grotere speler zet.
    property bool showPlinth: true
    property string playerStyle: "theme"
    readonly property bool paperDeck: playerStyle === "theme" && ThemeConfig.theme === "paper"
    readonly property bool woodDeck: playerStyle === "theme" && ThemeConfig.theme === "organic"
    readonly property bool compactDisc: playerStyle === "theme" && ThemeConfig.theme === "neon"
    // Afwerking van plaat en arm: "wood" (messing arm, vilt), "neon" (lichtgevende
    // arm, groeven en stroboscoop), "paper" (inkt) of "" (neutraal). Leeg volgt
    // het thema bij playerStyle "theme"; de schermvullende speler zet hem zelf.
    property string finish: ""
    // Stroboscoopstippen op de rand; hout en neon hebben ze altijd.
    property bool strobe: false
    readonly property string look: finish !== "" ? finish
        : woodDeck ? "wood" : paperDeck ? "paper" : compactDisc ? "neon" : ""
    readonly property color brass: "#c9a55f"
    readonly property color armTubeColor: look === "wood" ? brass
        : look === "neon" ? accent : look === "paper" ? mocha.text : mocha.overlay2
    // Armvoet: buitenring, binnenring en accent (lagerkap).
    readonly property color baseOuter: look === "wood" ? "#2b1d14" : look === "neon" ? "#05070c"
        : look === "paper" ? mocha.base : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.96)
    readonly property color baseInner: look === "wood" ? "#6e5330" : look === "neon" ? "#0b1220"
        : look === "paper" ? mocha.base : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.92)
    readonly property color baseAccent: look === "wood" ? brass : look === "paper" ? mocha.text : accent
    readonly property color armShellColor: look === "wood" ? "#2b1d14"
        : look === "neon" ? "#05070c" : mocha.base
    readonly property color platterRim: look === "wood" ? brass
        : look === "neon" ? accent : look === "paper" ? mocha.text
        : (playing ? accent : mocha.overlay0)
    readonly property color matColor: look === "wood" ? "#2a2320"
        : look === "neon" ? "#04060a" : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.92)
    readonly property color grooveColor: look === "neon" ? accent : mocha.overlay2
    readonly property color discColor: look === "neon" ? "#07090f"
        : look === "wood" ? "#151312" : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.98)
    // Graden per seconde tijdens afspelen (gestileerd, niet echt 33 tpm).
    property real spinSpeed: 45
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
            let target = deck.playing ? deck.spinSpeed : 0;
            deck.angularVelocity += (target - deck.angularVelocity) * (1 - Math.exp(-dt / 0.5));
            if (!deck.playing && deck.angularVelocity < 0.05) deck.angularVelocity = 0;
            deck.discAngle = (deck.discAngle + deck.angularVelocity * dt) % 360;
        }
    }

    readonly property bool hasArt: art.status === Image.Ready

    // --- Toonarm: stand, optillen en spoelen -------------------------------
    // Arm-geometrie. Standaard staat de arm op de plaat (rechtsboven); een
    // grotere speler kan de voet verplaatsen (armPivot, in pixels t.o.v. dit
    // item), de arm verlengen (armReach) en de voet groter maken (armBase).
    property point armPivot: Qt.point(-1, -1)
    property real armReach: 1
    property real armBase: 1
    // Begin- en eindhoek volgen uit de geometrie: de naald moet de buitenste
    // groef en de rand van het label raken, waar de voet ook staat.
    readonly property real armStart: solveArmAngle(discRadius * 0.93)
    readonly property real armSpan: Math.max(8, solveArmAngle(labelRadius * 1.12) - armStart)
    readonly property real armRest: armStart - 14
    readonly property real discRadius: (width * 0.85 - 2 * width * 0.06) / 2
    readonly property real labelRadius: discRadius * (compactDisc ? 0.24 : 0.38)
    function solveArmAngle(r) {
        let u = width / 220;
        // Naald t.o.v. het draaipunt bij hoek 0 (headshell 28° gedraaid).
        let vx = -7 * u - 5.87 * u;
        let vy = 66 * u * armReach + 11.04 * u;
        let px = armPivotX, py = armPivotY;
        let c = width / 2;
        function dist(deg) {
            let a = deg * Math.PI / 180;
            let tx = px + vx * Math.cos(a) - vy * Math.sin(a);
            let ty = py + vx * Math.sin(a) + vy * Math.cos(a);
            return Math.sqrt((tx - c) * (tx - c) + (ty - c) * (ty - c));
        }
        let prev = -40;
        for (let deg = -40; deg <= 90; deg += 1) {
            if (dist(deg) <= r) {
                let lo = prev, hi = deg;
                for (let i = 0; i < 12; i++) {
                    let mid = (lo + hi) / 2;
                    if (dist(mid) <= r) hi = mid; else lo = mid;
                }
                return hi;
            }
            prev = deg;
        }
        return 0;
    }
    // Draaipunt in item-coördinaten.
    readonly property real armPivotX: armPivot.x >= 0 ? armPivot.x : width - width * 0.075 - 4 * width / 220 - 14.5 * width / 220
    readonly property real armPivotY: armPivot.y >= 0 ? armPivot.y : width * 0.075 + 5 * width / 220 + 13 * width / 220
    function angleFor(fraction) {
        return armStart + Math.max(0, Math.min(1, fraction)) * armSpan;
    }
    function fractionFor(angle) {
        return Math.max(0, Math.min(1, (angle - armStart) / armSpan));
    }
    // Na een spoelactie houdt de arm de nieuwe plek vast tot de speler zijn
    // positie heeft bijgewerkt, anders springt hij even terug.
    property real seekHold: -1
    readonly property real shownProgress: seekHold >= 0 ? seekHold : progress
    onProgressChanged: if (seekHold >= 0 && Math.abs(progress - seekHold) < 0.02) seekHold = -1
    Timer {
        id: seekHoldTimer
        interval: 2500
        onTriggered: deck.seekHold = -1
    }
    readonly property real naturalAngle: tracking ? angleFor(shownProgress) : armRest
    // armHeld: de arm volgt heldAngle (spoelen, slepen, plaat wisselen).
    property bool armHeld: false
    property real heldAngle: armRest
    // 0 = naald op de plaat, 1 = arm opgetild.
    property real armLift: 0
    property real cueTarget: 0
    readonly property bool busy: cueAnim.running || swapAnim.running

    function holdArm() {
        if (armHeld) return;
        heldAngle = armRotation.angle;
        armHeld = true;
    }
    // Arm optillen en boven de plek van `fraction` houden (voor een
    // spoelbalk die nog wordt gesleept). cueTo laat hem daarna zakken.
    function previewCue(fraction) {
        if (swapAnim.running || !tracking) return;
        cueAnim.stop();
        holdArm();
        if (armLift < 1 && !liftAnim.running) liftAnim.restart();
        heldAngle = angleFor(fraction);
    }
    property int cueSwingMs: 300
    function cueTo(fraction) {
        if (swapAnim.running || !tracking) return;
        cueAnim.stop();
        dropAnim.stop();
        holdArm();
        cueTarget = Math.max(0, Math.min(1, fraction));
        cueSwingMs = 140 + Math.min(460, Math.abs(angleFor(cueTarget) - heldAngle) * 22);
        cueAnim.restart();
    }
    // Losgelaten zonder te spoelen: arm zakt terug op zijn eigen plek.
    function cancelCue() {
        cueAnim.stop();
        liftAnim.stop();
        dropAnim.restart();
    }

    NumberAnimation {
        id: liftAnim
        target: deck; property: "armLift"; to: 1
        duration: ThemeConfig.duration(170); easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: dropAnim
        NumberAnimation { target: deck; property: "armLift"; to: 0; duration: ThemeConfig.duration(240); easing.type: Easing.InOutQuad }
        ScriptAction { script: deck.armHeld = false }
    }
    SequentialAnimation {
        id: cueAnim
        NumberAnimation { target: deck; property: "armLift"; to: 1; duration: ThemeConfig.duration(170); easing.type: Easing.OutCubic }
        NumberAnimation {
            target: deck; property: "heldAngle"
            to: deck.angleFor(deck.cueTarget)
            duration: ThemeConfig.duration(deck.cueSwingMs)
            easing.type: Easing.InOutCubic
        }
        PauseAnimation { duration: ThemeConfig.duration(90) }
        NumberAnimation { target: deck; property: "armLift"; to: 0; duration: ThemeConfig.duration(260); easing.type: Easing.InOutQuad }
        ScriptAction {
            script: {
                deck.seekHold = deck.cueTarget;
                seekHoldTimer.restart();
                deck.seekRequested(deck.cueTarget);
                deck.armHeld = false;
            }
        }
    }

    // --- Plaat wisselen bij een nieuw album ---------------------------------
    property string shownKey: ""
    property string shownArt: ""
    // -1..1: plaat schuift naar rechts weg (1) en komt van links terug (-1).
    property real discShift: 0
    // 0..1: plaat van de draaitafel getild (groter, diepere schaduw).
    property real discLift: 0
    Component.onCompleted: { shownKey = trackKey; shownArt = artUrl; }
    onTrackKeyChanged: maybeSwap()
    onArtUrlChanged: if (!swapAnim.running && trackKey === shownKey) shownArt = artUrl
    function maybeSwap() {
        if (trackKey === shownKey || swapAnim.running) return;
        if (shownKey === "" || trackKey === "" || vinyl < 0.5 || !visible) {
            shownKey = trackKey;
            shownArt = artUrl;
            return;
        }
        cueAnim.stop();
        liftAnim.stop();
        dropAnim.stop();
        swapAnim.restart();
    }
    SequentialAnimation {
        id: swapAnim
        ScriptAction { script: deck.holdArm() }
        NumberAnimation { target: deck; property: "armLift"; to: 1; duration: ThemeConfig.duration(170); easing.type: Easing.OutCubic }
        NumberAnimation { target: deck; property: "heldAngle"; to: deck.armRest; duration: ThemeConfig.duration(420); easing.type: Easing.InOutCubic }
        NumberAnimation { target: deck; property: "armLift"; to: 0; duration: ThemeConfig.duration(200); easing.type: Easing.InOutQuad }
        NumberAnimation { target: deck; property: "discLift"; to: 1; duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic }
        NumberAnimation { target: deck; property: "discShift"; to: 1; duration: ThemeConfig.duration(420); easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                deck.shownKey = deck.trackKey;
                deck.shownArt = deck.artUrl;
                deck.discAngle = Math.random() * 360;
                deck.discShift = -1;
            }
        }
        NumberAnimation { target: deck; property: "discShift"; to: 0; duration: ThemeConfig.duration(480); easing.type: Easing.OutCubic }
        NumberAnimation { target: deck; property: "discLift"; to: 0; duration: ThemeConfig.duration(240); easing.type: Easing.InOutQuad }
        NumberAnimation { target: deck; property: "armLift"; to: 1; duration: ThemeConfig.duration(160); easing.type: Easing.OutCubic }
        // Loslaten terwijl hij omhoog is: de Behavior op de armhoek zwenkt
        // hem naar de stand van het nieuwe nummer (die nu pas bekend is).
        ScriptAction { script: deck.armHeld = false }
        PauseAnimation { duration: ThemeConfig.duration(560) }
        NumberAnimation { target: deck; property: "armLift"; to: 0; duration: ThemeConfig.duration(260); easing.type: Easing.InOutQuad }
        ScriptAction { script: deck.maybeSwap() }
    }
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
        source: deck.shownArt
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
        visible: deck.showPlinth && deck.vinyl > 0.01
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
            color: deck.look === "wood" ? "#3a2c22" : deck.look === "neon" ? "#05070c" : deck.mocha.surface0
            border.width: Math.max(2, Math.round(deck.width * 0.022))
            border.color: deck.platterRim
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
        }
        // Neon: gloed rond de draaischijf.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -deck.width * 0.01
            radius: width / 2
            visible: deck.look === "neon"
            color: "transparent"
            border.width: Math.max(2, deck.width * 0.012)
            border.color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, deck.playing ? 0.55 : 0.25)
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: 0.6 }
        }
        // Stroboscoopstippen op de rand van de draaischijf (hout en neon).
        Item {
            anchors.fill: parent
            visible: (deck.strobe || deck.look === "wood" || deck.look === "neon") && deck.width >= 200
            rotation: deck.discAngle * 0.6
            Repeater {
                model: 72
                Rectangle {
                    required property int index
                    readonly property real a: index / 72 * Math.PI * 2
                    readonly property real rr: parent.width / 2 - deck.width * 0.011
                    width: Math.max(2, deck.width * 0.007)
                    height: width
                    radius: width / 2
                    x: parent.width / 2 + Math.cos(a) * rr - width / 2
                    y: parent.height / 2 + Math.sin(a) * rr - height / 2
                    color: deck.look === "neon"
                        ? Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, index % 2 ? 0.9 : 0.35)
                        : deck.look === "wood" ? Qt.rgba(0.17, 0.11, 0.07, index % 2 ? 0.85 : 0.35)
                        : deck.look === "paper" ? Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, index % 2 ? 0.95 : 0.4)
                        : Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, index % 2 ? 0.8 : 0.3)
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: deck.width * 0.035
            radius: width / 2
            color: deck.matColor
            border.width: 1
            border.color: Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b, 0.50)
        }

        // As in het midden; zichtbaar als de plaat eraf is.
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(4, deck.width * 0.03)
            height: width
            radius: width / 2
            color: deck.mocha.overlay2
            border.width: 1
            border.color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.3)
        }

        // Schaduw van een opgetilde plaat op de mat.
        Rectangle {
            anchors.fill: parent
            anchors.margins: deck.width * 0.06
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.30 * deck.discLift * (1 - Math.abs(deck.discShift)))
            visible: deck.discLift > 0.01
            transform: Translate {
                x: deck.discShift * deck.width * 0.9 + 4 * deck.discLift
                y: 6 * deck.discLift
            }
        }

        // Draagt de wisselbeweging; de plaat zelf draait daarbinnen, zodat
        // hij om zijn eigen as blijft draaien terwijl hij wegschuift.
        Item {
            id: discCarrier
            anchors.fill: parent
            anchors.margins: deck.width * 0.06
            scale: 1 + 0.05 * deck.discLift
            opacity: 1 - Math.min(1, Math.abs(deck.discShift) * 1.15)
            transform: Translate { x: deck.discShift * deck.width * 0.9 }

        Item {
            id: disc
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: deck.discColor
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
                    border.color: deck.look === "neon"
                        ? (index % 3 === 0
                            ? Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.30)
                            : Qt.rgba(deck.mocha.pink.r, deck.mocha.pink.g, deck.mocha.pink.b, 0.10))
                        : Qt.rgba(deck.grooveColor.r, deck.grooveColor.g, deck.grooveColor.b,
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
        }


        // Toonarm: draait niet mee met de plaat. Voet → gebogen arm → element.
        // De arm is getekend (S-bocht met schuin headshell, zoals een echte
        // draaitafel); optillen = iets groter met een verder verschoven schaduw.
        Item {
            id: tonearm
            visible: deck.showArm && !deck.compactDisc
            readonly property real u: deck.width / 220
            readonly property real bs: deck.armBase
            width: 94 * u
            height: 96 * u
            // Plaats zo dat het draaipunt op deck.armPivot valt (record zit
            // met een marge in het deck).
            x: deck.armPivotX - record.x - pivotX
            y: deck.armPivotY - record.y - pivotY
            // Draaipunt van de arm, in tonearm-coördinaten.
            readonly property real pivotX: width - 14.5 * u
            readonly property real pivotY: 13 * u

            Rectangle {
                width: 31 * tonearm.u * tonearm.bs
                height: width
                radius: width / 2
                x: tonearm.pivotX - width / 2
                y: tonearm.pivotY - height / 2
                color: deck.baseOuter
                border.width: deck.look === "paper" ? 1.5 : 1
                border.color: deck.look === "" ? Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b, 0.68) : deck.baseAccent
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: width
                    radius: width / 2
                    color: deck.baseInner
                    border.width: 1
                    border.color: Qt.rgba(deck.baseAccent.r, deck.baseAccent.g, deck.baseAccent.b, 0.4)
                }
            }

            // Armsteun waar de arm rust als hij niet speelt.
            Rectangle {
                width: 9 * tonearm.u
                height: 6 * tonearm.u
                radius: 2 * tonearm.u
                readonly property real d: 44 * tonearm.u * deck.armReach
                x: tonearm.pivotX - Math.sin(deck.armRest * Math.PI / 180) * d - width / 2
                y: tonearm.pivotY + Math.cos(deck.armRest * Math.PI / 180) * d - height / 2
                color: deck.look === "" ? deck.mocha.surface2 : deck.armShellColor
                border.width: 1
                border.color: deck.look === "" ? Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b, 0.6) : deck.baseAccent
            }

            Item {
                id: arm
                readonly property real u: tonearm.u
                // Boven het draaipunt zit het contragewicht.
                readonly property real hubY: (6 + 8 * tonearm.bs) * u
                readonly property real reach: deck.armReach
                width: Math.max(34, 16 * tonearm.bs) * u
                height: hubY + (80 + 66 * (reach - 1)) * u
                x: tonearm.pivotX - width / 2
                y: tonearm.pivotY - hubY
                transform: [
                    Scale {
                        origin.x: arm.width / 2
                        origin.y: arm.hubY
                        xScale: 1 + 0.05 * deck.armLift
                        yScale: 1 + 0.05 * deck.armLift
                    },
                    Rotation {
                        id: armRotation
                        origin.x: arm.width / 2
                        origin.y: arm.hubY
                        angle: deck.armHeld ? deck.heldAngle : deck.naturalAngle
                        Behavior on angle {
                            enabled: !deck.armHeld
                            NumberAnimation { duration: ThemeConfig.duration(520); easing.type: Easing.OutCubic }
                        }
                    }
                ]

                Canvas {
                    id: armCanvas
                    anchors.fill: parent
                    antialiasing: true
                    readonly property color tube: deck.armTubeColor
                    readonly property color shine: deck.mocha.text
                    readonly property color shell: deck.armShellColor
                    readonly property color edge: deck.look === "wood" ? deck.brass
                        : deck.look === "neon" ? deck.accent : deck.mocha.overlay1
                    readonly property bool glow: deck.look === "neon"
                    readonly property color tip: deck.accent
                    readonly property real lift: deck.armLift
                    onTubeChanged: requestPaint()
                    onEdgeChanged: requestPaint()
                    onGlowChanged: requestPaint()
                    onShellChanged: requestPaint()
                    onTipChanged: requestPaint()
                    onLiftChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    function tubePath(ctx, u, cx, hub, end) {
                        ctx.beginPath();
                        ctx.moveTo(cx, hub - 6 * u);
                        ctx.lineTo(cx, hub + 8 * u);
                        ctx.bezierCurveTo(cx, hub + 34 * u * arm.reach,
                                          cx + 4 * u, hub + 50 * u * arm.reach,
                                          end.x, end.y);
                    }
                    function headshell(ctx, u, end, fill, stroke) {
                        ctx.save();
                        ctx.translate(end.x, end.y);
                        ctx.rotate(28 * Math.PI / 180);
                        ctx.beginPath();
                        let w = 10 * u, h = 15 * u, r = 3 * u;
                        ctx.moveTo(-w / 2 + r, -2 * u);
                        ctx.lineTo(w / 2 - r, -2 * u);
                        ctx.quadraticCurveTo(w / 2, -2 * u, w / 2, -2 * u + r);
                        ctx.lineTo(w / 2, h - r);
                        ctx.quadraticCurveTo(w / 2, h, w / 2 - r, h);
                        ctx.lineTo(-w / 2 + r, h);
                        ctx.quadraticCurveTo(-w / 2, h, -w / 2, h - r);
                        ctx.lineTo(-w / 2, -2 * u + r);
                        ctx.quadraticCurveTo(-w / 2, -2 * u, -w / 2 + r, -2 * u);
                        ctx.closePath();
                        ctx.fillStyle = fill;
                        ctx.fill();
                        if (stroke) {
                            ctx.lineWidth = Math.max(1, u * 0.8);
                            ctx.strokeStyle = stroke;
                            ctx.stroke();
                        }
                        ctx.restore();
                    }

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();
                        let u = arm.u;
                        let cx = width / 2;
                        let hub = arm.hubY;
                        let end = { x: cx - 7 * u, y: hub + 66 * u * arm.reach };
                        let bs = tonearm.bs;
                        let tw = Math.max(1.6, 3.6 * u);
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";

                        // Schaduw: verder weg naarmate de arm hoger is.
                        let off = (1.5 + 5 * lift) * u;
                        ctx.save();
                        ctx.translate(off, off * 1.3);
                        ctx.globalAlpha = 0.20 + 0.10 * (1 - lift);
                        tubePath(ctx, u, cx, hub, end);
                        ctx.lineWidth = tw;
                        ctx.strokeStyle = "black";
                        ctx.stroke();
                        headshell(ctx, u, end, "black", null);
                        ctx.restore();

                        // Contragewicht achter het draaipunt.
                        ctx.fillStyle = Qt.rgba(edge.r, edge.g, edge.b, 1);
                        ctx.beginPath();
                        ctx.roundedRect(cx - 5.5 * u * bs, hub - (4 + 8 * bs) * u, 11 * u * bs, 8 * u * bs, 2.5 * u * bs, 2.5 * u * bs);
                        ctx.fill();

                        // Buis met een smalle glans erover; neon gloeit.
                        if (glow) {
                            ctx.save();
                            ctx.shadowColor = Qt.rgba(tube.r, tube.g, tube.b, 0.9);
                            ctx.shadowBlur = 10 * u;
                        }
                        tubePath(ctx, u, cx, hub, end);
                        ctx.lineWidth = glow ? Math.max(1.2, tw * 0.7) : tw;
                        ctx.strokeStyle = tube;
                        ctx.stroke();
                        if (glow) ctx.restore();
                        tubePath(ctx, u, cx - tw * 0.18, hub, { x: end.x - tw * 0.18, y: end.y });
                        ctx.lineWidth = Math.max(0.6, tw * 0.28);
                        ctx.strokeStyle = Qt.rgba(shine.r, shine.g, shine.b, 0.35);
                        ctx.stroke();

                        // Headshell met vingerlift en naald.
                        headshell(ctx, u, end, Qt.rgba(shell.r, shell.g, shell.b, 0.96),
                                  Qt.rgba(edge.r, edge.g, edge.b, 0.9));
                        ctx.save();
                        ctx.translate(end.x, end.y);
                        ctx.rotate(28 * Math.PI / 180);
                        ctx.beginPath();
                        ctx.moveTo(5 * u, 3 * u);
                        ctx.lineTo(10 * u, 1.5 * u);
                        ctx.lineWidth = Math.max(1, 1.4 * u);
                        ctx.strokeStyle = Qt.rgba(edge.r, edge.g, edge.b, 1);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(0, 12.5 * u, Math.max(1, 1.8 * u), 0, Math.PI * 2);
                        ctx.fillStyle = Qt.rgba(tip.r, tip.g, tip.b, 1);
                        ctx.fill();
                        ctx.restore();
                    }
                }

                // De naald vastpakken: arm gaat omhoog, volgt de muis en zakt
                // bij loslaten op de nieuwe plek.
                MouseArea {
                    id: needleDrag
                    enabled: deck.canSeek && deck.tracking && deck.vinyl > 0.5 && !swapAnim.running
                    width: 30 * arm.u
                    height: 30 * arm.u
                    x: arm.width / 2 - 7 * arm.u - width / 2
                    y: arm.hubY + (60 * arm.reach + 6) * arm.u - height / 2
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: enabled ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                    function angleAt(mx, my) {
                        let p = mapToItem(tonearm, mx, my);
                        let dx = p.x - tonearm.pivotX;
                        let dy = p.y - tonearm.pivotY;
                        // Het element zit iets links van de buisas.
                        let a = Math.atan2(-dx, dy) * 180 / Math.PI - 6;
                        return Math.max(deck.armStart, Math.min(deck.armStart + deck.armSpan, a));
                    }
                    onPressed: mouse => {
                        cueAnim.stop();
                        dropAnim.stop();
                        deck.holdArm();
                        liftAnim.restart();
                    }
                    onPositionChanged: mouse => {
                        if (pressed) deck.heldAngle = angleAt(mouse.x, mouse.y);
                    }
                    onReleased: mouse => deck.cueTo(deck.fractionFor(deck.heldAngle))
                    onCanceled: deck.cancelCue()
                }
            }

            // Kleine pivot bovenop de arm.
            Rectangle {
                width: 18 * tonearm.u * tonearm.bs
                height: width
                radius: width / 2
                x: tonearm.pivotX - width / 2
                y: tonearm.pivotY - height / 2
                color: deck.look === "" ? deck.mocha.surface0 : deck.baseOuter
                border.width: 1
                border.color: Qt.rgba(deck.baseAccent.r, deck.baseAccent.g, deck.baseAccent.b, 0.72)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width / 3
                    height: width
                    radius: width / 2
                    color: Qt.rgba(deck.baseAccent.r, deck.baseAccent.g, deck.baseAccent.b, 0.92)
                }
            }
        }
    }
}
