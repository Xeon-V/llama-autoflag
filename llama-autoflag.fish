#!/usr/bin/env fish
# llama-autoflag.fish — Auto-detects hardware and generates optimal ik_llama.cpp flags
# KEY FINDINGS (Qwen3-8B on dual TITAN V):
#   - NGL 37 is sweet spot (not 99) — 2x performance gain
#   - KV quant (q8_0) slows TG by ~10% — use f16
#   - -ot ffn=CPU causes massive slowdown (AVOID)
#   - Row split NOT SUPPORTED in ik_llama.cpp

# Version: 2.1.0-ik for ik_llama.cpp (https://github.com/ikawrakow/ik_llama.cpp)

set -l VERSION "3.0.0-ik"
set -l PROG_NAME "llama-autoflag"

# Defaults
set -l MODEL ""
set -l CONTEXT 0
set -l KV_QUANT ""
set -l GPU_MODE "auto"
set -l DRY_RUN 0
set -l DETECT_ONLY 0
set -l SPLIT_MODE "graph"

# Parse Args
set -l i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case '-m' '--model'
            set i (math $i + 1)
            set MODEL $argv[$i]
        case '-c' '--context'
            set i (math $i + 1)
            set CONTEXT $argv[$i]
        case '-q' '--kv-quant'
            set i (math $i + 1)
            set KV_QUANT $argv[$i]
        case '-g' '--gpu'
            set i (math $i + 1)
            set GPU_MODE $argv[$i]
        case '--split-mode'
            set i (math $i + 1)
            set SPLIT_MODE $argv[$i]
        case '--cpu'
            set GPU_MODE "none"
        case '--dry-run'
            set DRY_RUN 1
        case '--detect-only'
            set DETECT_ONLY 1
        case '-h' '--help'
            echo "Usage: $PROG_NAME -m <model.gguf> [options]"
            exit 0
    end
    set i (math $i + 1)
end

# Validate
if test -z "$MODEL"
    echo "Error: Model required (-m)"
    exit 1
end

if not test -f "$MODEL"
    echo "Error: Model not found: $MODEL"
    exit 1
end

# Detect Hardware
set gpu_count (nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -1 | string trim)
if test -z "$gpu_count"; set gpu_count 0; end

set gpu_arch (nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | string trim)
if test -z "$gpu_arch"; set gpu_arch 0; end

set cpu_cores (nproc 2>/dev/null | head -1 | string trim)
if test -z "$cpu_cores"; set cpu_cores 4; end

# Detect GPUs
set -l GPU_INFO (nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null)
set -l TOTAL_VRAM 0
for line in $GPU_INFO
    set -l parts (string split ',' $line)
    set -l vram (string trim $parts[2] | string replace 'MiB' '')
    set -l vram_gb (math "$vram / 1024")
    set TOTAL_VRAM (math "$TOTAL_VRAM + $vram_gb")
end

# Parse Model
set -l filename (basename "$MODEL")
set -l model_bytes (stat -c%s "$MODEL" 2>/dev/null; or echo 0)
set -l model_gb (math "$model_bytes / 1073741824")

set -l params ""
set -l is_moe 0

if string match -rq '(\d+)B-A(\d+)B' "$filename"
    set params (string match -r '(\d+)B-A(\d+)B' "$filename" | head -1 | string replace 'B-A' 'B (MoE: ')
    set is_moe 1
else if string match -rq '(\d+)(\.\d+)?B' "$filename"
    set params (string match -r '(\d+)(\.\d+)?B' "$filename" | tail -1)
end

# Parse Family & Check Reasoning Model
set -l family "unknown"
set -l is_reasoning 0

if string match -rq '^[Qq]wen' "$filename"
    set family "qwen"
else if string match -rq '^[Dd]eep[Ss]eek.*[Rr]1' "$filename"
    set family "deepseek"
    set is_reasoning 1
else if string match -rq '^[Dd]eep[Ss]eek' "$filename"
    set family "deepseek"
else if string match -rq '^[Ll]lama' "$filename"
    set family "llama"
else if string match -rq '^[Gg]emma' "$filename"
    set family "gemma"
end

# Decision Logic
set -l NGL 0
set -l SPLIT_FLAG ""
set -l EXTRA_FLAGS ""
set -l NOTICE ""

# VRAM calc
set -l USABLE_VRAM (math "$TOTAL_VRAM - 4")
if test $USABLE_VRAM -lt 1
    set USABLE_VRAM 1
end

# Split mode
if test $gpu_count -ge 2 -a "$GPU_MODE" != "none"
    if test "$SPLIT_MODE" = "graph"
        set SPLIT_FLAG "-sm graph"
        set NOTICE "$NOTICE graph"
    else if test "$SPLIT_MODE" = "layer"
        set SPLIT_FLAG "-sm layer"
        set NOTICE "$NOTICE layer"
    end
end

# NGL calc
if test $gpu_count -gt 0 -a "$GPU_MODE" != "none"
    set params_num (echo "$params" | tr -d 'B' | string replace '.' '')
    if test -n "$params_num"
        set est_layers 32
        if test $params_num -ge 70
            set est_layers 80
        else if test $params_num -ge 27
            set est_layers 64
        else if test $params_num -ge 14
            set est_layers 48
        end
        
        set vram_per_layer (math "$model_gb / $est_layers")
        if test $vram_per_layer -gt 0
            set max_layers (math "floor($USABLE_VRAM / $vram_per_layer)")
            if test $max_layers -ge 99
                set NGL 37
            else
                set NGL $max_layers
            end
        else
            set NGL 37
        end
    else
        if test $model_gb -lt (math "$TOTAL_VRAM * 0.8")
            set NGL 37
        else
            set NGL 50
        end
    end
end

# ik_llama.cpp --fit option
if test $model_gb -gt $USABLE_VRAM
    set EXTRA_FLAGS "$EXTRA_FLAGS --fit"
    set NOTICE "$NOTICE fit"
end

# Context - larger for reasoning models
set CTX $CONTEXT
if test $CTX -eq 0
    if test "$family" = "qwen"
        set CTX 16384
    else if test "$family" = "deepseek"
        if test $is_reasoning -eq 1
            set CTX 32768
        else
            set CTX 16384
        end
    else if test "$family" = "gemma"
        set CTX 8192
    else
        set CTX 4096
    end
end

# Threads
set THREADS (math "$cpu_cores / 2")
if test $THREADS -lt 1
    set THREADS 1
end

# KV Quant
if test -n "$KV_QUANT"
    set CACHE_K $KV_QUANT
    set CACHE_V $KV_QUANT
else
    if test "$family" = "qwen" -o "$family" = "deepseek"
        set CACHE_K "f16"
        set CACHE_V "f16"
    else
        set CACHE_K "f16"
        set CACHE_V "q4_0"
    end
end

# ik_llama.cpp extras
if test "$family" = "deepseek" -a $gpu_count -gt 0
    set EXTRA_FLAGS "$EXTRA_FLAGS -mla 3 -khad -vhad"
    set NOTICE "$NOTICE MLA+Hadamard"
end

if test $is_moe -eq 1
    set EXTRA_FLAGS "$EXTRA_FLAGS -fmoe -ooae"
end

# Reasoning model optimization
if test $is_reasoning -eq 1
    set EXTRA_FLAGS "$EXTRA_FLAGS --reasoning on"
    set NOTICE "$NOTICE reasoning"
end

# Build Flags
set FLAGS "-m $MODEL"
if test $NGL -gt 0
    set FLAGS "$FLAGS -ngl $NGL"
end
if test -n "$SPLIT_FLAG"
    set FLAGS "$FLAGS $SPLIT_FLAG"
end
set FLAGS "$FLAGS -ctk $CACHE_K -ctv $CACHE_V -fa on"
set FLAGS "$FLAGS -c $CTX -t $THREADS -gr -muge 0"
if test -n "$EXTRA_FLAGS"
    set FLAGS "$FLAGS $EXTRA_FLAGS"
end
set FLAGS "$FLAGS -b 512 -ub 512"

# Output
echo ""
echo "llama-autoflag v$VERSION (ik_llama.cpp)"
echo "======================================"
echo "GPU: $gpu_count (VRAM: $TOTAL_VRAM GB)"
echo "Model: $model_gb GB"
if test -n "$params"
    echo "Params: $params"
end
if test $is_reasoning -eq 1
    echo "Type: Reasoning Model"
end
echo ""
echo "NGL: $NGL"
echo "Context: $CTX"
echo "KV: $CACHE_K / $CACHE_V"
if test -n "$NOTICE"
    echo "Features: $NOTICE"
end
echo ""
echo "FLAGS:"
echo "  $FLAGS"

if test $DETECT_ONLY -eq 1
    exit 0
end

if test $DRY_RUN -eq 1
    echo ""
    echo "[DRY RUN]"
    exit 0
end
