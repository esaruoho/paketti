#!/usr/bin/env python3
import json, urllib.request, subprocess, time, os, re, sys
SCR = os.path.dirname(os.path.abspath(__file__))
MCP = "http://localhost:19714/mcp"
STAGE = os.path.expanduser("~/Downloads/paketti-dialogs-clean")
os.makedirs(STAGE, exist_ok=True)
LOG = os.path.join(STAGE, "_progress.log")
WINLIST = os.path.join(SCR, "winlist")

def log(m):
    line = f"[{time.strftime('%H:%M:%S')}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def activate():
    subprocess.run(["osascript","-e",'tell application "Renoise" to activate'], capture_output=True)

def mcp_eval(code, timeout=15):
    data = json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call",
        "params":{"name":"paketti_eval","arguments":{"code":code}}}).encode()
    req = urllib.request.Request(MCP, data=data, headers={"Content-Type":"application/json"})
    try:
        r = json.load(urllib.request.urlopen(req, timeout=timeout))
        return r["result"]["content"][0]["text"]
    except Exception as e:
        return f"ERR:{e}"

def dialog_windows():
    out = subprocess.run([WINLIST], capture_output=True, text=True).stdout
    d = {}
    for line in out.splitlines():
        p = line.split("\t", 1)
        if len(p) == 2 and p[0].isdigit(): d[int(p[0])] = p[1]
    return d

def safe(label):
    return re.sub(r'[^A-Za-z0-9._-]+', '_', label).strip('_')[:60] or "dialog"

def main():
    dialogs = json.load(open(sys.argv[1]))
    activate(); time.sleep(3)
    log(f"=== batch start: {len(dialogs)} dialogs -> {STAGE} ===")
    captured, fails, consec_err = 0, [], 0
    for d in dialogs:
        i, label, tgt = d["i"], d["label"], d["target"]
        if tgt in ("FN", "?"): 
            fails.append([i, label, "target-not-string"]); continue
        before = dialog_windows()
        r = mcp_eval(f'local fn=rawget(_G,"{tgt}"); if type(fn)=="function" then pcall(fn) end return "o"')
        if r.startswith("ERR"):
            consec_err += 1; fails.append([i, label, "open-"+r])
            log(f"#{i} {label}: open ERR consec={consec_err}")
            if consec_err >= 3:
                log("3 consecutive MCP errors -> aborting to preserve progress"); break
            activate(); time.sleep(2); continue
        consec_err = 0
        time.sleep(1.3)
        after = dialog_windows()
        new = [wid for wid in after if wid not in before]
        if new:
            wid = sorted(new)[-1]
            path = os.path.join(STAGE, f"{i:03d}_{safe(label)}.png")
            subprocess.run(["screencapture","-x","-o",f"-l{wid}",path], capture_output=True)
            if os.path.exists(path) and os.path.getsize(path) > 0:
                captured += 1; log(f"#{i} {label}: OK (win {wid})")
            else:
                fails.append([i, label, "capture-failed"]); log(f"#{i} {label}: capture FAILED")
        else:
            fails.append([i, label, "no-window"]); log(f"#{i} {label}: no new window")
        # toggle-close
        mcp_eval(f'local fn=rawget(_G,"{tgt}"); if type(fn)=="function" then pcall(fn) end return "c"')
        time.sleep(0.5)
    log(f"=== DONE: {captured} captured, {len(fails)} issues ===")
    json.dump(fails, open(os.path.join(STAGE, "_fails.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
