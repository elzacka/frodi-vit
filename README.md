# Fróði vit

Norsk kunnskapsassistent for iPhone. Du skriver, limer inn eller laster opp,
og Fróði vit svarer. Alt skjer på enheten.

«Fróði» er norrønt for «den kunnskapsrike». «Vit» er forstand.

Fróði er en serie med to apper. Den andre heter [«Fróði røst»](https://github.com/elzacka/frodi-rost)
og er en diktafonapp med tale til tekst.

## Hva appen gjør

- Du skriver et spørsmål, eller limer inn en tekst
- Du kan laste opp et dokument og få svar som bygger på det
- En språkmodell inni appen lager svaret
- Du kan ha flere samtaler, bla i dem, og slette én, flere eller alle

## Hva appen ikke gjør

Fróði vit **sender ingenting og henter ingenting**. Ingen analyse, ingen
krasjrapportering, ingen tredjepartstjenester. Språkmodellen følger med appen,
så det finnes ikke engang en nedlasting.

Det du skriver, limer inn og laster opp ligger kryptert på enheten, med en
nøkkel som lages i maskinvaren og aldri forlater den. Det betyr også at
innholdet ikke kan leses av en annen enhet, og ikke kan leses fra en
sikkerhetskopi.

## To apper

Dette er den ene av to:

| App | Gjør |
|---|---|
| **Fróði røst** | Tar opp lyd og gjør den om til tekst |
| **Fróði vit** | Denne. Svarer på det du spør om |

De deler fornavn, design og løftet om at ingenting forlater enheten. De deler
ikke kode.

## Modeller

**borealis-open-1b** fra Nasjonalbiblioteket (NB) lager svarene. Modellen bygger på
Googles Gemma 3 med én milliard parametere, og er videretrent av NB på
norske instruksjonsdata, bokmål og nynorsk, for å svare, skrive og oppsummere på
norsk. «Open» betyr at den er trent uten pressestoffet fra NBs
rettighetsavtale, og derfor slipper bruksbegrensningene som følger resten av
serien.

Modellen følger med appen, kvantisert til 4 bit så den får plass i minnet, og
kjører på enheten gjennom MLX. Den koster ingenting å bruke, og appen kontakter
ingen tjeneste for å lage svaret. En modell på én milliard parametere kan ta
feil, og appen sier det selv.

**borealis-embed-212m**, også fra NB, finner de delene av et
dokument som gjelder spørsmålet. Et opplastet dokument deles i utdrag på rundt
tusen tegn, og hvert utdrag får en tallvektor. Når du spør, får spørsmålet sin
vektor, og utdragene som ligner mest går til svarmodellen — i den rekkefølgen
de sto i dokumentet. Slik kan du spørre om et dokument på hundre sider uten at
appen leser bare de første fem. Svaret sier hvilke dokumenter det bygger på.

| Kilde | Lenke |
|---|---|
| Svarmodellen | [NbAiLab/borealis-open-1b](https://huggingface.co/NbAiLab/borealis-open-1b) |
| Gjenfinningsmodellen | [NbAiLab/borealis-embed-212m](https://huggingface.co/NbAiLab/borealis-embed-212m) |
| Alle modellene fra NB | [huggingface.co/NbAiLab](https://huggingface.co/NbAiLab) |
| Om AI-laben | [ai.nb.no](https://ai.nb.no/) |

Lisensene står i `TREDJEPART.md`.

## Krav

- iPhone med iOS 26.5 eller nyere

## Bygge

```bash
brew install xcodegen
xcodebuild -downloadComponent MetalToolchain   # én gang per maskin
xcodegen generate
./Scripts/fetch-model.sh
xcodebuild -project FrodiVit.xcodeproj -scheme FrodiVit \
  -destination 'platform=iOS Simulator,name=Frodi-Test' \
  -skipPackagePluginValidation -skipMacroValidation build
```

MLX kompilerer egne Metal-kjerner, og fra Xcode 26 følger ikke
Metal-verktøykjeden med i grunninstallasjonen. Uten den stopper bygget med
`cannot execute tool 'metal'`, som ikke nevner MLX med et ord.

De to `-skip`-flaggene trengs fordi `mlx-swift` har en byggeplugin for CUDA.
Den gjør ingenting på iOS, men Xcode kjører ingen plugin uten godkjenning.

Uten `fetch-model.sh` bygger appen, men kan ikke svare.
