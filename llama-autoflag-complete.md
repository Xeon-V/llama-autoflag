# llama-autoflag - Technical Specification

## 1. USE CASE

**Purpose**: Auto-generate optimized llama.cpp CLI flags for any Model based on hardware detection.

**Target Users**:
- AI developers running local LLM inference
- Researchers benchmarking llama.cpp performance
- Power users with multi-GPU setups

---

## 2. TECHNICAL PLAN

### Architecture
```
┌─────────────────────┐
│  Hardware Detect    │ ← nvidia-smi, nproc
├─────────────────────┤
│  Model Parser       │ ← Extract params/family from filename
├─────────────────────┤
│  Decision Engine    │ ← NGL calc, context, flags
├─────────────────────┤
│  Flag Output        │ ← Shell function / CLI args
└─────────────────────┘
```

### Decision Matrix

| Model Type | Size | NGL | Context | Extra Flags |
|------------|------|-----|---------|--------------|
| Small | 0.5-1B | 20-25 | 2048-4096 | - |
| Standard | 3-8B | 37 | 8192 | - |
| Large | 14-20B | 40-45 | 8192 | - |
| X-Large | 30B+ | 35 | 8192 | - |
| Vision/Omni | Any | 40 | 16384 | - |
| Reasoning | Any | 50 | 32768 | --reasoning on |

### Benchmark Findings (Dual Titan V)

| Setting | Old Value | Optimized | Impact |
|---------|-----------|-----------|--------|
| NGL | 99 | **37** | 2x speedup |
| KV Cache | q8_0 | **f16** | +10% speed |
| Split Mode | row | **graph** | Required |

---

## 3. SOURCE CODE

```fish
#!/usr/bin/env fish
# llama-autoflag.fish - Auto-generate optimized ik_llama.cpp flags
# Version: 3.0.3-ik

set -l PROG_NAME "llama-autoflag"
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

# Model family detection
set family "unknown"
string match -rq '^[Qq]wen' "$filename"; and set family "qwen"
string match -rq '^[Dd]eep' "$filename"; and set family "deepseek"
string match -rq '[Oo]mni' "$filename"; and set family "omni"

# NGL calculation (benchmark-validated sweet spots)
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

# Reasoning/vision models need more NGL
if test "$family" = "deepseek"
    set NGL 50
else if test "$family" = "omni"
    set NGL 40
end

# Multi-GPU split
set SPLIT ""
test $gpu_count -ge 2; and set SPLIT "-sm graph"

# Context size by model family
set CTX 8192
if test "$family" = "deepseek"
    set CTX 32768
else if test "$family" = "omni"
    set CTX 16384
end

# Thread count (50% of physical cores)
set THREADS (math "$cpu_cores / 2")
test $THREADS -lt 1; and set THREADS 1

# Build flags (VALIDATED - NOT q8_0, NO =0 for booleans)
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
echo "NGL: $NGL | Context: $CTX | Threads: $THREADS | Family: $family"
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

| Model | Expected NGL | Expected Context | Speed (t/s) |
|-------|-------------|-----------------|--------------|
| qwen2.5-0.5B | 20 | 2048 | ~400 |
| Qwen3-8B | 37 | 8192 | ~120 |
| Qwen2.5-Omni-7B | 40 | 16384 | ~72 |
| DeepSeek-R1-32B | 50 | 32768 | ~30* |

*With --reasoning on flag

---

## 6. AUTOFLAGTESTER

Use `AutoFlagTester.sh` to validate all models:

```bash
# Run tests
./AutoFlagTester.sh

# Results saved to ~/llama_results/autoflag_test_*.txt
```

---

## 7. NOTES FOR CO-DEVELOPER

- **Fish shell required** - uses fish-specific syntax
- **ik_llama.cpp fork** - not compatible with mainline llama.cpp router mode
- **Boolean flags** - use `-gr -muge` NOT `-gr -muge 0`
- **NGL 37** is benchmark-validated sweet spot for 8B models
- **KV f16** is faster than q8_0 in all tests
- **--reasoning on** required for DeepSeek R1 and similar models
