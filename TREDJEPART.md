# Tredjepartslisenser

Lisensene under krever at opphavet oppgis. Dette er den attribusjonen.

Sist gjennomgått 8. september 2026.

## Modeller

| Hva | Opphav | Lisens |
|---|---|---|
| borealis-open-1b | Nasjonalbiblioteket (NbAiLab) | Gemma Terms of Use |
| borealis-embed-212m | Nasjonalbiblioteket (NbAiLab) | NB-lisens 1.0 |

### Om NB-lisensen

Lisensen på `borealis-embed-212m` er ikke åpen i OSI-forstand. Modellen er
fritt tilgjengelig og kan videreformidles, men lisensen setter grenser for
bruken. To av dem kan gjelde en app:

- Modellen skal ikke brukes til bevisst å gjenskape materiale fra treningsdataene
- Modellen skal ikke brukes til tjenester som først og fremst erstatter tilgang
  til pressestoffet som er brukt i treningen

Fróði vit gjør ingen av delene. Appen søker i dokumenter du selv har lastet
opp, og har ingen forbindelse til pressestoff.

Det finnes ingen åpen variant av denne modellen. Alternativet, `nb-sbert`, er
målt vesentlig svakere på lang kontekst, som er nettopp det denne appen trenger.

`borealis-open-1b` er merket med Gemma-lisensen i metadataene på Hugging Face,
og har ingen av begrensningene over: den åpne serien er trent uten pressestoffet.

**Men modellkortet motsier seg selv her.** Lisensavsnittet i kortet beskriver en
tilpasset Apache 2.0 med bruksbegrensninger, og lenker til en `LICENSE`-fil som
ikke finnes i dette repoet. Teksten ser ut til å være arvet fra den fulle serien.
Den sikreste lesningen er at metadataene gjelder, men uklarheten står her framfor
å bli glemt.

Gemma-lisensen har uansett sine egne bruksbegrensninger, gjennom Googles
Prohibited Use Policy. «Ingen begrensninger» er ikke riktig om noen av modellene.

## Kode

Løst 8. september 2026. To pakker legges inn direkte; resten følger med.

| Pakke | Versjon | Opphav | Lisens |
|---|---|---|---|
| mlx-swift-lm | 3.31.4 | Apple | MIT |
| mlx-swift | 0.31.6 | Apple | MIT |
| swift-transformers | 1.3.4 | Hugging Face | Apache 2.0 |
| swift-huggingface | 0.10.0 | Hugging Face | Apache 2.0 |
| swift-jinja | 2.5.0 | Hugging Face | Apache 2.0 |
| swift-numerics | 1.1.1 | Apple | Apache 2.0 |
| swift-argument-parser | 1.8.2 | Apple | Apache 2.0 |
| swift-collections | 1.6.0 | Apple | Apache 2.0 |
| swift-crypto | 4.5.2 | Apple | Apache 2.0 |
| swift-asn1 | 1.7.2 | Apple | Apache 2.0 |
| swift-syntax | 603.0.2 | Apple / Swift | Apache 2.0 |
| eventsource | 1.5.1 | Launch Darkly | Apache 2.0 |
| yyjson | 0.12.0 | Yao Yuan | MIT |

Fire produkter kobles inn: `MLXLLM`, `MLXLMCommon`, `MLXEmbedders` og
`Tokenizers`.

**`MLXHuggingFace` kobles bevisst ikke inn.** Det er makroer som utvider seg til
kall mot Hugging Face-hubben, og en modul som ikke er lenket kan ikke kalles ved
et uhell.

**Men nettverkskode finnes likevel i bygget**, og det skal stå her framfor å bli
oppdaget senere: `Tokenizers` avhenger av `Hub`, som avhenger av
`swift-huggingface`. Appen kaller bare `AutoTokenizer.from(modelFolder:)`, som
leser filer fra disk. Se `SECURITY.md` for hva løftet da presist er.

## Skrifter

| Skrift | Opphav | Lisens |
|---|---|---|
| Inter | Rasmus Andersson | SIL Open Font License 1.1 |
| Skranji | Font Diner | SIL Open Font License 1.1 |
