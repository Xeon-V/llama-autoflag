#!/bin/bash
# Test -ngl override

echo "Testing -ngl 55 override..."
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf --dir ~/llama-bee -c 4096 -fa -ngl 55 -q q8_0 --dry-run

echo ""
echo "Testing without -ngl (auto)..."
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf --dir ~/llama-bee -c 4096 -fa -q q8_0 --dry-run

echo ""
echo "Testing -ngl 99..."
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf --dir ~/llama-bee -c 4096 -fa -ngl 99 -q q8_0 --dry-run
