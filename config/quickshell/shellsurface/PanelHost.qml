import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root
    required property var hostWindow
    required property var anchorItem

    property string sourceEntryId: ""
    property bool open: sourceEntryId !== ""
    property real openProgress: open ? 1.0 : 0.0
    onSourceEntryIdChanged: syncActiveWidgetState()
    readonly property bool isRailDrawer: sourceEntryId === "performance"
    readonly property bool isCentered: sourceEntryId === "calendar"
                                      || sourceEntryId === "focustime"
                                          || sourceEntryId === "monitors"
                                          || sourceEntryId === "settings"
                                          || sourceEntryId === "power"
    readonly property bool fromRail: ThemeConfig.barRailEnabled
                                     && (sourceEntryId === "battery"
                                         || sourceEntryId === "network"
                                         || sourceEntryId === "volume"
                                         || sourceEntryId === "music"
                                         || sourceEntryId === "focustime"
                                         || sourceEntryId === "monitors"
                                         || sourceEntryId === "performance"
                                         || sourceEntryId === "gaming"
                                         || sourceEntryId === "settings"
                                         || sourceEntryId === "power")
    readonly property bool fromRailBottom: sourceEntryId === "battery"
                                           || sourceEntryId === "network"
                                           || sourceEntryId === "volume"
                                           || sourceEntryId === "power"
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
    readonly property int stripTopH: ThemeConfig.barStatusStripEnabled && !stripOnBottom ? ThemeConfig.barStatusStripHeight : 0
    readonly property int stripBotH: ThemeConfig.barStatusStripEnabled && stripOnBottom ? ThemeConfig.barStatusStripHeight : 0
    // Kwam de trigger uit de bovenstrip? (knop-Y binnen de strip)
    // De launcher groeit vanaf de onderrand omhoog i.p.v. uit een barknop.
    readonly property bool fromBottom: sourceEntryId === "launcher"
    // Alleen panelen met tekstinvoer hebben een focusgrab nodig. Bij de
    // overige panelen zou de grab botsen met de legacy focus-afhandeling
    // in qs_manager.sh en het paneel meteen weer sluiten.
    readonly property bool needsKeyboard: sourceEntryId === "launcher"
    readonly property bool fromStrip: ThemeConfig.barStatusStripEnabled && !stripOnBottom
                                      && anchorY < ThemeConfig.barStatusStripHeight + 4
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

    function panelWidth(entryId) {
        let available = hostWindow ? hostWindow.width : 1920;
        if (entryId === "calendar") return Math.min(1280, available - 48);
        if (entryId === "focustime") return Math.min(560, available - 48);
        if (entryId === "network") return Math.min(680, available - 48);
        if (entryId === "music") return Math.min(600, available - 48);
        if (entryId === "monitors") return Math.min(720, available - 48);
        if (entryId === "performance") return Math.min(360, available - 48);
        if (entryId === "settings") return Math.min(1200, available - 48);
        if (entryId === "gaming") return Math.min(720, available - 48);
        if (entryId === "launcher") return Math.min(620, available - 48);
        if (entryId === "power") return Math.min(360, available - 32);
        if (entryId === "volume") return Math.min(420, available - 32);
        return Math.min(460, available - 32);
    }

    function panelHeight(entryId) {
        let available = hostWindow ? hostWindow.height : 1080;
        if (entryId === "calendar") return Math.min(560, available - 72);
        if (entryId === "focustime") return Math.min(520, available - 72);
        if (entryId === "network") return Math.min(560, available - 72);
        if (entryId === "music") return Math.min(560, available - 72);
        if (entryId === "monitors") return Math.min(540, available - 72);
        if (entryId === "launcher") return Math.min(560, available - 72);
        if (entryId === "power") return Math.min(430, available - 72);
        if (entryId === "volume") return Math.min(460, available - 72);
        if (entryId === "performance") {
            let strip = ThemeConfig.barStatusStripEnabled ? ThemeConfig.barStatusStripHeight : 0;
            return Math.max(280, available - strip);
        }
        if (entryId === "settings") return Math.min(750, available - 72);
        if (entryId === "gaming") return Math.min(560, available - 72);
        return Math.min(620, available - 72);
    }

    function sourceFor(entryId) {
        if (entryId === "launcher") return Qt.resolvedUrl("LauncherPanel.qml");
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
        return "";
    }

    // Positie: geankerd aan de triggerende knop. De rail-drawer (performance)
    // vult de volle hoogte naast de rail; strip-triggers groeien naar beneden
    // vanaf de strip op de knop-X; rail-triggers groeien naar rechts vanaf de
    // railrand op de knop-Y. Positie snapt (geen slide), grootte groeit.
    x: {
        if (!hostWindow) return 12;
        let W = panelWidth(sourceEntryId);
        let leftEdge = (ThemeConfig.barRailEnabled && !railOnRight) ? railW : 0;
        let rightEdge = (ThemeConfig.barRailEnabled && railOnRight) ? hostWindow.width - railW : hostWindow.width - borderW;
        if (sourceEntryId === "settings" || fromBottom)
            return Math.round((leftEdge + rightEdge - W) / 2);
        if (fromStrip)
            return _clamp(anchorX - W / 2, leftEdge + gap, rightEdge - W - gap);
        return railOnRight ? (rightEdge - W - gap) : (leftEdge + gap);
    }
    y: {
        if (!hostWindow) return 12;
        let H = panelHeight(sourceEntryId);
        if (isRailDrawer) return stripTopH;
        // Onderrand vastzetten: naarmate height groeit schuift y omhoog.
        // Vlak tegen de schermrand: de launcher groeit uit de omlijning, dus
        // geen tussenruimte en hij dekt de rand in zijn eigen breedte af.
        if (fromBottom) return hostWindow.height - height;
        if (sourceEntryId === "settings")
            return Math.max(stripTopH + gap, Math.round((hostWindow.height - borderW - H) / 2));
        if (fromStrip) return stripTopH + gap;
        let top = stripTopH + gap;
        let bot = hostWindow.height - H - gap - stripBotH - borderW;
        return _clamp(anchorY - 18, top, Math.max(top, bot));
    }
    width: fromBottom ? panelWidth(sourceEntryId) : (open ? panelWidth(sourceEntryId) : 0)
    height: open ? panelHeight(sourceEntryId) : 0
    clip: true
    visible: open || width > 1 || height > 1
    focus: open
    opacity: openProgress

    Behavior on openProgress {
        NumberAnimation {
            duration: ThemeConfig.durationToken("fast")
            easing.type: ThemeConfig.easingToken("standard")
        }
    }
    Behavior on width {
        enabled: !root.fromBottom
        NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") }
    }
    Behavior on height {
        NumberAnimation {
            duration: ThemeConfig.durationToken("spatial")
            easing.type: root.fromBottom ? ThemeConfig.easingToken("standard") : ThemeConfig.easingToken("emphasized")
        }
    }

    Keys.onEscapePressed: event => {
        root.sourceEntryId = "";
        event.accepted = true;
    }

    // Stable pure-QML panel surface. A future native blob can replace this
    // component without changing the host/entry API.
    PanelBackdrop {
        open: root.open
        mocha: mocha
        squareCorners: root.isRailDrawer
        flushBottom: root.fromBottom
        // De barkleur draagt de bar-transparantie mee; voor een leesbare
        // launcher forceren we vrijwel dekkend.
        fillOverride: root.fromBottom && anchorItem
            ? Qt.rgba(anchorItem.barGradCenter.r, anchorItem.barGradCenter.g,
                      anchorItem.barGradCenter.b, 1.0)
            : "transparent"
        fillStartOverride: root.fromBottom && anchorItem
            ? Qt.rgba(anchorItem.launcherFillLeft.r, anchorItem.launcherFillLeft.g,
                      anchorItem.launcherFillLeft.b, 1.0)
            : "transparent"
        fillEndOverride: root.fromBottom && anchorItem
            ? Qt.rgba(anchorItem.launcherFillRight.r, anchorItem.launcherFillRight.g,
                      anchorItem.launcherFillRight.b, 1.0)
            : "transparent"
        bottomConnectorRadius: root.fromBottom && anchorItem ? anchorItem.cornerR : 0
        bottomConnectorLift: root.fromBottom && anchorItem ? anchorItem.shellBorderWidth : 0
        // Zelfde accentkleur en -dikte als de omlijning, zodat de rand van de
        // launcher de bogen naadloos voortzet.
        borderOverride: root.fromBottom && anchorItem
            ? Qt.rgba(anchorItem.barHueCenter.r, anchorItem.barHueCenter.g,
                      anchorItem.barHueCenter.b, anchorItem.chromeAccentAlpha)
            : "transparent"
        borderStartOverride: root.fromBottom && anchorItem
            ? Qt.rgba(anchorItem.launcherHueLeft.r, anchorItem.launcherHueLeft.g,
                      anchorItem.launcherHueLeft.b, anchorItem.chromeAccentAlpha)
            : "transparent"
        borderEndOverride: root.fromBottom && anchorItem
            ? Qt.rgba(anchorItem.launcherHueRight.r, anchorItem.launcherHueRight.g,
                      anchorItem.launcherHueRight.b, anchorItem.chromeAccentAlpha)
            : "transparent"
    }

    // Content op vaste eindgrootte in de linkerbovenhoek: terwijl de host
    // groeit (0→vol) onthult clip de content i.p.v. hem mee te pletten.
    Loader {
        id: contentLoader
        x: 0
        y: root.fromBottom ? root.height - root.panelHeight(root.sourceEntryId) : 0
        width: root.panelWidth(root.sourceEntryId)
        height: root.panelHeight(root.sourceEntryId)
        active: root.sourceFor(root.sourceEntryId) !== ""
        source: root.sourceFor(root.sourceEntryId)
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
