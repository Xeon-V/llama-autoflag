#!/usr/bin/env fish
# llama-autoflag - Automatic parameter optimization for ik_llama.cpp
# Updated to work with ik_llama.cpp fork (https://github.com/ikawrakow/ik_llama.cpp)
#
# Usage: llama-autoflag <model_path>
# Returns optimized flags for llama-cli or llama-server

function llama-autoflag
    set -l model $argv[1]
    set -l build_dir ~/llama-lab/build/ik  # Your ik_llama.cpp build path

    # Hardware detection
    set -l gpu_count (nvidia-smi --query-gpu=count --format=csv,noheader | head -1 | string trim)
    set -l gpu_arch (nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
    set -l cpu_threads (nproc)

    # Base flags
    set -l flags -m $model

    # GPU offload
    if test $gpu_count -gt 0
        set -a flags -ngl 999

        # Multi-GPU: use graph split mode (ik_llama.cpp exclusive feature)
        if test $gpu_count -ge 2
            set -a flags -sm graph
            # Use tensor split for fine-grained control if needed
            # set -a flags -ts 1,1
        end
    end

    # Context size detection from model name
    if string match -qr "*Qwen3*" $model
        set -a flags -c 16384
    else if string match -qr "*Omni*" $model
        set -a flags -c 32768
    else if string match -qr "*DeepSeek*" $model
        set -a flags -c 16384
    else
        set -a flags -c 4096
    end

    # Flash Attention + KV quant (ik_llama.cpp native optimization)
    # -fa on is default in ik_llama.cpp, but explicit is clearer
    set -a flags -fa on

    # KV cache quantization - significant VRAM savings with minimal quality loss
    set -a flags -ctk q8_0 -ctv q8_0

    # GPU architecture-specific optimizations
    if test $gpu_count -gt 0 -a $gpu_arch -lt 80
        # Volta/Turing: Disable some advanced features not supported
        # Note: MLA requires Ampere+ (compute capability 8.0+)
        # Flash Attention works on all modern GPUs
    end

    # MLA (Multi-Latent Attention) - ik_llama.cpp exclusive for DeepSeek models
    if string match -qr "*DeepSeek*" $model
        if test $gpu_count -gt 0 -a $gpu_arch -ge 80
            # MLA requires Ampere+ (compute capability 8.0+)
            set -a flags -mla 3
        end
        # Use Hadamard transform for better KV quality with quant
        set -a flags -khad -vhad
    end

    # MoE detection - ik_llama.cpp has excellent MoE support
    if string match -qr "*moe*" $model; or string match -qr "*MoE*" $model
        # ik_llama.cpp has smart tensor placement for MoE
        set -l model_size (stat -c%s $model 2>/dev/null; or echo 0)
        set -l vram_total (nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | awk '{s+=$1} END {print s*1024*1024}')

        if test $model_size -gt $vram_total
            # Use --fit for automatic VRAM optimization
            set -a flags --fit
            # Or use explicit tensor override to keep experts on CPU:
            # set -a flags -ot ".*ffn.*_exps.=CPU"
        else
            # Offload all layers - good for moE with sufficient VRAM
            set -a flags -ngl 999
        end

        # ik_llama.cpp specific: better MoE performance with fused MoE
        set -a flags -fmoe

        # Offload only active experts (default on, but explicit)
        set -a flags -ooae
    end

    # Thread count
    set -a flags -t $cpu_threads

    # ik_llama.cpp additional performance options
    # Graph reuse for faster token generation
    set -a flags -gr

    # Fused up-gate for dense models
    set -a flags -muge 0

    echo $flags
end