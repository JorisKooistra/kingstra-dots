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
import Quickshell.Services.SystemTray
import Kingstra.Blobs 1.0
import ".."

Item {
    id: root
    required property var shellWindow
    required property var mocha

    // Focus en hoofdscherm zijn twee verschillende dingen: focus verplaatst
    // bij normaal werken voortdurend, terwijl de visuele ankerplek stabiel
    // moet blijven. Het hoofdscherm wordt gekozen in Settings > Display.
    readonly property var monitorForScreen: Hyprland.monitorFor(shellWindow.screen)
    readonly property bool focusedScreen: monitorForScreen !== null
        && Hyprland.focusedMonitor !== null
        && monitorForScreen.id === Hyprland.focusedMonitor.id
    property string primaryMonitorName: ""
    readonly property bool configuredPrimaryAvailable: {
        if (primaryMonitorName === "") return false;
        let monitors = Hyprland.monitors.values;
        for (let i = 0; i < monitors.length; i++) {
            let mon = monitors[i];
            if (mon && mon.lastIpcObject && String(mon.lastIpcObject.name || "") === primaryMonitorName)
                return true;
        }
        return false;
    }
    readonly property bool primaryScreen: configuredPrimaryAvailable
        ? String(shellWindow.screen.name || "") === primaryMonitorName
        : focusedScreen

    readonly property bool railEnabled: ThemeConfig.barRailEnabled
    readonly property bool stripEnabled: ThemeConfig.barStatusStripEnabled
    readonly property bool stripControlsEnabled: stripEnabled && !railEnabled
    readonly property bool stripOnBottom: ThemeConfig.barStatusStripEdge === "bottom"
    readonly property bool topHoverHitEnabled: stripEnabled && !stripControlsEnabled && !stripOnBottom
    readonly property int topHoverHitWidth: Math.min(420, Math.max(0, width - railWidth - shellBorderWidth))
    readonly property int topHoverOpenDelay: 500
    // Waar tijdens panelRequested("tophover") om gevraagd werd: true bij
    // hover op de bovenrand, false bij een klik. Hover sluit weer bij
    // weggaan; een klik zet het controlecentrum vast.
    property bool hoverRequest: false
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
    readonly property bool technicalFrameStyle: neonStyle && frameEnabled
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
    readonly property var edgeBlobGroup: frameEnabled ? nativeBlobGroup : null

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
            let shortName = n.substring(8);
            if (shortName === "qs-master" || shortName === "") continue;
            out.push({ wsName: shortName, windows: list[i].toplevels.values.length });
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
        Quickshell.execDetached(["bash", "-lc", "\"$HOME/.config/hypr/scripts/hypr-dispatch.sh\" togglespecialworkspace " + name]);
    }

    readonly property Item railHitRegion: railHitArea
    readonly property Item stripHitRegion: stripHitArea
    readonly property Item topHoverHitRegion: topHoverHitArea
    readonly property bool topHoverHovered: topHover.hovered
    property string activeMode: "office"
    readonly property string notificationTooltip: NotificationService.dnd
        ? "Niet storen staat aan · middelklik om uit te zetten"
        : (NotificationService.count === 0 ? "Geen meldingen"
            : (NotificationService.count === 1 ? "1 melding" : NotificationService.count + " meldingen"))
    readonly property bool secondaryScreen: !primaryScreen
    readonly property bool gamingMinimal: activeMode === "gaming" && !railHover.hovered
    // De omlijsting is altijd gesloten. Een frame op nevenmonitoren weghalen
    // maakte hun buitenhoeken vierkant; hem half transparant maken leverde
    // juist dubbele/kapotte boogjes op. Daarom krijgt elk scherm dezelfde
    // complete SDF-contour, zonder opacity-mismatch.
    readonly property bool frameEnabled: cornersActive
    readonly property real chromePresence: gamingMinimal ? 0.76 : 1.0
    readonly property real railModulePresence: secondaryScreen
        ? (railHover.hovered ? 1.0 : 0.78) : (gamingMinimal ? 0.72 : 1.0)
    property var moduleList: ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications"]
    property bool barAutoHide: false
    property bool autoHideVisible: true
    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "ddd d MMM")
    property int clockSeconds: new Date().getSeconds()
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
        return ["workspaces", "clock", "updates", "cpu_temp", "ram_usage", "network", "battery", "volume", "bluetooth", "notifications"];
    }

    function _normalizeModules(mode, modules) {
        let normalized = Array.isArray(modules) ? modules.slice() : [];
        if (mode === "office" && normalized.indexOf("updates") === -1) normalized.push("updates");
        if (mode === "office" && normalized.indexOf("cpu_temp") === -1) normalized.push("cpu_temp");
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

    function applyPrimaryDisplayState(rawText) {
        try {
            let state = JSON.parse(String(rawText || "{}"));
            root.primaryMonitorName = String(state.primary || "");
        } catch (e) {
            root.primaryMonitorName = "";
        }
    }

    function togglePanel(target) {
        // Instellingen is een eigen venster, geen paneel uit de rand.
        if (target === "settings") {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "settings"]);
            return;
        }
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

    function switchWorkspace(wsId) {
        Quickshell.execDetached([
            "bash",
            "-lc",
            Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh " + wsId
        ]);
    }

    // De rail blijft bewust compact en beweegt nooit mee met inhoud. Op hover
    // krijgt een workspace daarom alleen een korte, bestaande tooltip met de
    // echte context: genoeg om te navigeren zonder nóg een paneel te openen.
    function workspaceTooltip(wsId) {
        let list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            let workspace = list[i];
            if (!workspace || workspace.id !== wsId) continue;
            let windows = workspace.toplevels.values;
            if (windows.length === 0) return "Workspace " + wsId + " · leeg";
            let titles = [];
            for (let j = 0; j < windows.length && j < 2; j++) {
                let win = windows[j];
                let ipc = win && win.lastIpcObject ? win.lastIpcObject : {};
                let title = String(ipc.title || ipc.initialTitle || ipc.class || "venster").trim();
                if (title !== "") titles.push(title);
            }
            let suffix = windows.length > titles.length ? " +" + (windows.length - titles.length) : "";
            return "Workspace " + wsId + " · " + windows.length + " venster" + (windows.length === 1 ? "" : "s")
                + (titles.length > 0 ? " · " + titles.join(" · ") + suffix : "");
        }
        return "Workspace " + wsId + " · leeg";
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

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        root.isMuted = !root.isMuted;
        if (!volPoller.running) volPoller.running = true;
    }

    // FileView kan geen afwezige file watchen. Initialiseer daarom de
    // user-state eenmalig voordat de poll begint; de helper schrijft alleen
    // de onschuldige automatische fallback wanneer er nog niets bestaat.
    Process {
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/settings/primary-display.sh", "list"]
        running: true
    }

    FileView {
        id: modeFileView
        path: Quickshell.env("HOME") + "/.config/kingstra/state/mode.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.applyModeState(__text)
    }

    FileView {
        id: primaryDisplayFileView
        path: Quickshell.env("HOME") + "/.config/kingstra/state/primary-display.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.applyPrimaryDisplayState(__text)
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: modeFileView.reload()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: primaryDisplayFileView.reload()
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
    readonly property bool batCharging: UPower.displayDevice !== null
        && (UPower.displayDevice.state === UPowerDeviceState.Charging
            || UPower.displayDevice.state === UPowerDeviceState.FullyCharged
            || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
    readonly property string batIcon: {
        if (batCharging) return "󰂄";
        if (batCap >= 90) return "󰁹";
        if (batCap >= 70) return "󰂀";
        if (batCap >= 50) return "󰁾";
        if (batCap >= 30) return "󰁼";
        if (batCap >= 15) return "󰁻";
        return "󰂃";
    }
    readonly property color batAccent: batCharging ? root.mocha.accent3
        : (batCap < 15 ? root.mocha.red : (batCap < 30 ? root.mocha.yellow : root.mocha.accent2))
    // Welke statusonderdelen de tegel toont volgt dezelfde moduleList en
    // hardware-checks als de losse knoppen die hij vervangt.
    readonly property bool statusShowWifi: moduleEnabled("network") && hasWifi
    readonly property bool statusShowEth: moduleEnabled("network") && !hasWifi && isEthConnected
    readonly property bool statusShowBt: moduleEnabled("bluetooth") && hasBluetooth
    readonly property bool statusShowBattery: moduleEnabled("battery") && hasBattery
    readonly property bool statusTileVisible: statusShowWifi || statusShowEth || statusShowBt
        || statusShowBattery
    readonly property bool audioTileVisible: moduleEnabled("volume") || mediaVisible
    readonly property string audioTooltip: {
        let parts = ["Volume " + (isMuted ? "gedempt" : volPercent)];
        if (mediaVisible && activePlayer) {
            let title = String(activePlayer.trackTitle || activePlayer.identity || "").trim();
            if (title !== "") parts.push((activePlayer.playbackState === MprisPlaybackState.Playing ? "speelt: " : "gepauzeerd: ") + title);
        }
        return "Geluid & media · " + parts.join(" · ");
    }
    readonly property string statusTooltip: {
        let parts = [];
        if (statusShowWifi) parts.push("Wi-Fi " + (isWifiOn ? "aan" : "uit"));
        if (statusShowEth) parts.push("Bedraad verbonden");
        if (statusShowBt) parts.push("Bluetooth " + (isBtOn ? "aan" : "uit"));
        if (statusShowBattery) parts.push("Batterij " + batCap + "%" + (batCharging ? " (laden)" : ""));
        return "Snelle instellingen · " + parts.join(" · ");
    }
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
    // Voortgang van de lopende track voor de ring in de rail en het lijntje
    // in de media-pill. Mpris werkt `position` niet zelf bij, dus tikken.
    readonly property real mediaLength: activePlayer && activePlayer.lengthSupported ? Number(activePlayer.length || 0) : 0
    property real mediaPosition: 0
    readonly property real mediaProgress: mediaLength > 0 ? Math.max(0, Math.min(1, mediaPosition / mediaLength)) : 0
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.mediaVisible && root.mediaLength > 0
        onTriggered: {
            let player = root.activePlayer;
            if (!player || !player.positionSupported) { root.mediaPosition = 0; return; }
            player.positionChanged();
            root.mediaPosition = Number(player.position || 0);
        }
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
            root.clockSeconds = now.getSeconds();
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
                root.hoverRequest = true;
                root.panelRequested("tophover", root.lastTriggerX, root.lastTriggerY);
                root.hoverRequest = false;
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
        anchors.rightMargin: root.frameEnabled && !root.railOnRight ? root.frameBandW : 0
        anchors.leftMargin: root.frameEnabled && root.railOnRight ? root.frameBandW : 0
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root._diagColor(root.railWidth / 2, 0) }
            GradientStop { position: 1.0; color: root._diagColor(root.railWidth / 2, root.height) }
        }
        border.width: 0
        opacity: root.railContentVisible ? root.chromePresence : 0.82
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
            visible: !root.frameEnabled
            width: 2
            anchors.top: parent.top
            // Boven de strip is dit een interne naad, geen buitenrand; daar
            // hoort geen lijn. De boog neemt het hoekstuk voor zijn rekening.
            anchors.topMargin: root.frameEnabled ? root.stripHeight + root.cornerR - root.cornerSeamOverlap : 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.frameEnabled ? root.shellBorderWidth + root.cornerR - root.cornerSeamOverlap : 0
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
            opacity: root.railModulePresence

            Behavior on opacity {
                NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
            }

            RailButton { tooltip: "Launcher";
                icon: "󰣇"
                accent: root.hotColor
                onTriggered: root.togglePanel("launcher")
            }

            ColumnLayout {
                visible: root.moduleEnabled("workspaces")
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        id: workspacePill
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property string tooltipLabel: root.workspaceTooltip(wsId)
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
                        Layout.preferredHeight: 30
                        radius: Math.min(9, ThemeConfig.styleWidgetRadius)
                        color: active ? Qt.rgba(root.hotColor.r, root.hotColor.g, root.hotColor.b, 0.20)
                            : (wsMouse.containsMouse ? root.pillHoverColor
                                : (occupied ? Qt.rgba(root.pillColor.r, root.pillColor.g, root.pillColor.b, 0.92) : "transparent"))
                        border.width: active ? 1 : (occupied ? 1 : 0)
                        border.color: active ? Qt.rgba(root.hotColor.r, root.hotColor.g, root.hotColor.b, 0.84)
                            : Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.12)
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenterOffset: active ? 2 : 0
                            text: wsId
                            font.family: ThemeConfig.textFont
                            font.pixelSize: 12
                            font.weight: active ? Font.Black : Font.Bold
                            color: active ? root.hotColor : root.mocha.text
                        }

                        Rectangle {
                            visible: active
                            width: 3
                            height: parent.height - 10
                            radius: width / 2
                            anchors.left: parent.left
                            anchors.leftMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.hotColor
                        }

                        Rectangle {
                            visible: occupied && !active
                            width: 4
                            height: width
                            radius: width / 2
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.mocha.accent1
                            opacity: 0.82
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.showTooltip(workspacePill, workspacePill.tooltipLabel, true)
                            onExited: root.hideTooltip(workspacePill.tooltipLabel)
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
                            font.family: ThemeConfig.iconFont
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

            // Kleine adem tussen navigatie en de statusgroep.
            Item { Layout.fillWidth: true; Layout.preferredHeight: 6 }

            // Midden: wat aandacht vraagt. Meldingen staan nu bij de andere
            // statusknoppen in plaats van tussen launcher en werkruimtes.
            // Meldingen: teller als er iets ligt, ander icoon bij Niet storen.
            // Middelklik zet Niet storen aan of uit.
            RailButton {
                tooltip: root.notificationTooltip
                visible: root.moduleEnabled("notifications")
                icon: NotificationService.dnd ? "󰂛" : (NotificationService.count > 0 ? "󰂚" : "󰂜")
                badge: NotificationService.dnd ? 0 : NotificationService.count
                accent: NotificationService.dnd ? root.mocha.subtext0 : root.mocha.accent2
                onTriggered: root.togglePanel("notifications")
                onMiddleClicked: NotificationService.toggleDnd()
            }

            // Focus (schermtijd) staat nu als kaart in het dashboard en
            // Monitoren als tegel Beeldschermen in Snelle instellingen.
            RailButton { tooltip: "Systeem";
                visible: root.anyModuleEnabled(["cpu_temp", "gpu_temp", "ram_usage", "fps"])
                icon: "󰍛"
                accent: root.mocha.accent1
                onTriggered: root.togglePanel("performance")
            }

            // Alleen zichtbaar als er iets bij te werken valt; bijwerken kan
            // altijd via `kingstra update` of Instellingen.
            RailButton {
                tooltip: root.updateTooltip()
                visible: root.moduleEnabled("updates") && root.updateCount > 0
                icon: "󰚰"
                text: root.updateCount.toString()
                accent: root.updateCount > 0 ? root.mocha.yellow : root.mocha.subtext0
                onTriggered: root.openUpdatesTerminal()
            }

            RailButton {
                tooltip: "Games"
                visible: root.moduleEnabled("game_launcher")
                icon: "󰊴"
                accent: root.mocha.accent2
                onTriggered: root.togglePanel("gaming")
            }

            Item { Layout.fillHeight: true }

            // Systeemvak: kwam in de oude bar mee, ontbrak sinds de rail.
            TrayGrid {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                vertical: true
            }

            // Geluid & media: volume met percentage (scrollen = volume,
            // middelklik = dempen) en, als er iets speelt, een play/pause-knop
            // eronder. Klik opent het paneel Geluid & media.
            AudioTile {
                visible: root.audioTileVisible
                onTriggered: root.togglePanel("audiomedia")
                onWheelDelta: (delta) => root.handleVolumeWheel(delta)
                onMiddleClicked: root.toggleMute()
            }

            // Compacte statustegel voor netwerk, bluetooth en batterij. Klik
            // opent het controlecentrum bovenaan, met doorverwijzing naar elk
            // detailpaneel.
            StatusTile {
                visible: root.statusTileVisible
                onTriggered: root.togglePanel("tophover")
            }
            // Klok onderaan bij de systeemknoppen, zoals in de meeste
            // verticale balken; bovenaan staat alleen navigatie.
            RailClock {
                visible: root.moduleEnabled("clock")
                onTriggered: root.togglePanel("calendar")
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
        // Wissel hier niet dynamisch tussen top/bottom- of left/right-anchors.
        // Tijdens bottom/geen-rail → top/rail kan Qt beide tegenoverliggende
        // anchors een frame vasthouden. Dan rekt deze strip over het hele
        // scherm en bedekt hij alle surfaces onder het layer-shell-venster.
        x: root.railEnabled && !root.railOnRight ? root.railWidth : 0
        y: root.stripOnBottom ? root.height - root.stripHeight : 0
        width: Math.max(0, root.width - (root.railEnabled ? root.railWidth : 0))
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
            anchors.bottomMargin: root.frameEnabled && !root.stripOnBottom ? root.frameBandW : 0
            anchors.topMargin: root.frameEnabled && root.stripOnBottom ? root.frameBandW : 0
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
                visible: !root.frameEnabled
                height: 2
                anchors.left: parent.left
                anchors.leftMargin: root.frameEnabled ? root.cornerR - root.cornerSeamOverlap : 0
                anchors.right: parent.right
                anchors.rightMargin: root.frameEnabled ? root.shellBorderWidth + root.cornerR - root.cornerSeamOverlap : 0
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
                        Layout.preferredWidth: active ? 40 : 28
                        Layout.preferredHeight: 24
                        radius: Math.min(8, ThemeConfig.styleWidgetRadius)
                        color: active ? Qt.rgba(root.hotColor.r, root.hotColor.g, root.hotColor.b, 0.20)
                            : (stripWsMouse.containsMouse ? root.pillHoverColor
                                : (occupied ? Qt.rgba(root.pillColor.r, root.pillColor.g, root.pillColor.b, 0.92) : "transparent"))
                        border.width: active ? 1 : (occupied ? 1 : 0)
                        border.color: active ? Qt.rgba(root.hotColor.r, root.hotColor.g, root.hotColor.b, 0.84)
                            : Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.12)
                        Text {
                            anchors.centerIn: parent
                            text: wsId
                            font.family: ThemeConfig.textFont
                            font.pixelSize: 11
                            font.weight: active ? Font.Black : Font.Bold
                            color: active ? root.hotColor : root.mocha.text
                        }
                        Rectangle {
                            visible: occupied && !active
                            width: 4
                            height: width
                            radius: width / 2
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.mocha.accent1
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
                StripButton { tooltip: root.notificationTooltip; visible: root.moduleEnabled("notifications"); icon: NotificationService.dnd ? "󰂛" : (NotificationService.count > 0 ? "󰂚" : "󰂜"); badge: NotificationService.dnd ? 0 : NotificationService.count; accent: NotificationService.dnd ? root.mocha.subtext0 : root.mocha.accent2; onTriggered: root.togglePanel("notifications"); onMiddleClicked: NotificationService.toggleDnd() }
                StripButton { tooltip: root.updateTooltip(); visible: root.moduleEnabled("updates") && root.updateCount > 0; icon: "󰚰"; text: root.updateCount.toString(); accent: root.updateCount > 0 ? root.mocha.yellow : root.mocha.subtext0; onTriggered: root.openUpdatesTerminal() }
                StripButton { tooltip: "Games"; visible: root.moduleEnabled("game_launcher"); icon: "󰊴"; accent: root.mocha.accent2; onTriggered: root.togglePanel("gaming") }
            }

            // De klok is de agendaknop: klik opent de agenda. Hover geeft
            // dezelfde zachte vulling als de andere stripknoppen.
            Rectangle {
                anchors.fill: stripClock
                anchors.leftMargin: -10
                anchors.rightMargin: -10
                anchors.topMargin: -5
                anchors.bottomMargin: -5
                visible: stripClock.visible
                radius: Math.min(7, ThemeConfig.styleWidgetRadius)
                color: stripClockMouse.containsMouse ? root.pillHoverColor : "transparent"
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }

                MouseArea {
                    id: stripClockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.showTooltip(parent, "Agenda", false)
                    onExited: root.hideTooltip("Agenda")
                    onClicked: {
                        let p = parent.mapToItem(root, parent.width / 2, parent.height / 2);
                        root.lastTriggerX = p.x;
                        root.lastTriggerY = p.y;
                        root.togglePanel("calendar");
                    }
                }
            }

            RowLayout {
                id: stripClock
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

                TrayGrid {
                    visible: !root.railEnabled && root.trayShownCount > 0
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignVCenter
                    vertical: false
                }

                StripButton { tooltip: root.audioTooltip
                    // Rail bezit de systeemcontrols; strip toont ze alleen zonder rail.
                    visible: !root.railEnabled && root.moduleEnabled("volume")
                    icon: root.volIcon
                    text: root.isMuted ? "" : root.volPercent
                    accent: root.isSoundActive ? root.mocha.accent3 : root.mocha.subtext0
                    onTriggered: root.togglePanel("audiomedia")
                    onWheelDelta: (delta) => root.handleVolumeWheel(delta)
                }

                StripStatus {
                    visible: !root.railEnabled && root.statusTileVisible
                    onTriggered: root.togglePanel("tophover")
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
        visible: root.frameEnabled
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
        visible: root.frameEnabled
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

    // Media-pill: hoesje en lopende track, met een dun voortgangslijntje
    // langs de onderrand. Op hover groeit hij uit tot transportcontrols
    // (caelestia-patroon). Klik opent Geluid & media, met de kaart Nu speelt.
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
        readonly property string artUrl: player && player.trackArtUrl ? String(player.trackArtUrl) : ""
        // HoverHandler i.p.v. de MouseArea: die ligt onder de knoppen, zodat
        // vorige/afspelen/volgende hun eigen klik krijgen en het paneel niet
        // openen.
        readonly property bool expanded: mpHover.hovered

        visible: root.mediaVisible
        Layout.preferredWidth: expanded ? 300 : 176
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
            anchors.leftMargin: 4
            anchors.rightMargin: 6
            spacing: 6

            // Hoesje; zonder hoes het muzieknootje van voorheen.
            Rectangle {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                radius: Math.min(5, ThemeConfig.styleWidgetRadius)
                color: Qt.rgba(root.mocha.accent3.r, root.mocha.accent3.g, root.mocha.accent3.b, 0.16)
                clip: true
                Image {
                    id: mpArt
                    anchors.fill: parent
                    source: mp.artUrl
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 36
                    sourceSize.height: 36
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: ThemeConfig.durationToken("fast") }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: mpArt.status !== Image.Ready
                    text: "\udb81\udf5a"
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 12
                    color: root.mocha.accent3
                }
            }

            Text {
                Layout.fillWidth: true
                text: mp.artist !== "" ? mp.title + "  ·  " + mp.artist : mp.title
                elide: Text.ElideRight
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: mp.playing ? root.mocha.text : root.mocha.subtext0
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
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

        // Voortgang: afgeronde lijn binnen de hoeken van de pill.
        Rectangle {
            visible: root.mediaLength > 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            anchors.bottomMargin: 2
            width: Math.max(height, (parent.width - 12) * root.mediaProgress)
            height: 2
            radius: 1
            color: root.mocha.accent3
            opacity: mp.playing ? 0.85 : 0.40
            Behavior on width {
                NumberAnimation { duration: 900; easing.type: Easing.Linear }
            }
            Behavior on opacity {
                NumberAnimation { duration: ThemeConfig.durationToken("fast") }
            }
        }

        HoverHandler { id: mpHover }

        MouseArea {
            id: mpMouse
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton
            onClicked: {
                let p = mp.mapToItem(root, mp.width / 2, mp.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                root.togglePanel("audiomedia");
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
            font.family: ThemeConfig.iconFont
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
        property int badge: 0
        signal triggered()
        signal middleClicked()
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
                font.family: ThemeConfig.iconFont
                font.pixelSize: 16
                color: btn.accent
            }
            Text {
                visible: btn.text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.text
                font.family: ThemeConfig.textFont
                font.pixelSize: 8
                font.weight: Font.Bold
                color: root.mocha.text
            }
        }

        // Rond tellerbolletje rechtsboven (bijv. aantal meldingen); 0 = weg.
        Rectangle {
            readonly property bool shown: btn.badge > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.rightMargin: 1
            width: Math.max(height, badgeText.implicitWidth + 7)
            height: 13
            radius: height / 2
            color: btn.accent
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.4
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") } }
            Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: btn.badge > 99 ? "99+" : String(btn.badge)
                font.family: ThemeConfig.textFont
                font.pixelSize: 8
                font.weight: Font.Black
                color: root.mocha.base
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onEntered: root.showTooltip(btn, btn.tooltip, true)
            onExited: root.hideTooltip(btn.tooltip)
            onClicked: (mouseEvent) => {
                if (mouseEvent.button === Qt.MiddleButton) {
                    btn.middleClicked();
                    return;
                }
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

    // Compacte railklok: uren boven minuten, de seconden lopen als dun
    // balkje mee. Klik opent de agenda, de datum staat in de tooltip.
    component RailClock: Rectangle {
        id: clock
        readonly property color accent: root.mocha.accent1
        readonly property string hoursText: root.timeText.split(":")[0] || "--"
        readonly property string minutesText: root.timeText.split(":")[1] || "--"
        readonly property string tooltip: root.dateText
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
        color: clockMouse.containsMouse ? root.pillHoverColor : "transparent"
        border.width: 1
        border.color: clockMouse.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.36) : "transparent"
        scale: clockMouse.containsMouse ? 1.07 : 1.0
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: -3
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.hoursText
                font.family: ThemeConfig.textFont
                font.pixelSize: 14
                font.weight: Font.Black
                color: clock.accent
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.minutesText
                font.family: ThemeConfig.textFont
                font.pixelSize: 14
                font.weight: Font.Black
                color: root.mocha.text
            }
        }

        Rectangle {
            id: secondsTrack
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: parent.width - 12
            height: 2
            radius: height / 2
            color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.12)

            Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * (root.clockSeconds / 59)
                color: clock.accent
                opacity: 0.82
                // Bij de minuutwissel springt het balkje terug zonder terugveeg.
                Behavior on width {
                    enabled: root.clockSeconds > 0
                    NumberAnimation { duration: 900; easing.type: Easing.Linear }
                }
            }
        }

        MouseArea {
            id: clockMouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.showTooltip(clock, clock.tooltip, true)
            onExited: root.hideTooltip(clock.tooltip)
            onClicked: {
                let p = clock.mapToItem(root, clock.width / 2, clock.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                clock.triggered();
            }
        }
    }

    component StripButton: Rectangle {
        id: btn
        property string icon: ""
        property string text: ""
        property color accent: root.hotColor
        property string tooltip: ""
        property int badge: 0
        signal triggered()
        signal middleClicked()
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
                font.family: ThemeConfig.iconFont
                font.pixelSize: 15
                color: btn.accent
            }
            Text {
                visible: btn.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: btn.text
                font.family: ThemeConfig.textFont
                font.pixelSize: 9
                font.weight: Font.Bold
                color: root.mocha.text
            }
        }
        // Rond tellerbolletje rechtsboven (bijv. aantal meldingen); 0 = weg.
        Rectangle {
            readonly property bool shown: btn.badge > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: -3
            width: Math.max(height, badgeText.implicitWidth + 7)
            height: 13
            radius: height / 2
            color: btn.accent
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.4
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") } }
            Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: btn.badge > 99 ? "99+" : String(btn.badge)
                font.family: ThemeConfig.textFont
                font.pixelSize: 8
                font.weight: Font.Black
                color: root.mocha.base
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onEntered: root.showTooltip(btn, btn.tooltip, false)
            onExited: root.hideTooltip(btn.tooltip)
            onClicked: (mouseEvent) => {
                if (mouseEvent.button === Qt.MiddleButton) {
                    btn.middleClicked();
                    return;
                }
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

    // --- Geluid & media-tegel (rail) -----------------------------------------
    // Bovenin dezelfde inhoud als de oude volumeknop (icoon + percentage).
    // Speelt er media, dan groeit eronder een ronde play/pause-knop met
    // voortgangsring uit, die direct schakelt zonder het paneel te openen.
    // Dezelfde knoptaal als RailButton.
    component AudioTile: Rectangle {
        id: audio
        signal triggered()
        signal middleClicked()
        signal wheelDelta(int delta)

        readonly property bool showMedia: root.mediaVisible
        readonly property bool playing: root.activePlayer !== null
            && root.activePlayer.playbackState === MprisPlaybackState.Playing

        property string shownTip: ""
        function showTip() {
            shownTip = root.audioTooltip;
            root.showTooltip(audio, shownTip, true);
        }
        readonly property string liveTip: root.audioTooltip
        onLiveTipChanged: if (audioMouse.containsMouse || mediaMouse.containsMouse) showTip()

        Layout.fillWidth: true
        Layout.preferredHeight: 40 + (showMedia ? 32 : 0)
        clip: true
        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
        color: audioMouse.containsMouse || mediaMouse.containsMouse ? root.pillHoverColor : "transparent"
        border.width: 1
        border.color: audioMouse.containsMouse || mediaMouse.containsMouse
            ? Qt.rgba(root.mocha.accent3.r, root.mocha.accent3.g, root.mocha.accent3.b, 0.36) : "transparent"
        scale: audioMouse.containsMouse ? 1.07 : 1.0
        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        MouseArea {
            id: audioMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onEntered: audio.showTip()
            onExited: if (!mediaMouse.containsMouse) root.hideTooltip(audio.shownTip)
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    audio.middleClicked();
                    return;
                }
                let p = audio.mapToItem(root, audio.width / 2, 20);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                audio.triggered();
            }
            onWheel: (wheel) => {
                audio.wheelDelta(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20 - height / 2
            spacing: -2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.volIcon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 16
                color: root.isSoundActive ? root.mocha.accent3 : root.mocha.subtext0
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isMuted ? "--" : root.volPercent
                font.family: ThemeConfig.textFont
                font.pixelSize: 8
                font.weight: Font.Bold
                color: root.mocha.text
            }
        }

        // Ronde afspeelknop met een voortgangsring: de ring loopt rond met
        // de track. Linksklik = afspelen/pauzeren, rechtsklik = volgende,
        // scrollen = volume (zoals de rest van de tegel).
        Item {
            id: mediaButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            width: 28
            height: 28
            opacity: audio.showMedia ? 1 : 0
            scale: audio.showMedia ? (mediaMouse.pressed ? 0.90 : (mediaMouse.containsMouse ? 1.08 : 1.0)) : 0.6
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
            }
            Behavior on scale {
                NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 22
                height: 22
                radius: width / 2
                color: mediaMouse.containsMouse
                    ? Qt.rgba(root.mocha.accent3.r, root.mocha.accent3.g, root.mocha.accent3.b, 0.30)
                    : Qt.rgba(root.mocha.accent3.r, root.mocha.accent3.g, root.mocha.accent3.b, audio.playing ? 0.18 : 0.08)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }
            }

            Shape {
                id: ring
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                property real shownProgress: root.mediaProgress
                Behavior on shownProgress {
                    NumberAnimation { duration: 900; easing.type: Easing.Linear }
                }
                // Spoor
                ShapePath {
                    strokeWidth: 2
                    strokeColor: Qt.rgba(root.mocha.accent3.r, root.mocha.accent3.g, root.mocha.accent3.b, 0.16)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 14; centerY: 14; radiusX: 13; radiusY: 13; startAngle: 0; sweepAngle: 360 }
                }
                // Voortgang
                ShapePath {
                    strokeWidth: 2
                    strokeColor: root.mocha.accent3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 14; centerY: 14; radiusX: 13; radiusY: 13
                        startAngle: -90
                        sweepAngle: Math.max(0.5, 360 * ring.shownProgress)
                    }
                }
                visible: root.mediaLength > 0
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: audio.playing ? 0 : 1
                text: audio.playing ? "\udb80\udfe4" : "\udb81\udc0a"
                font.family: ThemeConfig.iconFont
                font.pixelSize: 12
                color: root.mocha.accent3
            }

            MouseArea {
                id: mediaMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: audio.showTip()
                onExited: if (!audioMouse.containsMouse) root.hideTooltip(audio.shownTip)
                onClicked: (mouse) => {
                    let player = root.activePlayer;
                    if (!player) return;
                    if (mouse.button === Qt.RightButton) {
                        if (player.canGoNext) player.next();
                        return;
                    }
                    if (player.canTogglePlaying) player.togglePlaying();
                    else if (player.canPlay) player.play();
                }
                onWheel: (wheel) => {
                    audio.wheelDelta(wheel.angleDelta.y);
                    wheel.accepted = true;
                }
            }
        }
    }

    // --- Statustegel (rail) --------------------------------------------------
    // Zelfde knoptaal als RailButton (hover-vulling, accentrand, schaal), maar
    // met een raster: netwerk, bluetooth en batterij in de ruimte van één
    // knop. De batterij houdt haar percentage zichtbaar.
    component StatusTile: Rectangle {
        id: tile
        signal triggered()

        // De tooltip toont live waarden; bij scrollen verandert de tekst
        // terwijl je erboven hangt. Onthoud welke tekst er staat, anders
        // matcht hideTooltip niet meer en blijft hij hangen.
        property string shownTip: ""
        function showTip() {
            shownTip = root.statusTooltip;
            root.showTooltip(tile, shownTip, true);
        }
        readonly property string liveTip: root.statusTooltip
        onLiveTipChanged: if (tileMouse.containsMouse) showTip()

        Layout.fillWidth: true
        Layout.preferredHeight: statusGrid.implicitHeight + 12
        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
        color: tileMouse.containsMouse ? root.pillHoverColor : "transparent"
        border.width: 1
        border.color: tileMouse.containsMouse
            ? Qt.rgba(root.hotColor.r, root.hotColor.g, root.hotColor.b, 0.36) : "transparent"
        scale: tileMouse.containsMouse ? 1.07 : 1.0
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Grid {
            id: statusGrid
            anchors.centerIn: parent
            columns: tile.width >= 40 ? 2 : 1
            columnSpacing: 0
            rowSpacing: 3
            readonly property real cellW: Math.floor((tile.width - 4) / columns)

            StatusGlyph {
                visible: root.statusShowWifi
                width: statusGrid.cellW
                icon: root.isWifiOn ? "󰤨" : "󰤮"
                accent: root.isWifiOn ? root.mocha.accent3 : root.mocha.subtext0
            }
            StatusGlyph {
                visible: root.statusShowEth
                width: statusGrid.cellW
                icon: "󰈀"
                accent: root.mocha.accent3
            }
            StatusGlyph {
                visible: root.statusShowBt
                width: statusGrid.cellW
                icon: root.isBtOn ? "󰂱" : "󰂲"
                accent: root.isBtOn ? root.mocha.accent3 : root.mocha.subtext0
            }
            StatusGlyph {
                visible: root.statusShowBattery
                width: statusGrid.cellW
                icon: root.batIcon
                value: String(root.batCap)
                accent: root.batAccent
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: tile.showTip()
            onExited: root.hideTooltip(tile.shownTip)
            onClicked: (mouse) => {
                let p = tile.mapToItem(root, tile.width / 2, tile.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                tile.triggered();
            }
        }
    }

    component StatusGlyph: Column {
        id: glyph
        property string icon: ""
        property string value: ""
        property color accent: root.hotColor
        spacing: -2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: glyph.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 14
            color: glyph.accent
            Behavior on color {
                ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
            }
        }
        Text {
            visible: glyph.value !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: glyph.value
            font.family: ThemeConfig.textFont
            font.pixelSize: 8
            font.weight: Font.Bold
            color: root.mocha.text
        }
    }

    // --- Statuspil (strip, voor thema's zonder rail) -------------------------
    component StripStatus: Rectangle {
        id: pill
        signal triggered()

        property string shownTip: ""
        function showTip() {
            shownTip = root.statusTooltip;
            root.showTooltip(pill, shownTip, false);
        }
        readonly property string liveTip: root.statusTooltip
        onLiveTipChanged: if (pillMouse.containsMouse) showTip()

        Layout.preferredWidth: pillRow.implicitWidth + 16
        Layout.preferredHeight: 28
        radius: Math.min(6, ThemeConfig.styleWidgetRadius)
        color: pillMouse.containsMouse ? root.pillHoverColor : "transparent"
        scale: pillMouse.containsMouse ? 1.07 : 1.0
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            StripGlyph {
                visible: root.statusShowWifi
                icon: root.isWifiOn ? "󰤨" : "󰤮"
                accent: root.isWifiOn ? root.mocha.accent3 : root.mocha.subtext0
            }
            StripGlyph {
                visible: root.statusShowEth
                icon: "󰈀"
                accent: root.mocha.accent3
            }
            StripGlyph {
                visible: root.statusShowBt
                icon: root.isBtOn ? "󰂱" : "󰂲"
                accent: root.isBtOn ? root.mocha.accent3 : root.mocha.subtext0
            }
            StripGlyph {
                visible: root.statusShowBattery
                icon: root.batIcon
                value: root.batCap + "%"
                accent: root.batAccent
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: pill.showTip()
            onExited: root.hideTooltip(pill.shownTip)
            onClicked: (mouse) => {
                let p = pill.mapToItem(root, pill.width / 2, pill.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                pill.triggered();
            }
        }
    }

    component StripGlyph: Row {
        id: sglyph
        property string icon: ""
        property string value: ""
        property color accent: root.hotColor
        spacing: 3
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sglyph.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 15
            color: sglyph.accent
            Behavior on color {
                ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
            }
        }
        Text {
            visible: sglyph.value !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: sglyph.value
            font.family: ThemeConfig.textFont
            font.pixelSize: 9
            font.weight: Font.Bold
            color: root.mocha.text
        }
    }

    // --- Systeemvak ----------------------------------------------------------
    // Links: activeren, midden: secundaire actie, rechts: het menu van de app.
    // nm-applet blijft verborgen; netwerk zit al in de statustegel.
    function trayField(item, key) {
        if (!item) return "";
        try {
            let value = item[key];
            return value === undefined || value === null ? "" : String(value);
        } catch (e) {
            return "";
        }
    }
    function isHiddenTrayItem(item) {
        let haystack = [trayField(item, "id"), trayField(item, "title"),
                        trayField(item, "tooltipTitle"), trayField(item, "icon")].join(" ").toLowerCase();
        return haystack.indexOf("nm-applet") !== -1
            || haystack.indexOf("networkmanager") !== -1
            || haystack.indexOf("nm-signal") !== -1
            || haystack.indexOf("network-wireless-signal") !== -1;
    }
    readonly property int trayShownCount: {
        let list = SystemTray.items.values;
        let n = 0;
        for (let i = 0; i < list.length; i++) {
            if (!isHiddenTrayItem(list[i])) n++;
        }
        return n;
    }

    component TrayGrid: Grid {
        id: tray
        property bool vertical: true
        readonly property int cell: 24
        visible: root.trayShownCount > 0
        // Kolommen volgen de binnenbreedte van de rail (marge 7 aan elke kant),
        // niet de eigen breedte: zo is de grid precies zo breed als zijn
        // iconen en kan de rail hem centreren. Met fillWidth stond één kolom
        // links in de rail.
        readonly property real railInnerWidth: root.railWidth - 14
        columns: vertical
            ? Math.max(1, Math.min(root.trayShownCount, Math.floor((railInnerWidth + spacing) / (cell + spacing))))
            : Math.max(1, root.trayShownCount)
        spacing: vertical ? 2 : 4
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: SystemTray.items
            delegate: Rectangle {
                id: trayCell
                required property var modelData
                readonly property string label: String(modelData.tooltipTitle || modelData.title || modelData.id || "")
                visible: !root.isHiddenTrayItem(modelData)
                width: tray.cell
                height: tray.cell
                radius: Math.min(6, ThemeConfig.styleWidgetRadius)
                color: trayMouse.containsMouse ? root.pillHoverColor : "transparent"
                scale: trayMouse.containsMouse ? 1.07 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
                }
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }

                Image {
                    anchors.centerIn: parent
                    source: trayCell.modelData.icon || ""
                    width: 16
                    height: 16
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }

                QsMenuAnchor {
                    id: trayMenu
                    anchor.window: root.shellWindow
                    anchor.item: trayCell
                    menu: trayCell.modelData.menu
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onEntered: root.showTooltip(trayCell, trayCell.label, tray.vertical)
                    onExited: root.hideTooltip(trayCell.label)
                    onClicked: (mouse) => {
                        let item = trayCell.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) trayMenu.open();
                        } else {
                            item.activate();
                        }
                    }
                    onWheel: (wheel) => {
                        trayCell.modelData.scroll(wheel.angleDelta.y, false);
                        wheel.accepted = true;
                    }
                }
            }
        }
    }
}
