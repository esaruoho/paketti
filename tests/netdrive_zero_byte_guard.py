"""Run the actual NetDrive guard paths in Lua with mocked Renoise APIs."""
from pathlib import Path
import subprocess
import tempfile

source = Path('PakettiSamples.lua').read_text()
load = source[source.index('function PakettiNetDriveWatcherLoadFile(path)'):source.index('\n--------------------------------------------------------------------------------\n-- Durable load-after')]
start = source.index('    local function queue_or_load_changed_file(')
end = source.index('\n    -- Categorize files', start)
poll = source[start:end].replace('    local function queue_or_load_changed_file', '    function queue_or_load_changed_file', 1)
queue = source[source.index('function PakettiNetDriveWatcherProcessQueue()'):source.index('\n-- Enqueue paths')]
script = '''
local size = 0
local statuses = {}
local state = {pending={}, known={}, load_fail={}, load_queue={}, queued={}}
PakettiNetDriveWatcher = state
local song_calls = 0
renoise = {
  app=function() return {show_status=function(_, msg) table.insert(statuses,msg) end} end,
  song=function() song_calls=song_calls+1; error("must not mutate the song") end,
  tool=function() return {add_timer=function() end} end
}
local function PakettiNetDriveWatcherStat() return {size=size,mtime=100} end
local function PakettiNetDriveWatcherSignature(_, stat) return tostring(stat.size) end
local function PakettiNetDriveWatcherBeforeCutoff() return false end
local function PakettiNetDriveWatcherAdvanceLoadAfter() error("empty file advanced cutoff") end
local function PakettiNetDriveWatcherBasename(path) return path end
local function PakettiNetDriveWatcherVolumeMounted() return true end
local now, stable_seconds = 0, 2
local queued = 0
local function PakettiNetDriveWatcherEnqueue() queued=queued+1 end
ProcessSlicer = function(process)
  local slicer = {}
  function slicer:create_dialog() return nil,nil end
  function slicer:was_cancelled() return false end
  function slicer:start()
    local co=coroutine.create(process)
    while coroutine.status(co) ~= "dead" do
      local ok,err=coroutine.resume(co); assert(ok,err)
    end
  end
  return slicer
end
'''+load+poll+queue+'''
local ok,reason=PakettiNetDriveWatcherLoadFile("take.wav")
assert(not ok and reason=="empty" and song_calls==0)
assert(statuses[#statuses]=="NetDrive watcher: Zero Bytes - stop loading")
for t=0,10 do
  now=t
  queue_or_load_changed_file("take.wav","zero",0,100,state.pending["take.wav"])
end
assert(queued==0 and #statuses==2, "empty file requeued or repeated its notice")
now=11
queue_or_load_changed_file("take.wav","written",100,100,state.pending["take.wav"])
now=13
queue_or_load_changed_file("take.wav","written",100,100,state.pending["take.wav"])
assert(queued==1 and state.pending["take.wav"]==nil, "written file must stabilize then enqueue")
state.load_queue={"take.wav"}; state.queued["take.wav"]=true
state.load_fail["take.wav"]=2
PakettiNetDriveWatcherProcessQueue()
assert(song_calls==0 and state.load_fail["take.wav"]==nil and state.known["take.wav"]=="0")
-- Truncation between the queue stat and the loader's own stat.
state.loading=false
state.load_queue={"race.wav"}; state.queued["race.wav"]=true
local calls=0
PakettiNetDriveWatcherStat=function()
  calls=calls+1
  return {size=(calls==1 and 100 or 0),mtime=100}
end
PakettiNetDriveWatcherProcessQueue()
assert(song_calls==0 and state.load_fail["race.wav"]==nil and state.known["race.wav"]==nil)
print("PASS: empty import guard, repeated polls, nonempty recovery, queued truncation, import-time truncation")
'''
with tempfile.TemporaryDirectory() as folder:
    path=Path(folder)/'guard.lua'
    path.write_text(script)
    subprocess.run(['lua',str(path)],check=True)
