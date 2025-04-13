# SupportTools

SupportTools är en Powershellmodul som ger dig tillgång till ett flertal automatiserade verktyg för en organisations supportfunktioner.

## Sanering

Koden i detta repo skrevs för användning hos en tidigare arbetsgivare. Av denna anledning har all information som skulle kunna vara känslig helt och hållet rensats bort. Exempel på detta är servernamn, URL:er, känslig logik, detaljer om organisationen och systemnamn. Systemnamn har ersatts av ett ord som förklarar vad det är för typ av system för att ge ett sammanhang. 

Repot kan eller ska alltså inte användas till något i sin nuvarande form utan fungerar bara som ett exempel på vad jag har skrivit tidigare. 

## Systembeskrivning

SupportTools kräver Powershell 7 som kan installeras genom Klienthanteringssystem.

SupportTools används för att automatisera arbetsuppgifter inom Organisationens supportfunktioner. Det är en powershellmodul som installeras och konfigureras genom att köra installationsskriptet, och modulen hämtas då från en webbserver på servern serverX, packas upp, och läggs sedan under LocalAppData. Själva modulen körs genom en genväg som dras ner till ens aktivitetsfält. Modulen importerar modulen och kör därefter kommandot Get-Options.

Varje gång man kör modulen kontrollerar den det installerade versionsnumret mot versionsnumret på webbservern. Stämmer dessa inte överens kommer den fråga om man vill uppdatera, och hämtar isåfall den nya versionen och installerar den.

## Installation

Installationsinstruktioner finns [här.](https://servicedesk.domain.se/ui/solutions?entity_id=4535&mode=detail#feedback)

## Användning

SupportTools används genom att klicka på genvägen med två skiftnycklar nere i aktivitetsfältet. Därifrån får man förslag på saker man kan göra. Just nu finns tre funktioner.

### Visa alla låsta konton

Visa alla låsta konton hämtar info från AD:t om vilka konton som är låsta och visar dem. Den visar också vilken eller vilka datorer som låst ut användaren.

### Visa alla datorer en användare är inloggad på

Denna funktion låter dig skriva in ett användarnamn, och hämtar info från Klientsystem om vilka datorer personen är inloggad på. Den kollar också från CMDB var datorn står och vad det är för modell. Om en eller flera datorer har låst användarens konto visas det också.

### Visa SupportTools-version

Denna funktion visar den nuvarande SupportTools-versionen och kollar samtidigt efter nya uppdateringar. Finns det inga nya skriver den ut det, om det finns frågar den om man vill uppdatera.

## Support

För buggrapporter och förbättringsförslag kan man antingen lägga ett ärende till Teamet i Ärendehanteringssystem, eller [öppna ett issue i Kodplattformen.](https://codeplatform.domain.se/team/supporttools/-/issues "Issue"). Om Kodplattform används ska issuet märkas med någon av labelarna "Bugg" eller "Förbättringsförslag".