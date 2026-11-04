# Couch op je LG-tv zetten vanaf Windows

Deze versie van CleanYourTV voegt de couch-tv-look toe:

- vijf landschappen die elke 20 seconden wisselen;
- een grote glazen klok met het landschap ervóór;
- apps op glas onderaan;
- een Home Assistant-weerkaart op matglas.

De installatie loopt via één SSH-commando vanaf je Windows-pc. Het originele CleanYourTV moet al op de tv staan en ingesteld zijn.

## Wat je nodig hebt

- De tv staat aan en zit op hetzelfde netwerk als je pc.
- CleanYourTV is al ingesteld: Homebrew Channel, de manager-app, **Set up now**.
- Je weet het IP-adres van de tv, bijvoorbeeld `192.168.4.44`. Je vindt het op de tv onder **Instellingen > Netwerk > Wi-Fi/Bekabeld > Geavanceerd**, of in je router.

## Installeren

1. Open **PowerShell**: rechtsklik op Start en kies **Terminal**.

2. Maak verbinding met de tv:

   ```powershell
   ssh root@192.168.4.44
   ```

   - De eerste keer vraagt Windows of je de sleutel vertrouwt. Typ `yes`.
   - Wachtwoord: `alpine`. Je ziet niets terwijl je typt; dat is normaal.
   - Werkt `ssh` niet? Zet hem aan via **Instellingen > Apps > Optionele onderdelen > Een onderdeel toevoegen > OpenSSH-client**.
   - Krijg je een melding dat de host-sleutel veranderd is? Draai dan `ssh-keygen -R 192.168.4.44` en probeer opnieuw.

3. Je zit nu op de tv (je ziet een `root@LGwebOSTV`-prompt). Plak dit commando:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh
   ```

   Het script doet het volgende:
   - het downloadt deze repository;
   - het bewaart een kopie van wat er nu op de tv staat;
   - het vervangt de launcher en de servicebestanden;
   - het kiest het thema **Couch**.

   Na ongeveer een minuut knippert het scherm en zie je de nieuwe Home. Je bent klaar als je `couch: done.` ziet staan.

4. Typ `exit` om de verbinding te sluiten.

Je kunt stap 2 en 3 ook in één keer vanuit PowerShell doen:

```powershell
ssh root@192.168.4.44 "curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh"
```

## De Home Assistant-weerkaart instellen

1. **Home Assistant koppelen**, als dat nog niet gedaan is: open op de tv de manager-app **CleanYourTV** en ga naar **Meer > Home Assistant > Instellen met je telefoon** (*More > Home Assistant > Set up from your phone*). Scan de QR-code en vul in:
   - het adres van je Home Assistant, bijvoorbeeld `http://homeassistant.local:8123`;
   - een long-lived access token. Die maak je in Home Assistant onder **Profiel > Beveiliging > Langlevende toegangstokens**.

2. **De kaart vullen**: ga in de manager-app naar **Kaarten > Instellen met je telefoon** (*Cards > Set up from your phone*) en scan de QR-code. Kies bij **Boven het dock** (*Above the dock*) de kaart **Home Assistant-weer** en vul in:
   - **Weer-entiteit**: bijvoorbeeld `weather.forecast_thuis`;
   - **Sensor buitentemperatuur** (optioneel): je eigen buitensensor, bijvoorbeeld `sensor.buiten_temperatuur`. Zonder sensor wordt de temperatuur van de weer-entiteit gebruikt;
   - **Verwachting**: de komende dagen, de komende uren, of geen.

3. Druk op **Opslaan**. Op de rechterplek (**Rechterkolom**) kun je nog een tweede kaart kwijt, bijvoorbeeld **Home Assistant-entiteiten** met lampen of sensoren. Die komt ook in glasstijl.

## Terugdraaien

```powershell
ssh root@192.168.4.44 "curl -fsSL https://raw.githubusercontent.com/larsoss/cleanyourtv-WebOS/couch/tools/install-couch.sh | sh -s undo"
```

Dit zet de launcher en de servicebestanden van vóór de installatie terug en kiest het thema **Classic**. Wil je alleen een ander thema? Dat kan gewoon via **Customise > Theme** op de tv.

## Goed om te weten

- **Updates:** de tv volgt na de installatie deze repository in plaats van het originele project. Een update van het origineel overschrijft je look dus niet. Het nadeel is dat de manager-app geen updates meer meldt. Werk je CleanYourTV toch bij via het Homebrew Channel, draai dan het installatiecommando opnieuw.
- **Wallpapers:** de scènes vervangen Wallpapers zolang het thema Couch actief is.
- **Na 22:00** worden de scènes iets gedimd.
- **Wisselsnelheid:** de scènes wisselen elke 20 seconden. Dat pas je aan met `effects.sceneSecs` in `themes/couchtv/theme.json`.
- **Als iets niet werkt:** het servicelog staat op de tv in `/tmp/cleanyourtv-helper.log`. Gaat Home helemaal mis, start de tv dan opnieuw op. Lukt het daarna nog steeds niet, kies dan in de manager-app **CleanYourTV as Home** uit.
