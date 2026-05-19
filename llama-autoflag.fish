#!/usr/bin/env fish
# llama-autoflag - Automatic parameter optimization for ik_llama.cpp

set model $argv[1]

if test -z "$model"
    echo "Usage: $0 <model.gguf>"
    exit 1
end

# Hardware detection
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
if test "$gpu_count" -gt 0
    set flags "$flags -ngl 999"
    if test "$gpu_count" -ge 2
        set flags "$flags -sm graph"
    end
end

# Context size detection - lowercase comparison
set model_lower (echo $model | tr '[:upper:]' '[:lower:]')
if echo $model_lower | grep -q "qwen3"
    set flags "$flags -c 16384"
else if echo $model_lower | grep -q "omni"
    set flags "$flags -c 32768"
else if echo $model_lower | grep -q "deepseek"
    set flags "$flags -c 16384"
else
    set flags "$flags -c 4096"
end

set flags "$flags -fa on -ctk q8_0 -ctv q8_0"

# MLA for DeepSeek
if echo $model_lower | grep -q "deepseek"
    if test "$gpu_arch" -ge 80
        set flags "$flags -mla 3 -khad -vhad"
    end
end

# MoE detection
if echo $model_lower | grep -q "moe"
    set flags "$flags -fmoe -ooae"
end

set flags "$flags -t $cpu_threads -gr -muge 0"

echo $flags
