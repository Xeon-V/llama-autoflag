#!/usr/bin/env fish
# llama-autoflag.fish — Auto-detects hardware and generates optimal llama.cpp flags
# Version: 1.0.0
# Tailored for: Dual NVIDIA TITAN V (sm_70), CUDA 12.9, Driver 580.x, CachyOS

set -l VERSION "1.2.0"
set -l PROG_NAME "llama-autoflag"
set -l LLAMA_DIR "./build"
set -l LLAMA_BIN "$LLAMA_DIR/build/bin/llama-cli"

# ─── Defaults ───
set -l MODEL ""
set -l DRAFT_MODEL ""
set -l INF_TYPE "text"
set -l CONTEXT 0
set -l KV_QUANT ""
set -l SPEC_TYPE ""
set -l GPU_MODE "auto"
set -l DRY_RUN 0
set -l NGL 0
set -l NGL_USER_SET 0
set -l SAVE_PATH ""
set -l VERBOSE 0
set -l DETECT_ONLY 0
set -l SELF_TEST 0
set -l REPORT 0
set -l PROMPT ""
set -l NUM_TOKENS 128
set -l TEMP "0.6"
set -l SERVER_MODELS_DIR ""
set -l SERVER_PORT 8080
set -l SPLIT_MODE "layer"
set -l FLASH_ATTN ""

# ─── Parse Arguments ───
set -l i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case '-m' '--model'
            set i (math $i + 1)
            set MODEL $argv[$i]
        case '--dir'
            set i (math $i + 1)
            set LLAMA_DIR $argv[$i]
            set LLAMA_BIN "$LLAMA_DIR/build/bin/llama-cli"
        case '--models-dir'
            set i (math $i + 1)
            set SERVER_MODELS_DIR $argv[$i]
        case '--port'
            set i (math $i + 1)
            set SERVER_PORT $argv[$i]
        case '--split-mode'
            set i (math $i + 1)
            set SPLIT_MODE $argv[$i]
        case '-fa' '--flash-attn'
            set FLASH_ATTN "-fa"
        case '-d' '--draft'
            set i (math $i + 1)
            set DRAFT_MODEL $argv[$i]
        case '-t' '--type'
            set i (math $i + 1)
            set INF_TYPE $argv[$i]
        case '-c' '--context'
            set i (math $i + 1)
            set CONTEXT $argv[$i]
        case '-ngl'
echo "DEBUG: argv[$i]=$argv[$i]"
            set i (math $i + 1)
            echo "DEBUG-SET-VAL: i=$i argv[i]=$argv[$i]"
            set NGL $argv[$i]
            set NGL_USER_SET 1
            echo "DEBUG-AFTER-SET: NGL=$NGL"
echo "DEBUG-ARG-PARSE: Set NGL=$NGL NGL_USER_SET=$NGL_USER_SET"
        case '-q' '--kv-quant'
            set i (math $i + 1)
            set KV_QUANT $argv[$i]
        case '-s' '--spec-type'
            set i (math $i + 1)
            set SPEC_TYPE $argv[$i]
        case '-g' '--gpu'
            set i (math $i + 1)
            set GPU_MODE $argv[$i]
        case '-p' '--prompt'
            set i (math $i + 1)
            set PROMPT $argv[$i]
        case '-n' '--tokens'
            set i (math $i + 1)
            set NUM_TOKENS $argv[$i]
        case '--temp'
            set i (math $i + 1)
            set TEMP $argv[$i]
        case '--cpu'
            set GPU_MODE "none"
        case '--dry-run'
            set DRY_RUN 1
        case '--save'
            set i (math $i + 1)
            set SAVE_PATH $argv[$i]
        case '-v' '--verbose'
            set VERBOSE 1
        case '--detect-only'
            set DETECT_ONLY 1
        case '--self-test'
            set SELF_TEST 1
        case '--report'
            set REPORT 1
        case '-h' '--help'
            __print_help
            exit 0
    end
    set i (math $i + 1)
end

# ─── Help ───
function __print_help
    echo "Usage: $PROG_NAME -m <model.gguf> [options]"
    echo ""
    echo "Options:"
    echo "  -m, --model <path>      Model file (required)"
    echo "  -d, --draft <path>      Draft model for speculative decode"
    echo "  -t, --type <type>       Inference type: text|vision|omni|api|batch (default: text)"
    echo "  --models-dir <path>     Auto-discover models for server mode"
    echo "  --port <n>             Server port (default: 8080)"
    echo "  --split-mode <mode>    Split mode: layer|row (default: layer)"
    echo "  -fa, --flash-attn      Enable Flash Attention (saves VRAM)"
    echo "  -c, --context <n>      Context size in tokens (auto-detect if omitted)"
    echo "  -ngl <n>              GPU layers (default: auto)"
    echo "  -q, --kv-quant <type>   KV cache quant: q8_0|q4_0|q4_1|fp16|q5_0|q5_1|turbo3"
    echo "  -s, --spec-type <type>  Speculative: dflash|default"
    echo "  -g, --gpu <mode>        GPU mode: auto|none"
    echo "  -p, --prompt <text>     Prompt to run (executes if provided)"
    echo "  -n, --tokens <n>        Max tokens to generate (default: 128)"
    echo "  --temp <n>              Temperature (default: 0.6)"
    echo "  --cpu                   Force CPU-only mode"
    echo "  --dry-run               Print flags without executing"
    echo "  --detect-only           Only detect and show hardware"
    echo "  --self-test            Run self-test (math, parsing, shell)"
    echo "  --report               Generate test report for GitHub issues"
    echo "  --save <path>          Save command to file"
    echo "  -v, --verbose          Verbose output"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $PROG_NAME -m ~/models/Qwen3-8B-Q4_K_M.gguf"
    echo "  $PROG_NAME -m ~/models/Qwen3-8B-Q4_K_M.gguf -p \"Explain quantum computing\""
    echo "  $PROG_NAME -m ~/models/Qwen3-8B-Q4_K_M.gguf --dry-run"
    echo "  $PROG_NAME -m ~/models/Qwen2.5-72B-Q4_K_M.gguf --cpu"
    echo "  $PROG_NAME -m ~/models/Qwen2.5-Omni-7B-Q4_K_M.gguf -t text"
    echo "  $PROG_NAME --detect-only"
    echo "  $PROG_NAME --self-test"
    echo ""
    echo "BeeLlama Divergence:"
    echo "  This script targets mainline llama.cpp. For BeeLlama fork:"
    echo "  - Different quantization options (q3_K, q4_1, etc.)"
    echo "  - Additional backends (hipSYCL, metal)"
    echo "  - Extra KV cache types (q80, turbo3_tcq)"
end

# ─── Self-Test ───
function __run_self_test
    echo "llama-autoflag v$VERSION — Self Test"
    echo "===================================="
    echo ""
    
    set -l passed 0
    set -l failed 0
    
    # Test 1: Fish math
    echo -n "Test 1: Fish math (math command)... "
    set -l result (math "5 + 3")
    if test "$result" = "8"
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL (got: $result)"
        set failed (math $failed + 1)
    end
    
    # Test 2: String manipulation
    echo -n "Test 2: String trim... "
    set -l test_str "  hello  "
    set -l result (string trim "$test_str")
    if test "$result" = "hello"
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL"
        set failed (math $failed + 1)
    end
    
    # Test 3: String split
    echo -n "Test 3: String split... "
    set -l result (string split ',' "a,b,c" | head -1)
    if test "$result" = "a"
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL"
        set failed (math $failed + 1)
    end
    
    # Test 4: Regex match
    echo -n "Test 4: Regex match (model params)... "
    set -l result (string match -r '(\d+)B' "Qwen3-8B" | tail -1)
    if test "$result" = "8B"
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL (got: $result)"
        set failed (math $failed + 1)
    end
    
    # Test 5: MoE parsing
    echo -n "Test 5: MoE active-params parsing... "
    set -l result (string match -r 'A(\d+)B' "Qwen3-30B-A3B" | string replace 'A' '')
    if test "$result" = "3B"
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL (got: $result)"
        set failed (math $failed + 1)
    end
    
    # Test 6: Model family parsing
    echo -n "Test 6: Model family parsing... "
    set -l result (parse_model_family "Llama-3.1-8B-Instruct-Q4_K_M.gguf")
    if test "$result" = "llama"
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL (got: $result)"
        set failed (math $failed + 1)
    end
    
    # Test 7: Arithmetic
    echo -n "Test 7: Float arithmetic... "
    set -l result (math "10 / 3")
    if test "$result" != "0"
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL"
        set failed (math $failed + 1)
    end
    
    # Test 8: Conditional math
    echo -n "Test 8: Conditional (test -gt)... "
    if test 5 -gt 3
        echo "✓ PASS"
        set passed (math $passed + 1)
    else
        echo "✗ FAIL"
        set failed (math $failed + 1)
    end
    
    echo ""
    echo "Results: $passed passed, $failed failed"
    
    if test $failed -eq 0
        echo "✓ All tests passed!"
        return 0
    else
        echo "✗ Some tests failed"
        return 1
    end
end

# ─── Validation ───
if test -z "$MODEL"; and test -z "$SERVER_MODELS_DIR"
    echo "❌ Error: Model path required (-m <model.gguf>) or --models-dir"
    __print_help
    exit 1
end

if test -z "$SERVER_MODELS_DIR"; and not test -f "$MODEL"
    echo "❌ Error: Model not found: $MODEL"
    exit 1
end

# ─── Hardware Detection ───
function detect_gpus
    set -l gpus
    if command -sq nvidia-smi
        # Parse nvidia-smi for GPU info
        set -l smi (nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader 2>/dev/null)
        set -l idx 0
        for line in $smi
            set -l parts (string split ',' $line)
            set -l name (string trim $parts[1])
            set -l vram (string trim $parts[2])
            set -l cc (string trim $parts[3])
            set -l vram_gb (string replace ' MiB' '' $vram | string replace ' MB' '')
            # Convert MiB to GB
            set -l vram_num (math "$vram_gb / 1024")
            echo "GPU $idx:$name:$vram_num:$cc"
            set idx (math $idx + 1)
        end
    end
end

function detect_cpu
    set -l cores (grep -c ^processor /proc/cpuinfo 2>/dev/null; or echo 0)
    set -l sockets (grep 'physical id' /proc/cpuinfo | sort -u | wc -l 2>/dev/null; or echo 1)
    set -l model_name (grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | string trim)
    echo "$model_name:$cores:$sockets"
end

function detect_ram
    set -l mem_kb (grep MemTotal /proc/meminfo | awk '{print $2}')
    set -l mem_gb (math "$mem_kb / 1048576")
    echo $mem_gb
end

function detect_numa
    if command -sq numactl
        set -l nodes (numactl --hardware 2>/dev/null | grep 'available:' | awk '{print $2}')
        echo $nodes
    else
        echo 1
    end
end

function detect_kwin
    # Check if KWin compositor is running (uses GPU memory)
    if command -sq kwin_x11
        echo 1
    else if command -sq kwin_wayland
        echo 1
    else if pgrep -x kwin > /dev/null 2>&1
        echo 1
    else
        echo 0
    end
end

function check_mlock
    set -l limit (ulimit -Hl 2>/dev/null; or echo 0)
    if test "$limit" = "unlimited"; or test $limit -gt 0
        echo 1
    else
        echo 0
    end
end

function check_rt_kernel
    # Check for PREEMPT_RT kernel using kernel config (not kernel name)
    if test -f /proc/config.gz
        if zcat /proc/config.gz 2>/dev/null | grep -q CONFIG_PREEMPT_RT=y
            echo 1
            return
        end
    end
    # Also check /boot/config-* for custom kernels
    for config in /boot/config-(uname -r)
        if test -f "$config"
            if grep -q CONFIG_PREEMPT_RT=y "$config" 2>/dev/null
                echo 1
                return
            end
        end
    end
    # Check kernel cmdline
    if cat /proc/cmdline 2>/dev/null | grep -q preempt=rt
        echo 1
    else
        echo 0
    end
end

# ─── Model Parsing ───
function parse_model_size
    set -l path $argv[1]
    set -l bytes (stat -c%s "$path" 2>/dev/null; or stat -f%z "$path" 2>/dev/null; or echo 0)
    set -l gb (math "$bytes / 1073741824")

    # Parse parameter count from filename
    set -l filename (basename "$path")
    set -l params ""
    set -l active_params ""
    set -l is_moe 0
    
    # Check for MoE pattern: e.g., "30B-A3B" means 30B total, 3B active
    if string match -rq '(\d+(?:\.\d+)?)B-A(\d+(?:\.\d+)?)B' "$filename"
        set params (string match -r '(\d+(?:\.\d+)?)B-A(\d+(?:\.\d+)?)B' "$filename" | head -1)
        set active_params (string match -r 'A(\d+(?:\.\d+)?)B' "$filename" | string replace 'A' '')
        set is_moe 1
    else if string match -rq '(\d+)B-A(\d+)B' "$filename"
        set params (string match -r '(\d+)B-A(\d+)B' "$filename" | head -1)
        set active_params (string match -r 'A(\d+)B' "$filename" | string replace 'A' '')
        set is_moe 1
    else if string match -rq '(\d+)(\.\d+)?B' "$filename"
        set params (string match -r '(\d+(?:\.\d+)?)B' "$filename" | tail -1)
    else if string match -rq '(\d+)(\.\d+)?b' "$filename"
        set params (string match -r '(\d+(?:\.\d+)?)b' "$filename" | tail -1)
        set params (string replace 'b' 'B' $params)
    end

    echo "$gb:$params:$active_params:$is_moe"
end

function parse_model_family
    # Extract model family from filename for architecture validation
    set -l filename (basename "$argv[1]")
    set -l family "unknown"
    
    if string match -rq '^[Ll]lama' "$filename"
        set family "llama"
    else if string match -rq '^[Qq]wen' "$filename"
        set family "qwen"
    else if string match -rq '^[Gg]emma' "$filename"
        set family "gemma"
    else if string match -rq '^[Mm]ini[Cc][Pp][Mm]' "$filename"
        set family "minicpm"
    else if string match -rq '^[Dd]eep[Ss]eek' "$filename"
        set family "deepseek"
    else if string match -rq '^[Pp]hi-' "$filename"
        set family "phi"
    end
    
    echo $family
end

# ─── Execute Detection ───
set -l GPU_INFO (detect_gpus)
set -l CPU_INFO (detect_cpu)
set -l RAM_GB (detect_ram)
set -l NUMA_NODES (detect_numa)
set -l MLOCK_OK (check_mlock)
set -l RT_KERNEL (check_rt_kernel)
set -l KWIN_RUNNING (detect_kwin)
set -l MODEL_FAMILY (parse_model_family "$MODEL")
set -l MODEL_INFO (parse_model_size "$MODEL")

# Parse CPU info
set -l CPU_NAME (echo $CPU_INFO | cut -d':' -f1)
set -l CPU_CORES (echo $CPU_INFO | cut -d':' -f2)
set -l CPU_SOCKETS (echo $CPU_INFO | cut -d':' -f3)

# Parse model info
set -l MODEL_GB (echo $MODEL_INFO | cut -d':' -f1)
set -l MODEL_PARAMS (echo $MODEL_INFO | cut -d':' -f2)
set -l ACTIVE_PARAMS (echo $MODEL_INFO | cut -d':' -f3)
set -l IS_MOE (echo $MODEL_INFO | cut -d':' -f4)

# Use active params for MoE models, otherwise total params
if test "$IS_MOE" = "1"; and test -n "$ACTIVE_PARAMS"
    set -l EFFECTIVE_PARAMS $ACTIVE_PARAMS
    set -l PARAMS_DISPLAY "$MODEL_PARAMS (MoE: $ACTIVE_PARAMS active)"
else
    set -l EFFECTIVE_PARAMS $MODEL_PARAMS
    set -l PARAMS_DISPLAY "$MODEL_PARAMS"
end

# Parse GPU info
set -l GPU_COUNT (count $GPU_INFO)
set -l TOTAL_VRAM 0
set -l GPU_NAMES
set -l GPU_VRAMS
set -l GPU_CCS

for g in $GPU_INFO
    set -l parts (string split ':' $g)
    set -l idx $parts[1]
    set -l name $parts[2]
    set -l vram $parts[3]
    set -l cc $parts[4]
    set -a GPU_NAMES $name
    set -a GPU_VRAMS $vram
    set -a GPU_CCS $cc
    set TOTAL_VRAM (math "$TOTAL_VRAM + $vram")
end

# ─── Decision Logic ───

# GPU layers

set -l TS ""
set -l ENV_VARS ""
set -l EXTRA_FLAGS
set -l SAFETY_NOTICES ""
set -l CPU_FALLBACK 0

# Check for Qwen2vl/Omni model GPU corruption bug (upstream bug #15923)
# The bug affects GPU mode for omni/audio - NOT Volta-specific
set -l QWEN2VL_BUG 0
if test "$INF_TYPE" = "omni"; or test "$INF_TYPE" = "audio"
    if test $GPU_COUNT -gt 0; and test "$GPU_MODE" != "none"
        set QWEN2VL_BUG 1
        set SAFETY_NOTICES "$SAFETY_NOTICES ⚠ GPU offload BLOCKED — upstream bug #15923 (qwen2vl GPU corruption)"
        set CPU_FALLBACK 1
    end
end

# Calculate usable VRAM (accounting for KWin compositor overhead if detected)
set -l USABLE_VRAM $TOTAL_VRAM
set -l VRAM_OVERHEAD 0
if test $KWIN_RUNNING -eq 1; and test $GPU_COUNT -gt 1
    # KWin uses ~1-2GB on GPU 1
    set VRAM_OVERHEAD 2
    set USABLE_VRAM (math "$TOTAL_VRAM - $VRAM_OVERHEAD")
    set SAFETY_NOTICES "$SAFETY_NOTICES ℹ KWin compositor detected — VRAM overhead: $VRAM_OVERHEAD GB"
end

# VRAM threshold buffer: model > usable-4GB triggers CPU fallback
# This prevents OOM during KV cache allocation
set -l VRAM_THRESHOLD (math "$USABLE_VRAM - 4")
if test $MODEL_GB -gt $VRAM_THRESHOLD; and test "$GPU_MODE" = "auto"
    set CPU_FALLBACK 1
    set SAFETY_NOTICES "$SAFETY_NOTICES ⚠ Model size ($MODEL_GB GB) exceeds GPU safe threshold ($VRAM_THRESHOLD GB = $USABLE_VRAMGB usable - 4GB context)"
end

echo "DEBUG-CHECK: should_calc=$should_calc_n_gl NGL=$NGL NGL_USER_SET=$NGL_USER_SET CPU_FALLBACK=$CPU_FALLBACK GPU_COUNT=$GPU_COUNT GPU_MODE=$GPU_MODE"
# Determine NGL based on model size vs VRAM
set -l should_calc_n_gl 0
if test $NGL_USER_SET -eq 1
    set should_calc_n_gl 1
else if test $CPU_FALLBACK -eq 0
    if test $GPU_COUNT -gt 0
        if test "$GPU_MODE" != "none"
            set should_calc_n_gl 1
        end
    end
end

if test $should_calc_n_gl -eq 1
    # Use EFFECTIVE_PARAMS for MoE (active params), otherwise MODEL_PARAMS
    # Defensive: handle empty params
    set -l params_num 0
    if test -n "$EFFECTIVE_PARAMS"
        set -l tmp (echo "$EFFECTIVE_PARAMS" | tr -d 'B')
        if test -n "$tmp"
            set params_num $tmp
        end
    else if test -n "$MODEL_PARAMS"
        set -l tmp (echo "$MODEL_PARAMS" | tr -d 'B')
        if test -n "$tmp"
            set params_num $tmp
        end
    end
    
    echo "DEBUG-AFTER-SKIP: NGL=$NGL"
# Skip auto-NGL if user specified -ngl on command line
    if test $NGL_USER_SET -eq 1
        echo "   [User specified -ngl $NGL, skipping auto-calculation]"
    else if test $params_num -gt 0
        # Estimate layer size: model GB / typical layer count
        set -l est_layers 32
        if test $params_num -ge 70
            set est_layers 80
        else if test $params_num -ge 27
            set est_layers 64
        else if test $params_num -ge 14
            set est_layers 48
        else if test $params_num -ge 8
            set est_layers 32
        end
        set -l vram_per_layer (math "$MODEL_GB / $est_layers")
        set -l max_layers (math "floor($USABLE_VRAM / $vram_per_layer)")

        if test $max_layers -ge 99
            echo "DEBUG-SET-99: NGL=$NGL"
set NGL 99
        else
            set NGL $max_layers
        end
    else
        # Fallback: if model < 80% of VRAM, full offload
        set -l ratio (math "$MODEL_GB / $TOTAL_VRAM")
        if test $ratio -lt 0.8
            echo "DEBUG-SET-99: NGL=$NGL"
set NGL 99
        else
            set NGL (math "floor(99 * (1 - $ratio) + 10)")
            if test $NGL -lt 10
                set NGL 10
            end
        end
    end
end

# Tensor split: asymmetric when KWin compositor detected
if test $GPU_COUNT -eq 2; and test $NGL -gt 0
    if test $KWIN_RUNNING -eq 1
        # Give more VRAM to GPU 0 (where KWin doesn't run)
        echo "DEBUG-AFTER-TS: NGL=$NGL"
set TS "0.55,0.45"
        set SAFETY_NOTICES "$SAFETY_NOTICES ℹ Tensor split: 0.55,0.45 (KWin detected on GPU 1)"
    else
        set TS "0.5,0.5"
    end
    set -a ENV_VARS "GGML_CUDA_DISABLE_GRAPHS=1"
    set -a ENV_VARS "CUDA_MODULE_LOADING=LAZY"
else if test $GPU_COUNT -gt 2
    set -l ts_str ""
    set -l ts_val (math "1.0 / $GPU_COUNT")
    for i in (seq 1 $GPU_COUNT)
        if test -n "$ts_str"
            set ts_str "$ts_str,$ts_val"
        else
            set ts_str "$ts_val"
        end
    end
    set TS $ts_str
end

# CUDA graphs: 40-50% throughput penalty on dual Volta, documented
if test $GPU_COUNT -eq 2
    set SAFETY_NOTICES "$SAFETY_NOTICES ℹ CUDA graphs disabled — 40-50%% throughput penalty on dual Volta"
end

# Context size
set -l CTX $CONTEXT
if test $CTX -eq 0
    if test "$INF_TYPE" = "api"
        set CTX 32768
    else if test "$INF_TYPE" = "batch"
        set CTX 65536
    else if test "$INF_TYPE" = "vision"; or test "$INF_TYPE" = "omni"
        set CTX 8192
    else
        # Text: balance RAM and model size
        set CTX 131072
        if test $MODEL_GB -gt 40
            set CTX 65536
        else if test $MODEL_GB -lt 10
            set CTX 32768
        end
    end
end

# Threads
set -l THREADS (math "floor($CPU_CORES / 2)")
if test $THREADS -lt 1
    set THREADS 1
end

# KV Quant - 3-tier TurboQuant safety
set -l CACHE_TYPE_K "f16"
set -l CACHE_TYPE_V "f16"
if test -n "$KV_QUANT"
    set CACHE_TYPE_K $KV_QUANT
    set CACHE_TYPE_V $KV_QUANT
else
    # Use EFFECTIVE_PARAMS for MoE
    # Defensive: handle empty params
    set -l params_num 0
    if test -n "$EFFECTIVE_PARAMS"
        set -l tmp (echo "$EFFECTIVE_PARAMS" | tr -d 'B')
        if test -n "$tmp"
            set params_num $tmp
        end
    else if test -n "$MODEL_PARAMS"
        set -l tmp (echo "$MODEL_PARAMS" | tr -d 'B')
        if test -n "$tmp"
            set params_num $tmp
        end
    end
    
    # 3-tier TurboQuant safety
    if test $params_num -lt 10
        # Tier 1: <10B models - block turbo3, use q8_0
        set CACHE_TYPE_K "q8_0"
        set CACHE_TYPE_V "q8_0"
        set SAFETY_NOTICES "$SAFETY_NOTICES ℹ KV cache: q8_0 (turbo3 blocked: $params_num B < 10B threshold)"
    else if test $params_num -lt 27
        # Tier 2: 10-27B models - use asymmetric (q8_0_k, q4_0_v)
        # Asymmetric provides better quality than pure q4 with minimal VRAM savings
        set CACHE_TYPE_K "q8_0"
        set CACHE_TYPE_V "q4_0"
        set SAFETY_NOTICES "$SAFETY_NOTICES ℹ KV cache: asymmetric (q8_0_k, q4_0_v) for $params_num B model"
    else
        # Tier 3: >=27B models - allow turbo3
        if test "$INF_TYPE" = "api"; or test $CTX -gt 65536
            set CACHE_TYPE_K "q8_0"
            set CACHE_TYPE_V "q8_0"
        else
            set CACHE_TYPE_K "turbo3"
            set CACHE_TYPE_V "turbo3"
            set SAFETY_NOTICES "$SAFETY_NOTICES ℹ KV cache: turbo3 (allowed: $params_num B >= 27B threshold)"
        end
    end
end

# mmap / mlock - fixed detection using kernel config
set -l NO_MMAP ""
set -l MLOCK ""
if test $MODEL_GB -gt 20
    set NO_MMAP "--no-mmap"
end

if test $MLOCK_OK -eq 1; and test $RT_KERNEL -eq 0
    set MLOCK "--mlock"
    set SAFETY_NOTICES "$SAFETY_NOTICES ℹ mlock: enabled (CachyOS non-PREEMPT_RT)"
else if test $RT_KERNEL -eq 1
    set SAFETY_NOTICES "$SAFETY_NOTICES ℹ mlock: disabled (PREEMPT_RT kernel detected)"
end

# NUMA - CPU-only mode for large models (>15GB model OR GPU unavailable)
set -l NUMA_CMD ""
set -l NUMA_FLAG ""
if test $NUMA_NODES -gt 1
    set -l is_cpu_fallback 0
    if test $NGL -eq 0
        set is_cpu_fallback 1
    else if test $CPU_FALLBACK -eq 1
        set is_cpu_fallback 1
    end
    if test $is_cpu_fallback -eq 1; and test $NGL_USER_SET -eq 0
        # CPU-only mode with NUMA distribute for better memory locality
        set NUMA_FLAG "--numa distribute"
        set SAFETY_NOTICES "$SAFETY_NOTICES ℹ NUMA: distribute (CPU-only mode, dual-socket detected)"
    else if test $MODEL_GB -gt 20; and test $GPU_COUNT -gt 0
        # GPU present but large model - use isolate
        set NUMA_FLAG "--numa isolate"
    end
end

# Batch sizes
set -l BATCH 512
set -l UBATCH 512
if test "$INF_TYPE" = "vision"; or test "$INF_TYPE" = "omni"
    set BATCH 256
    set UBATCH 256
end

# Speculative decode with validation
set -l SPEC_FLAGS ""
set -l NGLD ""
set -l DRAFT_FAMILY ""
set -l DRAFT_ERROR ""

if test -n "$DRAFT_MODEL"
    # Parse draft family
    set DRAFT_FAMILY (parse_model_family "$DRAFT_MODEL")
    
    # Validate architecture match
    if test "$MODEL_FAMILY" != "$DRAFT_FAMILY"
        set DRAFT_ERROR "ERROR: Draft architecture ($DRAFT_FAMILY) incompatible with target ($MODEL_FAMILY)"
        set DRAFT_ERROR "$DRAFT_ERROR\\nSpeculative decoding requires identical tokenizer vocabulary."
        set DRAFT_ERROR "$DRAFT_ERROR\\nAborting. Use --force-draft to override (not recommended)."
        set SAFETY_NOTICES "$SAFETY_NOTICES ✗ $DRAFT_ERROR"
    else
        # Validate ratio (optimal: 2-8x)
        if test -n "$MODEL_PARAMS"; and test -n "$EFFECTIVE_PARAMS"
            set -l target_params (echo $EFFECTIVE_PARAMS | tr -d 'B')
            set -l draft_params (echo $MODEL_PARAMS | tr -d 'B')
            if test $target_params -gt 0; and test $draft_params -gt 0
                set -l ratio (math "$target_params / $draft_params")
                if test $ratio -lt 2; or test $ratio -gt 8
                    set SAFETY_NOTICES "$SAFETY_NOTICES ⚠ Draft/target ratio: $ratiox (optimal: 2-8x)"
                end
            end
        end
        
        if test -n "$SPEC_TYPE"
            set SPEC_FLAGS "--spec-type $SPEC_TYPE"
        else
            set SPEC_FLAGS "--spec-type dflash"
        end
        set SPEC_FLAGS "$SPEC_FLAGS --model-draft \"$DRAFT_MODEL\" --draft-max 15 --draft-min 1"
        set NGLD "-ngld 99"
        set SAFETY_NOTICES "$SAFETY_NOTICES ✓ Architecture match: $MODEL_FAMILY -> $DRAFT_FAMILY"
    end
end

# Binary selection (skip if already set via --dir)
if test -z "$LLAMA_DIR"
    set -l LLAMA_DIR "./build"
end
set -l LLAMA_BIN "$LLAMA_DIR/build/bin/llama-cli"
if test "$INF_TYPE" = "api"; or test -n "$SERVER_MODELS_DIR"
    set LLAMA_BIN "$LLAMA_DIR/build/bin/llama-server"
end

# ─── Build Command ───
set -l CMD "$LLAMA_BIN"
set -l FLAGS ""

# Add model flag for CLI (not server mode)
if test -z "$SERVER_MODELS_DIR"
    set FLAGS "-m \"$MODEL\""
end

if test $NGL -gt 0
    set FLAGS "$FLAGS -ngl $NGL"
end

if test -n "$TS"
    set FLAGS "$FLAGS -ts $TS"
end

if test -n "$CACHE_TYPE_K"
    set FLAGS "$FLAGS --cache-type-k $CACHE_TYPE_K --cache-type-v $CACHE_TYPE_V"
end

set FLAGS "$FLAGS -c $CTX -t $THREADS"

if test -n "$FLASH_ATTN"
    set FLAGS "$FLAGS -fa"
end

if test -n "$NO_MMAP"
    set FLAGS "$FLAGS $NO_MMAP"
end

if test -n "$MLOCK"
    set FLAGS "$FLAGS $MLOCK"
end

if test -n "$NUMA_FLAG"
    set FLAGS "$FLAGS $NUMA_FLAG"
end

if test -n "$SPEC_FLAGS"
    set FLAGS "$FLAGS $SPEC_FLAGS"
end

if test -n "$NGLD"
    set FLAGS "$FLAGS $NGLD"
end

if test "$INF_TYPE" = "api"; or test -n "$SERVER_MODELS_DIR"
    set FLAGS "$FLAGS --parallel 4 -b $BATCH -ub $UBATCH --host 0.0.0.0 --port $SERVER_PORT"
    if test -n "$SERVER_MODELS_DIR"
        set FLAGS "$FLAGS --models-dir $SERVER_MODELS_DIR"
    end
    if test "$SPLIT_MODE" = "row"
        set FLAGS "$FLAGS -sm row"
    end
else
    set FLAGS "$FLAGS -b $BATCH -ub $UBATCH"
end

# ─── Output ───

# Handle --self-test
if test $SELF_TEST -eq 1
    __run_self_test
    exit 0
end

# Handle --detect-only
if test $DETECT_ONLY -eq 1
    echo "llama-autoflag v$VERSION — Hardware Detection"
    echo "============================================"
    echo ""
    echo "CPU: $CPU_NAME, $CPU_CORES cores, $CPU_SOCKETS socket(s)"
    echo "RAM: $RAM_GB GB"
    echo "NUMA: $NUMA_NODES node(s)"
    echo "KWin: $KWIN_RUNNING (0=no, 1=yes)"
    echo "mlock: $MLOCK_OK"
    echo "RT kernel: $RT_KERNEL"
    echo ""
    echo "GPUs ($GPU_COUNT):"
    set -l idx 0
    for name in $GPU_NAMES
        set -l vram $GPU_VRAMS[(math $idx + 1)]
        set -l cc $GPU_CCS[(math $idx + 1)]
        echo "  GPU $idx: $name | $vram GB VRAM | sm_$cc"
        set idx (math $idx + 1)
    end
    if test $GPU_COUNT -eq 0
        echo "  (none detected)"
    end
    exit 0
end

# Main output
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           🎯 LLAMA AUTOFLAG SELECTOR v$VERSION                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 SYSTEM DETECTED"
echo "─────────────────────────────────────────────────────────────"
echo "🖥️  CPU: $CPU_NAME, $CPU_CORES cores, $CPU_SOCKETS socket(s)"
echo "💾 RAM: $RAM_GB GB total"
echo "🌐 NUMA: $NUMA_NODES node(s)"
if test $KWIN_RUNNING -eq 1
    echo "🪟 Compositor: KWin ($VRAM_OVERHEAD GB VRAM overhead)"
end
if test $RT_KERNEL -eq 1
    echo "⚡ Kernel: PREEMPT_RT detected (--mlock disabled)"
else
    echo "⚡ Kernel: CachyOS (non-RT, --mlock available)"
end
echo "🎮 GPUs:"
set -l idx 0
for name in $GPU_NAMES
    set -l vram $GPU_VRAMS[(math $idx + 1)]
    set -l cc $GPU_CCS[(math $idx + 1)]
    set -l arch ""
    if string match -q "7.0" "$cc"
        set arch "✅ Volta"
    end
    echo "   GPU $idx: $name | $vram GB VRAM | sm_$cc $arch"
    set idx (math $idx + 1)
end
if test $GPU_COUNT -eq 0
    echo "   (none detected — CPU-only mode)"
end

echo ""
echo "📦 MODEL"
echo "─────────────────────────────────────────────────────────────"
echo "   Path: $MODEL"
echo "   Size: $MODEL_GB GB"
if test -n "$PARAMS_DISPLAY"
    echo "   Params: $PARAMS_DISPLAY"
end
if test "$IS_MOE" = "1"
    echo "   Type: MoE (using active params for safety)"
end

# Safety notices
if test -n "$SAFETY_NOTICES"
    echo ""
    echo "⚠️  SAFETY NOTICES"
    echo "─────────────────────────────────────────────────────────────"
    echo "$SAFETY_NOTICES"
end

echo ""
echo "⚙️  INFERENCE CONFIG"
echo "─────────────────────────────────────────────────────────────"
echo "   Type: $INF_TYPE"
echo "   GPUs: $GPU_COUNT (VRAM: $TOTAL_VRAM GB total, $USABLE_VRAM GB usable)"
if test $NGL -gt 0
echo "DEBUG: NGL=$NGL NGL_USER_SET=$NGL_USER_SET CPU_FALLBACK=$CPU_FALLBACK"
    echo "   GPU Layers: $NGL/99"
else
    echo "   GPU Layers: 0 (CPU only)"
end
echo "   Context: $CTX tokens"
echo "   KV Quant: $CACHE_TYPE_K"
if test "$CACHE_TYPE_K" != "$CACHE_TYPE_V"
    echo "              (asymmetric: $CACHE_TYPE_V for values)"
end
echo "   Threads: $THREADS"
if test -n "$TS"
    echo "   Tensor Split: $TS"
end
if test -n "$SPEC_TYPE"
    echo "   Speculative: $SPEC_TYPE"
else if test -n "$DRAFT_MODEL"
    echo "   Speculative: dflash (default)"
end

echo ""
echo "🎯 RECOMMENDED FLAGS"
echo "─────────────────────────────────────────────────────────────"
echo "   $FLAGS"

echo ""
echo "💡 Rationale:"
set -l RATIONALE ""
if test $NUMA_NODES -gt 1
    set RATIONALE "$RATIONALE NUMA-bound to socket 0 for GPU0 affinity."
end
if test $GPU_COUNT -eq 2
    set RATIONALE "$RATIONALE Layer-split across 2 GPUs."
end
if test -n "$KV_QUANT"
    set RATIONALE "$RATIONALE KV cache compressed with $KV_QUANT."
end
if test -n "$NO_MMAP"
    set RATIONALE "$RATIONALE --no-mmap forces full RAM preload."
end
if test -n "$MLOCK"
    set RATIONALE "$RATIONALE --mlock prevents OS swapping."
end
if test $GPU_COUNT -eq 2
    set RATIONALE "$RATIONALE CUDA graphs disabled for dual-GPU stability."
end
if test -n "$NUMA_FLAG"
    set RATIONALE "$RATIONALE NUMA isolation for large model memory locality."
end
if test -n "$DRAFT_MODEL"
    set RATIONALE "$RATIONALE DFlash speculative decode active."
end
if test $RT_KERNEL -eq 1
    set RATIONALE "$RATIONALE RT kernel detected; mlock skipped."
end
echo "   $RATIONALE"

# Build full command with env
set -l ENV_STR ""
for e in $ENV_VARS
    if test -n "$ENV_STR"
        set ENV_STR "$ENV_STR $e"
    else
        set ENV_STR "$e"
    end
end

set -l FULL_CMD "$ENV_STR $NUMA_CMD $CMD $FLAGS"
# Clean up extra spaces
set FULL_CMD (string replace -r ' +' ' ' "$FULL_CMD")
set FULL_CMD (string trim "$FULL_CMD")

echo ""
echo "🚀 COMMAND:"
echo "─────────────────────────────────────────────────────────────"
echo "   $FULL_CMD"

# ─── Execute or Save ───
if test $DRY_RUN -eq 1
    echo ""
    echo "🏜️  DRY RUN — command not executed"
    exit 0
end

if test -n "$SAVE_PATH"
    echo "#!/usr/bin/env fish" > "$SAVE_PATH"
    echo "$FULL_CMD" >> "$SAVE_PATH"
    chmod +x "$SAVE_PATH"
    echo ""
    echo "💾 Saved to: $SAVE_PATH"
    exit 0
end

# Execute
echo ""
echo "▶️  Running..."
echo ""

# Add prompt and temperature if provided
if test -n "$PROMPT"
    set FULL_CMD "$FULL_CMD --temp $TEMP -p \"$PROMPT\" -n $NUM_TOKENS"
end

# Clean up extra spaces
set FULL_CMD (string replace -r ' +' ' ' "$FULL_CMD")
set FULL_CMD (string trim "$FULL_CMD")

echo "Command prepared:"
echo ""
echo "   $FULL_CMD"
echo ""

# Actually execute
echo "[autoflag] Executing..."
eval $FULL_CMD
