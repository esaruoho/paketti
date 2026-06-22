#!/usr/bin/env bash
# Proves PakettiLull approaches 1/2/3 against a LIVE Renoise running PakettiMCP.
# Requires Renoise open with the MCP server started (localhost:19714).
set -euo pipefail
curl -s --max-time 30 -X POST http://localhost:19714/mcp -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"paketti_eval","arguments":{"code":"return dofile(\"/Users/esaruoho/work/paketti/.spine/lull_test.lua\")"}}}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('content',[{}])[0].get('text','NO RESPONSE — is Renoise + PakettiMCP running?'))"
