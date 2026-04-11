# Game launcher taal

De game-launcher toont in sommige omgevingen nog Franse strings.

In `config/quickshell/game-launcher/config.toml` staat nu:

```toml
[localization]
language = "en"
```

Als de upstream launcher deze key negeert, gebruik dan een locale workaround via de startcommand:

```bash
LC_ALL=C LANG=C quickshell-game
```

Voor integratie in scripts:

```bash
LC_ALL=C LANG=C ~/.config/quickshell/game-launcher/toggle.sh
```
