# 1. OBJECTIVE

**Goal:** Establish a proven reference stack (upstream llama.cpp router mode + Open WebUI) and use it to validate and improve the BeeLlama/llama-autoflag project's router-mode functionality.

The user has existing BeeLlama development (Fish script + Python detector) that needs to be validated against a known-good upstream reference stack before updating/enhancing the fork. This approach:
1. Decouples problems (router issues vs UI issues)
2. Provides a golden client (Open WebUI) for verifying correct router behavior
3. Establishes a clean baseline before rebasing BeeLlama onto current upstream

---

# 2. CONTEXT SUMMARY

**Project:** `llama-autoflag` — Auto-detect hardware and generate optimal llama.cpp flags
- **Main files:** `llama-autoflag.fish` (v1.4.0), `llama-autoflag-detect.py`
- **Hardware context:** Dual NVIDIA TITAN V (sm_70), 128GB RAM, 28-core Xeon
- **Current mode:** Supports both CLI inference and server mode (`--models-dir`, `--port`)

**Key features already implemented:**
- Hardware detection (GPU VRAM, compute capability, NUMA, KWin compositor)
- Auto GPU layer calculation (-ngl) with manual override
- KV cache quantization (q8_0, q4_0, turbo3)
- Dual-GPU tensor split support
- `--detect-running` mode to query running router

**What's needed:**
- Router mode validation against upstream llama.cpp + Open WebUI reference stack
- This will become the "golden reference" for verifying BeeLlama's router behavior

---

# 3. APPROACH OVERVIEW

**Strategy:** Build a reference stack in phases to validate/fix router behavior before modifying BeeLlama:

| Phase | Component | Purpose |
|-------|-----------|---------|
| 1 | Upstream llama.cpp (latest) | Canonical router backend |
| 2 | Open WebUI | Golden client for UI/API testing |
| 3 | Integration test | Validate `/models`, `/v1/models`, model switching |
| 4 (optional) | BeeLlama rebase | Update fork or strip to config layer |

**Why this order:**
1. Upstream first → get known-good router API behavior
2. Open WebUI first → decouples UI bugs from router bugs
3. Then validate BeeLlama's router handling
4. Avoids "phantom bugs" from mixing fork changes with router issues

---

# 4. IMPLEMENTATION STEPS

## Phase 1: Set Up Upstream llama.cpp Router

### Step 1.1 — Clone and build upstream llama.cpp
- **Goal:** Get current upstream llama.cpp with router mode support
- **Method:** 
  ```bash
  git clone https://github.com/ggml-org/llama.cpp.git ~/llama-upstream
  cd ~/llama-upstream
  git pull  # get latest
  cmake -B build -DGGML_CUDA=on ...
  cmake --build build -j$(nproc)
  ```
- **Reference:** Build uses similar flags to existing BeeLlama (CUDA, etc.)

### Step 1.2 — Run llama-server in router mode
- **Goal:** Establish canonical router backend on local port
- **Method:**
  ```bash
  cd ~/llama-upstream
  ./build/bin/llama-server \
    --models-dir ~/models \
    --port 10000
  ```
- **Note:** Models directory should contain GGUF files for testing

### Step 1.3 — Verify router API endpoints
- **Goal:** Confirm `/models` and `/v1/models` work correctly
- **Method:**
  ```bash
  curl http://localhost:10000/models
  curl http://localhost:10000/v1/models
  ```
- **Expected:** JSON with model list, status fields

---

## Phase 2: Set Up Open WebUI

### Step 2.1 — Run Open WebUI (Docker or bare metal)
- **Goal:** Establish UI frontend for router testing
- **Method (Docker):**
  ```bash
  docker run -d -p:3000:8080 \
    -v open-webui:/app/backend/data \
    --add-host=host.docker.internal:host-gateway \
    -e OLLAMA_BASE_URL=http://host.docker.internal:10000/v1 \
    -e OLLAMA_MODELS=/models \
    --name open-webui \
    openwebui/open-webui:main
  ```
- **Reference:** Docs: docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-llama-cpp/

### Step 2.2 — Configure llama.cpp provider in Open WebUI
- **Goal:** Connect Open WebUI to upstream router
- **Open WebUI Admin → Settings → Add Provider:**
  - URL: `http://127.0.0.1:10000/v1`
  - Provider: `llama.cpp`

### Step 2.3 — Validate model list and switching
- **Goal:** Confirm models show in dropdown and can be switched
- **Method:**
  1. Verify model dropdown shows available models
  2. Send test prompt with one model
  3. Switch to different model, send same prompt
  4. Verify `/models` endpoint reflects changes

---

## Phase 3: Integration Testing (Golden Reference)

### Step 3.1 — Test `/models` endpoint behavior
- **Goal:** Map expected router API behavior
- **Method:**
  ```bash
  # Load a model via API
  curl -X POST http://localhost:10000/models/load \
    -H "Content-Type: application/json" \
    -d '{"model": "model-name.gguf"}'
  
  # Check status
  curl http://localhost:10000/models
  ```
- **Document findings:** Model states ( unloaded, loading, loaded, error)

### Step 3.2 — Document model selector behavior
- **Goal:** Understand how Open WebUI expects models to be listed
- **Method:** 
  - Compare `/models` vs `/v1/models` responses
  - Note `model` field semantics in chat completions
  - Document load/unload lifecycle

### Step 3.3 — Compare against BeeLlama behavior
- **Goal:** Identify gaps between BeeLlama router handling and upstream
- **Method:**
  1. Run same tests against BeeLlama's server mode
  2. Note differences in:
     - Endpoint responses
     - Model state handling
     - Error messages

---

## Phase 4 (Optional): Update BeeLlama

### Step 4.1 — Decide on BeeLlama's future
- **Goal:** Determine whether to rebase, strip, or retire custom UI
- **Options to evaluate:**
  - Rebase onto current upstream and keep as fork
  - Strip to config/preset layer only (delegate UI to Open WebUI)
  - Keep minimal UI layer over validated router endpoints

### Step 4.2 — If rebasing: sync with upstream router API
- **Goal:** Align BeeLlama's router handling with current upstream
- **Method:**
  - Update flag handling for new model management API
  - Adapt `--models-dir` behavior
  - Handle `/models/load` and `/models/unload`

### Step 4.3 — If stripping: convert to launcher
- **Goal:** Simplify BeeLlama to just config + docker-compose
- **Method:**
  - Output only starts `llama-server` + `open-webui`
  - Remove built-in UI code entirely
  - Keep auto-flag generation logic

---

# 5. TESTING AND VALIDATION

**Phase 1-2 validation checklist:**

| Test | Expected Result |
|------|--------------|
| `curl localhost:10000/models` | Returns JSON with model list |
| `curl localhost:10000/v1/models` | Returns OpenAI-compatible model list |
| Open WebUI dropdown | Shows all available GGUF models |
| Chat with model A | Works, model loaded |
| Switch to model B | Previous unloads, new loads |
| `curl localhost:10000/models` status | Reflects correct loaded/unloaded state |

**Phase 3 validation:**

| Test | Method | Success Condition |
|------|--------|-------------------|
| Model state transitions | Load/unload via API | Status changes correctly |
| Concurrent requests | Multiple chatters | No state corruption |
| Memory cleanup | Load/unload cycles | VRAM freed properly |

**Phase 4 (if implemented):**

| Test | Method | Success Condition |
|------|--------|-------------------|
| BeeLlama vs upstream parity | Run same test suite | Similar behavior |
| Model switching in BeeLlama UI | Use built-in UI | Works like Open WebUI |

**Success criteria:** 
- Upstream llama-server + Open WebUI forms a stable, testable reference
- Any router-mode behavior differences in BeeLlama are documented and understood
- Future development can use this stack as the "golden reference"
