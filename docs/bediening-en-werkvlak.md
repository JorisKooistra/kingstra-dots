# Bediening en ruimtelijk werkvlak

Deze ronde wordt via de bestaande updater geïnstalleerd. Er hoeft geen aparte
plugininstaller gedraaid te worden. De bestaande werkruimte-indeling blijft
behouden totdat je zelf een andere kiest.

## Beginnen

1. Open Instellingen met Super+Ctrl+I en kies op Bediening een fysieke monitor.
2. Kies bijvoorbeeld Media op één scherm en Office op de andere schermen.
3. Pas de zichtbare railonderdelen, extra railknoppen, autohide en muziek aan.
   Deze keuzes worden per scherm én per mode bewaard.
4. Kies bij de werkruimte Ruimtelijk werkvlak, of kies die kaart met Super+Z.
5. Open twee apps: ze staan als tegels naast elkaar en vullen het scherm.
   Super+Shift+omhoog zet een app op een eigen plek erboven. Super+pijlen kiest
   een app; Super+wiel, Super+Ctrl+wiel of Super+Ctrl+Alt+pijlen verplaatst het zicht.
   Houd Super+middelmuis ingedrukt om vrij te slepen. Een app die je op een lege
   plek opent, komt op die plek.
6. Super+drievingerveeg verwerkt X en Y tegelijk waar de compositor live
   Lua-gebaren ondersteunt. Gewone appscroll en ongewijzigde gebaren blijven bestaan.
7. Super+Tab opent de vensterkaart. Sleep om het echte zichtgebied te verplaatsen,
   vergroot/verklein de kaart met het wiel en klik een venster om terug te keren.

Het kader in de kaart is het zichtgebied. De tegels tonen live beelden van de
vensters. De knop 󰊢 in de rail opent dezelfde kaart (uitzoomen).

## Overzicht

Instellingen opent op het tabblad Overzicht: mode, thema, de indeling van de
huidige werkruimte, scrollgedrag (kolombreedte, tegels per plek, vastklikken)
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
- De keuze voor de ruimtelijke layout wordt bewaard. De precieze indeling van
  vensters en camerastand zijn voorlopig in-memory en kunnen na een
  compositor-configreload opnieuw worden opgebouwd.
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
- Echt render-uitzoomen, live previews en een eventuele derde ruimtelijke as
  vallen buiten deze eerste levering.

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
