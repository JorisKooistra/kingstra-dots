import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../"
import "../shellsurface"

// Batterij & energie: in dezelfde vormtaal als Snelle instellingen en
// Geluid & media (afgeronde tegels, Matugen-themakleuren, ThemeConfig-
// animaties). Vervangt de oude batterijkern met ring en golven; alle
// functies daarvan zitten er nog in:
//  - batterijpercentage en status (opladen, ontladen, vol), met
//    waarschuwingspuls onder 15%;
//  - helderheid en volume (klik op het luidsprekertje dempt);
//  - energieprofiel (Prestaties, Gebalanceerd, Besparing) + idle-profiel;
//  - vergrendelen, slaapstand, herstarten en afsluiten met ingedrukt
//    houden (kort op Afsluiten = slaapstand, net als voorheen);
//  - uptime, gebruikersnaam en uitloggen.
// Nieuw: resterende tijd, verbruik in watt en batterijconditie als UPower
// die meldt, en een terugknop naar Snelle instellingen.
// De vorm (blob, hoeken, groei-animatie) komt volledig uit PanelHost.
Item {
    id: root

    MatugenColors { id: mocha }
    // Voor PanelSlider: `mocha: mocha` zou op de eigen property kunnen binden.
    readonly property var mochaPalette: mocha

    signal panelSwitchRequested(string entryId)

    readonly property int pad: 16
    readonly property int itemRadius: Math.max(10, Math.min(16, ThemeConfig.styleWidgetRadius))
    readonly property bool matteStyle: ThemeConfig.styleFamily === "matte"
    readonly property int preferredPanelWidth: 420
    readonly property int preferredPanelHeight: Math.ceil(content.implicitHeight + pad * 2)

    // ------------------------------------------------------------------------
    // Batterij (UPower, event-driven)
    // ------------------------------------------------------------------------
    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device !== null && device.ready
        && device.state !== UPowerDeviceState.Unknown
    readonly property int batCapacity: hasBattery ? Math.round(device.percentage * 100) : 0
    readonly property bool isCharging: hasBattery
        && (device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.FullyCharged
            || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool isFull: hasBattery && device.state === UPowerDeviceState.FullyCharged
    readonly property bool isDanger: hasBattery && !isCharging && batCapacity < 15

    readonly property color batColor: {
        if (!hasBattery) return mocha.accent1;
        if (isCharging) return mocha.green;
        if (batCapacity >= 70) return mocha.accent1;
        if (batCapacity >= 30) return mocha.yellow;
        return mocha.red;
    }

    readonly property string batIcon: {
        if (!hasBattery) return "󰚥";
        if (isCharging) return "󰂄";
        let steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(10, Math.round(batCapacity / 10)))];
    }

    function spanText(seconds) {
        let h = Math.floor(seconds / 3600);
        let m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? h + "u " + (m < 10 ? "0" : "") + m + "m" : m + "m";
    }

    readonly property string statusText: {
        if (!hasBattery) return "Netstroom";
        if (isFull) return "Volledig opgeladen";
        if (isCharging) {
            let t = Number(device.timeToFull || 0);
            return t > 0 ? "Opladen · vol over " + spanText(t) : "Opladen";
        }
        let t = Number(device.timeToEmpty || 0);
        return t > 0 ? "Op batterij · nog " + spanText(t) : "Op batterij";
    }

    // Niet elke UPower-versie of batterij meldt dit; alleen tonen wat er is.
    readonly property real watts: hasBattery && device.changeRate !== undefined ? Math.abs(Number(device.changeRate) || 0) : 0
    readonly property real health: hasBattery && device.healthPercentage !== undefined
        && (device.healthSupported === undefined || device.healthSupported)
        ? Number(device.healthPercentage) || 0 : 0

    property real animCapacity: 0
    Behavior on animCapacity {
        NumberAnimation { duration: ThemeConfig.duration(1200); easing.type: Easing.OutQuint }
    }
    onBatCapacityChanged: animCapacity = batCapacity
    Component.onCompleted: animCapacity = batCapacity

    // ------------------------------------------------------------------------
    // Energieprofiel (UPower PowerProfiles)
    // ------------------------------------------------------------------------
    readonly property string powerProfile: {
        let p = PowerProfiles.profile;
        if (p === PowerProfile.Performance) return "performance";
        if (p === PowerProfile.PowerSaver) return "power-saver";
        return "balanced";
    }

    function profileColor(name) {
        if (name === "performance") return mocha.accent2;
        if (name === "power-saver") return mocha.green;
        return mocha.accent1;
    }

    function setProfile(name) {
        if (name === "performance") PowerProfiles.profile = PowerProfile.Performance;
        else if (name === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver;
        else PowerProfiles.profile = PowerProfile.Balanced;
        Quickshell.execDetached(["bash", "-lc", "sleep 0.4; \"$HOME/.config/shared/scripts/kingstra-idle-apply\" '" + name + "' >/dev/null 2>&1 || true"]);
    }

    // ------------------------------------------------------------------------
    // Volume (Pipewire) en helderheid (brightnessctl)
    // ------------------------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool volumeReady: !!sink && !!sink.audio && sink.audio.ready !== false
    readonly property int sysVolume: volumeReady ? Math.round(sink.audio.volume * 100) : -1
    readonly property bool sysMuted: volumeReady ? sink.audio.muted : false

    Timer {
        id: volumeThrottle
        interval: 50
        property real targetVol: -1
        onTriggered: {
            if (targetVol >= 0 && root.volumeReady) {
                root.sink.audio.volume = targetVol;
                if (targetVol > 0 && root.sink.audio.muted) root.sink.audio.muted = false;
            }
            targetVol = -1;
        }
    }

    property int sysBrightness: -1
    property bool draggingBrightness: false

    Timer {
        id: brightnessThrottle
        interval: 50
        property int targetPct: -1
        onTriggered: {
            if (targetPct >= 0)
                Quickshell.execDetached(["brightnessctl", "-q", "set", targetPct + "%"]);
            targetPct = -1;
        }
    }

    // ------------------------------------------------------------------------
    // Uptime, gebruikersnaam en helderheid
    // ------------------------------------------------------------------------
    property int upHours: 0
    property int upMins: 0
    property string currentUserName: ""

    Process {
        id: sysPoller
        command: ["bash", "-c",
            "echo \"$USER\"; " +
            "awk '{print int($1/3600)\" \"int(($1%3600)/60)}' /proc/uptime 2>/dev/null || echo '0 0'; " +
            "if command -v brightnessctl >/dev/null 2>&1; then brightnessctl -m 2>/dev/null | awk -F, 'NR==1{gsub(/%/,\"\",$4); print $4}'; else echo -1; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length < 2) return;
                root.currentUserName = lines[0];
                let up = lines[1].split(" ");
                root.upHours = parseInt(up[0]) || 0;
                root.upMins = parseInt(up[1]) || 0;
                if (!root.draggingBrightness && lines.length >= 3) {
                    let b = parseInt(lines[2]);
                    root.sysBrightness = isNaN(b) ? -1 : b;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!sysPoller.running) sysPoller.running = true
    }

    function closeAndRun(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
        Quickshell.execDetached(["bash", "-c", "echo close > /tmp/qs_widget_state"]);
        root.panelSwitchRequested("");
    }

    // ------------------------------------------------------------------------
    // Weergave
    // ------------------------------------------------------------------------
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 12

        // --- Kop -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Math.min(root.itemRadius, 18)
                color: Qt.rgba(root.batColor.r, root.batColor.g, root.batColor.b, 0.22)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.batIcon
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 18
                    color: root.batColor
                    Behavior on color {
                        ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: root.hasBattery ? "Batterij & energie" : "Energie"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: ThemeConfig.headingWeight
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: "Aan sinds " + root.upHours + "u " + (root.upMins < 10 ? "0" : "") + root.upMins + "m"
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "󰅁"
                accent: mocha.subtext1
                onTriggered: root.panelSwitchRequested("quicksettings")
            }

            // Uitloggen: klapt bij hover open met je gebruikersnaam.
            Rectangle {
                id: logoutButton
                Layout.preferredHeight: 32
                Layout.preferredWidth: logoutMouse.containsMouse ? 32 + userText.implicitWidth + 10 : 32
                radius: Math.min(root.itemRadius, 16)
                clip: true
                color: logoutMouse.containsMouse
                    ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.20)
                    : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
                }
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        id: userText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentUserName
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: mocha.text
                        opacity: logoutMouse.containsMouse ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: ThemeConfig.durationToken("fast") }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍃"
                        font.family: ThemeConfig.iconFont
                        font.pixelSize: 15
                        color: logoutMouse.containsMouse ? mocha.red : mocha.subtext0
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                        }
                    }
                }
                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeAndRun("loginctl terminate-user \"$USER\"")
                }
            }
        }

        // --- Batterijkaart ----------------------------------------------------
        Rectangle {
            id: hero
            Layout.fillWidth: true
            Layout.preferredHeight: heroColumn.implicitHeight + 24
            radius: Math.min(root.itemRadius + 2, 18)
            color: root.matteStyle
                ? mocha.shellRaisedFill
                : Qt.rgba(root.batColor.r, root.batColor.g, root.batColor.b, root.isDanger ? 0.10 + dangerPulse * 0.10 : 0.10)
            border.width: 1
            border.color: Qt.rgba(root.batColor.r, root.batColor.g, root.batColor.b, root.isDanger ? 0.40 + dangerPulse * 0.35 : 0.35)
            Behavior on color {
                enabled: !root.isDanger
                ColorAnimation { duration: ThemeConfig.durationToken("normal") }
            }

            // Waarschuwingspuls bij een bijna lege batterij.
            property real dangerPulse: 0
            SequentialAnimation on dangerPulse {
                running: root.isDanger
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 900; easing.type: Easing.InOutSine }
            }

            ColumnLayout {
                id: heroColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        visible: root.hasBattery
                        text: Math.round(root.animCapacity)
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 40
                        font.weight: ThemeConfig.headingWeight
                        color: mocha.text
                    }
                    Text {
                        visible: root.hasBattery
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 8
                        Layout.leftMargin: -6
                        text: "%"
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 18
                        font.weight: ThemeConfig.emphasisWeight
                        color: mocha.subtext0
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: root.hasBattery ? 4 : 0
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.statusText
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.isCharging || root.isDanger ? root.batColor : mocha.text
                            elide: Text.ElideRight
                            Behavior on color {
                                ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: !root.hasBattery ? "Geen batterij gevonden; dit apparaat draait op netstroom."
                                : (root.isDanger ? "Batterij bijna leeg: sluit de lader aan."
                                   : (root.isCharging ? "Lader aangesloten" : "Lader niet aangesloten"))
                            wrapMode: Text.WordWrap
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 10
                            color: mocha.subtext0
                        }
                    }
                }

                // Batterijbalk: gevulde pil, met een glans die meeloopt tijdens
                // het opladen.
                Rectangle {
                    id: batteryTrack
                    visible: root.hasBattery
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14
                    radius: height / 2
                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)

                    Rectangle {
                        id: batteryFill
                        width: Math.max(batteryTrack.height, batteryTrack.width * Math.max(0, Math.min(100, root.animCapacity)) / 100)
                        height: parent.height
                        radius: parent.radius
                        color: root.batColor
                        clip: true
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                        }

                        Rectangle {
                            visible: root.isCharging && !root.isFull
                            width: 60
                            height: parent.height
                            radius: parent.radius
                            property real sweep: 0
                            x: -width + (batteryFill.width + width) * sweep
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                            }
                            NumberAnimation on sweep {
                                from: 0; to: 1; duration: 1800
                                loops: Animation.Infinite
                                running: root.isCharging && !root.isFull
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                // Extra gegevens (alleen wat UPower meldt).
                Flow {
                    Layout.fillWidth: true
                    visible: root.hasBattery && (root.watts > 0.05 || root.health > 0)
                    spacing: 6
                    InfoChip {
                        visible: root.watts > 0.05
                        icon: root.isCharging ? "󱐋" : "󰠰"
                        label: (root.isCharging ? "Laadt " : "Verbruik ") + root.watts.toFixed(1) + " W"
                    }
                    InfoChip {
                        visible: root.health > 0
                        icon: "󰄌"
                        label: "Conditie " + Math.round(root.health) + "%"
                    }
                }
            }
        }

        // --- Schuifregelaars ---------------------------------------------------
        PanelSlider {
            mocha: root.mochaPalette
            itemRadius: root.itemRadius
            visible: root.sysBrightness >= 0
            icon: root.sysBrightness > 66 ? "󰃠" : (root.sysBrightness > 33 ? "󰃟" : "󰃞")
            label: "Helderheid"
            value: root.sysBrightness
            accent: mocha.yellow
            onDragToggled: (dragging) => root.draggingBrightness = dragging
            onMoved: (percent) => {
                let v = Math.max(1, Math.min(100, Math.round(percent)));
                root.sysBrightness = v;
                brightnessThrottle.targetPct = v;
                if (!brightnessThrottle.running) brightnessThrottle.start();
            }
        }

        PanelSlider {
            mocha: root.mochaPalette
            itemRadius: root.itemRadius
            visible: root.sysVolume >= 0
            icon: root.sysMuted || root.sysVolume === 0 ? "󰖁" : (root.sysVolume > 50 ? "󰕾" : "󰖀")
            label: root.sysMuted ? "Gedempt" : "Volume"
            value: root.sysVolume
            dimmed: root.sysMuted
            accent: mocha.accent3
            onIconClicked: if (root.volumeReady) root.sink.audio.muted = !root.sink.audio.muted
            onMoved: (percent) => {
                volumeThrottle.targetVol = Math.max(0, Math.min(100, percent)) / 100;
                if (!volumeThrottle.running) volumeThrottle.start();
            }
        }

        // --- Energieprofiel ---------------------------------------------------
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: "Energieprofiel"
            font.family: ThemeConfig.uiFont
            font.pixelSize: 10
            font.weight: ThemeConfig.emphasisWeight
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
            color: mocha.subtext0
        }

        Rectangle {
            id: profileBar
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Math.min(root.itemRadius, 20)
            color: root.matteStyle ? mocha.shellRaisedFill : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

            readonly property var profiles: ["performance", "balanced", "power-saver"]
            readonly property int profileIndex: Math.max(0, profiles.indexOf(root.powerProfile))
            readonly property real segmentWidth: (width - 6) / profiles.length
            readonly property color currentColor: root.profileColor(root.powerProfile)

            Rectangle {
                x: 3 + profileBar.profileIndex * profileBar.segmentWidth
                y: 3
                width: profileBar.segmentWidth
                height: profileBar.height - 6
                radius: Math.max(4, profileBar.radius - 3)
                color: Qt.rgba(profileBar.currentColor.r, profileBar.currentColor.g, profileBar.currentColor.b, 0.24)
                border.width: 1
                border.color: Qt.rgba(profileBar.currentColor.r, profileBar.currentColor.g, profileBar.currentColor.b, 0.50)
                Behavior on x {
                    NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
                }
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                }
                Behavior on border.color {
                    ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 0
                ProfileButton { profile: "performance"; icon: "󰓅"; label: "Prestaties" }
                ProfileButton { profile: "balanced"; icon: "󰾅"; label: "Gebalanceerd" }
                ProfileButton { profile: "power-saver"; icon: "󰌪"; label: "Besparing" }
            }
        }

        // --- Systeemacties ---------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8
            HoldAction {
                icon: "󰌾"; label: "Vergrendel"; accent: mocha.accent1
                holdMs: 550
                cmd: "bash ~/.config/hypr/scripts/lock.sh"
            }
            HoldAction {
                icon: "󰤄"; label: "Slaapstand"; accent: mocha.accent3
                holdMs: 550
                cmd: "bash ~/.config/hypr/scripts/suspend.sh"
            }
            HoldAction {
                icon: "󰜉"; label: "Herstart"; accent: mocha.yellow
                holdMs: 1375
                cmd: "systemctl reboot"
            }
            HoldAction {
                icon: "󰐥"; label: "Afsluiten"; accent: mocha.red
                holdMs: 2000
                cmd: "systemctl poweroff"
                // Kort tikken = slaapstand, lang vasthouden = afsluiten.
                tapCmd: "bash ~/.config/hypr/scripts/suspend.sh"
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Houd een knop ingedrukt om te bevestigen · kort op Afsluiten = slaapstand"
            wrapMode: Text.WordWrap
            font.family: ThemeConfig.uiFont
            font.pixelSize: 9
            color: mocha.subtext0
            opacity: 0.8
        }
    }

    // ------------------------------------------------------------------------
    // Componenten
    // ------------------------------------------------------------------------

    component IconButton: Rectangle {
        id: ib
        property string icon: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Math.min(root.itemRadius, 16)
        color: ibMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.20)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        scale: ibMouse.pressed ? 0.94 : (ibMouse.containsMouse ? 1.07 : 1.0)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Text {
            anchors.centerIn: parent
            text: ib.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 15
            color: ib.accent
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.triggered()
        }
    }

    component InfoChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        width: chipRow.implicitWidth + 16
        height: 24
        radius: height / 2
        color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 12
                color: root.batColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: ThemeConfig.monoFont
                font.pixelSize: 10
                font.weight: Font.Medium
                color: mocha.text
            }
        }
    }

    component ProfileButton: Item {
        id: pb
        property string profile: ""
        property string icon: ""
        property string label: ""
        readonly property bool current: root.powerProfile === profile
        readonly property color tint: root.profileColor(profile)

        Layout.fillWidth: true
        Layout.fillHeight: true

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pb.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 14
                color: pb.current ? pb.tint : (pbMouse.containsMouse ? mocha.text : mocha.subtext0)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pb.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: pb.current ? Font.DemiBold : Font.Normal
                color: pb.current || pbMouse.containsMouse ? mocha.text : mocha.subtext0
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setProfile(pb.profile)
        }
    }

    // Ingedrukt houden om te bevestigen: de tegel vult zich van onder naar
    // boven in de accentkleur; loslaten laat hem weer leeglopen.
    component HoldAction: Rectangle {
        id: action
        property string icon: ""
        property string label: ""
        property color accent: mocha.primary
        property string cmd: ""
        property string tapCmd: ""
        property int holdMs: 550
        property real fillLevel: 0
        property bool fired: false
        property real flash: 0

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: Math.min(root.itemRadius, 16)
        color: actionMouse.containsMouse
            ? Qt.rgba(action.accent.r, action.accent.g, action.accent.b, 0.14)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
        border.width: 1
        border.color: actionMouse.containsMouse
            ? Qt.rgba(action.accent.r, action.accent.g, action.accent.b, 0.50)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
        scale: actionMouse.pressed ? 0.97 : 1.0
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }
        Behavior on border.color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        // Vulling: een afgeronde pil die van onder omhoog groeit.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: Math.max(0, (parent.height - 2) * action.fillLevel)
            radius: Math.min(parent.radius - 1, height / 2)
            visible: action.fillLevel > 0.001
            color: Qt.rgba(action.accent.r, action.accent.g, action.accent.b, 0.85)
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#ffffff"
            opacity: action.flash
        }

        Column {
            anchors.centerIn: parent
            spacing: 3
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: action.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 20
                color: action.fillLevel > 0.5 ? mocha.crust
                    : (actionMouse.containsMouse ? action.accent : mocha.subtext0)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: action.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: action.fillLevel > 0.25 ? mocha.crust
                    : (actionMouse.containsMouse ? mocha.text : mocha.subtext0)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
        }

        function fire(command) {
            if (action.fired) return;
            action.fired = true;
            flashAnim.restart();
            runTimer.command = command;
            runTimer.start();
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: action.fired ? Qt.ArrowCursor : Qt.PointingHandCursor
            onPressed: {
                if (action.fired) return;
                drainAnim.stop();
                fillAnim.start();
            }
            onReleased: {
                if (action.fired || action.fillLevel >= 1.0) return;
                fillAnim.stop();
                drainAnim.start();
                if (action.tapCmd !== "") action.fire(action.tapCmd);
            }
            onCanceled: {
                if (action.fired) return;
                fillAnim.stop();
                drainAnim.start();
            }
        }

        NumberAnimation {
            id: fillAnim
            target: action
            property: "fillLevel"
            to: 1.0
            duration: action.holdMs * (1.0 - action.fillLevel)
            easing.type: Easing.InSine
            onFinished: if (action.fillLevel >= 1.0) action.fire(action.cmd)
        }
        NumberAnimation {
            id: drainAnim
            target: action
            property: "fillLevel"
            to: 0.0
            duration: 900 * action.fillLevel
            easing.type: Easing.OutQuad
        }
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: action; property: "flash"; to: 0.5; duration: 60 }
            NumberAnimation { target: action; property: "flash"; to: 0; duration: 420; easing.type: Easing.OutExpo }
        }
        // Korte pauze zodat de bevestiging zichtbaar is vóór het paneel sluit.
        Timer {
            id: runTimer
            interval: 350
            property string command: ""
            onTriggered: root.closeAndRun(command)
        }
    }
}
