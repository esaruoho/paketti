#!/usr/bin/env python3
import json, urllib.request, subprocess, time, os, re, sys
SCR=os.path.dirname(os.path.abspath(__file__)); MCP="http://localhost:19714/mcp"
STAGE=os.path.expanduser("~/Downloads/paketti-dialogs-clean"); WINALL=os.path.join(SCR,"winall")
def ev(code,t=15):
    d=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"paketti_eval","arguments":{"code":code}}}).encode()
    try: return json.load(urllib.request.urlopen(urllib.request.Request(MCP,data=d,headers={"Content-Type":"application/json"}),timeout=t))["result"]["content"][0]["text"]
    except Exception as e: return f"ERR:{e}"
def front_dialog_window():
    # CGWindowList is front-to-back; the first layer-3 Renoise window is the active dialog
    out=subprocess.run([WINALL],capture_output=True,text=True).stdout
    for line in out.splitlines():
        m=re.search(r'id=(\d+) layer=(\d+) size=\d+x\d+ title=(.*)',line)
        if m and int(m.group(2))>=3 and m.group(3) not in ("Renoise (Arm64)",) and "Scripting Terminal" not in m.group(3):
            return int(m.group(1)), m.group(3)
    return None,None
def safe(l): return re.sub(r'[^A-Za-z0-9._-]+','_',l).strip('_')[:60] or "dialog"
missed=json.load(open(sys.argv[1]))
subprocess.run(["osascript","-e",'tell application "Renoise" to activate'],capture_output=True); time.sleep(3)
ok=0; still=[]
for d in missed:
    i,label=d["i"],d["label"]
    # open by INDEX so inline-function targets work too
    r=ev(f'local b=create_button_list(); local e=b[{i}]; if not e then return "noentry" end local fn=e[2]; if type(fn)=="string" then fn=rawget(_G,fn) end; if type(fn)=="function" then pcall(fn) end return "o"')
    if r.startswith("ERR"): still.append([i,label,"open-"+r]); print(f"#{i} {label}: ERR"); time.sleep(1); continue
    time.sleep(3.0)  # longer wait for heavy/canvas dialogs
    wid,title=front_dialog_window()
    if wid:
        path=os.path.join(STAGE,f"{i:03d}_{safe(label)}.png")
        subprocess.run(["screencapture","-x","-o",f"-l{wid}",path],capture_output=True)
        if os.path.exists(path) and os.path.getsize(path)>0: ok+=1; print(f"#{i} {label}: OK (win {wid} '{title}')")
        else: still.append([i,label,"cap-fail"]); print(f"#{i} {label}: cap-fail")
    else: still.append([i,label,"no-layer3-window"]); print(f"#{i} {label}: no layer-3 window")
    # close (toggle by index)
    ev(f'local b=create_button_list(); local e=b[{i}]; local fn=e and e[2]; if type(fn)=="string" then fn=rawget(_G,fn) end; if type(fn)=="function" then pcall(fn) end return "c"')
    time.sleep(0.6)
print(f"=== recapture: {ok} recovered, {len(still)} still missing ===")
json.dump(still,open(os.path.join(STAGE,"_still_missing.json"),"w"),indent=1)
