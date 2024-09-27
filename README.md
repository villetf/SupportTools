# SupportTools

SupportTools är en Powershellmodul som ger dig tillgång till ett flertal automatiserade verktyg för Region Kalmar Läns supportfunktioner.

## Systembeskrivning

SupportTools kräver Powershell 7 som kan installeras genom SysMan.

SupportTools används för att automatisera arbetsuppgifter inom Region Kalmar Läns supportfunktioner. Det är en powershellmodul som installeras och konfigureras genom att köra installationsskriptet, och modulen hämtas då från en webbserver på servern serverX, packas upp, och läggs sedan under LocalAppData. Själva modulen körs genom en genväg som dras ner till ens aktivitetsfält. Modulen importerar modulen och kör därefter kommandot Get-Options.

Varje gång man kör modulen kontrollerar den det installerade versionsnumret mot versionsnumret på webbservern. Stämmer dessa inte överens kommer den fråga om man vill uppdatera, och hämtar isåfall den nya versionen och installerar den.

## Installation

Installationsinstruktioner finns [här.](https://servicedesk.ltkalmar.se/ui/solutions?entity_id=1498&mode=detail#feedback)

## Användning

SupportTools används genom att klicka på genvägen med två skiftnycklar nere i aktivitetsfältet. Därifrån får man förslag på saker man kan göra. Just nu finns tre funktioner.

### Visa alla låsta konton

Visa alla låsta konton hämtar info från AD:t om vilka konton som är låsta och visar dem. Den visar också vilken eller vilka datorer som låst ut användaren.

### Visa alla datorer en användare är inloggad på

Denna funktion låter dig skriva in ett användarnamn, och hämtar info från Sysman om vilka datorer personen är inloggad på. Den kollar också från CMDB var datorn står och vad det är för modell. Om en eller flera datorer har låst användarens konto visas det också.

### Visa SupportTools-version

Denna funktion visar den nuvarande SupportTools-versionen och kollar samtidigt efter nya uppdateringar. Finns det inga nya skriver den ut det, om det finns frågar den om man vill uppdatera.

## Support

För buggrapporter och förbättringsförslag kan man antingen lägga ett ärende till Operations Center i ServiceDesk Plus, eller [öppna ett issue i Gitlab.](https://gitlab.ltkalmar.se/oc/supporttools/-/issues "Issue"). Om GitLab används ska issuet märkas med någon av labelarna "Bugg" eller "Förbättringsförslag".