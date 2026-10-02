# FedoraRTK-Base

Fedora-adapter for RTKBase med Ardusimple/u-blox ZED-F9P.

**Eksperimentell førsteutgave. Ikke testet på Fedora eller med en fysisk F9P.**
Mål: Fedora 44 x86_64 uten X-server, Wayland eller skrivebord. Windows 11 skal
først erstattes etter at eventuelle filer som skal beholdes er kopiert ut.
Skriptet installerer programvare; innmåling, GNSS-konfigurasjon og tilkobling
til Centipede gjenstår. Ingen korreksjoner publiseres av installasjonen.

## Bruk

Last ned pakken og les skriptet før kjøring. Vis planen uten å endre systemet:

```bash
bash install-fedora.sh --plan
```

På en ny Fedora 44-installasjon, med en eksisterende vanlig Linux-bruker:

```bash
sudo bash install-fedora.sh --apply --user ditt_linux_brukernavn
```

Skriptet installerer Fedora-pakker med dnf, RTKBase 2.7.0 i `/opt/rtkbase`,
Python 3.11 i eget virtuelt miljø og RTKLIB 2.5.0 fra kildekode. De to
kildearkivene kontrolleres mot SHA-256-verdier. Python-avhengigheter installeres
fra PyPI med RTKBases versjonsliste; komplett låsing av transitive avhengigheter
gjenstår. Fedora-pakker oppdateres ikke utenom nødvendige installasjoner.

F9P får en udev-regel og brukeren legges i dialout-gruppen. Linux-tjenestene
kopieres fra RTKBase. Tjenester startes ikke automatisk av dette skriptet.
Skriptet endrer ikke SELinux-modus, åpner ikke brannmuren, endrer ikke
GNSS-mottakerens innstillinger og installerer ikke grafisk skrivebord.
Ved eksisterende installasjon stopper det i stedet for å overskrive den.
Hvis installasjonen feiler etter at filer er lagt inn, skal feilen undersøkes
før nytt forsøk; automatisk tilbakeføring og oppgraderinger er ikke implementert.

## Idriftsetting – må testes før offentlig deling

1. Koble bare den nye basemottakeren til, ikke traktormottakeren. Koble USB fra
   og til igjen så udev-regelen brukes. Kontroller `/dev/ttyGNSS` og rettigheter.
2. Konfigurer F9P etter RTKBases dokumentasjon. Upstream-verktøyet kan brukes
   separat for mottakeren, men ikke kjør dets `--all` eller pakkesteg på Fedora:
   `sudo bash /opt/rtkbase/tools/install.sh --user ditt_linux_brukernavn --detect-gnss --configure-gnss`.
   Dette endrer mottakerens konfigurasjon. Kontroller resultat og feilmeldinger;
   Fedora-funksjonen til dette steget er ennå ikke verifisert.
3. Start `rtkbase_web.service` med systemctl. Kontrollpanelet bruker port 8080.
   For første lokale oppsett kan SSH-tunnel brukes fra en annen PC:
   `ssh -L 8080:localhost:8080 bruker@serveradresse`, og åpne
   `http://localhost:8080` på den PC-en. Endre standardpassord umiddelbart.
4. Kontroller innstillinger, port, mottakerformat og faktisk satellittmottak.
   Start hovedtjenesten `str2str_tcp.service` når mottakerinnstillingene er klare.
5. Monter antennen permanent og bestem nøyaktige koordinater før sending.
   Registrer basen hos Centipede og konfigurer NTRIP-utgangen etter deres guide.
6. Tillat webtilgang kun fra ønsket lokalnett i Fedora-brannmuren, og bruk ikke
   portvideresending til kontrollpanelet fra internett. SELinux skal fortsatt
   være på; eventuelle AVC-avslag må undersøkes og løses konkret.
7. Aktiver relevante tjenester ved oppstart og test omstart, strømbrudd,
   nettutfall og gjenoppkobling med fysisk mottaker før offentlig drift.

RTKBase 2.7.0s webtjeneste kjører som root etter upstream-oppsettet. Dette er
beholdt i prototypen, og skal vurderes i gjennomgangen før offentlig utgivelse.
Upstream-webpanelets automatiske oppdatering er ikke Fedora-tilpasset; bruk
ikke den funksjonen før en Fedora-oppgraderingsstrategi er testet.
GPS-basert systemtid (gpsd/chrony), LTE-modem, polkit-regler, arkivering og alle
andre valgfrie tjenester er ikke konfigurert av prototypen.

## Kontroll før GitHub-utgivelse

- Bash-syntaks, help/plan og avvisning av ugyldige argumenter er kontrollert.
- Full installasjon på Fedora 44 med SELinux enforcing gjenstår.
- Verifisering av pakkene, Python-importer og alle installerte tjenester gjenstår.
- F9P-konfigurasjon, korreksjoner og RTK-fix på traktoren gjenstår.
- Nettutfall, omstart og vedvarende basekoordinater må testes.
- Oppgraderingsløp, avinstallasjon og tilbakeføring må dokumenteres før en stabil utgave.

## GitHub

Repository: https://github.com/oztiz/FedoraRTK-Base

Last ned koden med Code → Download ZIP. Førsteutgaven er eksperimentell.
Pakken inneholder ikke personlige innstillinger, basekoordinater eller passord.

## Kilder og lisens

- RTKBase: https://github.com/Stefal/rtkbase/tree/v2.7.0
- Standardinstallasjon: https://github.com/Stefal/rtkbase/blob/v2.7.0/tools/install.sh
- RTKLIB: https://github.com/rtklibexplorer/RTKLIB/tree/v2.5.0
- Fedora Minimal: https://fedoraproject.org/misc/
- Python 3.11 i Fedora: https://packages.fedoraproject.org/pkgs/python3.11/python3.11/
- Centipede: https://docs.centipede.fr/

Adapterskriptet og dokumentasjonen gis under GPL-3.0-lisensen som er valgt
for dette repositoryet og ligger i LICENSE. RTKBase og RTKLIB lastes ned separat og beholder sine egne
lisenser. Pakken inneholder ikke kopier av upstream-koden.
