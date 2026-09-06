ARG CUDA_VERSION=13.3.0
ARG PORT=8083
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential curl ca-certificates libcurl4-openssl-dev \
    gcc-13 g++-13 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100 \
    && rm -rf /var/lib/apt/lists/*&& rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/0xShug0/audio.cpp.git . \
    && git log -1 --format=%cd
RUN cmake -S . -B build -DENGINE_ENABLE_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120 -DCMAKE_BUILD_TYPE=Release \
    -DCUDATdocoolkit_ROOT=/usr/local/cuda \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
    -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda" \
    && cmake --build build --config Release -j$(nproc) --target audiocpp_server --target audiocpp_cli
RUN test -f /src/build/bin/audiocpp_server || (echo "BUILD FAILED - binary not found" && exit 1)


FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04

ARG PORT

ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH=/src:$LD_LIBRARY_PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libstdc++6 \
    ca-certificates \
    aria2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY --from=builder /src/build/bin/ /src/
WORKDIR /app

EXPOSE ${PORT}


CMD ["tail", "-f", "/dev/null"]
