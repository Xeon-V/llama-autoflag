#!/usr/bin/env fish
# llama-autoflag.fish v3.0.1-ik - Optimized for ik_llama.cpp

set -l MODEL ""
set -l RUN_MODE 0
set -l DRY_RUN 0
set -l DETECT_ONLY 0

# Parse args
for i in (seq 1 (count $argv))
    switch $argv[$i]
        case '-m' '--model'
            set MODEL $argv[(math $i + 1)]
        case '--run'
            set RUN_MODE 1
        case '--dry-run'
            set DRY_RUN 1
        case '--detect-only'
            set DETECT_ONLY 1
    end
end

if test -z "$MODEL"
    echo "Usage: $PROG_NAME -m <model.gguf> [--run|--dry-run|--detect-only]"
    exit 1
end

# Get GPU info
set gpu_count (nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -1 | string trim)
test -z "$gpu_count"; and set gpu_count 0
set cpu_cores (nproc 2>/dev/null | head -1 | string trim)
test -z "$cpu_cores"; and set cpu_cores 4

# Parse model
set filename (basename "$MODEL")
set params ""
string match -rq '(\d+)B' "$filename"; and set params (string match -r '(\d+)B' "$filename" | tail -1)

# Decision
set NGL 0
if test $gpu_count -gt 0
    set params_num (echo "$params" | tr -d 'B')
    if test -n "$params_num"
        if test $params_num -le 8; set NGL 37
        else if test $params_num -le 20; set NGL 64
        else; set NGL 80; end
    else; set NGL 37; end
end

set SPLIT ""
test $gpu_count -ge 2; and set SPLIT "-sm graph"

set CTX 8192
set family "unknown"
string match -rq '^[Qq]wen' "$filename"; and set family "qwen"
string match -rq '^[Dd]eep' "$filename"; and set family "deepseek"

test "$family" = "deepseek"; and set CTX 16384

set THREADS (math "$cpu_cores / 2")
test $THREADS -lt 1; and set THREADS 1

# Build flags
set FLAGS "-m $MODEL -ngl $NGL $SPLIT -ctk f16 -ctv f16 -fa on -c $CTX -t $THREADS -gr -muge 0 -b 512 -ub 512"

# Output
if test $DETECT_ONLY -eq 1
    echo "GPU: $gpu_count | CPU: $cpu_cores cores"
    exit 0
end

echo "NGL: $NGL | Context: $CTX | Threads: $THREADS"
echo "Flags: $FLAGS"

if test $DRY_RUN -eq 1
    echo "[DRY RUN]"
    exit 0
end

if test $RUN_MODE -eq 1
    echo "$FLAGS"
end
