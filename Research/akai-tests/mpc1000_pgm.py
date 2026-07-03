#!/usr/bin/env python3
"""
Independent MPC1000 .PGM parser — NOT derived from Paketti's Lua parser.

Written from the public MPC1000 PGM layout so it can serve as an outside
ground-truth check on Paketti's importer (Tier 2/3): if this parser and
Paketti agree, AND both agree with the .WAV files actually sitting next to
the .PGM, the import path is proven against real data rather than against
itself.

MPC1000 PGM layout (fixed 10,756-byte file):
  0x0000  u16 LE  file size (0x2A04 = 10756)
  0x0002  u16     padding (0)
  0x0004  16 bytes "MPC1000 PGM x.xx" version string
  0x0018  start of 64 pad records, 164 bytes each  (0x18 + 64*164 = 0x2818)
          within each pad, up to 4 sample slots at +25, +49, +73, +97
          each slot: 16-byte sample name, then (name+20) u16 LE tuning (cents*100)
  0x2959  128-byte MIDI note -> pad map (offset 10585)
"""
import struct
import sys
import os

PAD_RECORD_SIZE = 164
NUM_PADS = 64
# 0-based byte offsets of the 4 sample-name slots within a pad record.
# (Paketti's Lua parser uses 1-based 25/49/73/97; minus 1 => 24/48/72/96.)
SLOT_OFFSETS = (24, 48, 72, 96)
SLOT_NAME_LEN = 16
MIDIMAP_OFFSET = 10584      # Paketti 1-based 10585 -> 0-based
EXPECTED_FILE_SIZE = 10756


def _read_cstr(data, off, length):
    raw = data[off:off + length]
    # names are ASCII, NUL/space padded
    end = raw.find(b"\x00")
    if end != -1:
        raw = raw[:end]
    return raw.decode("latin-1", "replace").strip()


def parse_pgm(path):
    with open(path, "rb") as fh:
        data = fh.read()

    result = {
        "path": path,
        "file_size": len(data),
        "errors": [],
        "warnings": [],
        "version": None,
        "size_field": None,
        "pads": [],          # list of {pad, slot, name, tuning}
        "sample_names": [],  # unique ordered sample basenames referenced
    }

    if len(data) < 0x18:
        result["errors"].append("file smaller than header")
        return result

    result["size_field"] = struct.unpack_from("<H", data, 0)[0]
    if result["size_field"] != EXPECTED_FILE_SIZE:
        result["warnings"].append(
            f"size field {result['size_field']} != {EXPECTED_FILE_SIZE}")
    if len(data) != EXPECTED_FILE_SIZE:
        result["warnings"].append(
            f"actual size {len(data)} != {EXPECTED_FILE_SIZE}")

    version = _read_cstr(data, 0x04, 16)
    result["version"] = version
    if not version.startswith("MPC1000 PGM"):
        result["errors"].append(f"bad magic: {version!r}")
        return result

    seen = set()
    for pad in range(NUM_PADS):
        pad_off = pad * PAD_RECORD_SIZE
        for slot_i, slot in enumerate(SLOT_OFFSETS):
            name_off = pad_off + slot
            if name_off + SLOT_NAME_LEN > len(data):
                continue
            name = _read_cstr(data, name_off, SLOT_NAME_LEN)
            if not name:
                continue
            tuning_off = name_off + 20
            tuning = 0
            if tuning_off + 2 <= len(data):
                raw = struct.unpack_from("<H", data, tuning_off)[0]
                if raw >= 0x8000:
                    raw -= 0x10000
                tuning = raw / 100.0
            result["pads"].append(
                {"pad": pad, "slot": slot_i, "name": name, "tuning": tuning})
            if name not in seen:
                seen.add(name)
                result["sample_names"].append(name)

    return result


def verify_against_folder(result):
    """Cross-check every referenced sample name against .WAV files present."""
    folder = os.path.dirname(result["path"])
    try:
        present = {f.rsplit(".", 1)[0].lower()
                   for f in os.listdir(folder) if f.lower().endswith(".wav")}
    except OSError as e:
        result["errors"].append(f"cannot list folder: {e}")
        return
    missing = [n for n in result["sample_names"] if n.lower() not in present]
    result["missing_wavs"] = missing
    result["wavs_in_folder"] = len(present)


def main(argv):
    if len(argv) < 2:
        print("usage: mpc1000_pgm.py <file.PGM> [more.PGM ...]")
        return 2
    rc = 0
    for path in argv[1:]:
        r = parse_pgm(path)
        verify_against_folder(r)
        print("=" * 70)
        print(f"FILE: {path}")
        print(f"  size: {r['file_size']} bytes  (size field {r['size_field']})")
        print(f"  version: {r['version']!r}")
        print(f"  referenced samples ({len(r['sample_names'])}): "
              f"{', '.join(r['sample_names'])}")
        print(f"  pad->sample records: {len(r['pads'])}")
        print(f"  .wav files in folder: {r.get('wavs_in_folder', '?')}")
        miss = r.get("missing_wavs", [])
        if miss:
            print(f"  MISSING wavs for: {miss}")
        if r["warnings"]:
            print(f"  warnings: {r['warnings']}")
        if r["errors"] or miss:
            print("  RESULT: FAIL")
            rc = 1
        else:
            print("  RESULT: PASS (all referenced samples exist as .wav)")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
