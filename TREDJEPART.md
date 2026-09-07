# Tredjepartslisenser

Lisensene under krever at opphavet oppgis. Dette er den attribusjonen.

Sist gjennomgått 08.09.26.

## Modeller

| Hva | Opphav | Lisens |
|---|---|---|
| borealis-open-1b | Nasjonalbiblioteket (NbAiLab) | Gemma Terms of Use |
| borealis-embed-212m | Nasjonalbiblioteket (NbAiLab) | NB-lisens 1.0 |

### Om NB-lisensen

`borealis-embed-212m` er ikke en åpen lisens i OSI-forstand. Den er fritt
tilgjengelig og kan videreformidles, men har bruksbegrensninger. De to som kan
gjelde en app er:

- Modellen skal ikke brukes til bevisst å gjenskape materiale fra treningsdataene
- Modellen skal ikke brukes til tjenester som først og fremst erstatter tilgang
  til pressestoffet som er brukt i treningen

Fróði vit gjør ingen av delene. Appen søker i dokumenter du selv har lastet opp fra
din egen telefon, og har ingen forbindelse til pressestoff.

Det finnes ingen åpen variant av denne modellen. Alternativet, `nb-sbert`, er
målt vesentlig svakere på lang kontekst, som er nettopp det denne appen trenger.

`borealis-open-1b` er på Gemma-lisensen og har ingen slike begrensninger.

## Kode

Løst 8. september 2026, `mlx-swift-lm` pinnet til 3.31.4. Fem pakker i alt,
alle fra Apple eller Apples egne prosjekter.

| Pakke | Versjon | Opphav | Lisens |
|---|---|---|---|
| mlx-swift-lm | 3.31.4 | Apple | MIT |
| mlx-swift | 0.31.6 | Apple | MIT |
| swift-numerics | 1.1.1 | Apple | Apache 2.0 |
| swift-argument-parser | 1.8.2 | Apple | Apache 2.0 |
| swift-syntax | 603.0.2 | Apple / Swift | Apache 2.0 |

Tre produkter kobles inn: `MLXLLM`, `MLXLMCommon` og `MLXEmbedders`.
**`MLXHuggingFace` ligger i samme pakke og kobles bevisst ikke inn.** Det er den
eneste veien MLX har ut på nettet. En pakke som ikke er lenket kan ikke kalles
ved et uhell, og det er billigere enn å slå av nedlasting hvert sted den brukes.

## Skrifter

| Skrift | Opphav | Lisens |
|---|---|---|
| Inter | Rasmus Andersson | SIL Open Font License 1.1 |
| Skranji | Font Diner | SIL Open Font License 1.1 |
