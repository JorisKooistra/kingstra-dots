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
    // Gekleurde gloed achter de plaat tijdens afspelen.
    property bool halo: true
    // 45 toeren: een single van 7 inch in plaats van een lp van 12 inch.
    // Wisselen gaat als een plaatwissel (oude eraf, nieuwe erop).
    property bool single: false
    property bool shownSingle: false
    readonly property real discScale: shownSingle ? 0.6 : 1
    readonly property string look: finish !== "" ? finish
        : woodDeck ? "wood" : paperDeck ? "paper" : compactDisc ? "neon" : ""
    readonly property color brass: accent
    // Hout: geborsteld metaal met een zweem van het accent, geen gloed.
    readonly property color metal: Qt.tint(mocha.subtext1, Qt.rgba(accent.r, accent.g, accent.b, 0.22))
    readonly property color armTubeColor: look === "wood" ? metal
        : look === "neon" ? accent : look === "paper" ? mocha.text : mocha.overlay2
    // Armvoet: buitenring, binnenring en accent (lagerkap).
    readonly property color baseOuter: look === "wood" ? mocha.mantle : look === "neon" ? mocha.crust
        : look === "paper" ? mocha.base : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.96)
    readonly property color baseInner: look === "wood" ? mocha.surface1 : look === "neon" ? Qt.tint(mocha.mantle, Qt.rgba(accent.r, accent.g, accent.b, 0.08))
        : look === "paper" ? mocha.base : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.92)
    readonly property color baseAccent: look === "wood" ? metal : look === "paper" ? mocha.text : accent
    readonly property color armShellColor: look === "wood" ? mocha.surface0
        : look === "neon" ? mocha.crust : mocha.base
    readonly property color platterRim: look === "wood" ? Qt.darker(metal, 1.25)
        : look === "neon" ? accent : look === "paper" ? mocha.text
        : (playing ? accent : mocha.overlay0)
    // Rubbermat in een eigen tint, zodat een single er niet in verdwijnt.
    readonly property color matColor: look === "wood" ? Qt.darker(Qt.tint(mocha.surface1, Qt.rgba(accent.r, accent.g, accent.b, 0.22)), 1.35)
        : look === "neon" ? Qt.tint(mocha.mantle, Qt.rgba(accent.r, accent.g, accent.b, 0.14))
        : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.92)
    readonly property color grooveColor: look === "neon" ? accent : mocha.overlay2
    readonly property color discColor: look === "neon" ? Qt.darker(mocha.crust, 1.6)
        : look === "wood" ? Qt.darker(mocha.crust, 1.4) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.98)
    // Graden per seconde tijdens afspelen (gestileerd, niet echt 33 tpm).
    property real spinSpeed: 45
    property real angularVelocity: 0
    property real discAngle: 0
    // Op het ritme van het scherm (FrameAnimation), niet op een losse timer:
    // die liep niet gelijk met de frames en gaf een schokkerige draai.
    FrameAnimation {
        running: deck.visible && deck.vinyl > 0.01 && (deck.playing || deck.angularVelocity > 0.05)
        onTriggered: {
            let dt = Math.min(0.1, Math.max(0, frameTime));
            let target = deck.playing ? deck.spinSpeed : 0;
            deck.angularVelocity += (target - deck.angularVelocity) * (1 - Math.exp(-dt / 0.5));
            if (!deck.playing && deck.angularVelocity < 0.05) deck.angularVelocity = 0;
            // Wikkelen op 3600: de stroboscoopring draait op 0,6x mee en zou
            // bij 360 elke omwenteling een sprong maken.
            deck.discAngle = (deck.discAngle + deck.angularVelocity * dt) % 3600;
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
    // Grootte van headshell en element t.o.v. de buis; groter oogt minder plat.
    property real headScale: 1.3
    // Begin- en eindhoek volgen uit de geometrie: de naald moet de buitenste
    // groef en de rand van het label raken, waar de voet ook staat.
    readonly property real armStart: solveArmAngle(discRadius * 0.93)
    readonly property real armSpan: Math.max(8, solveArmAngle(labelRadius * 1.12) - armStart)
    readonly property real armRest: armStart - 14
    readonly property real discRadius: (width * 0.85 - 2 * width * 0.06) / 2 * discScale
    readonly property real labelFrac: compactDisc ? 0.24 : shownSingle ? 0.5 : 0.38
    readonly property real labelRadius: discRadius * labelFrac
    function solveArmAngle(r) {
        let u = width / 220;
        // Naald t.o.v. het draaipunt bij hoek 0 (headshell 28° gedraaid).
        let vx = -7 * u - 5.87 * u * headScale;
        let vy = 66 * u * armReach + 11.04 * u * headScale;
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
    // Zet de Behavior op de armhoek uit. Los van armHeld, zodat hij bij het
    // loslaten al aan staat voordat de hoek naar de nummerstand springt;
    // anders wint soms de hoekbinding en staat de naald meteen op de plaat.
    property bool armSnap: false
    property real heldAngle: armRest
    // 0 = naald op de plaat, 1 = arm opgetild.
    property real armLift: 0
    property real cueTarget: 0
    readonly property bool busy: cueAnim.running || swapAnim.running
    readonly property bool cueing: cueAnim.running

    function holdArm() {
        if (armHeld) return;
        heldAngle = armRotation.angle;
        armSnap = true;
        armHeld = true;
    }
    function releaseArm() {
        armSnap = false;
        armHeld = false;
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
        ScriptAction { script: deck.releaseArm() }
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
                deck.releaseArm();
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
    Component.onCompleted: { shownKey = trackKey; shownArt = artUrl; shownSingle = single; }
    onTrackKeyChanged: maybeSwap()
    // Spelers sturen de nieuwe hoes vaak net vóór het nieuwe album. Even
    // wachten, zodat een wissel de oude plaat afhaalt in plaats van eerst de
    // nieuwe hoes op de oude plaat te tonen.
    onArtUrlChanged: {
        if (shownArt === "") shownArt = artUrl;
        else artSettle.restart();
    }
    Timer {
        id: artSettle
        interval: 600
        onTriggered: if (!swapAnim.running && deck.trackKey === deck.shownKey) deck.shownArt = deck.artUrl
    }
    onSingleChanged: maybeSwap()
    function maybeSwap() {
        if ((trackKey === shownKey && single === shownSingle) || swapAnim.running) return;
        if (single !== shownSingle && trackKey === shownKey && (vinyl < 0.5 || !visible)) {
            shownSingle = single;
            return;
        }
        if (trackKey !== shownKey && (shownKey === "" || trackKey === "" || vinyl < 0.5 || !visible)) {
            shownKey = trackKey;
            shownArt = artUrl;
            shownSingle = single;
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
                deck.shownSingle = deck.single;
                deck.discAngle = Math.random() * 360;
                deck.discShift = -1;
            }
        }
        NumberAnimation { target: deck; property: "discShift"; to: 0; duration: ThemeConfig.duration(480); easing.type: Easing.OutCubic }
        NumberAnimation { target: deck; property: "discLift"; to: 0; duration: ThemeConfig.duration(240); easing.type: Easing.InOutQuad }
        NumberAnimation { target: deck; property: "armLift"; to: 1; duration: ThemeConfig.duration(160); easing.type: Easing.OutCubic }
        // Loslaten terwijl hij omhoog is: de Behavior op de armhoek zwenkt
        // hem naar de stand van het nieuwe nummer (die nu pas bekend is).
        ScriptAction { script: deck.releaseArm() }
        PauseAnimation { duration: ThemeConfig.duration(560) }
        NumberAnimation { target: deck; property: "armLift"; to: 0; duration: ThemeConfig.duration(260); easing.type: Easing.InOutQuad }
        ScriptAction {
            script: {
                if (deck.trackKey === deck.shownKey) deck.shownArt = deck.artUrl;
                deck.maybeSwap();
            }
        }
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
        visible: deck.halo
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
            color: deck.look === "wood" ? Qt.darker(deck.mocha.surface0, 1.2) : deck.look === "neon" ? deck.mocha.crust : deck.mocha.surface0
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
                        : deck.look === "wood" ? Qt.rgba(deck.mocha.crust.r, deck.mocha.crust.g, deck.mocha.crust.b, index % 2 ? 0.85 : 0.35)
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
            scale: deck.discScale
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
            scale: (1 + 0.05 * deck.discLift) * deck.discScale
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
                width: parent.width * deck.labelFrac
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
                // Gat in het midden; bij een single groot, met de adapter erin.
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(5, parent.width * (deck.shownSingle ? 0.3 : 0.20))
                    height: width
                    radius: width / 2
                    color: deck.shownSingle ? deck.metal : Qt.rgba(deck.mocha.base.r, deck.mocha.base.g, deck.mocha.base.b, 0.96)
                    border.width: 1
                    border.color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.22)
                }
            }

            rotation: deck.discAngle
        }

            // Zachte glans op de lak. Buiten de draaiende plaat: het licht
            // staat stil, de plaat draait eronder door.
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
            Rectangle {
                width: parent.width * 0.10
                height: parent.height * 0.5
                radius: width / 2
                x: parent.width * 0.68
                y: parent.height * 0.42
                rotation: -28
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
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

            // Armvoet als een ronde sokkel: slagschaduw op het hout en een
            // zijkant, zodat hij boven de plint uitsteekt.
            Rectangle {
                readonly property real d: 31 * tonearm.u * tonearm.bs
                width: d * 1.04
                height: width
                radius: width / 2
                x: tonearm.pivotX - d / 2 + d * 0.06
                y: tonearm.pivotY - d / 2 + d * 0.09
                color: Qt.rgba(0, 0, 0, deck.look === "paper" ? 0 : 0.35)
            }
            Rectangle {
                readonly property real d: 31 * tonearm.u * tonearm.bs
                width: d
                height: width
                radius: width / 2
                x: tonearm.pivotX - d / 2
                y: tonearm.pivotY - d / 2 + d * 0.05
                color: deck.look === "paper" ? deck.mocha.text : Qt.darker(deck.baseOuter, 1.9)
            }
            Rectangle {
                width: 31 * tonearm.u * tonearm.bs
                height: width
                radius: width / 2
                x: tonearm.pivotX - width / 2
                y: tonearm.pivotY - height / 2
                color: deck.baseOuter
                // Licht van linksboven, zodat de voet boven de plint uitsteekt.
                gradient: Gradient {
                    GradientStop { position: 0.0; color: deck.look === "paper" ? deck.baseOuter : Qt.lighter(deck.baseOuter, 1.6) }
                    GradientStop { position: 0.5; color: deck.baseOuter }
                    GradientStop { position: 1.0; color: deck.look === "paper" ? deck.baseOuter : Qt.darker(deck.baseOuter, 1.5) }
                }
                border.width: deck.look === "paper" ? 1.5 : 1
                border.color: deck.look === "" ? Qt.rgba(deck.mocha.overlay2.r, deck.mocha.overlay2.g, deck.mocha.overlay2.b, 0.68) : deck.baseAccent
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: width
                    radius: width / 2
                    color: deck.baseInner
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: deck.look === "paper" ? deck.baseInner : Qt.darker(deck.baseInner, 1.3) }
                        GradientStop { position: 1.0; color: deck.look === "paper" ? deck.baseInner : Qt.lighter(deck.baseInner, 1.3) }
                    }
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
                height: hubY + (88 + 66 * (reach - 1)) * u
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
                            enabled: !deck.armSnap
                            NumberAnimation { duration: ThemeConfig.duration(520); easing.type: Easing.OutCubic }
                        }
                    }
                ]

                // Schaduw van de arm: één keer getekend en daarna alleen
                // verschoven. Opnieuw tekenen met vervaging bij elke stap van
                // het optillen maakte spoelen traag.
                Canvas {
                    id: armShadow
                    readonly property real pad: 10 * arm.u
                    x: -pad
                    y: -pad
                    width: arm.width + 2 * pad
                    height: arm.height + 2 * pad
                    opacity: 0.30 - 0.12 * deck.armLift
                    transform: Translate {
                        x: (2 + 7 * deck.armLift) * arm.u
                        y: (2 + 7 * deck.armLift) * arm.u * 1.3
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();
                        let u = arm.u;
                        ctx.translate(pad, pad);
                        let cx = arm.width / 2;
                        let hub = arm.hubY;
                        let end = { x: cx - 7 * u, y: hub + 66 * u * arm.reach };
                        ctx.lineCap = "round";
                        ctx.shadowColor = "black";
                        ctx.shadowBlur = 4 * u;
                        armCanvas.tubePath(ctx, u, cx, hub, end);
                        ctx.lineWidth = Math.max(1.6, 3.6 * u) * 1.1;
                        ctx.strokeStyle = "black";
                        ctx.stroke();
                        armCanvas.headshell(ctx, u, end, "black", null);
                    }
                }

                Canvas {
                    id: armCanvas
                    anchors.fill: parent
                    antialiasing: true
                    readonly property color tube: deck.armTubeColor
                    readonly property color shine: deck.mocha.text
                    readonly property color shell: deck.armShellColor
                    readonly property color edge: deck.look === "wood" ? deck.metal
                        : deck.look === "neon" ? deck.accent : deck.mocha.overlay1
                    readonly property bool glow: deck.look === "neon"
                    readonly property color tip: deck.accent
                    onTubeChanged: requestPaint()
                    onEdgeChanged: requestPaint()
                    onGlowChanged: requestPaint()
                    onShellChanged: requestPaint()
                    onTipChanged: requestPaint()
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
                        ctx.scale(deck.headScale, deck.headScale);
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

                        // Contragewicht achter het draaipunt: een cilinder met
                        // licht van linksboven en twee groeven.
                        let cwx = cx - 5.5 * u * bs, cwy = hub - (4 + 8 * bs) * u;
                        let cww = 11 * u * bs, cwh = 8 * u * bs;
                        let cwg = ctx.createLinearGradient(cwx, 0, cwx + cww, 0);
                        cwg.addColorStop(0.0, Qt.darker(edge, 1.5));
                        cwg.addColorStop(0.3, Qt.lighter(edge, 1.25));
                        cwg.addColorStop(0.55, edge);
                        cwg.addColorStop(1.0, Qt.darker(edge, 1.9));
                        ctx.fillStyle = cwg;
                        ctx.beginPath();
                        ctx.roundedRect(cwx, cwy, cww, cwh, 2.5 * u * bs, 2.5 * u * bs);
                        ctx.fill();
                        ctx.lineWidth = Math.max(0.6, 0.5 * u);
                        ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.35);
                        for (let g = 1; g <= 2; g++) {
                            ctx.beginPath();
                            ctx.moveTo(cwx + 1, cwy + cwh * g / 3);
                            ctx.lineTo(cwx + cww - 1, cwy + cwh * g / 3);
                            ctx.stroke();
                        }

                        // Buis als cilinder: donkere rand, de buis zelf, een
                        // heldere glans links en een zachte terugkaatsing rechts.
                        if (glow) {
                            ctx.save();
                            ctx.shadowColor = Qt.rgba(tube.r, tube.g, tube.b, 0.9);
                            ctx.shadowBlur = 10 * u;
                        } else {
                            tubePath(ctx, u, cx, hub, end);
                            ctx.lineWidth = tw * 1.35;
                            ctx.strokeStyle = Qt.darker(tube, 2.2);
                            ctx.stroke();
                        }
                        tubePath(ctx, u, cx, hub, end);
                        ctx.lineWidth = glow ? Math.max(1.2, tw * 0.7) : tw;
                        ctx.strokeStyle = tube;
                        ctx.stroke();
                        if (glow) ctx.restore();
                        if (!glow) {
                            tubePath(ctx, u, cx + tw * 0.22, hub, { x: end.x + tw * 0.22, y: end.y });
                            ctx.lineWidth = Math.max(0.6, tw * 0.3);
                            ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.22);
                            ctx.stroke();
                        }
                        tubePath(ctx, u, cx - tw * 0.2, hub, { x: end.x - tw * 0.2, y: end.y });
                        ctx.lineWidth = Math.max(0.6, tw * 0.26);
                        ctx.strokeStyle = Qt.rgba(shine.r, shine.g, shine.b, glow ? 0.35 : 0.7);
                        ctx.stroke();

                        // Headshell met vingerlift en naald; licht van linksboven.
                        let hg = ctx.createLinearGradient(end.x - 6 * u, end.y - 2 * u, end.x + 8 * u, end.y + 14 * u);
                        hg.addColorStop(0.0, Qt.lighter(shell, 1.9));
                        hg.addColorStop(0.45, shell);
                        hg.addColorStop(1.0, Qt.darker(shell, 1.6));
                        // Dikte van de headshell: dezelfde vorm iets lager, donker.
                        ctx.save();
                        ctx.translate(1.1 * u, 1.7 * u);
                        headshell(ctx, u, end, Qt.darker(shell, 2.6), null);
                        ctx.restore();
                        headshell(ctx, u, end, hg, Qt.rgba(edge.r, edge.g, edge.b, 0.9));

                        ctx.save();
                        ctx.translate(end.x, end.y);
                        ctx.rotate(28 * Math.PI / 180);
                        ctx.scale(deck.headScale, deck.headScale);
                        // Vingerlift met schaduw.
                        ctx.beginPath();
                        ctx.moveTo(5 * u, 4.2 * u);
                        ctx.lineTo(10.5 * u, 2.7 * u);
                        ctx.lineWidth = Math.max(1, 1.4 * u);
                        ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.45);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.moveTo(5 * u, 3 * u);
                        ctx.lineTo(10 * u, 1.5 * u);
                        ctx.strokeStyle = Qt.lighter(edge, 1.2);
                        ctx.stroke();

                        // Element onder de headshell: blokje met zijkant,
                        // belichte bovenkant en een glanslijn.
                        let cw = 7 * u, ch = 7.5 * u, cy0 = 3.5 * u;
                        ctx.fillStyle = Qt.darker(tip, 2.4);
                        ctx.beginPath();
                        ctx.roundedRect(-cw / 2 + 0.9 * u, cy0 + 1.5 * u, cw, ch, 1.2 * u, 1.2 * u);
                        ctx.fill();
                        let cg = ctx.createLinearGradient(-cw / 2, cy0, cw / 2, cy0 + ch);
                        cg.addColorStop(0.0, Qt.lighter(tip, 1.35));
                        cg.addColorStop(0.5, tip);
                        cg.addColorStop(1.0, Qt.darker(tip, 1.5));
                        ctx.fillStyle = cg;
                        ctx.beginPath();
                        ctx.roundedRect(-cw / 2, cy0, cw, ch, 1.2 * u, 1.2 * u);
                        ctx.fill();
                        ctx.beginPath();
                        ctx.moveTo(-cw / 2 + 1.2 * u, cy0 + 0.6 * u);
                        ctx.lineTo(cw / 2 - 1.2 * u, cy0 + 0.6 * u);
                        ctx.lineWidth = Math.max(0.6, 0.6 * u);
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55);
                        ctx.stroke();
                        // Naaldhouder en naald.
                        ctx.beginPath();
                        ctx.moveTo(-1.2 * u, cy0 + ch);
                        ctx.lineTo(1.2 * u, cy0 + ch);
                        ctx.lineTo(0, cy0 + ch + 2.6 * u);
                        ctx.closePath();
                        ctx.fillStyle = Qt.lighter(edge, 1.3);
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

            // Kleine pivot bovenop de arm: een kapje met zijkant en glans.
            Rectangle {
                readonly property real d: 18 * tonearm.u * tonearm.bs
                width: d
                height: width
                radius: width / 2
                x: tonearm.pivotX - d / 2 + d * 0.05
                y: tonearm.pivotY - d / 2 + d * 0.12
                color: Qt.rgba(0, 0, 0, deck.look === "paper" ? 0 : 0.4)
            }
            Rectangle {
                width: 18 * tonearm.u * tonearm.bs
                height: width
                radius: width / 2
                x: tonearm.pivotX - width / 2
                y: tonearm.pivotY - height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: deck.look === "paper" ? deck.mocha.base : Qt.lighter(deck.look === "" ? deck.mocha.surface0 : deck.baseOuter, 1.9) }
                    GradientStop { position: 1.0; color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.look === "" ? deck.mocha.surface0 : deck.baseOuter, 1.3) }
                }
                border.width: 1
                border.color: Qt.rgba(deck.baseAccent.r, deck.baseAccent.g, deck.baseAccent.b, 0.72)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width / 3
                    height: width
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(deck.baseAccent, 1.3) }
                        GradientStop { position: 1.0; color: Qt.darker(deck.baseAccent, 1.4) }
                    }
                }
                // Glanspuntje linksboven.
                Rectangle {
                    visible: deck.look !== "paper"
                    x: parent.width * 0.2
                    y: parent.height * 0.14
                    width: parent.width * 0.22
                    height: width * 0.6
                    radius: height / 2
                    rotation: -35
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }
    }
}
