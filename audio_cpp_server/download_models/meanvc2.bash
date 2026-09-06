set -euo pipefail
. /app/download_models/download.bash

download \
    "https://huggingface.co/audio-cpp/audio.cpp-gguf/resolve/main/MeanVC2-GGUF/meanvc2-120ms-40ms-fp32.gguf" \
    "base_models/meanvc2.gguf" \
    16 &

wait

echo "All downloads finished."
