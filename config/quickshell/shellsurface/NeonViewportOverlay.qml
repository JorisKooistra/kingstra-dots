import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Io
import ".."

Item {
    id: root

    required property var mocha
    required property var telemetry
    property int shellBorderWidth: 8
    property int railWidth: 48
    property int stripHeight: 34

    readonly property bool active: String(ThemeConfig.theme || ThemeConfig.styleFamily || "").toLowerCase() === "neon"
    readonly property color cyan: mocha.accent2 || "#4de8f2"
    readonly property color cyanSoft: mocha.accent3 || mocha.accent2 || "#a7f7ff"
    // Derde accent uit matugen. cyan en cyanSoft pakken accent2 en accent3,
    // dus accent1 is de enige die nog een eigen kleur oplevert; een vaste
    // magenta viel buiten het palet.
    readonly property color accentAlt: mocha.accent1 || mocha.pink || "#ff4fd8"
    // De drie meters lopen de matugen-accenten op volgorde af.
    readonly property color meterCpu: accentAlt
    readonly property color meterRam: cyan
    readonly property color meterGpu: cyanSoft
    readonly property color glass: mocha.crust || "#020712"
    readonly property real hudAlpha: 0.88
    readonly property real panelAlpha: 0.24
    // Kleine glyph-canvassen worden op deze factor getekend en teruggeschaald,
    // zodat ze scherp blijven in het 2x-layer van hun paneel.
    readonly property real glyphSupersample: 2.0

    readonly property string uptimeText: telemetry.uptimeText
    readonly property int cpuPercent: telemetry.cpuPercent
    readonly property int ramPercent: telemetry.ramPercent
    readonly property int gpuPercent: telemetry.gpuPercent
    readonly property int diskPercent: telemetry.diskPercent
    readonly property int cpuTemperature: telemetry.cpuTemperature
    readonly property int gpuTemperature: telemetry.gpuTemperature
    readonly property bool gpuAvailable: telemetry.gpuAvailable
    readonly property string gpuName: telemetry.gpuName
    readonly property int fan1Rpm: telemetry.fan1Rpm
    readonly property int fan2Rpm: telemetry.fan2Rpm
    readonly property int fan3Rpm: telemetry.fan3Rpm
    readonly property int fan4Rpm: telemetry.fan4Rpm
    readonly property bool fan1Available: fan1Rpm > 0
    readonly property bool fan2Available: fan2Rpm > 0
    readonly property bool fan3Available: fan3Rpm > 0
    readonly property bool fan4Available: fan4Rpm > 0
    readonly property string gpuDisplay: gpuAvailable ? (gpuPercent + "%") : "n/a"

    anchors.fill: parent
    visible: active
    opacity: active ? 1.0 : 0.0

    // --- Opstartvolgorde ---------------------------------------------------
    // De HUD bouwt zichzelf in drie tellen op: eerst het lijnenwerk, dan de
    // vakken die daarin staan, dan pas de meetwaarden. Elke fase heeft zijn
    // eigen voortgang in plaats van één gedeelde teller, zodat ze elkaar mogen
    // overlappen — een strikt na-elkaar oogt hakkerig.
    property real decoReveal: 0
    property real panelReveal: 0
    property real contentReveal: 0

    // Verschuift de voortgang per item, zodat de vakken niet als blok maar één
    // voor één binnenkomen. Items met een hogere index starten later maar
    // eindigen gelijk, dus de hele fase blijft even lang duren.
    function stagger(progress, index) {
        let start = Math.min(0.55, Math.max(0, index) * 0.11);
        return Math.max(0.0, Math.min(1.0, (progress - start) / (1.0 - start)));
    }

    function startBoot() {
        bootSequence.stop();
        decoReveal = 0;
        panelReveal = 0;
        contentReveal = 0;
        if (active)
            bootSequence.start();
    }

    ParallelAnimation {
        id: bootSequence

        NumberAnimation {
            target: root
            property: "decoReveal"
            to: 1
            duration: ThemeConfig.duration(560)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: ThemeConfig.duration(360) }
            NumberAnimation {
                target: root
                property: "panelReveal"
                to: 1
                duration: ThemeConfig.duration(620)
                easing.type: Easing.OutCubic
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: ThemeConfig.duration(800) }
            NumberAnimation {
                target: root
                property: "contentReveal"
                to: 1
                duration: ThemeConfig.duration(560)
                easing.type: Easing.OutCubic
            }
        }
    }

    onActiveChanged: startBoot()
    Component.onCompleted: startBoot()

    // De HUD is opgebouwd in drie duidelijk gescheiden lagen:
    //
    //   z 0  decoratie  — achtergrondwas, raster, het perspectiefframe en de
    //                     scanlijn: alles wat alleen lijnenwerk is
    //   z 1  vakken     — de HUD-panelen zelf; hun omlijsting is vectorwerk
    //                     (QtQuick.Shapes), dus resolutie-onafhankelijk scherp
    //   z 2  inhoud     — binnen elk vak: cpu%, rpm, teksten en balken
    //
    // De inhoud-laag zit per vak in de component, zodat een paneel zijn eigen
    // omlijsting nooit overtekent. De scanlijn stond eerder ná de panelen en
    // liep er dus overheen; die hoort bij de decoratie.
    Item {
        id: decoLayer
        anchors.fill: parent
        z: 0
        opacity: root.decoReveal

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.018)
        }

        Repeater {
            model: Math.ceil(root.height / 8)
            Rectangle {
                x: root.railWidth
                y: index * 8
                width: root.width - root.railWidth
                height: 1
                color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.012)
                // Het raster loopt van boven naar beneden vol in plaats van in
                // één keer aan te floepen.
                opacity: {
                    let rowPos = root.height > 0 ? (index * 8) / root.height : 0;
                    return Math.max(0, Math.min(1, (root.decoReveal - rowPos * 0.55) * 3.5));
                }
            }
        }

        PerspectiveFrame {
            // Het lijnenwerk zet zich bij het opkomen nog een fractie uit.
            scale: 0.994 + root.decoReveal * 0.006
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: Math.max(root.shellBorderWidth + 20, 28)
            anchors.rightMargin: Math.max(root.shellBorderWidth + 20, 28)
            anchors.bottomMargin: Math.max(root.shellBorderWidth + 20, 28)
            anchors.leftMargin: Math.max(root.shellBorderWidth + 20,
                root.railWidth + root.shellBorderWidth + 6)
            accent: root.cyan
            topBypassWidth: Math.min(root.width * 0.35, 650)
            topBypassTop: Math.max(root.stripHeight + 28, 48)
                - Math.max(root.shellBorderWidth + 20, 28)
            topBypassHeight: 76
            bottomBypassWidth: Math.min(root.width * 0.24, 440)
            bottomBypassTop: root.height - 72 - root.shellBorderWidth - 76
                - Math.max(root.shellBorderWidth + 20, 28)
            bottomBypassHeight: 72
        }

        Rectangle {
            id: scanSweep
            x: -width
            y: topVisor.y + topVisor.height + 18
            width: Math.max(220, root.width * 0.16)
            height: 1
            opacity: 0.42
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.50; color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.95) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            SequentialAnimation on x {
                running: root.active
                loops: Animation.Infinite
                NumberAnimation { to: root.width; duration: ThemeConfig.duration(12500); easing.type: Easing.Linear }
                NumberAnimation { to: -scanSweep.width; duration: 0 }
            }
        }
    }

    Item {
        id: panelLayer
        anchors.fill: parent
        z: 1

        TelemetryPanel {
            revealIndex: 1
            x: root.railWidth + 54
            y: Math.max(root.stripHeight + 104, root.height * 0.17)
            width: Math.min(root.width * 0.17, 304)
            height: 178
            rotation: -0.60
            accent: root.cyan
        }

        VerticalMeter {
            revealIndex: 3
            x: root.railWidth + 72
            y: root.height - height - root.shellBorderWidth - 150
            width: 92
            height: Math.min(root.height * 0.30, 292)
            rotation: -0.45
            label: "ROOT"
            value: root.diskPercent
            display: root.diskPercent + "%"
            accent: root.cyan
        }

        HudFrame {
            id: topVisor
            revealIndex: 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(root.stripHeight + 28, 48)
            width: Math.min(parent.width * 0.35, 650)
            height: 76
            rotation: -0.16
            accent: root.cyan
            label: "STATUS // 01"
            primary: "SYSTEM NOMINAL"
            secondary: "UPTIME " + root.uptimeText + "  //  KERNEL " + root.telemetry.kernelVersion
            primaryPixelSize: 22
        }

        HudFrame {
            revealIndex: 2
            x: root.width - width - root.shellBorderWidth - 60
            y: Math.max(root.stripHeight + 104, root.height * 0.17)
            width: Math.min(root.width * 0.20, 370)
            height: 122
            rotation: 0.60
            accent: root.cyan
            label: "IDENT // HOST"
            primary: root.telemetry.hostName.toUpperCase()
            secondary: root.telemetry.cpuName + "  //  " + root.telemetry.coreCount + " THREADS"
            primaryPixelSize: 21
        }

        Radar {
            revealIndex: 6
            x: root.width - width - root.shellBorderWidth - 72
            y: root.height - height - root.shellBorderWidth - 78
            size: Math.min(root.width * 0.12, 178)
            accent: root.cyan
        }

        FanGridPanel {
            revealIndex: 4
            x: root.width - width - root.shellBorderWidth - 64
            y: Math.max(root.stripHeight + 292, root.height * 0.37)
            width: Math.min(root.width * 0.16, 294)
            height: 224
            rotation: 0.60
            accent: root.cyan
        }

        HudFrame {
            revealIndex: 5
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height - height - root.shellBorderWidth - 76
            width: Math.min(parent.width * 0.24, 440)
            height: 72
            rotation: 0.16
            accent: root.cyan
            label: "DATALINK // " + root.telemetry.linkState
            primary: root.telemetry.interfaceName.toUpperCase()
            secondary: "↓ " + root.telemetry.formatRate(root.telemetry.downloadKiB)
                + "   ↑ " + root.telemetry.formatRate(root.telemetry.uploadKiB)
                + "   //   " + root.telemetry.ipAddress
            primaryPixelSize: 21
        }
    }

    component PerspectiveFrame: Item {
        required property color accent
        property real lineAlpha: 0.94
        property real topBypassWidth: 0
        property real topBypassTop: 0
        property real topBypassHeight: 0
        property real bottomBypassWidth: 0
        property real bottomBypassTop: 0
        property real bottomBypassHeight: 0

        Canvas {
            id: convexOutline
            anchors.fill: parent
            antialiasing: true
            opacity: 1.0
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.lineJoin = "miter";
                ctx.lineCap = "square";
                ctx.lineWidth = 1.6;
                ctx.strokeStyle = Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, parent.lineAlpha);
                ctx.shadowColor = Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.42);
                ctx.shadowBlur = 8;

                let w = width;
                let h = height;
                let m = 14;
                let notch = Math.min(78, w * 0.05);
                let visorDepth = Math.min(34, h * 0.04);
                let bottomOuterDepth = Math.min(10, h * 0.015);
                let bottomIndentDepth = Math.min(18, h * 0.026);
                let curveLift = Math.min(10, h * 0.012);
                let sideBulge = Math.min(10, w * 0.008);
                let bypassPad = Math.min(64, Math.max(42, w * 0.028));
                let bypassSlope = Math.min(42, Math.max(28, w * 0.020));
                let bypassHalf = Math.max(0, parent.bottomBypassWidth / 2 + bypassPad);
                let bypassLeft = w * 0.50 - bypassHalf;
                let bypassRight = w * 0.50 + bypassHalf;
                let bypassTop = parent.bottomBypassTop > 0
                    ? Math.max(h * 0.62, parent.bottomBypassTop - 18)
                    : h - m - bottomIndentDepth;
                let bypassBase = h - m - bottomOuterDepth;
                let topBypassPad = Math.min(72, Math.max(48, w * 0.032));
                let topBypassSlope = Math.min(46, Math.max(30, w * 0.022));
                let topBypassHalf = Math.max(0, parent.topBypassWidth / 2 + topBypassPad);
                let topBypassLeft = w * 0.50 - topBypassHalf;
                let topBypassRight = w * 0.50 + topBypassHalf;
                let topBypassBase = m;
                let topBypassBottom = parent.topBypassTop > 0
                    ? Math.min(h * 0.30,
                        parent.topBypassTop + parent.topBypassHeight + 18)
                    : m + visorDepth;

                ctx.beginPath();
                ctx.moveTo(m + notch, m + 3);
                ctx.quadraticCurveTo(w * 0.18, m - curveLift, topBypassLeft, topBypassBase);
                ctx.lineTo(topBypassLeft + topBypassSlope, topBypassBottom);
                ctx.lineTo(topBypassRight - topBypassSlope, topBypassBottom);
                ctx.lineTo(topBypassRight, topBypassBase);
                ctx.quadraticCurveTo(w * 0.82, m - curveLift,
                    w - m - notch, m + 3);
                ctx.lineTo(w - m, m + notch);
                ctx.quadraticCurveTo(w - m + sideBulge, h * 0.50,
                    w - m, h - m - notch);
                ctx.lineTo(w - m - notch, h - m - 3);
                ctx.quadraticCurveTo(w * 0.82, h - m + curveLift,
                    w * 0.65, h - m);
                ctx.lineTo(bypassRight, bypassBase);
                ctx.lineTo(bypassRight - bypassSlope, bypassTop);
                ctx.lineTo(bypassLeft + bypassSlope, bypassTop);
                ctx.lineTo(bypassLeft, bypassBase);
                ctx.lineTo(w * 0.35, h - m);
                ctx.quadraticCurveTo(w * 0.18, h - m + curveLift,
                    m + notch, h - m - 3);
                ctx.lineTo(m, h - m - notch);
                ctx.quadraticCurveTo(m - sideBulge, h * 0.50,
                    m, m + notch);
                ctx.closePath();
                ctx.stroke();

                ctx.shadowBlur = 0;
                ctx.lineWidth = 1.0;
                ctx.globalAlpha = 0.52;
                ctx.beginPath();
                ctx.moveTo(m + 30, m + notch + 20);
                ctx.quadraticCurveTo(m + 22, h * 0.24,
                    m + 26, h * 0.36);
                ctx.moveTo(m + 30, h * 0.64);
                ctx.quadraticCurveTo(m + 22, h * 0.76,
                    m + 30, h - m - notch - 20);
                ctx.moveTo(w - m - 30, m + notch + 20);
                ctx.quadraticCurveTo(w - m - 22, h * 0.24,
                    w - m - 26, h * 0.36);
                ctx.moveTo(w - m - 30, h * 0.64);
                ctx.quadraticCurveTo(w - m - 22, h * 0.76,
                    w - m - 30, h - m - notch - 20);
                ctx.stroke();

                ctx.globalAlpha = 0.78;
                ctx.lineWidth = 1.4;
                ctx.beginPath();
                ctx.moveTo(w * 0.32, m + 7);
                ctx.lineTo(topBypassLeft, m + 7);
                ctx.lineTo(topBypassLeft + topBypassSlope, topBypassBottom);
                ctx.lineTo(topBypassRight - topBypassSlope, topBypassBottom);
                ctx.lineTo(topBypassRight, m + 7);
                ctx.lineTo(w * 0.68, m + 7);
                ctx.moveTo(w * 0.34, h - m - 7);
                ctx.lineTo(bypassLeft, h - m - 7);
                ctx.lineTo(bypassLeft + bypassSlope, bypassTop);
                ctx.lineTo(bypassRight - bypassSlope, bypassTop);
                ctx.lineTo(bypassRight, h - m - 7);
                ctx.lineTo(w * 0.66, h - m - 7);
                ctx.stroke();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Repeater {
            model: 4
            Rectangle {
                width: index % 2 === 0 ? 48 : 28
                height: 1
                x: index < 2 ? 30 + index * 52 : parent.width - 104 + (index - 2) * 46
                y: index % 2 === 0 ? 38 : parent.height - 40
                rotation: index < 2 ? 28 : -28
                color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, parent.lineAlpha * 0.66)
            }
        }
    }

    component TelemetryPanel: Item {
        required property color accent
        // Opstartfase: het vak komt op in fase 2, zijn inhoud in fase 3.
        property int revealIndex: 0
        readonly property real reveal: root.stagger(root.panelReveal, revealIndex)
        readonly property real contentAlpha: root.stagger(root.contentReveal, revealIndex)
        opacity: reveal
        scale: 0.94 + reveal * 0.06

        layer.enabled: Math.abs(rotation) > 0.001
        layer.smooth: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * 2)),
            Math.max(1, Math.ceil(height * 2)))

        // laag 1: het vak zelf
        HudPanelChrome {
            z: 0
            anchors.fill: parent
            accent: parent.accent
        }

        // laag 2: de inhoud
        Text {
            z: 1
            opacity: parent.contentAlpha
            x: 18
            y: 14
            text: "COMPUTE // LIVE"
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Black
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.96)
        }

        Text {
            z: 1
            opacity: parent.contentAlpha
            x: 18
            y: 38
            width: parent.width - 36
            text: "RESOURCE ARRAY"
            elide: Text.ElideRight
            font.family: ThemeConfig.displayFont
            font.pixelSize: 20
            font.weight: Font.Light
            color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.98)
        }

        ColumnLayout {
            id: telemetryContent
            z: 1
            opacity: parent.contentAlpha
            x: 20
            y: 76
            width: parent.width - 40
            spacing: 8
            StatBar {
                reveal: telemetryContent.opacity
                label: "CPU"
                value: root.cpuPercent
                display: root.cpuPercent + "%  //  "
                    + (root.telemetry.cpuTemperatureAvailable ? root.cpuTemperature + "°C" : "TEMP n/a")
                accent: root.meterCpu
            }
            StatBar {
                reveal: telemetryContent.opacity
                label: "RAM"
                value: root.ramPercent
                accent: root.meterRam
            }
            StatBar {
                reveal: telemetryContent.opacity
                label: "GPU"
                value: Math.max(0, root.gpuPercent)
                display: root.gpuAvailable
                    ? root.gpuPercent + "%  //  "
                        + (root.telemetry.gpuTemperatureAvailable ? root.gpuTemperature + "°C" : "TEMP n/a")
                    : "n/a"
                accent: root.meterGpu
                available: root.gpuAvailable
            }
        }
    }

    component FanGridPanel: Item {
        required property color accent
        // Opstartfase: het vak komt op in fase 2, zijn inhoud in fase 3.
        property int revealIndex: 0
        readonly property real reveal: root.stagger(root.panelReveal, revealIndex)
        readonly property real contentAlpha: root.stagger(root.contentReveal, revealIndex)
        opacity: reveal
        scale: 0.94 + reveal * 0.06

        layer.enabled: Math.abs(rotation) > 0.001
        layer.smooth: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * 2)),
            Math.max(1, Math.ceil(height * 2)))

        // laag 1: het vak zelf
        HudPanelChrome {
            z: 0
            anchors.fill: parent
            accent: parent.accent
        }

        // laag 2: de inhoud
        Text {
            z: 1
            opacity: parent.contentAlpha
            x: 16
            y: 13
            text: "THERMAL // RPM"
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Black
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.96)
        }

        Text {
            z: 1
            opacity: parent.contentAlpha
            x: 16
            y: 31
            width: parent.width - 32
            text: "CPU " + (root.telemetry.cpuTemperatureAvailable ? root.cpuTemperature + "°C" : "n/a")
                + "   //   GPU " + (root.telemetry.gpuTemperatureAvailable ? root.gpuTemperature + "°C" : "n/a")
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            color: Qt.rgba(root.cyanSoft.r, root.cyanSoft.g, root.cyanSoft.b, 0.78)
        }

        GridLayout {
            z: 1
            opacity: parent.contentAlpha
            x: 14
            y: 54
            width: parent.width - 28
            height: parent.height - 72
            columns: 2
            columnSpacing: 10
            rowSpacing: 12
            FanTile { label: "FAN 01"; rpm: root.fan1Rpm; available: root.fan1Available; accent: root.cyan }
            FanTile { label: "FAN 02"; rpm: root.fan2Rpm; available: root.fan2Available; accent: root.cyanSoft }
            FanTile { label: "FAN 03"; rpm: root.fan3Rpm; available: root.fan3Available; accent: root.cyan }
            FanTile { label: "FAN 04"; rpm: root.fan4Rpm; available: root.fan4Available; accent: root.cyanSoft }
        }
    }

    // De omlijsting van een vak. Vectorwerk in plaats van een Canvas-bitmap:
    // een Canvas tekent in een textuur op zijn eigen logische maat en wordt
    // daarna in de 2x-layer van het paneel opgeblazen — dat is precies waarom
    // de vakranden vaag oogden. Een Shape wordt door de curve-renderer op de
    // uiteindelijke schaal gerasterd en blijft dus scherp, ook onder de lichte
    // rotatie van de panelen.
    component HudPanelChrome: Item {
        required property color accent

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, root.panelAlpha)
        }

        Shape {
            id: chromeShape
            anchors.fill: parent
            anchors.margins: -3
            preferredRendererType: Shape.CurveRenderer

            readonly property color accent: parent.accent
            readonly property real cut: Math.min(18, Math.min(width, height) * 0.16)

            // zachte gloed onder de kernlijn, in plaats van shadowBlur
            ShapePath {
                strokeColor: Qt.rgba(chromeShape.accent.r, chromeShape.accent.g,
                    chromeShape.accent.b, 0.20)
                strokeWidth: 5
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                startX: chromeShape.cut
                startY: 0
                PathLine { x: chromeShape.width - chromeShape.cut; y: 0 }
                PathLine { x: chromeShape.width; y: chromeShape.cut }
                PathLine { x: chromeShape.width; y: chromeShape.height - chromeShape.cut }
                PathLine { x: chromeShape.width - chromeShape.cut; y: chromeShape.height }
                PathLine { x: chromeShape.cut; y: chromeShape.height }
                PathLine { x: 0; y: chromeShape.height - chromeShape.cut }
                PathLine { x: 0; y: chromeShape.cut }
                PathLine { x: chromeShape.cut; y: 0 }
            }

            ShapePath {
                strokeColor: Qt.rgba(chromeShape.accent.r, chromeShape.accent.g,
                    chromeShape.accent.b, root.hudAlpha)
                strokeWidth: 1.25
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                startX: chromeShape.cut
                startY: 0
                PathLine { x: chromeShape.width - chromeShape.cut; y: 0 }
                PathLine { x: chromeShape.width; y: chromeShape.cut }
                PathLine { x: chromeShape.width; y: chromeShape.height - chromeShape.cut }
                PathLine { x: chromeShape.width - chromeShape.cut; y: chromeShape.height }
                PathLine { x: chromeShape.cut; y: chromeShape.height }
                PathLine { x: 0; y: chromeShape.height - chromeShape.cut }
                PathLine { x: 0; y: chromeShape.cut }
                PathLine { x: chromeShape.cut; y: 0 }
            }

            ShapePath {
                strokeColor: Qt.rgba(chromeShape.accent.r, chromeShape.accent.g,
                    chromeShape.accent.b, root.hudAlpha * 0.28)
                strokeWidth: 1
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                startX: 5.5
                startY: 5.5
                PathLine { x: chromeShape.width - 5.5; y: 5.5 }
                PathLine { x: chromeShape.width - 5.5; y: chromeShape.height - 5.5 }
                PathLine { x: 5.5; y: chromeShape.height - 5.5 }
                PathLine { x: 5.5; y: 5.5 }
            }
        }

        Rectangle {
            x: 12
            y: -3
            width: parent.width * 0.30
            height: 2
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.98)
        }
        Rectangle {
            x: parent.width * 0.76
            y: parent.height + 1
            width: parent.width * 0.20
            height: 2
            color: Qt.rgba(root.accentAlt.r, root.accentAlt.g, root.accentAlt.b, 0.76)
        }
    }

    component VerticalMeter: Item {
        required property string label
        required property int value
        required property string display
        required property color accent
        // Opstartfase: het vak komt op in fase 2, zijn inhoud in fase 3.
        property int revealIndex: 0
        readonly property real reveal: root.stagger(root.panelReveal, revealIndex)
        readonly property real contentAlpha: root.stagger(root.contentReveal, revealIndex)
        opacity: reveal
        scale: 0.94 + reveal * 0.06

        layer.enabled: Math.abs(rotation) > 0.001
        layer.smooth: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * 2)),
            Math.max(1, Math.ceil(height * 2)))

        // laag 1: het vak zelf
        HudPanelChrome {
            z: 0
            anchors.fill: parent
            accent: parent.accent
        }
        // laag 2: de inhoud
        Rectangle {
            z: 1
            opacity: parent.contentAlpha
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46
            width: 24
            height: parent.height - 92
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.18)
            border.width: 1
            border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.34)

            Column {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3
                Repeater {
                    model: 10
                    Rectangle {
                        width: parent.width
                        height: Math.max(3, (parent.parent.height - 27) / 10)
                        color: index >= 10 - Math.ceil(value * contentAlpha / 10)
                            ? Qt.rgba(parent.parent.parent.accent.r, parent.parent.parent.accent.g, parent.parent.parent.accent.b, 0.86)
                            : Qt.rgba(parent.parent.parent.accent.r, parent.parent.parent.accent.g, parent.parent.parent.accent.b, 0.10)
                    }
                }
            }
        }
        Text {
            z: 1
            opacity: parent.contentAlpha
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 14
            text: label
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Black
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.88)
        }
        Text {
            z: 1
            opacity: parent.contentAlpha
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 14
            text: display
            font.family: ThemeConfig.displayFont
            font.pixelSize: 18
            color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.90)
        }
    }

    component FanTile: Item {
        required property string label
        required property int rpm
        required property bool available
        required property color accent
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 64

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, available ? 0.34 : 0.18)
            border.width: 1
            border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, available ? 0.82 : 0.30)
            radius: 2
        }
        Item {
            id: fanGlyph
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34
            height: 34
            opacity: available ? 0.95 : 0.28
            property color glyphAccent: parent.accent

            // De ventilatorglyphs zitten in het 2x-layer van het paneel. Een
            // Canvas op logische maat wordt daarin opgeblazen, dus tekenen we
            // hem zelf al op dubbele maat en schalen hem terug.
            Canvas {
                id: fanRings
                readonly property real ss: root.glyphSupersample
                width: fanGlyph.width * ss
                height: fanGlyph.height * ss
                transformOrigin: Item.TopLeft
                scale: 1 / ss
                antialiasing: true
                smooth: true
                opacity: available ? 0.98 : 0.50
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(ss, ss);
                    let w = width / ss;
                    let h = height / ss;
                    let cx = w / 2;
                    let cy = h / 2;
                    let r = Math.min(w, h) / 2 - 3;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.82);
                    ctx.shadowColor = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.70);
                    ctx.shadowBlur = 8;

                    ctx.lineWidth = 1.8;
                    for (let i = 0; i < 4; i++) {
                        let start = i * Math.PI / 2 + 0.12;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, start, start + Math.PI / 2 - 0.34);
                        ctx.stroke();
                    }

                    ctx.shadowBlur = 0;
                    ctx.lineWidth = 1.0;
                    ctx.strokeStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.38);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r * 0.58, 0, Math.PI * 2);
                    ctx.stroke();

                    ctx.fillStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.88);
                    for (let i = 0; i < 8; i++) {
                        let a = i * Math.PI / 4;
                        let x1 = cx + Math.cos(a) * (r + 1);
                        let y1 = cy + Math.sin(a) * (r + 1);
                        ctx.save();
                        ctx.translate(x1, y1);
                        ctx.rotate(a);
                        ctx.fillRect(-1.5, -0.8, 3, 1.6);
                        ctx.restore();
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            Item {
                id: rotorSpin
                anchors.fill: parent

                Canvas {
                    id: rotorCanvas
                    readonly property real ss: root.glyphSupersample
                    width: rotorSpin.width * ss
                    height: rotorSpin.height * ss
                    transformOrigin: Item.TopLeft
                    scale: 1 / ss
                    antialiasing: true
                    smooth: true
                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();
                        ctx.scale(ss, ss);
                        let w = width / ss;
                        let h = height / ss;
                        let cx = w / 2;
                        let cy = h / 2;
                        let r = Math.min(w, h) / 2 - 5;
                        ctx.translate(cx, cy);
                        ctx.shadowColor = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.82);
                        ctx.shadowBlur = 10;

                        for (let i = 0; i < 5; i++) {
                            ctx.save();
                            ctx.rotate(i * Math.PI * 2 / 5);
                            let blade = ctx.createLinearGradient(0, -2, r * 0.78, -9);
                            blade.addColorStop(0.0, Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.12));
                            blade.addColorStop(0.45, Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.82));
                            blade.addColorStop(1.0, Qt.rgba(root.accentAlt.r, root.accentAlt.g, root.accentAlt.b, 0.30));
                            ctx.fillStyle = blade;
                            ctx.beginPath();
                            ctx.moveTo(3, -2);
                            ctx.quadraticCurveTo(r * 0.42, -12, r * 0.78, -5);
                            ctx.quadraticCurveTo(r * 0.55, 5, 6, 4);
                            ctx.closePath();
                            ctx.fill();
                            ctx.restore();
                        }

                        ctx.shadowBlur = 0;
                        ctx.strokeStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.76);
                        ctx.lineWidth = 1.3;
                        ctx.beginPath();
                        ctx.arc(0, 0, r * 0.30, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.fillStyle = Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.84);
                        ctx.beginPath();
                        ctx.arc(0, 0, r * 0.18, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.fillStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.92);
                        ctx.beginPath();
                        ctx.arc(0, 0, r * 0.09, 0, Math.PI * 2);
                        ctx.fill();
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }
                RotationAnimation on rotation {
                    running: root.active && available
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: Math.max(850, 4600 - rpm)
                }
            }
        }
        ColumnLayout {
            anchors.top: fanGlyph.bottom
            anchors.topMargin: 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: label
                font.family: ThemeConfig.monoFont
                font.pixelSize: 10
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                color: Qt.rgba(parent.parent.accent.r, parent.parent.accent.g, parent.parent.accent.b, 0.84)
            }
            Text {
                Layout.fillWidth: true
                text: available ? (rpm + " RPM") : "offline"
                elide: Text.ElideRight
                font.family: ThemeConfig.displayFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, available ? 0.90 : 0.38)
            }
        }
    }

    component HudFrame: Item {
        required property color accent
        required property string label
        required property string primary
        required property string secondary
        property int primaryPixelSize: Math.max(18, Math.min(42, height * 0.38))
        property int contentMargin: height <= 80 ? 10 : 14
        property int detailPixelSize: height <= 80 ? 10 : 11
        // Opstartfase: het vak komt op in fase 2, zijn inhoud in fase 3.
        property int revealIndex: 0
        readonly property real reveal: root.stagger(root.panelReveal, revealIndex)
        readonly property real contentAlpha: root.stagger(root.contentReveal, revealIndex)
        opacity: reveal
        scale: 0.94 + reveal * 0.06

        layer.enabled: Math.abs(rotation) > 0.001
        layer.smooth: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * 2)),
            Math.max(1, Math.ceil(height * 2)))

        // laag 1: het vak zelf
        HudPanelChrome {
            z: 0
            anchors.fill: parent
            accent: parent.accent
        }

        // laag 2: de inhoud
        ColumnLayout {
            z: 1
            opacity: parent.contentAlpha
            anchors.fill: parent
            anchors.margins: parent.contentMargin
            spacing: parent.height <= 80 ? 1 : 3
            Text {
                text: label
                font.family: ThemeConfig.monoFont
                font.pixelSize: parent.parent.detailPixelSize
                font.weight: Font.Bold
                color: Qt.rgba(parent.parent.accent.r, parent.parent.accent.g, parent.parent.accent.b, 0.96)
            }
            Text {
                text: primary
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: ThemeConfig.displayFont
                font.pixelSize: parent.parent.primaryPixelSize
                font.weight: Font.Light
                color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.96)
            }
            Text {
                text: secondary
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: ThemeConfig.monoFont
                font.pixelSize: parent.parent.detailPixelSize
                color: Qt.rgba(root.cyanSoft.r, root.cyanSoft.g, root.cyanSoft.b, 0.88)
            }
        }
    }

    component StatBar: ColumnLayout {
        required property string label
        required property int value
        required property color accent
        // Loopt tijdens de inhoudfase van 0 naar 1, zodat de balk zichzelf
        // vult in plaats van meteen op zijn waarde te staan.
        property real reveal: 1
        property bool available: true
        property string display: available ? (value + "%") : "n/a"
        Layout.fillWidth: true
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: label
                font.family: ThemeConfig.monoFont
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.96)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: display
                font.family: ThemeConfig.monoFont
                font.pixelSize: 11
                color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, available ? 0.92 : 0.42)
            }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 4
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.42)
            border.width: 1
            border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.30)
            Rectangle {
                width: available
                    ? parent.width * Math.max(0.0, Math.min(1.0, value / 100.0)) * reveal
                    : 0
                height: parent.height
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.88)
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            }
        }
    }

    component Radar: Item {
        required property real size
        required property color accent
        property int revealIndex: 0
        readonly property real reveal: root.stagger(root.panelReveal, revealIndex)
        readonly property real contentAlpha: root.stagger(root.contentReveal, revealIndex)
        width: size
        height: size
        opacity: 0.72 * reveal
        scale: 0.94 + reveal * 0.06

        Repeater {
            model: 4
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (0.25 + index * 0.20)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.24 + index * 0.04)
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: 1
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.42)
        }
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height * 0.86
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.30)
        }
        // De naald en het label zijn de inhoud van de radar en komen dus in
        // fase 3 mee, niet met de ringen.
        Rectangle {
            id: radarNeedle
            opacity: parent.contentAlpha
            x: parent.width / 2
            y: parent.height / 2
            width: parent.width * 0.43
            height: 2
            transformOrigin: Item.Left
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.66)
            RotationAnimation on rotation {
                running: root.active
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: ThemeConfig.duration(18000)
            }
        }

        Text {
            opacity: parent.contentAlpha
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 6
            text: root.telemetry.linkState + " // " + root.telemetry.interfaceName.toUpperCase()
            font.family: ThemeConfig.monoFont
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.68)
        }
    }
}
