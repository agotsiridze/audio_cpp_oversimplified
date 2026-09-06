# audio_cpp_oversimplified

> **Almost all credit for this project belongs to
> [audio.cpp](https://github.com/0xShug0/audio.cpp) by
> [0xShug0](https://github.com/0xShug0) and its contributors.** This
> repository is just a Docker wrapper around their work — it does not
> reimplement or improve on the inference engine itself. Please star,
> credit, and support the upstream project.

A GPU-accelerated audio inference server built on
[audio.cpp](https://github.com/0xShug0/audio.cpp), deployed as a
containerized service. It serves GGUF-based audio models (TTS, voice
conversion, speech generation) over a local HTTP API on an NVIDIA GPU.

This repository contains **deployment configuration and runtime
scripts only** — the actual C++ source is cloned from the upstream
`audio.cpp` repository at Docker build time (see
[Building](#building)).

## Repository layout

```
audio_cpp_oversimplified/
├── docker-compose.yaml            # GPU service definition
├── sample.env                     # template for .env
├── .env                           # runtime secrets (gitignored)
└── audio_cpp_server/
    ├── Dockerfile                 # multi-stage CUDA build
    ├── configs/                   # JSON runtime configs
    │   ├── ace-step-1.5-turbo.json
    │   ├── meanvc2.json
    │   └── omnivoice_stream.json
    ├── download_models/           # model download scripts
    │   ├── ace-step-1.5-turbo.bash
    │   ├── download.bash          # shared aria2c helper
    │   ├── meanvc2.bash
    │   └── omnivoice.bash
    ├── models/                    # model weights (gitignored, filled in by you)
    │   ├── base_models/
    │   └── LoRA/
    └── run_server/                # per-model launch scripts
        ├── ace-step-1.5-turbo.bash
        ├── meanvc2.bash
        └── omnivoice.bash
```

The container mounts the host `audio_cpp_server/` directory to `/app`,
so configuration files, models, and run scripts are visible both
inside the container and on the host.

## Supported models

| Config / script | Model | Task |
| --- | --- | --- |
| `omnivoice_stream.json` / `omnivoice.bash` | OmniVoice | Text-to-speech (streaming) |
| `meanvc2.json` / `meanvc2.bash` | MeanVC2 | Voice conversion |
| `ace-step-1.5-turbo.json` / `ace-step-1.5-turbo.bash` | ACE-Step 1.5 Turbo | Speech generation |

**These are sample/template configs, not production-optimized
builds.** They're meant to be copied and adjusted, not treated as a
fixed list — audio.cpp supports many more model families than the
three set up here. To run a different model, copy an existing config
under `configs/` and an existing script under `run_server/` (and
`download_models/` if it needs its own download step), then adjust
the model path, backend settings, and any GPU-specific flags (e.g.
quantization, batch size) to fit your target GPU and task. For the
exact meaning of any config field or script argument, consult the
upstream [audio.cpp](https://github.com/0xShug0/audio.cpp)
documentation or the docs for the specific model rather than this
file.

## Prerequisites

- NVIDIA GPU with CUDA (driver + runtime)
- Docker, with the **NVIDIA Container Toolkit** installed so the
  container can see the GPU
- A Hugging Face token (`HF_TOKEN`) to download the model weights

`aria2c` is used by the download scripts and is installed
automatically inside the Docker image — no need to install it
separately on the host.

## Configuration

Settings come from a `.env` file (see `sample.env`):

| Variable | Purpose |
| --- | --- |
| `HF_TOKEN` | Hugging Face token used to authenticate model downloads. |
| `PORT` | Host port mapped to the container's port. |
| `CUDA_VERSION` | Base image CUDA tag for the Docker build (e.g. `13.3.0`). Must match a CUDA version your NVIDIA driver supports — check with `nvidia-smi`. |

**Important:** the `port` value inside each JSON config (under
`audio_cpp_server/configs/`) must match `PORT` in `.env`. The server
binds to the port written in its JSON config, but Docker only forwards
traffic on the port set by `PORT`/`docker-compose.yaml`. If these two
values don't match, the server will start and look fine in the logs,
but you won't be able to reach it from outside the container at all —
it'll only be reachable if you exec into the container itself. Always
double check both files agree before reporting a "server not
responding" issue.

## Build & run

```bash
# 1. Configure
cp sample.env .env
#    - HF_TOKEN:      your Hugging Face token
#    - PORT:          port to expose (default 8080)
#    - CUDA_VERSION:  base-image tag for the Docker build

# 2. Build and start (foreground, logs stream to your terminal)
docker compose up --build

# ...or start detached (runs in the background)
docker compose up --build -d
```

Once running, the server exposes its HTTP API on
`http://localhost:${PORT}`.

To stop it:

```bash
docker compose down
```

## Accessing the running container

First, find the container's name or ID:

```bash
docker ps
```

**Option A — open an interactive shell** (good for exploring, running
multiple commands, or debugging):

```bash
docker exec -it <container_name> bash
```

Once inside, you're at a normal bash prompt inside the container and
can launch the server directly against a config, e.g.:

```bash
bash app/run_server/omnivoice.bash
```

**Option B — run a single command directly from the host** (no need
to enter the container first):

```bash
docker exec -it <container_name> bash /app/run_server/omnivoice.bash
```

This runs the script and streams its output back to your host
terminal, without leaving you inside the container afterward.

## Running a specific model

Each `run_server/*.bash` script launches the server binary against a
specific config. The binary resolves to `/src/audiocpp_server` inside
the container:


The equivalent host-side scripts live under
`audio_cpp_server/run_server/`.

## Downloading models

Model weights are GGUF files pulled from Hugging Face. The download
scripts use `aria2c` with your `HF_TOKEN`:

```bash
app/download_models/omnivoice.bash
```

Models are saved to `audio_cpp_server/models/base_models/` and
referenced by the configs listed above.

## Building

The real C++ source is **not** committed here. The
`audio_cpp_server/Dockerfile` clones the upstream repository into the
build container:

```dockerfile
RUN git clone https://github.com/0xShug0/audio.cpp.git .
```

Build the image from the project root:

```bash
docker compose build
```

The Dockerfile compiles the server and CLI with CUDA enabled
(`-DENGINE_ENABLE_CUDA=ON`), targeting a specific CUDA architecture,
and produces the `audiocpp_server` and `audiocpp_cli` binaries under
`build/bin/`.

## Notes & gotchas

- **Source is remote.** There is no C++ source in this repository —
  it's cloned from `audio.cpp` at build time. To inspect or modify the
  actual inference code, clone the upstream repo and build from there.
- **`.env` is gitignored.** Don't commit secrets — copy `sample.env`
  to `.env` and fill in your own `HF_TOKEN`.
- **`*/data/*` and `*/models/*` are gitignored.** Sample data and
  model weights are downloaded or added separately, not committed.
- **A GPU is required at runtime.** The image and container are
  pinned to `nvidia/cuda` and request GPU access via Docker's
  `deploy.resources.reservations.devices`.

## Credits & License

All the actual inference work here is done by
[audio.cpp](https://github.com/0xShug0/audio.cpp) by
[0xShug0](https://github.com/0xShug0) and its contributors. This
repository is nothing more than a thin Docker wrapper around it — the
Dockerfile, configs, and launch/download scripts are the only things
original to this repo.

**audio.cpp itself is Apache 2.0 licensed.** This wrapper repo doesn't
change or override that — you're bound by its license and terms, not
just this repo's.

**⚠️ Individual models are licensed separately, and some are
restrictive.** audio.cpp bundles support for many different model
families, each released under its own license by its own authors.
These are **not** all permissive — for example, some community model
ports are licensed **CC-BY-NC (non-commercial use only)**, meaning
you legally cannot use output from that model for anything
commercial, regardless of what license this repo or audio.cpp itself
uses. Before using any model shipped or downloadable through this
project:

- Check that specific model's license and usage terms (commercial-use
  restrictions, redistribution terms, generated-content terms, etc.)
- Don't assume Apache 2.0 (audio.cpp's license) extends to every model
  it can load — it doesn't
- When in doubt, check the model's page on Hugging Face or wherever it
  was sourced from

If you use this project, please:

- Respect the [audio.cpp license and
  documentation](https://github.com/0xShug0/audio.cpp) for anything
  related to the inference engine itself
- Direct bug reports or feature requests about the inference engine
  itself upstream to audio.cpp, not this repo — this repo only wraps
  it in Docker
