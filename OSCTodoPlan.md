# Paketti OSC/Socket Todo Plan

> Paketti currently uses ZERO OSC or Socket API — this is a completely untapped area.

---

## Renoise OSC/Socket API — What Exists

### Built-in Renoise OSC server (enable in Preferences > OSC)

```
/renoise/transport/start
/renoise/transport/stop
/renoise/transport/panic
/renoise/song/bpm [float]
/renoise/trigger/note_on [int instr] [int track] [int note] [float velocity]
/renoise/trigger/note_off [int instr] [int track] [int note]
/renoise/evaluate [string lua_code]    ← executes arbitrary Lua code
```

### What Paketti can build

- **Create its own OSC server** using `renoise.Socket.create_server()` + `renoise.Osc.from_binary_data()` to receive custom messages
- **Create OSC clients** to SEND data to external apps
- **TCP and UDP** both supported via `renoise.Socket.PROTOCOL_TCP` / `renoise.Socket.PROTOCOL_UDP`

---

## Ideas (ranked by impact)

### 1. Phone/Tablet as Paketti Controller (TouchOSC / Lemur / Open Stage Control)

Paketti runs an OSC server on a configurable port. Any OSC app on your phone becomes a wireless Paketti controller:

- **Canvas Parameter Editor via phone** — drag bars on your phone, they move on the Canvas in Renoise + write automation
- **Sample slice triggering** — tap pads on phone → `trigger_instrument_note_on()` with velocity
- **BPM tap tempo via phone taps**
- **Mute/solo matrix on tablet** — 8×8 grid of track mutes

This is achievable because Paketti already has the Canvas parameter editor — it just needs an OSC input layer on top.

### 2. Accelerometer/Gyro → Automation Recording

Phone sends continuous accelerometer XYZ data over OSC → Paketti writes those values directly into automation lanes in real time. Tilt your phone to draw filter sweeps, pan movements, or any parameter. Three axes = three simultaneous automation lanes.

```lua
-- Incoming: /paketti/accel [float x] [float y] [float z]
-- → writes x to Cutoff automation, y to Resonance, z to Pan
```

### 3. `/renoise/evaluate` — Remote Live Coding

The built-in `/renoise/evaluate` command executes arbitrary Lua code sent as a string. Paketti could ship a companion script (Python/Node) that lets you:

- Type Paketti commands in a terminal on another machine and they execute in Renoise
- Build a web UI dashboard that sends Lua code to Renoise
- Script entire compositions from an external IDE

### 4. Inter-DAW Bridge

Paketti as OSC client, sending data TO external apps:

- **Renoise → SuperCollider/Pure Data/Max**: Forward note-on events, BPM changes, pattern position in real time
- **Renoise → VCV Rack**: Send CC-style data as OSC
- **Renoise → OBS/Resolume/TouchDesigner**: Send beat position, BPM, current pattern for synced visuals
- **Renoise → Another Renoise instance**: Network jam — trigger patterns on a second machine

### 5. OSC State Broadcaster

Paketti periodically broadcasts song state to the network:

```
/paketti/state/bpm 140.0
/paketti/state/playing 1
/paketti/state/pattern 3
/paketti/state/line 47
/paketti/state/instrument "Kick 808"
/paketti/state/track "Drums"
```

Any visualizer, LED controller, or stage lighting system on the network picks this up. Concert/live performance gold.

### 6. Sensor-Driven Sample Manipulation

Build an OSC receiver that maps incoming continuous data to sample properties:

- `/paketti/sample/pitch [float]` → real-time pitch shift of playing sample
- `/paketti/sample/slice [int]` → trigger specific slice
- `/paketti/sample/loop_start [float]` → scrub loop start point
- `/paketti/sample/reverse` → toggle reverse

Feed it from Kinect, Leap Motion, Wii Remote (via osculator), webcam hand tracking, anything that speaks OSC.

### 7. Pattern Data Network Sync

Two musicians on separate machines. One person's pattern edits stream via OSC to the other's Renoise in real-time. Collaborative tracker composition over the network.

---

## Recommended First Step

Start with **#1 + #5 combined** — a single `PakettiOSC.lua` module that:

1. Creates an OSC server on port 8000 (configurable via preferences)
2. Accepts a set of `/paketti/*` commands (parameter changes, note triggers, transport)
3. Broadcasts beat/position/state on a configurable output port
4. Works with free [Open Stage Control](https://openstagecontrol.ammd.net/) (web-based, runs on any device)

This would be a single file, ~300-400 lines, and would instantly make Paketti controllable from any device on the network. None of the other major Renoise tools do this.

---

## Technical Notes

### Creating an OSC Server in Paketti

```lua
local osc_server = nil

function start_paketti_osc(port)
  osc_server = renoise.Socket.create_server("localhost", port, renoise.Socket.PROTOCOL_UDP)
  if not osc_server then
    renoise.app():show_warning("Failed to create OSC server on port " .. port)
    return
  end

  osc_server:run({
    socket_message = function(socket, data)
      local osc, error = renoise.Osc.from_binary_data(data)
      if osc then
        handle_paketti_osc(osc)
      end
    end,
    socket_error = function(socket, error_message)
      print("Paketti OSC error: " .. error_message)
    end
  })

  renoise.app():show_status("Paketti OSC server running on port " .. port)
end
```

### Sending OSC from Paketti

```lua
function send_osc(host, port, pattern, ...)
  local client = renoise.Socket.create_client(host, port, renoise.Socket.PROTOCOL_UDP)
  if not client then return end

  local args = {}
  for _, v in ipairs({...}) do
    local tag = type(v) == "number" and (v == math.floor(v) and "i" or "f")
              or type(v) == "string" and "s"
              or "N"
    table.insert(args, {tag = tag, value = v})
  end

  local msg = renoise.Osc.Message(pattern, args)
  client:send(msg.binary_data)
  client:close()
end
```

### Preferences needed

```lua
-- In preferences / Document.create:
pakettiOscServerPort = 8000,
pakettiOscBroadcastPort = 9000,
pakettiOscBroadcastHost = "localhost",
pakettiOscServerEnabled = false,
pakettiOscBroadcastEnabled = false,
```
