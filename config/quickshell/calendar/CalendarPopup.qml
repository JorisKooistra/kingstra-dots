import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"

Item {
    id: window

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        // Uses the physical screen width so the popup scales synchronously
        currentWidth: Screen.width
    }
    
    // Helper function scoped to the root Item for easy access
    function s(val) { 
        return scaler.s(val); 
    }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // (Escape is handled by Main.qml now)
    // -------------------------------------------------------------------------
    Shortcut { 
        sequence: "Left"
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut { 
        sequence: "Right"
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

  
    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext1: _theme.subtext1
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay2: _theme.overlay1
    readonly property color overlay1: _theme.overlay1
    readonly property color overlay0: _theme.overlay0
    readonly property color surface2: _theme.surface2
    readonly property color surface1: _theme.surface1
    readonly property color surface0: _theme.surface0
    
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color teal: _theme.teal
    readonly property color green: _theme.green
    readonly property color red: _theme.red
    readonly property color accent1: _theme.accent1
    readonly property color accent2: _theme.accent2
    readonly property color accent3: _theme.accent3
    readonly property int themedRadius: window.s(Math.max(14, ThemeConfig.styleWidgetRadius))
    readonly property int themedInnerRadius: window.s(Math.max(10, ThemeConfig.styleWidgetRadius - 4))
    readonly property string uiFontFamily: ThemeConfig.uiFont
    readonly property string monoFontFamily: ThemeConfig.monoFont
    readonly property string displayFontFamily: ThemeConfig.displayFont
    readonly property real themedLetterSpacing: ThemeConfig.letterSpacing
    readonly property int themedFontWeight: ThemeConfig.fontWeight
    readonly property color popupFill: Qt.rgba(window.base.r, window.base.g, window.base.b, ThemeConfig.popupOpacity)

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/calendar"

    // -------------------------------------------------------------------------
    // TIME OF DAY DYNAMIC COLORS
    // -------------------------------------------------------------------------
    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.peach;      // Morning
        if (h >= 12 && h < 17) return window.sapphire;  // Afternoon
        if (h >= 17 && h < 21) return window.mauve;     // Evening
        return window.blue;                             // Night
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.yellow;     // Morning Accent
        if (h >= 12 && h < 17) return window.teal;      // Afternoon Accent
        if (h >= 17 && h < 21) return window.pink;      // Evening Accent
        return window.mauve;                            // Night Accent
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(window.text, 0.35))

    // -------------------------------------------------------------------------
    // STARTUP ANIMATION STATES
    // -------------------------------------------------------------------------
    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    SequentialAnimation {
        running: true
        
        // 50ms buffer to allow the window manager to map the surface before animating
        PauseAnimation { duration: 20 }

        ParallelAnimation {
            // Base window fades and scales slightly
            NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }

            // Ambient background glows and big parallax icon fade in
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: 1000; easing.type: Easing.OutSine }
            }

            // Central clock and 3D orbital pop from the center
            SequentialAnimation {
                PauseAnimation { duration: 250 }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            // Left wing (Calendar) slides in from the left
            SequentialAnimation {
                PauseAnimation { duration: 350 }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }

            // Right wing (Weather) slides in from the right
            SequentialAnimation {
                PauseAnimation { duration: 400 }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: window; property: "introMain"; to: 0; duration: 400; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introAmbient"; to: 0; duration: 250; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introClock"; to: 0; duration: 300; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introCalendar"; to: 0; duration: 350; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introWeather"; to: 0; duration: 350; easing.type: Easing.InQuart }
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // -------------------------------------------------------------------------
    // STATE & TIME (WITH SECOND PULSE)
    // -------------------------------------------------------------------------
    property var currentTime: new Date()
    property real currentEpoch: currentTime.getTime() / 1000
    
    property real secondPulse: 1.0
    NumberAnimation on secondPulse { 
        id: pulseReset 
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false 
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            window.currentTime = new Date();
            window.secondPulse = 1.06; // Gentle pulse
            pulseReset.start();        
            
            if (window.currentTime.getHours() === 0 && window.currentTime.getMinutes() === 0 && window.currentTime.getSeconds() === 0) {
                updateCalendarGrid();
            }
        }
    }

    // -------------------------------------------------------------------------
    // WEATHER DATA & ELEGANT TRANSITIONS (3D ORBIT SPIN)
    // -------------------------------------------------------------------------
    property var weatherData: null
    property int weatherView: 0
    property color activeWeatherHex: weatherData && weatherData.forecast && weatherData.forecast[weatherView] ? weatherData.forecast[weatherView].hex : window.mauve

    // Transition Properties
    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1
    
    // New 3D Spin Properties
    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    // -------------------------------------------------------------------------
    // TEMPERATURE LOGIC 
    // -------------------------------------------------------------------------
    property real targetTemp: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? Number(window.weatherData.forecast[window.targetWeatherView].max) : 0
    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        
        // If the target is higher than the currently ticking number, we are counting up
        if (window.targetTemp > window.displayedTemp) return window.red;
        
        // If the target is lower than the currently ticking number, we are counting down
        if (window.targetTemp < window.displayedTemp) return window.blue;
        
        return window.text; 
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: window.s(-40) * weatherAnimDirection; duration: 250; easing.type: Easing.InSine }
            
            // Spin the 3D orbit out and scale it down for depth
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: 300; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction { 
            script: { 
                window.weatherView = window.targetWeatherView; 
                window.weatherContentOffset = window.s(40) * weatherAnimDirection; // Move to opposite side while hidden
                
                // Reset the spin to the opposite side so it continues spinning into place seamlessly
                window.transitionSpin = -180 * weatherAnimDirection;
            } 
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: 450; easing.type: Easing.OutQuart }
            
            // Snap the 3D orbit back to 0 degrees and restore full scale
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || !window.weatherData) return;
        if (idx === window.targetWeatherView) return; // Ignore if we are already heading there

        // If an animation is already running, gracefully interrupt it and apply the logical switch
        // before starting the new animation so the data doesn't get desynced.
        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
        }

        window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;
        
        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;
        
        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let h = parseInt(timeStr.split(":")[0]);
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    Process {
        id: weatherPoller
        command: ["bash", window.scriptsDir + "/weather.sh", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { window.weatherData = JSON.parse(txt); } catch(e) {}
                }
            }
        }
    }

    property var thunderbirdCalendarData: ({})
    property var thunderbirdCalendars: []
    property var thunderbirdEvents: []
    property var localAgendaEvents: []
    property string selectedDateKey: Qt.formatDateTime(window.currentTime, "yyyy-MM-dd")
    property bool addEventOpen: false

    Process {
        id: thunderbirdCalendarPoller
        command: ["python3", window.scriptsDir + "/thunderbird_calendar_status.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    let data = JSON.parse(txt);
                    window.thunderbirdCalendarData = data;
                    window.thunderbirdCalendars = Array.isArray(data.calendars) ? data.calendars : [];
                    window.thunderbirdEvents = Array.isArray(data.events) ? data.events : [];
                    window.updateCalendarGrid();
                } catch (e) {
                    window.thunderbirdCalendarData = ({});
                    window.thunderbirdCalendars = [];
                    window.thunderbirdEvents = [];
                    window.updateCalendarGrid();
                }
            }
        }
    }

    Process {
        id: localAgendaPoller
        command: ["python3", window.scriptsDir + "/agenda_events.py", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: window.applyLocalAgendaJson(this.text)
        }
    }

    Process {
        id: localAgendaAction
        property string action: "list"
        property string eventId: ""
        property string eventDate: ""
        property string eventTime: ""
        property string eventTitle: ""
        command: ["python3", window.scriptsDir + "/agenda_events.py", action, eventId, eventDate, eventTime, eventTitle]
        stdout: StdioCollector {
            onStreamFinished: window.applyLocalAgendaJson(this.text)
        }
    }

    Timer {
        interval: 150000 
        running: true; repeat: true
        onTriggered: weatherPoller.running = true
    }

    Timer {
        interval: 90000
        running: true; repeat: true
        onTriggered: if (!thunderbirdCalendarPoller.running) thunderbirdCalendarPoller.running = true
    }

    Timer {
        interval: 45000
        running: true; repeat: true
        onTriggered: if (!localAgendaPoller.running) localAgendaPoller.running = true
    }

    // -------------------------------------------------------------------------
    // CALENDAR GRID LOGIC & TRANSITIONS
    // -------------------------------------------------------------------------
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: window.s(-20) * calendarAnimDirection; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = window.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 350; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 350; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1); 
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();
        
        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        window.targetMonthName = Qt.formatDateTime(d, "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1; 

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            let day = daysInPrevMonth - i;
            let date = new Date(targetYear, targetMonth - 1, day);
            let key = Qt.formatDateTime(date, "yyyy-MM-dd");
            calendarModel.append({ dayNum: day.toString(), dateKey: key, isCurrentMonth: false, isToday: false, eventCount: window.eventCountForDate(key) });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            let date = new Date(targetYear, targetMonth, i);
            let key = Qt.formatDateTime(date, "yyyy-MM-dd");
            calendarModel.append({ dayNum: i.toString(), dateKey: key, isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate), eventCount: window.eventCountForDate(key) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            let date = new Date(targetYear, targetMonth + 1, i);
            let key = Qt.formatDateTime(date, "yyyy-MM-dd");
            calendarModel.append({ dayNum: i.toString(), dateKey: key, isCurrentMonth: false, isToday: false, eventCount: window.eventCountForDate(key) });
        }
    }

    function eventCountForDate(dateKey) {
        let count = 0;
        let events = combinedAgendaEvents();
        for (let i = 0; i < events.length; i++) {
            if (String(events[i].dateKey || "") === dateKey)
                count += 1;
        }
        return count;
    }

    function eventsForDate(dateKey) {
        let out = [];
        let events = combinedAgendaEvents();
        for (let i = 0; i < events.length; i++) {
            let ev = events[i] || {};
            if (String(ev.dateKey || "") === dateKey)
                out.push(ev);
        }
        return out;
    }

    function upcomingEvents(limit) {
        return combinedAgendaEvents().slice(0, limit);
    }

    function combinedAgendaEvents() {
        let out = [];
        for (let i = 0; i < thunderbirdEvents.length; i++) out.push(thunderbirdEvents[i]);
        for (let j = 0; j < localAgendaEvents.length; j++) out.push(localAgendaEvents[j]);
        out.sort((a, b) => {
            let ad = String((a && a.dateKey) || "");
            let bd = String((b && b.dateKey) || "");
            if (ad !== bd) return ad.localeCompare(bd);
            let at = String((a && a.timeRaw) || ((a && a.allDay) ? "" : a.time) || "99:99");
            let bt = String((b && b.timeRaw) || ((b && b.allDay) ? "" : b.time) || "99:99");
            if (at !== bt) return at.localeCompare(bt);
            return String((a && a.title) || "").localeCompare(String((b && b.title) || ""));
        });
        return out;
    }

    function calendarColor(value) {
        let text = String(value || "");
        if (text === "accent1") return window.accent1;
        if (text === "accent2") return window.accent2;
        if (text === "accent3") return window.accent3;
        if (text.length > 0) {
            try { return Qt.color(text); } catch (e) {}
        }
        return window.blue;
    }

    function applyLocalAgendaJson(text) {
        let txt = String(text || "").trim();
        if (txt === "") return;
        try {
            let data = JSON.parse(txt);
            window.localAgendaEvents = Array.isArray(data.events) ? data.events : [];
            window.updateCalendarGrid();
        } catch (e) {
            window.localAgendaEvents = [];
            window.updateCalendarGrid();
        }
    }

    function normalizedInputTime(value) {
        let text = String(value || "").trim();
        if (text === "") return "";
        let match = text.match(/^([0-2]?[0-9])[:.]([0-5][0-9])$/);
        if (!match) return text;
        let h = Math.min(23, parseInt(match[1], 10));
        let m = parseInt(match[2], 10);
        return (h < 10 ? "0" + h : "" + h) + ":" + (m < 10 ? "0" + m : "" + m);
    }

    function runLocalAgendaAction(action, eventId, dateKey, timeText, title) {
        if (localAgendaAction.running) localAgendaAction.running = false;
        localAgendaAction.action = action;
        localAgendaAction.eventId = eventId || "";
        localAgendaAction.eventDate = dateKey || "";
        localAgendaAction.eventTime = timeText || "";
        localAgendaAction.eventTitle = title || "";
        localAgendaAction.running = true;
    }

    function addLocalAgendaEvent(title, timeText) {
        let cleanTitle = String(title || "").trim().replace(/\s+/g, " ");
        if (cleanTitle === "") return;
        window.runLocalAgendaAction("add", "", selectedDateKey, normalizedInputTime(timeText), cleanTitle);
        window.addEventOpen = false;
    }

    function deleteLocalAgendaEvent(eventId) {
        if (String(eventId || "") === "") return;
        window.runLocalAgendaAction("delete", eventId, "", "", "");
    }

    readonly property var selectedEvents: eventsForDate(selectedDateKey)
    readonly property var agendaEvents: selectedEvents.length > 0 ? selectedEvents : upcomingEvents(6)
    readonly property string agendaTitle: selectedEvents.length > 0
        ? "AGENDA " + Qt.formatDateTime(new Date(selectedDateKey + "T12:00:00"), "dd MMM").toUpperCase()
        : "KOMENDE AFSPRAKEN"

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain

        Rectangle {
            anchors.fill: parent
            radius: window.themedRadius
            color: "transparent"
            border.width: 0
            clip: true

            // =======================================================
            // AMBIENT WIDGET COLOR BLOBS (Spread Out)
            // =======================================================
            Rectangle {
                width: window.s(parent.width * 0.5); height: width; radius: width / 2
                x: (parent.width * 0.75 - width / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(350)
                y: (parent.height * 0.3 - height / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(200)
                opacity: 0.025 * window.introAmbient
                color: window.activeWeatherHex
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Rectangle {
                width: window.s(parent.width * 0.6); height: width; radius: width / 2
                x: (parent.width * 0.25 - width / 2) + Math.sin(window.globalOrbitAngle * 1.2) * window.s(-300)
                y: (parent.height * 0.7 - height / 2) + Math.cos(window.globalOrbitAngle * 1.2) * window.s(-250)
                opacity: 0.02 * window.introAmbient
                color: window.timeColor
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Rectangle {
                width: window.s(parent.width * 0.45); height: width; radius: width / 2
                x: (parent.width * 0.5 - width / 2) + Math.cos(window.globalOrbitAngle * -1.8) * window.s(400)
                y: (parent.height * 0.5 - height / 2) + Math.sin(window.globalOrbitAngle * -1.8) * window.s(-350)
                opacity: 0.015 * window.introAmbient
                color: window.timeAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            // Big Parallax Weather Icon (Tied to Weather Transition)
            Text {
                id: weatherIconBackdrop
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.s(-100)
                text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: window.s(800)
                color: window.activeWeatherHex
                opacity: (0.03 + (0.01 * Math.sin(window.globalOrbitAngle * 4))) * window.introAmbient * window.weatherContentOpacity
                z: 0
                Behavior on color { ColorAnimation { duration: 1500 } }
                
                property real drift: 0
                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    NumberAnimation { to: window.s(-20); duration: 6000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                }
                
                transform: [
                    Translate { y: weatherIconBackdrop.drift },
                    Translate { x: window.weatherContentOffset * 2 } // Exaggerated shift for background depth
                ]
            }

            // =======================================================
            // CENTRAL HERO: THE BREATHING TIME HUB & 3D HOURLY ORBIT
            // =======================================================
            Item {
                id: centralHub
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.s(-100)
                width: window.s(1); height: window.s(1) 
                z: 5

                opacity: introClock
                scale: 0.85 + (0.15 * introClock)

                property real levitation: 0
                SequentialAnimation on levitation {
                    loops: Animation.Infinite
                    NumberAnimation { to: window.s(-15); duration: 4000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 4000; easing.type: Easing.InOutSine }
                }

                property real orbitBreath: 1.0
                SequentialAnimation on orbitBreath {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { to: 1.035; duration: 3500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 3500; easing.type: Easing.InOutSine }
                }

                // 3D Perspective Wobble (Pitch, Yaw, Roll)
                property real pitchBreath: 0
                SequentialAnimation on pitchBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 3.5; duration: 4200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -3.5; duration: 4200; easing.type: Easing.InOutSine }
                }

                property real yawBreath: 0
                SequentialAnimation on yawBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 2.5; duration: 5100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -2.5; duration: 5100; easing.type: Easing.InOutSine }
                }

                property real rollBreath: 0
                SequentialAnimation on rollBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 1.5; duration: 5800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1.5; duration: 5800; easing.type: Easing.InOutSine }
                }
                
                transform: [
                    Translate { y: window.s(25) * (1.0 - introClock) },
                    Translate { y: centralHub.levitation },
                    Rotation { axis { x: 1; y: 0; z: 0 } angle: centralHub.pitchBreath },
                    Rotation { axis { x: 0; y: 1; z: 0 } angle: centralHub.yawBreath },
                    Rotation { axis { x: 0; y: 0; z: 1 } angle: centralHub.rollBreath }
                ]

                Canvas {
                    z: -10
                    x: window.s(-400)   // Widened to prevent clipping when scaled
                    y: window.s(-200)   // Heightened to prevent clipping when scaled
                    width: window.s(800)
                    height: window.s(400)
                    opacity: 0.25

                    property real currentScale: centralHub.orbitBreath
                    onCurrentScaleChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.beginPath();
                        var currentRx = window.s(320) * currentScale;
                        var currentRy = window.s(140) * currentScale;
                        for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                            var xx = width/2 + Math.cos(i) * currentRx;
                            var yy = height/2 + Math.sin(i) * currentRy;
                            if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                        }
                        ctx.strokeStyle = window.textAccent;
                        ctx.lineWidth = window.s(1.5);
                        ctx.setLineDash([window.s(4), window.s(10)]);
                        ctx.stroke();
                    }
                    Behavior on opacity { NumberAnimation { duration: 1500 } }
                }

                // Core Clock
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    z: 0 
                    scale: 0.95 + (0.05 * window.secondPulse) 
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: window.s(2)
                        Text {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.family: window.displayFontFamily
                            font.weight: window.themedFontWeight
                            font.letterSpacing: window.themedLetterSpacing
                            font.pixelSize: window.s(84)
                            color: window.text
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                        }
                        Text {
                            text: Qt.formatTime(window.currentTime, ":ss")
                            font.family: window.monoFontFamily
                            font.weight: Font.Bold
                            font.letterSpacing: window.themedLetterSpacing
                            font.pixelSize: window.s(32)
                            color: window.textAccent
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: window.s(15)
                            opacity: window.secondPulse > 1.02 ? 1.0 : 0.6 
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(window.currentTime, "dddd, MMMM dd")
                        font.family: window.uiFontFamily
                        font.weight: Font.DemiBold
                        font.letterSpacing: window.themedLetterSpacing
                        font.pixelSize: window.s(16)
                        color: window.subtext0
                        opacity: 0.9
                    }
                }

                // TRUE 3D ORBITAL HOURLY FORECAST (Tied to Spin Transition)
                Item {
                    anchors.fill: parent
                    opacity: window.weatherContentOpacity
                    
                    // Added Scale property to give a z-depth shrink effect when spinning
                    scale: window.transitionScale 
                    transform: Translate { x: window.weatherContentOffset * 1.5 }

                    Repeater {
                        id: hourRepeater
                        model: window.weatherData && window.weatherData.forecast[window.weatherView] && window.weatherData.forecast[window.weatherView].hourly ? window.weatherData.forecast[window.weatherView].hourly.slice(0, 8) : []
                        
                        delegate: Item {
                            property int mCount: hourRepeater.count
                            property bool isToday: window.weatherView === 0
                            property bool isHighlighted: isToday && index === window.activeHourIndex
                            
                            property real rx: window.s(320) * centralHub.orbitBreath
                            property real ry: window.s(140) * centralHub.orbitBreath
                            
                            property int relIdx: isToday ? (index - window.activeHourIndex) : index
                            
                            property real targetAngleDeg: isToday ? (65 + (relIdx * 30)) : (index * (360 / Math.max(1, mCount)))
                            
                            property real orbitOffset: isToday ? 0 : (window.globalOrbitAngle * (180 / Math.PI) * -1.5)
                            property real osc: isToday ? (Math.sin(window.globalOrbitAngle * 10 + index) * 5) : 0 
                            
                            // Integrated window.transitionSpin directly into the final angle calculation
                            property real rad: (targetAngleDeg + orbitOffset + osc + window.transitionSpin) * (Math.PI / 180)

                            x: Math.cos(rad) * rx - width/2
                            y: Math.sin(rad) * ry - height/2
                            z: Math.sin(rad) * window.s(100) 
                            
                            scale: isHighlighted ? 1.4 : (isToday ? (0.95 + 0.20 * Math.sin(rad)) : (0.90 + 0.25 * Math.sin(rad)))
                            opacity: isHighlighted ? 1.0 : (isToday ? (0.7 + 0.3 * ((Math.sin(rad) + 1) / 2)) : (0.65 + 0.35 * ((Math.sin(rad) + 1) / 2)))

                            width: window.s(56); height: window.s(95)
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: window.s(28)
                                color: isHighlighted ? window.textAccent : (hrMa.containsMouse ? window.surface2 : window.surface0)
                                border.color: isHighlighted ? "transparent" : (hrMa.containsMouse ? window.textAccent : window.surface1)
                                border.width: 1
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                ColumnLayout {
                                    anchors.centerIn: parent 
                                    spacing: window.s(4)
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.time
                                        font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: window.s(12)
                                        color: isHighlighted ? window.base : (hrMa.containsMouse ? window.text : window.overlay1)
                                    }
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon || (window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : "")
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: window.s(18)
                                        color: isHighlighted ? window.base : (modelData.hex || window.text)
                                        
                                        transform: Translate { y: hrMa.containsMouse ? window.s(-3) : 0 }
                                        Behavior on transform { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter; text: modelData.temp + "°"
                                        font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(14)
                                        color: isHighlighted ? window.base : window.text 
                                    }
                                }
                            }
                            MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // =======================================================
            // LEFT WING: FLOATING GLASS CALENDAR
            // =======================================================
            Rectangle {
                id: calendarRect
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: window.s(40)
                width: window.s(320)
                height: window.s(420)
                color: Qt.alpha(window.surface0, 0.2) 
                radius: window.s(14)
                border.color: Qt.alpha(window.surface1, 0.4)
                border.width: 1
                z: 10 

                opacity: introCalendar
                transform: Translate { x: window.s(-40) * (1.0 - introCalendar) }

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(25)
                    spacing: window.s(15)

                    RowLayout {
                        Layout.fillWidth: true
                        
                        // "Return to Today" Home Button
                        Rectangle {
                            width: window.s(32); height: window.s(32); radius: window.s(16)
                            color: homeMa.containsMouse ? window.surface1 : "transparent"
                            opacity: window.targetMonthOffset !== 0 ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Text { anchors.centerIn: parent; text: "󰃭"; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: window.s(16) }
                            MouseArea { 
                                id: homeMa; anchors.fill: parent; hoverEnabled: window.targetMonthOffset !== 0; 
                                onClicked: if (window.targetMonthOffset !== 0) window.setMonthOffset(0) 
                            }
                        }

                        Rectangle {
                            width: window.s(32); height: window.s(32); radius: window.s(16)
                            color: prevMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: window.s(16) }
                            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.setMonthOffset(window.targetMonthOffset - 1) }
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: window.s(16)
                            color: window.text
                            horizontalAlignment: Text.AlignHCenter
                            
                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }
                        }

                        Rectangle {
                            width: window.s(32); height: window.s(32); radius: window.s(16)
                            color: nextMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: window.s(16) }
                            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.setMonthOffset(window.targetMonthOffset + 1) }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: window.s(14)
                                color: window.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: window.s(6)
                        columnSpacing: window.s(6)

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                readonly property bool selectedDay: dateKey === window.selectedDateKey

                                color: isToday ? window.textAccent : (selectedDay ? Qt.alpha(window.blue, 0.22) : (dayMa.containsMouse ? Qt.alpha(window.surface2, 0.4) : "transparent"))
                                radius: window.s(10)
                                scale: dayMa.containsMouse ? 1.2 : 1.0
                                border.color: isToday ? window.surface0 : (selectedDay ? window.blue : (dayMa.containsMouse ? window.overlay0 : "transparent"))
                                border.width: isToday || selectedDay || dayMa.containsMouse ? 1 : 0
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: "JetBrains Mono"
                                    font.weight: isToday ? Font.Black : Font.Bold
                                    font.pixelSize: window.s(14)
                                    color: isToday ? window.base : (isCurrentMonth ? window.text : window.surface0)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: window.s(4)
                                    spacing: window.s(2)
                                    visible: eventCount > 0

                                    Repeater {
                                        model: Math.min(3, eventCount)
                                        Rectangle {
                                            width: window.s(4)
                                            height: window.s(4)
                                            radius: width / 2
                                            color: isToday ? window.base : window.timeAccent
                                            opacity: isCurrentMonth ? 0.95 : 0.45
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: window.selectedDateKey = dateKey
                                }
                            }
                        }
                    }
                }
            }

            // =======================================================
            // LEFT LOWER WING: THUNDERBIRD AGENDA
            // =======================================================
            Rectangle {
                anchors.left: parent.left
                anchors.top: calendarRect.bottom
                anchors.leftMargin: window.s(40)
                anchors.topMargin: window.s(18)
                width: window.s(420)
                height: window.s(232)
                color: Qt.alpha(window.surface0, 0.18)
                radius: window.s(14)
                border.color: Qt.alpha(window.surface1, 0.38)
                border.width: 1
                z: 10

                opacity: introCalendar
                transform: Translate { x: window.s(-40) * (1.0 - introCalendar) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(18)
                    spacing: window.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(10)

                        Text {
                            text: "󰃰"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(17)
                            color: window.timeAccent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.agendaTitle
                            font.family: window.monoFontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(13)
                            color: window.text
                            elide: Text.ElideRight
                        }

                        Text {
                            text: window.thunderbirdCalendars.length + ""
                            font.family: window.monoFontFamily
                            font.weight: Font.Bold
                            font.pixelSize: window.s(11)
                            color: window.subtext0
                        }

                        Rectangle {
                            Layout.preferredWidth: window.s(26)
                            Layout.preferredHeight: window.s(26)
                            radius: window.s(8)
                            color: addEventMa.containsMouse || window.addEventOpen ? Qt.alpha(window.timeAccent, 0.24) : Qt.alpha(window.surface1, 0.18)
                            border.width: 1
                            border.color: window.addEventOpen ? Qt.alpha(window.timeAccent, 0.7) : Qt.alpha(window.surface2, 0.35)

                            Text {
                                anchors.centerIn: parent
                                text: window.addEventOpen ? "" : ""
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(12)
                                color: window.addEventOpen ? window.timeAccent : window.text
                            }

                            MouseArea {
                                id: addEventMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    window.addEventOpen = !window.addEventOpen;
                                    if (window.addEventOpen)
                                        Qt.callLater(() => eventTitleInput.forceActiveFocus());
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.addEventOpen ? window.s(38) : 0
                        visible: height > 1
                        radius: window.s(10)
                        color: Qt.alpha(window.surface1, 0.18)
                        border.width: 1
                        border.color: Qt.alpha(window.timeAccent, 0.34)
                        clip: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: window.s(10)
                            anchors.rightMargin: window.s(8)
                            spacing: window.s(8)

                            TextInput {
                                id: eventTitleInput
                                Layout.fillWidth: true
                                color: window.text
                                selectionColor: Qt.alpha(window.timeAccent, 0.34)
                                selectedTextColor: window.base
                                font.family: window.uiFontFamily
                                font.pixelSize: window.s(12)
                                clip: true
                                onAccepted: {
                                    window.addLocalAgendaEvent(text, eventTimeInput.text);
                                    eventTitleInput.text = "";
                                    eventTimeInput.text = "";
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: eventTitleInput.text === ""
                                    text: "Nieuwe gebeurtenis"
                                    font: eventTitleInput.font
                                    color: window.subtext0
                                }
                            }

                            TextInput {
                                id: eventTimeInput
                                Layout.preferredWidth: window.s(54)
                                color: window.text
                                selectionColor: Qt.alpha(window.timeAccent, 0.34)
                                selectedTextColor: window.base
                                font.family: window.monoFontFamily
                                font.pixelSize: window.s(12)
                                horizontalAlignment: Text.AlignHCenter
                                maximumLength: 5
                                onAccepted: {
                                    window.addLocalAgendaEvent(eventTitleInput.text, text);
                                    eventTitleInput.text = "";
                                    eventTimeInput.text = "";
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: eventTimeInput.text === ""
                                    text: "--:--"
                                    font: eventTimeInput.font
                                    color: window.overlay0
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: window.s(28)
                                Layout.preferredHeight: window.s(28)
                                radius: window.s(8)
                                color: saveEventMa.containsMouse ? Qt.alpha(window.green, 0.28) : Qt.alpha(window.green, 0.16)
                                border.width: 1
                                border.color: Qt.alpha(window.green, 0.48)

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(12)
                                    color: window.green
                                }

                                MouseArea {
                                    id: saveEventMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.addLocalAgendaEvent(eventTitleInput.text, eventTimeInput.text);
                                        eventTitleInput.text = "";
                                        eventTimeInput.text = "";
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(6)
                        visible: window.thunderbirdCalendars.length > 0

                        Repeater {
                            model: window.thunderbirdCalendars.slice(0, 3)
                            Rectangle {
                                Layout.preferredHeight: window.s(20)
                                Layout.preferredWidth: Math.min(window.s(128), calLabel.implicitWidth + window.s(24))
                                radius: window.s(7)
                                color: Qt.alpha(window.calendarColor(modelData.color), 0.18)
                                border.width: 1
                                border.color: Qt.alpha(window.calendarColor(modelData.color), 0.55)
                                clip: true

                                Text {
                                    id: calLabel
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: window.s(8)
                                    anchors.rightMargin: window.s(8)
                                    text: modelData.name || "Kalender"
                                    font.family: window.uiFontFamily
                                    font.pixelSize: window.s(10)
                                    font.weight: Font.DemiBold
                                    color: window.text
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: window.s(6)
                        model: window.agendaEvents
                        visible: window.agendaEvents.length > 0

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: window.s(42)
                            radius: window.s(10)
                            color: agendaHover.hovered ? Qt.alpha(window.surface2, 0.34) : Qt.alpha(window.surface1, 0.16)
                            border.width: 1
                            border.color: agendaHover.hovered ? Qt.alpha(window.calendarColor(modelData.color), 0.62) : Qt.alpha(window.surface2, 0.22)

                            HoverHandler { id: agendaHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: window.s(10)
                                anchors.rightMargin: window.s(10)
                                spacing: window.s(10)

                                Rectangle {
                                    Layout.preferredWidth: window.s(4)
                                    Layout.fillHeight: true
                                    Layout.topMargin: window.s(8)
                                    Layout.bottomMargin: window.s(8)
                                    radius: width / 2
                                    color: window.calendarColor(modelData.color)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || "(Geen titel)"
                                        font.family: window.uiFontFamily
                                        font.weight: Font.DemiBold
                                        font.pixelSize: window.s(12)
                                        color: window.text
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.time || "") + "  ·  " + (modelData.calendar || "")
                                        font.family: window.monoFontFamily
                                        font.pixelSize: window.s(10)
                                        color: window.subtext0
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: window.s(62)
                                    text: modelData.source === "local" ? "Lokaal" : (modelData.day || "")
                                    horizontalAlignment: Text.AlignRight
                                    font.family: window.monoFontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(10)
                                    color: window.overlay1
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.preferredWidth: modelData.source === "local" ? window.s(24) : 0
                                    Layout.preferredHeight: window.s(24)
                                    visible: modelData.source === "local"
                                    radius: window.s(7)
                                    color: deleteEventMa.containsMouse ? Qt.alpha(window.red, 0.22) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: window.s(11)
                                        color: deleteEventMa.containsMouse ? window.red : window.overlay1
                                    }

                                    MouseArea {
                                        id: deleteEventMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            mouse.accepted = true;
                                            window.deleteLocalAgendaEvent(modelData.id);
                                        }
                                    }
                                }
                            }

                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: window.agendaEvents.length === 0
                        spacing: window.s(7)

                        Item { Layout.fillHeight: true }
                        Text {
                            Layout.fillWidth: true
                            text: window.thunderbirdCalendars.length > 0 ? "Geen afspraken gevonden" : "Geen kalenderbronnen gevonden"
                            horizontalAlignment: Text.AlignHCenter
                            font.family: window.uiFontFamily
                            font.weight: Font.DemiBold
                            font.pixelSize: window.s(12)
                            color: window.text
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: window.thunderbirdCalendars.length > 0 ? "Gebruik de plusknop om een lokale gebeurtenis toe te voegen." : "Open Thunderbird om kalenders te koppelen of voeg lokaal een gebeurtenis toe."
                            horizontalAlignment: Text.AlignHCenter
                            font.family: window.uiFontFamily
                            font.pixelSize: window.s(10)
                            color: window.subtext0
                            wrapMode: Text.WordWrap
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // =======================================================
            // RIGHT WING: ORGANIC FLOATING WEATHER STATS
            // =======================================================
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: window.s(40)
                width: window.s(320)
                height: window.s(420)
                z: 10 

                opacity: introWeather
                transform: Translate { x: window.s(40) * (1.0 - introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: window.s(20)

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: window.s(20)
                        
                        MouseArea { 
                            id: wPrevMa; width: window.s(30); height: window.s(30); hoverEnabled: true
                            onClicked: window.setWeatherView(window.targetWeatherView - 1) 
                            
                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: window.s(-3); duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }
                            
                            Text { 
                                anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                                color: parent.containsMouse ? window.textAccent : window.overlay1
                                transform: Translate { x: parent.containsMouse ? window.s(-5) : wPrevMa.pulseOffset }
                                Behavior on transform { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            }
                        }
                        
                        Text {
                            Layout.preferredWidth: window.s(110) 
                            horizontalAlignment: Text.AlignHCenter 
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].day_full.toUpperCase() : "LOADING..."
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: window.s(16)
                            color: window.text
                        }
                        
                        MouseArea { 
                            id: wNextMa; width: window.s(30); height: window.s(30); hoverEnabled: true
                            onClicked: window.setWeatherView(window.targetWeatherView + 1)
                            
                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: window.s(3); duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }
                            
                            Text { 
                                anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                                color: parent.containsMouse ? window.textAccent : window.overlay1
                                transform: Translate { x: parent.containsMouse ? window.s(5) : wNextMa.pulseOffset }
                                Behavior on transform { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight 
                        spacing: window.s(-5)
                        
                        // BIG TEMPERATURE TEXT - Anchored so it doesn't slide with the wrapper
                        Text {
                            Layout.alignment: Qt.AlignHCenter 
                            text: Math.round(window.displayedTemp) + "°"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: window.s(84)
                            color: window.tempGlowColor
                            style: Text.Outline; 
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(window.crust, 0.4)
                            
                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on styleColor { ColorAnimation { duration: 300 } }
                        }
                        
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].desc : ""
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: window.s(16)
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            
                            opacity: window.weatherContentOpacity
                            transform: Translate { x: window.weatherContentOffset }
                        }
                    }

                    Item { Layout.fillHeight: true } 

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: window.s(10)
                        spacing: window.s(20)

                        Repeater {
                            model: 4

                            Item {
                                width: window.s(68)
                                height: window.s(100)
                                scale: gaugeMa.containsMouse ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                property var forecast: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? window.weatherData.forecast[window.targetWeatherView] : null

                                property string gaugeIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                property string gaugeLbl: index === 0 ? "WIND" : index === 1 ? "HUMID" : index === 2 ? "RAIN" : "FEELS"

                                property string gaugeVal: forecast ? (
                                    index === 0 ? forecast.wind + "m/s" :
                                    index === 1 ? forecast.humidity + "%" :
                                    index === 2 ? forecast.pop + "%" :
                                    forecast.feels_like + "°"
                                ) : ""

                                property real gaugeFill: forecast ? (
                                    index === 0 ? Math.min(1.0, forecast.wind / 25.0) :
                                    index === 1 ? forecast.humidity / 100.0 :
                                    index === 2 ? forecast.pop / 100.0 :
                                    Math.max(0.0, Math.min(1.0, (forecast.feels_like + 15) / 55.0))
                                ) : 0.0
                                
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: window.s(68); height: window.s(68); radius: window.s(34)
                                    color: window.textAccent
                                    opacity: gaugeMa.containsMouse ? 0.3 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                Item {
                                    id: circleItem
                                    width: window.s(68); height: window.s(68)
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    
                                    Canvas {
                                        id: gaugeCanvas
                                        anchors.fill: parent
                                        rotation: -90 
                                        
                                        property real animProgress: parent.parent.gaugeFill
                                        
                                        Behavior on animProgress {
                                            NumberAnimation { duration: 1000; easing.type: Easing.OutExpo }
                                        }
                                        
                                        onAnimProgressChanged: requestPaint()
                                        
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var r = width / 2;
                                            
                                            ctx.beginPath();
                                            ctx.arc(r, r, r - window.s(4), 0, 2 * Math.PI);
                                            ctx.strokeStyle = Qt.alpha(window.text, 0.1);
                                            ctx.lineWidth = window.s(3);
                                            ctx.stroke();
                                            
                                            if (animProgress > 0) {
                                                ctx.beginPath();
                                                ctx.arc(r, r, r - window.s(4), 0, animProgress * 2 * Math.PI);
                                                var grad = ctx.createLinearGradient(0, 0, width, height);
                                                grad.addColorStop(0, window.timeAccent);
                                                grad.addColorStop(1, window.sapphire);
                                                ctx.strokeStyle = grad;
                                                ctx.lineWidth = window.s(4);
                                                ctx.lineCap = "round";
                                                ctx.stroke();
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.parent.gaugeVal
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        font.pixelSize: window.s(14)
                                        color: window.text
                                    }
                                }
                                
                                RowLayout {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: window.s(4)
                                    
                                    Text { 
                                        text: parent.parent.gaugeIcon
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: window.s(14)
                                        color: gaugeMa.containsMouse ? window.textAccent : window.overlay0
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text { 
                                        text: parent.parent.gaugeLbl
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: window.s(12)
                                        color: window.overlay0 
                                    }
                                }
                                
                                MouseArea { id: gaugeMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
