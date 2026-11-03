import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// Meldingen en rust: niet storen, nachtlicht en per app hoe hard een app
// mag roepen. Deze pagina draait in het instellingenproces en praat daarom
// via bestanden en notification_control.sh met de meldingendienst in de
// shell (die bestanden houdt NotificationService zelf in de gaten).
Item {
    id: root
    signal pageRequested(string page)
    property real unit: 1.0

    readonly property string home: Quickshell.env("HOME")
    readonly property string control: home + "/.config/quickshell/notifications/notification_control.sh"
    readonly property string rulesFile: home + "/.config/kingstra/notification-rules.json"
    readonly property string historyFile: home + "/.local/state/kingstra/notification-history.json"
    readonly property string dndFile: home + "/.local/state/kingstra/notification-dnd"
    readonly property string nightCmd: home + "/.local/bin/kingstra-nightlight"

    property bool dnd: false
    property var rules: ({})
    property var historyApps: []
    readonly property var apps: {
        let seen = {}, out = [];
        for (let a of historyApps) if (!seen[a]) { seen[a] = true; out.push(a); }
        for (let a in rules) if (!seen[a]) { seen[a] = true; out.push(a); }
        return out.sort((x, y) => x.localeCompare(y));
    }

    MatugenColors { id: pageColors }
    readonly property var c: pageColors

    function setDnd(on) {
        dnd = on;
        Quickshell.execDetached(["bash", control, on ? "dnd-on" : "dnd-off"]);
    }
    function ruleFor(app) {
        let r = rules[app];
        return ["stil", "nooit", "altijd"].indexOf(r) !== -1 ? r : "normaal";
    }
    function setRule(app, rule) {
        let next = Object.assign({}, rules);
        if (rule === "normaal") delete next[app]; else next[app] = rule;
        rules = next;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"",
            "sh", rulesFile, JSON.stringify(next)]);
    }

    FileView {
        path: root.dndFile
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.dnd = text().trim() === "1"
    }
    FileView {
        path: root.rulesFile
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text() || "{}");
                root.rules = (data && typeof data === "object" && !Array.isArray(data)) ? data : ({});
            } catch (e) { root.rules = ({}); }
        }
    }
    FileView {
        path: root.historyFile
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text() || "[]");
                root.historyApps = Array.isArray(data) ? data.map(h => String(h && h.app || "").trim()).filter(a => a !== "") : [];
            } catch (e) {}
        }
    }

    component Note: Text {
        Layout.fillWidth: true
        color: root.c.subtext0
        font.family: ThemeConfig.uiFont
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: body.implicitHeight + 24
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 16

            Text { text: "Meldingen en rust"; color: root.c.text; font.family: ThemeConfig.uiFont; font.pixelSize: 24; font.bold: true }
            Note { text: "Wanneer iets je mag storen, en hoe het scherm 's avonds aanvoelt." }

            SimpleCard {
                colors: root.c
                glyph: "󰂛"
                heading: "Niet storen"
                hint: "Meldingen komen stil binnen; je vindt ze in het meldingencentrum (Super+N)."
                SimpleSwitch {
                    colors: root.c
                    label: "Niet storen"
                    hint: "Dringende meldingen en apps op Altijd komen wel door."
                    checked: root.dnd
                    onToggled: (on) => root.setDnd(on)
                }
            }

            SimpleCard {
                colors: root.c
                glyph: NightLight.nightOn ? "󰖔" : "󰖙"
                heading: "Nachtlicht"
                hint: NightLight.available ? "Warmere kleuren in de avond. Nu: " + NightLight.subtitle.toLowerCase() + "."
                    : "Nachtlicht is nog niet geïnstalleerd; draai kingstra update."
                SimpleSwitch {
                    colors: root.c
                    label: "Nachtlicht nu"
                    hint: NightLight.scheduled ? "Met de hand schakelen geldt tot het volgende schemamoment." : ""
                    checked: NightLight.nightOn
                    allowed: NightLight.available
                    blockedReason: "Draai kingstra update om hyprsunset te installeren."
                    onToggled: NightLight.toggle()
                }
                SimpleSwitch {
                    colors: root.c
                    label: "Vanzelf volgens schema"
                    checked: NightLight.scheduled
                    allowed: NightLight.available
                    onToggled: (on) => NightLight.setScheduled(on)
                }
                SimpleChoice {
                    visible: NightLight.scheduled
                    colors: root.c
                    label: "Begint om"
                    options: [{id: "19:00", title: "19:00"}, {id: "20:00", title: "20:00"}, {id: "21:00", title: "21:00"}, {id: "22:00", title: "22:00"}, {id: "23:00", title: "23:00"}]
                    current: NightLight.startTime
                    allowed: NightLight.available
                    onPicked: (value) => Quickshell.execDetached([root.nightCmd, "set", "start", value])
                }
                SimpleChoice {
                    visible: NightLight.scheduled
                    colors: root.c
                    label: "Stopt om"
                    options: [{id: "05:00", title: "05:00"}, {id: "06:00", title: "06:00"}, {id: "07:00", title: "07:00"}, {id: "08:00", title: "08:00"}]
                    current: NightLight.endTime
                    allowed: NightLight.available
                    onPicked: (value) => Quickshell.execDetached([root.nightCmd, "set", "end", value])
                }
                SimpleChoice {
                    colors: root.c
                    label: "Hoe warm"
                    hint: "Het nachtlicht vloeit in twintig minuten in en uit."
                    options: [{id: "5000", title: "Licht"}, {id: "4000", title: "Middel"}, {id: "3200", title: "Sterk"}]
                    current: String(NightLight.warmth)
                    allowed: NightLight.available
                    onPicked: (value) => Quickshell.execDetached([root.nightCmd, "set", "temperature", value])
                }
            }

            SimpleCard {
                colors: root.c
                glyph: "󰂚"
                heading: "Meldingen per app"
                hint: root.apps.length === 0 ? "Zodra een app een melding stuurt, verschijnt hij hier."
                    : "Normaal: gewoon tonen. Stil: alleen in het centrum. Nooit: niet tonen. Altijd: ook bij niet storen."
                Repeater {
                    model: root.apps
                    delegate: RowLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            Layout.preferredWidth: 160
                            text: modelData
                            color: root.c.text
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        SimpleChoice {
                            colors: root.c
                            options: [{id: "normaal", title: "Normaal"}, {id: "stil", title: "Stil"}, {id: "nooit", title: "Nooit"}, {id: "altijd", title: "Altijd"}]
                            current: root.ruleFor(modelData)
                            onPicked: (value) => root.setRule(modelData, value)
                        }
                    }
                }
            }
        }
    }
}
