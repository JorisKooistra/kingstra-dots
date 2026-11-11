.pragma library

// Losse instellingen met de pagina waar ze staan. Gedeeld door de
// instellingen-app (zoeken) en de launcher (voorvoegsel /). Labels zijn de
// koppen zoals ze op de pagina staan; editor = tabblad van de thema-editor,
// section = uitklapblok dat bij openen meteen openklapt.

var entries = [
    { label: "Accentkleur", page: 17, where: "Uiterlijk", keywords: "accent kleur wallpaper primair aanpassen" },
    { label: "Licht of donker", page: 17, where: "Uiterlijk", keywords: "dark light donker licht modus" },
    { label: "Rondheid", page: 17, where: "Uiterlijk", keywords: "rond hoeken radius strak zacht" },
    { label: "Ruimte", page: 17, where: "Uiterlijk", keywords: "ruimte compact ruim gaps dichtheid density" },
    { label: "Lettertype", page: 17, where: "Uiterlijk", keywords: "font letters lettertype" },
    { label: "Origineel thema terug", page: 17, where: "Uiterlijk", keywords: "reset herstel origineel standaard thema aanpassingen" },
    { label: "Zijbalk verbergen", page: 18, where: "Bureaublad › Zijbalk", keywords: "rail zijbalk autohide verbergen rand" },
    { label: "Wat staat in de zijbalk", page: 18, where: "Bureaublad › Zijbalk", keywords: "rail zijbalk knoppen modules klok geluid batterij" },
    { label: "Indeling van de werkruimte", page: 18, where: "Bureaublad", keywords: "indeling tegels scrollen scrollstrook ruimtelijk werkvlak 50 70 layout" },
    { label: "Vanzelf: spel, batterij, scherm delen", page: 18, where: "Bureaublad › Vanzelf", keywords: "automatisch vanzelf gaming spel batterij zuinig delen screencast" },
    { label: "Speler op het bureaublad", page: 18, where: "Bureaublad", keywords: "speler muziek plaat vinyl cassette discman hoes" },
    { label: "Wallpaperkiezer: weergave en bronnen", page: 18, where: "Bureaublad › Wallpapers", keywords: "wallpaper kiezer picker weergave hexagon raster bronnen tabs moewalls pixabay wallhaven sfeer sorteren ai" },
    { label: "Video-wallpapers op schermmaat", page: 18, where: "Bureaublad › Wallpapers", keywords: "video wallpaper resolutie 1080p 1440p 4k fps beelden per seconde normaliseren omzetten mpvpaper" },
    { label: "Scrollbreedte en vastklikken", page: 18, where: "Bureaublad › Geavanceerd", keywords: "scroll kolom breedte snap vastklikken slepen" },
    { label: "Niet storen", page: 19, where: "Meldingen en rust", keywords: "dnd niet storen stil meldingen" },
    { label: "Meldingen per app", page: 19, where: "Meldingen en rust", keywords: "meldingen app regels stil nooit altijd notificaties" },
    { label: "Thema kiezen", page: 17, where: "Super+A (Sfeer)", keywords: "theme thema wisselen matte mono neon organic paper wallpaper achtergrond" },
    { label: "Kleurstijl en contrast", page: 2, editor: "colors", where: "Uiterlijk › Alle onderdelen › Kleuren", keywords: "matugen scene scheme kleur color contrast wallpaper index" },
    { label: "Icoonthema", page: 2, editor: "colors", where: "Uiterlijk › Alle onderdelen › Kleuren", keywords: "icon icons iconen gtk qt papirus" },
    { label: "Lettertypes", page: 2, editor: "fonts", where: "Uiterlijk › Alle onderdelen › Letters", keywords: "font lettertype tekst koppen mono terminal grootte dikte gewicht letterafstand spacing" },
    { label: "Hoekrondheid en randen van vensters", page: 2, editor: "windows", where: "Uiterlijk › Alle onderdelen › Vensters", keywords: "radius rond rounding hoeken border rand dikte" },
    { label: "Ruimte tussen vensters", page: 2, editor: "windows", where: "Uiterlijk › Alle onderdelen › Vensters", keywords: "gaps marge ruimte tussenruimte schermrand" },
    { label: "Vervaging", page: 2, editor: "windows", where: "Uiterlijk › Alle onderdelen › Vensters", keywords: "blur wazig vervagen lagen passes" },
    { label: "Strook boven of onder", page: 2, editor: "shell", where: "Uiterlijk › Alle onderdelen › Strook en panelen", keywords: "bar topbar strook statusbalk boven onder hoogte positie" },
    { label: "Zijbalk links of rechts", page: 2, editor: "shell", where: "Uiterlijk › Alle onderdelen › Strook en panelen", keywords: "rail zijbalk links rechts breedte" },
    { label: "Doorzichtigheid en animatie", page: 2, editor: "shell", where: "Uiterlijk › Alle onderdelen › Strook en panelen", keywords: "opacity doorzichtig transparant dekking animatie snelheid beweging motion" },
    { label: "Randen, glas en gloed", page: 2, editor: "shell", where: "Uiterlijk › Alle onderdelen › Strook en panelen", keywords: "outline rand glas glass gloed glow effecten neon rondheid panelen" },
    { label: "Alle themavariabelen", page: 2, section: "thema", where: "Uiterlijk › Alle onderdelen", keywords: "variabelen toml matugen sjablonen templates" },
    { label: "Zijbalk-indeling", page: 15, where: "Bureaublad › Zijbalk-indeling", keywords: "rail volgorde slepen tweede rail links rechts verplaatsen knoppen" },
    { label: "Eigen apps in de zijbalk", page: 15, where: "Bureaublad › Zijbalk-indeling", keywords: "app launcher knop snelkoppeling eigen commando rail" },
    { label: "Aantal werkruimtes", page: 15, where: "Bureaublad › Zijbalk-indeling", keywords: "werkruimtes workspaces aantal rail" },
    { label: "Sneltoetsen bewerken", page: 4, where: "Invoer en sneltoetsen › Sneltoetsen", keywords: "keybind toets sneltoets binding super" },
    { label: "Scrollsnelheid", page: 5, where: "Invoer en sneltoetsen › Invoer", keywords: "scroll touchpad muis snelheid" },
    { label: "Toetsenbordindeling", page: 5, where: "Invoer en sneltoetsen › Invoer", keywords: "keyboard layout taal us intl qwerty" },
    { label: "Rechtsklik op touchpad", page: 5, section: "invoer", where: "Invoer en sneltoetsen › Invoer › Geavanceerd", keywords: "rechtsklik touchpad klikgebied tweevinger" },
    { label: "Dode toetsen (accenten)", page: 5, section: "invoer", where: "Invoer en sneltoetsen › Invoer › Geavanceerd", keywords: "dead keys dode toetsen accenten aanhalingstekens" },
    { label: "Schermindeling", page: 6, where: "Schermen", keywords: "monitor layout indeling resolutie scherm" },
    { label: "Hoofdscherm", page: 6, where: "Schermen", keywords: "primary hoofd rail anker monitor" },
    { label: "Helderheid", page: 6, where: "Schermen", keywords: "brightness helderheid licht" },
    { label: "Nachtlicht", page: 19, where: "Meldingen en rust", keywords: "nachtlicht night light warm blauw licht avond schema hyprsunset kleurtemperatuur" },
    { label: "Tabletmodus", page: 6, where: "Schermen", keywords: "tablet touch aanraak" },
    { label: "Workspaces per scherm", page: 6, section: "beeldschermen", where: "Schermen › Geavanceerd", keywords: "workspace werkruimte monitor vastzetten toewijzen" },
    { label: "Wifi en bluetooth", page: 7, where: "Netwerk en Bluetooth", keywords: "wifi netwerk bluetooth draadloos" },
    { label: "Uitvoer en invoer", page: 8, where: "Geluid", keywords: "speaker koptelefoon microfoon output input audio standaard" },
    { label: "Volume per app", page: 8, section: "geluid", where: "Geluid › Alle apparaten en apps", keywords: "app streams mixer volume" },
    { label: "Tijd- en datumnotatie", page: 9, section: "tijd", where: "Systeem › Tijd en weer", keywords: "tijd datum notatie formaat 24 uur klok" },
    { label: "Weer-API en locatie", page: 9, where: "Systeem › Tijd en weer", keywords: "weer openweather api sleutel locatie eenheden celsius" },
    { label: "Stand per scherm (Werken, Spelen, Kijken)", page: 0, where: "Schermen › Per scherm", keywords: "stand mode modus office gaming media per scherm" },
    { label: "Automatisch vergrendelen", page: 10, section: "sessie", where: "Systeem › Energie en sessie › Vergrendelen en slaapstand", keywords: "idle lock vergrendelen scherm uit dpms slaapstand suspend timeout" },
    { label: "Apps echt sluiten", page: 10, where: "Systeem › Energie en sessie", keywords: "tray systeemtray achtergrond sluiten afsluiten quit kill chatgpt privacy minimaliseren" },
    { label: "Energieprofiel", page: 10, section: "sessie", where: "Systeem › Energie en sessie › Vergrendelen en slaapstand", keywords: "power profile performance balanced saver batterij" },
    { label: "Updates", page: 11, where: "Systeem › Updates", keywords: "update pakketten dotfiles upgrade kernel arch nieuws" },
    { label: "Laatste update terugdraaien", page: 11, where: "Systeem › Updates", keywords: "terugdraaien rollback downgrade herstel kapot vorige versie" },
    { label: "Herstelmenu", page: 11, where: "Systeem › Updates", keywords: "herstel rescue noodmenu kapot start niet" },
    { label: "Gezondheid", page: 11, where: "Systeem › Updates", keywords: "gezondheid controle check schijf ruimte boot kernel smart" },
    { label: "Back-up", page: 20, where: "Systeem › Back-up", keywords: "back-up backup restic versies kopie schijf data terughalen herstellen bestand kwijt" },
    { label: "Shell herstarten", page: 12, where: "Systeem › Onderhoud", keywords: "quickshell herstart topbar herladen matugen render" },
    { label: "Verwijderen", page: 12, section: "verwijderen", where: "Systeem › Onderhoud › Verwijderen en details", keywords: "uninstall verwijderen restore" },
    { label: "Over Kingstra", page: 13, where: "Systeem › Over", keywords: "versie over github onderdelen" }
];

// Paginanummer naar de naam die qs_manager.sh open settings <naam> kent.
var pageNames = {
    0: "perscherm", 1: "thema", 2: "aanpassen", 4: "sneltoetsen", 5: "invoer", 6: "beeldschermen",
    7: "netwerk", 8: "geluid", 9: "tijd", 10: "sessie", 11: "updates",
    12: "geavanceerd", 13: "over", 15: "rail", 16: "start", 17: "uiterlijk", 18: "bureaublad", 19: "rust", 20: "backup"
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
