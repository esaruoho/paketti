#!/usr/bin/env python3
"""Regression probe for PakettiTransientNavigation detector defaults.

This mirrors the Lua transient navigation detector closely enough to catch the
level-Schmitt latch failure that detected only frames 160 and 18132 in
farmman-369finlp.wav, and to verify the adaptive Schmitt replacement.
"""

from __future__ import annotations

import math
import struct
import sys
import wave


class BeatDetector:
    def __init__(self, filter_freq, release_time, trigger_on, trigger_off, filter_type):
        self.k_beat_filter = 0.0
        self.filter1_out = 0.0
        self.filter2_out = 0.0
        self.beat_release = 0.0
        self.peak_env = 0.0
        self.beat_trigger = False
        self.prev_beat_pulse = False
        self.filter_freq = filter_freq
        self.release_time = release_time
        self.trigger_on = trigger_on
        self.trigger_off = trigger_off
        self.filter_type = filter_type

    def set_sample_rate(self, sample_rate):
        t_filter = 1.0 / (2.0 * math.pi * self.filter_freq)
        self.k_beat_filter = 1.0 / (sample_rate * t_filter)
        self.beat_release = math.exp(-1.0 / (sample_rate * self.release_time))

    def process(self, sample):
        self.filter1_out = self.filter1_out + (self.k_beat_filter * (sample - self.filter1_out))
        self.filter2_out = self.filter2_out + (self.k_beat_filter * (self.filter1_out - self.filter2_out))
        filtered = self.filter2_out if self.filter_type == "lowpass" else sample - self.filter2_out

        env_in = abs(filtered)
        if env_in > self.peak_env:
            self.peak_env = env_in
        else:
            self.peak_env = self.peak_env * self.beat_release + (1.0 - self.beat_release) * env_in

        if not self.beat_trigger:
            if self.peak_env > self.trigger_on:
                self.beat_trigger = True
        elif self.peak_env < self.trigger_off:
            self.beat_trigger = False

        pulse = self.beat_trigger and not self.prev_beat_pulse
        self.prev_beat_pulse = self.beat_trigger
        return pulse


def read_mono_16bit_wav(path):
    with wave.open(path, "rb") as wav:
        if wav.getnchannels() != 1 or wav.getsampwidth() != 2:
            raise SystemExit("expected a mono 16-bit PCM WAV fixture")
        sample_rate = wav.getframerate()
        frames = wav.getnframes()
        data = wav.readframes(frames)
    return sample_rate, [value / 32768.0 for (value,) in struct.iter_unpack("<h", data)]


def zero_crossing(samples, pos, sample_rate, threshold=0.01):
    search = int(0.01 * sample_rate)
    start = max(1, pos - search)
    end = min(len(samples), pos + search)
    best = pos
    min_amplitude = abs(samples[pos - 1])

    for i in range(pos, start - 1, -1):
        amplitude = abs(samples[i - 1])
        if amplitude <= threshold:
            return i
        if amplitude < min_amplitude:
            min_amplitude = amplitude
            best = i

    if best == pos:
        for i in range(pos, end + 1):
            amplitude = abs(samples[i - 1])
            if amplitude <= threshold:
                return i
            if amplitude < min_amplitude:
                min_amplitude = amplitude
                best = i

    return best


def beat_detector_hits(samples, sample_rate, trigger_off):
    low = BeatDetector(150, 0.02, 0.04, trigger_off, "lowpass")
    high = BeatDetector(3000, 0.02, 0.04, trigger_off, "highpass")
    low.set_sample_rate(sample_rate)
    high.set_sample_rate(sample_rate)

    raw = []
    for index, sample in enumerate(samples, start=1):
        low_hit = low.process(sample)
        high_hit = high.process(sample)
        if low_hit or high_hit:
            raw.append(index)
    return raw


class AdaptiveSchmittDetector:
    def __init__(self, filter_freq, filter_type, sample_rate):
        t_filter = 1.0 / (2.0 * math.pi * filter_freq)
        self.k_filter = 1.0 / (sample_rate * t_filter)
        self.fast_release = math.exp(-1.0 / (sample_rate * 0.010))
        self.slow_coeff = 1.0 - math.exp(-1.0 / (sample_rate * 0.120))
        self.filter1 = 0.0
        self.filter2 = 0.0
        self.fast_env = 0.0
        self.slow_env = 0.0
        self.trigger = False
        self.prev_trigger = False
        self.filter_type = filter_type

    def process(self, sample):
        self.filter1 = self.filter1 + (self.k_filter * (sample - self.filter1))
        self.filter2 = self.filter2 + (self.k_filter * (self.filter1 - self.filter2))
        filtered = self.filter2 if self.filter_type == "lowpass" else sample - self.filter2
        env_in = abs(filtered)

        if env_in > self.fast_env:
            self.fast_env = env_in
        else:
            self.fast_env = self.fast_env * self.fast_release + (1.0 - self.fast_release) * env_in
        self.slow_env = self.slow_env + (self.slow_coeff * (env_in - self.slow_env))

        novelty = max(0.0, self.fast_env - self.slow_env)
        ratio = self.fast_env / (self.slow_env + 0.000000001)
        should_trigger = self.fast_env > 0.02 and novelty > 0.012 and ratio > 1.25
        should_release = novelty < 0.004 or ratio < 1.05

        if not self.trigger:
            if should_trigger:
                self.trigger = True
        elif should_release:
            self.trigger = False

        pulse = self.trigger and not self.prev_trigger
        self.prev_trigger = self.trigger
        return pulse


def adaptive_schmitt_hits(samples, sample_rate):
    low = AdaptiveSchmittDetector(150, "lowpass", sample_rate)
    high = AdaptiveSchmittDetector(3000, "highpass", sample_rate)
    raw = []
    for index, sample in enumerate(samples, start=1):
        if low.process(sample) or high.process(sample):
            raw.append(index)
    return raw


def filter_and_snap(samples, sample_rate, raw):
    filtered = []
    min_spacing = int(0.010 * sample_rate)
    suppressed = []
    last = None
    for pos in sorted(raw):
        if last is None or pos - last >= min_spacing:
            snapped = zero_crossing(samples, pos, sample_rate)
            filtered.append(snapped)
            last = snapped
        else:
            suppressed.append((pos, pos - last))
    return filtered, suppressed


def detect_beat_only(samples, sample_rate, trigger_off):
    raw = beat_detector_hits(samples, sample_rate, trigger_off)
    filtered, _ = filter_and_snap(samples, sample_rate, raw)
    return filtered


def detect_adaptive(samples, sample_rate):
    adaptive_raw = adaptive_schmitt_hits(samples, sample_rate)
    filtered, suppressed = filter_and_snap(samples, sample_rate, adaptive_raw)
    return adaptive_raw, suppressed, filtered


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: transient_navigation_detector_regression.py /path/to/farmman-369finlp.wav")

    sample_rate, samples = read_mono_16bit_wav(sys.argv[1])
    old_positions = detect_beat_only(samples, sample_rate, 0.005)
    legacy_raw = beat_detector_hits(samples, sample_rate, 0.03)
    adaptive_raw, suppressed, new_positions = detect_adaptive(samples, sample_rate)

    print(f"old peak_off=0.005: {len(old_positions)} positions {old_positions}")
    print(f"legacy level-Schmitt raw: {len(legacy_raw)} positions {legacy_raw}")
    print(f"adaptive Schmitt raw: {len(adaptive_raw)} positions {adaptive_raw}")
    print(f"suppressed by min spacing: {len(suppressed)} positions {suppressed}")
    print(f"adaptive snapped: {len(new_positions)} positions {new_positions}")

    assert old_positions == [160, 18132], "fixture no longer reproduces the original two-hit failure"
    assert len(new_positions) >= 80, "adaptive Schmitt should detect dense visible hits"
    assert any(59000 <= pos <= 73000 for pos in new_positions), "adaptive Schmitt should cover the previously skipped middle"
    assert max(new_positions) > 130000, "new defaults should reach the tail of the sample"


if __name__ == "__main__":
    main()
