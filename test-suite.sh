#!/bin/bash
# llama-autoflag Test Suite
# Run: bash test-suite.sh

echo "╔══════════════════════════════════════════════════════╗"
echo "║         LLAMA AUTOFLAG TEST SUITE v1.3.0            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

MODEL_PATH="~/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf"
LLAMA_DIR="~/llama-bee"

run_test() {
    local name="$1"
    local cmd="$2"
    local check="$3"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TEST: $name"
    echo "CMD:  $cmd"
    echo ""
    
    result=$(eval "$cmd" 2>&1)
    
    if [[ "$result" == *"$check"* ]]; then
        echo "✅ PASS: Found '$check'"
        ((PASS++))
    else
        echo "❌ FAIL: Missing '$check'"
        ((FAIL++))
        echo "--- Output ---"
        echo "$result" | head -30
    fi
    echo ""
}

# Test 1: detect-only works
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: detect-only (no model needed)"
echo ""
result=$(fish ./llama-autoflag.fish --detect-only 2>&1)
if [[ "$result" == *"sm_7.0"* ]]; then
    echo "✅ PASS: detect-only shows sm_7.0 GPU"
    ((PASS++))
else
    echo "❌ FAIL: sm_7.0 not detected"
    ((FAIL++))
fi
echo ""

# Test 2: -ngl 55 override
run_test "NGL Override (55)" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 55 --dry-run" \
    "GPU Layers: 55/99"

# Test 3: -ngl 99 (full GPU)
run_test "NGL Full GPU (99)" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 99 --dry-run" \
    "GPU Layers: 99/99"

# Test 4: -ngl 0 (CPU only)
run_test "NGL CPU Only (0)" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 0 --dry-run" \
    "GPU Layers: 0"

# Test 5: GGML_CUDA_FORCE_MMQ present
run_test "GGML_CUDA_FORCE_MMQ env" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 55 --dry-run" \
    "GGML_CUDA_FORCE_MMQ=1"

# Test 6: KV quant q8_0
run_test "KV Quant q8_0" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 55 -q q8_0 --dry-run" \
    "KV Quant: q8_0"

# Test 7: Flash attention
run_test "Flash Attention" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 55 -fa --dry-run" \
    "-fa --mlock"

# Test 8: Context size
run_test "Context Size 4096" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 55 -c 4096 --dry-run" \
    "Context: 4096"

# Test 9: CPU only mode
run_test "CPU Only Mode" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR --cpu --dry-run" \
    "CPU only"

# Test 10: Tensor split present for dual GPU
run_test "Tensor Split (dual GPU)" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 55 --dry-run" \
    "-ts 0.55,0.45"

# Test 11: Threads set
run_test "Thread Count" \
    "fish ./llama-autoflag.fish -m $MODEL_PATH --dir $LLAMA_DIR -ngl 55 --dry-run" \
    "Threads: 14"

# SUMMARY
echo "╔══════════════════════════════════════════════════════╗"
echo "║                    TEST RESULTS                      ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  ✅ PASSED: $PASS                                      ║"
echo "║  ❌ FAILED: $FAIL                                      ║"
echo "╚══════════════════════════════════════════════════════╝"

if [ $FAIL -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED!"
    exit 0
else
    echo "⚠️  SOME TESTS FAILED"
    exit 1
fi
