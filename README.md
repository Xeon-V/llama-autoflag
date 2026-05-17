# llama-autoflag

Auto-detect hardware and generate optimal llama.cpp flags.

**Version: Alpha 3** | For dual NVIDIA TITAN V (sm_70), CUDA 12.9

---

## Quick Start

```bash
# Install
curl -LO https://raw.githubusercontent.com/Xeon-V/llama-autoflag/master/llama-autoflag.fish
chmod +x llama-autoflag.fish

# Run with your model
fish ./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf --dir ~/llama-bee
```

---

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-m <path>` | Model file (required) | - |
| `--dir <path>` | llama.cpp build directory | `./build` |
| `-d, --draft <path>` | Draft model for speculative decode | - |
| `-p <text>` | Prompt to run | interactive |
| `-n <n>` | Max tokens to generate | 128 |
| `--temp <n>` | Temperature | 0.6 |
| `-t <type>` | Inference type: text, vision, omni, api | text |
| `-q <type>` | KV cache: q8_0, q4_0, turbo3 | auto |
| `-c <n>` | Context size (tokens) | auto |
| `--cpu` | Force CPU only | GPU if available |
| `--dry-run` | Show command without running | - |
| `--detect-only` | Show hardware info only | - |
| `-h` | Show help | - |

---

## Predefined Commands

### Basic Usage

```bash
# Dry-run (see flags without running)
fish ./llama-autoflag.fish -m ~/models/<model>.gguf --dir ~/llama-bee --dry-run

# Interactive chat mode
fish ./llama-autoflag.fish -m ~/models/<model>.gguf --dir ~/llama-bee

# Single prompt, save output
echo "What is AI?" | fish ./llama-autoflag.fish -m ~/models/<model>.gguf --dir ~/llama-bee -p "$(cat)" -n 256
```

### Model Size Examples

```bash
# Small model (≤8B) - full GPU
fish ./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf --dir ~/llama-bee

# Medium model (10-30B) - partial offload
fish ./llama-autoflag.fish -m ~/models/Qwen2.5-32B-Q4_K_M.gguf --dir ~/llama-bee

# Large model (>30B) - CPU fallback or minimal GPU
fish ./llama-autoflag.fish -m ~/models/Qwen2.5-72B-Q4_K_M.gguf --dir ~/llama-bee --cpu
```

### Speculative Decoding

```bash
# Draft model (smaller, faster)
fish ./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf -d ~/models/Qwen3-1B-Q4_K_M.gguf --dir ~/llama-bee
```

### KV Cache Tuning

```bash
# Force turbo3 for large models (faster but more VRAM)
fish ./llama-autoflag.fish -m ~/models/Qwen2.5-72B-Q4_K_M.gguf -q turbo3 --dir ~/llama-bee

# Force q8_0 for stability
fish ./llama-autoflag.fish -m ~/models/<model>.gguf -q q8_0 --dir ~/llama-bee
```

### Context Size

```bash
# Small context (faster)
fish ./llama-autoflag.fish -m ~/models/<model>.gguf -c 4096 --dir ~/llama-bee

# Large context (more memory)
fish ./llama-autoflag.fish -m ~/models/<model>.gguf -c 65536 --dir ~/llama-bee
```

### Hardware Detection

```bash
# Show detected hardware only
fish ./llama-autoflag.fish --detect-only
```

---

## Hardware Tested

- **GPUs**: Dual NVIDIA TITAN V (12GB each, sm_70)
- **CPU**: Intel Xeon E5-2697 v3 (28 cores, 2x)
- **RAM**: 128GB DDR4
- **OS**: CachyOS (kernel 6.x)
- **CUDA**: 12.9

---

## Features

| Feature | Description |
|---------|-------------|
| Auto GPU layers | Calculates VRAM vs model size |
| KV cache | Auto-selects q8_0/turbo3/asymmetric |
| KWin detection | Accounts for 2GB VRAM overhead |
| Tensor split | Asymmetric 0.55/0.45 for dual-GPU |
| CUDA graphs | Auto-disables for dual-GPU stability |
| NUMA | Auto-enables for multi-socket CPUs |
| MoE support | Parses active params (e.g., 30B-A3B) |
| mlock | Prevents OS swapping |

---

## Requirements

| Component | Minimum |
|-----------|----------|
| Shell | Fish 3.0+ |
| CPU | 8 cores |
| RAM | 32GB |
| GPU | 8GB VRAM |

---

## Troubleshooting

### "test: Missing argument"
- Update to latest version: `curl -LO https://raw.githubusercontent.com/Xeon-V/llama-autoflag/master/llama-autoflag.fish`

### Model not found
- Use absolute path: `-m /home/xeonv/models/<model>.gguf`

### Invalid argument
- Check llama.cpp binary: `--dir ~/llama-bee`

### Out of VRAM
- Try `--cpu` or reduce `-c` context size

---

## License

MIT

---

## Server / Router Mode

Start llama-server in **router mode** for live model switching:

```bash
# Start router (auto-discovers all models in folder)
fish ./llama-autoflag.fish --models-dir ~/models --port 8081 --dir ~/llama-bee
```

### How It Works

1. **No `-m` flag** → enters router mode
2. Server scans `--models-dir` for all `.gguf` files
3. Models indexed, NOT loaded until requested
4. Switch models via API without restart

### API Usage

```bash
# List available models
curl http://localhost:8081/models

# Chat with specific model (in JSON body)
curl http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen3-8B-Q4_K_M.gguf", "messages": [{"role": "user", "content": "Hello"}]}'

# Switch to different model (just change model name)
curl http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf", "messages": [{"role": "user", "content": "Explain AI"}]}'
```

### Web UI

Open http://localhost:8081/ in browser - dropdown to switch models live!


---

## Large Model Workarounds (18GB+ models)

For large models like DeepSeek-R1-32B on dual 12GB Titans:

```bash
# Option 1: Smaller context + Flash Attention
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf --dir ~/llama-bee -c 4096 -fa

# Option 2: Partial GPU offload (~55 layers)
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf --dir ~/llama-bee -ngl 55

# Option 3: CPU only (slow but works)
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf --dir ~/llama-bee --cpu
```

### Router Mode with Large Models

```bash
# Use --models-max 1 to prevent memory bloat
fish ./llama-autoflag.fish --models-dir ~/models --port 8081 --dir ~/llama-bee --dry-run
# Add -c 4096 -fa manually to reduce VRAM
```
