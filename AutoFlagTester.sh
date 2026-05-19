#!/bin/bash
#===============================================================================
# AutoFlagTester - Comprehensive Testing Script for llama-autoflag
# Version: 1.0
# Purpose: Validate llama-autoflag generates correct flags for all model types
#===============================================================================

set -e

# Configuration
BINARY="${HOME}/llama-lab/build/ik/bin/llama-cli"
MODEL_DIR="${HOME}/models"
RESULTS_DIR="${HOME}/llama_results"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="${RESULTS_DIR}/autoflag_test_${TIMESTAMP}.txt"

# AutoFlag script location
AUTOFLAG="${SCRIPT_DIR}/llama-autoflag.fish"

#===============================================================================
# Test Cases - Model -> Expected Flags
#===============================================================================
declare -A TEST_CASES

# Small models
TEST_CASES["qwen2.5-0.5b-instruct-q5_k_m.gguf"]="-ngl 20 -c 2048"
TEST_CASES["qwen2.5-1b"]="-ngl 25 -c 4096"

# Standard models
TEST_CASES["Qwen3-8B-Q4_K_M.gguf"]="-ngl 37 -c 8192"
TEST_CASES["Qwen3-8B-q6_k_m.gguf"]="-ngl 37 -c 8192"

# Vision/Omni models
TEST_CASES["Qwen2.5-Omni-7B-Q8_0.gguf"]="-ngl 40 -c 16384"
TEST_CASES["MiniCPM-o-4_5-Q8_0.gguf"]="-ngl 40 -c 16384"

# Reasoning models
TEST_CASES["DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf"]="-ngl 50 -c 32768 --reasoning on"

# Large models
TEST_CASES["Qwen3-30B-A3B-Q4_K_M.gguf"]="-ngl 35 -c 8192"
TEST_CASES["qwen2.5-14b"]="-ngl 45 -c 8192"

#===============================================================================
# Helper Functions
#===============================================================================

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOGFILE"
}

check_flag() {
    local expected="$1"
    local actual="$2"
    
    # Extract key flags from expected
    for flag in $expected; do
        if [[ "$actual" != *"$flag"* ]]; then
            return 1  # FAIL
        fi
    done
    return 0  # PASS
}

run_model_test() {
    local model="$1"
    local model_path="$MODEL_DIR/$model"
    local expected_flags="$2"
    
    if [[ ! -f "$model_path" ]]; then
        log "SKIP: $model (not found)"
        return 1
    fi
    
    log "Testing: $model"
    
    # Get flags from AutoFlag
    local actual_flags=$(fish "$AUTOFLAG" -m "$model_path" --run 2>/dev/null)
    
    # Validate flags
    if check_flag "$expected_flags" "$actual_flags"; then
        log "  ✓ PASS - Flags generated correctly"
        return 0
    else
        log "  ✗ FAIL"
        log "    Expected: $expected_flags"
        log "    Got: $actual_flags"
        return 1
    fi
}

run_inference_test() {
    local model="$1"
    local model_path="$MODEL_DIR/$model"
    
    if [[ ! -f "$model_path" ]]; then
        return 1
    fi
    
    log "  Running inference test..."
    
    # Get flags
    local flags=$(fish "$AUTOFLAG" -m "$model_path" --run 2>/dev/null)
    
    # Run quick inference
    if timeout 30 "$BINARY" $flags -p "Hi" -n 5 --no-display-prompt 2>&1 | grep -q "eval time"; then
        log "  ✓ Inference works"
        return 0
    else
        log "  ✗ Inference failed"
        return 1
    fi
}

#===============================================================================
# Main Test Execution
#===============================================================================

mkdir -p "$RESULTS_DIR"

echo "===============================================================================" | tee "$LOGFILE"
echo "AutoFlagTester - $(date)" | tee -a "$LOGFILE"
echo "Binary: $BINARY" | tee -a "$LOGFILE"
echo "AutoFlag: $AUTOFLAG" | tee -a "$LOGFILE"
echo "===============================================================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

# Check prerequisites
if [[ ! -x "$BINARY" ]]; then
    log "ERROR: Binary not found: $BINARY"
    exit 1
fi

if [[ ! -f "$AUTOFLAG" ]]; then
    log "ERROR: AutoFlag not found: $AUTOFLAG"
    exit 1
fi

# Run flag validation tests
log "=== PHASE 1: Flag Validation ==="
PASS=0
FAIL=0

for model in "${!TEST_CASES[@]}"; do
    expected="${TEST_CASES[$model]}"
    if run_model_test "$model" "$expected"; then
        ((PASS++))
    else
        ((FAIL++))
    fi
done

echo "" | tee -a "$LOGFILE"
log "Results: $PASS passed, $FAIL failed"

# Run inference tests on available models
echo "" | tee -a "$LOGFILE"
log "=== PHASE 2: Inference Validation ==="
INFER_PASS=0
INFER_FAIL=0

for model in "${!TEST_CASES[@]}"; do
    if [[ -f "$MODEL_DIR/$model" ]]; then
        if run_inference_test "$model"; then
            ((INFER_PASS++))
        else
            ((INFER_FAIL++))
        fi
    fi
done

echo "" | tee -a "$LOGFILE"
log "Inference: $INFER_PASS passed, $INFER_FAIL failed"

# Summary
echo "" | tee -a "$LOGFILE"
echo "===============================================================================" | tee -a "$LOGFILE"
if [[ $FAIL -eq 0 && $INFER_FAIL -eq 0 ]]; then
    log "✓ ALL TESTS PASSED"
    exit 0
else
    log "✗ SOME TESTS FAILED"
    exit 1
fi
