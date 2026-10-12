# C++ Differential Testing Harness Specification

To finalize the SampleBrain Lua port mathematically, we need a small standalone C++ utility that runs the upstream `fxbeaulieu/SampleBrain` code and dumps JSON/CSV arrays for direct comparison.

## Target Exporter Variables:
1. `FFTW Complex Spectrum` (First 1024 bins of a 3000 block input)
2. `SampleBrain FFT 100-bin Descriptor` (Aggregated real^2 output)
3. `Aquila 24-filter Mel output`
4. `Aquila 12-coefficient DCT-II MFCC output`
5. `Dominant Frequency`
6. `distance` (raw, normalized, usage blended)

We will use this exporter to generate `.json` fixtures for fixed waveforms (440Hz Sine, Impulse, White Noise). The Lua `test_dsp.lua` will load these fixtures and assert numeric equality.
