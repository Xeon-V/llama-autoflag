#!/usr/bin/env python3
import json, sys
if len(sys.argv) < 2:
    print("Usage: python llama-autoflag-detect.py <json_file>")
    sys.exit(1)
with open(sys.argv[1]) as f:
    data = json.load(f)
for m in data.get('data', []):
    mid = m.get('id', '?')
    st = m.get('status', {})
    val = st.get('value', '?')
    args = st.get('args', [])
    print(f"📦 {mid}")
    print(f"   Status: ✅ LOADED" if val == 'loaded' else f"   Status: ○ {val}")
    o = {}
    for i in range(0, len(args) - 1, 2):
        if args[i].startswith('--'):
            o[args[i][2:]] = args[i + 1]
    for k in ['n-gpu-layers', 'batch-size', 'ubatch-size', 'ctx-size', 'parallel', 'tensor-split']:
        if k in o:
            print(f"   {k.replace('-', ' ').title()}: {o[k]}")
