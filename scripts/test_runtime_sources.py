"""Prevent known arithmetic fixtures that throw in WoW's Lua VM."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent
# Deliberately conservative: even comments should not suggest constructing a
# nonfinite game fixture by dividing by a literal zero. Offline files are exempt.
ZERO_DIVISION = re.compile(r"/\s*\(*\s*[+-]?\s*0(?:\.0*)?(?:[eE][+-]?\d+)?(?![\w.])")


class RuntimeSourceTests(unittest.TestCase):
    def test_toc_sources_have_no_literal_zero_division(self):
        runtime_files = [line.strip() for line in (ROOT / 'NoPoizen.toc').read_text().splitlines()
                         if line.strip().endswith('.lua')]
        self.assertTrue(runtime_files)
        for name in runtime_files:
            with self.subTest(file=name):
                self.assertNotRegex((ROOT / name).read_text(), ZERO_DIVISION,
                                    'Keep zero-division fixtures in offline-only tests')


if __name__ == '__main__':
    unittest.main()
