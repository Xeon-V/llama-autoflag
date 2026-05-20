#!/bin/bash
set -e
PASS=0; FAIL=0
extract(){ echo "$1"|grep -oE "[0-9]+B"|head -1|tr -d "B";}
detect(){ f=$(echo "$1"|tr "[:upper:]" "[:lower:]"); [[ "$f" =~ ^qwen ]]&&echo qwen||{ [[ "$f" =~ ^deep ]]&&echo deepseek||echo unknown; };}
calc_ngl(){ p=$1; [ "$p" -le 1 ]&&echo 20||[ "$p" -le 3 ]&&echo 25||[ "$p" -le 8 ]&&echo 37||[ "$p" -le 20 ]&&echo 45||echo 35; }
[ "$(extract Qwen3-8B.gguf)" = "8" ]&&echo "  PASS: Param"||echo "  FAIL: Param"
[ "$(detect Qwen3-8B.gguf)" = "qwen" ]&&echo "  PASS: Family"||echo "  FAIL: Family"  
[ "$(calc_ngl 8)" = "37" ]&&echo "  PASS: NGL"||echo "  FAIL: NGL"
echo "Done"
