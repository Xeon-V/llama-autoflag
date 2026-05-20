#!/bin/bash
extract(){ echo "$1"|grep -oE "[0-9]+B"|head -1|tr -d "B";}
detect(){ f=$(echo "$1"|tr "[:upper:]" "[:lower:]"); [[ "$f" =~ ^qwen ]]&&echo qwen||{ [[ "$f" =~ ^deep ]]&&echo deepseek||echo unknown; };}
calc_ngl(){ p=$1; if [ $p -le 1 ];then echo 20;elif [ $p -le 3 ];then echo 25;elif [ $p -le 8 ];then echo 37;elif [ $p -le 20 ];then echo 45;else echo 35;fi; }
[ "$(extract Qwen3-8B.gguf)" = "8" ]&&echo "  PASS: Param"||echo "  FAIL: Param"
[ "$(detect Qwen3-8B.gguf)" = "qwen" ]&&echo "  PASS: Family"||echo "  FAIL: Family"  
[ "$(calc_ngl 8)" = "37" ]&&echo "  PASS: NGL"||echo "  FAIL: NGL"
echo "Tests done!"
