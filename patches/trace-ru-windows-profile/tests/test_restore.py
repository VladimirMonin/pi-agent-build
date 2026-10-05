"""Trace restore regression; synthetic files only, no Pi or package builder calls.

Run with an existing owned private parent outside Git:
  python -I -B patches/trace-ru-windows-profile/tests/test_restore.py --fixture-root <PRIVATE_PARENT>
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import unittest
from unittest import mock
import uuid

PATCH = Path(__file__).resolve().parents[1]
REPO = PATCH.parents[1]
spec = importlib.util.spec_from_file_location("trace_restore_contract", PATCH / "apply.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
PARENT: Path


class RestoreContract(unittest.TestCase):
    def setUp(self):
        self.fixture = PARENT / ("trace-restore-" + uuid.uuid4().hex)
        self.root = self.fixture / "package"
        self.backups = self.fixture / "backups"
        for rel in module.FILES:
            target = self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(module.PAYLOAD / rel, target)
        (self.root / "viewer/assets.json").write_bytes(b'[]\n')
        self.backup = module.create_backup(self.root, self.backups)

    def image(self):
        return {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}

    def manifest(self, change):
        file = self.backup / "manifest.json"
        data = json.loads(file.read_text())
        change(data)
        file.write_text(json.dumps(data))

    def refuse_without_writes(self):
        before = self.image()
        with mock.patch.object(module.shutil, "copy2", wraps=shutil.copy2) as copy, mock.patch.object(module, "rebuild_assets") as build:
            with self.assertRaises(RuntimeError):
                module.restore(self.root, self.backups)
            self.assertEqual(0, copy.call_count)
            build.assert_not_called()
        self.assertEqual(before, self.image())

    def test_exact_restore_including_recorded_assets(self):
        (self.root / "viewer/assets.json").write_bytes(b'SYNTHETIC_CHANGED_ASSETS\n')
        with mock.patch.object(module, "rebuild_assets") as build:
            self.assertEqual(0, module.restore(self.root, self.backups))
            build.assert_not_called()
        self.assertEqual(b'[]\n', (self.root / "viewer/assets.json").read_bytes())
        self.assertTrue(all(value == "patched" for value in module.states(self.root).values()))

    def test_unknown_current_file_refuses_restore(self):
        (self.root / "index.ts").write_bytes(b'SYNTHETIC_UNKNOWN_CURRENT\n')
        self.refuse_without_writes()

    def test_late_backup_corruption_refuses_before_first_copy(self):
        (self.backup / list(module.FILES)[-1]).write_bytes(b'SYNTHETIC_CORRUPT_LAST_BACKUP\n')
        self.refuse_without_writes()

    def test_rehashed_unknown_backup_does_not_gain_authority(self):
        data = b'SYNTHETIC_REHASHED_UNKNOWN_BACKUP\n'
        (self.backup / "index.ts").write_bytes(data)
        self.manifest(lambda m: m["files"][0].update(sha256=hashlib.sha256(data).hexdigest()))
        self.refuse_without_writes()

    def test_corrupt_backup_assets_refuses_before_source_writes(self):
        (self.backup / "viewer/assets.json").write_bytes(b'SYNTHETIC_CORRUPT_ASSETS\n')
        self.refuse_without_writes()

    def test_incomplete_duplicate_or_escaping_inventory_refuses(self):
        original = (self.backup / "manifest.json").read_bytes()
        for change in (lambda m: m["files"].pop(), lambda m: m["files"].__setitem__(1, dict(m["files"][0])), lambda m: m["files"][0].update(path="../../outside.txt")):
            (self.backup / "manifest.json").write_bytes(original)
            self.manifest(change)
            self.refuse_without_writes()

    def test_wrong_backup_identity_refuses(self):
        self.manifest(lambda m: m.update(version="999.0.0"))
        self.refuse_without_writes()

    def test_unrecorded_backup_assets_refuses(self):
        self.manifest(lambda m: m.pop("assetsSha256"))
        self.refuse_without_writes()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture-root", required=True)
    args = parser.parse_args()
    PARENT = Path(args.fixture_root).resolve()
    if not PARENT.is_dir() or PARENT == PARENT.parent or PARENT.is_relative_to(REPO) or REPO.is_relative_to(PARENT):
        raise SystemExit("Existing private fixture parent outside Git required")
    unittest.main(argv=[__file__], verbosity=2)
