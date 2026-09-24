#!/usr/bin/env python3
"""Verify runtime inputs and optionally build a reproducible installable ZIP."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def payloads(root, library_source=None):
    toc = (root / 'NoPoizen.toc').read_text()
    match = re.search(r'^## Version: ([0-9]+\.[0-9]+\.[0-9]+(?:-[\w.]+)?)$', toc, re.M)
    if not match:
        raise ValueError('Missing or invalid addon version')
    files = [line for line in toc.splitlines() if line and not line.startswith('#')]
    if len(files) != len(set(files)) or files[:5] != [
        'Libs/libchev/libchev.lua', 'Libs/libchev/Debug.lua', 'Libs/libchev/DebugWindow.lua',
        'Libs/libchev/ReportWindow.lua', 'Libs/libchev/SelfTests.lua'
    ]:
        raise ValueError('Invalid TOC load order or duplicate entries')
    if any(not line.endswith('.lua') or line.startswith('scripts/') for line in files):
        raise ValueError('Only runtime Lua files may appear in the TOC')
    files += ['NoPoizen.toc', 'CHANGELOG.md', 'CURSEFORGE_DESCRIPTION.md',
              'Libs/libchev/manifest.json', 'Libs/libchev/LICENSE']
    files += [f'sounds/{stem}-{percent:03d}.ogg'
              for stem in ('nopoizen', 'hahaha') for percent in range(5, 101, 5)]
    result = {}
    for name in sorted(files):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or '\\' in name:
            raise ValueError(f'Unsafe package path: {name}')
        source = root / name
        if source.is_symlink() or not source.is_file() or not source.resolve().is_relative_to(root.resolve()):
            raise ValueError(f'Missing or unsafe runtime file: {name}')
        result[name] = source.read_bytes()
    manifest = json.loads(result['Libs/libchev/manifest.json'])
    expected = {'libchev.lua', 'Debug.lua', 'DebugWindow.lua', 'ReportWindow.lua', 'SelfTests.lua', 'LICENSE'}
    if manifest['repository'] != 'https://github.com/AlexAllocated/libchev' or set(manifest['files']) != expected:
        raise ValueError('Unexpected library manifest')
    for name, digest in manifest['files'].items():
        data = result['Libs/libchev/' + name]
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(f'Library hash mismatch: {name}')
        if library_source:
            upstream = subprocess.check_output(['git', '-C', str(library_source), 'show',
                                                f"{manifest['revision']}:{name}"])
            if data != upstream:
                raise ValueError(f'Library source mismatch: {name}')
    return match[1], result


def package(root, output=None, library_source=None):
    version, files = payloads(root, library_source)
    if output:
        with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, data in files.items():
                entry = zipfile.ZipInfo('NoPoizen/' + name, (1980, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, data)
        with zipfile.ZipFile(output) as archive:
            if archive.testzip() is not None or len(archive.namelist()) != len(files):
                raise ValueError('ZIP integrity check failed')
            if any(archive.read('NoPoizen/' + name) != data for name, data in files.items()):
                raise ValueError('ZIP payload mismatch')
    return version, len(files)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--library-source', type=Path)
    args = parser.parse_args()
    version, count = package(ROOT, args.output, args.library_source)
    print(f'NoPoizen {version}: {count} runtime/package files verified')
    if args.output:
        print(f'{args.output}: sha256={hashlib.sha256(args.output.read_bytes()).hexdigest()}')
