# llama-autoflag v1.3.0 - Release Notes

## Why We Made This

**Problem**: Every time we wanted to test different GPU layer configurations (-ngl values), we had to manually calculate VRAM vs model size and edit command lines. This takes time and is error-prone.

**Solution**: Auto-detect hardware, calculate optimal settings, BUT allow manual override when needed.

This script saves **~5-10 minutes per test session** by eliminating manual flag calculation.

---

## What's New in v1.3.0

### Fixed: -ngl Manual Override

- **Before**: `-ngl 55` was being ignored, always reset to 0
- **After**: `-ngl <value>` is now properly preserved
- Works with: Large models (18GB+) where manual tuning is needed

### How to Use

```bash
# Test different -ngl values quickly
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-32B-Q4_K_M.gguf -ngl 55 --dry-run
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-32B-Q4_K_M.gguf -ngl 75 --dry-run
fish ./llama-autoflag.fish -m ~/models/DeepSeek-R1-32B-Q4_K_M.gguf -ngl 99 --dry-run
```

---

## Testing Status

🧪 **Testing in Progress** - Please report issues: https://github.com/Xeon-V/llama-autoflag/issues

---

## Quick Compare

| Approach | Time per test | Manual work |
|----------|--------------|-------------|
| Manual flags | 5-10 min | Calculate VRAM, write full command |
| llama-autoflag | 10 sec | Run with -ngl value |

---

## Thanks

Created to speed up iterative testing on dual NVIDIA TITAN V setup.

---
