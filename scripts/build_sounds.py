#!/usr/bin/env python3
"""Build bounded-volume custom sounds without modifying WoW's shared audio CVars.

Requires ffmpeg with libvorbis. The source WAV files remain untouched.
"""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
output = root / 'sounds'
output.mkdir(exist_ok=True)
for stem in ('nopoizen', 'hahaha'):
    for percent in range(5, 101, 5):
        subprocess.run([
            'ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error', '-y',
            '-i', str(root / f'{stem}.wav'), '-map_metadata', '-1',
            '-af', f'volume={percent / 100:.2f}', '-c:a', 'libvorbis', '-q:a', '4',
            str(output / f'{stem}-{percent:03d}.ogg'),
        ], check=True)
print('Built 40 volume variants (5%–100%).')
