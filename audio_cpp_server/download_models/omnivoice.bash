set -euo pipefail
. /app/download_models/download.bash

download \
    "https://huggingface.co/audio-cpp/audio.cpp-gguf/resolve/main/OmniVoice-GGUF/omnivoice-bf16.gguf" \
    "base_models/omnivoice-bf16.gguf" \
    16 &

wait

echo "All downloads finished."
