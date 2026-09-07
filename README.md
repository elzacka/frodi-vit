# Fróði vit

Norsk kunnskapsassistent for iPhone. Du skriver eller limer inn, og Fróði vit
svarer. Alt skjer på telefonen.

«Fróði» er norrønt for «den kunnskapsrike». «Vit» er forstand. Søsterappen
heter Fróði røst og hører etter i stedet.

## Hva appen gjør

- Du skriver et spørsmål, eller limer inn en tekst
- Du kan laste opp et dokument og få svar som bygger på det
- Svaret lages av en språkmodell som ligger i appen
- Du kan laste ned svaret

## Hva appen ikke gjør

Fróði vit **sender ingenting og henter ingenting**. Ingen analyse, ingen
krasjrapportering, ingen tredjepartstjenester. Språkmodellen følger med appen,
så det finnes ikke engang en nedlasting.

Det du skriver og laster opp ligger kryptert på telefonen, med en nøkkel som
lages i maskinvaren og aldri forlater den. Det betyr også at innholdet ikke kan
leses av en annen telefon, og ikke følger med i en sikkerhetskopi. Vil du ta
vare på et svar, henter du det ut selv.

## To apper

Dette er den ene av to:

| App | Gjør |
|---|---|
| **Fróði røst** | Tar opp lyd og gjør det om til tekst |
| **Fróði vit** | Denne. Svarer på det du spør om |

De deler fornavn, design og løftet om at ingenting forlater telefonen. De deler
ikke kode.

## Modeller

| Rolle | Modell | Lisens |
|---|---|---|
| Svar | `NbAiLab/borealis-open-1b` | Gemma |
| Gjenfinning | `NbAiLab/borealis-embed-212m` | NB-lisens 1.0 |

Begge er åpne modeller fra Nasjonalbiblioteket. Se `TREDJEPART.md`.

## Bygge

```bash
brew install xcodegen
xcodebuild -downloadComponent MetalToolchain   # én gang per maskin
xcodegen generate
./Scripts/fetch-model.sh
xcodebuild -project FrodiKunnskap.xcodeproj -scheme FrodiKunnskap \
  -destination 'platform=iOS Simulator,name=Frodi-Test' \
  -skipPackagePluginValidation -skipMacroValidation build
```

MLX kompilerer egne Metal-kjerner, og fra Xcode 26 følger ikke
Metal-verktøykjeden med i grunninstallasjonen. Uten den stopper bygget med
`cannot execute tool 'metal'`, som ikke nevner MLX med et ord.

De to `-skip`-flaggene trengs fordi `mlx-swift` har en byggeplugin for CUDA.
Den gjør ingenting på iOS, men Xcode kjører ingen plugin uten godkjenning.

Uten `fetch-model.sh` bygger appen, men kan ikke svare.
