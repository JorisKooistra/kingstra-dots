# Bediening en ruimtelijk werkvlak

Deze ronde wordt via de bestaande updater geïnstalleerd. Er hoeft geen aparte
plugininstaller gedraaid te worden. De bestaande werkruimte-indeling blijft
behouden totdat je zelf een andere kiest.

## Alles in één: Super+A

Super+A opent de Bediening-overlay, net als de thema- en modekiezer maar met
alles tegelijk: thema, wallpaper, mode voor de hele desktop, mode per scherm
(klik een scherm op het kaartje), energieprofiel, indeling van de werkruimte,
kolombreedte en snap-sterkte, wallpaper-effect en de rail per scherm. Een klik
past het meteen toe; Esc of nogmaals Super+A sluit. Het toetsenbordmenu
(Super+Ctrl+Space) heeft dezelfde ingang. Voor de details (muziek, extra
railknoppen, Meer-lijst) gaat "Meer en muziek…" naar Instellingen › Bediening.

## Beginnen

1. Open Instellingen met Super+Ctrl+I en kies op Bediening een fysieke monitor.
2. Kies bijvoorbeeld Media op één scherm en Office op de andere schermen.
3. Pas de zichtbare railonderdelen, extra railknoppen, autohide en muziek aan.
   Deze keuzes worden per scherm én per mode bewaard.
4. Kies bij de werkruimte Ruimtelijk werkvlak, of kies die kaart met Super+Z.
5. Open twee apps: ze staan als tegels naast elkaar en vullen het scherm.
   Super+Shift+omhoog zet een app op een eigen plek erboven. Super+pijlen kiest
   een app; Super+wiel, Super+Alt+wiel of Super+Ctrl+Alt+pijlen verplaatst het zicht.
   Houd Super+Ctrl+linkermuis ingedrukt om vrij te slepen. Een app die je op een lege
   plek opent, komt op die plek.
6. Super+drievingerveeg verwerkt X en Y tegelijk waar de compositor live
   Lua-gebaren ondersteunt. Gewone appscroll en ongewijzigde gebaren blijven bestaan.
7. Super+Tab opent de vensterkaart. Gewoon slepen verplaatst alleen de camera,
   ook als je op een miniatuur begint. Super+slepen verplaatst een app: op het
   midden van een ander venster op dezelfde pagina wisselen ze van tegel; op een andere pagina komt de app ernaast. Aan een rand splits je dat
   vlak. Het oplichtende vak toont het doel. Wiel zoomt, klik kiest een venster.
8. Super+linkermuis slepen op het scherm zelf werkt hetzelfde: het venster komt
   waar je het loslaat, ook tussen bestaande tegels.
9. Super+Ctrl+wiel verkleint de echte desktop tot 25%. Meerdere pagina's zijn
   tegelijk zichtbaar; apps blijven klikbaar, ontvangen toetsen en gewone appscroll.
   Super+wiel verplaatst steeds een hele pagina. Super+Ctrl+linkermuis sleept vrij.
   Super+Ctrl+middelklik gaat terug naar 100%. De zoom geldt per monitor.

Een pagina gebruikt Dwindle-splits in plaats van een vast raster, zonder limiet
aan het aantal vensters. Super+rechtermuis verandert de verhoudingen; Super+backslash
wisselt de richting van de geselecteerde splitsing. Een zichtbare vensterrand
aanraken met de muis verschuift het beeld niet. Pagina's, splitsverhoudingen en
camera worden binnen de sessie bewaard bij het herladen van Hyprland.

Het kader in de kaart is het zichtgebied. Vensters in beeld tonen live beeld;
Hyprland geeft geen beeld van vensters buiten het scherm, dus die tonen een
miniatuur die bewaard is toen ze voor het laatst helemaal in beeld stonden
(`werkvlak-thumb.sh`, in `$XDG_RUNTIME_DIR/kingstra-thumbs`). De knop 󰊢 in de
rail opent dezelfde kaart (uitzoomen).
Zwevende vensters staan ook in de kaart, met een ◇ voor hun titel. Ze blijven
zwevend als je ze met Super+slepen verplaatst.

## Overzicht

Instellingen opent op het tabblad Overzicht: mode, thema, de indeling van de
huidige werkruimte, scrollgedrag (kolombreedte en vastklikken)
en de wallpaper staan daar samen en zijn direct te wijzigen.

## Afzonderlijke schermkeuzes

De keuze van een schermmode verandert geen globale energieprofielen, Niet storen
of Matugen-thema. Thema en wallpaper-picker hebben een ingang onder Hele desktop.
De extra railknoppen kunnen per mode op een scherm in volgorde worden gezet.
Knoppen die je weinig gebruikt zet je onder "Achter Meer": ze schuiven uit de
rail tot je op Meer klikt. De vaste navigatiegroepen zijn nog niet vrij te
verslepen.

De muziekpill gebruikt standaard één stabiel mediascherm; tonen/verbergen kan
per scherm worden overschreven. Desktopmedia kan apart aan/uit.
Bij playerstijl kan het uiterlijk het thema volgen of altijd vinyl/hoes blijven.

Een monitor met bruikbaar serienummer behoudt zijn profiel bij een andere
connector. Voor identieke schermen zonder serienummer is de connector de sleutel.

## GPU

Het tabblad Systeem in het controlecentrum toont per GPU beschikbare belasting,
temperatuur en VRAM. Onbekende waarden blijven onbekend. Slapende GPU's worden
niet wakker gemaakt voor een ongebruikte tegel. Intel-systemen zonder een
bruikbare busy-counter tonen bijvoorbeeld wel temperatuur, maar geen verzonnen
belasting.

## Reikwijdte en resterend werk

- De ruimtelijke layout is optioneel en gebruikt de custom-layout-API van
  Hyprland 0.56. Oudere versies moeten de bestaande layouts blijven gebruiken.
- De keuze voor de ruimtelijke layout wordt bewaard. Pagina's, camerastand en
  Dwindle-verhoudingen overleven een compositor-configreload binnen dezelfde sessie.
- Echte desktopzoom gebruikt een lokaal gebouwde native plugin voor Hyprland
  0.56.2. De gewone updater bouwt die automatisch in fase 05; een andere
  Hyprland-ABI laadt nooit een oud binair bestand. Zie `config/hypr/native-zoom/README.md`.
- Groepen, fullscreen en verplaatsen tussen fysieke monitoren moeten nog in de
  echte sessie worden beoordeeld. Geautomatiseerde tests vervangen die controle niet.
- Echte wallpaper-parallax kan niet: skwd-paper (de Rust/Vulkan-renderer) kent
  geen verschuiving van de wallpaper. In plaats daarvan glijdt bij elke
  camerabeweging een zachte lichtvlek in de accentkleur tegen de beweging in en
  dooft uit (Bediening › Wallpaper-effect bij scrollen, per scherm).
- De sneltoetsenhandleiding is bijgewerkt; welke bestaande bindings Joris wil
  schrappen of vervangen vraagt nog een keuze. Geen gebruikslogging toegevoegd.
- “Schermen minimaliseren” is nog niet ingevuld: een venster parkeren,
  bureaublad tonen en een fysieke monitor uitschakelen zijn verschillende functies.
- Een eventuele derde ruimtelijke as valt buiten deze levering.

## Live controleren na bijwerken

- Starten bar, panelen en Instellingen; Super+Ctrl+I opent Bediening.
- Media op één display, Office op twee andere: wisselen, herstart en los/weer
  aansluiten overschrijven de andere schermen niet.
- Nieuwe lege ruimtelijke werkruimte: eerste venster staat volledig in beeld.
- Tweede app naar de rij erboven verplaatsen, diagonaal bewegen, kaart openen en
  een venster kiezen; normale appscroll blijft normaal.
- Scroll uitzetten: geen fout bij wiel of kolombreedteactie; ook leeg doet niets.
- Muziekpill beweegt niet als geheel; pauze/afspelen werkt in alle gebruikte themes.
- Systeem toont beschikbare GPU-metingen; ontbrekende data is geen 0%.
