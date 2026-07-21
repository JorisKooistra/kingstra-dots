import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."

// Dashboard dat uit de bovenrand groeit. Opzet overgenomen van Caelestia's
// dash-tab: informatie die je in één oogopslag wilt zien (tijd, maand,
// systeembelasting, wat er speelt) in plaats van knoppen die alleen andere
// panelen openen — die staan al in de rail, dus die waren hier dubbelop.
Item {
    id: root

    MatugenColors { id: mocha }

    readonly property int pad: 14
    readonly property int cardRadius: Math.max(12, ThemeConfig.styleWidgetRadius)
    readonly property color cardColor: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.26)
    readonly property color cardBorder: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

    property var now: new Date()
    // Expliciete locale: de sessie draait op een C/en_US-locale, waardoor
    // dag- en maandnamen anders in het Engels tussen de Nederlandse labels
    // zouden staan.
    readonly property var nl: Qt.locale("nl_NL")
    readonly property string timeText: Qt.formatDateTime(now, "HH:mm")
    readonly property string dayName: now.toLocaleDateString(nl, "dddd")
    readonly property string dateText: now.toLocaleDateString(nl, "d MMMM yyyy")

    property int cpuPercent: 0
    property int ramPercent: 0
    property int diskPercent: 0
    property string cpuTemp: "--"

    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool hasMedia: activePlayer !== null
                                     && String(activePlayer.trackTitle || "").trim() !== ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: metricsPoller.running = true
    }

    Process {
        id: metricsPoller
        command: ["bash", "-lc",
            "cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(seen){printf \"%.0f\",(u-prevu)*100/(t-prevt); exit} prevt=t; prevu=u; seen=1}' <(cat /proc/stat; sleep 0.25; cat /proc/stat)); " +
            "ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\",((t-a)*100)/t}' /proc/meminfo); " +
            "disk=$(df -P / | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'); " +
            "cput=$(sensors 2>/dev/null | awk '/^(Core 0|Tdie|Package id 0|temp1):/ {gsub(/[^0-9.]/,\" \",$2); if($2+0>0){printf \"%.0f\",$2; exit}}'); " +
            "if [ -z \"$cput\" ]; then cput=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk 'NF{printf \"%.0f\", $1/1000}'); fi; " +
            "printf '%s|%s|%s|%s\\n' \"${cpu:-0}\" \"${ram:-0}\" \"${disk:-0}\" \"${cput:---}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length < 4) return;
                root.cpuPercent = root.clampPercent(parts[0]);
                root.ramPercent = root.clampPercent(parts[1]);
                root.diskPercent = root.clampPercent(parts[2]);
                root.cpuTemp = (parts[3] === "" || parts[3] === "--") ? "--" : parts[3] + "°";
            }
        }
    }

    function clampPercent(value) {
        let parsed = parseInt(value);
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 10

        // --- Tijd en datum ---------------------------------------------------
        Card {
            Layout.preferredWidth: 190
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timeText
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 46
                    font.weight: Font.Black
                    color: mocha.text
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.dayName
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: mocha.primary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.dateText
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }
            }
        }

        // --- Maandkalender ---------------------------------------------------
        Card {
            Layout.preferredWidth: 250
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.now.toLocaleDateString(root.nl, "MMMM yyyy")
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: mocha.text
                    horizontalAlignment: Text.AlignHCenter
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 1
                    columnSpacing: 1

                    Repeater {
                        model: ["ma", "di", "wo", "do", "vr", "za", "zo"]
                        delegate: Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 9
                            color: mocha.subtext0
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // 6 weken * 7 dagen dekt elke maandindeling.
                    Repeater {
                        model: 42
                        delegate: Item {
                            required property int index

                            // Maandag = 0. JS telt zondag als 0, vandaar de shift.
                            readonly property int firstDow: {
                                let d = new Date(root.now.getFullYear(), root.now.getMonth(), 1).getDay();
                                return (d + 6) % 7;
                            }
                            readonly property int daysInMonth: new Date(
                                root.now.getFullYear(), root.now.getMonth() + 1, 0).getDate()
                            readonly property int dayNum: index - firstDow + 1
                            readonly property bool valid: dayNum >= 1 && dayNum <= daysInMonth
                            readonly property bool isToday: valid && dayNum === root.now.getDate()

                            Layout.fillWidth: true
                            Layout.preferredHeight: 17

                            Rectangle {
                                anchors.centerIn: parent
                                width: 18
                                height: 16
                                radius: 5
                                visible: parent.isToday
                                color: mocha.primary
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: parent.valid
                                text: parent.valid ? parent.dayNum : ""
                                font.family: ThemeConfig.monoFont
                                font.pixelSize: 10
                                font.weight: parent.isToday ? Font.Black : Font.Normal
                                color: parent.isToday ? mocha.base : mocha.text
                            }
                        }
                    }
                }
            }
        }

        // --- Systeembelasting ------------------------------------------------
        Card {
            Layout.preferredWidth: 210
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Meter {
                    label: "CPU"
                    value: root.cpuPercent
                    suffix: root.cpuTemp === "--" ? "" : root.cpuTemp
                    accent: mocha.peach
                }
                Meter {
                    label: "Geheugen"
                    value: root.ramPercent
                    accent: mocha.blue
                }
                Meter {
                    label: "Schijf"
                    value: root.diskPercent
                    accent: mocha.teal
                }
            }
        }

        // --- Media -----------------------------------------------------------
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: 14
                    color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.14)
                    clip: true

                    Image {
                        id: cover
                        anchors.fill: parent
                        source: root.activePlayer && root.activePlayer.trackArtUrl
                            ? root.activePlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: "󰎆"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 24
                        color: mocha.green
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.hasMedia ? root.activePlayer.trackTitle : "Geen media actief"
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: mocha.text
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.hasMedia ? String(root.activePlayer.trackArtist || "") : ""
                        visible: text !== ""
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 11
                        color: mocha.subtext0
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 6
                        visible: root.hasMedia

                        MediaButton {
                            icon: "󰒮"
                            onTriggered: if (root.activePlayer && root.activePlayer.canGoPrevious)
                                root.activePlayer.previous()
                        }
                        MediaButton {
                            icon: root.activePlayer
                                && root.activePlayer.playbackState === MprisPlaybackState.Playing
                                ? "󰏤" : "󰐊"
                            onTriggered: if (root.activePlayer && root.activePlayer.canTogglePlaying)
                                root.activePlayer.togglePlaying()
                        }
                        MediaButton {
                            icon: "󰒭"
                            onTriggered: if (root.activePlayer && root.activePlayer.canGoNext)
                                root.activePlayer.next()
                        }
                    }
                }
            }
        }
    }

    component Card: Rectangle {
        radius: root.cardRadius
        color: root.cardColor
        border.width: 1
        border.color: root.cardBorder
    }

    component Meter: ColumnLayout {
        id: meter

        property string label: ""
        property int value: 0
        property string suffix: ""
        property color accent: mocha.text

        Layout.fillWidth: true
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: meter.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                color: mocha.subtext1
            }
            Item { Layout.fillWidth: true }
            Text {
                text: meter.value + "%" + (meter.suffix !== "" ? "  " + meter.suffix : "")
                font.family: ThemeConfig.monoFont
                font.pixelSize: 11
                font.weight: Font.Bold
                color: mocha.text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            radius: 3
            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
                height: parent.height
                radius: parent.radius
                color: meter.accent

                Behavior on width {
                    NumberAnimation {
                        duration: ThemeConfig.durationToken("medium")
                        easing.type: ThemeConfig.easingToken("standard")
                    }
                }
            }
        }
    }

    component MediaButton: Rectangle {
        id: btn

        property string icon: ""
        signal triggered()

        implicitWidth: 28
        implicitHeight: 24
        radius: 8
        color: btnMouse.containsMouse
            ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.22)
            : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.30)

        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 13
            color: mocha.text
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
