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
# Krever: mlx-lm i et virtuelt miljø under .venv/. Skriptet lager det selv
# første gang. Et eget miljø, ikke den globale python-installasjonen: mlx-lm
# drar med seg huggingface_hub, som igjen drar med seg httpx og trio, og de
# krangler lett med det som allerede ligger globalt.
set -euo pipefail

# Pinnet med vilje. En modell som endrer seg under føttene på deg gir svar som
# endrer seg uten at noe i repoet er rørt.
GENERATOR="NbAiLab/borealis-open-1b"
GENERATOR_REVISION="acebb4d8ae77098a05fc83061e7d0148bfd6027c"
EMBEDDER="NbAiLab/borealis-embed-212m"
EMBEDDER_REVISION="2ae20a7ca72bbfaf526d9b1b371c6b326ccfc7f2"

MLX_LM_VERSION="0.31.3"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/FrodiKunnskap/Resources/Model"

VENV="$ROOT/.venv"
PY="$VENV/bin/python"

if [ ! -x "$PY" ]; then
  echo "Lager .venv ..."
  python3 -m venv "$VENV"
fi

if ! "$PY" -c "import mlx_lm" 2>/dev/null; then
  echo "Installerer mlx-lm i .venv ..."
  "$PY" -m pip install -q --upgrade pip
  "$PY" -m pip install -q "mlx-lm==$MLX_LM_VERSION"
fi

mkdir -p "$DEST"

# mlx_lm convert har ingen --revision. Den henter alltid siste versjon av et
# repo-navn, og da er «pinnet» bare noe skriptet påstår. Vi laster derfor ned
# den navngitte revisjonen først, og konverterer fra mappen på disk.
convert() { # $1 = modell-id, $2 = revisjon, $3 = målmappe, $4 = kvantisering i bit
  local target="$DEST/$3"
  if [ -f "$target/config.json" ]; then
    echo "  har $3"
    return
  fi

  echo "  henter $1 @ ${2:0:12}"
  local snapshot
  snapshot="$("$PY" - "$1" "$2" <<'PYEOF'
import sys
from huggingface_hub import snapshot_download
print(snapshot_download(repo_id=sys.argv[1], revision=sys.argv[2]))
PYEOF
)"

  echo "  konverterer -> $3 (${4}-bit)"
  "$PY" -m mlx_lm convert \
    --hf-path "$snapshot" \
    --mlx-path "$target" \
    --quantize --q-bits "$4"
}

echo "Språkmodell:"
# 4-bit på svarmodellen. Arbeidssettet lander da rundt 1,2 GB, som er innenfor
# den vanlige minnegrensen for en app. 8-bit ville krevd et rettighetstillegg
# for økt minne, og det er en søknad vi slipper å skrive.
convert "$GENERATOR" "$GENERATOR_REVISION" "borealis-open-1b" 4
# Gjenfinningsmodellen konverteres IKKE her, og det er ikke en forglemmelse.
#
# `mlx_lm convert` bygger alltid en causal LM. borealis-embed-212m er en
# Gemma3TextModel — en ryggrad uten lm_head, med pooling-lag fra
# SentenceTransformers oppå. Konverteringen stopper med «Received 158
# parameters not in model», målt 8. september 2026.
#
# Modellen trengs først når kunnskapsbasen bygges (fase 3). Da må den enten
# konverteres med et eget skript som skriver vektnavnene om til det
# MLXEmbedders' Gemma3 forventer, eller byttes mot en BERT-basert modell,
# som MLXEmbedders støtter rett fram. Ikke bruk tid på det før retrieval
# faktisk skal bygges.
#
# convert "$EMBEDDER" "$EMBEDDER_REVISION" "borealis-embed-212m" 8

echo
echo "Ferdig. Størrelse:"
du -sh "$DEST"
