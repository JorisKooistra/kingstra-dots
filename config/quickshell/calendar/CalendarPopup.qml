import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// Agenda: klok, maand, lokale afspraken en het weer in één compact paneel.
// Links de maand, rechts de afspraken van de gekozen dag en de komende
// week; onderin het weer per dag met de uurverwachting. Afspraken zijn alleen
// lokaal (agenda_events.py) en zijn hier toe te voegen, te bewerken en te
// verwijderen.
Item {
    id: window

    readonly property int preferredPanelWidth: 920
    readonly property int preferredPanelHeight: 580

    MatugenColors { id: mocha }

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/calendar"
    readonly property var nl: Qt.locale("nl_NL")
    readonly property int cardRadius: Math.max(14, ThemeConfig.styleWidgetRadius + 2)
    readonly property int itemRadius: Math.max(10, ThemeConfig.styleWidgetRadius)
    readonly property color cardColor: mocha.shellRaisedFill
    readonly property color cardBorder: mocha.shellOutline
    readonly property color hoverColor: mocha.shellHoverFill

    // Kleur volgt het dagdeel, net als in de oude agenda.
    readonly property color timeAccent: {
        let h = currentTime.getHours();
        if (h >= 5 && h < 12) return mocha.yellow;
        if (h >= 12 && h < 17) return mocha.teal;
        if (h >= 17 && h < 21) return mocha.pink;
        return mocha.mauve;
    }

    // --- Openen ---------------------------------------------------------------
    property real intro: 0
    NumberAnimation on intro {
        from: 0; to: 1
        duration: ThemeConfig.durationToken("medium")
        easing.type: ThemeConfig.easingToken("emphasized")
    }

    // --- Tijd -------------------------------------------------------------------
    property var currentTime: new Date()
    readonly property string todayKey: Qt.formatDate(currentTime, "yyyy-MM-dd")
    // Verandert alleen bij een nieuwe dag, zodat de maand niet elke seconde
    // opnieuw wordt opgebouwd.
    property var todayDate: new Date()
    onTodayKeyChanged: todayDate = new Date()
    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            let previousKey = window.todayKey;
            window.currentTime = new Date();
            window.secondPulse = 1.06;
            pulseReset.start();
            // Na middernacht schuift "vandaag" mee als die geselecteerd was.
            if (window.selectedDateKey === previousKey && window.todayKey !== previousKey)
                window.selectedDateKey = window.todayKey;
        }
    }

    function dateFromKey(key) {
        return new Date(String(key) + "T12:00:00");
    }

    function dayLabel(key) {
        if (key === todayKey) return "Vandaag";
        let tomorrow = new Date(todayDate.getFullYear(), todayDate.getMonth(), todayDate.getDate() + 1);
        if (key === Qt.formatDate(tomorrow, "yyyy-MM-dd")) return "Morgen";
        let label = dateFromKey(key).toLocaleDateString(nl, "dddd d MMMM");
        return label.charAt(0).toUpperCase() + label.slice(1);
    }

    function shortDayLabel(key) {
        if (key === todayKey) return "Vandaag";
        return dateFromKey(key).toLocaleDateString(nl, "ddd d MMM");
    }

    // --- Lokale afspraken -------------------------------------------------------
    property var events: []
    property string selectedDateKey: todayKey
    property bool formOpen: false
    property string editingId: ""

    readonly property var eventCounts: {
        let map = {};
        for (let i = 0; i < events.length; i++) {
            let key = String(events[i].dateKey || "");
            map[key] = (map[key] || 0) + 1;
        }
        return map;
    }
    readonly property var selectedEvents: events.filter(ev => ev.dateKey === selectedDateKey)
    // De komende zeven dagen na de gekozen dag, zodat je vooruit kijkt.
    readonly property var upcomingEvents: {
        let start = dateFromKey(selectedDateKey);
        let end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 7);
        let endKey = Qt.formatDate(end, "yyyy-MM-dd");
        return events.filter(ev => ev.dateKey > selectedDateKey && ev.dateKey <= endKey);
    }

    function applyEventsJson(text) {
        let txt = String(text || "").trim();
        if (txt === "") return;
        try {
            let data = JSON.parse(txt);
            window.events = Array.isArray(data.events) ? data.events : [];
        } catch (e) {}
    }

    Process {
        id: listProc
        command: ["python3", window.scriptsDir + "/agenda_events.py", "list"]
        running: true
        stdout: StdioCollector { onStreamFinished: window.applyEventsJson(this.text) }
    }

    Process {
        id: actionProc
        property var args: []
        command: ["python3", window.scriptsDir + "/agenda_events.py"].concat(args)
        stdout: StdioCollector { onStreamFinished: window.applyEventsJson(this.text) }
    }

    Timer {
        interval: 45000; running: true; repeat: true
        onTriggered: if (!listProc.running) listProc.running = true
    }

    function runAction(args) {
        if (actionProc.running) actionProc.running = false;
        actionProc.args = args;
        actionProc.running = true;
    }

    function normalizedTime(value) {
        let text = String(value || "").trim();
        if (text === "") return "";
        let match = text.match(/^([0-2]?[0-9])(?:[:.]?([0-5][0-9]))?$/);
        if (!match) return "";
        let h = Math.min(23, parseInt(match[1], 10));
        let m = match[2] ? parseInt(match[2], 10) : 0;
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    function openNewForm() {
        editingId = "";
        titleInput.text = "";
        timeInput.text = "";
        formOpen = true;
        Qt.callLater(() => titleInput.forceActiveFocus());
    }

    function openEditForm(ev) {
        editingId = String(ev.id || "");
        selectedDateKey = String(ev.dateKey || selectedDateKey);
        titleInput.text = String(ev.title || "");
        timeInput.text = String(ev.timeRaw || "");
        formOpen = true;
        Qt.callLater(() => titleInput.forceActiveFocus());
    }

    function closeForm() {
        formOpen = false;
        editingId = "";
    }

    function saveForm() {
        let title = titleInput.text.trim().replace(/\s+/g, " ");
        if (title === "") return;
        let time = normalizedTime(timeInput.text);
        if (editingId !== "")
            runAction(["update", editingId, selectedDateKey, time, title]);
        else
            runAction(["add", "", selectedDateKey, time, title]);
        closeForm();
    }

    function deleteEvent(ev) {
        if (String(ev.id || "") === "") return;
        if (editingId === ev.id) closeForm();
        runAction(["delete", String(ev.id)]);
    }

    // --- Maand ------------------------------------------------------------------
    property int monthOffset: 0
    property real monthShift: 0
    property real monthOpacity: 1
    property int monthDirection: 1
    property int pendingOffset: 0

    readonly property var monthDate: new Date(todayDate.getFullYear(), todayDate.getMonth() + monthOffset, 1)
    readonly property string monthTitle: {
        let t = monthDate.toLocaleDateString(nl, "MMMM yyyy");
        return t.charAt(0).toUpperCase() + t.slice(1);
    }
    readonly property var monthCells: {
        let year = monthDate.getFullYear();
        let month = monthDate.getMonth();
        let firstDow = (new Date(year, month, 1).getDay() + 6) % 7;
        let cells = [];
        for (let i = 0; i < 42; i++) {
            let d = new Date(year, month, 1 - firstDow + i);
            let key = Qt.formatDate(d, "yyyy-MM-dd");
            cells.push({
                key: key,
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                count: eventCounts[key] || 0
            });
        }
        return cells;
    }

    SequentialAnimation {
        id: monthAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "monthOpacity"; to: 0; duration: 140; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "monthShift"; to: -18 * window.monthDirection; duration: 140; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.pendingOffset;
                window.monthShift = 18 * window.monthDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "monthOpacity"; to: 1; duration: 260; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "monthShift"; to: 0; duration: 260; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(offset) {
        if (offset === pendingOffset && (monthAnim.running || offset === monthOffset)) return;
        if (monthAnim.running) {
            monthAnim.stop();
            monthOffset = pendingOffset;
        }
        monthDirection = offset > monthOffset ? 1 : -1;
        pendingOffset = offset;
        monthAnim.start();
    }

    function goToday() {
        selectedDateKey = todayKey;
        setMonthOffset(0);
    }

    function selectCell(cell) {
        selectedDateKey = cell.key;
        if (!cell.inMonth) {
            let d = dateFromKey(cell.key);
            let offset = (d.getFullYear() - todayDate.getFullYear()) * 12 + d.getMonth() - todayDate.getMonth();
            setMonthOffset(offset);
        }
    }

    Shortcut {
        sequence: "Left"
        enabled: !window.formOpen
        onActivated: window.setMonthOffset(window.pendingOffset - 1)
    }
    Shortcut {
        sequence: "Right"
        enabled: !window.formOpen
        onActivated: window.setMonthOffset(window.pendingOffset + 1)
    }

    // --- Weer -------------------------------------------------------------------
    property var weatherData: null
    property int weatherDay: 0
    property real weatherOpacity: 1
    property real weatherShift: 0
    property int pendingWeatherDay: 0
    property int weatherDirection: 1

    readonly property var forecast: weatherData && Array.isArray(weatherData.forecast) ? weatherData.forecast : []
    // Zonder API-sleutel levert weather.sh nullen; dan tonen we geen weer.
    readonly property bool hasWeather: forecast.length > 0
        && String(forecast[0].desc || "") !== "No API Key"
        && !(Number(forecast[0].max) === 0 && Number(forecast[0].min) === 0 && String(forecast[0].icon || "") === "")
    readonly property var dayWeather: hasWeather && forecast[weatherDay] ? forecast[weatherDay] : null
    readonly property var hourly: dayWeather && Array.isArray(dayWeather.hourly) ? dayWeather.hourly.slice(0, 8) : []

    function weatherDayName(index) {
        if (index === 0) return "Vandaag";
        let d = new Date(todayDate.getFullYear(), todayDate.getMonth(), todayDate.getDate() + index);
        return d.toLocaleDateString(nl, "ddd");
    }

    function roundTemp(value) {
        let n = Number(value);
        return isNaN(n) ? "--" : Math.round(n) + "°";
    }

    function weatherColor(entry) {
        try { return entry && entry.hex ? Qt.color(entry.hex) : mocha.text; } catch (e) { return mocha.text; }
    }

    SequentialAnimation {
        id: weatherAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherOpacity"; to: 0; duration: 140; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherShift"; to: -16 * window.weatherDirection; duration: 140; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.weatherDay = window.pendingWeatherDay;
                window.weatherShift = 16 * window.weatherDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherOpacity"; to: 1; duration: 260; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherShift"; to: 0; duration: 260; easing.type: Easing.OutQuart }
        }
    }

    function setWeatherDay(index) {
        if (index < 0 || index >= forecast.length || index === pendingWeatherDay) return;
        if (weatherAnim.running) {
            weatherAnim.stop();
            weatherDay = pendingWeatherDay;
        }
        weatherDirection = index > weatherDay ? 1 : -1;
        pendingWeatherDay = index;
        weatherAnim.start();
    }

    Process {
        id: weatherProc
        command: ["bash", window.scriptsDir + "/weather.sh", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try { window.weatherData = JSON.parse(txt); } catch (e) {}
            }
        }
    }

    Timer {
        interval: 150000; running: true; repeat: true
        onTriggered: if (!weatherProc.running) weatherProc.running = true
    }

    // =========================================================================
    // INDELING
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        opacity: window.intro
        scale: 0.97 + 0.03 * window.intro
        transform: Translate { y: 10 * (1 - window.intro) }

        // --- Klok en datum ----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Row {
                spacing: 2
                Text {
                    text: Qt.formatTime(window.currentTime, "HH:mm")
                    font.family: ThemeConfig.displayFont
                    font.weight: Font.Black
                    font.pixelSize: 44
                    color: mocha.text
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: Qt.formatTime(window.currentTime, ":ss")
                    font.family: ThemeConfig.monoFont
                    font.weight: Font.Bold
                    font.pixelSize: 18
                    color: window.timeAccent
                    opacity: window.secondPulse > 1.02 ? 1.0 : 0.6
                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(1000) } }
                }
            }

            ColumnLayout {
                spacing: 0
                Text {
                    text: {
                        let t = window.currentTime.toLocaleDateString(window.nl, "dddd");
                        return t.charAt(0).toUpperCase() + t.slice(1);
                    }
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: mocha.primary
                }
                Text {
                    text: window.currentTime.toLocaleDateString(window.nl, "d MMMM yyyy") + "  ·  week " + window.isoWeek(window.currentTime)
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }
            }

            Item { Layout.fillWidth: true }

            // Weer nu
            RowLayout {
                visible: window.hasWeather
                spacing: 8
                Text {
                    text: window.hasWeather ? String(window.forecast[0].icon || "") : ""
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 26
                    color: window.hasWeather ? window.weatherColor(window.forecast[0]) : mocha.text
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: window.hasWeather ? window.roundTemp(window.forecast[0].max) : ""
                        font.family: ThemeConfig.displayFont
                        font.weight: Font.Bold
                        font.pixelSize: 18
                        color: mocha.text
                    }
                    Text {
                        text: window.hasWeather ? String(window.forecast[0].desc || "") : ""
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 10
                        color: mocha.subtext0
                    }
                }
            }
        }

        // --- Maand en afspraken ----------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Card {
                id: monthCard
                Layout.preferredWidth: 320
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RoundButton { icon: "󰅁"; onTriggered: window.setMonthOffset(window.pendingOffset - 1) }
                        Text {
                            Layout.fillWidth: true
                            text: window.monthTitle
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: mocha.text
                            opacity: window.monthOpacity
                        }
                        RoundButton { icon: "󰅂"; onTriggered: window.setMonthOffset(window.pendingOffset + 1) }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 2
                        rowSpacing: 0
                        Repeater {
                            model: ["ma", "di", "wo", "do", "vr", "za", "zo"]
                            delegate: Text {
                                required property string modelData
                                Layout.fillWidth: true
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 10
                                color: mocha.subtext0
                            }
                        }
                    }

                    GridLayout {
                        id: monthGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        columnSpacing: 2
                        rowSpacing: 2
                        opacity: window.monthOpacity
                        transform: Translate { x: window.monthShift }

                        Repeater {
                            model: window.monthCells
                            delegate: Rectangle {
                                id: cell
                                required property var modelData
                                readonly property bool isToday: modelData.key === window.todayKey
                                readonly property bool isSelected: modelData.key === window.selectedDateKey
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: height / 2
                                color: isToday ? window.timeAccent
                                    : (isSelected ? Qt.alpha(window.timeAccent, 0.20)
                                        : (cellMouse.containsMouse ? window.hoverColor : "transparent"))
                                border.width: isSelected && !isToday ? 1 : 0
                                border.color: Qt.alpha(window.timeAccent, 0.6)
                                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: cell.modelData.count > 0 ? -2 : 0
                                    text: cell.modelData.day
                                    font.family: ThemeConfig.monoFont
                                    font.pixelSize: 12
                                    font.weight: cell.isToday || cell.isSelected ? Font.Black : Font.Normal
                                    color: cell.isToday ? mocha.base : (cell.modelData.inMonth ? mocha.text : mocha.overlay0)
                                }
                                Rectangle {
                                    visible: cell.modelData.count > 0
                                    width: 4; height: 4; radius: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    color: cell.isToday ? mocha.base : window.timeAccent
                                }
                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.selectCell(cell.modelData)
                                    onDoubleClicked: { window.selectCell(cell.modelData); window.openNewForm(); }
                                }
                            }
                        }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: (event) => {
                                if (event.angleDelta.y === 0) return;
                                window.setMonthOffset(window.pendingOffset + (event.angleDelta.y < 0 ? 1 : -1));
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: window.selectedDateKey !== window.todayKey || window.monthOffset !== 0
                        Item { Layout.fillWidth: true }
                        PillButton { label: "Vandaag"; icon: "󰃶"; onTriggered: window.goToday() }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "󰃰"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 16
                            color: window.timeAccent
                        }
                        Text {
                            Layout.fillWidth: true
                            text: window.dayLabel(window.selectedDateKey)
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: mocha.text
                            elide: Text.ElideRight
                        }
                        PillButton {
                            label: window.formOpen ? "Annuleren" : "Afspraak"
                            icon: window.formOpen ? "󰅖" : "󰐕"
                            accent: window.timeAccent
                            onTriggered: window.formOpen ? window.closeForm() : window.openNewForm()
                        }
                    }

                    // Formulier: nieuw of bewerken. Tijd leeg = hele dag.
                    Rectangle {
                        Layout.fillWidth: true
                        property real openHeight: window.formOpen ? 44 : 0
                        Layout.preferredHeight: openHeight
                        visible: openHeight > 1
                        clip: true
                        radius: 22
                        color: Qt.alpha(window.timeAccent, 0.08)
                        border.width: 1
                        border.color: Qt.alpha(window.timeAccent, 0.45)
                        Behavior on openHeight {
                            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 6
                            spacing: 8

                            TextInput {
                                id: titleInput
                                Layout.fillWidth: true
                                color: mocha.text
                                selectionColor: Qt.alpha(window.timeAccent, 0.34)
                                selectedTextColor: mocha.base
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 12
                                clip: true
                                onAccepted: window.saveForm()
                                Keys.onEscapePressed: (event) => { window.closeForm(); event.accepted = true; }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: titleInput.text === ""
                                    text: window.editingId !== "" ? "Titel" : "Nieuwe afspraak op " + window.shortDayLabel(window.selectedDateKey)
                                    font: titleInput.font
                                    color: mocha.subtext0
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 30
                                radius: 15
                                color: Qt.alpha(mocha.text, 0.06)
                                TextInput {
                                    id: timeInput
                                    anchors.fill: parent
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: mocha.text
                                    font.family: ThemeConfig.monoFont
                                    font.pixelSize: 12
                                    maximumLength: 5
                                    onAccepted: window.saveForm()
                                    Keys.onEscapePressed: (event) => { window.closeForm(); event.accepted = true; }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: timeInput.text === ""
                                        text: "hele dag"
                                        font.family: ThemeConfig.uiFont
                                        font.pixelSize: 10
                                        color: mocha.overlay0
                                    }
                                }
                            }

                            RoundButton {
                                icon: "󰄬"
                                accent: mocha.green
                                filled: true
                                onTriggered: window.saveForm()
                            }
                        }
                    }

                    // Afspraken van de gekozen dag, daarna de week erna.
                    Flickable {
                        id: agendaList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: agendaColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: agendaColumn
                            width: agendaList.width
                            spacing: 6

                            Text {
                                visible: window.selectedEvents.length === 0
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4
                                text: "Niets gepland. Dubbelklik op een dag of gebruik + Afspraak."
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                color: mocha.subtext0
                                wrapMode: Text.WordWrap
                            }

                            Repeater {
                                model: window.selectedEvents
                                delegate: EventRow {
                                    required property var modelData
                                    event: modelData
                                    showDay: false
                                }
                            }

                            Text {
                                visible: window.upcomingEvents.length > 0
                                Layout.topMargin: 8
                                text: "Komende week"
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: mocha.subtext1
                            }

                            Repeater {
                                model: window.upcomingEvents
                                delegate: EventRow {
                                    required property var modelData
                                    event: modelData
                                    showDay: true
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Weer -----------------------------------------------------------
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: window.hasWeather ? 150 : 46

            Text {
                visible: !window.hasWeather
                anchors.centerIn: parent
                text: "Geen weergegevens. Vul een API-sleutel in bij Instellingen › Tijd & weer."
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                color: mocha.subtext0
            }

            RowLayout {
                visible: window.hasWeather
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                // Dagkeuze
                // Vaste breedte: de dagknoppen vullen deze kolom, en zonder
                // vaste maat erft de kolom hun fillWidth en duwt hij de
                // uurverwachting rechts weg tot alles over elkaar staat.
                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 330
                    Layout.minimumWidth: 330
                    Layout.maximumWidth: 330
                    Layout.fillHeight: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: Math.min(5, window.forecast.length)
                            delegate: Rectangle {
                                id: dayPill
                                required property int index
                                readonly property var entry: window.forecast[index]
                                readonly property bool active: index === window.pendingWeatherDay
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 76
                                radius: 26
                                color: active ? Qt.alpha(window.weatherColor(entry), 0.18)
                                    : (dayMouse.containsMouse ? window.hoverColor : Qt.alpha(mocha.text, 0.04))
                                border.width: active ? 1 : 0
                                border.color: Qt.alpha(window.weatherColor(entry), 0.55)
                                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: window.weatherDayName(dayPill.index)
                                        font.family: ThemeConfig.uiFont
                                        font.pixelSize: 10
                                        font.weight: dayPill.active ? Font.Bold : Font.Normal
                                        color: dayPill.active ? mocha.text : mocha.subtext0
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: String(dayPill.entry.icon || "")
                                        font.family: ThemeConfig.iconFont
                                        font.pixelSize: 18
                                        color: window.weatherColor(dayPill.entry)
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: window.roundTemp(dayPill.entry.max) + " " + window.roundTemp(dayPill.entry.min)
                                        font.family: ThemeConfig.monoFont
                                        font.pixelSize: 9
                                        color: mocha.subtext1
                                    }
                                }
                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.setWeatherDay(dayPill.index)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.dayWeather ? String(window.dayWeather.desc || "") : ""
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 11
                        color: mocha.subtext0
                        elide: Text.ElideRight
                        opacity: window.weatherOpacity
                    }
                }

                // Details en uurverwachting van de gekozen dag
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 420
                    Layout.fillHeight: true
                    spacing: 8
                    opacity: window.weatherOpacity
                    transform: Translate { x: window.weatherShift }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        StatChip { icon: "󰔏"; label: "Gevoel"; value: window.dayWeather ? window.roundTemp(window.dayWeather.feels_like) : "--" }
                        StatChip { icon: "󰖝"; label: "Wind"; value: window.dayWeather ? String(window.dayWeather.wind || "0") + " km/u" : "--" }
                        StatChip { icon: "󰖎"; label: "Vocht"; value: window.dayWeather ? String(window.dayWeather.humidity || "0") + "%" : "--" }
                        StatChip { icon: "󰖗"; label: "Regen"; value: window.dayWeather ? String(window.dayWeather.pop || "0") + "%" : "--" }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        Repeater {
                            model: window.hourly
                            delegate: Rectangle {
                                id: hourPill
                                required property var modelData
                                readonly property bool isNow: window.weatherDay === 0
                                    && parseInt(String(modelData.time || "0").split(":")[0]) === window.currentTime.getHours()
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                radius: width / 2 > 22 ? 22 : width / 2
                                color: isNow ? window.timeAccent : Qt.alpha(mocha.text, 0.05)
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: String(hourPill.modelData.time || "")
                                        font.family: ThemeConfig.monoFont
                                        font.pixelSize: 9
                                        color: hourPill.isNow ? mocha.base : mocha.subtext0
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: String(hourPill.modelData.icon || "")
                                        font.family: ThemeConfig.iconFont
                                        font.pixelSize: 14
                                        color: hourPill.isNow ? mocha.base : window.weatherColor(hourPill.modelData)
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: window.roundTemp(hourPill.modelData.temp)
                                        font.family: ThemeConfig.monoFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: hourPill.isNow ? mocha.base : mocha.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function isoWeek(date) {
        let d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        let day = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - day);
        let yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

    // =========================================================================
    // COMPONENTEN
    // =========================================================================
    component Card: Rectangle {
        radius: window.cardRadius
        color: window.cardColor
        border.width: 1
        border.color: window.cardBorder
        clip: true
    }

    component RoundButton: Rectangle {
        id: roundButton
        property string icon: ""
        property color accent: mocha.text
        property bool filled: false
        signal triggered()
        implicitWidth: 30
        implicitHeight: 30
        radius: 15
        color: filled ? Qt.alpha(accent, roundMouse.containsMouse ? 0.30 : 0.18)
            : (roundMouse.containsMouse ? window.hoverColor : "transparent")
        scale: roundMouse.pressed ? 0.92 : 1.0
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
        Text {
            anchors.centerIn: parent
            text: roundButton.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 14
            color: roundButton.accent
        }
        MouseArea {
            id: roundMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: roundButton.triggered()
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property color accent: mocha.primary
        signal triggered()
        implicitHeight: 28
        implicitWidth: pillRow.implicitWidth + 22
        radius: 14
        color: Qt.alpha(accent, pillMouse.containsMouse ? 0.24 : 0.12)
        border.width: 1
        border.color: Qt.alpha(accent, pillMouse.containsMouse ? 0.55 : 0.30)
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 12
                color: pill.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: Font.Bold
                color: mocha.text
            }
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.triggered()
        }
    }

    component StatChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 15
        color: Qt.alpha(mocha.text, 0.05)
        Row {
            anchors.centerIn: parent
            spacing: 5
            Text { anchors.verticalCenter: parent.verticalCenter; text: chip.icon; font.family: ThemeConfig.iconFont; font.pixelSize: 12; color: window.timeAccent }
            Text { anchors.verticalCenter: parent.verticalCenter; text: chip.label; font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: chip.value; font.family: ThemeConfig.monoFont; font.pixelSize: 10; font.weight: Font.Bold; color: mocha.text }
        }
    }

    // Eén afspraak: tijd als ronde pil, titel, en bij hover bewerken/weg.
    component EventRow: Rectangle {
        id: row
        property var event: ({})
        property bool showDay: false
        readonly property bool editing: window.formOpen && window.editingId === String(event.id || "")
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 20
        color: editing ? Qt.alpha(window.timeAccent, 0.14) : (rowHover.hovered ? window.hoverColor : Qt.alpha(mocha.text, 0.04))
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

        HoverHandler { id: rowHover }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 28
                radius: 14
                color: Qt.alpha(window.timeAccent, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: row.event.allDay ? "hele dag" : String(row.event.timeRaw || row.event.time || "")
                    font.family: row.event.allDay ? ThemeConfig.uiFont : ThemeConfig.monoFont
                    font.pixelSize: row.event.allDay ? 10 : 11
                    font.weight: Font.Bold
                    color: window.timeAccent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: String(row.event.title || "(Geen titel)")
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    visible: row.showDay
                    Layout.fillWidth: true
                    text: window.dayLabel(String(row.event.dateKey || ""))
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            Row {
                spacing: 2
                opacity: rowHover.hovered || row.editing ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }
                RoundButton { icon: "󰏫"; accent: mocha.subtext1; onTriggered: window.openEditForm(row.event) }
                RoundButton { icon: "󰆴"; accent: mocha.red; onTriggered: window.deleteEvent(row.event) }
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onDoubleTapped: window.openEditForm(row.event)
        }
    }
}
