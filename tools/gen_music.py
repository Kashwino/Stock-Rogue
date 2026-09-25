#!/usr/bin/env python3
"""Adaptive music for Stock Rogue (standard library only).

Noir-jazz stems that loop seamlessly and layer in sync:

  Shared stems (96 BPM, A minor) — every stage plays these, pitch-scaled to
  its own tempo (City 104 = x1.0833 ...), so one set serves all four stages:
      drums_brush  drums_combat  wanted3  wanted4  wanted5  combo_a  combo_b
  Stage stems (the stage's BPM, the same key scaled by the same ratio, so
  they sit in tune with the pitch-scaled shared stems):
      <stage>_explore  <stage>_tension  <stage>_combat
      stages: town 96 · city 104 · world 112 · doomsday 124
  Themes: boss_<id> and boss_<id>_hi (the phase-2 intensity layer) for the
  Landlord, Auditor, Ambassador and Chairman; verdict; map; and the ending
  families rule / escape / collapse / retire / busted.

Every stage stem is 8 bars; boss themes and endings 4 bars. 22,050 Hz mono
16-bit WAV (Godot compresses them on import). Deterministic.

    python3 tools/gen_music.py           # writes missing files
    python3 tools/gen_music.py all       # regenerates everything
    python3 tools/gen_music.py town      # one stage / theme by name prefix
"""
import array
import math
import os
import random
import struct
import sys
import wave

SR = 22050
TAU = math.tau
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "music")
BASE_BPM = 96.0
STAGES = {"town": 96.0, "city": 104.0, "world": 112.0, "doomsday": 124.0}
rng = random.Random(1955)

# i - VI - iv - V7 in A minor, one chord per two bars (8 bars).
PROG = [[57, 60, 64, 67], [53, 57, 60, 64], [50, 53, 57, 60], [52, 56, 59, 62]]
ROOTS = [45, 41, 38, 40]
# Motifs: (midi, beat, beats) over 8 bars. A recognizable hook per stage/boss.
MOTIFS = {
    "town": [(69, 0, 1), (72, 1, 1), (76, 2, 1.5), (74, 3.5, 0.5), (72, 4, 1), (69, 5, 1), (67, 6, 1), (69, 7, 1)],
    "city": [(76, 0, 1.5), (74, 1.5, 0.5), (72, 2, 1), (71, 3, 1), (69, 4, 1), (72, 5, 1), (71, 6, 1), (64, 7, 1)],
    "world": [(69, 0, 1), (70, 1, 0.5), (73, 1.5, 0.5), (74, 2, 1), (76, 3, 1), (77, 4, 1.5), (76, 5.5, 0.5), (73, 6, 2)],
    "doomsday": [(69, 0, 0.5), (69, 0.5, 0.5), (72, 1, 1), (69, 2, 0.5), (75, 2.5, 1.5), (76, 4, 2), (75, 6, 1), (69, 7, 1)],
    "landlord": [(57, 0, 1), (64, 1, 1), (65, 2, 1.5), (64, 3.5, 0.5), (62, 4, 1), (60, 5, 3)],
    "auditor": [(76, 0, 0.5), (76, 0.5, 0.5), (76, 1, 0.5), (77, 1.5, 0.5), (76, 2, 1), (75, 3, 1), (76, 4, 4)],
    "ambassador": [(72, 0, 1), (76, 1, 1), (80, 2, 1), (83, 3, 1.5), (81, 4.5, 3.5)],
    "chairman": [(69, 0, 1), (72, 1, 1), (71, 2, 1), (76, 3, 1), (74, 4, 1), (72, 5, 1), (71, 6, 1), (69, 7, 1)],
}


# ---------------------------------------------------------------- engine ----
class Track:
    """A loop `bars` long at `bpm`. Everything written wraps around, so note
    tails ring into the start and the loop point is seamless."""

    def __init__(self, bpm, bars=8, tune=1.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.tune = tune
        self.n = int(round(bars * 4 * self.beat * SR))
        self.buf = array.array("f", [0.0]) * self.n

    def at(self, beat):
        return int(round(beat * self.beat * SR))

    def put(self, beat, samples, gain=1.0):
        start = self.at(beat)
        n = self.n
        buf = self.buf
        for i, v in enumerate(samples):
            buf[(start + i) % n] += v * gain

    def hz(self, midi):
        return 440.0 * 2 ** ((midi - 69) / 12.0) * self.tune


def osc(freq, n, shape="sine", vib=0.0, vib_rate=5.0, glide_to=None):
    out = [0.0] * n
    ph = rng.random()
    for i in range(n):
        f = freq if glide_to is None else freq + (glide_to - freq) * i / max(1, n - 1)
        if vib:
            f *= 1.0 + vib * math.sin(TAU * vib_rate * i / SR)
        ph += f / SR
        p = ph - int(ph)
        if shape == "sine":
            out[i] = math.sin(TAU * p)
        elif shape == "tri":
            out[i] = 4.0 * abs(p - 0.5) - 1.0
        elif shape == "saw":
            out[i] = 2.0 * p - 1.0
        else:
            out[i] = 1.0 if p < 0.5 else -1.0
    return out


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.1):
    """Attack, decay to sustain, release at the end of n samples."""
    a_n, d_n, r_n = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    out = [0.0] * n
    for i in range(n):
        if i < a_n:
            v = i / a_n
        elif i < a_n + d_n:
            v = 1.0 - (1.0 - s) * (i - a_n) / d_n
        else:
            v = s
        if i > n - r_n:
            v *= max(0.0, (n - i) / r_n)
        out[i] = v
    return out


def lp(samples, cutoff):
    """One-pole low-pass."""
    k = 1.0 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = [0.0] * len(samples)
    for i, x in enumerate(samples):
        y += k * (x - y)
        out[i] = y
    return out


def hp(samples, cutoff):
    low = lp(samples, cutoff)
    return [x - y for x, y in zip(samples, low)]


def noise(n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def shaped(samples, env):
    return [x * e for x, e in zip(samples, env)]


def soft(samples, amount):
    t = math.tanh(amount)
    return [math.tanh(x * amount) / t for x in samples]


def reverb(buf, mix=0.22):
    """Schroeder reverb (4 combs + 2 allpasses), run over the loop twice so
    the tail wraps into the start."""
    n = len(buf)
    doubled = list(buf) + list(buf)
    wet = [0.0] * len(doubled)
    for delay, fb in ((1557, 0.77), (1617, 0.76), (1491, 0.75), (1422, 0.74)):
        d = delay // 2
        line = [0.0] * len(doubled)
        for i in range(len(doubled)):
            y = doubled[i] + (line[i - d] * fb if i >= d else 0.0)
            line[i] = y
            wet[i] += y * 0.25
    for delay, g in ((225, 0.5), (556, 0.5)):
        d = delay // 2
        out = [0.0] * len(wet)
        for i in range(len(wet)):
            xd = wet[i - d] if i >= d else 0.0
            yd = out[i - d] if i >= d else 0.0
            out[i] = -g * wet[i] + xd + g * yd
        wet = out
    tail = wet[n:]
    return array.array("f", [buf[i] + tail[i] * mix for i in range(n)])


# ------------------------------------------------------------ instruments ---
_cache = {}


def cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


def kick(soft_kick=False):
    def make():
        n = int(0.32 * SR)
        body = osc(105.0, n, "sine", glide_to=42.0)
        return shaped(body, adsr(n, 0.001, 0.14, 0.0, 0.05)) if not soft_kick else lp(shaped(body, adsr(n, 0.004, 0.12, 0.0, 0.05)), 300)
    return cached(("kick", soft_kick), make)


def snare():
    def make():
        n = int(0.26 * SR)
        return [a * 0.8 + b * 0.4 for a, b in zip(shaped(hp(noise(n), 1400), adsr(n, 0.001, 0.09, 0.0, 0.05)),
                                                   shaped(osc(185.0, n, "tri"), adsr(n, 0.001, 0.05, 0.0, 0.03)))]
    return cached("snare", make)


def brush():
    def make():
        n = int(0.24 * SR)
        return shaped(lp(hp(noise(n), 1800), 6000), adsr(n, 0.02, 0.12, 0.0, 0.06))
    return cached("brush", make)


def hat(open_hat=False):
    def make():
        n = int((0.22 if open_hat else 0.05) * SR)
        return shaped(hp(noise(n), 6500), adsr(n, 0.0005, 0.12 if open_hat else 0.02, 0.0, 0.02))
    return cached(("hat", open_hat), make)


def ride():
    def make():
        n = int(0.5 * SR)
        metal = [0.0] * n
        for f in (3150.0, 4270.0, 5190.0, 6600.0):
            for i, v in enumerate(osc(f, n, "square")):
                metal[i] += v * 0.2
        return shaped(hp(metal, 4000), adsr(n, 0.001, 0.3, 0.0, 0.1))
    return cached("ride", make)


def tom(freq):
    def make():
        n = int(0.4 * SR)
        return shaped(osc(freq, n, "sine", glide_to=freq * 0.6), adsr(n, 0.001, 0.2, 0.0, 0.1))
    return cached(("tom", freq), make)


def bass_note(freq, dur, dist=1.0):
    def make():
        n = int((dur + 0.15) * SR)
        s = [a * 0.8 + b * 0.25 for a, b in zip(osc(freq, n, "tri"), osc(freq * 2.0, n, "sine"))]
        s = shaped(lp(s, 650), adsr(n, 0.008, dur * 0.8, 0.0, 0.1))
        return soft(s, dist) if dist > 1.0 else s
    return cached(("bass", round(freq, 2), round(dur, 3), dist), make)


def epiano(freqs, dur):
    n = int((dur + 0.5) * SR)
    out = [0.0] * n
    for f in freqs:
        e = adsr(n, 0.005, dur, 0.3, 0.3)
        a = osc(f, n)
        b = osc(f * 2.01, n)
        for i in range(n):
            out[i] += (a[i] + 0.3 * b[i]) * e[i] * (0.86 + 0.14 * math.sin(TAU * 4.5 * i / SR))
    return out


def vibes(freq, dur):
    n = int((dur + 0.9) * SR)
    e = adsr(n, 0.002, 0.8, 0.0, 0.4)
    a, b = osc(freq, n), osc(freq * 4.0, n)
    return [(x + 0.2 * y) * v * (0.8 + 0.2 * math.sin(TAU * 5.5 * i / SR)) for i, (x, y, v) in enumerate(zip(a, b, e))]


def pad(freqs, dur, cut=1100):
    n = int(dur * SR)
    out = [0.0] * n
    for f in freqs:
        for det in (-0.004, 0.004):
            for i, v in enumerate(osc(f * (1.0 + det), n, "saw")):
                out[i] += v
    return shaped(lp(out, cut), adsr(n, dur * 0.25, 0.1, 1.0, dur * 0.3))


def brass(freq, dur, bright=1600):
    n = int((dur + 0.12) * SR)
    s = lp(osc(freq, n, "saw", vib=0.006, vib_rate=5.5), bright)
    return soft(shaped(s, adsr(n, 0.025, 0.1, 0.65, 0.1)), 1.5)


def stab(freqs, dur=0.18):
    n = int((dur + 0.1) * SR)
    out = [0.0] * n
    for f in freqs:
        for i, v in enumerate(lp(osc(f, n, "saw"), 2200)):
            out[i] += v
    return soft(shaped(out, adsr(n, 0.004, dur, 0.0, 0.06)), 1.4)


def lead(freq, dur, vib=0.008):
    n = int((dur + 0.1) * SR)
    s = lp([a * 0.7 + b * 0.3 for a, b in zip(osc(freq, n, "saw", vib=vib, vib_rate=5.8), osc(freq * 1.003, n, "square"))], 2600)
    return shaped(s, adsr(n, 0.02, 0.15, 0.7, 0.08))


def pluck(freq, dur):
    n = int((dur + 0.4) * SR)
    return shaped(lp(osc(freq, n, "tri"), 2400), adsr(n, 0.002, 0.25, 0.0, 0.2))


def crackle(t, level=0.03):
    for i in range(t.n):
        t.buf[i] += rng.uniform(-1, 1) * level * 0.05
        if rng.random() < 0.0004:
            t.buf[i] += rng.uniform(-1, 1) * level * 2.5


def chord_of(bar, bars_per_chord=2):
    return (bar // bars_per_chord) % 4


# ----------------------------------------------------------------- stems ----
def walking(t, gain=0.5, dist=1.0):
    for bar in range(t.bars):
        c = chord_of(bar)
        root = ROOTS[c]
        line = [root, root + 7, root + 12, root + 10] if bar % 2 == 0 else [root + 12, root + 10, root + 7, root + 4]
        for b in range(4):
            t.put(bar * 4 + b, bass_note(t.hz(line[b]), t.beat * 0.92, dist), gain)


def motif(t, name, voice="vibes", octave=0, gain=0.3, bars=(0, 4)):
    for start_bar in bars:
        for midi, beat, beats in MOTIFS[name]:
            f = t.hz(midi + 12 * octave)
            dur = beats * t.beat
            s = vibes(f, dur) if voice == "vibes" else (brass(f, dur) if voice == "brass" else (lead(f, dur) if voice == "lead" else pluck(f, dur)))
            t.put(start_bar * 4 + beat, s, gain)


def stem_explore(stage, bpm):
    t = Track(bpm, 8, bpm / BASE_BPM)
    walking(t, 0.45)
    for bar in range(8):
        c = chord_of(bar)
        voicing = [t.hz(m) for m in PROG[c]]
        t.put(bar * 4 + (0 if bar % 2 == 0 else 1.5), epiano(voicing, t.beat * 1.4), 0.06)
    motif(t, stage, "vibes", 0, 0.22, bars=(0, 4))
    crackle(t, 0.03)
    t.buf = reverb(t.buf, 0.18)
    return t


def stem_tension(stage, bpm):
    t = Track(bpm, 8, bpm / BASE_BPM)
    for c in range(4):
        voicing = [t.hz(m - 12) for m in PROG[c]]
        t.put(c * 8, pad(voicing, t.beat * 8.2, 900), 0.05)
    # Tremolo strings: a pulsing fifth over the bass note.
    for bar in range(8):
        root = ROOTS[chord_of(bar)] + 12
        n = int(t.beat * 4 * SR)
        trem = [v * (0.5 + 0.5 * math.sin(TAU * 7.0 * i / SR)) for i, v in enumerate(lp(osc(t.hz(root + 7), n, "saw"), 1400))]
        t.put(bar * 4, shaped(trem, adsr(n, 0.05, 0.1, 0.8, 0.1)), 0.05)
    # Motif fragment, low and slow, on bars 3 and 7.
    for bar in (2, 6):
        for midi, beat, beats in MOTIFS[stage][:3]:
            t.put(bar * 4 + beat * 1.3, pluck(t.hz(midi - 12), beats * t.beat * 1.3), 0.2)
    t.buf = reverb(t.buf, 0.28)
    return t


def stem_combat(stage, bpm):
    t = Track(bpm, 8, bpm / BASE_BPM)
    for bar in range(8):
        root = ROOTS[chord_of(bar)]
        for e in range(8):
            midi = root if e % 2 == 0 else root + (12 if e % 4 == 1 else 7)
            t.put(bar * 4 + e * 0.5, bass_note(t.hz(midi), t.beat * 0.45, 2.0), 0.4)
        voicing = [t.hz(m) for m in PROG[chord_of(bar)][:3]]
        for b in (1.5, 3.5):
            t.put(bar * 4 + b, stab(voicing), 0.09)
    motif(t, stage, "brass", 0, 0.16, bars=(4,))
    return t


def shared_drums_brush():
    t = Track(BASE_BPM, 8)
    for bar in range(8):
        base = bar * 4
        t.put(base, kick(True), 0.4)
        t.put(base + 2.66, kick(True), 0.25)
        for b in (1, 3):
            t.put(base + b, brush(), 0.35)
        for b in (0, 1, 1.66, 2, 3, 3.66):
            t.put(base + b, ride(), 0.1)
    return t


def shared_drums_combat():
    t = Track(BASE_BPM, 8)
    for bar in range(8):
        base = bar * 4
        for b in (0, 1.5, 2):
            t.put(base + b, kick(), 0.55)
        for b in (1, 3):
            t.put(base + b, snare(), 0.4)
        for e in range(8):
            t.put(base + e * 0.5, hat(), 0.16 if e % 2 else 0.22)
        t.put(base + 3.5, hat(True), 0.14)
    return t


def shared_wanted3():
    t = Track(BASE_BPM, 8)
    for bar in range(8):
        base = bar * 4
        for e in range(8):
            t.put(base + e * 0.5, tom(95.0 if e % 4 == 0 else 130.0), 0.3 if e % 2 == 0 else 0.18)
        if bar % 2 == 1:
            for k in range(8):
                t.put(base + 2 + k * 0.25, snare(), 0.1 + 0.02 * k)
        voicing = [t.hz(m) for m in PROG[chord_of(bar)][:3]]
        for b in (0.5, 2.5):
            t.put(base + b, stab(voicing, 0.14), 0.1)
    return t


def shared_wanted4():
    t = Track(BASE_BPM, 8)
    for bar in range(8):
        root = ROOTS[chord_of(bar)] - 12
        for e in range(8):
            t.put(bar * 4 + e * 0.5, bass_note(t.hz(root + (12 if e % 2 else 0)), t.beat * 0.45, 3.0), 0.35)
    # The siren motif: a gliding two-tone wail every two bars.
    for bar in range(0, 8, 2):
        n = int(t.beat * 4 * SR)
        up = lp(osc(t.hz(76), n // 2, "saw", glide_to=t.hz(81)), 2000)
        down = lp(osc(t.hz(81), n // 2, "saw", glide_to=t.hz(76)), 2000)
        wail = up + down
        t.put(bar * 4 + 4, shaped(wail, adsr(len(wail), 0.1, 0.2, 0.8, 0.2)), 0.06)
    return t


def shared_wanted5():
    t = Track(BASE_BPM, 8)
    for bar in range(8):
        base = bar * 4
        for s16 in range(16):
            t.put(base + s16 * 0.25, hat(), 0.12 if s16 % 2 else 0.18)
        voicing = [t.hz(m) for m in PROG[chord_of(bar)]]
        t.put(base, stab(voicing, 0.35), 0.12)
        arp = PROG[chord_of(bar)]
        for s16 in range(16):
            t.put(base + s16 * 0.25, pluck(t.hz(arp[s16 % 4] + 12), t.beat * 0.22), 0.08)
    return t


def shared_combo_a():
    t = Track(BASE_BPM, 8)
    for bar in range(8):
        base = bar * 4
        for s16 in range(16):
            if s16 % 4 != 0:
                t.put(base + s16 * 0.25, hat(), 0.1)
        root = ROOTS[chord_of(bar)] + 12
        for b, off in ((0, 0), (0.75, 7), (1.5, 12), (2.5, 10), (3.25, 7)):
            n = int(t.beat * 0.3 * SR)
            t.put(base + b, shaped(lp(osc(t.hz(root + off), n, "square"), 1800), adsr(n, 0.002, 0.08, 0.2, 0.04)), 0.1)
    return t


def shared_combo_b():
    t = Track(BASE_BPM, 8)
    phrase = [(76, 0, 1.5), (79, 1.5, 0.5), (81, 2, 2), (79, 4, 1), (76, 5, 1), (74, 6, 2),
              (72, 8, 1.5), (74, 9.5, 0.5), (76, 10, 2), (81, 12, 1), (79, 13, 1), (76, 14, 2)]
    for rep in (0, 16):
        for midi, beat, beats in phrase:
            t.put(rep + beat, lead(t.hz(midi), beats * t.beat), 0.12)
    return t


# ----------------------------------------------------------------- themes ---
BOSSES = {"landlord": 100.0, "auditor": 118.0, "ambassador": 108.0, "chairman": 128.0}


def boss_theme(name, bpm, hi=False):
    t = Track(bpm, 4)
    if not hi:
        for bar in range(4):
            base = bar * 4
            for b in (0, 2, 2.5):
                t.put(base + b, kick(), 0.5)
            for b in (1, 3):
                t.put(base + b, snare(), 0.32)
            root = ROOTS[bar % 4] - 12
            for e in range(8):
                t.put(base + e * 0.5, bass_note(t.hz(root + (7 if e == 6 else 0)), t.beat * 0.45, 2.5), 0.35)
            t.put(base, pad([t.hz(m - 12) for m in PROG[bar % 4]], t.beat * 4.1, 800), 0.04)
        motif(t, name, "brass" if name != "auditor" else "pluck", 0, 0.2, bars=(0,))
    else:
        for bar in range(4):
            base = bar * 4
            for s16 in range(16):
                t.put(base + s16 * 0.25, hat(), 0.12)
            for e in range(4):
                t.put(base + e + 0.5, tom(110.0), 0.25)
            t.put(base, stab([t.hz(m) for m in PROG[bar % 4][:3]], 0.3), 0.1)
        motif(t, name, "lead", 1, 0.1, bars=(0,))
    return t


def theme_verdict():
    t = Track(70.0, 4)
    for bar in range(4):
        base = bar * 4
        t.put(base, kick(True), 0.5)
        t.put(base + 0.35, kick(True), 0.3)
        for b in range(4):
            n = int(0.03 * SR)
            t.put(base + b, shaped(hp(noise(n), 3000), adsr(n, 0.0005, 0.01, 0.0, 0.005)), 0.2)
    t.put(0, pad([t.hz(m - 12) for m in (45, 52, 60)], t.beat * 16, 700), 0.07)
    for i, (m, b) in enumerate(((69, 2), (72, 3), (71, 6), (64, 7), (69, 10), (68, 14))):
        t.put(b, pluck(t.hz(m), t.beat * 1.5), 0.2)
    t.buf = reverb(t.buf, 0.35)
    return t


def theme_map():
    t = Track(90.0, 8)
    walking(t, 0.35)
    for bar in range(8):
        base = bar * 4
        for b in (1, 3):
            t.put(base + b, brush(), 0.25)
        for b in (0, 2, 2.66):
            t.put(base + b, ride(), 0.07)
        voicing = [t.hz(m) for m in PROG[chord_of(bar)]]
        t.put(base + (0.5 if bar % 2 else 0), epiano(voicing, t.beat * 1.2), 0.05)
    for midi, beat, beats in [(72, 0, 1), (71, 1, 1), (69, 2, 2), (64, 16, 1), (67, 17, 1), (69, 18, 2)]:
        t.put(beat, pluck(t.hz(midi), beats * t.beat), 0.18)
    crackle(t, 0.04)
    t.buf = reverb(t.buf, 0.2)
    return t


def theme_ending(family):
    if family == "rule":
        t = Track(76.0, 4)
        for bar in range(4):
            t.put(bar * 4, pad([t.hz(m - 12) for m in ([45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59], [40, 47, 52, 56])[bar]], t.beat * 4.1, 1400), 0.06)
            t.put(bar * 4, kick(), 0.45)
            t.put(bar * 4 + 2, tom(80.0), 0.3)
        for midi, beat, beats in MOTIFS["chairman"]:
            t.put(beat * 2, brass(t.hz(midi), beats * 2 * t.beat), 0.16)
    elif family == "escape":
        t = Track(92.0, 4)
        for bar in range(4):
            base = bar * 4
            chord = ([57, 60, 64], [62, 65, 69], [64, 68, 71], [57, 60, 64])[bar]
            for b in (0, 1.5, 2, 3):
                t.put(base + b, pluck(t.hz(chord[int(b) % 3]), t.beat * 0.8), 0.14)
            for b in (0, 1.5, 3):
                t.put(base + b, bass_note(t.hz(chord[0] - 24), t.beat * 0.9), 0.3)
            for b in (0.5, 1, 2.5, 3.5):
                t.put(base + b, brush(), 0.18)
        t.buf = reverb(t.buf, 0.3)
    elif family == "collapse":
        t = Track(66.0, 4)
        for bar in range(4):
            t.put(bar * 4, pad([t.hz(m - 12) * (1.0 - 0.01 * bar) for m in (45, 51, 56)], t.beat * 4.1, 700), 0.07)
            t.put(bar * 4, tom(60.0), 0.4)
        for i, m in enumerate((76, 75, 72, 69, 68, 63)):
            t.put(i * 2.5, lead(t.hz(m), t.beat * 2.0, 0.02), 0.08)
        t.buf = reverb(t.buf, 0.4)
    elif family == "retire":
        t = Track(72.0, 4)
        walking(t, 0.3)
        for bar in range(4):
            voicing = [t.hz(m) for m in ([60, 64, 67, 71], [57, 60, 64, 67], [62, 65, 69, 72], [55, 59, 62, 65])[bar]]
            t.put(bar * 4, epiano(voicing, t.beat * 3.5), 0.07)
        for midi, beat, beats in [(76, 0, 2), (74, 2, 1), (72, 3, 1), (71, 4, 3), (72, 8, 2), (74, 10, 2), (76, 12, 4)]:
            t.put(beat, vibes(t.hz(midi), beats * t.beat), 0.2)
        t.buf = reverb(t.buf, 0.25)
    else:  # busted
        t = Track(64.0, 4)
        for bar in range(4):
            base = bar * 4
            for b in (1, 3):
                t.put(base + b, brush(), 0.25)
            t.put(base, bass_note(t.hz(ROOTS[bar % 4] - 12), t.beat * 1.8), 0.35)
        for midi, beat, beats in [(69, 0, 1.5), (68, 1.5, 0.5), (65, 2, 2), (64, 4, 3), (69, 8, 1), (72, 9, 1), (71, 10, 2), (64, 12, 4)]:
            t.put(beat, brass(t.hz(midi), beats * t.beat, 1100), 0.18)
        crackle(t, 0.05)
        t.buf = reverb(t.buf, 0.3)
    return t


# ------------------------------------------------------------------ files ---
def write(name, track, gain=1.0):
    path = os.path.join(OUT, name + ".wav")
    buf = track.buf
    peak = max(1e-6, max(abs(x) for x in buf))
    # Stems keep their relative levels: only scale down if they'd clip.
    g = gain if peak * gain <= 0.95 else 0.95 / peak
    frames = array.array("h", [int(max(-1.0, min(1.0, x * g)) * 32767) for x in buf])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames.tobytes())
    print("music %-22s %5.1fs  %.2f MB" % (name, len(buf) / SR, os.path.getsize(path) / 1e6))


def jobs():
    out = {
        "drums_brush": shared_drums_brush, "drums_combat": shared_drums_combat,
        "wanted3": shared_wanted3, "wanted4": shared_wanted4, "wanted5": shared_wanted5,
        "combo_a": shared_combo_a, "combo_b": shared_combo_b,
        "verdict": theme_verdict, "map": theme_map,
    }
    for stage, bpm in STAGES.items():
        out[stage + "_explore"] = (lambda s=stage, b=bpm: stem_explore(s, b))
        out[stage + "_tension"] = (lambda s=stage, b=bpm: stem_tension(s, b))
        out[stage + "_combat"] = (lambda s=stage, b=bpm: stem_combat(s, b))
    for boss, bpm in BOSSES.items():
        out["boss_" + boss] = (lambda n=boss, b=bpm: boss_theme(n, b))
        out["boss_" + boss + "_hi"] = (lambda n=boss, b=bpm: boss_theme(n, b, True))
    for family in ("rule", "escape", "collapse", "retire", "busted"):
        out["end_" + family] = (lambda f=family: theme_ending(f))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, fn in jobs().items():
        path = os.path.join(OUT, name + ".wav")
        if which == "" and os.path.exists(path):
            continue
        if which not in ("", "all") and not name.startswith(which):
            continue
        write(name, fn())


if __name__ == "__main__":
    main()
