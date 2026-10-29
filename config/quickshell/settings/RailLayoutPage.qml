import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// Rail-indeling per thema: sleep onderdelen tussen hoofdrail, tweede rail
// en "niet getoond", stel het aantal werkruimtes in en zet eigen apps in de
// rail. Alles wordt meteen bewaard (RailLayout); de rail volgt live.
Item {
    id: root
    signal pageRequested(string page)

    MatugenColors { id: pageColors }
    readonly property var themeColors: pageColors

    property string editTheme: ThemeConfig.theme
    readonly property var layout: RailLayout.resolve(editTheme)
    readonly property var poolItems: RailLayout.pool(editTheme).concat(["gap", "fill"])
    readonly property bool railOnRight: ThemeConfig.barRailEdge === "right"
    readonly property string mainSide: railOnRight ? "rechts" : "links"
    readonly property string secondSide: railOnRight ? "links" : "rechts"
    readonly property bool railShown: layout.rail === "on" || (layout.rail !== "off"
        && (editTheme === ThemeConfig.theme ? ThemeConfig.themeRailEnabled : themeHasRail(editTheme)))

    function themeHasRail(id) {
        return id === "neon" || id === "organic";
    }

    // --- Bewerken -----------------------------------------------------------
    function lists() {
        let r = RailLayout.resolve(editTheme);
        return {main: r.main.slice(), second: r.second.slice(), hidden: r.hidden.slice()};
    }
    function commit(l) {
        RailLayout.change(editTheme, {main: l.main, second: l.second, hidden: l.hidden});
    }
    function listFor(key) {
        return key === "main" ? layout.main : (key === "second" ? layout.second : poolItems);
    }
    // Verplaats van (lijst, plek) naar (lijst, plek). Kleine ruimte en Duw
    // naar onder uit "niet getoond" worden gekopieerd; terug naar "niet
    // getoond" haalt ze weg. Eigen apps zijn daar vanzelf zodra ze nergens
    // anders staan.
    function moveItem(fromKey, fromIndex, toKey, toIndex) {
        let l = lists();
        let id;
        if (fromKey === "pool") {
            id = poolItems[fromIndex];
            if (id === undefined) return;
            let h = l.hidden.indexOf(id);
            if (!RailLayout.isRepeatable(id) && h >= 0) l.hidden.splice(h, 1);
        } else {
            id = l[fromKey].splice(fromIndex, 1)[0];
            if (id === undefined) return;
            if (fromKey === toKey && toIndex > fromIndex) toIndex -= 1;
        }
        if (toKey === "pool") {
            if (fromKey === "pool") return;
            if (!RailLayout.isRepeatable(id) && id.indexOf("app:") !== 0) l.hidden.push(id);
        } else {
            l[toKey].splice(Math.max(0, Math.min(toIndex, l[toKey].length)), 0, id);
        }
        commit(l);
    }
    function nudge(key, index, delta) {
        moveItem(key, index, key, index + delta + (delta > 0 ? 1 : 0));
    }

    // --- Slepen -------------------------------------------------------------
    property bool dragging: false
    property string dragKey: ""
    property int dragIndex: -1
    property string dragId: ""
    property string dropKey: ""
    property int dropIndex: -1
    property real ghostX: 0
    property real ghostY: 0

    function beginDrag(key, index, id) {
        dragKey = key; dragIndex = index; dragId = id;
        dropKey = ""; dropIndex = -1;
        dragging = true;
    }
    function dragMove(x, y) {
        ghostX = x; ghostY = y;
        let columns = [mainColumn, secondColumn, poolColumn];
        let key = "", index = -1;
        for (let col of columns) {
            let p = col.mapFromItem(root, x, y);
            if (p.x >= -8 && p.x <= col.width + 8 && p.y >= -24 && p.y <= col.height + 24) {
                key = col.key;
                index = col.indexAt(p.y);
            }
        }
        dropKey = key; dropIndex = index;
    }
    function endDrag() {
        if (dragging && dropKey !== "" && !(dropKey === dragKey && (dropIndex === dragIndex || dropIndex === dragIndex + 1)))
            moveItem(dragKey, dragIndex, dropKey, dropIndex);
        dragging = false;
        dropKey = ""; dropIndex = -1; dragIndex = -1; dragKey = ""; dragId = "";
    }

    // --- Eigen apps ---------------------------------------------------------
    property string editAppId: ""
    property string appName: ""
    property string appIcon: ""
    property string appCommand: ""
    property string appQuery: ""
    property var installedApps: []
    property string appError: ""

    function slug(text) {
        let base = String(text || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").substring(0, 28);
        if (base === "") base = "app";
        let id = base, n = 2;
        while (RailLayout.app(id) !== null && id !== editAppId) id = base + "-" + (n++);
        return id;
    }
    function editApp(a) {
        editAppId = a ? a.id : "";
        appName = a ? a.name : "";
        appIcon = a ? a.icon : "";
        appCommand = a ? a.command : "";
        appError = "";
    }
    function saveApp() {
        if (appCommand.trim() === "") { appError = "Vul een commando in, bijvoorbeeld: firefox"; return; }
        let id = editAppId !== "" ? editAppId : slug(appName || appCommand.split(" ")[0]);
        let entry = {id: id, name: appName.trim() || id, icon: appIcon.trim(), command: appCommand.trim()};
        let list = RailLayout.apps.slice();
        let found = false;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) { list[i] = entry; found = true; }
        }
        if (!found) list.push(entry);
        RailLayout.saveApps(list);
        if (!found) {
            // Nieuwe app: meteen in de hoofdrail, bij de knoppen bovenaan.
            let l = lists();
            let at = l.main.indexOf("fill");
            l.main.splice(at >= 0 ? at : l.main.length, 0, "app:" + id);
            commit(l);
        }
        editApp(null);
    }
    function removeApp(id) {
        RailLayout.saveApps(RailLayout.apps.filter(a => a.id !== id));
        if (editAppId === id) editApp(null);
    }
    function pickInstalled(a) {
        appName = a.name;
        appIcon = a.icon || "";
        appCommand = a.terminal ? "kitty -e " + a.exec : a.exec;
        appQuery = "";
    }
    readonly property var appMatches: {
        let q = appQuery.trim().toLowerCase();
        if (q === "") return [];
        let out = [];
        for (let a of installedApps) {
            if ((a.name + " " + (a.genericName || "") + " " + (a.keywords || "")).toLowerCase().indexOf(q) !== -1) out.push(a);
            if (out.length >= 8) break;
        }
        return out;
    }
    onAppQueryChanged: if (appQuery !== "" && installedApps.length === 0 && !appLister.running) appLister.running = true
    Process {
        id: appLister
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/list-apps.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.installedApps = JSON.parse(this.text); } catch (e) { root.installedApps = []; }
            }
        }
    }

    // --- Bouwstenen ---------------------------------------------------------
    component Action: Rectangle {
        id: button
        property string label: ""
        property bool chosen: false
        property bool allowed: true
        signal triggered()
        implicitHeight: 34
        implicitWidth: caption.implicitWidth + 24
        radius: 8
        opacity: allowed ? 1 : 0.45
        scale: mouse.pressed ? 0.97 : 1.0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(150) } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
        color: chosen ? Qt.alpha(root.themeColors.primary, 0.2) : mouse.containsMouse ? root.themeColors.shellHoverFill : root.themeColors.shellRaisedFill
        border.width: 1
        border.color: chosen ? root.themeColors.primary : root.themeColors.shellOutline
        Text {
            id: caption
            anchors.centerIn: parent
            text: button.label
            color: root.themeColors.text
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.allowed
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
    component Heading: Text {
        color: root.themeColors.text
        font.family: ThemeConfig.uiFont
        font.pixelSize: 16
        font.bold: true
    }
    component Hint: Text {
        color: root.themeColors.subtext0
        font.family: ThemeConfig.uiFont
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    component Field: Rectangle {
        id: field
        property alias value: input.text
        property string placeholder: ""
        signal edited(string text)
        implicitHeight: 34
        radius: 8
        color: root.themeColors.shellRaisedFill
        border.width: 1
        border.color: input.activeFocus ? root.themeColors.primary : root.themeColors.shellOutline
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: root.themeColors.text
            selectionColor: Qt.alpha(root.themeColors.primary, 0.4)
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            onTextEdited: field.edited(text)
        }
        Text {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.activeFocus
            text: field.placeholder
            color: root.themeColors.subtext0
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    // Eén blokje in een kolom. Slepen verplaatst het; de pijltjes doen
    // hetzelfde zonder muisgeslinger.
    component Tile: Rectangle {
        id: tile
        required property string itemId
        required property int itemIndex
        required property string columnKey
        readonly property bool lifted: root.dragging && root.dragKey === columnKey && root.dragIndex === itemIndex
        readonly property int count: root.listFor(columnKey).length
        implicitHeight: 36
        radius: 9
        color: grab.containsMouse || grab.pressed ? root.themeColors.shellHoverFill : root.themeColors.shellRaisedFill
        border.width: 1
        border.color: lifted ? root.themeColors.primary : root.themeColors.shellOutline
        opacity: lifted ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(140) } }
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(140) } }

        MouseArea {
            id: grab
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point pressPoint: Qt.point(0, 0)
            onPressed: (mouse) => pressPoint = Qt.point(mouse.x, mouse.y)
            onPositionChanged: (mouse) => {
                if (!pressed) return;
                let p = mapToItem(root, mouse.x, mouse.y);
                if (!root.dragging) {
                    if (Math.abs(mouse.x - pressPoint.x) + Math.abs(mouse.y - pressPoint.y) < 6) return;
                    root.beginDrag(tile.columnKey, tile.itemIndex, tile.itemId);
                }
                root.dragMove(p.x, p.y);
            }
            onReleased: root.endDrag()
            onCanceled: root.endDrag()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 4
            spacing: 6
            Text {
                text: "󰇛"
                color: root.themeColors.subtext0
                font.family: ThemeConfig.iconFont
                font.pixelSize: 13
            }
            Text {
                text: RailLayout.itemIcon(tile.itemId)
                color: root.themeColors.primary
                font.family: ThemeConfig.iconFont
                font.pixelSize: 15
                visible: text.length <= 2
                Layout.preferredWidth: 18
                horizontalAlignment: Text.AlignHCenter
            }
            Image {
                visible: RailLayout.itemIcon(tile.itemId).length > 2
                source: visible ? Quickshell.iconPath(RailLayout.itemIcon(tile.itemId), true) : ""
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                sourceSize.width: 36
                sourceSize.height: 36
            }
            Text {
                Layout.fillWidth: true
                text: RailLayout.itemTitle(tile.itemId)
                color: root.themeColors.text
                font.family: ThemeConfig.uiFont
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            TileButton {
                glyph: "󰁝"; tip: "Omhoog"
                visible: tile.columnKey !== "pool"
                allowed: tile.itemIndex > 0
                onTriggered: root.nudge(tile.columnKey, tile.itemIndex, -1)
            }
            TileButton {
                glyph: "󰁅"; tip: "Omlaag"
                visible: tile.columnKey !== "pool"
                allowed: tile.itemIndex < tile.count - 1
                onTriggered: root.nudge(tile.columnKey, tile.itemIndex, 1)
            }
            TileButton {
                // Naar de andere rail; vanuit "niet getoond" naar de hoofdrail.
                glyph: tile.columnKey === "pool" ? "󰐕" : "󰁔"
                tip: tile.columnKey === "main" ? "Naar de tweede rail" : (tile.columnKey === "second" ? "Naar de hoofdrail" : "In de hoofdrail zetten")
                onTriggered: {
                    let to = tile.columnKey === "main" ? "second" : "main";
                    root.moveItem(tile.columnKey, tile.itemIndex, to, root.listFor(to).length);
                }
            }
            TileButton {
                glyph: "󰅖"; tip: "Niet tonen"
                visible: tile.columnKey !== "pool"
                onTriggered: root.moveItem(tile.columnKey, tile.itemIndex, "pool", 0)
            }
        }
    }
    component TileButton: Rectangle {
        id: tb
        property string glyph: ""
        property string tip: ""
        property bool allowed: true
        signal triggered()
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: 7
        opacity: allowed ? 1 : 0.3
        color: tbMouse.containsMouse ? Qt.alpha(root.themeColors.primary, 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(120) } }
        Text {
            anchors.centerIn: parent
            text: tb.glyph
            color: root.themeColors.text
            font.family: ThemeConfig.iconFont
            font.pixelSize: 13
        }
        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: tb.allowed
            cursorShape: Qt.PointingHandCursor
            onClicked: tb.triggered()
        }
    }
    component LayoutColumn: Rectangle {
        id: column
        required property string key
        property string title: ""
        property string note: ""
        readonly property var entries: root.listFor(key)
        readonly property bool target: root.dragging && root.dropKey === key
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 1
        implicitHeight: content.implicitHeight + 20
        radius: 12
        color: target ? Qt.alpha(root.themeColors.primary, 0.08) : "transparent"
        border.width: 1
        border.color: target ? root.themeColors.primary : root.themeColors.shellOutline
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(140) } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(140) } }

        function indexAt(y) {
            for (let i = 0; i < tiles.count; i++) {
                let t = tiles.itemAt(i);
                if (!t) continue;
                let p = t.mapToItem(column, 0, 0);
                if (y < p.y + t.height / 2) return i;
            }
            return tiles.count;
        }
        function markerY(index) {
            if (tiles.count === 0) return list.mapToItem(column, 0, 0).y;
            let i = Math.min(index, tiles.count - 1);
            let t = tiles.itemAt(i);
            if (!t) return 0;
            let p = t.mapToItem(column, 0, 0);
            return index >= tiles.count ? p.y + t.height + 2 : p.y - 3;
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 6
            Text {
                text: column.title
                color: root.themeColors.text
                font.family: ThemeConfig.uiFont
                font.pixelSize: 13
                font.bold: true
            }
            Hint { text: column.note; visible: text !== ""; Layout.fillWidth: true; font.pixelSize: 11 }
            ColumnLayout {
                id: list
                Layout.fillWidth: true
                spacing: 5
                Repeater {
                    id: tiles
                    model: column.entries
                    delegate: Tile {
                        required property string modelData
                        required property int index
                        itemId: modelData
                        itemIndex: index
                        columnKey: column.key
                        Layout.fillWidth: true
                    }
                }
                // Lege kolom: een vak om iets in te laten vallen.
                Rectangle {
                    visible: tiles.count === 0
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: 9
                    color: "transparent"
                    border.width: 1
                    border.color: root.themeColors.shellOutline
                    Hint {
                        anchors.centerIn: parent
                        text: column.key === "second" ? "Sleep hier iets heen" : "Leeg"
                    }
                }
            }
        }
        // Waar het gesleepte blok landt.
        Rectangle {
            visible: column.target && root.dropIndex >= 0
            x: 10
            width: column.width - 20
            height: 3
            radius: 1.5
            y: column.target ? column.markerY(root.dropIndex) : 0
            color: root.themeColors.primary
            Behavior on y { NumberAnimation { duration: ThemeConfig.duration(90) } }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: body.implicitHeight
        contentWidth: width
        clip: true
        interactive: !root.dragging
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 16
            Heading { text: "Rail-indeling"; font.pixelSize: 24 }
            Hint {
                Layout.fillWidth: true
                text: "Sleep onderdelen om de volgorde te veranderen, naar de tweede rail aan de " + root.secondSide
                    + "kant of naar Niet getoond. Dit geldt per thema en wordt meteen bewaard. Welke onderdelen "
                    + "een scherm toont en wat achter Meer staat, kies je per scherm onder Bediening."
            }

            Hint { text: "Thema"; Layout.fillWidth: true }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: RailLayout.themes
                    delegate: Action {
                        required property var modelData
                        label: modelData.title + (modelData.id === ThemeConfig.theme ? "  ·  actief" : "")
                        chosen: root.editTheme === modelData.id
                        onTriggered: root.editTheme = modelData.id
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                ColumnLayout {
                    spacing: 6
                    Hint { text: "Rail in dit thema" }
                    Flow {
                        spacing: 8
                        Layout.preferredWidth: 330
                        Repeater {
                            model: [{id: "theme", title: "Volg thema"}, {id: "on", title: "Aan"}, {id: "off", title: "Uit"}]
                            delegate: Action {
                                required property var modelData
                                label: modelData.title
                                chosen: root.layout.rail === modelData.id
                                onTriggered: RailLayout.change(root.editTheme, {rail: modelData.id})
                            }
                        }
                    }
                }
                ColumnLayout {
                    spacing: 6
                    Hint { text: "Werkruimtes in de rail" }
                    RowLayout {
                        spacing: 8
                        Action {
                            label: "−"
                            allowed: root.layout.workspaces > 1
                            onTriggered: RailLayout.change(root.editTheme, {workspaces: root.layout.workspaces - 1})
                        }
                        Text {
                            text: root.layout.workspaces
                            color: root.themeColors.text
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 16
                            font.bold: true
                            Layout.preferredWidth: 26
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Action {
                            label: "+"
                            allowed: root.layout.workspaces < 10
                            onTriggered: RailLayout.change(root.editTheme, {workspaces: root.layout.workspaces + 1})
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Action {
                    label: "Standaardindeling"
                    allowed: RailLayout.hasSaved(root.editTheme)
                    onTriggered: RailLayout.reset(root.editTheme)
                }
            }
            Hint {
                Layout.fillWidth: true
                visible: !root.railShown
                color: root.themeColors.yellow
                text: "Dit thema toont nu geen rail, alleen de bovenstrook. Zet de rail hierboven op Aan om deze indeling te zien."
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                LayoutColumn {
                    id: mainColumn
                    key: "main"
                    title: "Hoofdrail  ·  " + root.mainSide
                }
                LayoutColumn {
                    id: secondColumn
                    key: "second"
                    title: "Tweede rail  ·  " + root.secondSide
                    note: "Verschijnt zodra hier iets staat."
                }
                LayoutColumn {
                    id: poolColumn
                    key: "pool"
                    title: "Niet getoond"
                    note: "Kleine ruimte en Duw naar onder kun je vaker gebruiken."
                }
            }

            Heading { text: "Eigen apps en launchers" }
            Hint {
                Layout.fillWidth: true
                text: "Een eigen knop start een app of commando. Kies een geïnstalleerde app of vul zelf een commando in. "
                    + "Een icoonnaam (zoals firefox) komt uit je icoonthema; een Nerd Font-teken mag ook. "
                    + "Een nieuwe knop komt bovenaan in de hoofdrail; sleep hem daarna waarheen je wilt."
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: RailLayout.apps
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: RailLayout.itemIcon("app:" + modelData.id)
                            visible: text.length <= 2
                            color: root.themeColors.primary
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 16
                            Layout.preferredWidth: 20
                        }
                        Image {
                            visible: String(modelData.icon || "").length > 2
                            source: visible ? Quickshell.iconPath(modelData.icon, true) : ""
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            sourceSize.width: 40
                            sourceSize.height: 40
                        }
                        Hint {
                            Layout.fillWidth: true
                            text: modelData.name + "  ·  " + modelData.command
                            color: root.themeColors.text
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                        Action { label: "Wijzigen"; chosen: root.editAppId === modelData.id; onTriggered: root.editApp(modelData) }
                        Action { label: "Verwijderen"; onTriggered: root.removeApp(modelData.id) }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: form.implicitHeight + 24
                radius: 12
                color: "transparent"
                border.width: 1
                border.color: root.themeColors.shellOutline
                ColumnLayout {
                    id: form
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    Text {
                        text: root.editAppId !== "" ? "App wijzigen" : "Nieuwe app"
                        color: root.themeColors.text
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Field {
                        Layout.fillWidth: true
                        placeholder: "Zoek een geïnstalleerde app…"
                        value: root.appQuery
                        onEdited: (text) => root.appQuery = text
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.appMatches.length > 0
                        Repeater {
                            model: root.appMatches
                            delegate: Action {
                                required property var modelData
                                label: modelData.name
                                onTriggered: root.pickInstalled(modelData)
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Field {
                            Layout.preferredWidth: 180
                            placeholder: "Naam"
                            value: root.appName
                            onEdited: (text) => root.appName = text
                        }
                        Field {
                            Layout.preferredWidth: 140
                            placeholder: "Icoon (firefox of 󰈹)"
                            value: root.appIcon
                            onEdited: (text) => root.appIcon = text
                        }
                        Field {
                            Layout.fillWidth: true
                            placeholder: "Commando, bijvoorbeeld: firefox --new-window"
                            value: root.appCommand
                            onEdited: (text) => root.appCommand = text
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Action { label: root.editAppId !== "" ? "Opslaan" : "Toevoegen aan de rail"; onTriggered: root.saveApp() }
                        Action { label: "Leegmaken"; visible: root.editAppId !== "" || root.appName !== "" || root.appCommand !== ""; onTriggered: root.editApp(null) }
                    }
                    Hint { text: root.appError; visible: text !== ""; color: root.themeColors.red; Layout.fillWidth: true }
                }
            }
            Hint { text: RailLayout.errorText; visible: text !== ""; color: root.themeColors.red; Layout.fillWidth: true }
            Item { Layout.preferredHeight: 12 }
        }
    }

    // Het blokje onder de muis tijdens het slepen.
    Rectangle {
        visible: root.dragging
        z: 100
        x: root.ghostX - width / 2
        y: root.ghostY - height / 2
        width: 190
        height: 36
        radius: 9
        color: root.themeColors.shellRaisedFill
        border.width: 1
        border.color: root.themeColors.primary
        scale: root.dragging ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(120) } }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            spacing: 8
            Text {
                text: RailLayout.itemIcon(root.dragId).length <= 2 ? RailLayout.itemIcon(root.dragId) : "󰀻"
                color: root.themeColors.primary
                font.family: ThemeConfig.iconFont
                font.pixelSize: 15
            }
            Text {
                Layout.fillWidth: true
                text: RailLayout.itemTitle(root.dragId)
                color: root.themeColors.text
                font.family: ThemeConfig.uiFont
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }
}
