#!/bin/bash
# Henter og konverterer språkmodellene Fróði vit svarer med.
#
# Modellene ligger ikke i git — de er over en halv gigabyte til sammen. Kjør
# dette skriptet én gang etter kloning, før du bygger.
#
# Nasjonalbiblioteket publiserer den åpne serien som safetensors og GGUF, men
# ikke som MLX. Konverteringen gjøres derfor her, én gang, på en Mac. Den er
# ikke eksperimentell: NB har selv kjørt samme konvertering på samme arkitektur
# for forhåndsversjonene sine.
#
# Kilder:
#   svar:        https://huggingface.co/NbAiLab/borealis-open-1b (Gemma-lisens)
#   gjenfinning: https://huggingface.co/NbAiLab/borealis-embed-212m (NB-lisens 1.0)
#
# Krever: python3 med mlx-lm.
#   pip install "mlx-lm==0.28.4"
set -euo pipefail

# Pinnet med vilje. En modell som endrer seg under føttene på deg gir svar som
# endrer seg uten at noe i repoet er rørt.
GENERATOR="NbAiLab/borealis-open-1b"
GENERATOR_REVISION="main"
EMBEDDER="NbAiLab/borealis-embed-212m"
EMBEDDER_REVISION="main"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/FrodiKunnskap/Resources/Model"

if ! python3 -c "import mlx_lm" 2>/dev/null; then
  echo "Mangler mlx-lm. Installer det med:"
  echo "  pip install \"mlx-lm==0.28.4\""
  exit 1
fi

mkdir -p "$DEST"

convert() { # $1 = modell-id, $2 = revisjon, $3 = målmappe, $4 = kvantisering i bit
  local target="$DEST/$3"
  if [ -f "$target/config.json" ]; then
    echo "  har $3"
    return
  fi
  echo "  konverterer $1 -> $3 (${4}-bit)"
  python3 -m mlx_lm convert \
    --hf-path "$1" \
    --revision "$2" \
    --mlx-path "$target" \
    --quantize --q-bits "$4"
}

echo "Språkmodeller:"
# 4-bit på svarmodellen. Arbeidssettet lander da rundt 1,2 GB, som er innenfor
# den vanlige minnegrensen for en app. 8-bit ville krevd et rettighetstillegg
# for økt minne, og det er en søknad vi slipper å skrive.
convert "$GENERATOR" "$GENERATOR_REVISION" "borealis-open-1b" 4
# 8-bit på gjenfinningen. Den er liten nok til at det ikke koster, og
# innebygginger taper mer på hard kvantisering enn generering gjør.
convert "$EMBEDDER" "$EMBEDDER_REVISION" "borealis-embed-212m" 8

echo
echo "Ferdig. Størrelse:"
du -sh "$DEST"
