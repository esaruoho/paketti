// Oracle validator: parse any .mtp/.mt with Polyend's OWN official tracker-lib
// and report structure. Used to verify that Paketti-written files are accepted by
// the same code the Polyend web editors use.
//
// Setup (one time):
//   cd ~/work/tracker-lib && npm install && npm run build
// Run:
//   node validate-mtp.mjs <file.mtp> [<file2.mtp> ...]
//   node validate-mtp.mjs            # defaults to the bundled sample + any real device files
//
// Ground truth (verified against real device files in ~/Music/samples/PTI and the
// official 2324-byte project template decoded from tracker-lib/src/data/project.ts):
//   .mtp pattern: id="KS", type=2, fwVersion=1.9.1.1, fileStructureVersion=5.5.5.5,
//                 size field = total file size, 28-byte base (14 header + 2 pad + 12 unused),
//                 769 bytes/track (1 lastStep + 128*6), lastStep on ALL tracks, CRC=0.
//                 16-track total = 28 + 769*16 + 4 = 12336 bytes.
//   project.mt:   globalTempo = float32 @ 0x1C0 (NOT 0x80), playlist @ 0x10, name version-gated
//                 (>16 -> 0x810, >15 -> 0x80C, else 0x600), track names @ 0x428 (21b) / 0x603 (8b).

import Tracker from "/Users/esaruoho/work/tracker-lib/dist/index.js";
import fs from "fs";

const DEFAULTS = [
  decodeURIComponent(new URL("./sample-paketti-export.mtp", import.meta.url).pathname),
  "/Users/esaruoho/Music/samples/PTI/sandroid_testproject/patterns/pattern_01.mtp",
  "/Users/esaruoho/Music/samples/PTI/MT/Demover - Treasure Island 140bpm/patterns/pattern_01.mtp",
];

const files = process.argv.slice(2);
const targets = files.length ? files : DEFAULTS;

let pass = 0, fail = 0;
for (const path of targets) {
  const label = path.split("/").slice(-2).join("/");
  try {
    const pat = await Tracker.readPattern(path);
    if (!pat) throw new Error("parser returned null");
    let notes = 0, fxUsed = new Set();
    for (const t of pat.tracks) for (const s of t.steps) {
      if (s.note >= 0) notes++;
      for (const fx of s.fx) if (fx?.type?.index > 0) fxUsed.add(fx.type.index);
    }
    console.log(`  PASS  ${label}: tracks=${pat.tracks.length} lastStep(t0)=${pat.tracks[0].length} notes=${notes} fxTypes=[${[...fxUsed].sort((a,b)=>a-b)}]`);
    pass++;
  } catch (e) {
    console.log(`  FAIL  ${label}: ${e.message}`);
    fail++;
  }
}
console.log(`\n${fail === 0 ? "ALL PASS" : "FAILURES"} (${pass} pass, ${fail} fail)`);
process.exit(fail === 0 ? 0 : 1);
