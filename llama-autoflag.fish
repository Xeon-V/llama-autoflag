#!/usr/bin/env fish
# llama-autoflag - Automatic parameter optimization for ik_llama.cpp

set model $argv[1]

if test -z "$model"
    echo "Usage: $0 <model.gguf>"
    exit 1
end

# Hardware detection (handles empty results)
set gpu_count (nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -1 | string trim)
if test -z "$gpu_count"
    set gpu_count 0
end

set gpu_arch (nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | string trim | string replace '.' '')
if test -z "$gpu_arch"
    set gpu_arch 0
end

set cpu_threads (nproc 2>/dev/null | head -1 | string trim)
if test -z "$cpu_threads"
    set cpu_threads 4
end

set flags "-m $model"

# GPU offload
if test "$gpu_count" -gt 0 2>/dev/null
    set flags "$flags -ngl 999"

    # Multi-GPU: use graph split mode
    if test "$gpu_count" -ge 2 2>/dev/null
        set flags "$flags -sm graph"
    end
end

# Context size detection (case-insensitive)
if string match -ri "*Qwen3*" $model 2>/dev/null
    set flags "$flags -c 16384"
else if string match -ri "*Omni*" $model 2>/dev/null
    set flags "$flags -c 32768"
else if string match -ri "*DeepSeek*" $model 2>/dev/null
    set flags "$flags -c 16384"
else
    set flags "$flags -c 4096"
end

# Flash Attention + KV quant
set flags "$flags -fa on -ctk q8_0 -ctv q8_0"

# MLA for DeepSeek (Ampere+ GPUs)
if string match -ri "*DeepSeek*" $model 2>/dev/null
    if test "$gpu_arch" -ge 80 2>/dev/null
        set flags "$flags -mla 3 -khad -vhad"
    end
end

# MoE detection
if string match -ri "*moe*" $model 2>/dev/null
    set flags "$flags -fmoe -ooae"
end

# Thread count + performance options
set flags "$flags -t $cpu_threads -gr -muge 0"

echo $flags
