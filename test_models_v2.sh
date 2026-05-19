#!/bin/bash
# Model Test Script for ik_llama.cpp
# Uses ONLY benchmark-validated flags

set -e

BINARY="$HOME/llama-lab/build/ik/bin/llama-cli"
MODEL_DIR="$HOME/models"
RESULTS_DIR="$HOME/llama_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$RESULTS_DIR/test_$TIMESTAMP.txt"

# WORKING FLAGS (from benchmark)
# -ngl 37 = sweet spot (not 99!)
# -sm graph = dual GPU split
# -fa on = Flash Attention
# -ctk f16 -ctv f16 = KV cache (q8_0 is slower!)
# -gr -muge = graph optimization
BASE_FLAGS="-ngl 37 -sm graph -fa on -ctk f16 -ctv f16 -gr -muge -b 512 -ub 512"

# Models to test
MODELS=(
    "qwen2.5-0.5b-instruct-q5_k_m.gguf"
    "Qwen3-8B-Q4_K_M.gguf"
    "Qwen2.5-Omni-7B-Q8_0.gguf"
    "DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf"
)

PROMPT="Explain quantum computing in one sentence."
MAX_TOKENS=30

mkdir -p "$RESULTS_DIR"

echo "========================================" | tee "$LOGFILE"
echo "ik_llama.cpp Model Test" | tee -a "$LOGFILE"
echo "Date: $(date)" | tee -a "$LOGFILE"
echo "Flags: $BASE_FLAGS" | tee -a "$LOGFILE"
echo "========================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

for model in "${MODELS[@]}"; do
    MODEL_PATH="$MODEL_DIR/$model"
    
    if [[ ! -f "$MODEL_PATH" ]]; then
        echo "SKIP: $model not found"
        continue
    fi
    
    echo "Testing: $model" | tee -a "$LOGFILE"
    echo "----------------------------------------" | tee -a "$LOGFILE"
    
    START=$(date +%s)
    OUTPUT=$("$BINARY" -m "$MODEL_PATH" $BASE_FLAGS -c 8192 -t 14 -p "$PROMPT" -n $MAX_TOKENS --no-display-prompt 2>&1)
    END=$(date +%s)
    
    # Extract timing
    TG=$(echo "$OUTPUT" | grep -oP 'eval time.*?(\d+\.\d+) tokens per second' | grep -oP '\d+\.\d+' | tail -1)
    
    echo "TG Speed: ${TG:-ERR} t/s" | tee -a "$LOGFILE"
    echo "Duration: $((END-START))s" | tee -a "$LOGFILE"
    
    # Check errors
    if echo "$OUTPUT" | grep -qi "error\|oom"; then
        echo "ERROR DETECTED!" | tee -a "$LOGFILE"
    fi
    
    echo "" | tee -a "$LOGFILE"
    sleep 3
done

echo "========================================" | tee -a "$LOGFILE"
echo "DONE - Results: $LOGFILE" | tee -a "$LOGFILE"
