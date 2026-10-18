# Track Mute Controller and Track Mute Modes

Open **Tools → Paketti → Controllers → Track Mute Controller**. Choose your input, pad MIDI channel and numbers, then press **Start**. The default pad map is 36–43 on channel 10; change it to match your controller program. Numbers are MIDI note/CC numbers, not Renoise octave labels.

Open **Track Mute Modes** from the same menu or the setup dialog. Each button shows a track name and actual mute state: green ON, red MUTED. Click to toggle, or use your pads. Previous/Next tracks moves the pad bank. Master, sends and groups are not controlled. A track's ON indication describes its own mute state; soloing and parent-group mutes can still affect audibility.

## Input and performance modes

- **Momentary hardware:** each press toggles once; release is ignored in Toggle mode.
- **Toggle hardware:** alternating Note On/Off or nonzero/zero CC messages each toggle once. Choose this when the controller latches internally.
- **Toggle mute:** each tap inverts the current track state.
- **Hold to mute / Hold to enable:** press applies the state, release restores the original. With hardware-toggle pads, the second tap acts as release.

Stop, settings changes and track paging restore held tracks. Closing either dialog keeps the bridge running. Use **Stop** or the **Stop Track Mute Controller** shortcut to stop it. Song release stops the bridge; start again for the new song.

## Hardware LED feedback

Enable **Send LED feedback**, select the output port and its channel, and configure the active and muted values for the exact device protocol. Output uses the chosen Note or CC message type and each pad's configured number. **Test LEDs** displays alternating active/muted values for one second and restores the real track states; **Resync LEDs** sends the current states again.

The bridge polls actual Renoise mute states every 50 ms, including mouse edits and other mappings. It sends only changed LED values. Hardware palettes differ: our APC Key 25 mk1 implementation uses channel 1 and green 1 / red 3; MIDImix uses channel 1 and 127 / 0. Those protocols do not establish MPK Mini compatibility. Host-controlled LEDs on the exact MPK model need verification. White/red cannot be promised without a documented or tested palette. Feedback is disabled by default.

Incoming pad messages appear in the performance status line so alternating On/Off behavior can be checked. Keyboard and knob messages are not interpreted by this bridge; keep their normal Renoise configuration. Avoid mapping the same pads to another mute action, which would toggle twice.

Starting mute control stops an existing 8120 APC/MIDImix/LPD8 step bridge for that device family. Starting its step sequencer again stops mute control. For other tools that own the same MIDI ports, stop their bridge first.

Settings are stored in `TrackMuteControllerSettings.xml` in the tool folder. No automatic startup is enabled. Two global shortcuts open the dialogs, and a third stops the bridge.

Validation: Lua and LuaJIT regression mocks cover input edges, feedback, cleanup and dialog state updates. Actual Renoise UI and controller hardware have not been tested in this session. See `features/track-mute-controller.feature` for grades and citations.
