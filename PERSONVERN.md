# Personvern i Fróði vit

Fróði vit samler ikke inn noe om deg. Det er ikke en policy – det er at appen ikke
har kode som kan gjøre det.

## Hva som skjer med det du skriver

Det du skriver, limer inn og laster opp blir liggende på enheten. Appen
sender det ingen steder. Den har ingen adresse å sende til, og ingen tjeneste å
spørre.

Språkmodellen som lager svarene ligger inne i appen. Den snakker ikke med en
server, og det finnes ingen server å snakke med.

## Hvordan innholdet er beskyttet

| Lag | Hva det gjør |
|---|---|
| Sandkassen | Ingen andre apper på enheten kan lese mappen |
| Filbeskyttelse | Innholdet er ulesbart mens enheten er låst |
| Utenfor sikkerhetskopi | Innholdet følger ikke med i iCloud |
| Kryptering per melding og dokument | AES-GCM, med en nøkkel som pakkes inn av en nøkkel i Secure Enclave |

Nøkkelen i Secure Enclave lages på enheten og forlater den aldri. Den er
merket `whenUnlockedThisDeviceOnly`: den er bare tilgjengelig mens enheten er
låst opp, og den kopieres ikke til en ny enhet.

Det har en pris, og den er med vilje: **innholdet kan ikke leses av en annen
enhet.** Bytter du enhet, følger det ikke med. Vil du ta vare på et svar,
henter du det ut selv mens du har enheten.

## Rettighetene dine

Du gjør alt selv i appen, uten å spørre noen. Det finnes ingen konto, ingen
innlogging og ingen som sitter på dataene dine.

- **Innsyn:** alt du har skrevet står i samtalen
- **Uttrekk:** last ned svaret du vil ta vare på
- **Sletting:** slett samtalen i innstillinger, eller slett appen

Sletter du appen, følger alt med. Det finnes ingen kopi noe annet sted.

## Sporing

Ingen. `NSPrivacyTracking` er `false`, listen over innsamlede datatyper er tom,
og listen over sporingsdomener er tom. En test i bygget passer på at det blir
stående slik.
