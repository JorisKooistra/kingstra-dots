import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Kingstra.Blobs 1.0
import ".."

Item {
    id: root
    required property var shellWindow
    required property var mocha

    readonly property bool railEnabled: ThemeConfig.barRailEnabled
    readonly property bool stripEnabled: ThemeConfig.barStatusStripEnabled
    readonly property bool stripControlsEnabled: stripEnabled && !railEnabled
    readonly property bool stripOnBottom: ThemeConfig.barStatusStripEdge === "bottom"
    readonly property bool topHoverHitEnabled: stripEnabled && !stripControlsEnabled && !stripOnBottom
    readonly property int topHoverHitWidth: Math.min(420, Math.max(0, width - railWidth - shellBorderWidth))
    readonly property int topHoverOpenDelay: 500
    readonly property bool railOnRight: ThemeConfig.barRailEdge === "right"
    readonly property int railWidth: ThemeConfig.barRailWidth
    // Als alle statusstrip-content naar de rail is verhuisd, blijft boven alleen
    // de omlijsting over. Die hoort even dun te zijn als de onderrand.
    readonly property int stripHeight: stripControlsEnabled ? ThemeConfig.barStatusStripHeight : shellBorderWidth
    // De rail bezit de volledige zijrand (top→bottom). De strip begint al bij
    // rail.right, dus zonder deze full-height rail bleef er een gat in de
    // hoek waar rail en strip elkaar niet raakten ("de ontbrekende hoek").
    readonly property int railTopOffset: 0
    readonly property int railBottomOffset: 0
    // Dunne omlijning rechts/onder, zodat de content een volledig afgerond
    // kader krijgt (caelestia-stijl). Links/boven kosten al rail+strip.
    readonly property int shellBorderWidth: 8
    // Breedte van de accentband die de blob-shader net binnen de contour
    // tekent. De chrome-vlakken (rail/strip/randen) laten deze strook vrij,
    // anders schilderen ze de lijn van de omlijsting dicht.
    readonly property int frameBandW: 2
    // Binnenhoek van de schermomlijsting. Deze moet dezelfde visuele familie
    // hebben als Hyprland's window rounding; een losse grote radius laat vooral
    // onderin vensterhoeken en framehoeken optisch door elkaar snijden.
    readonly property int cornerR: Math.round(neonStyle
        ? Math.max(1, Math.min(5, Math.max(ThemeConfig.borderRadius, ThemeConfig.styleWidgetRadius)))
        : monoStyle
        ? Math.max(2, Math.min(8, Math.max(ThemeConfig.borderRadius, ThemeConfig.styleWidgetRadius) + frameBandW))
        : Math.max(paperStyle ? 12 : 10,
                   Math.min(organicStyle ? 34 : 20,
                            Math.max(ThemeConfig.borderRadius, ThemeConfig.styleWidgetRadius) + frameBandW)))
    readonly property bool technicalFrameStyle: neonStyle && cornersActive
    readonly property int cornerSeamOverlap: 3
    readonly property string styleFamily: String(ThemeConfig.styleFamily || "").toLowerCase()
    readonly property bool paperStyle: styleFamily === "paper"
    readonly property bool organicStyle: styleFamily === "organic"
    readonly property bool neonStyle: styleFamily === "neon"
    readonly property bool monoStyle: styleFamily === "mono"
    readonly property color paperBase: "#f1e3c6"
    readonly property color paperSurface: "#f6ecd6"
    // --- Matugen multi-color chrome -----------------------------------------
    // De bar leunde voorheen op crust/base (bijna-zwart), waardoor matugen
    // visueel vrijwel niets deed. We tinten nu een donker chrome-oppervlak met
    // twee onderscheiden wallpaper-hues en leggen daar een subtiele
    // twee-kleur-gradient overheen (rail verticaal, strip horizontaal).
    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       1.0);
    }
    function _mix3(a, b, c, t) {
        let k = _clamp01(t);
        return k < 0.5 ? _mix(a, b, k * 2.0) : _mix(b, c, (k - 0.5) * 2.0);
    }
    // Materiaalvloer per familie. Paper mag juist licht en warm lezen; mono
    // blijft vlak en bijna kleurloos; neon/organic mogen op donker tinten.
    readonly property color barFloor: paperStyle ? paperBase
        : (neonStyle || monoStyle ? mocha.crust : mocha.base)
    // De schermrand-chrome zit direct op de wallpaper. Elke transparantie in
    // deze laag laat vooral in de afgeronde schermhoeken de wallpaper-hoek
    // meedoen met de kleur, waardoor de vorm wel klopt maar de hoek alsnog
    // doorschijnt. Popups gebruiken hun eigen opacity; de edge zelf is solid.
    readonly property real barFillAlpha: 1.0
    // Drie stabiele accentrollen: accent1 = primary/cyan, accent2 = warme
    // lucht, accent3 = organisch groen. De *source* samples blijven bruikbaar
    // voor kleurherkomst, maar voor de UI nemen we geharmoniseerde rollen zodat
    // donkere source-kleuren zoals accent3_source niet onzichtbaar worden.
    readonly property color barHueA: monoStyle ? mocha.text
        : (paperStyle ? (mocha.accent2Container || mocha.accent2) : (mocha.accent1 || mocha.primary))
    readonly property color barHueB: monoStyle ? mocha.subtext0
        : (paperStyle ? (mocha.surfaceContainer || mocha.surface1) : (mocha.accent3Container || mocha.accent3))
    readonly property color barHueC: monoStyle ? mocha.overlay0
        : (paperStyle ? (mocha.primaryContainer || mocha.accent1Container) : (mocha.accent2Container || mocha.accent2))
    readonly property real barTintK: monoStyle ? 0.0 : (paperStyle ? 0.055 : (neonStyle ? 0.38 : 0.30))
    readonly property color barGradStart: {
        let c = _mix(barFloor, barHueA, barTintK);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    readonly property color barGradMid: {
        let c = _mix(barFloor, barHueB, barTintK * 1.05);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    readonly property color barGradEnd: {
        let c = _mix(barFloor, barHueC, barTintK * 1.1);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    readonly property color barGradCenter: barGradMid
    readonly property color barHueCenter: barHueB
    readonly property real chromeAccentAlpha: monoStyle ? 0.62 : (paperStyle ? 0.42 : 1.0)

    // Accentrand-kleuren. De rauwe wallpaper-samples (barHueA/B/C) zijn prima
    // als subtiele tint ín de vulling, maar als lijn kunnen ze vrijwel
    // onzichtbaar worden: accent3_source is bij donkere wallpapers al gauw
    // bijna zwart. Voor de rand tillen we daarom elke tint naar een
    // minimum-helderheid, richting wit zodat de tint zelf behouden blijft.
    function _ensureLum(c, minLum) {
        let lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        if (lum >= minLum) return c;
        let t = 1.0 - lum / minLum;
        return Qt.rgba(c.r + (1.0 - c.r) * t,
                       c.g + (1.0 - c.g) * t,
                       c.b + (1.0 - c.b) * t,
                       1.0);
    }
    // Kleur van het schermbrede diagonale verloop op een gegeven punt. De
    // losse chrome-vlakken (rail, strip, randen) tekenen hun eigen verloop
    // met een QML-Gradient, die alleen verticaal of horizontaal kan. Door hun
    // stops op deze functie te baseren volgen ze exact dezelfde diagonaal als
    // de blob eronder, in plaats van elk hun eigen volledige a→b over te doen.
    function _diagColor(x, y) {
        let t = _clamp01((x + y) / Math.max(1, root.width + root.height));
        return root._mix3(root.barGradStart, root.barGradMid, root.barGradEnd, t);
    }

    readonly property real edgeAccentMinLum: paperStyle ? 0.34 : (neonStyle ? 0.68 : 0.55)
    readonly property color edgeAccentA: monoStyle ? mocha.text
        : _ensureLum(paperStyle ? barHueA : (mocha.accent1 || barHueA), edgeAccentMinLum)
    readonly property color edgeAccentB: monoStyle ? mocha.subtext0
        : _ensureLum(paperStyle ? barHueB : (mocha.accent3 || barHueB), edgeAccentMinLum)
    readonly property color edgeAccentC: monoStyle ? mocha.overlay0
        : _ensureLum(paperStyle ? barHueC : (mocha.accent2 || barHueC), edgeAccentMinLum)
    // Geometrie van een paneel dat uit een schermrand groeit. Dit volgt de
    // Caelestia-blobgroep-benadering: de rand en het paneel worden als één
    // samengestelde vorm behandeld in plaats van losse connectorstukjes.
    property bool edgeBlobOpen: false
    property string edgeBlobEdge: ""
    property real edgeBlobProgress: 0
    property real edgeBlobX: 0
    property real edgeBlobY: 0
    property real edgeBlobWidth: 0
    property real edgeBlobHeight: 0
    function _clamp01(v) {
        return Math.max(0.0, Math.min(1.0, Number(v) || 0.0));
    }
    function _easeOutCubic(v) {
        let t = _clamp01(v);
        return 1.0 - Math.pow(1.0 - t, 3);
    }
    readonly property real edgeBlobReveal: _easeOutCubic(edgeBlobProgress)
    readonly property real edgeBlobConnectorOpacity: _clamp01((edgeBlobReveal - 0.08) / 0.74)
    readonly property real edgeBlobConnectorRadius: Math.max(1, cornerR * edgeBlobConnectorOpacity)
    readonly property real edgeBlobCutInset: Math.max(0, edgeBlobWidth * (1.0 - edgeBlobReveal) / 2.0)
    readonly property real edgeBlobCutX: edgeBlobX + edgeBlobCutInset
    readonly property real edgeBlobCutRight: edgeBlobX + edgeBlobWidth - edgeBlobCutInset
    readonly property bool nativeEdgeBlobActive: edgeBlobOpen && edgeBlobEdge !== ""
    function _bottomGradientT(screenX) {
        let w = Math.max(1, root.width - root.railWidth - root.shellBorderWidth);
        return root._clamp01((screenX - root.railWidth) / w);
    }
    function _bottomAccentT(screenX) {
        let x0 = root.railWidth + root.cornerR;
        let w = Math.max(1, root.width - root.railWidth - root.shellBorderWidth - root.cornerR * 2);
        return root._clamp01((screenX - x0) / w);
    }
    function _stripFillAt(screenX) {
        let w = Math.max(1, root.width - root.railWidth);
        return root._mix3(root.barGradStart, root.barGradMid, root.barGradEnd, root._clamp01((screenX - root.railWidth) / w));
    }
    function _railFillAt(screenY) {
        return root._mix3(root.barGradStart, root.barGradMid, root.barGradEnd, root._clamp01(screenY / Math.max(1, root.height)));
    }
    function _rightFillAt(screenY) {
        let h = Math.max(1, root.height - root.stripHeight);
        return root._mix3(root.barGradEnd, root.barGradMid, root.barGradStart, root._clamp01((screenY - root.stripHeight) / h));
    }
    function _bottomFillAt(screenX) {
        return root._mix3(root.barGradEnd, root.barGradMid, root.barGradStart, root._bottomGradientT(screenX));
    }
    function _stripHueAt(screenX) {
        let x0 = root.railWidth + root.cornerR;
        let w = Math.max(1, root.width - root.railWidth - root.shellBorderWidth - root.cornerR * 2);
        return root._mix3(root.barHueA, root.barHueB, root.barHueC, root._clamp01((screenX - x0) / w));
    }
    function _railHueAt(screenY) {
        let y0 = root.stripHeight + root.cornerR;
        let h = Math.max(1, root.height - root.stripHeight - root.shellBorderWidth - root.cornerR * 2);
        return root._mix3(root.barHueA, root.barHueB, root.barHueC, root._clamp01((screenY - y0) / h));
    }
    function _rightHueAt(screenY) {
        let y0 = root.stripHeight + root.cornerR;
        let h = Math.max(1, root.height - root.stripHeight - root.shellBorderWidth - root.cornerR * 2);
        return root._mix3(root.barHueC, root.barHueB, root.barHueA, root._clamp01((screenY - y0) / h));
    }
    function _bottomHueAt(screenX) {
        return root._mix3(root.barHueC, root.barHueB, root.barHueA, root._bottomAccentT(screenX));
    }
    readonly property color edgeBlobFillLeft: _bottomFillAt(edgeBlobX)
    readonly property color edgeBlobFillRight: _bottomFillAt(edgeBlobX + edgeBlobWidth)
    readonly property color edgeBlobHueLeft: _bottomHueAt(edgeBlobX)
    readonly property color edgeBlobHueRight: _bottomHueAt(edgeBlobX + edgeBlobWidth)
    readonly property color edgeBlobFillStart: {
        if (edgeBlobEdge === "left") return _railFillAt(edgeBlobY);
        if (edgeBlobEdge === "right") return _rightFillAt(edgeBlobY);
        if (edgeBlobEdge === "top") return _stripFillAt(edgeBlobX);
        return _bottomFillAt(edgeBlobX);
    }
    readonly property color edgeBlobFillEnd: {
        if (edgeBlobEdge === "left") return _railFillAt(edgeBlobY + edgeBlobHeight);
        if (edgeBlobEdge === "right") return _rightFillAt(edgeBlobY + edgeBlobHeight);
        if (edgeBlobEdge === "top") return _stripFillAt(edgeBlobX + edgeBlobWidth);
        return _bottomFillAt(edgeBlobX + edgeBlobWidth);
    }
    readonly property color edgeBlobFillMid: {
        if (edgeBlobEdge === "left") return _railFillAt(edgeBlobY + edgeBlobHeight / 2);
        if (edgeBlobEdge === "right") return _rightFillAt(edgeBlobY + edgeBlobHeight / 2);
        if (edgeBlobEdge === "top") return _stripFillAt(edgeBlobX + edgeBlobWidth / 2);
        return _bottomFillAt(edgeBlobX + edgeBlobWidth / 2);
    }
    readonly property color edgeBlobHueStart: {
        if (edgeBlobEdge === "left") return _railHueAt(edgeBlobY);
        if (edgeBlobEdge === "right") return _rightHueAt(edgeBlobY);
        if (edgeBlobEdge === "top") return _stripHueAt(edgeBlobX);
        return _bottomHueAt(edgeBlobX);
    }
    readonly property color edgeBlobHueEnd: {
        if (edgeBlobEdge === "left") return _railHueAt(edgeBlobY + edgeBlobHeight);
        if (edgeBlobEdge === "right") return _rightHueAt(edgeBlobY + edgeBlobHeight);
        if (edgeBlobEdge === "top") return _stripHueAt(edgeBlobX + edgeBlobWidth);
        return _bottomHueAt(edgeBlobX + edgeBlobWidth);
    }
    readonly property bool edgeBlobGradientVertical: edgeBlobEdge === "left" || edgeBlobEdge === "right"
    readonly property var edgeBlobGroup: cornersActive ? nativeBlobGroup : null

    readonly property color panelColor: {
        if (paperStyle) {
            let p = _mix(paperSurface, barHueA, 0.055);
            return Qt.rgba(p.r, p.g, p.b, 1.0);
        }
        if (monoStyle) return Qt.rgba(barFloor.r, barFloor.g, barFloor.b, 1.0);
        let c = _mix(barFloor, barHueCenter, barTintK * 0.6);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    readonly property color pillColor: {
        if (paperStyle) {
            let p = _mix(paperBase, mocha.text, 0.055);
            return Qt.rgba(p.r, p.g, p.b, 0.92);
        }
        if (neonStyle) return Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.72);
        if (monoStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06);
        return Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58);
    }
    readonly property color pillHoverColor: {
        if (paperStyle) return Qt.rgba(barHueA.r, barHueA.g, barHueA.b, 0.24);
        if (neonStyle) return Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.34);
        if (monoStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.14);
        return Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, paperStyle ? 0.64 : 0.86);
    }
    readonly property color borderColor: {
        if (paperStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.24);
        if (neonStyle) return Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.58);
        if (monoStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.34);
        return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06 + ThemeConfig.styleOutlineStrength);
    }
    readonly property color hotColor: {
        if (monoStyle) return mocha.text;
        if (neonStyle) return mocha.teal;
        if (paperStyle) return mocha.accent2Container;
        return mocha.accent2;
    }
    // --- Special workspaces (scratchpads: spotify, discord, ...) -------------
    // Hyprland geeft deze een negatieve id en de naam "special:<naam>". De
    // interne qs-master overlay laten we bewust weg.
    readonly property var specialWorkspaces: {
        let out = [];
        let list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            let n = String(list[i].name || "");
            if (n.indexOf("special:") !== 0) continue;
            let short = n.substring(8);
            if (short === "qs-master" || short === "") continue;
            out.push({ wsName: short, windows: list[i].toplevels.values.length });
        }
        out.sort((a, b) => a.wsName < b.wsName ? -1 : 1);
        return out;
    }
    // Welke special workspace staat open op de gefocuste monitor?
    readonly property string activeSpecial: {
        let m = Hyprland.focusedMonitor;
        if (!m || !m.lastIpcObject) return "";
        let sw = m.lastIpcObject.specialWorkspace;
        if (!sw || !sw.name) return "";
        let n = String(sw.name);
        return n.indexOf("special:") === 0 ? n.substring(8) : n;
    }

    function specialIcon(name) {
        if (name === "spotify") return "\uf1bc";
        if (name === "discord") return "\udb81\ude6f";
        return "\udb81\udcfe";
    }

    function toggleSpecial(name) {
        Quickshell.execDetached(["bash", "-lc", "hyprctl dispatch togglespecialworkspace " + name]);
    }

    readonly property Item railHitRegion: railHitArea
    readonly property Item stripHitRegion: stripHitArea
    readonly property Item topHoverHitRegion: topHoverHitArea
    readonly property bool topHoverHovered: topHover.hovered
    property string activeMode: "office"
    property var moduleList: ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications", "mail"]
    property bool barAutoHide: false
    property bool autoHideVisible: true
    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "ddd d MMM")
    property int volumeWheelAccumulator: 0
    property int workspaceWheelAccumulator: 0
    property int _volRaw: 0
    property bool isMuted: false
    property int updateCount: 0
    property int packageUpdateCount: 0
    property int flatpakUpdateCount: 0
    property int dotfilesUpdateCount: 0
    property int dotfilesCommitCount: 0
    readonly property bool railContentVisible: !barAutoHide || autoHideVisible || railHover.hovered
    readonly property bool stripContentVisible: !barAutoHide || autoHideVisible || stripHover.hovered
    // Anker van de laatst getriggerde knop (host-coords), zodat panelen uit
    // de knop groeien i.p.v. uit een vaste schermhoek.
    property real lastTriggerX: 0
    property real lastTriggerY: 0
    signal panelRequested(string sourceEntryId, real anchorX, real anchorY)
    signal panelCloseRequested(string sourceEntryId)

    function _defaultModules(mode) {
        if (mode === "gaming") return ["workspaces", "cpu_temp", "gpu_temp", "ram_usage", "fps", "battery", "volume", "game_launcher", "clock"];
        if (mode === "media")  return ["volume", "brightness", "media_controls", "battery", "clock"];
        return ["workspaces", "clock", "updates", "cpu_temp", "ram_usage", "network", "battery", "volume", "bluetooth", "notifications", "mail"];
    }

    function _normalizeModules(mode, modules) {
        let normalized = Array.isArray(modules) ? modules.slice() : [];
        if (mode === "office" && normalized.indexOf("updates") === -1) normalized.push("updates");
        if (mode === "office" && normalized.indexOf("cpu_temp") === -1) normalized.push("cpu_temp");
        if (mode === "office" && normalized.indexOf("mail") === -1) normalized.push("mail");
        if ((mode === "office" || mode === "gaming" || mode === "media")
                && normalized.indexOf("battery") === -1) {
            normalized.push("battery");
        }
        return normalized;
    }

    function moduleEnabled(name) {
        return Array.isArray(moduleList) && moduleList.indexOf(name) !== -1;
    }

    function anyModuleEnabled(names) {
        for (let i = 0; i < names.length; i++) {
            if (moduleEnabled(names[i])) return true;
        }
        return false;
    }

    function applyModeState(rawText) {
        if (!rawText) return;
        try {
            let m = JSON.parse(rawText);
            let mode = m.name || "office";
            let resolvedModules = (m.modules && m.modules.length > 0)
                ? m.modules
                : root._defaultModules(mode);
            root.activeMode = mode;
            root.moduleList = root._normalizeModules(mode, resolvedModules);
            root.barAutoHide = m.bar_autohide === true;
            root.autoHideVisible = true;
            if (root.barAutoHide) autoHideTimer.restart();
            else autoHideTimer.stop();
        } catch(e) {}
    }

    function togglePanel(target) {
        panelRequested(target, lastTriggerX, lastTriggerY);
    }

    function updateTooltip() {
        if (updatesPoller.running) return "Updates controleren…";
        let dotfilesText = dotfilesUpdateCount > 0
            ? "ja (" + dotfilesCommitCount + " commit" + (dotfilesCommitCount === 1 ? "" : "s") + ")"
            : "nee";
        return updateCount + " updates · Arch/AUR " + packageUpdateCount
            + " · Flatpak " + flatpakUpdateCount
            + " · dotfiles " + dotfilesText;
    }

    function openUpdatesTerminal() {
        let script = Quickshell.env("HOME") + "/.config/quickshell/package_upgrade.sh";
        Quickshell.execDetached(["kitty", "--hold", "bash", script]);
        Quickshell.execDetached(["notify-send", "Updates", "Updateworkflow gestart in terminal"]);
    }

    function launchWalker() {
        Quickshell.execDetached(["bash", "-lc", "walker"]);
    }

    function switchWorkspace(wsId) {
        Quickshell.execDetached([
            "bash",
            "-lc",
            Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh " + wsId
        ]);
    }

    function handleWorkspaceWheel(deltaY, workspaceCount) {
        if (!deltaY || deltaY === 0) return;
        root.workspaceWheelAccumulator += deltaY;
        let steps = 0;
        while (root.workspaceWheelAccumulator >= 120) { steps -= 1; root.workspaceWheelAccumulator -= 120; }
        while (root.workspaceWheelAccumulator <= -120) { steps += 1; root.workspaceWheelAccumulator += 120; }
        if (steps === 0) return;

        let monitor = root.shellWindow && root.shellWindow.screen ? root.shellWindow.screen.name : "";
        Quickshell.execDetached([
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-scroll-monitor.sh",
            monitor,
            steps > 0 ? "next" : "prev",
            String(Math.max(1, workspaceCount || 8)),
            String(Math.abs(steps))
        ]);
    }

    function handleVolumeWheel(deltaY) {
        if (!deltaY || deltaY === 0) return;
        root.volumeWheelAccumulator += deltaY;
        let steps = 0;
        while (root.volumeWheelAccumulator >= 120) { steps += 1; root.volumeWheelAccumulator -= 120; }
        while (root.volumeWheelAccumulator <= -120) { steps -= 1; root.volumeWheelAccumulator += 120; }
        if (steps === 0) return;

        Quickshell.execDetached([
            "bash",
            "-lc",
            steps > 0
                ? "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + steps + "%+"
                : "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.abs(steps) + "%-"
        ]);
        if (!volPoller.running) volPoller.running = true;
    }

    FileView {
        id: modeFileView
        path: Quickshell.env("HOME") + "/.config/kingstra/state/mode.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.applyModeState(__text)
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: modeFileView.reload()
    }

    Timer {
        id: autoHideTimer
        interval: 2400
        repeat: false
        onTriggered: if (root.barAutoHide && !railHover.hovered && !stripHover.hovered) root.autoHideVisible = false
    }

    readonly property bool hasWifi: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return true;
        }
        return false;
    }
    readonly property bool isWifiOn: {
        if (!Networking.wifiEnabled) return false;
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi && devs[i].connected) return true;
        }
        return false;
    }
    readonly property bool isEthConnected: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wired && devs[i].connected) return true;
        }
        return false;
    }
    readonly property bool hasBluetooth: Bluetooth.defaultAdapter !== null
    readonly property bool isBtOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    readonly property int batCap: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isSoundActive: !isMuted && _volRaw > 0
    readonly property string volPercent: _volRaw + "%"
    readonly property string volIcon: {
        if (isMuted || _volRaw === 0) return "󰝟";
        if (_volRaw >= 70) return "󰕾";
        if (_volRaw >= 30) return "󰖀";
        return "󰕿";
    }
    readonly property var activePlayer: {
        var players = Mpris.players.values;
        var playingWithTitle = null;
        var playingAny = null;
        var pausedWithTitle = null;
        var pausedAny = null;

        for (var i = 0; i < players.length; i++) {
            var player = players[i];
            var title = String(player.trackTitle || "").trim();
            var hasTitle = title !== "";

            if (player.playbackState === MprisPlaybackState.Playing) {
                if (playingAny === null) playingAny = player;
                if (hasTitle && playingWithTitle === null) playingWithTitle = player;
                continue;
            }

            if (player.playbackState === MprisPlaybackState.Paused) {
                if (pausedAny === null) pausedAny = player;
                if (hasTitle && pausedWithTitle === null) pausedWithTitle = player;
            }
        }

        if (playingWithTitle !== null) return playingWithTitle;
        if (playingAny !== null) return playingAny;
        if (pausedWithTitle !== null) return pausedWithTitle;
        if (pausedAny !== null) return pausedAny;

        for (var j = 0; j < players.length; j++) {
            if (String(players[j].trackTitle || "").trim() !== "") return players[j];
        }

        return players.length > 0 ? players[0] : null;
    }
    readonly property bool mediaVisible: activePlayer !== null
        && (activePlayer.playbackState !== MprisPlaybackState.Stopped
            || ((activePlayer.canTogglePlaying || activePlayer.canPlay)
                && (String(activePlayer.trackTitle || "").trim() !== ""
                    || String(activePlayer.identity || "").trim() !== "")))

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date();
            let nextTimeText = Qt.formatDateTime(now, "HH:mm");
            let nextDateText = Qt.formatDateTime(now, "ddd d MMM");
            if (nextTimeText !== root.timeText) root.timeText = nextTimeText;
            if (nextDateText !== root.dateText) root.dateText = nextDateText;
        }
    }

    Process {
        id: volPoller
        command: ["bash", "-lc", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let line = this.text.trim();
                let match = line.match(/Volume:\s+([\d.]+)/);
                if (match) root._volRaw = Math.round(parseFloat(match[1]) * 100);
                root.isMuted = line.indexOf("[MUTED]") !== -1;
            }
        }
    }

    Process {
        id: updatesPoller
        command: [
            "bash",
            Quickshell.env("HOME") + "/.config/quickshell/package_updates.sh",
            "--json"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                try {
                    let state = JSON.parse(raw);
                    root.updateCount = Math.max(0, parseInt(state.total) || 0);
                    root.packageUpdateCount = Math.max(0, parseInt(state.packages) || 0);
                    root.flatpakUpdateCount = Math.max(0, parseInt(state.flatpak) || 0);
                    root.dotfilesUpdateCount = Math.max(0, parseInt(state.dotfiles) || 0);
                    root.dotfilesCommitCount = Math.max(0, parseInt(state.dotfiles_commits) || 0);
                } catch (e) {
                    let total = parseInt(raw);
                    if (!isNaN(total) && total >= 0) root.updateCount = total;
                }
            }
        }
    }

    // De checker zelf cachet netwerkresultaten 5–15 minuten. Deze lichte poll
    // leest iedere minuut ook snel een nieuwe cache in nadat de terminalrunner
    // klaar is.
    Timer {
        interval: 60000
        running: root.moduleEnabled("updates")
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!updatesPoller.running) updatesPoller.running = true
    }

    BlobGroup {
        id: nativeBlobGroup
        color: root.barGradCenter
        // Eén verloop over het volle scherm, gedeeld door de omlijsting en elk
        // paneel. Eerder wisselde de groep van verloop zodra er een paneel
        // openging en berekende elk paneel zijn eigen start/eind-kleur; dan
        // volgt het verloop de omhulzing i.p.v. het scherm en sluit een blob
        // qua kleur niet aan op de rand waar hij uit groeit. De shader sampelt
        // op scene-positie, dus origin/span zijn schermcoördinaten.
        gradientStart: root.barGradStart
        // Drie accentrollen in één schermbreed verloop: accent1/cyan,
        // accent3/groen en accent2/warm. Dit houdt de wallpaper-kleuren
        // herkenbaar zonder dat één rode luchtkleur de hele chrome overneemt.
        gradientMid: root.barGradMid
        gradientEnd: root.barGradEnd
        // Diagonaal verloop over het volle scherm: langs de as linksboven →
        // rechtsonder gaat de kleur van a naar b, en elke lijn loodrecht
        // daarop (de andere diagonaal) houdt exact één kleur. De span is de
        // projectie van de schermdiagonaal op die richting.
        gradientDirection: Qt.point(0.7071, 0.7071)
        gradientOrigin: 0
        gradientSpan: Math.max(1, (root.width + root.height) * 0.7071)
        // De accentrand wordt in dezelfde SDF getekend als de vulling, dus hij
        // loopt automatisch om de samengesmolten vorm van omlijsting + panelen
        // heen. Losse Canvas-outlines per paneel konden in de hoeken nooit
        // naadloos aansluiten en lieten daar een open kant achter.
        // Zelfde driepunts-opzet als de vulling, maar met opgelichte
        // accentrand-kleuren zodat ook donkere derde kleuren zichtbaar blijven.
        borderStart: Qt.rgba(root.edgeAccentA.r, root.edgeAccentA.g, root.edgeAccentA.b, root.chromeAccentAlpha)
        borderMid: Qt.rgba(root.edgeAccentB.r, root.edgeAccentB.g, root.edgeAccentB.b, root.chromeAccentAlpha)
        borderEnd: Qt.rgba(root.edgeAccentC.r, root.edgeAccentC.g, root.edgeAccentC.b, root.chromeAccentAlpha)
        borderWidth: root.frameBandW
        smoothing: Math.max(18, root.cornerR)
        cornerFill: true
    }

    // De omlijstings-blob zelf staat bewust niet hier maar als aparte laag
    // onder de panelhost in ShellSurface: hij vloeit met de SDF-blend een eind
    // naar binnen uit, en zou vanuit deze (hoger liggende) chrome over de
    // paneelinhoud heen tekenen. Zie frameBlobLayer daar.

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: if (!volPoller.running) volPoller.running = true
    }

    Item {
        id: railHitArea
        visible: root.railEnabled
        anchors.top: parent.top
        anchors.topMargin: root.railTopOffset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.railBottomOffset
        anchors.left: root.railOnRight ? undefined : parent.left
        anchors.right: root.railOnRight ? parent.right : undefined
        width: root.railEnabled ? root.railWidth : 0

        HoverHandler {
            id: railHover
            onHoveredChanged: {
                if (hovered) {
                    root.autoHideVisible = true;
                } else if (root.barAutoHide) {
                    autoHideTimer.restart();
                }
            }
        }
    }

    Item {
        id: topHoverHitArea

        visible: root.topHoverHitEnabled
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.topHoverHitEnabled ? root.topHoverHitWidth : 0
        height: root.topHoverHitEnabled ? Math.max(root.shellBorderWidth, 8) : 0
        z: 30

        Timer {
            id: topHoverOpenTimer
            interval: root.topHoverOpenDelay
            repeat: false
            onTriggered: {
                if (!topHover.hovered) return;
                root.lastTriggerX = root.width / 2;
                root.lastTriggerY = 0;
                root.panelRequested("tophover", root.lastTriggerX, root.lastTriggerY);
            }
        }

        HoverHandler {
            id: topHover
            onHoveredChanged: {
                if (hovered) {
                    topHoverOpenTimer.restart();
                } else {
                    topHoverOpenTimer.stop();
                    root.panelCloseRequested("tophover");
                }
            }
        }
    }

    Rectangle {
        id: rail
        visible: root.railEnabled
        anchors.fill: railHitArea
        // De blob-shader tekent de accentband op de binnenrand van de
        // omlijsting; laat die strook vrij in plaats van hem dicht te verven.
        anchors.rightMargin: root.cornersActive && !root.railOnRight ? root.frameBandW : 0
        anchors.leftMargin: root.cornersActive && root.railOnRight ? root.frameBandW : 0
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root._diagColor(root.railWidth / 2, 0) }
            GradientStop { position: 1.0; color: root._diagColor(root.railWidth / 2, root.height) }
        }
        border.width: 0
        opacity: root.railContentVisible ? 1 : 0.82
        transform: Translate {
            id: railSlide
            x: root.railContentVisible ? 0 : (root.railOnRight ? root.railWidth - 7 : -root.railWidth + 7)
            Behavior on x {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
        }

        // Accent-spine: drie wallpaper-hues over de binnenrand van de rail.
        Rectangle {
            visible: !root.cornersActive
            width: 2
            anchors.top: parent.top
            // Boven de strip is dit een interne naad, geen buitenrand; daar
            // hoort geen lijn. De boog neemt het hoekstuk voor zijn rekening.
            anchors.topMargin: root.cornersActive ? root.stripHeight + root.cornerR - root.cornerSeamOverlap : 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.cornersActive ? root.shellBorderWidth + root.cornerR - root.cornerSeamOverlap : 0
            anchors.left: root.railOnRight ? parent.left : undefined
            anchors.right: root.railOnRight ? undefined : parent.right
            opacity: root.chromeAccentAlpha
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.barHueA }
                GradientStop { position: 0.5; color: root.barHueB }
                GradientStop { position: 1.0; color: root.barHueC }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 7

            RailButton { tooltip: "Launcher";
                icon: "󰣇"
                accent: root.hotColor
                onTriggered: root.togglePanel("launcher")
            }

            RailButton {
                tooltip: root.moduleEnabled("clock") ? root.dateText : "Agenda"
                visible: root.moduleEnabled("clock")
                icon: "󰃰"
                text: root.timeText
                accent: root.mocha.accent1
                onTriggered: root.togglePanel("calendar")
            }

            RailButton {
                tooltip: "Meldingen"
                visible: root.moduleEnabled("notifications")
                icon: "󰍜"
                accent: root.mocha.accent2
                onTriggered: root.togglePanel("notifications")
            }

            RailButton {
                tooltip: MailService.statusText
                visible: root.moduleEnabled("mail")
                icon: "󰇮"
                text: MailService.badgeText
                accent: MailService.unreadKnown && MailService.unreadCount > 0 ? root.mocha.accent2 : root.mocha.accent1
                onTriggered: root.togglePanel("mail")
            }

            RailButton {
                tooltip: "Media"
                visible: root.mediaVisible
                icon: "󰎆"
                accent: root.mocha.accent3
                onTriggered: root.togglePanel("music")
            }

            ColumnLayout {
                visible: root.moduleEnabled("workspaces")
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool active: Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool occupied: {
                            var list = Hyprland.workspaces.values;
                            for (var i = 0; i < list.length; i++) {
                                if (list[i].id === wsId && list[i].toplevels.values.length > 0) return true;
                            }
                            return false;
                        }
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
                        color: active ? root.hotColor
                            : (wsMouse.containsMouse ? root.pillHoverColor
                                : (occupied ? root.pillColor : "transparent"))
                        border.width: active || occupied ? 0 : 1
                        border.color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.14)
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: wsId
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: 12
                            font.weight: active ? Font.Black : Font.Bold
                            color: active ? root.mocha.base : root.mocha.text
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.switchWorkspace(wsId)
                            onWheel: (wheel) => {
                                root.handleWorkspaceWheel(wheel.angleDelta.y, 8);
                                wheel.accepted = true;
                            }
                        }
                    }
                }
            }

            // Special workspaces (scratchpads) — alleen tonen als ze bestaan.
            ColumnLayout {
                visible: root.specialWorkspaces.length > 0
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.14)
                }

                Repeater {
                    model: root.specialWorkspaces
                    delegate: Rectangle {
                        id: spPill
                        required property var modelData
                        readonly property bool active: root.activeSpecial === modelData.wsName
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
                        color: active ? root.hotColor
                            : (spMouse.containsMouse ? root.pillHoverColor : root.pillColor)
                        scale: spMouse.containsMouse ? 1.07 : 1.0
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.specialIcon(spPill.modelData.wsName)
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 14
                            color: spPill.active ? root.mocha.base : root.mocha.text
                        }

                        MouseArea {
                            id: spMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.showTooltip(spPill, spPill.modelData.wsName, true)
                            onExited: root.hideTooltip(spPill.modelData.wsName)
                            onClicked: root.toggleSpecial(spPill.modelData.wsName)
                        }
                    }
                }
            }

            RailButton { tooltip: "Focus";
                visible: root.activeMode === "office" || root.moduleEnabled("focus")
                icon: "󰥔"
                accent: root.mocha.accent1
                onTriggered: root.togglePanel("focustime")
            }

            RailButton { tooltip: "Systeem";
                visible: root.anyModuleEnabled(["cpu_temp", "gpu_temp", "ram_usage", "fps"])
                icon: "󰍛"
                accent: root.mocha.accent1
                onTriggered: root.togglePanel("performance")
            }

            RailButton {
                tooltip: root.updateTooltip()
                visible: root.moduleEnabled("updates")
                icon: "󰚰"
                text: root.updateCount.toString()
                accent: root.updateCount > 0 ? root.mocha.yellow : root.mocha.subtext0
                onTriggered: root.openUpdatesTerminal()
            }

            RailButton {
                tooltip: "Monitoren"
                visible: root.anyModuleEnabled(["cpu_temp", "gpu_temp", "ram_usage", "fps", "brightness"])
                icon: "󰍹"
                accent: root.mocha.accent3
                onTriggered: root.togglePanel("monitors")
            }

            RailButton {
                tooltip: "Games"
                visible: root.moduleEnabled("game_launcher")
                icon: "󰊴"
                accent: root.mocha.accent2
                onTriggered: root.togglePanel("gaming")
            }

            Item { Layout.fillHeight: true }

            RailButton { tooltip: "Netwerk";
                visible: root.moduleEnabled("network") && root.hasWifi
                icon: root.isWifiOn ? "󰤨" : "󰤮"
                accent: root.isWifiOn ? root.mocha.accent3 : root.mocha.subtext0
                onTriggered: root.togglePanel("network")
            }
            RailButton { tooltip: "Bedraad netwerk";
                visible: root.moduleEnabled("network") && !root.hasWifi && root.isEthConnected
                icon: "󰈀"
                accent: root.mocha.accent3
                onTriggered: {
                    Quickshell.execDetached(["bash", "-lc", "printf eth > /tmp/qs_network_mode"]);
                    root.togglePanel("network");
                }
            }
            RailButton { tooltip: "Bluetooth";
                visible: root.moduleEnabled("bluetooth") && root.hasBluetooth
                icon: root.isBtOn ? "󰂱" : "󰂲"
                accent: root.isBtOn ? root.mocha.accent3 : root.mocha.subtext0
                onTriggered: {
                    Quickshell.execDetached(["bash", "-lc", "printf bt > /tmp/qs_network_mode"]);
                    root.togglePanel("network");
                }
            }
            RailButton { tooltip: "Volume";
                visible: root.moduleEnabled("volume")
                icon: root.volIcon
                text: root.volPercent
                accent: root.isSoundActive ? root.mocha.accent3 : root.mocha.subtext0
                onTriggered: root.togglePanel("volume")
                onWheelDelta: (delta) => root.handleVolumeWheel(delta)
            }
            RailButton { tooltip: "Batterij";
                visible: root.moduleEnabled("battery") && root.hasBattery
                icon: "󰁹"
                text: root.batCap + "%"
                accent: root.mocha.accent2
                onTriggered: root.togglePanel("battery")
            }
            RailButton { tooltip: "Afsluitmenu";
                icon: "󰐥"
                accent: root.mocha.red
                onTriggered: root.togglePanel("power")
            }
            RailButton { tooltip: "Instellingen";
                visible: root.activeMode !== "media"
                icon: "󰒓"
                accent: root.mocha.subtext1
                onTriggered: root.togglePanel("settings")
            }
        }
    }

    Item {
        id: statusStripZone
        visible: root.stripEnabled
        anchors.top: root.stripOnBottom ? undefined : parent.top
        anchors.bottom: root.stripOnBottom ? parent.bottom : undefined
        anchors.left: root.railEnabled && !root.railOnRight ? rail.right : parent.left
        anchors.right: root.railEnabled && root.railOnRight ? rail.left : parent.right
        height: root.stripHeight

        Item {
            id: stripHitArea
            visible: root.stripControlsEnabled
            anchors.left: root.stripControlsEnabled ? parent.left : undefined
            anchors.right: root.stripControlsEnabled ? parent.right : undefined
            anchors.top: root.stripControlsEnabled ? parent.top : undefined
            anchors.bottom: root.stripControlsEnabled ? parent.bottom : undefined
            width: root.stripControlsEnabled ? parent.width : 0
            height: root.stripControlsEnabled ? parent.height : 0

            HoverHandler {
                id: stripHover
                onHoveredChanged: {
                    if (hovered) {
                        root.autoHideVisible = true;
                    } else if (root.barAutoHide) {
                        autoHideTimer.restart();
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            // Zelfde als bij de rail: de accentband van de shader vrijlaten.
            anchors.bottomMargin: root.cornersActive && !root.stripOnBottom ? root.frameBandW : 0
            anchors.topMargin: root.cornersActive && root.stripOnBottom ? root.frameBandW : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root._diagColor(0, root.stripHeight / 2) }
                GradientStop { position: 1.0; color: root._diagColor(root.width, root.stripHeight / 2) }
            }
            border.width: 0
            opacity: root.stripContentVisible ? 1 : 0.84
            transform: Translate {
                id: stripSlide
                y: root.stripContentVisible ? 0 : (root.stripOnBottom ? root.stripHeight - 6 : -root.stripHeight + 6)
                Behavior on y {
                    NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
            }

            // Accent-lijn: drie wallpaper-hues over de buitenrand van de strip.
            Rectangle {
                visible: !root.cornersActive
                height: 2
                anchors.left: parent.left
                anchors.leftMargin: root.cornersActive ? root.cornerR - root.cornerSeamOverlap : 0
                anchors.right: parent.right
                anchors.rightMargin: root.cornersActive ? root.shellBorderWidth + root.cornerR - root.cornerSeamOverlap : 0
                anchors.top: root.stripOnBottom ? parent.top : undefined
                anchors.bottom: root.stripOnBottom ? undefined : parent.bottom
                opacity: root.chromeAccentAlpha
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.barHueA }
                    GradientStop { position: 0.5; color: root.barHueB }
                    GradientStop { position: 1.0; color: root.barHueC }
                }
            }

            RowLayout {
                visible: root.stripControlsEnabled
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.railEnabled || !root.moduleEnabled("workspaces") ? 0 : 8
                    delegate: Rectangle {
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool active: Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool occupied: {
                            var list = Hyprland.workspaces.values;
                            for (var i = 0; i < list.length; i++) {
                                if (list[i].id === wsId && list[i].toplevels.values.length > 0) return true;
                            }
                            return false;
                        }
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 24
                        radius: Math.min(6, ThemeConfig.styleWidgetRadius)
                        color: active ? root.hotColor
                            : (stripWsMouse.containsMouse ? root.pillHoverColor
                                : (occupied ? root.pillColor : "transparent"))
                        border.width: active || occupied ? 0 : 1
                        border.color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.14)
                        Text {
                            anchors.centerIn: parent
                            text: wsId
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: 11
                            font.weight: active ? Font.Black : Font.Bold
                            color: active ? root.mocha.base : root.mocha.text
                        }
                        MouseArea {
                            id: stripWsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.switchWorkspace(wsId)
                            onWheel: (wheel) => {
                                root.handleWorkspaceWheel(wheel.angleDelta.y, 8);
                                wheel.accepted = true;
                            }
                        }
                    }
                }
                StripButton { tooltip: "Meldingen"; visible: root.moduleEnabled("notifications"); icon: "󰍜"; accent: root.mocha.accent2; onTriggered: root.togglePanel("notifications") }
                StripButton { tooltip: MailService.statusText; visible: root.moduleEnabled("mail"); icon: "󰇮"; accent: MailService.unreadKnown && MailService.unreadCount > 0 ? root.mocha.accent2 : root.mocha.accent1; onTriggered: root.togglePanel("mail") }
                StripButton { tooltip: "Agenda"; visible: root.moduleEnabled("clock"); icon: "󰃰"; accent: root.mocha.accent1; onTriggered: root.togglePanel("calendar") }
                StripButton { tooltip: root.updateTooltip(); visible: root.moduleEnabled("updates"); icon: "󰚰"; text: root.updateCount.toString(); accent: root.updateCount > 0 ? root.mocha.yellow : root.mocha.subtext0; onTriggered: root.openUpdatesTerminal() }
                StripButton { tooltip: "Monitoren"; visible: root.anyModuleEnabled(["cpu_temp", "gpu_temp", "ram_usage", "fps", "brightness"]); icon: "󰍹"; accent: root.mocha.accent3; onTriggered: root.togglePanel("monitors") }
                StripButton { tooltip: "Games"; visible: root.moduleEnabled("game_launcher"); icon: "󰊴"; accent: root.mocha.accent2; onTriggered: root.togglePanel("gaming") }
            }

            RowLayout {
                anchors.centerIn: parent
                visible: root.stripControlsEnabled && root.moduleEnabled("clock")
                spacing: 10
                Text {
                    text: root.timeText
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 15
                    font.weight: Font.Black
                    color: root.hotColor
                    horizontalAlignment: Text.AlignRight
                }
                Rectangle {
                    width: 1
                    height: 16
                    color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.18)
                }
                Text {
                    text: root.dateText
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: root.mocha.subtext0
                    horizontalAlignment: Text.AlignLeft
                }
            }

            RowLayout {
                visible: root.stripControlsEnabled
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MediaPill {}

                StripButton { tooltip: "Netwerk";
                    visible: !root.railEnabled && root.moduleEnabled("network") && root.hasWifi
                    icon: root.isWifiOn ? "󰤨" : "󰤮"
                    accent: root.isWifiOn ? root.mocha.accent3 : root.mocha.subtext0
                    onTriggered: root.togglePanel("network")
                }
                StripButton { tooltip: "Bedraad netwerk";
                    visible: !root.railEnabled && root.moduleEnabled("network") && !root.hasWifi && root.isEthConnected
                    icon: "󰈀"
                    accent: root.mocha.accent3
                    onTriggered: {
                        Quickshell.execDetached(["bash", "-lc", "printf eth > /tmp/qs_network_mode"]);
                        root.togglePanel("network");
                    }
                }
                StripButton { tooltip: "Volume";
                    // Rail bezit de systeemcontrols; strip toont ze alleen zonder rail.
                    visible: !root.railEnabled && root.moduleEnabled("volume")
                    icon: root.volIcon
                    accent: root.isSoundActive ? root.mocha.accent3 : root.mocha.subtext0
                    onTriggered: root.togglePanel("volume")
                    onWheelDelta: (delta) => root.handleVolumeWheel(delta)
                }
                StripButton { tooltip: "Batterij";
                    visible: !root.railEnabled && root.moduleEnabled("battery") && root.hasBattery
                    icon: "󰁹"
                    accent: root.mocha.accent2
                    onTriggered: root.togglePanel("battery")
                }
                StripButton { tooltip: "Afsluitmenu";
                    visible: !root.railEnabled
                    icon: "󰐥"
                    accent: root.mocha.red
                    onTriggered: root.togglePanel("power")
                }
                StripButton { tooltip: "Instellingen"; visible: !root.railEnabled && root.activeMode !== "media"; icon: "󰒓"; accent: root.mocha.subtext1; onTriggered: root.togglePanel("settings") }
            }
        }
    }

    // Concave binnenhoek waar rail (links) en strip (boven) samenkomen, zodat
    // de content vloeiend afgerond in de bar-L nestelt i.p.v. een harde 90°.
    // Shape rendert declaratief (geen requestPaint nodig, i.t.t. Canvas).
    readonly property bool cornersActive: railEnabled && stripEnabled && !railOnRight && !stripOnBottom
    // --- Dunne omlijning rechts en onder --------------------------------------
    // Samen met rail (links) en strip (boven) vormt dit een gesloten kader om
    // de content, met afgeronde binnenhoeken.
    Rectangle {
        id: rightBorder
        visible: root.cornersActive
        // frameBandW erbij opgeteld: de accentband van de blob-shader ligt op
        // de binnenrand van de omlijsting en moet zichtbaar blijven.
        x: root.width - root.shellBorderWidth + root.frameBandW
        y: root.stripHeight
        width: root.shellBorderWidth - root.frameBandW
        height: root.height - root.stripHeight
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root._diagColor(root.width, root.stripHeight) }
            GradientStop { position: 1.0; color: root._diagColor(root.width, root.height) }
        }
    }

    Rectangle {
        id: bottomBorder
        visible: root.cornersActive
        x: root.railWidth
        y: root.height - root.shellBorderWidth + root.frameBandW
        width: root.width - root.railWidth - root.shellBorderWidth
        height: root.shellBorderWidth - root.frameBandW
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root._diagColor(root.railWidth, root.height) }
            GradientStop { position: 1.0; color: root._diagColor(root.width, root.height) }
        }
    }

    Shape {
        id: technicalFrameStroke
        anchors.fill: parent
        visible: root.technicalFrameStyle
        z: 4
        opacity: 0.92
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4

        readonly property real l: root.railWidth + root.frameBandW + 2
        readonly property real t: root.stripHeight + root.frameBandW + 2
        readonly property real r: root.width - root.shellBorderWidth - root.frameBandW - 2
        readonly property real b: root.height - root.shellBorderWidth - root.frameBandW - 2
        readonly property real cut: Math.min(34, Math.max(22, root.width * 0.012))
        readonly property real step: Math.min(70, Math.max(42, root.width * 0.026))
        readonly property real notch: Math.min(92, Math.max(58, root.width * 0.035))

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.edgeAccentA.r, root.edgeAccentA.g, root.edgeAccentA.b, 0.88)
            strokeWidth: 1.2
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathMove { x: technicalFrameStroke.l + technicalFrameStroke.cut; y: technicalFrameStroke.t }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.step; y: technicalFrameStroke.t }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.step + 14; y: technicalFrameStroke.t + 10 }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.step - 14; y: technicalFrameStroke.t + 10 }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.step; y: technicalFrameStroke.t }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.cut; y: technicalFrameStroke.t }
            PathLine { x: technicalFrameStroke.r; y: technicalFrameStroke.t + technicalFrameStroke.cut }
            PathLine { x: technicalFrameStroke.r; y: technicalFrameStroke.b - technicalFrameStroke.cut }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.cut; y: technicalFrameStroke.b }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.step; y: technicalFrameStroke.b }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.step - 14; y: technicalFrameStroke.b - 10 }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.step + 14; y: technicalFrameStroke.b - 10 }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.step; y: technicalFrameStroke.b }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.cut; y: technicalFrameStroke.b }
            PathLine { x: technicalFrameStroke.l; y: technicalFrameStroke.b - technicalFrameStroke.cut }
            PathLine { x: technicalFrameStroke.l; y: technicalFrameStroke.t + technicalFrameStroke.cut }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.cut; y: technicalFrameStroke.t }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.edgeAccentC.r, root.edgeAccentC.g, root.edgeAccentC.b, 0.62)
            strokeWidth: 1
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathMove { x: technicalFrameStroke.l + technicalFrameStroke.notch; y: technicalFrameStroke.t + 16 }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.notch + 24; y: technicalFrameStroke.t + 16 }
            PathMove { x: technicalFrameStroke.r - technicalFrameStroke.notch - 24; y: technicalFrameStroke.t + 16 }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.notch; y: technicalFrameStroke.t + 16 }
            PathMove { x: technicalFrameStroke.l + technicalFrameStroke.notch; y: technicalFrameStroke.b - 16 }
            PathLine { x: technicalFrameStroke.l + technicalFrameStroke.notch + 24; y: technicalFrameStroke.b - 16 }
            PathMove { x: technicalFrameStroke.r - technicalFrameStroke.notch - 24; y: technicalFrameStroke.b - 16 }
            PathLine { x: technicalFrameStroke.r - technicalFrameStroke.notch; y: technicalFrameStroke.b - 16 }
        }
    }

    // De accentlijn om omlijsting én panelen komt volledig uit de blob-shader:
    // één band op de samengesmolten SDF (zie blob.frag). De vroegere Canvas
    // hier tekende een geïdealiseerde outline met eigen hoekbogen overheen,
    // wat dubbele lijnen en afwijkende hoekvormen gaf zodra een paneel open was.

    // --- Hover-tooltip -------------------------------------------------------
    // Eén gedeelde tooltip die naar de gehoverde knop toe beweegt. Rail-knoppen
    // krijgen hem rechts ernaast, strip-knoppen eronder.
    property string tooltipText: ""
    property real tooltipAnchorX: 0
    property real tooltipAnchorY: 0
    property bool tooltipFromRail: true

    function showTooltip(item, text, fromRail) {
        if (!text) return;
        let p = item.mapToItem(root, item.width / 2, item.height / 2);
        root.tooltipAnchorX = p.x;
        root.tooltipAnchorY = p.y;
        root.tooltipFromRail = fromRail;
        root.tooltipText = text;
    }

    function hideTooltip(text) {
        if (root.tooltipText === text) root.tooltipText = "";
    }

    Rectangle {
        id: tooltip
        z: 200
        visible: opacity > 0.01
        opacity: root.tooltipText !== "" ? 1 : 0
        radius: Math.max(6, ThemeConfig.styleWidgetRadius)
        color: root.barGradStart
        border.width: 1
        border.color: Qt.rgba(root.barHueA.r, root.barHueA.g, root.barHueA.b, 0.45)
        width: tipText.implicitWidth + 18
        height: tipText.implicitHeight + 10
        x: root.tooltipFromRail
            ? (root.railOnRight ? root.width - root.railWidth - width - 10 : root.railWidth + 10)
            : Math.max(4, Math.min(root.width - width - 4, root.tooltipAnchorX - width / 2))
        y: root.tooltipFromRail
            ? Math.max(4, Math.min(root.height - height - 4, root.tooltipAnchorY - height / 2))
            : (root.stripOnBottom ? root.height - root.stripHeight - height - 8 : root.stripHeight + 8)

        Behavior on opacity {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on x {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on y {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.tooltipText
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: root.mocha.text
        }
    }

    // Media-pill: toont de lopende track en groeit op hover uit tot
    // transportcontrols (caelestia-patroon). Klik opent het volledige
    // muziekpaneel.
    component MediaPill: Rectangle {
        id: mp
        readonly property var player: root.activePlayer
        readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing
        readonly property string title: player
            ? (String(player.trackTitle || "").trim() !== ""
                ? String(player.trackTitle || "")
                : (String(player.identity || "").trim() !== "" ? String(player.identity || "") : "Media"))
            : ""
        readonly property string artist: player ? String(player.trackArtist || "") : ""
        readonly property bool expanded: mpMouse.containsMouse

        visible: root.mediaVisible
        Layout.preferredWidth: expanded ? 300 : 168
        Layout.preferredHeight: 26
        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
        color: expanded ? root.pillHoverColor : root.pillColor
        border.width: 1
        border.color: expanded
            ? Qt.rgba(root.barHueA.r, root.barHueA.g, root.barHueA.b, 0.40)
            : "transparent"

        Behavior on Layout.preferredWidth {
            NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 6

            Text {
                text: mp.playing ? "\udb81\udf5a" : "\udb81\udf5a"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 13
                color: root.mocha.accent3
            }

            Text {
                Layout.fillWidth: true
                text: mp.artist !== "" ? mp.title + "  ·  " + mp.artist : mp.title
                elide: Text.ElideRight
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.mocha.text
            }

            Row {
                spacing: 2
                visible: mp.expanded
                opacity: mp.expanded ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: ThemeConfig.durationToken("fast") }
                }

                MediaCtl { icon: "\udb81\udcae"; onTriggered: if (mp.player) mp.player.previous() }
                MediaCtl {
                    icon: mp.playing ? "\udb80\udfe4" : "\udb81\udc0a"
                    onTriggered: {
                        if (!mp.player) return;
                        if (mp.player.canTogglePlaying) mp.player.togglePlaying();
                        else if (mp.player.canPlay) mp.player.play();
                    }
                }
                MediaCtl { icon: "\udb81\udcad"; onTriggered: if (mp.player) mp.player.next() }
            }
        }

        MouseArea {
            id: mpMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: {
                let p = mp.mapToItem(root, mp.width / 2, mp.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                root.togglePanel("music");
            }
        }
    }

    // Kleine transportknop binnen de media-pill.
    component MediaCtl: Rectangle {
        id: mc
        property string icon: ""
        signal triggered()
        width: 22
        height: 22
        radius: 5
        color: mcMouse.containsMouse
            ? Qt.rgba(root.barHueA.r, root.barHueA.g, root.barHueA.b, 0.28)
            : "transparent"
        Text {
            anchors.centerIn: parent
            text: mc.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 13
            color: root.mocha.text
        }
        MouseArea {
            id: mcMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: mc.triggered()
        }
    }

    component RailButton: Rectangle {
        id: btn
        property string icon: ""
        property string text: ""
        property color accent: root.hotColor
        property string tooltip: ""
        signal triggered()
        signal wheelDelta(int delta)

        Layout.fillWidth: true
        Layout.preferredHeight: text === "" ? 34 : 40
        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
        color: mouse.containsMouse ? root.pillHoverColor : "transparent"
        border.width: 1
        border.color: mouse.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.36) : "transparent"
        scale: mouse.containsMouse ? 1.07 : 1.0
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Column {
            anchors.centerIn: parent
            spacing: -2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 16
                color: btn.accent
            }
            Text {
                visible: btn.text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.text
                font.family: ThemeConfig.monoFont
                font.pixelSize: 8
                font.weight: Font.Bold
                color: root.mocha.text
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.showTooltip(btn, btn.tooltip, true)
            onExited: root.hideTooltip(btn.tooltip)
            onClicked: {
                let p = btn.mapToItem(root, btn.width / 2, btn.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                btn.triggered();
            }
            onWheel: (wheel) => {
                btn.wheelDelta(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }
    }

    component StripButton: Rectangle {
        id: btn
        property string icon: ""
        property string text: ""
        property color accent: root.hotColor
        property string tooltip: ""
        signal triggered()
        signal wheelDelta(int delta)

        Layout.preferredWidth: text === "" ? 30 : 43
        Layout.preferredHeight: 28
        radius: Math.min(6, ThemeConfig.styleWidgetRadius)
        color: mouse.containsMouse ? root.pillHoverColor : "transparent"
        scale: mouse.containsMouse ? 1.07 : 1.0
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Row {
            anchors.centerIn: parent
            spacing: 3
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 15
                color: btn.accent
            }
            Text {
                visible: btn.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: btn.text
                font.family: ThemeConfig.monoFont
                font.pixelSize: 9
                font.weight: Font.Bold
                color: root.mocha.text
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.showTooltip(btn, btn.tooltip, false)
            onExited: root.hideTooltip(btn.tooltip)
            onClicked: {
                let p = btn.mapToItem(root, btn.width / 2, btn.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                btn.triggered();
            }
            onWheel: (wheel) => {
                btn.wheelDelta(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }
    }
}
