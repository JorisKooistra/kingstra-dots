# Handmatige testchecklist — Fase 1

Voer deze checks uit na het draaien van fase 1.

## Installer basis

- [ ] `./install.sh --help` toont het helptekst zonder errors
- [ ] `./install.sh --dry-run` doorloopt alle fases zonder iets te schrijven
- [ ] `./install.sh --phase 01_project_base` slaagt op een Arch-machine
- [ ] `./install.sh --phase 01_project_base --dry-run` toont dry-run output
- [ ] Logbestand aangemaakt in `~/.local/share/kingstra/install.log`
- [ ] Markerbestand aangemaakt in `~/.local/share/kingstra/phase01.marker`
- [ ] Back-upmap aangemaakt in `~/.local/share/kingstra/backups/`

## Projectstructuur

- [ ] `installer/lib/` bevat alle 9 bibliotheekbestanden
- [ ] `installer/phases/` bevat alle 15 fasebestanden
- [ ] `installer/profiles/` bevat default, nvidia en laptop
- [ ] `manifest/packages/` bevat 7 pakketlijsten
- [ ] `manifest/services.txt` aanwezig
- [ ] `manifest/fonts.txt` aanwezig
- [ ] `manifest/files.txt` aanwezig
- [ ] `config/` heeft submappen voor alle apps
- [ ] `assets/` heeft submappen

## Dry-run gedrag

- [ ] Geen enkel bestand buiten de repo wordt aangemaakt bij dry-run
- [ ] Dry-run output is duidelijk leesbaar
- [ ] Alle `[DRY]` regels verschijnen in het logbestand

## Profile-laden

- [ ] `./install.sh --profile nvidia` laadt nvidia.conf zonder errors
- [ ] `./install.sh --profile laptop` laadt laptop.conf zonder errors
- [ ] `./install.sh --profile onbekend` toont een waarschuwing maar crasht niet
