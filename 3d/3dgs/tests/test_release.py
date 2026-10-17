import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_3dgs', ROOT/'release.py')
release = importlib.util.module_from_spec(spec); spec.loader.exec_module(release)


class Artifacts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name)
        self.data = b'verified binary'
        self.item = dict(filename='binary.tar.xz', url='https://example.invalid/binary', sha256=hashlib.sha256(self.data).hexdigest())

    def test_download_verifies_before_promoting(self):
        with patch.object(release.urllib.request, 'urlopen', return_value=io.BytesIO(self.data)):
            self.assertEqual(release.download(self.item, self.output).read_bytes(), self.data)
        self.assertFalse(list(self.output.glob('*.part')))

    def test_bad_download_is_removed(self):
        with patch.object(release.urllib.request, 'urlopen', return_value=io.BytesIO(b'bad')):
            with self.assertRaisesRegex(RuntimeError, 'SHA256 mismatch'):
                release.download(self.item, self.output)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_bad_existing_artifact_is_not_overwritten(self):
        (self.output/self.item['filename']).write_bytes(b'corrupt')
        with patch.object(release.urllib.request, 'urlopen') as network:
            with self.assertRaisesRegex(RuntimeError, 'SHA256 mismatch'):
                release.download(self.item, self.output)
            network.assert_not_called()

    def test_missing_artifacts_fail_verification(self):
        lock = json.loads((ROOT/'artifacts.lock.json').read_text())
        with self.assertRaisesRegex(RuntimeError, 'Missing 3DGS artifact'):
            release.verify(self.output, lock)

    def test_release_covers_wheel_archive_and_rpm(self):
        lock = json.loads((ROOT/'artifacts.lock.json').read_text())
        names = [p.name for p in release.assets(self.output, lock)]
        self.assertEqual(len(names), 5)
        self.assertTrue(any(n.endswith('.whl') for n in names))
        self.assertTrue(any(n.endswith('.tar.xz') for n in names))
        self.assertTrue(any(n.endswith('.rpm') for n in names))
        self.assertIn('SHA256SUMS', names); self.assertIn('SOURCE_MANIFEST.json', names)

    def test_existing_asset_with_different_hash_is_never_overwritten(self):
        lock = json.loads((ROOT/'artifacts.lock.json').read_text())
        first = next(iter(lock['artifacts'].values()))['filename']
        (self.output/first).write_bytes(b'original')
        remote = json.dumps({'assets': [{'name': first}], 'draft': False})
        def download_existing(args, **kwargs):
            directory = Path(args[args.index('--dir')+1]); (directory/first).write_bytes(b'changed')
        with patch.object(release, 'verify'), patch.object(release.subprocess, 'check_output', return_value=remote), \
             patch.object(release.subprocess, 'run', side_effect=download_existing) as command:
            with self.assertRaisesRegex(RuntimeError, 'Refusing to overwrite'):
                release.publish(self.output, lock, 'published-sha')
        self.assertEqual(command.call_count, 1)


if __name__ == '__main__':
    unittest.main()
