"""Strict model formatting and role transport, generated source/main/worker."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PATCH = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('contracts_patch', PATCH / 'apply.py')
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)


class EmbeddingContracts(unittest.TestCase):
    def run_case(self, kind, scenario):
        _, files = patch.canonical_files(True)
        with tempfile.TemporaryDirectory(prefix='embedding-contracts-') as td:
            root = Path(td)
            for rel, body in files.items():
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(body)
            env = {k: v for k, v in os.environ.items() if k.upper() in {
                'PATH', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'PATHEXT', 'TEMP', 'TMP', 'TMPDIR'}}
            proc = subprocess.run([os.environ.get('SESSION_SEARCH_NODE', 'node'),
                str(PATCH / 'tests/embedding-contracts.mjs'), str(root), kind, scenario],
                cwd=root, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=25)
            self.assertEqual(proc.returncode, 0, f'{kind}/{scenario}\n{proc.stdout}\n{proc.stderr}')
            print(proc.stdout.strip())

    def test_exact_mapping(self):
        for kind in ('source', 'main', 'worker'):
            with self.subTest(kind=kind):
                self.run_case(kind, 'mapping')

    def test_real_loopback_transport(self):
        for kind in ('source', 'main', 'worker'):
            with self.subTest(kind=kind):
                self.run_case(kind, 'transport')

    def test_semantic_only_search(self):
        for kind in ('source', 'main', 'worker'):
            with self.subTest(kind=kind):
                self.run_case(kind, 'search')

    def test_config_preservation(self):
        for kind in ('source', 'main'):
            with self.subTest(kind=kind):
                self.run_case(kind, 'config')


if __name__ == '__main__':
    unittest.main(verbosity=2)
