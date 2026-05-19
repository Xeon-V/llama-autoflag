#!/bin/bash
# Model Test Script v3 - with model-specific optimizations
# ik_llama.cpp benchmark-validated settings

set -e

BINARY="$HOME/llama-lab/build/ik/bin/llama-cli"
MODEL_DIR="$HOME/models"
RESULTS_DIR="$HOME/llama_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$RESULTS_DIR/test_$TIMESTAMP.txt"

# Base flags (work for most models)
BASE_FLAGS="-ngl 37 -sm graph -fa on -ctk f16 -ctv f16 -gr -muge -b 512 -ub 512 -t 14"

# Model-specific overrides
declare -A MODEL_FLAGS
MODEL_FLAGS=(
    # Small models - fewer layers needed
    ["0.5b"]="-ngl 20 -c 2048"
    ["1b"]="-ngl 25 -c 4096"
    ["3b"]="-ngl 30 -c 4096"
    
    # Reasoning models (DeepSeek R1, etc)
    ["reasoning"]="-ngl 50 -c 32768 --reasoning on"
    ["r1"]="-ngl 50 -c 32768 --reasoning on"
    ["deepseek"]="-ngl 50 -c 32768 --reasoning on"
    
    # Vision models
    ["omni"]="-ngl 40 -c 8192"
    ["vision"]="-ngl 40 -c 8192"
    ["llava"]="-ngl 40 -c 8192"
    
    # Large models (20B+) - need fewer layers
    ["14b"]="-ngl 45 -c 8192"
    ["20b"]="-ngl 40 -c 8192"
    ["30b"]="-ngl 35 -c 8192"
    ["32b"]="-ngl 35 -c 8192"
)

# Models to test
MODELS=(
    "qwen2.5-0.5b-instruct-q5_k_m.gguf"
    "Qwen3-8B-Q4_K_M.gguf"
    "Qwen2.5-Omni-7B-Q8_0.gguf"
    "DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf"
)

PROMPT="Explain quantum computing in one sentence."
MAX_TOKENS=30

get_flags() {
    local model="$1"
    local flags="$BASE_FLAGS"
    
    # Check for model-specific flags
    for key in "${!MODEL_FLAGS[@]}"; do
        if echo "$model" | grep -iq "$key"; then
            flags="${MODEL_FLAGS[$key]}"
            break
        fi
    done
    
    echo "$flags"
}

mkdir -p "$RESULTS_DIR"

echo "========================================"
echo "ik_llama.cpp Model Test v3"
echo "Date: $(date)"
echo "========================================"

for model in "${MODELS[@]}"; do
    MODEL_PATH="$MODEL_DIR/$model"
    
    if [[ ! -f "$MODEL_PATH" ]]; then
        echo "SKIP: $model not found"
        continue
    fi
    
    FLAGS=$(get_flags "$model")
    
    echo ""
    echo "Testing: $model"
    echo "Flags: $FLAGS"
    echo "----------------------------------------"
    
    START=$(date +%s)
    OUTPUT=$("$BINARY" -m "$MODEL_PATH" $FLAGS -p "$PROMPT" -n $MAX_TOKENS --no-display-prompt 2>&1)
    END=$(date +%s)
    
    TG=$(echo "$OUTPUT" | grep -oP 'eval time.*?(\d+\.\d+) tokens per second' | grep -oP '\d+\.\d+' | tail -1)
    
    echo "TG Speed: ${TG:-ERR} t/s"
    echo "Duration: $((END-START))s"
    
    if echo "$OUTPUT" | grep -qi "error\|oom"; then
        echo "ERROR DETECTED!"
    fi
    
    sleep 3
done

echo ""
echo "========================================"
echo "DONE"
