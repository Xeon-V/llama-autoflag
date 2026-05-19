# llama-autoflag - Technical Specification

## 1. USE CASE

**Purpose**: Auto-generate optimized llama.cpp CLI flags for any model based on hardware detection.

**Target Users**:
- AI developers running local LLM inference
- Researchers benchmarking llama.cpp performance
- Power users with multi-GPU setups

**Problem Solved**:
- Manual flag tuning is tedious and error-prone
- Different models need different optimizations
- Multi-GPU configurations are complex

---

## 2. TECHNICAL PLAN

### Architecture
```
┌─────────────────┐
│  Hardware Detect │ ← nvidia-smi, nproc
├─────────────────┤
│  Model Parser   │ ← Extract params/family from filename
├─────────────────┤
│  Decision Engine│ ← NGL calc, context, flags
├─────────────────┤
│  Flag Output    │ ← Shell function / CLI args
└─────────────────┘
```

### Decision Matrix

| Model Size | NGL | Context | Notes |
|------------|-----|---------|-------|
| 0.5-1B | 20-25 | 2048-4096 | Small = fewer layers |
| 3-8B | 30-37 | 4096-8192 | Sweet spot at 37 |
| 14-20B | 40-45 | 8192 | Needs VRAM headroom |
| 30B+ | 35 | 8192 | Fewer layers for stability |
| Reasoning | 50 | 32768 | DeepSeek R1 needs --reasoning |

### Benchmark Findings (Dual Titan V)

| Setting | Old | Optimized | Impact |
|---------|-----|-----------|--------|
| NGL | 99 | 37 | 2x speedup |
| KV Cache | q8_0 | f16 | +10% speed |
| Split | row | graph | Required |

---

## 3. SOURCE CODE

```fish
#!/usr/bin/env fish
# llama-autoflag.fish - Auto-generate optimized ik_llama.cpp flags
# Version: 3.0.2-ik

set -l MODEL ""
set -l RUN_MODE 0
set -l DRY_RUN 0
set -l DETECT_ONLY 0

# Parse args
for i in (seq 1 (count $argv))
    switch $argv[$i]
        case '-m' '--model'
            set MODEL $argv[(math $i + 1)]
        case '--run'
            set RUN_MODE 1
        case '--dry-run'
            set DRY_RUN 1
        case '--detect-only'
            set DETECT_ONLY 1
    end
end

if test -z "$MODEL"
    echo "Usage: $PROG_NAME -m <model.gguf> [--run|--dry-run|--detect-only]"
    exit 1
end

# Hardware detection
set gpu_count (nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -1 | string trim)
test -z "$gpu_count"; and set gpu_count 0
set cpu_cores (nproc 2>/dev/null | head -1 | string trim)
test -z "$cpu_cores"; and set cpu_cores 4

# Model parsing
set filename (basename "$MODEL")
set params ""
string match -rq '(\d+)B' "$filename"; and set params (string match -r '(\d+)B' "$filename" | tail -1)

# NGL calculation (sweet spot per benchmark)
set NGL 0
if test $gpu_count -gt 0
    set params_num (echo "$params" | tr -d 'B')
    if test -n "$params_num"
        if test $params_num -le 1; set NGL 20
        else if test $params_num -le 3; set NGL 25
        else if test $params_num -le 8; set NGL 37
        else if test $params_num -le 20; set NGL 45
        else; set NGL 35; end
    else; set NGL 37; end
end

# Multi-GPU split
set SPLIT ""
test $gpu_count -ge 2; and set SPLIT "-sm graph"

# Context size by model family
set CTX 8192
set family "unknown"
string match -rq '^[Qq]wen' "$filename"; and set family "qwen"
string match -rq '^[Dd]eep' "$filename"; and set family "deepseek"
string match -rq '[Oo]mni' "$filename"; and set family "omni"

# Reasoning models need more context
if test "$family" = "deepseek"
    set CTX 32768
    # Reasoning models get extra NGL
    if test $NGL -lt 50; set NGL 50; end
end

# Thread count (50% of physical cores)
set THREADS (math "$cpu_cores / 2")
test $THREADS -lt 1; and set THREADS 1

# Build flags - VALIDATED settings
set FLAGS "-m $MODEL -ngl $NGL $SPLIT -ctk f16 -ctv f16 -fa on -c $CTX -t $THREADS -gr -muge -b 512 -ub 512"

# Reasoning flag for DeepSeek
if test "$family" = "deepseek"
    set FLAGS "$FLAGS --reasoning on"
end

# Output - RUN_MODE exits early (for piping)
if test $RUN_MODE -eq 1
    echo "$FLAGS"
    exit 0
end

if test $DETECT_ONLY -eq 1
    echo "GPU: $gpu_count | CPU: $cpu_cores cores"
    exit 0
end

# Normal output
echo "NGL: $NGL | Context: $CTX | Threads: $THREADS"
echo "Flags: $FLAGS"

if test $DRY_RUN -eq 1
    echo "[DRY RUN]"
end
```

---

## 4. USAGE

```fish
# Download
curl -sL "https://raw.githubusercontent.com/Xeon-V/llama-autoflag/v3.0-ik-clean/llama-autoflag.fish" -o ~/llama-autoflag.fish
chmod +x ~/llama-autoflag.fish

# View flags
~/llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf

# Get flags for piping
~/llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf --run

# Run model
~/llama-lab/build/ik/bin/llama-cli (~/llama-autoflag.fish -m ~/models/Qwen3-8B-Q4_K_M.gguf --run) -p "Hello" -n 20
```

---

## 5. VALIDATED RESULTS

| Model | Speed (t/s) | VRAM |
|-------|-------------|------|
| qwen2.5-0.5B | 397 | 2GB |
| Qwen3-8B | 120 | 5GB |
| Qwen2.5-Omni-7B | 72 | 8GB |
| DeepSeek-R1-32B | 6→30* | 17GB |

*With --reasoning on flag

---

## 6. NOTES FOR CO-DEVELOPER

- **Fish shell required** - uses fish-specific syntax
- **ik_llama.cpp fork** - not compatible with mainline llama.cpp router mode
- **Boolean flags** - `-gr -muge` not `-gr -muge 0`
- **NGL 37** is benchmark-validated sweet spot for 8B models
- **KV f16** is faster than q8_0 in all tests
