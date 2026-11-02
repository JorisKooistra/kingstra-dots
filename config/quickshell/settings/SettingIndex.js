.pragma library

// Losse instellingen met de pagina waar ze staan. Gedeeld door de
// instellingen-app (zoeken) en de launcher (voorvoegsel /). Labels zijn de
// koppen zoals ze op de pagina staan; editor = tabblad van de thema-editor,
// section = uitklapblok dat bij openen meteen openklapt.

var entries = [
    { label: "Thema kiezen", page: 1, where: "Uiterlijk › Thema", keywords: "theme carousel actief thema toepassen preview" },
    { label: "Licht of donker", page: 2, editor: "colors", where: "Uiterlijk › Aanpassen › Kleuren", keywords: "dark light donker licht modus mode" },
    { label: "Kleurstijl en contrast", page: 2, editor: "colors", where: "Uiterlijk › Aanpassen › Kleuren", keywords: "matugen scene scheme kleur color contrast wallpaper index" },
    { label: "Icoonthema", page: 2, editor: "colors", where: "Uiterlijk › Aanpassen › Kleuren", keywords: "icon icons iconen gtk qt papirus" },
    { label: "Lettertypes", page: 2, editor: "fonts", where: "Uiterlijk › Aanpassen › Letters", keywords: "font lettertype tekst koppen mono terminal grootte dikte gewicht letterafstand spacing" },
    { label: "Hoekrondheid en randen van vensters", page: 2, editor: "windows", where: "Uiterlijk › Aanpassen › Vensters", keywords: "radius rond rounding hoeken border rand dikte" },
    { label: "Ruimte tussen vensters", page: 2, editor: "windows", where: "Uiterlijk › Aanpassen › Vensters", keywords: "gaps marge ruimte tussenruimte schermrand" },
    { label: "Vervaging", page: 2, editor: "windows", where: "Uiterlijk › Aanpassen › Vensters", keywords: "blur wazig vervagen lagen passes" },
    { label: "Strook boven of onder", page: 2, editor: "shell", where: "Uiterlijk › Aanpassen › Strook en panelen", keywords: "bar topbar strook statusbalk boven onder hoogte positie" },
    { label: "Rail links of rechts", page: 2, editor: "shell", where: "Uiterlijk › Aanpassen › Strook en panelen", keywords: "rail zijbalk links rechts breedte" },
    { label: "Doorzichtigheid en animatie", page: 2, editor: "shell", where: "Uiterlijk › Aanpassen › Strook en panelen", keywords: "opacity doorzichtig transparant dekking animatie snelheid beweging motion" },
    { label: "Randen, glas en gloed", page: 2, editor: "shell", where: "Uiterlijk › Aanpassen › Strook en panelen", keywords: "outline rand glas glass gloed glow effecten neon rondheid panelen" },
    { label: "Alle themavariabelen", page: 2, section: "thema", where: "Uiterlijk › Aanpassen", keywords: "variabelen toml matugen sjablonen templates" },
    { label: "Rail-indeling", page: 15, where: "Bediening › Rail-indeling", keywords: "rail volgorde slepen tweede rail links rechts verplaatsen knoppen" },
    { label: "Eigen apps in de rail", page: 15, where: "Bediening › Rail-indeling", keywords: "app launcher knop snelkoppeling eigen commando rail" },
    { label: "Aantal werkruimtes", page: 15, where: "Bediening › Rail-indeling", keywords: "werkruimtes workspaces aantal rail" },
    { label: "Sneltoetsen bewerken", page: 4, where: "Sneltoetsen", keywords: "keybind toets sneltoets binding super" },
    { label: "Scrollsnelheid", page: 5, where: "Apparaten › Invoer", keywords: "scroll touchpad muis snelheid" },
    { label: "Toetsenbordindeling", page: 5, where: "Apparaten › Invoer", keywords: "keyboard layout taal us intl qwerty" },
    { label: "Rechtsklik op touchpad", page: 5, section: "invoer", where: "Apparaten › Invoer › Geavanceerd", keywords: "rechtsklik touchpad klikgebied tweevinger" },
    { label: "Dode toetsen (accenten)", page: 5, section: "invoer", where: "Apparaten › Invoer › Geavanceerd", keywords: "dead keys dode toetsen accenten aanhalingstekens" },
    { label: "Schermindeling", page: 6, where: "Apparaten › Beeldschermen", keywords: "monitor layout indeling resolutie scherm" },
    { label: "Hoofdscherm", page: 6, where: "Apparaten › Beeldschermen", keywords: "primary hoofd rail anker monitor" },
    { label: "Helderheid", page: 6, where: "Apparaten › Beeldschermen", keywords: "brightness helderheid licht" },
    { label: "Tabletmodus", page: 6, where: "Apparaten › Beeldschermen", keywords: "tablet touch aanraak" },
    { label: "Workspaces per scherm", page: 6, section: "beeldschermen", where: "Apparaten › Beeldschermen › Geavanceerd", keywords: "workspace werkruimte monitor vastzetten toewijzen" },
    { label: "Wifi en bluetooth", page: 7, where: "Apparaten › Netwerk", keywords: "wifi netwerk bluetooth draadloos" },
    { label: "Uitvoer en invoer", page: 8, where: "Apparaten › Geluid", keywords: "speaker koptelefoon microfoon output input audio standaard" },
    { label: "Volume per app", page: 8, section: "geluid", where: "Apparaten › Geluid › Alle apparaten en apps", keywords: "app streams mixer volume" },
    { label: "Tijd- en datumnotatie", page: 9, section: "tijd", where: "Systeem › Tijd & weer", keywords: "tijd datum notatie formaat 24 uur klok" },
    { label: "Weer-API en locatie", page: 9, where: "Systeem › Tijd & weer", keywords: "weer openweather api sleutel locatie eenheden celsius" },
    { label: "Modus (office, gaming, media)", page: 10, where: "Systeem › Sessie", keywords: "mode modus office gaming media" },
    { label: "Automatisch vergrendelen", page: 10, section: "sessie", where: "Systeem › Sessie › Vergrendelen en slaapstand", keywords: "idle lock vergrendelen scherm uit dpms slaapstand suspend timeout" },
    { label: "Apps echt sluiten", page: 10, where: "Systeem › Sessie", keywords: "tray systeemtray achtergrond sluiten afsluiten quit kill chatgpt privacy minimaliseren" },
    { label: "Energieprofiel", page: 10, section: "sessie", where: "Systeem › Sessie › Vergrendelen en slaapstand", keywords: "power profile performance balanced saver batterij" },
    { label: "Updates", page: 11, where: "Systeem › Updates", keywords: "update pakketten dotfiles upgrade" },
    { label: "Shell herstarten", page: 12, where: "Systeem › Onderhoud", keywords: "quickshell herstart topbar herladen matugen render" },
    { label: "Verwijderen", page: 12, section: "verwijderen", where: "Systeem › Onderhoud › Verwijderen en details", keywords: "uninstall verwijderen restore" },
    { label: "Over Kingstra", page: 13, where: "Systeem › Over", keywords: "versie over github onderdelen" }
];

// Paginanummer naar de naam die qs_manager.sh open settings <naam> kent.
var pageNames = {
    1: "thema", 2: "aanpassen", 4: "sneltoetsen", 5: "invoer", 6: "beeldschermen",
    7: "netwerk", 8: "geluid", 9: "tijd", 10: "sessie", 11: "updates",
    12: "geavanceerd", 13: "over"
};

function search(query, limit) {
    var q = String(query || "").trim().toLowerCase();
    if (q.length < 2) return [];
    var words = q.split(/\s+/);
    var out = [];
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        var hay = (e.label + " " + e.where + " " + e.keywords).toLowerCase();
        var ok = true;
        for (var w = 0; w < words.length; w++) {
            if (hay.indexOf(words[w]) === -1) { ok = false; break; }
        }
        if (ok) out.push(e);
        if (out.length >= (limit || 8)) break;
    }
    return out;
}

// Diepe link voor een treffer: "thema/fonts" opent ook het juiste tabblad,
// "invoer/invoer" klapt het uitklapblok van die pagina open.
function deepLink(entry) {
    var name = pageNames[entry.page] || String(entry.page);
    if (entry.editor) return name + "/" + entry.editor;
    return entry.section ? name + "/" + entry.section : name;
}
