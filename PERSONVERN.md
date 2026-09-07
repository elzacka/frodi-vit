# Personvern

Fróði samler ikke inn noe om deg. Det er ikke en policy — det er at appen ikke
har kode som kan gjøre det.

## Hva som skjer med det du skriver

Alt du skriver, limer inn og laster opp blir liggende på telefonen din. Det
sendes ingen steder, fordi appen ikke har noen måte å sende noe på: den har
ingen nettverkskode.

Språkmodellen som lager svarene ligger inne i appen. Den snakker ikke med en
tjener, og det finnes ingen tjener å snakke med.

## Hvordan innholdet er beskyttet

| Lag | Hva det gjør |
|---|---|
| Sandkassen | Ingen andre apper på telefonen kan lese mappen |
| Filbeskyttelse | Innholdet er ulesbart mens telefonen er låst |
| Utenfor sikkerhetskopi | Innholdet følger ikke med i iCloud |
| Kryptering per melding og dokument | AES-GCM, med en nøkkel som pakkes inn av en nøkkel i Secure Enclave |

Nøkkelen i Secure Enclave lages på telefonen din og forlater den aldri. Den er
merket `whenUnlockedThisDeviceOnly`: den er bare tilgjengelig mens telefonen er
låst opp, og den kopieres ikke til en ny telefon.

Det har en pris, og den er med vilje: **innholdet kan ikke leses av en annen
telefon.** Bytter du telefon, følger det ikke med. Vil du ta vare på et svar,
henter du det ut selv mens du har telefonen.

## Dine rettigheter

Innsyn, sletting og uttrekk er alle noe du gjør selv i appen, uten å spørre
noen. Det finnes ingen konto, ingen innlogging og ingen som sitter på dataene
dine.

- **Innsyn:** alt du har skrevet står i samtalen
- **Uttrekk:** last ned svaret du vil ta vare på
- **Sletting:** slett samtalen i innstillinger, eller slett appen

Sletter du appen, følger alt med. Det finnes ingen kopi noe annet sted.

## Sporing

Ingen. `NSPrivacyTracking` er `false`, listen over innsamlede datatyper er tom,
og listen over sporingsdomener er tom. En test i bygget vokter at det holder
seg slik.
