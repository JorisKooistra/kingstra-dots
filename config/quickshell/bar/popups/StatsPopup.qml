// =============================================================================
// StatsPopup.qml — Uitgebreid systeeminfopaneel
// =============================================================================
// Opent via klik op de SystemStats-pill in de topbar.
// Toont: CPU, RAM, Disk, Temperatuur, Netwerk, Uptime, btop-knop.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../"

PanelWindow {
    id: statsPopup

    // Koppeling met de ouderbar voor monitor + hoogte
    property PanelWindow parentBar

    // ---------------------------------------------------------------------------
    // Layershell configuratie
    // ---------------------------------------------------------------------------
    WlrLayershell.monitor: parentBar ? parentBar.WlrLayershell.monitor : null
    WlrLayershell.layer:   WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; right: true }
    margins {
        top:   (parentBar ? parentBar.height : 36) + 6
        right: 8
    }

    width:  248
    height: content.implicitHeight + 24
    color:  "transparent"

    // ---------------------------------------------------------------------------
    // Achtergrond
    // ---------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:        Colors.popupBackground
        radius:       14
        border {
            color: Qt.rgba(
                Colors.outline.r,
                Colors.outline.g,
                Colors.outline.b,
                0.35
            )
            width: 1
        }

        // ---------------------------------------------------------------------------
        // Inhoud
        // ---------------------------------------------------------------------------
        ColumnLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 6

            // Header
            Text {
                text:  " Systeeminfo"
                color: Colors.text
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: true }
                Layout.bottomMargin: 2
            }

            // Scheidingslijn
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                Layout.bottomMargin: 2
            }

            // CPU
            _StatRow {
                icon:    ""
                label:   "CPU"
                value:   cpuPct.toFixed(0) + "%"
                pct:     cpuPct
                iconClr: Colors.blue
            }

            // RAM
            _StatRow {
                icon:    "󰍛"
                label:   "RAM"
                value:   ramUsed + " / " + ramTotal
                pct:     ramPct
                iconClr: Colors.mauve
            }

            // Disk
            _StatRow {
                icon:    "󰋊"
                label:   "Disk /"
                value:   diskUsed + " / " + diskTotal
                pct:     diskPct
                iconClr: Colors.peach
            }

            // Temperatuur
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                Text {
                    text:  ""
                    color: tempC > 80 ? Colors.red : tempC > 65 ? Colors.yellow : Colors.green
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                }
                Text {
                    text:  "Temp"
                    color: Colors.subtext0
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                    Layout.fillWidth: true
                }
                Text {
                    text:  tempC > 0 ? tempC.toFixed(0) + " °C" : "—"
                    color: tempC > 80 ? Colors.red : tempC > 65 ? Colors.yellow : Colors.text
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: true }
                }
            }

            // Netwerk
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                Text {
                    text:  "󰇚"
                    color: Colors.green
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                }
                Text {
                    text:  "Net ↓↑"
                    color: Colors.subtext0
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                    Layout.fillWidth: true
                }
                Text {
                    text:  rxRate + " / " + txRate
                    color: Colors.text
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: true }
                }
            }

            // Uptime
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                Text {
                    text:  "󱑀"
                    color: Colors.subtext0
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                }
                Text {
                    text:  "Uptime"
                    color: Colors.subtext0
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                    Layout.fillWidth: true
                }
                Text {
                    text:  uptimeStr
                    color: Colors.text
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: true }
                }
            }

            // Scheidingslijn voor btop-knop
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                Layout.topMargin:    2
                Layout.bottomMargin: 2
            }

            // btop knop
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 8
                color: btopHover.containsMouse
                       ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                       : "transparent"
                border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4); width: 1 }

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text:  " btop"
                    color: Colors.primary
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                }

                MouseArea {
                    id:          btopHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        btopProc.running = true
                        statsPopup.visible = false
                    }
                }
            }

            // Ondermarge
            Item { height: 2 }
        }
    }

    // ---------------------------------------------------------------------------
    // Data — lezers en parsers
    // ---------------------------------------------------------------------------

    property real cpuPct:   0
    property real ramPct:   0
    property string ramUsed:  "—"
    property string ramTotal: "—"
    property real diskPct:    0
    property string diskUsed:  "—"
    property string diskTotal: "—"
    property real tempC:      0
    property string rxRate: "—"
    property string txRate: "—"
    property string uptimeStr: "—"

    property var _prevCpu: null
    property var _prevNet: null

    // CPU
    FileView { id: cpuF; path: "/proc/stat";   onTextChanged: _parseCpu(text) }
    // RAM
    FileView { id: memF; path: "/proc/meminfo"; onTextChanged: _parseMem(text) }
    // Temperatuur (kernel thermal zone 0)
    FileView { id: tmpF; path: "/sys/class/thermal/thermal_zone0/temp"; onTextChanged: _parseTemp(text) }
    // Netwerk
    FileView { id: netF; path: "/proc/net/dev"; onTextChanged: _parseNet(text) }
    // Uptime
    FileView { id: upF;  path: "/proc/uptime";  onTextChanged: _parseUptime(text) }

    // Disk — via Process (df)
    Process {
        id: dfProc
        command: ["df", "-BM", "--output=size,used,avail", "/"]
        onExited: _parseDisk(stdout)
    }

    // btop — opent in kitty
    Process {
        id: btopProc
        command: ["kitty", "--title=btop", "btop"]
        running: false
    }

    // Prikkel alle bronnen elke 4 seconden (alleen als popup zichtbaar is)
    Timer {
        interval: 4000
        running:  statsPopup.visible
        repeat:   true
        onTriggered: _refreshAll()
    }

    onVisibleChanged: {
        if (visible) _refreshAll()
    }

    function _refreshAll() {
        cpuF.reload()
        memF.reload()
        tmpF.reload()
        netF.reload()
        upF.reload()
        dfProc.running = true
    }

    function _parseCpu(text) {
        const line  = text.split("\n")[0]
        const parts = line.split(/\s+/).slice(1).map(Number)
        const idle  = parts[3]
        const total = parts.reduce((a, b) => a + b, 0)
        if (_prevCpu) {
            const dIdle  = idle  - _prevCpu.idle
            const dTotal = total - _prevCpu.total
            cpuPct = dTotal > 0 ? Math.max(0, Math.min(100, (1 - dIdle / dTotal) * 100)) : 0
        }
        _prevCpu = { idle, total }
    }

    function _parseMem(text) {
        const vals = {}
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/)
            if (m) vals[m[1]] = parseInt(m[2])
        }
        const totalKb = vals["MemTotal"]     ?? 1
        const availKb = vals["MemAvailable"] ?? 0
        const usedKb  = totalKb - availKb
        ramPct   = (usedKb / totalKb) * 100
        ramUsed  = (usedKb  / 1048576).toFixed(1) + " GB"
        ramTotal = (totalKb / 1048576).toFixed(1) + " GB"
    }

    function _parseTemp(text) {
        const val = parseInt(text.trim())
        tempC = isNaN(val) ? 0 : val / 1000
    }

    function _parseNet(text) {
        // Kies de eerste niet-loopback interface met bytes > 0
        let rx = 0, tx = 0
        for (const line of text.split("\n")) {
            const m = line.match(/^\s*(\w+):\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/)
            if (!m || m[1] === "lo") continue
            rx += parseInt(m[2])
            tx += parseInt(m[3])
        }
        const now = Date.now()
        if (_prevNet) {
            const dt   = (now - _prevNet.ts) / 1000
            const rxBs = Math.max(0, (rx - _prevNet.rx) / dt)
            const txBs = Math.max(0, (tx - _prevNet.tx) / dt)
            rxRate = _fmtBps(rxBs)
            txRate = _fmtBps(txBs)
        }
        _prevNet = { rx, tx, ts: now }
    }

    function _fmtBps(bps) {
        if (bps < 1024)          return bps.toFixed(0) + " B/s"
        if (bps < 1048576)       return (bps / 1024).toFixed(0) + " KB/s"
        return (bps / 1048576).toFixed(1) + " MB/s"
    }

    function _parseUptime(text) {
        const secs = parseFloat(text.split(" ")[0])
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        uptimeStr = h > 0 ? h + "u " + m + "m" : m + "m"
    }

    function _parseDisk(text) {
        const lines = text.trim().split("\n")
        if (lines.length < 2) return
        const parts = lines[1].trim().split(/\s+/)
        const total = parseInt(parts[0])
        const used  = parseInt(parts[1])
        if (!total) return
        diskPct   = (used / total) * 100
        diskUsed  = used  > 1024 ? (used  / 1024).toFixed(0) + " GB" : used  + " MB"
        diskTotal = total > 1024 ? (total / 1024).toFixed(0) + " GB" : total + " MB"
    }

    // ---------------------------------------------------------------------------
    // Intern component — rij met label, waarde en voortgangsbalk
    // ---------------------------------------------------------------------------
    component _StatRow: ColumnLayout {
        property string icon:    ""
        property string label:   ""
        property string value:   ""
        property real   pct:     0
        property color  iconClr: Colors.blue

        Layout.fillWidth: true
        spacing: 3

        RowLayout {
            spacing: 6
            Layout.fillWidth: true

            Text {
                text:  icon
                color: iconClr
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
            }
            Text {
                text:  label
                color: Colors.subtext0
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                Layout.fillWidth: true
            }
            Text {
                text:  value
                color: pct > 85 ? Colors.red : pct > 65 ? Colors.yellow : Colors.text
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: true }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        // Voortgangsbalk
        Rectangle {
            Layout.fillWidth: true
            height: 3
            radius: 2
            color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.25)

            Rectangle {
                width:  parent.width * Math.min(1, pct / 100)
                height: parent.height
                radius: parent.radius
                color:  pct > 85 ? Colors.red : pct > 65 ? Colors.yellow : iconClr
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
}
