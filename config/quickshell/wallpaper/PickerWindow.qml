import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "PickerLogic.js" as Logic

PanelWindow {
    id: root
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    screen: Quickshell.screens.find(s => s.name === Quickshell.env("KINGSTRA_PICKER_MONITOR")) || Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "kingstra-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    MatugenColors {
        id: c
    }
    // Append rows to a real model. Changing an integer GridView model resets
    // its content position whenever Wallhaven adds another page.
    ListModel {
        id: tileModel
    }
    readonly property string uiFont: ThemeConfig.uiFont
    readonly property real wheelFactor: Math.max(0.01, Number(Quickshell.env("KINGSTRA_PICKER_SCROLL_FACTOR")) || 1)
    readonly property real uiRadius: Math.max(0, Math.min(12, ThemeConfig.styleWidgetRadius))
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("backend.py").toString().replace(/^file:\/\//, ""))
    readonly property url cardShader: "file://" + Quickshell.env("KINGSTRA_PICKER_SHADER")
    readonly property url cardVertexShader: "file://" + Quickshell.env("KINGSTRA_PICKER_VERTEX_SHADER")
    property string mode: "hex"
    property string sortMode: "color"
    property var pickerLayout: ({})
    property string sourceTab: "local"
    readonly property bool online: sourceTab !== "local"
    readonly property string sourceName: sourceTab === "nasa" ? "NASA" : "Wallhaven"
    property string operationLabel: "Even geduld…"
    property string operationStage: ""
    property int operationPercent: -1
    property string waitingDownloadId: ""
    readonly property string operationButtonLabel: operationStage === "download" || operationStage === "metadata" ? (operationPercent < 0 ? "Downloaden…" : operationPercent + "%") : operationStage === "colors" ? "Kleuren…" : operationStage === "apps" ? "Afronden…" : "Instellen…"
    property string currentPath: ""
    property string folder: ""
    property var localItems: []
    property bool catalogInitialized: false
    property var remoteItems: []
    property var thumbnails: ({})
    property var items: []
    property int selected: 0
    property bool favoritesOnly: false
    property string message: ""
    property int remotePage: 1
    property int remoteLastPage: 1
    property bool pendingApply: false
    property bool quitAfterApply: false
    property bool paletteOpen: false
    property var paletteGroups: []
    property var preferenceQueue: []
    property string colorFilter: ""
    property int localHue: -1
    property int pendingSearchPage: 0
    property bool pendingSearchForce: false
    property string lastSearchSignature: ""
    property string remoteSeed: ""
    property int activeSearchPage: 0
    property bool remoteLoadFailed: false
    property bool previewOpen: false
    property var previewInfo: ({})
    property string previewSource: ""
    property string previewMessage: ""
    property string pendingPreviewId: ""
    property string activePreviewId: ""
    readonly property bool previewLoading: previewProcess.running
    property double startedMs: Date.now()
    readonly property var chosen: selected >= 0 && selected < items.length ? items[selected] : ({})
    readonly property bool busy: !!waitingDownloadId || downloadProcess.running || applyProcess.running || removeProcess.running
    readonly property bool loading: online ? searchProcess.running : (catalogProcess.running || catalogDelay.running)
    readonly property var wallhavenColors: ["cc0000", "ff6600", "ffcc33", "77cc33", "669900", "66cccc", "0099cc", "0066cc", "333399", "663399", "993399", "ea4c88", "999999"]
    readonly property var localColors: ["dd3333", "dd9933", "c1d635", "76ce36", "33bb55", "33b88c", "33aabd", "3377cc", "6655cc", "aa55cc", "cc55bb", "cc557d", "999999"]
    readonly property var colorNames: ["Rood", "Oranje", "Geel", "Lichtgroen", "Groen", "Turkoois", "Lichtblauw", "Blauw", "Donkerblauw", "Paars", "Purper", "Roze", "Grijs"]

    function worker(args) {
        return ["python3", helper].concat(args);
    }
    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return {};
        }
    }
    function identity(item) {
        return item.id || item.path || "";
    }
    function showMessage(text) {
        message = text;
        if (previewOpen)
            previewMessage = text;
    }
    function close() {
        quitAfterApply = true;
        root.visible = false;
        finishClose();
    }
    function finishClose() {
        if (quitAfterApply && !busy && !preferencesProcess.running && !preferenceQueue.length)
            Qt.quit();
    }
    function filter(appendOnly) {
        let previous = identity(chosen);
        let query = sourceTab === "local" ? searchField.text.toLowerCase().trim() : "";
        let next = (sourceTab === "local" ? localItems : remoteItems).filter(item => (!favoritesOnly || item.favorite) && (sourceTab !== "local" || localHue < 0 || (thumbnailFor(item).hue === undefined ? item.hue : thumbnailFor(item).hue) === localHue) && (!query || (item.name + " " + (item.displayName || "") + " " + (item.folder || "") + " " + (item.tags || []).join(" ") + " " + (item.tagAliases || []).join(" ")).toLowerCase().includes(query)));
        if (sourceTab === "local") {
            if (sortMode === "name")
                next.sort((a, b) => a.name.localeCompare(b.name));
            else if (sortMode === "date")
                next.sort((a, b) => b.mtime - a.mtime);
            else
                next.sort((a, b) => Logic.compareColors(Object.assign({}, a, thumbnailFor(a)), Object.assign({}, b, thumbnailFor(b))));
        }
        let structureChanged = next.length !== items.length || next.some((item, i) => identity(item) !== identity(items[i]));
        let samePrefix = tileModel.count <= next.length;
        for (let i = 0; samePrefix && i < tileModel.count; i++)
            samePrefix = tileModel.get(i).entryKey === identity(next[i]);
        items = next;
        if (!samePrefix)
            tileModel.clear();
        for (let i = tileModel.count; i < next.length; i++)
            tileModel.append({
                entryKey: identity(next[i])
            });
        let index = next.findIndex(item => identity(item) === (previous || currentPath));
        selected = Math.max(0, index);
        if (structureChanged && !appendOnly)
            Qt.callLater(function () {
                position(false);
            });
    }
    function position(animate) {
        if (views.item && views.item.positionSelected)
            views.item.positionSelected(animate !== false);
    }
    function navigate(delta) {
        if (!items.length)
            return;
        selected = online ? Math.max(0, Math.min(items.length - 1, selected + delta)) : Logic.modulo(selected + delta, items.length);
        position(true);
    }
    function navigateVertical(delta) {
        if (mode === "wall")
            navigate(delta * (views.item ? views.item.columns : 1));
        else if (mode !== "hex" || (delta < 0 ? selected % viewport.hexRows > 0 : selected % viewport.hexRows < viewport.hexRows - 1))
            navigate(delta);
    }
    function navigateColumns(delta) {
        if (!items.length)
            return;
        if (views.item && views.item.navigateColumns) {
            views.item.navigateColumns(delta);
            return;
        }
        let rows = mode === "hex" ? Math.max(1, Math.min(5, pickerLayout.hexRows || 2)) : (mode === "mosaic" ? 2 : 1);
        let column = Logic.modulo(Math.floor(selected / rows) + delta, Math.ceil(items.length / rows));
        let row = Math.min(selected % rows, items.length - column * rows - 1);
        selected = column * rows + row;
        position(true);
    }
    function select(index) {
        selected = index;
        viewport.forceActiveFocus();
    }
    function focusBrowser() {
        viewport.forceActiveFocus();
    }
    function activate(index) {
        if (busy || index < 0 || index >= items.length)
            return;
        selected = index;
        if (views.item && views.item.pause)
            views.item.pause();
        if (online)
            openPreview(index);
        else
            applyPath(items[index].path);
    }
    function openPreview(index) {
        if (index < 0 || index >= items.length)
            return;
        selected = index;
        previewInfo = ({});
        previewMessage = "";
        // Decode only the full image. A thumbnail followed by the original
        // creates a distracting second resize/flash in this large preview.
        previewSource = "";
        previewOpen = true;
        if (views.item && views.item.pause)
            views.item.pause();
        pendingPreviewId = chosen.id;
        if (previewProcess.running) {
            if (activePreviewId === pendingPreviewId)
                pendingPreviewId = "";
            else if (!waitingDownloadId)
                previewProcess.running = false;
            return;
        }
        drainPreview();
    }
    function drainPreview() {
        if (previewProcess.running || !pendingPreviewId)
            return;
        activePreviewId = pendingPreviewId;
        previewProcess.command = worker(["preview", pendingPreviewId]);
        pendingPreviewId = "";
        previewProcess.running = true;
    }
    function previewNavigate(delta) {
        let next = selected + delta;
        if (next >= 0 && next < items.length)
            openPreview(next);
        maybeLoadMore();
    }
    onPreviewOpenChanged: {
        if (!previewOpen) {
            pendingPreviewId = "";
            if (previewProcess.running && !waitingDownloadId) previewProcess.running = false;
            position(true);
            viewport.forceActiveFocus();
        }
    }
    function savePreference(key, value) {
        preferenceQueue.push([key, value]);
        drainPreferences();
    }
    function drainPreferences() {
        if (preferencesProcess.running || !preferenceQueue.length)
            return;
        preferencesProcess.command = worker(["preferences"].concat(preferenceQueue.shift()));
        preferencesProcess.running = true;
    }
    function favorite(index) {
        let item = items[index];
        if (!item || !item.path)
            return;
        localItems = localItems.map(row => row.path === item.path ? Object.assign({}, row, {
                favorite: !row.favorite
            }) : row);
        savePreference("favorites", item.path);
        filter();
        focusBrowser();
    }
    function setMode(value) {
        mode = value;
        savePreference("mode", value);
        focusBrowser();
        Qt.callLater(function () {
            position(false);
        });
    }
    function switchSource(value) {
        sourceTab = value;
        favoritesOnly = false;
        searchField.text = "";
        message = "";
        filter();
        focusBrowser();
        if (value === "local")
            reloadCatalog();
        if (value !== "local") {
            remoteItems = [];
            remotePage = 1;
            remoteLastPage = 1;
            remoteTopic.currentIndex = value === "nasa" ? 1 : 0;
            filter();
            search(1, true);
        }
    }
    function reloadCatalog() {
        if (sourceTab !== "local")
            return;
        if (preferencesProcess.running || preferenceQueue.length) {
            catalogDelay.restart();
            return;
        }
        if (!catalogProcess.running)
            catalogProcess.running = true;
    }
    function scheduleSearch() {
        if (online)
            remoteSearchDelay.restart();
    }
    function maybeLoadMore() {
        if (!online || searchProcess.running || remoteLoadFailed || remotePage >= remoteLastPage || pendingSearchPage)
            return;
        let near = previewOpen ? selected >= items.length - 6 : (views.item && views.item.nearEnd ? views.item.nearEnd() : false);
        if (near)
            search(remotePage + 1);
    }
    function search(page, force) {
        let signature = JSON.stringify([sourceTab, remoteTopic.currentIndex, searchField.text, remoteSort.currentIndex, categoryBox.currentIndex, purityBox.currentIndex, colorFilter, resolutionField.text, ratioField.text]);
        if (page === 1 && !force && signature === lastSearchSignature && remoteItems.length && !remoteLoadFailed)
            return;
        if (searchProcess.running) {
            pendingSearchPage = page;
            pendingSearchForce = !!force;
            if (page === 1)
                searchProcess.running = false;
            return;
        }
        if (page === 1) {
            lastSearchSignature = signature;
            remoteSeed = "";
        }
        remoteLoadFailed = false;
        activeSearchPage = page;
        message = "";
        let topic = (sourceTab === "nasa" ? ["", "nebula", "galaxy", "earth", "moon", "mars", "jupiter"] : ["", "nature", "landscape", "space", "abstract", "minimalism", "architecture", "cyberpunk", "digital art"])[remoteTopic.currentIndex] || "";
        let query = [searchField.text.trim(), topic].filter(Boolean).join(" ");
        searchProcess.command = worker(["search", "--source", sourceTab, "--query", query, "--page", String(page), "--sort", ["toplist", "date_added", "random", "favorites", "views"][remoteSort.currentIndex], "--categories", ["111", "100", "010", "001"][categoryBox.currentIndex], "--purity", ["100", "110", "111"][purityBox.currentIndex], "--color", colorFilter, "--atleast", resolutionField.text.trim(), "--ratios", ratioField.text.trim(), "--seed", page > 1 ? remoteSeed : ""]);
        searchProcess.running = true;
    }
    function applyChosen() {
        if (busy || !items.length)
            return;
        showMessage("");
        operationLabel = chosen.path ? "Wallpaper instellen…" : "Download voorbereiden…";
        operationStage = chosen.path ? "apply" : "metadata";
        operationPercent = -1;
        if (chosen.path)
            applyPath(chosen.path);
        else {
            pendingApply = true;
            requestDownload(chosen.id);
        }
    }
    function downloadChosen() {
        if (busy || !chosen.id)
            return;
        pendingApply = false;
        showMessage("");
        operationLabel = "Download voorbereiden…";
        operationStage = "metadata";
        operationPercent = -1;
        requestDownload(chosen.id);
    }
    function requestDownload(identifier, ready) {
        // A pending HD preview already downloads these exact bytes. Reuse its
        // published file instead of racing it with a second full-size request.
        if (!ready && previewProcess.running && activePreviewId === identifier) {
            waitingDownloadId = identifier;
            operationStage = "download";
            operationLabel = "Volledige afbeelding laden…";
            return;
        }
        downloadProcess.command = worker(["download", identifier]);
        downloadProcess.running = true;
    }
    function downloadAt(index) {
        if (busy || !items[index] || !items[index].id)
            return;
        selected = index;
        if (views.item && views.item.pause)
            views.item.pause();
        showMessage("");
        downloadChosen();
    }
    function applyAt(index) {
        if (busy || !items[index]) return;
        selected = index;
        if (views.item && views.item.pause) views.item.pause();
        applyChosen();
    }
    function operationProgress(event) {
        if (event.event !== "progress") return;
        operationStage = event.stage;
        operationPercent = event.percent === undefined ? -1 : event.percent;
        operationLabel = event.label + (operationPercent >= 0 ? " " + operationPercent + "%" : "");
    }
    function canRemove(item) {
        return !!item.path && item.path !== currentPath;
    }
    function removeAt(index) {
        let item = items[index];
        if (busy || !item || !canRemove(item))
            return;
        selected = index;
        if (views.item && views.item.pause)
            views.item.pause();
        showMessage("");
        operationLabel = "Naar prullenbak…";
        removeProcess.command = worker(["remove", item.id]);
        removeProcess.running = true;
    }
    function applyPath(path) {
        showMessage("");
        operationLabel = "Wallpaper instellen…";
        operationStage = "apply";
        operationPercent = -1;
        applyProcess.command = worker(["apply", path]);
        applyProcess.running = true;
    }
    function thumbnailFor(item) {
        return thumbnails[item.path] || thumbnails[item.id] || ({});
    }
    function handleCatalog(event) {
        if (event.event === "catalog") {
            localItems = event.items;
            folder = event.folder;
            currentPath = event.current;
            if (!catalogInitialized) {
                mode = event.settings.mode;
                sortMode = event.settings.sort || "color";
                pickerLayout = event.settings.layout || ({});
                catalogInitialized = true;
            }
            filter();
            console.log("Kingstra picker catalog:", localItems.length, "items in", Date.now() - startedMs, "ms");
        } else if (event.event === "thumbnail") {
            let next = Object.assign({}, thumbnails);
            next[event.path] = event;
            thumbnails = next;
        } else if (event.event === "ready") {
            if (sourceTab === "local" && sortMode === "color")
                filter();
        } else if (event.event === "error")
            showMessage(event.message);
    }
    function readPalette() {
        let data = parse(paletteFile.text());
        paletteGroups = data.groups || [
            {
                label: "Tokens",
                colors: data.colors || []
            }
        ];
    }

    IpcHandler {
        target: "picker"
        function close(): void {
            root.close();
        }
        function view(mode: string): void {
            if (["hex", "slices", "wall", "mosaic", "coverflow"].includes(mode))
                root.setMode(mode);
        }
        function move(delta: int): void {
            root.navigate(delta);
        }
        function scroll(columns: int): void {
            root.navigateColumns(columns);
        }
        function trace(enabled: bool): void {
            if (views.item && views.item.trace)
                views.item.trace(enabled);
        }
        function samples(): string {
            return JSON.stringify(views.item && views.item.frameSamples ? views.item.frameSamples : []);
        }
        function browse(query: string): void {
            if (root.sourceTab !== "wallhaven") root.switchSource("wallhaven");
            root.favoritesOnly = false;
            searchField.text = query;
            root.search(1);
        }
        function colour(hue: int): void {
            root.localHue = hue;
            root.filter();
        }
        function current(): void {
            root.sourceTab = "local";
            root.localHue = -1;
            root.filter();
            root.selected = Math.max(0, root.items.findIndex(item => item.path === root.currentPath));
            root.position(false);
        }
        function inspect(): string {
            return JSON.stringify({
                monitor: root.screen.name,
                mode: root.mode,
                sort: root.sortMode,
                source: root.sourceTab,
                count: root.items.length,
                selected: root.selected,
                chosen: root.chosen.name,
                current: root.currentPath,
                filter: root.localHue,
                remoteColor: root.colorFilter,
                previewZoom: previewPane.zoom,
                previewPan: previewPane.panPosition,
                previewMessage: root.previewMessage,
                chosenId: root.chosen.id,
                chosenPath: root.chosen.path,
                chosenFavorite: root.chosen.favorite,
                page: root.remotePage,
                lastPage: root.remoteLastPage,
                preview: root.previewOpen,
                previewLoading: root.previewLoading,
                previewSource: root.previewSource,
                previewInfo: root.previewInfo,
                keyboardFocus: "OnDemand",
                viewport: {
                    x: viewport.mapToItem(null, 0, 0).x,
                    y: viewport.mapToItem(null, 0, 0).y,
                    width: viewport.width,
                    height: viewport.height
                },
                motion: views.item && views.item.inspect ? views.item.inspect() : {},
                operation: root.operationLabel,
                operationPercent: root.operationPercent,
                busy: root.busy,
                loading: root.loading,
                message: root.message
            });
        }
    }
    Process {
        id: catalogProcess
        command: root.worker(["catalog"])
        running: true
        stdout: SplitParser {
            onRead: data => root.handleCatalog(root.parse(data))
        }
        onExited: code => {
            if (code !== 0 && !root.message)
                root.showMessage("Je collectie kon niet worden geladen. Probeer opnieuw.");
        }
    }
    Process {
        id: preferencesProcess
        onExited: code => {
            if (code !== 0)
                root.message = "Instelling opslaan mislukt";
            Qt.callLater(root.drainPreferences);
            Qt.callLater(root.finishClose);
        }
    }
    Process {
        id: searchProcess
        stdout: SplitParser {
            onRead: data => {
                let event = root.parse(data);
                if (event.event === "thumbnail")
                    root.handleCatalog(event);
                if (event.event === "error") {
                    root.message = event.message;
                    root.remoteLoadFailed = true;
                }
                if (event.event === "search") {
                    if (root.pendingSearchPage === 1)
                        return;
                    let append = event.page > 1;
                    if (append) {
                        let ids = ({});
                        root.remoteItems.forEach(item => ids[item.id] = true);
                        root.remoteItems = root.remoteItems.concat(event.items.filter(item => !ids[item.id]));
                    } else
                        root.remoteItems = event.items;
                    root.remotePage = event.page;
                    root.remoteLastPage = event.lastPage;
                    root.remoteSeed = event.seed || "";
                    root.filter(append);
                    if (!append && root.online && root.mode !== "wall") {
                        let rows = root.mode === "hex" ? Math.max(1, Math.min(5, root.pickerLayout.hexRows || 2)) : (root.mode === "mosaic" ? 2 : 1);
                        root.selected = Math.min(root.items.length - 1, Math.floor((root.pickerLayout.hexCols || 9) / 2) * rows);
                        Qt.callLater(function () {
                            root.position(false);
                        });
                    }
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.remoteLoadFailed = true;
            if (code !== 0 && !root.pendingSearchPage && !root.message)
                root.showMessage(root.sourceName + " kon niet worden geladen. Probeer opnieuw.");
            if (root.pendingSearchPage) {
                let page = root.pendingSearchPage, force = root.pendingSearchForce;
                root.pendingSearchPage = 0;
                root.pendingSearchForce = false;
                Qt.callLater(function () {
                    root.search(page, force);
                });
            }
        }
    }
    Process {
        id: previewProcess
        stdout: SplitParser {
            onRead: data => {
                let event = root.parse(data);
                if (root.waitingDownloadId === root.activePreviewId) root.operationProgress(event);
                if (event.event === "preview" && event.id === root.waitingDownloadId) {
                    root.waitingDownloadId = "";
                    root.requestDownload(event.id, true);
                }

                if (event.event === "error" && root.previewOpen && root.activePreviewId === root.chosen.id)
                    root.previewMessage = event.message;
                if (event.event === "preview" && root.previewOpen && event.id === root.chosen.id) {
                    root.previewInfo = event;
                    root.previewSource = event.url;
                    root.previewMessage = "";
                }
            }
        }
        onExited: code => {
            if (root.waitingDownloadId && root.waitingDownloadId === root.activePreviewId) {
                root.waitingDownloadId = "";
                root.showMessage("Afbeelding laden mislukt. Probeer opnieuw.");
                Qt.callLater(root.finishClose);
            }
            if (code !== 0 && root.previewOpen && root.activePreviewId === root.chosen.id && !root.previewMessage)
                root.previewMessage = "Preview laden mislukt. Probeer opnieuw.";
            Qt.callLater(root.drainPreview);
        }
    }
    Process {
        id: downloadProcess
        stdout: SplitParser {
            onRead: data => {
                let event = root.parse(data);
                root.operationProgress(event);
                if (event.event === "error")
                    root.showMessage(event.message);
                if (event.event === "download") {
                    root.remoteItems = root.remoteItems.map(item => item.id === event.id ? Object.assign({}, item, {
                            path: event.path,
                            tags: event.tags || item.tags || []
                        }) : item);
                    root.filter();
                    root.showMessage("Opgeslagen in je wallpapercollectie");
                    if (root.pendingApply)
                        root.applyPath(event.path);
                }
            }
        }
        onExited: code => {
            if (code !== 0 && !root.message)
                root.showMessage("Downloaden mislukt. Probeer opnieuw.");
            Qt.callLater(root.finishClose);
        }
    }
    Process {
        id: removeProcess
        stdout: SplitParser {
            onRead: data => {
                let event = root.parse(data);
                root.operationProgress(event);
                if (event.event === "error")
                    root.showMessage(event.message);
                if (event.event === "removed") {
                    root.localItems = root.localItems.filter(item => item.path !== event.path);
                    root.remoteItems = root.remoteItems.map(item => item.id === event.id ? Object.assign({}, item, {
                            path: event.remaining || ""
                        }) : item);
                    root.filter();
                    root.showMessage("Naar de prullenbak verplaatst");
                }
            }
        }
        onExited: Qt.callLater(root.finishClose)
    }
    Process {
        id: applyProcess
        stdout: SplitParser {
            onRead: data => {
                let event = root.parse(data);
                root.operationProgress(event);
                if (event.event === "error")
                    root.showMessage(event.message);
                if (event.event === "wallpaper-set") root.currentPath = event.path;
                if (event.event === "applied") {
                    root.currentPath = event.path;
                    root.showMessage("Wallpaper ingesteld");
                }
            }
        }
        onExited: code => {
            if (code !== 0 && !root.message)
                root.showMessage("Wallpaper instellen mislukt. Probeer opnieuw.");
            Qt.callLater(root.finishClose);
        }
    }
    FileView {
        id: paletteFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/kingstra/state/matugen-palette.json"
        preload: true
        watchChanges: true
        onLoaded: root.readPalette()
        onFileChanged: reload()
    }
    Timer {
        interval: 2000
        running: root.paletteOpen
        repeat: true
        onTriggered: paletteFile.reload()
    }
    Timer {
        id: localSearchDelay
        interval: 150
        onTriggered: root.filter()
    }
    Timer {
        id: catalogDelay
        interval: 100
        onTriggered: root.reloadCatalog()
    }
    Timer {
        id: remoteSearchDelay
        interval: 400
        onTriggered: root.search(1)
    }
    Timer {
        interval: 250
        repeat: true
        running: root.online
        onTriggered: root.maybeLoadMore()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(c.surface.r, c.surface.g, c.surface.b, Math.max(0.9, Math.min(1, ThemeConfig.popupOpacity)))
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(24, Math.min(root.width, root.height) * 0.045)
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                PickerText {
                    Layout.fillWidth: true
                    text: "Wallpapers"
                    font.pixelSize: 28
                    font.family: ThemeConfig.uiFont
                    font.bold: true
                    color: c.text
                }
                PickerText {
                    Layout.fillWidth: true
                    text: root.sourceTab === "local" ? root.folder : (root.sourceTab === "nasa" ? "NASA Image and Video Library · bronvermelding bij elke afbeelding" : "Wallhaven")
                    font.pixelSize: 12
                    color: c.onSurfaceVariant
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                }
            }
            PickerButton {
                objectName: "source-local"
                colors: c
                text: "Collectie"
                selected: root.sourceTab === "local"
                onClicked: root.switchSource("local")
            }
            PickerButton {
                objectName: "source-wallhaven"
                colors: c
                text: "Wallhaven"
                selected: root.sourceTab === "wallhaven"
                onClicked: root.switchSource("wallhaven")
            }
            PickerButton {
                objectName: "source-nasa"
                colors: c
                text: "NASA"
                selected: root.sourceTab === "nasa"
                onClicked: root.switchSource("nasa")
            }
            PickerButton {
                colors: c
                text: "×"
                onClicked: root.close()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: searchField
                objectName: "search"
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                placeholderText: root.sourceTab === "local" ? "Zoeken in je collectie…" : "Zoeken op " + root.sourceName + "…"
                color: c.text
                placeholderTextColor: c.onSurfaceVariant
                selectionColor: c.primary
                background: Rectangle {
                    color: c.surfaceContainer
                    radius: root.uiRadius
                }
                onTextChanged: {
                    if (root.sourceTab === "local")
                        localSearchDelay.restart();
                    else
                        root.scheduleSearch();
                }
                onAccepted: {
                    if (root.online)
                        root.search(1, true);
                    else
                        viewport.forceActiveFocus();
                }
            }
            PickerCombo {
                id: sortBox
                colors: c
                visible: root.sourceTab === "local"
                model: ["Kleur", "Nieuwste", "Naam"]
                currentIndex: Math.max(0, ["color", "date", "name"].indexOf(root.sortMode))
                onActivated: {
                    root.sortMode = ["color", "date", "name"][currentIndex];
                    root.savePreference("sort", root.sortMode);
                    root.filter();
                    root.focusBrowser();
                }
            }
            PickerButton {
                colors: c
                text: "♥ Favorieten"
                visible: root.sourceTab === "local"
                selected: root.favoritesOnly
                onClicked: {
                    root.favoritesOnly = !root.favoritesOnly;
                    root.filter();
                }
            }
            PickerButton {
                colors: c
                text: "↻"
                visible: root.sourceTab === "local"
                available: !catalogProcess.running
                onClicked: root.reloadCatalog()
            }
            PickerButton {
                colors: c
                text: "Zoeken"
                visible: root.online
                onClicked: root.search(1, true)
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            PickerCombo {
                id: remoteSort
                visible: root.sourceTab === "wallhaven"
                colors: c
                model: ["Populair", "Nieuwste", "Willekeurig", "Favorieten", "Bekeken"]
                onActivated: root.scheduleSearch()
            }
            PickerCombo {
                id: categoryBox
                visible: root.sourceTab === "wallhaven"
                colors: c
                model: ["Alle hoofdcategorieën", "Algemeen", "Anime", "Personen"]
                onActivated: root.scheduleSearch()
            }
            PickerCombo {
                id: remoteTopic
                objectName: "remote-topic"
                visible: root.online
                colors: c
                model: root.sourceTab === "nasa" ? ["Alle onderwerpen", "Nevels", "Sterrenstelsels", "Aarde", "Maan", "Mars", "Jupiter"] : ["Alle onderwerpen", "Natuur", "Landschappen", "Ruimte", "Abstract", "Minimalisme", "Architectuur", "Cyberpunk", "Digitale kunst"]
                onActivated: root.scheduleSearch()
            }
            PickerCombo {
                id: purityBox
                visible: root.sourceTab === "wallhaven"
                colors: c
                model: ["SFW", "SFW + Sketchy", "Alles (API-sleutel)"]
                onActivated: root.scheduleSearch()
            }
            TextField {
                id: resolutionField
                objectName: "remote-resolution"
                visible: root.sourceTab === "wallhaven"
                width: 160
                height: 36
                placeholderText: "Min. 2560x1440"
                color: c.text
                placeholderTextColor: c.onSurfaceVariant
                onEditingFinished: root.scheduleSearch()
                background: Rectangle {
                    color: c.surfaceContainer
                    radius: root.uiRadius
                }
            }
            TextField {
                id: ratioField
                objectName: "remote-ratio"
                visible: root.sourceTab === "wallhaven"
                width: 110
                height: 36
                placeholderText: "Ratio 16x9"
                color: c.text
                placeholderTextColor: c.onSurfaceVariant
                onEditingFinished: root.scheduleSearch()
                background: Rectangle {
                    color: c.surfaceContainer
                    radius: root.uiRadius
                }
            }
            PickerButton {
                visible: root.sourceTab !== "nasa"
                objectName: root.sourceTab === "local" ? "local-colour-all" : "remote-colour-all"
                colors: c
                text: "Alle kleuren"
                selected: root.sourceTab === "local" ? root.localHue < 0 : !root.colorFilter
                onClicked: {
                    if (root.sourceTab === "local") {
                        root.localHue = -1;
                        root.filter();
                    } else {
                        root.colorFilter = "";
                        root.scheduleSearch();
                    }
                    root.focusBrowser();
                }
            }
            Row {
                visible: root.sourceTab !== "nasa"
                spacing: 8
                height: 36
                Repeater {
                    model: root.sourceTab === "local" ? root.localColors : root.wallhavenColors
                    PickerColourChip {
                        required property string modelData
                        required property int index
                        readonly property int hue: index === 12 ? 99 : index
                        objectName: root.sourceTab === "local" ? "local-colour-" + hue : "remote-colour-" + modelData
                        y: 4
                        fill: "#" + modelData
                        outline: c.text
                        label: root.colorNames[index]
                        selected: root.sourceTab === "local" ? root.localHue === hue : root.colorFilter === modelData
                        onClicked: {
                            if (root.sourceTab === "local") {
                                root.localHue = root.localHue === hue ? -1 : hue;
                                root.filter();
                            } else {
                                root.colorFilter = root.colorFilter === modelData ? "" : modelData;
                                root.scheduleSearch();
                            }
                            root.focusBrowser();
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            Repeater {
                model: [
                    {
                        key: "slices",
                        label: "Slices"
                    },
                    {
                        key: "hex",
                        label: "Hexagons"
                    },
                    {
                        key: "wall",
                        label: "Raster"
                    },
                    {
                        key: "mosaic",
                        label: "Mozaïek"
                    },
                    {
                        key: "coverflow",
                        label: "Coverflow"
                    }
                ]
                PickerButton {
                    required property var modelData
                    objectName: "mode-" + modelData.key
                    colors: c
                    text: modelData.label
                    selected: root.mode === modelData.key
                    onClicked: root.setMode(modelData.key)
                }
            }
        }
        Item {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            focus: true
            clip: true
            readonly property int hexRows: Math.max(1, Math.min(5, root.pickerLayout.hexRows || 2))
            Keys.onLeftPressed: root.navigateColumns(-1)
            Keys.onRightPressed: root.navigateColumns(1)
            Keys.onUpPressed: root.navigateVertical(-1)
            Keys.onDownPressed: root.navigateVertical(1)
            Keys.onReturnPressed: {
                if (root.online)
                    root.openPreview(root.selected);
                else
                    root.applyChosen();
            }
            Keys.onEnterPressed: {
                if (root.online)
                    root.openPreview(root.selected);
                else
                    root.applyChosen();
            }
            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_F && root.sourceTab === "local") {
                    root.favorite(root.selected);
                    event.accepted = true;
                }
            }
            Loader {
                id: views
                anchors.fill: parent
                sourceComponent: root.mode === "wall" ? gridComponent : carouselComponent
                onLoaded: Qt.callLater(function () {
                    root.position(false);
                })
            }
            PickerText {
                anchors.centerIn: parent
                visible: root.items.length === 0
                text: root.loading ? "Wallpapers laden…" : (root.message || (root.sourceTab === "local" ? "Geen wallpapers gevonden" : "Geen resultaten"))
                color: c.onSurfaceVariant
                font.pixelSize: 18
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            PickerButton {
                colors: c
                text: "←"
                available: root.items.length > 1
                onClicked: root.navigateColumns(-1)
            }
            PickerButton {
                colors: c
                text: "→"
                available: root.items.length > 1
                onClicked: root.navigateColumns(1)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                PickerText {
                    Layout.fillWidth: true
                    text: root.chosen.displayName || root.chosen.name || ""
                    elide: Text.ElideMiddle
                    color: c.text
                    font.pixelSize: 15
                    font.bold: true
                    textFormat: Text.PlainText
                }
                PickerText {
                    text: root.items.length ? (root.selected + 1) + " / " + root.items.length + "   ·   " + (root.thumbnailFor(root.chosen).dimensions || root.chosen.dimensions || root.chosen.type || "") : ""
                    color: c.onSurfaceVariant
                    font.pixelSize: 12
                }
            }
            PickerText {
                visible: root.online
                text: root.remoteItems.length + " resultaten"
                color: c.onSurfaceVariant
            }
            PickerButton {
                objectName: "remote-retry"
                colors: c
                text: "Opnieuw laden"
                visible: root.online && root.remoteLoadFailed
                onClicked: root.search(root.activeSearchPage || 1)
            }
            PickerButton {
                colors: c
                text: "Vergroten"
                visible: root.online
                available: !!root.chosen.id
                onClicked: root.openPreview(root.selected)
            }
            PickerButton {
                colors: c
                text: "♥"
                visible: root.sourceTab === "local"
                selected: root.chosen.favorite === true
                available: root.items.length > 0
                onClicked: root.favorite(root.selected)
            }
            PickerButton {
                colors: c
                text: root.chosen.path ? "Opgeslagen" : "Downloaden"
                visible: root.online
                available: !root.busy && !!root.chosen.id && !root.chosen.path
                onClicked: root.downloadChosen()
            }
            PickerButton {
                colors: c
                text: root.busy ? root.operationButtonLabel : "Instellen"
                selected: true
                available: !root.busy && root.items.length > 0
                onClicked: root.applyChosen()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            PickerText {
                text: (root.busy ? root.operationLabel : root.message) || (root.sourceTab === "local" ? "Klik of Enter instellen    ← → kiezen    F favoriet    Esc sluiten" : "Klik of Enter bekijken    Scroll voor meer resultaten    Esc sluiten")
                color: c.onSurfaceVariant
                font.pixelSize: 12
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            PickerText {
                text: root.loading ? "Laden…" : ""
                color: c.onSurfaceVariant
                font.pixelSize: 12
            }
            PickerButton {
                colors: c
                text: "Matugen tokens"
                selected: root.paletteOpen
                onClicked: root.paletteOpen = !root.paletteOpen
            }
        }
    }

    Component {
        id: carouselComponent
        WallpaperCarousel {
            controller: root
            colors: c
        }
    }
    Component {
        id: gridComponent
        GridView {
            id: grid
            anchors.fill: parent
            readonly property int columns: Math.max(2, Math.floor(width / 290))
            cellWidth: width / columns
            cellHeight: cellWidth * 0.62
            model: tileModel
            cacheBuffer: cellHeight
            reuseItems: true
            clip: true
            onContentYChanged: {
                if (!count || root.previewOpen)
                    return;
                let first = Math.max(0, Math.floor((contentY + 1) / cellHeight) * columns);
                let last = Math.min(count - 1, Math.ceil((contentY + height - 1) / cellHeight) * columns - 1);
                if (root.selected < first || root.selected > last)
                    root.selected = Math.min(count - 1, first + root.selected % columns);
            }
            function positionSelected() {
                positionViewAtIndex(root.selected, GridView.Contain);
            }
            function nearEnd() {
                return contentY + height > contentHeight - cellHeight * 2;
            }
            function inspect() {
                return {
                    contentY: contentY,
                    contentHeight: contentHeight,
                    columns: columns,
                    selectionPoint: selectionPoint()
                };
            }
            function selectionPoint() {
                return {
                    x: (root.selected % columns + 0.5) * cellWidth,
                    y: (Math.floor(root.selected / columns) + 0.5) * cellHeight - contentY
                };
            }
            delegate: WallpaperCard {
                required property int index
                width: grid.cellWidth - 12
                height: grid.cellHeight - 12
                itemData: root.items[index] || ({})
                remote: root.online
                actionBusy: root.busy
                removable: root.canRemove(itemData)
                shaderSource: root.cardShader
                vertexSource: root.cardVertexShader
                thumbnail: root.thumbnailFor(itemData)
                colors: c
                selected: root.selected === index
                fontFamily: root.uiFont
                current: !!itemData.path && itemData.path === root.currentPath
                onPicked: root.activate(index)
                onApplyRequested: root.applyAt(index)
                onDownloadRequested: root.downloadAt(index)
                onRemoveRequested: root.removeAt(index)
                onFavoriteRequested: root.favorite(index)
            }
        }
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.previewOpen)
                root.previewOpen = false;
            else if (root.paletteOpen)
                root.paletteOpen = false;
            else
                root.close();
        }
    }
    WallpaperPreview {
        id: previewPane
        objectName: "preview"
        anchors.fill: parent
        z: 100
        controller: root
        colors: c
        visible: root.previewOpen
    }
    Rectangle {
        visible: root.paletteOpen
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            margins: 32
        }
        width: Math.min(520, root.width - 64)
        radius: 20
        color: c.surfaceContainer
        border.color: c.primary
        MouseArea {
            anchors.fill: parent
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            RowLayout {
                PickerText {
                    text: "Matugen tokens"
                    font.pixelSize: 20
                    color: c.text
                    Layout.fillWidth: true
                }
                PickerButton {
                    colors: c
                    text: "×"
                    onClicked: root.paletteOpen = false
                }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Column {
                    width: parent.width
                    spacing: 18
                    Repeater {
                        model: root.paletteGroups
                        Column {
                            required property var modelData
                            width: parent.width
                            spacing: 6
                            PickerText {
                                text: parent.modelData.label
                                color: c.text
                                font.bold: true
                            }
                            Repeater {
                                model: parent.modelData.colors
                                Row {
                                    required property var modelData
                                    spacing: 10
                                    Rectangle {
                                        width: 26
                                        height: 24
                                        radius: 5
                                        color: parent.modelData.hex || parent.modelData.color || "transparent"
                                    }
                                    PickerText {
                                        text: parent.modelData.key + "  " + (parent.modelData.hex || "")
                                        color: c.text
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
