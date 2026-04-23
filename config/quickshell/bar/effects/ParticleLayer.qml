import QtQuick

// ── Wat is dit bestand? ───────────────────────────────────────────────────────
// ParticleLayer tekent bewegende lichtpuntjes over de bar.
// Het type en de hoeveelheid worden bepaald door theme.json:
//
//   particle_type:  "fireflies" | "space-specks" | "space-specks-layered" |
//                   "sparkles" | "rain" | "snow" | "dust" | "none"
//   particle_count: aantal deeltjes (0–50)
//   particle_speed: snelheid (0.1–2.0, standaard 1.0)
//
// BarSurface.qml laadt dit component en geeft `fireflyBoost: 1.25` mee voor
// het Botanical-theme zodat de vuurvliegjes daar iets groter en helderder zijn.
//
// ── Hoe de animaties werken ───────────────────────────────────────────────────
// Elk deeltje is een `Item` in een Repeater. De Repeater maakt `safeCount`
// exemplaren aan. Per deeltje draaien maximaal vier animaties tegelijk:
//
//   glowPulse    — float 0.0–1.0, stuurt de gloedhalo-grootte (alleen fireflies)
//   pathPhase    — float 0–2π, stuurt de x/y-positie via cos/sin (Lissajous-pad)
//   opacity      — fade in/out met willekeurige timing per deeltje
//   y            — lichte zweef-beweging omhoog/omlaag (alleen space-specks)
//
// De `index * 137` / `index % N` trucs zorgen dat elk deeltje op een andere
// startpositie en met een andere timing begint — zonder dat er een Random-aanroep
// nodig is (QML heeft geen Math.random() die stabiel herstart).
//
// ── Muisinteractie (alleen fireflies) ────────────────────────────────────────
// Een MouseArea onderaan volgt de muispositie. Als de muis dichtbij een vuurvliegje
// komt (binnen `scareRadius` pixels), wordt het weggeduwd via `scarePush` en
// licht het kortstondig op. Dit voelt alsof je ze verstoort.
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root
    required property var shell
    required property var mocha
    property real fireflyBoost: 1.0   // >1.0 = grotere/fellere vuurvliegjes (Botanical)
    property real trackY: 0
    property real trackHeight: height
    property bool pointerActive: false
    property real pointerX: -9999
    property real pointerY: -9999

    // ── Ingelezen waarden uit theme.json ─────────────────────────────────────
    // normalizedType: alleen bekende types worden doorgegeven; onbekend → "none"
    readonly property string normalizedType: {
        let t = String(shell.particleType || "none").toLowerCase();
        if (t === "fireflies" || t === "space-specks" || t === "space-specks-layered"
                || t === "sparkles" || t === "rain" || t === "snow" || t === "dust") return t;
        return "none";
    }
    readonly property int  safeCount: Math.max(0, Math.min(50, Number(shell.particleCount || 0)))
    readonly property real safeSpeed: Math.max(0.1, Math.min(2.0, Number(shell.particleSpeed || 1.0)))

    // ── Deeltjes ──────────────────────────────────────────────────────────────
    // model = 0 als type "none" is → Repeater maakt dan niets aan.
    Repeater {
        model: root.normalizedType === "none" ? 0 : root.safeCount

        delegate: Item {
            id: particle

            // Type-vlaggen zodat elke conditie leesbaar blijft
            readonly property bool isFireflies:     root.normalizedType === "fireflies"
            readonly property bool isLayeredSpecks: root.normalizedType === "space-specks-layered"
            readonly property bool isSparkles:      root.normalizedType === "sparkles"
            readonly property bool isRain:          root.normalizedType === "rain"
            readonly property bool isSnow:          root.normalizedType === "snow"
            readonly property bool isDust:          root.normalizedType === "dust"
            readonly property bool largeLayeredSpeck: isLayeredSpecks && (index % 2) === 1
            readonly property bool driftingDown: isRain || isSnow || isDust

            // Grootte: vuurvliegjes zijn groter dan space-specks
            width: isFireflies
                   ? shell.s(root.fireflyBoost > 1.0 ? 5 : 4)
                   : (isRain ? Math.max(1, shell.s(1))
                             : (isSparkles ? shell.s((index % 3) === 0 ? 3 : 2)
                                           : (isSnow ? shell.s((index % 3) === 0 ? 3 : 2)
                                                     : (isDust ? Math.max(1, shell.s(1)) : (largeLayeredSpeck ? 2 : 1)))))
            height: isRain ? shell.s(9 + (index % 4) * 2) : width

            // ── Startpositie ──────────────────────────────────────────────────
            // Deterministisch verspreid over de breedte/hoogte via priemgetallen
            // (137, 97). Geen Random nodig — zelfde resultaat bij elke herstart.
            property real baseX: root.safeCount > 0
                                 ? (((index + 0.5) / root.safeCount) * Math.max(1, root.width)
                                    + (((index * 37) % 23) - 11) * Math.max(1, root.width) / Math.max(36, root.safeCount * 18))
                                 : 0
            property real baseY: isFireflies
                                 ? (root.trackY + ((index * 97) % Math.max(1, root.trackHeight)))
                                 : ((index * 97) % Math.max(1, root.height))

            // ── Animatiestatus ────────────────────────────────────────────────
            property real glowPulse: 0.0   // 0.0 = gedoofd, 1.0 = volop gloeiend
            property real pathPhase: 0.0   // huidige hoek in de vliegbaan (0–2π)

            readonly property real pathOffset: index * 1.37   // unieke fase per deeltje
            readonly property real fallDistance: root.height + shell.s(24 + (index % 5) * 8)

            // Vliegbereik (hoe ver een vuurvliegje van zijn startpunt afdwaalt)
            readonly property real fireflyDriftX: shell.s(root.fireflyBoost > 1.0 ? 18 : 13)
            readonly property real fireflyDriftY: shell.s(root.fireflyBoost > 1.0 ? 12 : 9)

            // ── Berekende positie ─────────────────────────────────────────────
            // Lissajous-achtig pad: cos + kleine secundaire golf voor onregelmatigheid.
            readonly property real naturalX: isFireflies
               ? baseX + Math.cos(pathPhase + pathOffset) * fireflyDriftX
                       + Math.cos(pathPhase * 2 + pathOffset * 0.7) * fireflyDriftX * 0.28
               : (isSnow ? baseX + Math.sin(pathPhase + pathOffset) * shell.s(5) : baseX)
            readonly property real naturalY: isFireflies
               ? baseY + Math.sin(pathPhase + pathOffset) * fireflyDriftY
                       + Math.sin(pathPhase * 2 + pathOffset * 0.7) * fireflyDriftY * 0.24
               : baseY

            // ── Muisvlucht (alleen fireflies) ─────────────────────────────────
            // Afstand van het deeltje tot de muiscursor.
            readonly property real pointerDx: naturalX + width / 2 - root.pointerX
            readonly property real pointerDy: naturalY + height / 2 - root.pointerY
            readonly property real pointerDistance: Math.sqrt(pointerDx * pointerDx + pointerDy * pointerDy)

            // scareRadius: straal waarbinnen het deeltje reageert op de muis.
            readonly property real scareRadius: shell.s(root.fireflyBoost > 1.0 ? 76 : 58)

            // scareStrength: 0.0 (buiten bereik) → 1.0 (direct onder muis)
            readonly property real scareStrength: (isFireflies && root.pointerActive)
                                                  ? Math.max(0.0, 1.0 - pointerDistance / scareRadius)
                                                  : 0.0
            readonly property real scareNorm:  Math.max(1.0, pointerDistance)
            // scarePush: hoe ver het deeltje weggedrukt wordt (kwadraat = snelle afname)
            readonly property real scarePush: scareStrength * scareStrength * shell.s(root.fireflyBoost > 1.0 ? 34 : 26)

            // startledGlow: extra gloed als het deeltje verschrikt is
            readonly property real startledGlow: Math.min(1.25, glowPulse + scareStrength * 0.55)

            // Definitieve positie = natuurlijke positie + vluchtrichting × afstand
            x: isFireflies ? naturalX + (pointerDx / scareNorm) * scarePush : naturalX
            y: isFireflies ? naturalY + (pointerDy / scareNorm) * scarePush : naturalY

            opacity: isFireflies
                ? (root.fireflyBoost > 1.0 ? 0.35 : 0.25) + scareStrength * 0.20
                : (isSparkles ? 0.46 : (isRain ? 0.30 : (isSnow ? 0.38 : (isDust ? 0.18 : (largeLayeredSpeck ? 0.22 : 0.16)))))

            // ── Visuele lagen (fireflies: drie gloedhalo's + kern) ────────────

            // Buitenste halo (groot, zwak blauw)
            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 11.0 : 8.0); height: width; radius: width / 2
                scale: 0.70 + particle.startledGlow * 0.50
                opacity: (root.fireflyBoost > 1.0 ? 0.06 : 0.04) * particle.startledGlow
                color: Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 0.35)
            }

            // Middelste halo (geel-oranje gloed)
            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 7.8 : 5.8); height: width; radius: width / 2
                scale: 0.78 + particle.startledGlow * 0.40
                opacity: (root.fireflyBoost > 1.0 ? 0.22 : 0.16) * particle.startledGlow
                color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.58)
            }

            // Binnenste halo (warm oranje, helderder)
            Rectangle {
                visible: isFireflies
                anchors.centerIn: parent
                width: parent.width * (root.fireflyBoost > 1.0 ? 4.8 : 3.6); height: width; radius: width / 2
                scale: 0.88 + particle.startledGlow * 0.26
                opacity: (root.fireflyBoost > 1.0 ? 0.56 : 0.42) * particle.startledGlow
                color: Qt.rgba(1.0, 0.78, 0.28, 0.82)
            }

            // Kern: het lichtpuntje zelf (wit voor fireflies, blauw voor space-specks)
            Rectangle {
                visible: !isRain
                anchors.fill: parent; radius: width / 2
                scale: isSparkles ? (0.78 + particle.glowPulse * 0.42) : (1.0 + particle.scareStrength * 0.36)
                color: isFireflies
                    ? Qt.rgba(1.0, 0.94, 0.78, 1.0)
                    : (isSparkles
                       ? ((index % 3) === 0 ? mocha.pink : ((index % 3) === 1 ? mocha.mauve : mocha.yellow))
                       : (isSnow
                          ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.82)
                          : (isDust
                             ? Qt.rgba(mocha.subtext0.r, mocha.subtext0.g, mocha.subtext0.b, 0.45)
                             : Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, largeLayeredSpeck ? 0.88 : 0.72))))
            }

            Rectangle {
                visible: isRain
                anchors.fill: parent
                radius: width / 2
                rotation: 8
                color: Qt.rgba(mocha.sapphire.r, mocha.sapphire.g, mocha.sapphire.b, 0.56)
            }

            // ── Animaties ─────────────────────────────────────────────────────

            // Gloed pulseert in/uit (alleen fireflies)
            SequentialAnimation on glowPulse {
                running: particle.isFireflies || particle.isSparkles; loops: Animation.Infinite
                NumberAnimation { to: 1.0;  duration: (1500 + (index % 5) * 180) / root.safeSpeed; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.28; duration: (1800 + (index % 5) * 220) / root.safeSpeed; easing.type: Easing.InOutSine }
            }

            // Vliegbaan: pathPhase loopt van 0 naar 2π in een lus → cos/sin-positie hierboven
            NumberAnimation on pathPhase {
                running: particle.isFireflies || particle.isSnow
                from: 0; to: Math.PI * 2
                duration: (9000 + (index % 6) * 650) / root.safeSpeed
                loops: Animation.Infinite; easing.type: Easing.Linear
            }

            // Fade in/uit — elke deeltje heeft een unieke timing via index % N
            SequentialAnimation on opacity {
                running: root.normalizedType !== "none"; loops: Animation.Infinite
                NumberAnimation {
                    to: isFireflies ? (root.fireflyBoost > 1.0 ? 1.0 : 0.95) : (isSparkles ? 0.78 : (isRain ? 0.38 : (isSnow ? 0.52 : (isDust ? 0.24 : (largeLayeredSpeck ? 0.52 : 0.38)))))
                    duration: (2200 + (index % 7) * 240) / (root.safeSpeed * (largeLayeredSpeck ? 1.2 : 1.0))
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: isFireflies ? (root.fireflyBoost > 1.0 ? 0.35 : 0.25) : (isSparkles ? 0.18 : (isRain ? 0.16 : (isSnow ? 0.22 : (isDust ? 0.08 : (largeLayeredSpeck ? 0.18 : 0.12)))))
                    duration: (2200 + (index % 7) * 260) / (root.safeSpeed * (largeLayeredSpeck ? 1.1 : 0.9))
                    easing.type: Easing.InOutSine
                }
            }

            // Zweef-beweging omhoog/omlaag (alleen space-specks, niet fireflies)
            SequentialAnimation on y {
                running: root.normalizedType !== "none" && !particle.isFireflies && !particle.driftingDown; loops: Animation.Infinite
                NumberAnimation {
                    to: particle.baseY + (largeLayeredSpeck ? shell.s(5) : shell.s(3))
                    duration: (3800 + (index % 5) * 220) / (root.safeSpeed * (largeLayeredSpeck ? 1.15 : 0.75))
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.baseY - (largeLayeredSpeck ? shell.s(4) : shell.s(2))
                    duration: (3600 + (index % 5) * 260) / (root.safeSpeed * (largeLayeredSpeck ? 1.05 : 0.7))
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on y {
                running: particle.driftingDown
                loops: Animation.Infinite
                NumberAnimation {
                    to: particle.baseY + particle.fallDistance
                    duration: (isRain ? 1200 : (isSnow ? 4200 : 6800)) / root.safeSpeed + (index % 6) * 120
                    easing.type: isRain ? Easing.Linear : Easing.InOutSine
                }
                NumberAnimation { to: -shell.s(16 + (index % 5) * 5); duration: 0 }
            }
        }
    }

    // ── Muistracking ─────────────────────────────────────────────────────────
    // propagateComposedEvents: true → klikken gaan gewoon door naar de bar eronder.
    // acceptedButtons: Qt.NoButton → deze MouseArea "slikt" geen klikken op.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.normalizedType === "fireflies"
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onPositionChanged: mouse => {
            root.pointerActive = true;
            root.pointerX = mouse.x;
            root.pointerY = mouse.y;
        }
        onExited: {
            root.pointerActive = false;
            root.pointerX = -9999;
            root.pointerY = -9999;
        }
    }
}
