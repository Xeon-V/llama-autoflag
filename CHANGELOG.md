# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - 2025-05-17

### Fixed
- **-ngl manual override**: User-specified GPU layers now properly preserved
- Variable scope issue: Declare NGL at file top before arg parsing

### Added
- `-ngl <n>` option to README documentation
- Test script: test-ngl.sh

### Purpose
Auto-detect hardware and generate optimal llama.cpp flags, with manual override when needed. Saves 5-10 min per test session.

---

## [1.2.0] - 2025-05-16

### Added
- Dual GPU tensor split (0.55/0.45)
- KWin compositor VRAM overhead detection
- CUDA graphs auto-disable for dual-GPU stability

---

## [1.1.0] - 2025-05-15

### Added
- KV cache quantization (q8_0, turbo3)
- NUMA support
- MoE model active params parsing

---

## [1.0.0] - 2025-05-14

### Added
- Initial release
- Auto GPU layer calculation
- Hardware detection
