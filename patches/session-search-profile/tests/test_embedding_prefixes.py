"""Document/query formatting and no-FTS semantic-first regressions. Synthetic only."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PATCH = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prefix_patch', PATCH / 'apply.py')
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)


class PrefixTests(unittest.TestCase):
    def run_case(self, kind, scenario='prefixes'):
        _, files = patch.canonical_files(True)
        with tempfile.TemporaryDirectory(prefix='embedding-prefixes-') as td:
            root = Path(td)
            for rel, body in files.items():
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(body)
            env = {k: v for k, v in os.environ.items() if k.upper() in {
                'PATH', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'PATHEXT', 'TEMP', 'TMP', 'TMPDIR'}}
            proc = subprocess.run([os.environ.get('SESSION_SEARCH_NODE', 'node'),
                str(PATCH / 'tests/embedding-prefixes.mjs'), str(root), kind, scenario],
                cwd=root, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=25)
            self.assertEqual(proc.returncode, 0, f'{kind}/{scenario}\n{proc.stdout}\n{proc.stderr}')
            print(proc.stdout.strip())

    def test_bundled_input_formats(self):
        for kind in ('main', 'worker'):
            with self.subTest(kind=kind):
                self.run_case(kind)

    def test_source_input_formats(self):
        self.run_case('source')

    def test_configuration_default_and_overrides(self):
        for kind in ('main', 'source'):
            with self.subTest(kind=kind):
                self.run_case(kind, 'defaults')

    def test_semantic_first_does_not_consult_keyword_ranks(self):
        for kind in ('main', 'worker', 'source'):
            with self.subTest(kind=kind):
                self.run_case(kind, 'search')


if __name__ == '__main__':
    unittest.main(verbosity=2)
