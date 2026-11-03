#!/usr/bin/env python3
"""Synthesizes the sound effects that the CC0 packs don't cover (XP chime, level-up, core,
gate hum, heartbeat, fire whoosh) as mono 16-bit WAV files. Pure Python, no dependencies.

Usage: python3 tools/synth_sfx.py [output_dir]   (default: audio/sfx)
The output is deterministic (fixed random seeds), so rerunning gives the same files.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100
PEAK = 0.89  # about -1 dBFS


def write_wav(path, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = PEAK / peak
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))


def fade_out(samples, seconds):
    count = min(len(samples), int(seconds * RATE))
    for i in range(count):
        samples[len(samples) - count + i] *= 1.0 - i / count
    return samples


def bell(frequency, seconds, partials, attack=0.002):
    """partials: (frequency ratio, amplitude, decay per second). The tail is faded so a cut-off
    note never clicks."""
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        env = min(t / attack, 1.0)
        value = sum(amp * math.exp(-decay * t) * math.sin(2 * math.pi * frequency * ratio * t)
                    for ratio, amp, decay in partials)
        out.append(value * env)
    return fade_out(out, min(0.05, seconds * 0.3))


def mix_into(target, source, offset_seconds, gain=1.0):
    start = int(offset_seconds * RATE)
    needed = start + len(source)
    if len(target) < needed:
        target.extend([0.0] * (needed - len(target)))
    for i, value in enumerate(source):
        target[start + i] += value * gain
    return target


def xp_chime():
    partials = [(1.0, 1.0, 18.0), (2.0, 0.35, 26.0), (3.01, 0.16, 34.0), (4.17, 0.07, 40.0)]
    return fade_out(bell(1567.98, 0.24, partials), 0.03)


def level_up():
    partials = [(1.0, 1.0, 4.0), (2.0, 0.3, 6.0), (3.0, 0.12, 8.0)]
    out = []
    for index, note in enumerate([523.25, 659.25, 783.99, 1046.5]):
        mix_into(out, bell(note, 0.9, partials, attack=0.004), 0.07 * index, 0.8)
    shimmer = []
    for i in range(int(0.8 * RATE)):
        t = i / RATE
        tremolo = 0.6 + 0.4 * math.sin(2 * math.pi * 9.0 * t)
        shimmer.append(math.sin(2 * math.pi * 2093.0 * t) * math.exp(-3.5 * t) * min(t / 0.05, 1.0) * tremolo)
    mix_into(out, shimmer, 0.24, 0.25)
    return fade_out(out, 0.15)


def core_bell():
    partials = [(1.0, 1.0, 2.5), (2.4, 0.5, 4.0), (3.9, 0.25, 6.0), (5.8, 0.12, 8.0)]
    out = bell(392.0, 1.1, partials, attack=0.003)
    glint = bell(1568.0, 0.4, [(1.0, 1.0, 12.0), (2.0, 0.3, 18.0)])
    mix_into(out, glint, 0.0, 0.35)
    return fade_out(out, 0.2)


def gate_hum():
    """Seamless 2 s loop (every component completes whole cycles, so the loop point never
    clicks). The game raises its pitch and volume with the gate's channel progress."""
    seconds = 2.0
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        vibrato = 0.6 * math.sin(2 * math.pi * 5.0 * t)
        value = 0.0
        for n in range(1, 9):
            weight = (1.0 / n) * 0.75 ** (n - 1)
            value += weight * math.sin(2 * math.pi * 98.0 * n * t + vibrato / n)
            value += 0.5 * weight * math.sin(2 * math.pi * 147.0 * n * t + vibrato / n)
        tremolo = 0.85 + 0.15 * math.sin(2 * math.pi * 2.0 * t)
        out.append(value * tremolo)
    return out


def heartbeat():
    """One "lub-dub" padded to 0.95 s, so looping it gives a steady heartbeat."""
    out = []
    for offset, gain in [(0.0, 1.0), (0.18, 0.7)]:
        thump = []
        phase = 0.0
        for i in range(int(0.3 * RATE)):
            t = i / RATE
            frequency = 45.0 + 25.0 * math.exp(-t / 0.04)
            phase += 2 * math.pi * frequency / RATE
            thump.append(math.sin(phase) * min(t / 0.005, 1.0) * math.exp(-22.0 * t))
        mix_into(out, thump, offset, gain)
    out.extend([0.0] * (int(0.95 * RATE) - len(out)))
    return out


def fire_whoosh(seed):
    rng = random.Random(seed)
    seconds = 0.75
    out = []
    low1 = low2 = low3 = 0.0
    crackle = 0.0
    phase = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        # Filter cutoff: opens quickly, then closes as the flames die down.
        if t < 0.1:
            cutoff = 250.0 + (1800.0 - 250.0) * (t / 0.1)
        else:
            cutoff = 1800.0 + (400.0 - 1800.0) * min((t - 0.1) / 0.55, 1.0)
        a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
        noise = rng.uniform(-1.0, 1.0)
        low1 += a * (noise - low1)
        low2 += a * (low1 - low2)
        low3 += a * (low2 - low3)
        env = min(t / 0.03, 1.0) * math.exp(-4.5 * t)
        if 0.05 < t < 0.55 and rng.random() < 0.0008:
            crackle = rng.uniform(0.4, 0.8) * (1 if rng.random() < 0.5 else -1)
        crackle *= 0.9
        frequency = 50.0 + 30.0 * math.exp(-t / 0.08)
        phase += 2 * math.pi * frequency / RATE
        whoomp = math.sin(phase) * math.exp(-6.0 * t) * min(t / 0.01, 1.0)
        out.append(low3 * 3.0 * env + crackle * 0.2 * env + whoomp * 0.45)
    return fade_out(out, 0.08)


SOUNDS = {
    "xp_1": xp_chime,
    "level_up_1": level_up,
    "core_1": core_bell,
    "gate_hum_1": gate_hum,
    "heartbeat_1": heartbeat,
    "fire_wave_1": lambda: fire_whoosh(11),
    "fire_wave_2": lambda: fire_whoosh(29),
}


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "audio/sfx"
    os.makedirs(out_dir, exist_ok=True)
    for name, make in SOUNDS.items():
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, make())
        print("wrote", path)


if __name__ == "__main__":
    main()
