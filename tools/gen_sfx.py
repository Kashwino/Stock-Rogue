#!/usr/bin/env python3
"""Generate every placeholder sound effect and music loop for Stock Rogue.

Standard library only (wave, struct, math, random, array). Deterministic:
the same seed always produces the same files.

    python3 tools/gen_sfx.py            # writes any missing sfx + music files
    python3 tools/gen_sfx.py sfx        # regenerates every sound effect
    python3 tools/gen_sfx.py music      # regenerates every music loop

Output: 22.05 kHz, 16-bit mono WAV. Music loops are rendered into circular
buffers so every note tail wraps around and the loop point is seamless.
The heist's stealth and combat layers share tempo, key and length so they
can be crossfaded in sync.
"""
import array
import math
import os
import random
import struct
import sys
import wave

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
SFX_DIR = os.path.join(ROOT, "sfx")
MUSIC_DIR = os.path.join(ROOT, "music")
TAU = math.tau
rng = random.Random(1947)


# --------------------------------------------------------------- helpers ----
def zeros(seconds):
    return array.array("f", [0.0]) * int(seconds * SR)


def write(path, buf, peak=0.89):
    m = max((abs(x) for x in buf), default=1.0) or 1.0
    k = peak / m if m > peak else 1.0
    data = array.array("h", (int(max(-1.0, min(1.0, x * k)) * 32767) for x in buf))
    if sys.byteorder == "big":
        data.byteswap()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def add(buf, start, samples, gain=1.0, wrap=False):
    n = len(buf)
    for i, v in enumerate(samples):
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        buf[j] += v * gain


def env(n, attack=0.005, decay=None, sustain=1.0, release=0.05, curve=4.0):
    """Attack / exponential decay envelope over n samples."""
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    out = []
    for i in range(n):
        if i < a:
            v = i / a
        elif decay is not None:
            v = math.exp(-curve * (i - a) / max(1, decay * SR))
            v = sustain + (1 - sustain) * v if sustain < 1.0 else v
        else:
            v = 1.0
        if i > n - r:
            v *= max(0.0, (n - i) / r)
        out.append(v)
    return out


def lowpass(samples, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    lp = lowpass(samples, cutoff)
    return [x - y for x, y in zip(samples, lp)]


def noise(n, color="white"):
    if color == "white":
        return [rng.uniform(-1, 1) for _ in range(n)]
    out, b = [], 0.0
    for _ in range(n):
        b = (b + 0.02 * rng.uniform(-1, 1)) * 0.998
        out.append(b * 8.0)
    return out


def tone(freq, n, shape="sine", detune=0.0, vibrato=0.0, vib_rate=5.0, sweep_to=None):
    out, ph = [], rng.random()
    for i in range(n):
        t = i / SR
        f = freq if sweep_to is None else freq + (sweep_to - freq) * (i / max(1, n - 1))
        f *= 1.0 + detune + vibrato * math.sin(TAU * vib_rate * t)
        ph += f / SR
        p = ph % 1.0
        if shape == "sine":
            v = math.sin(TAU * p)
        elif shape == "tri":
            v = 4 * abs(p - 0.5) - 1
        elif shape == "saw":
            v = 2 * p - 1
        else:
            v = 1.0 if p < 0.5 else -1.0
        out.append(v)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def mix(*parts):
    n = max(len(p[0]) for p in parts)
    out = [0.0] * n
    for samples, gain in parts:
        for i, v in enumerate(samples):
            out[i] += v * gain
    return out


def drive(samples, amount):
    return [math.tanh(x * amount) / math.tanh(amount) for x in samples]


def echo(samples, delay, fb, tail=0.4):
    d = int(delay * SR)
    out = list(samples) + [0.0] * int(tail * SR)
    for i in range(d, len(out)):
        out[i] += out[i - d] * fb
    return out


def secs(n):
    return int(n * SR)


def note_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


# ------------------------------------------------------------------ SFX -----
def gunshot(thump_hz, body_cut, decay, click=0.6, crack=0.5, length=0.45):
    n = secs(length)
    body = mul(lowpass(noise(n), body_cut), env(n, 0.001, decay, release=0.05, curve=5))
    crack_n = mul(highpass(noise(n), 2500), env(n, 0.0005, 0.03, release=0.01, curve=6))
    thump = mul(tone(thump_hz, n, "sine", sweep_to=thump_hz * 0.35), env(n, 0.001, decay * 0.8, release=0.05, curve=5))
    clk = mul(tone(1800, n, "square"), env(n, 0.0002, 0.004, release=0.002, curve=8))
    return drive(mix((body, 1.0), (crack_n, crack), (thump, 1.1), (clk, click)), 2.2)


def sfx_bank():
    s = {}
    s["shot_pistol"] = gunshot(160, 3200, 0.09)
    s["shot_revolver"] = gunshot(110, 2600, 0.16, crack=0.8, length=0.6)
    s["shot_smg"] = gunshot(180, 3800, 0.05, length=0.25)
    s["shot_rifle"] = gunshot(120, 2400, 0.12, crack=0.9, length=0.55)
    s["shot_sniper"] = echo(gunshot(90, 2000, 0.2, crack=1.0, length=0.7), 0.11, 0.3)
    s["shot_shotgun"] = gunshot(70, 1600, 0.22, crack=0.6, length=0.8)
    s["shot_lmg"] = gunshot(130, 3000, 0.06, crack=0.7, length=0.3)
    n = secs(0.25)
    s["shot_silenced"] = mix((mul(lowpass(noise(n), 1400), env(n, 0.001, 0.05, release=0.03)), 0.8),
                             (mul(tone(900, n, "square"), env(n, 0.0005, 0.01, release=0.005, curve=8)), 0.4))
    s["shot_enemy"] = gunshot(140, 2800, 0.08, length=0.4)
    n = secs(0.12)
    s["dry_fire"] = mul(highpass(noise(n), 3000), env(n, 0.0005, 0.02, release=0.01, curve=7))
    n = secs(0.25)
    s["mag_out"] = mix((mul(highpass(noise(n), 1800), env(n, 0.001, 0.05, release=0.02)), 0.6),
                       (mul(tone(520, n, "square", sweep_to=380), env(n, 0.001, 0.03, release=0.02)), 0.3))
    s["mag_in"] = mix((mul(highpass(noise(n), 1200), env(n, 0.0005, 0.03, release=0.02, curve=6)), 0.8),
                      (mul(tone(300, n, "square"), env(n, 0.0005, 0.02, release=0.01, curve=7)), 0.5))
    n = secs(0.2)
    s["impact_wall"] = mix((mul(highpass(noise(n), 2200), env(n, 0.0005, 0.04, release=0.02, curve=6)), 1.0),
                           (mul(tone(2400, n, "sine", sweep_to=1200), env(n, 0.0005, 0.03, release=0.02)), 0.3))
    s["impact_body"] = mix((mul(lowpass(noise(n), 700), env(n, 0.001, 0.06, release=0.03)), 1.0),
                           (mul(tone(90, n, "sine"), env(n, 0.001, 0.05, release=0.03)), 0.8))
    for i in range(3):
        n = secs(0.14)
        s["footstep_%d" % (i + 1)] = mul(lowpass(noise(n), 600 + i * 150), env(n, 0.002, 0.03 + i * 0.01, release=0.02, curve=5))
    n = secs(0.35)
    s["hurt"] = drive(mix((mul(lowpass(noise(n), 1200), env(n, 0.001, 0.12, release=0.05)), 1.0),
                          (mul(tone(220, n, "saw", sweep_to=110), env(n, 0.002, 0.15, release=0.05)), 0.6)), 1.8)
    n = secs(0.6)
    s["death_enemy"] = mix((mul(lowpass(noise(n), 500), env(n, 0.002, 0.2, release=0.1)), 1.0),
                           (mul(tone(140, n, "saw", sweep_to=60), env(n, 0.005, 0.25, release=0.1)), 0.5))
    n = secs(1.4)
    s["death_player"] = echo(mix((mul(tone(220, n, "saw", sweep_to=55, vibrato=0.01), env(n, 0.01, 0.6, release=0.3)), 0.6),
                                 (mul(lowpass(noise(n), 400), env(n, 0.005, 0.4, release=0.2)), 0.8)), 0.18, 0.35)
    n = secs(0.4)
    s["alert"] = drive(mul(tone(330, n, "saw", vibrato=0.04, vib_rate=9), env(n, 0.01, 0.2, release=0.08)), 2.5)
    for tier, base in enumerate([880, 1100, 1320, 1760]):
        n = secs(0.35)
        s["loot_%d" % tier] = mix((mul(tone(base, n), env(n, 0.002, 0.12, release=0.05)), 0.6),
                                  (mul(tone(base * 1.5, n), env(n, 0.06, 0.15, release=0.05)), 0.5))
    n = secs(0.9)
    bell = mix((mul(tone(2093, n), env(n, 0.001, 0.35, release=0.1)), 0.5), (mul(tone(3136, n), env(n, 0.001, 0.25, release=0.1)), 0.35))
    drawer = mul(lowpass(noise(n), 900), env(n, 0.003, 0.08, release=0.05))
    s["cash_register"] = mix((drawer, 0.7), (bell, 1.0))
    n = secs(0.06)
    s["ui_hover"] = mul(tone(1600, n), env(n, 0.001, 0.02, release=0.01))
    n = secs(0.1)
    s["ui_click"] = mix((mul(tone(700, n, "square"), env(n, 0.0005, 0.02, release=0.01, curve=7)), 0.4),
                        (mul(highpass(noise(n), 2000), env(n, 0.0005, 0.01, release=0.005)), 0.5))
    n = secs(0.3)
    s["ui_deny"] = mul(tone(160, n, "square", vibrato=0.08, vib_rate=30), env(n, 0.002, 0.15, release=0.05))
    n = secs(0.03)
    s["case_tick"] = mul(tone(2600, n, "square"), env(n, 0.0005, 0.006, release=0.004, curve=8))
    for r, notes in enumerate([[72], [72, 76], [72, 76, 79], [72, 76, 79, 83], [72, 76, 79, 84, 88]]):
        n = secs(1.3)
        buf = [0.0] * n
        for k, m in enumerate(notes):
            start = secs(0.07 * k)
            part = mul(tone(note_hz(m), n - start), env(n - start, 0.002, 0.5, release=0.2))
            add(buf, start, part, 0.5)
        s["reveal_%d" % r] = echo(buf, 0.09, 0.3)
    n = secs(1.6)
    s["van_engine"] = drive(mix((mul(tone(48, n, "saw", vibrato=0.05, vib_rate=11), env(n, 0.2, None, release=0.4)), 0.8),
                                (mul(lowpass(noise(n), 300), env(n, 0.2, None, release=0.4)), 0.5)), 2.0)
    n = secs(0.8)
    s["van_brakes"] = mul(highpass(tone(2200, n, "saw", vibrato=0.02, vib_rate=40, sweep_to=1500), 1500), env(n, 0.02, 0.4, release=0.2))
    n = secs(0.5)
    s["van_doors"] = mix((mul(lowpass(noise(n), 400), env(n, 0.001, 0.08, release=0.05)), 1.0),
                         (mul(tone(80, n), env(n, 0.001, 0.1, release=0.05)), 0.9))
    n = secs(2.0)
    siren = []
    for i in range(n):
        t = i / SR
        f = 700 + 350 * math.sin(TAU * 0.5 * t)
        siren.append(f)
    ph, out = 0.0, []
    for f in siren:
        ph += f / SR
        out.append(math.sin(TAU * ph) * 0.7 + (2 * (ph % 1) - 1) * 0.3)
    s["alarm"] = out
    n = secs(0.25)
    s["camera_spot"] = mix((mul(tone(1320, n, "square"), env(n, 0.001, 0.06, release=0.03)), 0.4),
                           (mul(tone(1760, n, "square"), env(n, 0.09, 0.06, release=0.03)), 0.4))
    n = secs(0.18)
    s["stock_up"] = mul(tone(880, n, "sine", sweep_to=1320), env(n, 0.002, 0.08, release=0.04))
    s["stock_down"] = mul(tone(660, n, "sine", sweep_to=330), env(n, 0.002, 0.08, release=0.04))
    n = secs(0.8)
    beat = [0.0] * n
    for off in (0, secs(0.22)):
        part = mul(tone(55, secs(0.18), "sine", sweep_to=40), env(secs(0.18), 0.002, 0.08, release=0.04))
        add(beat, off, part, 1.0)
    s["heartbeat"] = lowpass(beat, 300)
    n = secs(2.2)
    stab = mix((mul(tone(note_hz(38), n, "saw"), env(n, 0.005, 0.9, release=0.3)), 0.6),
               (mul(tone(note_hz(45), n, "saw"), env(n, 0.005, 0.9, release=0.3)), 0.5),
               (mul(tone(note_hz(50), n, "saw", vibrato=0.01), env(n, 0.005, 0.9, release=0.3)), 0.5),
               (mul(lowpass(noise(n), 200), env(n, 0.001, 0.5, release=0.2)), 0.8))
    s["boss_intro"] = echo(drive(lowpass(stab, 1400), 1.6), 0.21, 0.35)
    n = secs(1.2)
    s["boss_phase"] = drive(mix((mul(tone(note_hz(40), n, "saw", sweep_to=note_hz(52)), env(n, 0.01, 0.6, release=0.2)), 0.8),
                                (mul(highpass(noise(n), 800), env(n, 0.3, 0.3, release=0.2)), 0.4)), 2.0)
    n = secs(2.6)
    fall = mix((mul(tone(note_hz(50), n, "saw", sweep_to=note_hz(26)), env(n, 0.005, 1.4, release=0.4)), 0.7),
               (mul(lowpass(noise(n), 250), env(n, 0.001, 0.9, release=0.3)), 1.0))
    s["boss_death"] = echo(drive(fall, 1.6), 0.25, 0.4)
    n = secs(0.18)
    s["stamp"] = mix((mul(lowpass(noise(n), 500), env(n, 0.0005, 0.05, release=0.03)), 1.0),
                     (mul(tone(70, n), env(n, 0.0005, 0.06, release=0.03)), 1.0))
    n = secs(0.5)
    s["paper"] = mul(highpass(noise(n), 1500), env(n, 0.05, 0.2, release=0.1))
    n = secs(0.05)
    s["typewriter"] = mix((mul(highpass(noise(n), 2500), env(n, 0.0005, 0.01, release=0.005, curve=8)), 0.6),
                          (mul(tone(400, n, "square"), env(n, 0.0005, 0.008, release=0.004)), 0.3))
    n = secs(1.3)
    s["explosion"] = drive(mix((mul(lowpass(noise(n, "brown"), 600), env(n, 0.002, 0.5, release=0.2)), 1.0),
                               (mul(tone(60, n, "sine", sweep_to=25), env(n, 0.002, 0.4, release=0.2)), 1.0)), 2.5)
    n = secs(1.2)
    s["laser_charge"] = mul(tone(300, n, "saw", sweep_to=1600, vibrato=0.01, vib_rate=20), env(n, 0.05, None, release=0.08))
    n = secs(0.2)
    s["deflect"] = mix((mul(tone(3200, n, "square", sweep_to=2200), env(n, 0.0005, 0.05, release=0.02)), 0.5),
                       (mul(highpass(noise(n), 3000), env(n, 0.0005, 0.03, release=0.02)), 0.5))
    n = secs(0.35)
    s["dog_bark"] = drive(mul(tone(420, n, "saw", sweep_to=260, vibrato=0.06, vib_rate=35), env(n, 0.005, 0.1, release=0.05)), 3.0)
    n = secs(0.6)
    s["drone"] = mul(tone(210, n, "saw", vibrato=0.02, vib_rate=60), env(n, 0.05, None, release=0.05))
    n = secs(0.3)
    s["radio"] = mix((mul(highpass(noise(n), 1800), env(n, 0.002, None, release=0.05)), 0.5),
                     (mul(tone(1000, n, "square"), env(n, 0.002, 0.05, release=0.02)), 0.25))
    n = secs(0.5)
    s["shutter"] = drive(mix((mul(lowpass(noise(n), 900), env(n, 0.001, 0.2, release=0.08)), 1.0),
                             (mul(tone(90, n, "square"), env(n, 0.001, 0.12, release=0.05)), 0.6)), 2.0)
    n = secs(0.25)
    s["dodge"] = mul(lowpass(noise(n), 1200), env(n, 0.03, 0.08, release=0.06))
    n = secs(0.5)
    s["chest_open"] = mix((mul(tone(180, n, "saw", sweep_to=140), env(n, 0.01, 0.2, release=0.1)), 0.5),
                          (mul(tone(note_hz(76), n), env(n, 0.15, 0.25, release=0.1)), 0.4))
    n = secs(0.4)
    s["door_bang"] = mix((mul(lowpass(noise(n), 350), env(n, 0.001, 0.1, release=0.05)), 1.0),
                         (mul(tone(60, n), env(n, 0.001, 0.12, release=0.05)), 1.0))
    n = secs(0.3)
    s["throw"] = mul(highpass(lowpass(noise(n), 2400), 500), env(n, 0.06, 0.12, release=0.08))
    n = secs(0.25)
    s["punch"] = drive(mix((mul(lowpass(noise(n), 450), env(n, 0.0008, 0.05, release=0.03)), 1.0),
                           (mul(tone(75, n, "sine", sweep_to=45), env(n, 0.0008, 0.07, release=0.03)), 1.0)), 2.2)
    n = secs(0.6)
    s["cloak"] = mul(tone(1800, n, "sine", sweep_to=500, vibrato=0.05, vib_rate=28), env(n, 0.02, 0.3, release=0.1))
    n = secs(0.7)
    s["scream"] = drive(mul(tone(760, n, "saw", sweep_to=520, vibrato=0.05, vib_rate=7), env(n, 0.02, 0.35, release=0.15)), 1.6)
    n = secs(0.09)
    s["beep"] = mul(tone(1400, n, "square"), env(n, 0.001, 0.04, release=0.02))
    s.update(kill_bank())
    return s


def droplets(n, count, cut, spread=1.0, seed=0):
    """A scatter of tiny wet ticks across the first `spread` of n samples."""
    r = random.Random(4400 + seed)
    buf = [0.0] * n
    for _ in range(count):
        m = secs(r.uniform(0.008, 0.03))
        part = mul(lowpass(noise(m), cut * r.uniform(0.6, 1.4)), env(m, 0.0005, m / SR * 0.4, release=0.004, curve=6))
        add(buf, int(r.uniform(0, spread) * (n - m)), part, r.uniform(0.25, 0.7))
    return buf


def kill_bank():
    """Kill layers: impact + body + fall, plus confirm ticks and stings.
    Percussive and tonal only: no voices."""
    s = {}
    # Flesh impacts: a wet thump with a slightly different body each time.
    for i, (cut, thump, length) in enumerate([(700, 95, 0.16), (900, 80, 0.18), (1100, 110, 0.14), (620, 70, 0.2)]):
        n = secs(length)
        s["flesh_%d" % (i + 1)] = drive(mix(
            (mul(lowpass(noise(n), cut), env(n, 0.0008, 0.05 + i * 0.01, release=0.03, curve=5)), 1.0),
            (mul(tone(thump, n, "sine", sweep_to=thump * 0.6), env(n, 0.0008, 0.06, release=0.03)), 0.9),
            (mul(highpass(noise(n), 3000), env(n, 0.0003, 0.006, release=0.003, curve=8)), 0.25),
            (droplets(n, 3, 1400, 0.6, i), 0.35)), 1.6)
    # Bone crunch: a knot of dry cracks over a thud.
    n = secs(0.32)
    crunch = [0.0] * n
    r = random.Random(77)
    for k in range(6):
        m = secs(r.uniform(0.012, 0.03))
        part = mul(highpass(noise(m), 1800 + k * 300), env(m, 0.0003, 0.008, release=0.004, curve=7))
        add(crunch, secs(0.006 + k * r.uniform(0.012, 0.03)), part, r.uniform(0.6, 1.0))
    s["bone_crunch"] = drive(mix((crunch, 1.0),
        (mul(tone(70, n, "sine", sweep_to=40), env(n, 0.001, 0.09, release=0.04)), 0.9),
        (mul(lowpass(noise(n), 500), env(n, 0.001, 0.07, release=0.04)), 0.6)), 2.0)
    # Wet splatter: a smear of noise and a spray of droplets.
    n = secs(0.45)
    s["splatter"] = mix((mul(lowpass(highpass(noise(n), 300), 1800), env(n, 0.002, 0.12, release=0.08, curve=4)), 0.8),
                        (droplets(n, 14, 2200, 0.8, 9), 0.9))
    # Gib burst: a wet explosion — brown-noise punch, low thump, droplets.
    n = secs(0.7)
    s["gib_burst"] = drive(mix((mul(lowpass(noise(n, "brown"), 900), env(n, 0.001, 0.18, release=0.1)), 1.0),
                               (mul(tone(58, n, "sine", sweep_to=32), env(n, 0.001, 0.2, release=0.1)), 1.0),
                               (droplets(n, 22, 2000, 0.9, 13), 0.8)), 2.2)
    # Body falls, matched to the floor.
    n = secs(0.45)
    base = mul(tone(62, n, "sine", sweep_to=44), env(n, 0.002, 0.09, release=0.05))
    s["fall_concrete"] = mix((base, 1.0), (mul(lowpass(noise(n), 700), env(n, 0.002, 0.08, release=0.05)), 0.8),
                             (mul(highpass(noise(n), 2500), env(n, 0.03, 0.08, release=0.05)), 0.15))
    s["fall_carpet"] = mix((base, 0.9), (mul(lowpass(noise(n), 260), env(n, 0.004, 0.07, release=0.05)), 0.9))
    n = secs(0.6)
    slap = mix((mul(tone(62, n, "sine", sweep_to=44), env(n, 0.002, 0.08, release=0.05)), 1.0),
               (mul(highpass(noise(n), 1600), env(n, 0.001, 0.03, release=0.02, curve=6)), 0.6))
    s["fall_marble"] = echo(slap, 0.06, 0.3)
    ring = mix((mul(tone(523, n), env(n, 0.001, 0.25, release=0.1)), 0.18),
               (mul(tone(1347, n), env(n, 0.001, 0.18, release=0.08)), 0.12),
               (mul(tone(2217, n), env(n, 0.001, 0.12, release=0.06)), 0.08))
    s["fall_metal"] = mix((slap, 0.9), (ring, 1.0))
    # A dropped gun clattering: three metal hits, each softer.
    n = secs(0.55)
    clat = [0.0] * n
    for k, (t, g) in enumerate([(0.0, 1.0), (0.09, 0.6), (0.2, 0.35), (0.27, 0.2)]):
        m = secs(0.08)
        hit = mix((mul(tone(1800 + k * 230, m, "square"), env(m, 0.0003, 0.012, release=0.006, curve=7)), 0.3),
                  (mul(tone(3100 - k * 180, m), env(m, 0.0003, 0.03, release=0.01)), 0.3),
                  (mul(highpass(noise(m), 2500), env(m, 0.0003, 0.01, release=0.005, curve=7)), 0.5))
        add(clat, secs(t), hit, g)
    s["clatter"] = clat
    # The kill registered: a crisp double tick; a crit rings a bell.
    n = secs(0.12)
    tick = [0.0] * n
    add(tick, 0, mul(tone(2400, secs(0.03)), env(secs(0.03), 0.0003, 0.01, release=0.005, curve=7)), 0.6)
    add(tick, secs(0.035), mul(tone(3200, secs(0.04)), env(secs(0.04), 0.0003, 0.015, release=0.008, curve=7)), 0.5)
    s["kill_tick"] = tick
    n = secs(0.7)
    s["crit_ding"] = mix((mul(tone(1568, n), env(n, 0.0008, 0.3, release=0.1)), 0.5),
                         (mul(tone(2349, n), env(n, 0.0008, 0.22, release=0.08)), 0.35),
                         (mul(tone(3951, n), env(n, 0.0008, 0.08, release=0.04)), 0.15))
    # Burn: a crackling sizzle.
    n = secs(0.8)
    crackle = droplets(n, 18, 5000, 0.95, 21)
    s["burn_sizzle"] = mix((mul(highpass(noise(n), 3500), env(n, 0.02, 0.35, release=0.2, curve=3)), 0.5), (crackle, 0.6))
    # Takedowns: a muffled slash, or a muffled crack.
    n = secs(0.3)
    swoosh = mul(highpass(lowpass(noise(n), 5000), 1200), env(n, 0.03, 0.05, release=0.03, curve=3))
    s["takedown_knife"] = mix((swoosh, 0.6), (mul(lowpass(noise(n), 500), env(n, 0.001, 0.06, release=0.03)), 0.9),
                              (mul(tone(85, n, "sine", sweep_to=55), env(n, 0.001, 0.07, release=0.03)), 0.6))
    s["takedown_crack"] = lowpass(drive(mix((crunch[:n] + [0.0] * max(0, n - len(crunch)), 0.8),
                                            (mul(tone(75, n, "sine", sweep_to=45), env(n, 0.001, 0.08, release=0.03)), 1.0)), 2.0), 2200)
    # Multi-kill stings: minor-key brass hits, rising and thickening.
    for count, notes in [(2, [57, 60]), (3, [57, 60, 64]), (4, [57, 60, 64, 67, 69])]:
        n = secs(1.0)
        buf = [0.0] * n
        for k, m in enumerate(notes):
            start = secs(0.055 * k)
            part = mul(lowpass(tone(note_hz(m), n - start, "saw", vibrato=0.004), 2200), env(n - start, 0.004, 0.35, release=0.15))
            add(buf, start, part, 0.28)
        add(buf, 0, mul(tone(note_hz(33), secs(0.5), "sine"), env(secs(0.5), 0.002, 0.2, release=0.1)), 0.7 if count >= 4 else 0.4)
        s["multi_%d" % count] = echo(drive(buf, 1.4), 0.12, 0.25)
    # THE RALLY: a rising ticker blip for a tier-up, a bell-and-drawer for a
    # cash-out, a falling crash for a panic sell.
    n = secs(0.5)
    up = [0.0] * n
    for k, m in enumerate([69, 73, 76, 81]):
        start = secs(0.045 * k)
        add(up, start, mul(tone(note_hz(m), n - start, "square"), env(n - start, 0.002, 0.12, release=0.06)), 0.22)
    s["combo_up"] = echo(lowpass(up, 4200), 0.07, 0.25)
    n = secs(0.8)
    chime = mix((mul(tone(1568, n), env(n, 0.001, 0.25, release=0.1)), 0.4),
                (mul(tone(2093, n), env(n, 0.04, 0.25, release=0.1)), 0.35),
                (mul(tone(2637, n), env(n, 0.08, 0.3, release=0.1)), 0.3))
    s["combo_cash"] = mix((chime, 1.0), (mul(lowpass(noise(n), 900), env(n, 0.002, 0.06, release=0.04)), 0.5))
    n = secs(1.0)
    fall = mul(tone(note_hz(64), n, "saw", sweep_to=note_hz(40)), env(n, 0.002, 0.5, release=0.2))
    s["combo_crash"] = drive(mix((lowpass(fall, 1600), 0.7),
                                 (mul(lowpass(noise(n, "brown"), 500), env(n, 0.001, 0.25, release=0.1)), 0.8)), 1.8)
    return s


# ----------------------------------------------------------------- music ----
class Song:
    def __init__(self, bpm, bars, beats=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = self.beat * beats * bars
        self.buf = zeros(self.length)
        self.bars = bars
        self.beats = beats

    def at(self, bar, beat):
        return secs((bar * self.beats + beat) * self.beat)

    def put(self, start, samples, gain):
        add(self.buf, start, samples, gain, wrap=True)


def bass(freq, dur, dist=1.0):
    n = secs(dur + 0.2)
    s = mix((tone(freq, n, "tri"), 0.8), (tone(freq * 2, n, "sine"), 0.2))
    s = lowpass(s, 600)
    s = mul(s, env(n, 0.01, dur * 0.9, sustain=0.0, release=0.12, curve=2.5))
    return drive(s, dist) if dist > 1.0 else s


def piano(freq, dur, bright=1.0):
    n = secs(dur + 0.8)
    parts = [(1, 1.0, 1.0), (2, 0.5 * bright, 1.8), (3, 0.25 * bright, 2.6), (4, 0.12 * bright, 3.5)]
    out = [0.0] * n
    for h, amp, speed in parts:
        e = env(n, 0.003, (dur + 0.6) / speed, release=0.2, curve=3.0)
        t = tone(freq * h * (1 + 0.0007 * h), n)
        for i in range(n):
            out[i] += t[i] * e[i] * amp
    hammer = mul(highpass(noise(secs(0.02)), 2000), env(secs(0.02), 0.0005, 0.01, release=0.005))
    add(out, 0, hammer, 0.15)
    return out


def epiano(freqs, dur):
    n = secs(dur + 0.5)
    out = [0.0] * n
    for f in freqs:
        e = env(n, 0.005, dur + 0.3, release=0.25, curve=2.0)
        a = tone(f, n)
        b = tone(f * 2.01, n)
        for i in range(n):
            trem = 0.85 + 0.15 * math.sin(TAU * 4.5 * i / SR)
            out[i] += (a[i] + 0.35 * b[i] * e[i]) * e[i] * trem
    return out


def pad(freqs, dur, cut=1200):
    n = secs(dur)
    out = [0.0] * n
    for f in freqs:
        for d in (-0.004, 0.004):
            t = tone(f, n, "saw", detune=d)
            for i in range(n):
                out[i] += t[i]
    out = lowpass(out, cut)
    return mul(out, env(n, dur * 0.25, None, release=dur * 0.3))


def brass(freq, dur):
    n = secs(dur + 0.15)
    s = tone(freq, n, "saw", vibrato=0.006, vib_rate=5.5)
    s = lowpass(s, 1600)
    return drive(mul(s, env(n, 0.03, dur, sustain=0.6, release=0.12, curve=2.0)), 1.5)


def kick():
    n = secs(0.35)
    return mul(tone(110, n, "sine", sweep_to=40), env(n, 0.001, 0.12, release=0.05, curve=4))


def snare(brush=False):
    n = secs(0.3 if not brush else 0.25)
    if brush:
        return mul(lowpass(highpass(noise(n), 1500), 6000), env(n, 0.02, 0.12, release=0.06, curve=3))
    return mix((mul(highpass(noise(n), 1200), env(n, 0.001, 0.08, release=0.05, curve=4)), 0.8),
               (mul(tone(190, n), env(n, 0.001, 0.05, release=0.03)), 0.5))


def hat(open_hat=False):
    n = secs(0.25 if open_hat else 0.06)
    return mul(highpass(noise(n), 6000), env(n, 0.0005, 0.12 if open_hat else 0.02, release=0.02, curve=5))


def ride():
    n = secs(0.5)
    metal = mix(*[(tone(f, n, "square"), 0.2) for f in (3150, 4270, 5190, 6600)])
    return mul(highpass(metal, 4000), env(n, 0.001, 0.3, release=0.1, curve=3))


def vinyl(song, level=0.04):
    for i in range(len(song.buf)):
        song.buf[i] += rng.uniform(-1, 1) * level * 0.06
        if rng.random() < 0.0004:
            song.buf[i] += rng.uniform(-1, 1) * level * 3


# D minor: i - VI - iv - V7
PROG = [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52, 55]]
ROOTS = [38, 34, 31, 33]
SCALE = [62, 64, 65, 67, 69, 70, 72, 74, 76, 77]


def walking_bass(song, gain=0.55, per_bar_chords=2):
    for bar in range(song.bars):
        chord = (bar // per_bar_chords) % 4
        root = ROOTS[chord]
        line = [root, root + 7, root + 12, root + 10] if bar % 2 == 0 else [root + 12, root + 10, root + 7, root + 4]
        for b in range(song.beats):
            song.put(song.at(bar, b), bass(note_hz(line[b % 4]), song.beat * 0.95), gain)


def song_menu():
    s = Song(72, 8)
    walking_bass(s, 0.5, 2)
    for bar in range(s.bars):
        chord = (bar // 2) % 4
        s.put(s.at(bar, 0), epiano([note_hz(m + 12) for m in PROG[chord]], s.beat * 3.5), 0.12)
        for b in (1, 3):
            s.put(s.at(bar, b), snare(True), 0.18)
        for b in range(4):
            s.put(s.at(bar, b), ride(), 0.05)
    motif = [(0, 0, 74, 1.5), (0, 2, 72, 0.5), (0, 3, 70, 1), (1, 0, 69, 2.5),
             (4, 0, 74, 1.5), (4, 2, 77, 0.5), (4, 3, 76, 1), (5, 0, 73, 2.5)]
    for bar, beat, m, d in motif:
        s.put(s.at(bar, beat), brass(note_hz(m), s.beat * d), 0.1)
    vinyl(s, 0.05)
    return s.buf


def song_hideout():
    s = Song(96, 16)
    walking_bass(s, 0.5, 2)
    for bar in range(s.bars):
        chord = (bar // 2) % 4
        for b in (0, 2):
            s.put(s.at(bar, b + 0.66), epiano([note_hz(m + 12) for m in PROG[chord]], s.beat * 0.6), 0.1)
        for b in range(4):
            s.put(s.at(bar, b), ride(), 0.05)
            s.put(s.at(bar, b + 0.66), ride(), 0.03)
        s.put(s.at(bar, 1), snare(True), 0.14)
        s.put(s.at(bar, 3), snare(True), 0.14)
        if bar % 2 == 1:
            for k in range(3):
                m = rng.choice(SCALE)
                s.put(s.at(bar, k * 1.33), piano(note_hz(m), s.beat * 0.8), 0.08)
    vinyl(s, 0.03)
    return s.buf


def song_heist(layer):
    s = Song(100, 16)
    for bar in range(s.bars):
        chord = (bar // 2) % 4
        root = ROOTS[chord]
        if layer == "stealth":
            for e in range(8):
                s.put(s.at(bar, e * 0.5), bass(note_hz(root), s.beat * 0.4), 0.4 if e % 2 == 0 else 0.25)
            for q in range(16):
                s.put(s.at(bar, q * 0.25), hat(), 0.05 if q % 4 else 0.09)
            if bar % 4 == 0:
                s.put(s.at(bar, 0), pad([note_hz(m) for m in PROG[chord]], s.beat * 8, 700), 0.05)
            if bar % 2 == 1:
                s.put(s.at(bar, 3.5), piano(note_hz(PROG[chord][2] + 24), s.beat * 0.6, 0.6), 0.08)
        else:
            for b in range(4):
                s.put(s.at(bar, b), kick(), 0.5 if b % 2 == 0 else 0.3)
            s.put(s.at(bar, 1), snare(), 0.3)
            s.put(s.at(bar, 3), snare(), 0.3)
            for q in range(8):
                s.put(s.at(bar, q * 0.5), hat(q % 2 == 1), 0.07)
            for e in range(8):
                step = [0, 0, 12, 0, 10, 0, 7, 3][e]
                s.put(s.at(bar, e * 0.5), bass(note_hz(root + step), s.beat * 0.45, 2.2), 0.35)
            if bar % 2 == 0:
                for k, m in enumerate(PROG[chord][:3]):
                    s.put(s.at(bar, 0), brass(note_hz(m + 12), s.beat * 0.9), 0.07)
            s.put(s.at(bar, 2.5), brass(note_hz(PROG[chord][0] + 24), s.beat * 0.4), 0.06)
    return s.buf


def song_boss():
    s = Song(132, 16)
    riff = [0, 0, 3, 0, 5, 0, 6, 5]
    for bar in range(s.bars):
        chord = [0, 0, 2, 3][(bar // 4) % 4]
        root = ROOTS[chord]
        for b in range(4):
            s.put(s.at(bar, b), kick(), 0.55)
            s.put(s.at(bar, b + 0.5), kick(), 0.2 if b % 2 else 0.0)
        s.put(s.at(bar, 1), snare(), 0.35)
        s.put(s.at(bar, 3), snare(), 0.35)
        for q in range(8):
            s.put(s.at(bar, q * 0.5), hat(), 0.06)
            s.put(s.at(bar, q * 0.5), bass(note_hz(root + riff[q]), s.beat * 0.45, 3.0), 0.38)
        if bar % 4 == 0:
            s.put(s.at(bar, 0), pad([note_hz(m) for m in PROG[chord]], s.beat * 16, 900), 0.06)
            s.put(s.at(bar, 0), brass(note_hz(PROG[chord][0] + 12), s.beat * 1.5), 0.12)
        if bar % 2 == 1:
            s.put(s.at(bar, 2), brass(note_hz(PROG[chord][2] + 12), s.beat * 0.5), 0.1)
            s.put(s.at(bar, 3), brass(note_hz(PROG[chord][1] + 12), s.beat * 0.5), 0.1)
    return s.buf


def song_ending():
    s = Song(70, 12)
    for bar in range(s.bars):
        chord = (bar // 2) % 4
        root = ROOTS[chord]
        s.put(s.at(bar, 0), bass(note_hz(root), s.beat * 3.8), 0.4)
        s.put(s.at(bar, 0), pad([note_hz(m) for m in PROG[chord]], s.beat * 4, 900), 0.05)
        for k, m in enumerate(PROG[chord]):
            s.put(s.at(bar, k * 0.5), piano(note_hz(m + 12), s.beat * 2.5), 0.09)
    melody = [(0, 0, 74, 2), (0, 2, 72, 2), (1, 0, 70, 3), (2, 0, 69, 2), (2, 2, 70, 2), (3, 0, 73, 3),
              (4, 0, 74, 2), (4, 2, 77, 2), (5, 0, 76, 2), (5, 2, 74, 2), (6, 0, 72, 4), (8, 0, 74, 4), (10, 0, 62, 6)]
    for bar, beat, m, d in melody:
        s.put(s.at(bar, beat), brass(note_hz(m), s.beat * d), 0.09)
    vinyl(s, 0.03)
    return s.buf


def main():
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    only = sys.argv[1] if len(sys.argv) > 1 else "all"
    random.seed(1977)
    if only in ("all", "sfx"):
        for name, buf in sfx_bank().items():
            path = os.path.join(SFX_DIR, name + ".wav")
            if only == "all" and os.path.exists(path):
                continue    # keep existing takes; "sfx" regenerates every file
            write(path, buf)
        print("sfx written")
    if only in ("all", "music"):
        tracks = {
            "menu": song_menu, "hideout": song_hideout,
            "heist_stealth": lambda: song_heist("stealth"), "heist_combat": lambda: song_heist("combat"),
            "boss": song_boss, "ending": song_ending,
        }
        for name, fn in tracks.items():
            if only == "all" and os.path.exists(os.path.join(MUSIC_DIR, name + ".wav")):
                continue
            write(os.path.join(MUSIC_DIR, name + ".wav"), fn(), 0.8)
            print("music", name)


if __name__ == "__main__":
    main()
