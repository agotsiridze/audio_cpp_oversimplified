set -euo pipefail
. /app/download_models/download.bash

download \
    "https://huggingface.co/audio-cpp/audio.cpp-gguf/resolve/main/ACE-Step1.5-GGUF/turbo/ace-step-1.5-turbo-bf16.gguf" \
    "base_models/ace-step-1.5-turbo-bf16.gguf" \
    16 &

wait

echo "All downloads finished."
