#!/usr/bin/env python3
# pmcp.py <lua_file>   OR   pmcp.py -e "lua code"
# Sends Lua to PakettiMCP paketti_eval, prints the returned text.
import sys, json, urllib.request
if sys.argv[1] == "-e":
    code = sys.argv[2]
else:
    code = open(sys.argv[1]).read()
req = urllib.request.Request(
    "http://localhost:19714/mcp",
    data=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call",
        "params":{"name":"paketti_eval","arguments":{"code":code}}}).encode(),
    headers={"Content-Type":"application/json"})
try:
    r = json.load(urllib.request.urlopen(req, timeout=60))
except Exception as e:
    print("MCP_ERROR:", e); sys.exit(2)
if "error" in r:
    print("EVAL_ERROR:", json.dumps(r["error"])); sys.exit(1)
txt = r["result"]["content"][0]["text"]
print(txt)
