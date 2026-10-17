#!/usr/bin/env python3
"""Prepare verified upstream binaries and publish immutable 3DGS release assets."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent
LOCK = ROOT / 'artifacts.lock.json'
DEFAULT_OUTPUT = ROOT.parents[1] / '_artifacts/3dgs-v1'


def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def download(item, output):
    path = output / item['filename']
    if not path.is_file():
        temporary = path.with_name(path.name + '.part')
        try:
            with urllib.request.urlopen(item['url'], timeout=120) as source, temporary.open('wb') as target:
                while block := source.read(1024 * 1024):
                    target.write(block)
            if sha256(temporary) != item['sha256']:
                raise RuntimeError(f'SHA256 mismatch: {path.name}')
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)
    if sha256(path) != item['sha256']:
        raise RuntimeError(f'SHA256 mismatch: {path.name}')
    return path


def metadata(lock):
    manifest = json.dumps(lock, indent=2, ensure_ascii=False) + '\n'
    checksums = ''.join(f"{i['sha256']}  {i['filename']}\n" for i in lock['artifacts'].values())
    return {'SOURCE_MANIFEST.json': manifest, 'SHA256SUMS': checksums}


def verify(output, lock):
    for item in lock['artifacts'].values():
        path = output / item['filename']
        if not path.is_file():
            raise RuntimeError(f'Missing 3DGS artifact: {path.name}')
        if sha256(path) != item['sha256']:
            raise RuntimeError(f'SHA256 mismatch: {path.name}')
    for name, text in metadata(lock).items():
        if not (output / name).is_file() or (output / name).read_text() != text:
            raise RuntimeError(f'Missing or changed release metadata: {name}')
    wheel = lock['artifacts']['pycolmap']
    with zipfile.ZipFile(output / wheel['filename']) as archive:
        assert any(n.endswith('/licenses/COPYING.txt') for n in archive.namelist()), 'Missing PyCOLMAP license'
        wheel_metadata = archive.read('pycolmap-4.2.1.dist-info/METADATA').decode()
        assert 'Version: 4.2.1\n' in wheel_metadata
    brush = lock['artifacts']['brush']
    with tarfile.open(output / brush['filename']) as archive:
        for key in ('member', 'license_member'):
            if not archive.getmember(brush[key]).isfile():
                raise RuntimeError(f'Expected regular Brush archive member: {brush[key]}')
    rpm = output / lock['artifacts']['vulkan_loader']['filename']
    with rpm.open('rb') as stream:
        if stream.read(4) != bytes.fromhex('edabeedb'):
            raise RuntimeError('Invalid Vulkan Loader RPM')


def assets(output, lock):
    return [output / i['filename'] for i in lock['artifacts'].values()] + [output / n for n in metadata(lock)]


def publish(output, lock, target):
    """Stage as a draft; verify every remote byte before making it public."""
    verify(output, lock)
    tag, repo = lock['release_tag'], lock['release_repository']
    listed = subprocess.check_output(['gh', 'api', '--paginate', f'repos/{repo}/releases', '--jq', '.[] | select(.tag_name == "' + tag + '")'], text=True)
    exists = bool(listed.strip())
    if exists:
        remote = json.loads(listed)
        existing = {a['name']: a for a in remote['assets']}
        if existing:
            with tempfile.TemporaryDirectory(prefix='3dgs-existing-release-') as temporary:
                subprocess.run(['gh', 'release', 'download', tag, '--repo', repo, '--dir', temporary], check=True)
                for path in assets(output, lock):
                    if path.name in existing and sha256(Path(temporary) / path.name) != sha256(path):
                        raise RuntimeError(f'Refusing to overwrite existing release asset: {path.name}')
        missing = [str(p) for p in assets(output, lock) if p.name not in existing]
        if missing and not remote['draft']:
            raise RuntimeError('Published release is incomplete; use a new release version')
        if missing:
            subprocess.run(['gh', 'release', 'upload', tag, '--repo', repo, *missing], check=True)
    else:
        subprocess.run(['gh', 'release', 'create', tag, '--repo', repo, '--target', target,
                        '--draft', '--title', '3DGS v1 — official Linux amd64 runtime dependencies',
                        '--notes-file', str(ROOT / 'RELEASE_NOTES.md'), *map(str, assets(output, lock))], check=True)
    # gh downloads work for both public and authenticated draft assets.
    with tempfile.TemporaryDirectory(prefix='3dgs-release-check-') as temporary:
        subprocess.run(['gh', 'release', 'download', tag, '--repo', repo, '--dir', temporary], check=True)
        verify(Path(temporary), lock)
    subprocess.run(['gh', 'release', 'edit', tag, '--repo', repo, '--draft=false'], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['prepare', 'verify', 'release'])
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--target', help='Published commit containing this release recipe; required to publish')
    args = parser.parse_args()
    lock = json.loads(LOCK.read_text())
    if args.command == 'prepare':
        args.output.mkdir(parents=True, exist_ok=True)
        for item in lock['artifacts'].values():
            print(download(item, args.output))
        for name, text in metadata(lock).items():
            (args.output / name).write_text(text)
    if args.command == 'release' and not args.target:
        parser.error('--target is required to publish a release')
    verify(args.output, lock)
    if args.command == 'release':
        publish(args.output, lock, args.target)
    print(f'3DGS {args.command}: verified {args.output}')


if __name__ == '__main__':
    main()
