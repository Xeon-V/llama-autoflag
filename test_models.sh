#!/bin/bash
# Comprehensive Model Test Script for ik_llama.cpp
# Tests all models with various flag combinations
# Quality focus - records results to file

set -e

BINARY="$HOME/llama-lab/build/ik/bin/llama-cli"
MODEL_DIR="$HOME/models"
RESULTS_DIR="$HOME/llama_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$RESULTS_DIR/test_results_$TIMESTAMP.txt"

# Models to test (skip vocab files, only actual models)
MODELS=(
    "qwen2.5-0.5b-instruct-q5_k_m.gguf"
    "Qwen3-8B-Q4_K_M.gguf"
    "Qwen3-8B-q6_k_m.gguf"
    "Qwen2.5-Omni-7B-Q8_0.gguf"
    "MiniCPM-o-4_5-Q8_0.gguf"
    "qwen2.5-coder-7b-instruct-q6_k.gguf"
    "qwen2.5-coder-14b-instruct-q8_0.gguf"
    "DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf"
    "Qwen3-30B-A3B-Q4_K_M.gguf"
    "gemma-4-26B-A4B-it-UD-Q4_K_M.gguf"
)

# Flag combinations to test (quality focus)
FLAG_COMBOS=(
    "baseline|-ngl 37 -c 4096 -fa on -t 14"
    "full_gpu|-ngl 99 -c 4096 -fa on -t 14"
    "low_context|-ngl 37 -c 2048 -fa on -t 14"
    "high_context|-ngl 37 -c 8192 -fa on -t 14"
    "no_flash|-ngl 37 -c 4096 -fa off -t 14"
    "multi_gpu|-ngl 99 -c 4096 -fa on -t 14 -sm graph"
    "kv_q8|-ngl 37 -c 4096 -fa on -t 14 -ctk q8_0 -ctv q8_0"
    "kv_q4|-ngl 37 -c 4096 -fa on -t 14 -ctk q4_0 -ctv q4_0"
    "threads_28|-ngl 37 -c 4096 -fa on -t 28"
)

PROMPT="Write a brief technical explanation of how neural networks learn through backpropagation."
MAX_TOKENS=50

mkdir -p "$RESULTS_DIR"

echo "========================================"
echo "ik_llama.cpp Model Test Suite"
echo "Date: $(date)"
echo "Binary: $BINARY"
echo "========================================"
echo ""

# Check binary
if [[ ! -x "$BINARY" ]]; then
    echo "ERROR: Binary not found: $BINARY"
    exit 1
fi

# Test each model
for model in "${MODELS[@]}"; do
    MODEL_PATH="$MODEL_DIR/$model"
    
    if [[ ! -f "$MODEL_PATH" ]]; then
        echo "SKIP: Model not found: $model"
        continue
    fi
    
    echo "========================================"
    echo "MODEL: $model"
    echo "SIZE: $(du -h "$MODEL_PATH" | cut -f1)"
    echo "========================================"
    
    # Get model info
    MODEL_INFO=$("$BINARY" -m "$MODEL_PATH" --log-disable 2>&1 | grep -E "(model ftype|model params|arch|layers)" | head -5)
    echo "$MODEL_INFO"
    echo ""
    
    for combo in "${FLAG_COMBOS[@]}"; do
        NAME="${combo%%|*}"
        FLAGS="${combo#*|}"
        
        echo "--- Test: $NAME ---"
        echo "Flags: $FLAGS"
        
        # Run test
        START=$(date +%s)
        OUTPUT=$("$BINARY" -m "$MODEL_PATH" $FLAGS -p "$PROMPT" -n $MAX_TOKENS --no-display-prompt 2>&1)
        END=$(date +%s)
        DURATION=$((END - START))
        
        # Extract timing
        PP_TOKENS=$(echo "$OUTPUT" | grep -oP 'prompt eval time.*?(\d+\.\d+) tokens per second' | grep -oP '\d+\.\d+' | tail -1)
        TG_TOKENS=$(echo "$OUTPUT" | grep -oP 'eval time.*?(\d+\.\d+) tokens per second' | grep -oP '\d+\.\d+' | tail -1)
        
        echo "PP Speed: ${PP_TOKENS:-N/A} t/s"
        echo "TG Speed: ${TG_TOKENS:-N/A} t/s"
        echo "Duration: ${DURATION}s"
        
        # Check for errors
        if echo "$OUTPUT" | grep -qi "error\|oom\|cuda"; then
            echo "WARNING: Error detected!"
        fi
        
        echo ""
        
        # Cool down
        sleep 3
    done
    
    echo ""
done

echo "========================================"
echo "TEST COMPLETE"
echo "Results saved to: $LOGFILE"
echo "========================================"
