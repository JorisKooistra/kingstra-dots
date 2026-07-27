import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../WindowRegistry.js" as Registry

Item {
    id: root
    required property var hostWindow
    required property var anchorItem

    property string sourceEntryId: ""
    property string visualEntryId: ""
    property bool open: sourceEntryId !== ""
    property real openProgress: open ? 1.0 : 0.0
    readonly property bool hovered: panelHover.hovered
    onSourceEntryIdChanged: {
        if (sourceEntryId !== "") {
            visualClearTimer.stop();
            visualEntryId = sourceEntryId;
            // Ook hier de focus doorschuiven, niet alleen in
            // onActiveFocusChanged: bij een tweede keer openen heeft de host de
            // focus meestal nog van de vorige keer, dus dat signaal blijft uit
            // en zou het zoekveld leeg laten. callLater wacht tot de Loader
            // zijn inhoud heeft geplaatst.
            if (sourceEntryId === "launcher") Qt.callLater(focusContent);
        } else {
            visualClearTimer.restart();
        }
        syncActiveWidgetState();
    }
    readonly property bool isCentered: sourceEntryId === "settings" && !ThemeConfig.barRailEnabled
    readonly property bool railOnRight: ThemeConfig.barRailEdge === "right"
    readonly property bool stripOnBottom: ThemeConfig.barStatusStripEdge === "bottom"

    // Anker van de triggerende bar-knop (host-coords), gezet door ShellSurface.
    // Panelen groeien vanuit dit punt i.p.v. uit een vaste schermhoek.
    property real anchorX: 0
    property real anchorY: 0
    readonly property int gap: 10
    // Breedte van de dunne omlijning rechts/onder, zodat panelen er niet
    // onder wegschuiven. ShellChrome is de eigenaar van dat getal.
    readonly property int borderW: (anchorItem && anchorItem.shellBorderWidth !== undefined)
        ? anchorItem.shellBorderWidth : 0
    readonly property int railW: ThemeConfig.barRailEnabled ? ThemeConfig.barRailWidth : 0
    readonly property int stripH: (anchorItem && anchorItem.stripHeight !== undefined)
        ? anchorItem.stripHeight : ThemeConfig.barStatusStripHeight
    readonly property int stripTopH: ThemeConfig.barStatusStripEnabled && !stripOnBottom ? stripH : 0
    readonly property int stripBotH: ThemeConfig.barStatusStripEnabled && stripOnBottom ? stripH : 0
    // Edge-panelen groeien uit de schermomlijsting. Met een rail groeien alle
    // reguliere widgets uit de zijkant; zonder rail vallen ze terug op de strip.
    function isWidgetEntry(entryId) {
        return entryId === "tophover"
            || entryId === "battery"
            || entryId === "network"
            || entryId === "volume"
            || entryId === "music"
            || entryId === "focustime"
            || entryId === "monitors"
            || entryId === "performance"
            || entryId === "gaming"
            || entryId === "power"
            || entryId === "notifications"
            || entryId === "mail"
            || entryId === "calendar"
            || entryId === "settings";
    }
    function isRailEntry(entryId) {
        return ThemeConfig.barRailEnabled && isWidgetEntry(entryId);
    }
    function isStripEntry(entryId) {
        return ThemeConfig.barStatusStripEnabled
            && (entryId === "calendar"
                || entryId === "monitors"
                || entryId === "gaming"
                || entryId === "settings"
                || entryId === "mail"
                || (!ThemeConfig.barRailEnabled
                    && (entryId === "battery"
                        || entryId === "network"
                        || entryId === "volume"
                        || entryId === "music"
                        || entryId === "power")));
    }
    function edgeFor(entryId) {
        if (entryId === "tophover") return "top";
        if (entryId === "launcher") return "bottom";
        if (isRailEntry(entryId)) return railOnRight ? "right" : "left";
        if (isStripEntry(entryId)) return stripOnBottom ? "bottom" : "top";
        return "";
    }
    // Alleen panelen met tekstinvoer hebben een focusgrab nodig. Bij de
    // overige panelen zou de grab botsen met de legacy focus-afhandeling
    // in qs_manager.sh en het paneel meteen weer sluiten.
    readonly property bool needsKeyboard: sourceEntryId === "launcher"
    readonly property bool fromStrip: ThemeConfig.barStatusStripEnabled && !stripOnBottom
                                      && anchorY < stripH + 4
    readonly property string visualEdge: edgeFor(visualEntryId)
    readonly property bool visualFromEdge: visualEdge !== ""
    readonly property bool visualVerticalEdge: visualEdge === "top" || visualEdge === "bottom"
    readonly property bool visualHorizontalEdge: visualEdge === "left" || visualEdge === "right"
    readonly property bool visualFromBottom: visualEdge === "bottom"
    readonly property real visualEdgeBlobProgress: visualFromEdge
        ? (visualVerticalEdge
            ? _clamp(height / Math.max(1, panelHeight(visualEntryId)), 0, 1)
            : _clamp(width / Math.max(1, panelWidth(visualEntryId)), 0, 1))
        : 0
    readonly property real visualContentProgress: visualFromEdge
        ? _clamp((visualEdgeBlobProgress - 0.10) / 0.90, 0, 1)
        : 1
    function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    function syncActiveWidgetState() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "printf '%s' \"$1\" > /tmp/qs_active_widget",
            "qs-active",
            root.sourceEntryId === "" ? "hidden" : root.sourceEntryId
        ]);
    }

    MatugenColors { id: mocha }

    Timer {
        id: visualClearTimer
        interval: ThemeConfig.durationToken("spatial") + 80
        repeat: false
        onTriggered: if (root.sourceEntryId === "") root.visualEntryId = ""
    }

    // De popups komen uit het legacy qs-master-venster en schalen hun interne
    // layout op Screen.width via WindowRegistry. Ze hebben dus een vaste maat
    // waarvoor ze ontworpen zijn; kregen ze minder, dan liep de inhoud over
    // elkaar heen en werd hij links weggeknipt. Diezelfde registry is hier de
    // bron van waarheid, zodat paneel en inhoud altijd overeenkomen.
    function registrySize(entryId) {
        if (!hostWindow) return null;
        let layout = Registry.getLayout(entryId, 0, 0, hostWindow.width, hostWindow.height,
                                        TouchProfile.windowScale, ThemeConfig.theme,
                                        ThemeConfig.barPosition);
        return layout ? layout : null;
    }

    // Ruimte die de chrome zelf inneemt; panelen mogen daar niet onder schuiven.
    readonly property int availableW: (hostWindow ? hostWindow.width : 1920) - railW - borderW - gap * 2
    readonly property int availableH: (hostWindow ? hostWindow.height : 1080)
        - stripTopH - stripBotH - borderW - gap * 2

    function panelWidth(entryId) {
        if (entryId === "launcher") return Math.min(620, availableW);
        if (entryId === "tophover") return Math.min(1020, availableW);
        if (entryId === "performance") return Math.min(380, availableW);
        if (entryId === "gaming") return Math.min(720, availableW);
        if (entryId === "notifications") return Math.min(460, availableW);
        if (entryId === "mail") return Math.min(520, availableW);
        let reg = registrySize(entryId);
        if (reg) return Math.min(reg.w, availableW);
        return Math.min(460, availableW);
    }

    function panelHeight(entryId) {
        if (entryId === "launcher") return Math.min(560, availableH);
        if (entryId === "tophover") return Math.min(232, availableH);
        // Was volle schermhoogte terwijl er maar een handvol meters in staat.
        if (entryId === "performance") return Math.min(360, availableH);
        if (entryId === "gaming") return Math.min(560, availableH);
        if (entryId === "notifications") return Math.min(620, availableH);
        if (entryId === "mail") return Math.min(560, availableH);
        let reg = registrySize(entryId);
        if (reg) return Math.min(reg.h, availableH);
        return Math.min(620, availableH);
    }

    function sourceFor(entryId) {
        if (entryId === "launcher") return Qt.resolvedUrl("LauncherPanel.qml");
        if (entryId === "tophover") return Qt.resolvedUrl("TopHoverWidget.qml");
        if (entryId === "battery") return Qt.resolvedUrl("../battery/BatteryPopup.qml");
        if (entryId === "focustime") return Qt.resolvedUrl("../focustime/FocusTimePopup.qml");
        if (entryId === "network") return Qt.resolvedUrl("../network/NetworkPopup.qml");
        if (entryId === "volume") return Qt.resolvedUrl("../volume/VolumePopup.qml");
        if (entryId === "music") return Qt.resolvedUrl("../music/MusicPopup.qml");
        if (entryId === "calendar") return Qt.resolvedUrl("../calendar/CalendarPopup.qml");
        if (entryId === "monitors") return Qt.resolvedUrl("../monitors/MonitorPopup.qml");
        if (entryId === "performance") return Qt.resolvedUrl("PerformanceDrawer.qml");
        if (entryId === "gaming") return Qt.resolvedUrl("../monitors/GamingPopup.qml");
        if (entryId === "settings") return Qt.resolvedUrl("../settings/SettingsPopup.qml");
        if (entryId === "power") return Qt.resolvedUrl("../power/PowerMenu.qml");
        if (entryId === "notifications") return Qt.resolvedUrl("../notifications/NotificationPopup.qml");
        if (entryId === "mail") return Qt.resolvedUrl("../mail/MailPopup.qml");
        return "";
    }

    // Positie: geankerd aan de triggerende knop. De rail-drawer (performance)
    // vult de volle hoogte naast de rail; strip-triggers groeien naar beneden
    // vanaf de strip op de knop-X; rail-triggers groeien naar rechts vanaf de
    // railrand op de knop-Y. Positie snapt (geen slide), grootte groeit.
    x: {
        if (!hostWindow) return 12;
        let entry = visualEntryId !== "" ? visualEntryId : sourceEntryId;
        let W = panelWidth(entry);
        let leftEdge = (ThemeConfig.barRailEnabled && !railOnRight) ? railW : 0;
        let rightEdge = (ThemeConfig.barRailEnabled && railOnRight) ? hostWindow.width - railW : hostWindow.width - borderW;
        if (visualEdge === "bottom" || visualEdge === "top")
            return Math.round((leftEdge + rightEdge - W) / 2);
        // Flush tegen de rail/omlijsting, net als de launcher onderaan: de
        // linker-/rechterkant van deze panelen is bewust vierkant (zie
        // PanelBackdrop) zodat de blob met de frame-blob samensmelt tot één
        // silhouet met één accentlijn. Met een gap ertussen tekenden paneel en
        // frame elk hun eigen accent → dubbele lijn langs de railkant.
        if (visualEdge === "left")
            return leftEdge;
        if (visualEdge === "right")
            return rightEdge - width;
        if (sourceEntryId === "settings")
            return Math.round((leftEdge + rightEdge - W) / 2);
        if (fromStrip)
            return _clamp(anchorX - W / 2, leftEdge + gap, rightEdge - W - gap);
        return railOnRight ? (rightEdge - W - gap) : (leftEdge + gap);
    }
    y: {
        if (!hostWindow) return 12;
        let entry = visualEntryId !== "" ? visualEntryId : sourceEntryId;
        let H = panelHeight(entry);
        // Onderrand vastzetten: naarmate height groeit schuift y omhoog.
        // Vlak tegen de schermrand: de launcher groeit uit de omlijning, dus
        // geen tussenruimte en hij dekt de rand in zijn eigen breedte af.
        if (visualEdge === "bottom") return hostWindow.height - height;
        if (visualEdge === "top") return stripTopH;
        if (sourceEntryId === "settings")
            return Math.max(stripTopH + gap, Math.round((hostWindow.height - borderW - H) / 2));
        if (visualEdge === "left" || visualEdge === "right")
            return _clamp(anchorY - H / 2, stripTopH + gap, Math.max(stripTopH + gap, hostWindow.height - H - stripBotH - borderW - gap));
        if (fromStrip) return stripTopH + gap;
        let top = stripTopH + gap;
        let bot = hostWindow.height - H - gap - stripBotH - borderW;
        return _clamp(anchorY - 18, top, Math.max(top, bot));
    }
    width: visualVerticalEdge ? panelWidth(visualEntryId) : (open ? panelWidth(sourceEntryId) : 0)
    height: visualHorizontalEdge ? panelHeight(visualEntryId) : (open ? panelHeight(sourceEntryId) : 0)
    clip: false
    visible: open || width > 1 || height > 1
    // De host moet focus houden: zonder focus-item in deze surface geeft de
    // compositor er geen toetsenbordfocus aan en komt er helemaal niets meer
    // aan (ook Escape niet). Bij een paneel met tekstinvoer schuiven we de
    // focus daarna door naar de inhoud; `focus` hier blijft waar, alleen
    // `activeFocus` verhuist naar het zoekveld.
    focus: open
    // `open` en `needsKeyboard` hangen allebei van sourceEntryId af maar
    // updaten niet in dezelfde bindingstap: heel even is `open` waar terwijl
    // `needsKeyboard` nog niet is bijgewerkt, waardoor de host de focus van
    // het zoekveld afpakt en daarna laat vallen — niemand heeft hem dan nog.
    // Qt.callLater draait pas als alle bindingen gesetteld zijn, dus daar
    // leggen we de focus definitief bij de inhoud.
    // Zodra de host de focus krijgt schuift hij hem door naar de inhoud. Dat
    // is volgorde-onafhankelijk: of de inhoud nu vóór of ná het openen wordt
    // geladen, de focus belandt hoe dan ook bij het zoekveld. Geen lus: na
    // forceActiveFocus verliest de host zelf activeFocus.
    // Bewust sourceEntryId i.p.v. needsKeyboard: die afgeleide property is op
    // dit moment nog niet herberekend en leest dan false terwijl de bron al
    // "launcher" is, waardoor de focus nooit werd doorgegeven.
    onActiveFocusChanged: if (activeFocus && sourceEntryId === "launcher") focusContent()

    function focusContent() {
        if (contentLoader.item)
            contentLoader.item.forceActiveFocus();
        // De eerste opening na een shell-herstart valt samen met het opbouwen
        // van het paneel en het scannen van de desktop-entries; de focus kan
        // daar nog tussenuit glippen, waardoor de eerste aanslagen verdwijnen.
        // Kort nachecken vangt dat af zonder permanent te pollen.
        focusRetry.restart();
    }

    Timer {
        id: focusRetry
        interval: 60
        repeat: true
        property int tries: 0
        onRunningChanged: if (running) tries = 0
        onTriggered: {
            tries += 1;
            let it = contentLoader.item;
            if (!root.open || !it || tries > 8) {
                stop();
                return;
            }
            if (!it.activeFocus)
                it.forceActiveFocus();
            else
                stop();
        }
    }
    opacity: visualFromEdge ? 1.0 : openProgress

    HoverHandler {
        id: panelHover
    }

    Behavior on openProgress {
        NumberAnimation {
            duration: ThemeConfig.durationToken("fast")
            easing.type: ThemeConfig.easingToken("standard")
        }
    }
    Behavior on width {
        enabled: !root.visualVerticalEdge
        NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") }
    }
    Behavior on height {
        NumberAnimation {
            // De launcher is primair toetsenbordgereedschap en moet meteen
            // bruikbaar voelen; de langere ruimtelijke animatie voegt daar
            // onnodig wachttijd aan toe.
            duration: root.visualEntryId === "launcher"
                ? ThemeConfig.durationToken("fast")
                : ThemeConfig.durationToken("spatial")
            easing.type: root.visualVerticalEdge ? ThemeConfig.easingToken("standard") : ThemeConfig.easingToken("emphasized")
        }
    }

    Keys.onEscapePressed: event => {
        root.sourceEntryId = "";
        event.accepted = true;
    }

    // Stable pure-QML panel surface. A future native blob can replace this
    // component without changing the host/entry API.
    PanelBackdrop {
        id: panelBackdrop

        open: root.visualFromEdge ? true : root.open
        mocha: mocha
        // Performance was hiervoor een volle-hoogte drawer met rechte hoeken;
        // hij is nu een gewoon paneel op knophoogte, net als de andere.
        squareCorners: false
        flushBottom: root.visualFromBottom
        edge: root.visualEdge
        sideConnectorOverlap: root.visualHorizontalEdge ? root.gap + root.borderW / 4 : 0
        blobGroup: root.visualFromEdge && anchorItem ? anchorItem.edgeBlobGroup : null
        // Vulling en rand komen bij een native blob uit de shader, die één
        // schermbreed verloop over de hele groep sampelt. De overrides
        // hieronder zijn puur de fallback voor de Rectangle-variant (geen
        // afgeronde chrome-hoeken). Ze staan bewust uit zodra de blob actief
        // is: het zijn per-paneel kleursamples die anders bij elke frame van
        // de groei-animatie opnieuw berekend worden zonder iets te tekenen.
        readonly property bool blobActive: blobGroup !== null

        fillOverride: !blobActive && root.visualFromEdge && anchorItem
            ? Qt.rgba(anchorItem.barGradCenter.r, anchorItem.barGradCenter.g,
                      anchorItem.barGradCenter.b, 1.0)
            : "transparent"
        fillStartOverride: !blobActive && root.visualFromEdge && anchorItem
            ? Qt.rgba(anchorItem.edgeBlobFillStart.r, anchorItem.edgeBlobFillStart.g,
                      anchorItem.edgeBlobFillStart.b, 1.0)
            : "transparent"
        fillEndOverride: !blobActive && root.visualFromEdge && anchorItem
            ? Qt.rgba(anchorItem.edgeBlobFillEnd.r, anchorItem.edgeBlobFillEnd.g,
                      anchorItem.edgeBlobFillEnd.b, 1.0)
            : "transparent"
        bottomConnectorRadius: root.visualFromEdge && anchorItem ? anchorItem.cornerR : 0
        bottomConnectorLift: root.visualFromBottom && anchorItem ? anchorItem.shellBorderWidth : 0
        borderOverride: !blobActive && root.visualFromEdge && anchorItem
            ? Qt.rgba(anchorItem.barHueCenter.r, anchorItem.barHueCenter.g,
                      anchorItem.barHueCenter.b, anchorItem.chromeAccentAlpha)
            : "transparent"
        borderStartOverride: !blobActive && root.visualFromEdge && anchorItem
            ? Qt.rgba(anchorItem.edgeBlobHueStart.r, anchorItem.edgeBlobHueStart.g,
                      anchorItem.edgeBlobHueStart.b, anchorItem.chromeAccentAlpha)
            : "transparent"
        borderEndOverride: !blobActive && root.visualFromEdge && anchorItem
            ? Qt.rgba(anchorItem.edgeBlobHueEnd.r, anchorItem.edgeBlobHueEnd.g,
                      anchorItem.edgeBlobHueEnd.b, anchorItem.chromeAccentAlpha)
            : "transparent"
    }

    // Alleen de content wordt geknipt tijdens de reveal. De native blob-backdrop
    // moet buiten de host-bounds kunnen tekenen om met de schermrand te mengen.
    Item {
        anchors.fill: parent
        clip: true
        transform: Matrix4x4 {
            matrix: panelBackdrop.nativeDeformMatrix
        }

        Loader {
            id: contentLoader
            x: 0
            y: 0
            width: root.panelWidth(root.visualEntryId !== "" ? root.visualEntryId : root.sourceEntryId)
            height: root.panelHeight(root.visualEntryId !== "" ? root.visualEntryId : root.sourceEntryId)
            opacity: root.visualContentProgress
            active: root.sourceFor(root.visualEntryId !== "" ? root.visualEntryId : root.sourceEntryId) !== ""
            source: root.sourceFor(root.visualEntryId !== "" ? root.visualEntryId : root.sourceEntryId)

            // De focus moet naar het geladen paneel zelf (een FocusScope), niet
            // naar de Loader: die is zelf geen scope en houdt de focus dan vast
            // zonder hem door te geven, waardoor zelfs Escape niet meer aankomt.
            focus: root.open
            onLoaded: if (root.open && root.needsKeyboard) root.focusContent()

            Behavior on opacity {
                NumberAnimation {
                    duration: ThemeConfig.durationToken("fast")
                    easing.type: ThemeConfig.easingToken("standard")
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.sourceEntryId !== "" && contentLoader.status === Loader.Error
            radius: Math.min(8, ThemeConfig.styleWidgetRadius)
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8
                Text {
                    text: root.sourceEntryId === "" ? "" : root.sourceEntryId
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 16
                    color: mocha.text
                    Layout.fillWidth: true
                }
                Text {
                    text: "Panelhost actief"
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    color: mocha.subtext1
                    Layout.fillWidth: true
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
