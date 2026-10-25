"""Native Windows bundle regressions, owned fixtures only; no live provider/history.

Set SESSION_SEARCH_TYPEBOX to the installed peer's entry module. Use the locked
Node on PATH. Optional SESSION_SEARCH_BASELINE points to a frozen candidate tree
with code/{stock,published,previous} and task/{stock,published,previous}; set
SESSION_SEARCH_REVISION to the selected exact baseline. Assertions are identical.
Temporary state follows TMP/TEMP/TMPDIR (set these to the admitted private root).
"""
import hashlib
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PATCH = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('regression_patch', PATCH / 'apply.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)

@unittest.skipUnless(os.name == 'nt', 'native Windows HOME/filesystem regression')
class NativeRegressionTests(unittest.TestCase):
    def run_case(self, scenario, mode, worker, backend='fts'):
        peer = os.environ.get('SESSION_SEARCH_TYPEBOX')
        self.assertTrue(peer and Path(peer).is_file(), 'set SESSION_SEARCH_TYPEBOX to a real installed peer entry module')
        with tempfile.TemporaryDirectory(prefix='session-search-regression-') as td:
            home = Path(td) / 'home'
            home.mkdir()
            pkg = home / 'candidate'
            baseline = os.environ.get('SESSION_SEARCH_BASELINE')
            if baseline:
                candidate = Path(baseline) / mode / os.environ.get('SESSION_SEARCH_REVISION', 'published')
                for rel in s.REL_FILES:
                    target = pkg / rel
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(candidate / rel, target)
            else:
                _, files = s.canonical_files(mode == 'code')
                for rel, body in files.items():
                    (pkg / rel).parent.mkdir(parents=True, exist_ok=True)
                    (pkg / rel).write_bytes(body)
            (pkg / 'package.json').write_text('{"version":"1.6.0","type":"module"}')
            before = {str(rel): hashlib.sha256((pkg / rel).read_bytes()).hexdigest() for rel in s.REL_FILES}
            # An allowlist prevents inherited HOME, profile/source selectors and
            # provider secrets from leaking into native import/singleton creation.
            env = {k: v for k, v in os.environ.items() if k.upper() in {
                'PATH', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'PATHEXT', 'TEMP', 'TMP', 'TMPDIR'}}
            env.update(USERPROFILE=str(home), PI_CODING_AGENT_DIR=str(home / 'profile'), SESSION_SEARCH_TYPEBOX=peer)
            proc = subprocess.run([os.environ.get('SESSION_SEARCH_NODE', 'node'),
                str(PATCH / 'tests/session-search-regression.mjs'), str(pkg), str(home / 'case'), scenario, mode, worker, backend],
                cwd=home, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=40)
            after = {str(rel): hashlib.sha256((pkg / rel).read_bytes()).hexdigest() for rel in s.REL_FILES}
            self.assertEqual(after, before, 'the tested production bytes must remain exact')
            self.assertEqual(proc.returncode, 0, f'{scenario}/{mode}/{worker}/{backend}\n{proc.stdout}\n{proc.stderr}')
            print(proc.stdout.strip())

    def test_native_no_home_roots_and_reader(self):
        for mode in ('code', 'task'):
            for worker in ('main', 'worker', 'source'):
                with self.subTest(mode=mode, worker=worker):
                    self.run_case('no-home', mode, worker)

    def test_missing_unreadable_vs_readable_empty_roots(self):
        for backend in ('fts', 'hybrid'):
            for worker in ('main', 'worker', 'source'):
                with self.subTest(backend=backend, worker=worker):
                    self.run_case('preservation', 'code', worker, backend)

    def test_partial_legacy_hybrid_fts_id_coverage(self):
        for worker in ('main', 'worker', 'source'):
            with self.subTest(worker=worker):
                self.run_case('partial-fts', 'code', worker, 'hybrid')

    def test_native_unreadable_root_preserves_index(self):
        for backend in ('fts', 'hybrid'):
            for worker in ('main', 'worker', 'source'):
                with self.subTest(backend=backend, worker=worker):
                    self.run_case('unreadable', 'code', worker, backend)

    def test_same_service_reader_after_own_sync(self):
        for backend in ('fts', 'hybrid'):
            for worker in ('main', 'worker', 'source'):
                with self.subTest(backend=backend, worker=worker):
                    self.run_case('own-sync', 'code', worker, backend)

    def test_configured_roots_and_containment(self):
        for mode in ('code', 'task'):
            for worker in ('main', 'worker', 'source'):
                with self.subTest(mode=mode, worker=worker):
                    self.run_case('configured', mode, worker)

    def test_modern_env_roots_and_containment(self):
        for worker in ('main', 'worker', 'source'):
            with self.subTest(worker=worker):
                self.run_case('env-roots', 'code', worker)

    def test_actual_indexer_input_formats_and_preservation(self):
        for scenario in ('format-qwen', 'format-google', 'format-role'):
            for worker in ('main', 'worker', 'source'):
                with self.subTest(scenario=scenario, worker=worker):
                    self.run_case(scenario, 'code', worker, 'hybrid')

    def test_actual_setup_preservation_and_explicit_mapping(self):
        for worker in ('main', 'source'):
            with self.subTest(worker=worker):
                self.run_case('setup', 'code', worker)

if __name__ == '__main__':
    unittest.main(verbosity=2)
