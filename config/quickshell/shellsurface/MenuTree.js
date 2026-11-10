.pragma library

// De boom van het toetsenbordmenu (Super+Ctrl+Space). Gedeeld door
// KingstraMenu.qml (bladeren) en LauncherPanel.qml (alles-zoeken), zodat er
// één lijst met acties is.
//
// Elk item: label, icon, en óf children (submenu) óf cmd (argv). hint is de
// sneltoets. panel: true betekent dat de actie zelf een paneel opent; dan
// sluit het menu niet eerst via qs_manager close (dat zou het paneel weer
// dichtdoen).

function build(home, scripts) {
    function qs(target, sub) {
        return ["bash", scripts + "/qs_manager.sh", "toggle", target].concat(sub ? [sub] : []);
    }
    function kingstra(args) {
        return ["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\" kingstra " + args];
    }
    function inTerminal(cmd) {
        return ["kitty", "--hold", "bash", "-lc", cmd];
    }

    return [
        { icon: "󱓞", label: "Apps", hint: "Launcher", cmd: qs("launcher"), panel: true },
        { icon: "󰊢", label: "Werkruimte-overzicht", hint: "Super+Tab", cmd: ["bash", scripts + "/overview-toggle.sh"] },
        { icon: "󰕰", label: "Vensters", children: [
            { icon: "󰕰", label: "Wisselen met voorbeelden", hint: "Super+Ctrl+Tab", cmd: qs("switcher"), panel: true },
            { icon: "󰕰", label: "Indeling kiezen", hint: "Super+Z", cmd: qs("snap"), panel: true },
            { icon: "󰕰", label: "Volgende indeling (tegels, scrollen, ruimtelijk)", cmd: ["bash", scripts + "/layout-tool.sh", "next"] },
            { icon: "󰁔", label: "Scrollen aan of uit", hint: "Super+Alt+S", cmd: ["bash", scripts + "/layout-tool.sh", "scroll"] },
            { icon: "󰕴", label: "Terug naar tegels", cmd: ["bash", scripts + "/layout-tool.sh", "apply", "tegels"] },
            { icon: "󰠮", label: "Kladblok tonen", hint: "Super+`", cmd: ["bash", scripts + "/scratchpad.sh", "toggle"] },
            { icon: "󰁝", label: "Venster naar kladblok", hint: "Super+Shift+`", cmd: ["bash", scripts + "/scratchpad.sh", "send"] },
            { icon: "󰖰", label: "Venster parkeren", hint: "Super+-", cmd: ["python3", scripts + "/park-window.py", "park"] },
            { icon: "󰖯", label: "Geparkeerd venster terug", hint: "Super+Shift+-", cmd: ["python3", scripts + "/park-window.py", "last"] },
            { icon: "󰐃", label: "Op alle werkruimtes vastzetten", cmd: ["hyprctl", "dispatch", "hl.dsp.window.pin()"] },
            { icon: "󰓩", label: "Venster uit groep halen", cmd: ["hyprctl", "dispatch", "hl.dsp.group.move_window({ action = \"out\" })"] },
            { icon: "󰌾", label: "Groep vergrendelen of vrijgeven", cmd: ["hyprctl", "dispatch", "hl.dsp.group.lock_active({ action = \"toggle\" })"] }
        ] },
        { icon: "󰏘", label: "Uiterlijk", children: [
            { icon: "󰏘", label: "Thema", children: [
                { icon: "󰝤", label: "Matte", cmd: kingstra("theme matte") },
                { icon: "󰝤", label: "Mono", cmd: kingstra("theme mono") },
                { icon: "󰝤", label: "Mono accent", cmd: kingstra("theme mono-accent") },
                { icon: "󰝤", label: "Neon", cmd: kingstra("theme neon") },
                { icon: "󰝤", label: "Organic", cmd: kingstra("theme organic") },
                { icon: "󰝤", label: "Paper", cmd: kingstra("theme paper") },
                { icon: "󰑐", label: "Volgend thema", hint: "Super+Shift+T", cmd: ["bash", scripts + "/theme-next-safe.sh"] }
            ] },
            { icon: "󰸉", label: "Achtergrond", children: [
                { icon: "󰋩", label: "Kiezer", hint: "Super+Ctrl+W", cmd: ["bash", scripts + "/wallpaper-picker-safe.sh"] },
                { icon: "󰒝", label: "Willekeurig", hint: "Super+Shift+W", cmd: ["bash", scripts + "/wallpaper-random-safe.sh"] }
            ] },
            { icon: "󰥔", label: "Bureaubladwidgets", children: [
                { icon: "󰔡", label: "Aan of uit", cmd: kingstra("widgets wissel") },
                { icon: "󰁜", label: "Klok linksboven", cmd: kingstra("widgets klok linksboven") },
                { icon: "󰁝", label: "Klok rechtsboven", cmd: kingstra("widgets klok rechtsboven") },
                { icon: "󰘞", label: "Klok in het midden", cmd: kingstra("widgets klok midden") },
                { icon: "󰁆", label: "Klok linksonder", cmd: kingstra("widgets klok linksonder") },
                { icon: "󰁅", label: "Klok rechtsonder", cmd: kingstra("widgets klok rechtsonder") },
                { icon: "󰝚", label: "Mediakaart aan", cmd: kingstra("widgets media aan") },
                { icon: "󰝛", label: "Mediakaart uit", cmd: kingstra("widgets media uit") },
                { icon: "󰀥", label: "Draaitafel schermvullend", cmd: kingstra("vinyl") },
                { icon: "󰗅", label: "Cassettespeler schermvullend", cmd: kingstra("cassette") },
                { icon: "󰗮", label: "Discman schermvullend", cmd: kingstra("discman") },
                { icon: "󰀥", label: "Draaitafel als screensaver aan", cmd: kingstra("vinyl auto 120") },
                { icon: "󰀥", label: "Draaitafel als screensaver uit", cmd: kingstra("vinyl auto uit") }
            ] },
            { icon: "󰒓", label: "Thema aanpassen", cmd: ["bash", scripts + "/qs_manager.sh", "open", "settings", "uiterlijk"] }
        ] },
        { icon: "󰾅", label: "Stand", children: [
            { icon: "󰈙", label: "Werken (Office)", cmd: kingstra("mode office") },
            { icon: "󰊴", label: "Spelen (Gaming)", cmd: kingstra("mode gaming") },
            { icon: "󰝚", label: "Kijken en luisteren (Media)", cmd: kingstra("mode media") },
            { icon: "󰚀", label: "Zen aan of uit", hint: "Super+Shift+Z", cmd: ["bash", scripts + "/zen.sh", "toggle"] }
        ] },
        { icon: "󰏘", label: "Sfeer: thema, wallpaper, stand", hint: "Super+A", cmd: qs("bediening"), panel: true },
        { icon: "󰕮", label: "Snel schakelen", children: [
            { icon: "󰕮", label: "Controlecentrum", cmd: qs("tophover"), panel: true },
            { icon: "󰤨", label: "Wi-Fi aan/uit", cmd: ["bash", "-lc", "[ \"$(nmcli radio wifi)\" = enabled ] && nmcli radio wifi off || nmcli radio wifi on"] },
            { icon: "󰂯", label: "Bluetooth aan/uit", cmd: ["bash", home + "/.config/quickshell/network/bluetooth_panel_logic.sh", "--toggle"] },
            { icon: "󰤨", label: "Netwerk beheren (nmtui)", cmd: ["kitty", "--title=Network", "nmtui"] },
            { icon: "󰂱", label: "Bluetooth-apparaten", cmd: ["blueman-manager"] },
            { icon: "󰂛", label: "Niet storen aan/uit", cmd: ["bash", home + "/.config/quickshell/notifications/notification_control.sh", "dnd"] },
            { icon: "󰑐", label: "Laatst weggeklikte melding terug", cmd: ["bash", home + "/.config/quickshell/notifications/notification_control.sh", "recall"] },
            { icon: "󰓅", label: "Energieprofiel", children: [
                { icon: "󰌪", label: "Energiebesparing", cmd: ["powerprofilesctl", "set", "power-saver"] },
                { icon: "󰾅", label: "Gebalanceerd", cmd: ["powerprofilesctl", "set", "balanced"] },
                { icon: "󰓅", label: "Prestaties", cmd: ["powerprofilesctl", "set", "performance"] }
            ] }
        ] },
        { icon: "󰍹", label: "Schermen", children: [
            { icon: "󰍹", label: "Schermindeling", cmd: qs("monitors"), panel: true },
            { icon: "󰓶", label: "Tabletmodus aan/uit", cmd: ["bash", scripts + "/tablet-mode.sh", "toggle"] }
        ] },
        { icon: "󰄀", label: "Vastleggen", children: [
            { icon: "󰄀", label: "Vastleg-studio", hint: "Super+Ctrl+Print", cmd: qs("capture"), panel: true },
            { icon: "󰹑", label: "Schermafbeelding van gebied", cmd: ["bash", scripts + "/screenshot.sh", "--preview"] },
            { icon: "󰍹", label: "Schermafbeelding van scherm", hint: "Ctrl+Print", cmd: ["bash", scripts + "/screenshot.sh", "--full"] },
            { icon: "󰖯", label: "Schermafbeelding van venster", cmd: ["bash", scripts + "/screenshot.sh", "--window", "--preview"] },
            { icon: "󰑋", label: "Schermopname starten of stoppen", hint: "Super+Shift+R", cmd: ["bash", scripts + "/capture.sh", "record", "area"] },
            { icon: "󰈙", label: "Tekst uit beeld kopiëren", cmd: ["bash", scripts + "/capture.sh", "ocr"] },
            { icon: "󰏫", label: "Schermafbeelding met notities", hint: "Shift+Print", cmd: ["bash", scripts + "/screenshot.sh", "--annotate"] },
            { icon: "󰈊", label: "Kleur kiezen", cmd: ["bash", scripts + "/capture.sh", "color"] },
            { icon: "󰅌", label: "Klembord", hint: "Super+V", cmd: qs("clipboard"), panel: true }
        ] },
        { icon: "󰒓", label: "Systeem", children: [
            { icon: "󰒓", label: "Instellingen", hint: "Super+Ctrl+I", cmd: ["bash", scripts + "/qs_manager.sh", "open", "settings"] },
            { icon: "󰚰", label: "Bijwerken", cmd: inTerminal("kingstra update") },
            { icon: "󰓙", label: "Controleren (doctor)", cmd: inTerminal("kingstra doctor") },
            { icon: "󰁯", label: "Terugzetpunt maken", cmd: inTerminal("kingstra snapshot create") },
            { icon: "󰑓", label: "Shell herstarten", cmd: kingstra("restart") },
            { icon: "󰃭", label: "Kalender", cmd: qs("calendar"), panel: true },
            { icon: "󱎫", label: "FocusTime", cmd: qs("focustime"), panel: true },
            { icon: "󰊴", label: "Games", cmd: qs("gaming"), panel: true },
            { icon: "󰉋", label: "Yazi (bestanden in terminal)", cmd: ["kitty", "--title=yazi", "yazi"] },
            { icon: "󰍛", label: "Systeemmonitor", cmd: ["kitty", "--title", "btop — Kingstra", "bash", "-lc", "exec btop"] }
        ] },
        { icon: "󰐥", label: "Sessie", children: [
            { icon: "󰌾", label: "Vergrendelen", hint: "Super+Ctrl+L", cmd: ["bash", scripts + "/lock.sh"] },
            { icon: "󰤄", label: "Slaapstand", cmd: ["bash", scripts + "/suspend.sh"] },
            { icon: "󰜉", label: "Opnieuw opstarten", cmd: ["systemctl", "reboot"] },
            { icon: "󰐥", label: "Uitschakelen", cmd: ["systemctl", "poweroff"] },
            { icon: "󰍃", label: "Afsluitmenu", cmd: qs("power"), panel: true }
        ] },
        { icon: "󰋖", label: "Sneltoetsen", hint: "Super+F1", cmd: qs("help"), panel: true }
    ];
}

// Alle uitvoerbare items plat, met het pad erbij: [{ item, path: "Uiterlijk › Thema" }].
function flatten(tree) {
    let out = [];
    function walk(level, trail) {
        for (let i = 0; i < level.length; i++) {
            let it = level[i];
            if (it.children) walk(it.children, trail.concat([it.label]));
            else if (it.cmd) out.push({ item: it, path: trail.join(" › ") });
        }
    }
    walk(tree, []);
    return out;
}
