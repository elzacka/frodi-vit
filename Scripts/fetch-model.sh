#!/bin/bash
# Fetches and converts the language models Fróði vit answers with.
#
# The models are not in git; together they are over half a gigabyte. Run this
# script once after cloning, before you build.
#
# The National Library publishes the open series as safetensors and GGUF, but
# not as MLX. So the conversion is done here, once, on a Mac. It is not
# experimental: NB has run the same conversion on the same architecture for
# its own preview releases.
#
# Sources:
# answers:    https://huggingface.co/NbAiLab/borealis-open-1b (Gemma licence)
# retrieval:  https://huggingface.co/NbAiLab/borealis-embed-212m (NB licence 1.0)
#
# Requires: mlx-lm in a virtual environment under .venv/. The script creates it
# the first time. A separate environment, not the global Python install: mlx-lm
# pulls in huggingface_hub, which pulls in httpx and trio, and they clash
# easily with what is already installed globally.
set -euo pipefail

# Pinned on purpose. A model that changes under your feet gives answers that
# change without anything in the repo being touched.
GENERATOR="NbAiLab/borealis-open-1b"
GENERATOR_REVISION="acebb4d8ae77098a05fc83061e7d0148bfd6027c"
EMBEDDER="NbAiLab/borealis-embed-212m"
EMBEDDER_REVISION="2ae20a7ca72bbfaf526d9b1b371c6b326ccfc7f2"

MLX_LM_VERSION="0.31.3"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/FrodiVit/Resources/Model"

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

# mlx_lm convert has no --revision. It always fetches the latest version of a
# repo name, and then «pinned» is only something the script claims. So we
# download the named revision first, and convert from the folder on disk.
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
# 4-bit for the answer model. The working set then lands around 1.2 GB, which
# is within the usual memory limit for an app. 8-bit would need an entitlement
# for increased memory, and that is an application we can skip writing.
convert "$GENERATOR" "$GENERATOR_REVISION" "borealis-open-1b" 4
# The retrieval model does not go straight through `mlx_lm convert`. It is a
# Gemma3TextModel — the backbone alone, without lm_head — and the weights in
# safetensors lack the `model.` prefix the conversion expects. That was the
# whole error «Received 158 parameters not in model», measured 8 September
# 2026: 158 is exactly the number of tensors in the file.
#
# So we put a step in front: copy the weights with the prefix in place, and
# rewrite config.json from transformers 5's keys (`rope_parameters`,
# `_sliding_window_pattern`) to the flat keys both mlx_lm and the Swift code
# read. After that it is an ordinary conversion. 8-bit: measured 12 September
# 2026, cosine against fp32 is 0.9997, and the model is 236 MB.
#
# The run inside the app is not MLXEmbedders' `EmbeddingGemma`; that computes
# causally, while this model is trained bidirectionally and with silu. See
# `BorealisEmbedder.swift`.
stage_embedder() { # $1 = snapshot, $2 = mellommappe
  "$PY" - "$1" "$2" <<'PYEOF'
import sys, json, shutil, os
import mlx.core as mx
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
weights = mx.load(f"{src}/model.safetensors")
mx.save_safetensors(f"{dst}/model.safetensors", {f"model.{k}": v for k, v in weights.items()})
config = json.load(open(f"{src}/config.json"))
config["sliding_window_pattern"] = config.pop("_sliding_window_pattern")
rope = config.pop("rope_parameters")
config["rope_theta"] = rope["full_attention"]["rope_theta"]
config["rope_local_base_freq"] = rope["sliding_attention"]["rope_theta"]
json.dump(config, open(f"{dst}/config.json", "w"), indent=2)
for name in ("tokenizer.json", "tokenizer_config.json"):
    shutil.copy(f"{src}/{name}", dst)
PYEOF
}

echo "Gjenfinningsmodell:"
target="$DEST/borealis-embed-212m"
if [ -f "$target/config.json" ]; then
  echo "  har borealis-embed-212m"
else
  echo "  henter $EMBEDDER @ ${EMBEDDER_REVISION:0:12}"
  snapshot="$("$PY" - "$EMBEDDER" "$EMBEDDER_REVISION" <<'PYEOF'
import sys
from huggingface_hub import snapshot_download
print(snapshot_download(repo_id=sys.argv[1], revision=sys.argv[2]))
PYEOF
)"
  staged="$(mktemp -d)"
  echo "  legger til prefikset model. og flater ut config.json"
  stage_embedder "$snapshot" "$staged"
  echo "  konverterer -> borealis-embed-212m (8-bit)"
  "$PY" -m mlx_lm convert \
    --hf-path "$staged" \
    --mlx-path "$target" \
    --quantize --q-bits 8
  rm -rf "$staged"
fi

echo
echo "Ferdig. Størrelse:"
du -sh "$DEST"
