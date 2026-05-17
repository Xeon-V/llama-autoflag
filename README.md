# llama-autoflag

Auto-detect hardware and generate optimal llama.cpp flags.

**v1.3.0** - Fixed: -ngl manual override

---

## Install

```bash
curl -L -o llama-autoflag.fish https://raw.githubusercontent.com/Xeon-V/llama-autoflag/master/llama-autoflag.fish
chmod +x llama-autoflag.fish
```

## Quick Use

```bash
# See flags (dry-run)
fish ./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf --dry-run

# Run with model
fish ./llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf --dir ~/llama-bee

# Override GPU layers
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-32B-Q4_K_M.gguf -ngl 55 --dry-run

# CPU only
fish ./llama-autoflag.fish -m ~/models/<model>.gguf --cpu
```

---

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `-m` | Model path (required) | - |
| `--dir` | llama.cpp build dir | `./build` |
| `-c` | Context size | auto |
| `-q` | KV cache: q8_0, q4_0, turbo3 | auto |
| `-ngl` | GPU layers (0-99) | auto |
| `--cpu` | CPU only | GPU |
| `--dry-run` | Show flags only | - |
| `-h` | Help | - |

---

## Examples

```bash
# Small model (≤8B) - full GPU
-qwen3-8b-q4_k_m.gguf --dir ~/llama-bee

# Medium (10-30B) - partial offload
-qwen2.5-32b-q4_k_m.gguf --dir ~/llama-bee

# Large (18GB+) - manual -ngl
-m ~/models/deepseek-r1-32b-q4_k_m.gguf -ngl 55

# Large context (65536)
-m ~/models/<model>.gguf -c 65536
```

---

## Hardware

Tested on: Dual NVIDIA TITAN V (12GB), 128GB RAM, 28-core Xeon

---

## Requirements

| Component | Recommend |
|-----------|------------|
| Shell | Fish 3.0+ |
| RAM | 16GB+ |
| GPU | 6GB+ VRAM |

---

## Why

Tired of calculating -ngl, -ts, -b flags by hand? This auto-detects your hardware and generates optimal llama.cpp command. Override anytime with `-ngl`.

Time saved: ~5 min per test run.

---

## License

MIT
