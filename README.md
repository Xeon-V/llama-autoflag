# llama-autoflag

Auto-detect hardware and generate optimal llama.cpp flags.

## Usage

```bash
./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf
```

## Options

| Option | Description |
|--------|-------------|
| `-m <path>` | Model file (required) |
| `-p <text>` | Prompt to run |
| `-n <n>` | Max tokens (default: 128) |
| `--temp <n>` | Temperature (default: 0.6) |
| `-t <type>` | Type: text, vision, omni, api |
| `-q <type>` | KV cache: q8_0, q4_0, turbo3 |
| `--cpu` | Force CPU-only |
| `--dry-run` | Show flags without running |
| `--detect-only` | Show hardware info |
| `--self-test` | Run self-tests |
| `-h` | Show help |

## Examples

```bash
# Auto-detect hardware and run
./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf -p "What is AI?"

# Dry-run to see flags
./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf --dry-run

# Force CPU mode for large models
./llama-autoflag.fish -m ~/models/Qwen2.5-72B-Q4_K_M.gguf --cpu

# Multimodal with text mode (GPU OK)
./llama-autoflag.fish -m ~/models/Qwen2.5-Omni-7B-Q4_K_M.gguf -t text

# Multimodal with audio mode (CPU only - upstream bug)
./llama-autoflag.fish -m ~/models/Qwen2.5-Omni-7B-Q4_K_M.gguf -t omni

# Hardware detection only
./llama-autoflag.fish --detect-only
```

## Features

- **Auto GPU layers**: Calculates based on VRAM and model size
- **KV cache**: Auto-selects q8_0/turbo3/asymmetric based on model size
- **TURBOQUANT safety**: <10B blocks turbo3, 10-27B uses asymmetric, >=27B allows turbo3
- **MoE support**: Parses active params (30B-A3B → 3B active)
- **Tensor split**: Asymmetric 0.55,0.45 when KWin compositor detected
- **NUMA**: Auto-enables for dual-socket CPUs
- **Draft validation**: Blocks mismatched architectures for speculative decode

## Hardware Requirements

| Component | Minimum |
|-----------|----------|
| CPU | 8 cores |
| RAM | 32GB |
| GPU | 8GB VRAM |
| Shell | Fish 3.0+ |

## License

MIT