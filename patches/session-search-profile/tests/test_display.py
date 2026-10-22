"""Exact main/worker display and previous-canonical migration, no personal index."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

PATCH = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('display_patch', PATCH / 'apply.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)

class DisplayTests(unittest.TestCase):
    def test_main_worker_display(self):
        stock, patched = s.canonical_files()
        for leaf in ('dist/index.js', 'dist/index-worker.js'):
            rel = Path(leaf)
            self.assertIn(rel, patched, 'worker must be guarded/backed up/restored')
            source = patched[rel].decode()
            start = source.index('function slugToProject(')
            end = source.index('\n}', start) + 2
            body = source[start:end]
            command = body + "\nconst assert=require('node:assert/strict');const slug='--work-proj-alpha--';assert.equal(slugToProject(slug,'/work/proj-alpha'),'/work/proj-alpha');assert.equal(slugToProject(slug),slug);assert.equal(slugToProject(slug,''),slug);console.log('main/worker cwd + unchanged slug');"
            subprocess.run(['node', '-e', command], check=True)
            self.assertIn('slugToProject(s.projectSlug, s.cwd)', source)
            self.assertIn('summary: buildSummary(entry.session)', source)
            self.assertNotIn('summary: String(r.summary ?? "")', source)

    def test_previous_transition_and_complete_restore(self):
        for mode in (False, True):
            stock, previous = s.canonical_files(mode, previous=True)
            _, current = s.canonical_files(mode)
            with tempfile.TemporaryDirectory() as td:
                root=Path(td)
                (root/'package.json').write_text('{"version":"1.6.0"}')
                for rel,data in previous.items():
                    (root/rel).parent.mkdir(parents=True,exist_ok=True)
                    (root/rel).write_bytes(data)
                s.configure_paths(root)
                self.assertEqual(s.classify(root,mode)[0],'previous-patched')
                s.apply(root,mode)
                self.assertEqual(s.read_files(root),current)
                receipts=list(s.BACKUP_ROOT.glob('*/receipt.json'))
                self.assertEqual(len(receipts),1)
                self.assertEqual(len(json.loads(receipts[0].read_text())['sha256']),len(s.REL_FILES))
                s.apply(root,mode)
                self.assertEqual(len(list(s.BACKUP_ROOT.glob('*/receipt.json'))),1)
                s.restore(root,mode)
                self.assertEqual(s.read_files(root),stock)
                (root/'dist/index-worker.js').write_bytes(stock[Path('dist/index-worker.js')]+b'\n// unknown')
                with self.assertRaises(RuntimeError): s.apply(root,mode)

if __name__=='__main__': unittest.main()
