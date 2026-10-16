# Lua RX2 decoding and 32-bit limits

The 24-bit truncation fix allows returning to the Lua decoder for 16-bit and 24-bit RX2 imports. The actual supplied 24-bit file passed exact PCM serialization checks, but Windows Renoise playback remains unverified. preferences.xml currently sets pakettiRX2NativeDecoder to false; enabling “RX2 decode in Lua” selects Lua on Windows too. External fallback remains available on failed or silent Lua imports.

32-bit RX2 is not correctly supported. PakettiRX2Reader.lua recognizes container depth code 7 as 32, but PakettiRX2Decode.lua clamp_sample defaults to 16-bit limits for every depth except 24. pcm_to_wav emits two bytes for every depth except 24, so a 32-bit header would describe a payload containing only two bytes per sample. The codec also uses signed 32-bit predictor state and doubled-amplitude arithmetic, so changing only the clamp and WAV packing does not establish full-range 32-bit codec correctness.

PakettiRX2Encode.lua also accepts 32-bit metadata while its sample gathering scale defaults to 32767 for 32-bit buffers. Genuine 32-bit support needs codec and exporter validation against a trustworthy real-file/reference pair. Until then, unsupported depths should be rejected by Lua and routed to the external decoder rather than reported as supported. No preferences or source changes were made during this follow-up.
