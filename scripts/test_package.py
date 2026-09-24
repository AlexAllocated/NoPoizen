import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('package', Path(__file__).with_name('package.py'))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackagingTests(unittest.TestCase):
    def test_reproducible_installable_zip(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / 'a.zip', Path(directory) / 'b.zip'
            package.package(package.ROOT, first)
            package.package(package.ROOT, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_missing_volume_variant_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, files = package.payloads(package.ROOT)
            for name, data in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            (root / 'sounds/nopoizen-050.ogg').unlink()
            with self.assertRaises(ValueError):
                package.package(root)

    def test_changed_library_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, files = package.payloads(package.ROOT)
            for name, data in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            with (root / 'Libs/libchev/libchev.lua').open('ab') as file:
                file.write(b'\n-- changed\n')
            with self.assertRaises(ValueError):
                package.package(root)


if __name__ == '__main__':
    unittest.main()
