"""Word timings for the Kokoro narration (Kokoro emits none and Whisper is unavailable offline).

The script text is known exactly, so only timing is needed: ffmpeg silencedetect finds the real
pauses in each line's wav; pauses are matched to the phrase breaks (, . ? !) in SCRIPT.md, and words
inside a phrase share its speech span by character length. Writes voices[].words into audio_meta.json
(frame-relative seconds), which captions.mjs consumes.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FFMPEG = sys.argv[1] if len(sys.argv) > 1 else 'ffmpeg'

script = open(os.path.join(ROOT, 'SCRIPT.md'), encoding='utf-8').read()
lines = [l.strip() for l in script.splitlines() if l.startswith('    ') and l.strip()]
meta_path = os.path.join(ROOT, 'audio_meta.json')
meta = json.load(open(meta_path, encoding='utf-8'))


def speech_regions(wav, dur):
    out = subprocess.run([FFMPEG, '-hide_banner', '-nostats', '-i', wav, '-af', 'silencedetect=noise=-38dB:d=0.12',
                          '-f', 'null', '-'], capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r'silence_start: ([\d.]+)', out)]
    ends = [float(x) for x in re.findall(r'silence_end: ([\d.]+)', out)]
    silences = list(zip(starts, ends + [dur] * (len(starts) - len(ends))))
    regions, t = [], 0.0
    for s, e in silences:
        if s - t > 0.05:
            regions.append([t, s])
        t = e
    if dur - t > 0.05:
        regions.append([t, dur])
    return regions


for i, v in enumerate(meta['voices']):
    text = lines[i]
    wav = os.path.join(ROOT, v['path'])
    dur = float(v.get('duration_s') or v.get('duration'))
    regions = speech_regions(wav, dur)
    phrases = [p.split() for p in re.split(r'(?<=[,.?!])\s+', text) if p.strip()]
    if len(regions) != len(phrases):
        # merge/split mismatch: fall back to one span from first speech to last speech
        span = [regions[0][0], regions[-1][1]] if regions else [0.0, dur]
        total = sum(len(w) for p in phrases for w in p) or 1
        spans, t = [], span[0]
        for p in phrases:
            n = sum(len(w) for w in p)
            d = (span[1] - span[0]) * n / total
            spans.append([t, t + d])
            t += d
    else:
        spans = regions
    words = []
    for p, (a, b) in zip(phrases, spans):
        n = sum(len(w) for w in p) or 1
        t = a
        for w in p:
            d = (b - a) * len(w) / n
            words.append({'text': w, 'start': round(t, 3), 'end': round(t + d, 3)})
            t += d
    v['words'] = words
    print(f"voice {i + 1:02d}: {len(words)} words, {len(regions)} speech regions / {len(phrases)} phrases"
          + ('' if len(regions) == len(phrases) else ' (proportional)'))

json.dump(meta, open(meta_path, 'w', encoding='utf-8'), indent=2)
